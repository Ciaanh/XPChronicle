-- XP Bar Enhanced - QuestXP
-- Centralized quest XP calculation and caching service

local Addon = XPBarEnhanced
Addon.QuestXP = Addon.QuestXP or {}
local QuestXP = Addon.QuestXP

-- Replace simple cache with a per-quest cache and totals
local questCache = {
    perQuest = {}, -- [key] = { xp = number, complete = bool, stable = bool }
    totals = nil, -- { total, complete, incomplete }
    timestamp = 0,
    TTL = 0.5,
    ready = false
}

-- Small helper to key per-quest entries — prefer questID if available
local function makeQuestKey(info, idx)
    if info and info.questID and info.questID > 0 then
        return tostring(info.questID)
    end
    return "idx:" .. tostring(idx)
end

-- New: determine whether the quest is ready for turn-in/complete.
-- Uses available fields and compatibility API/C_QuestLog fallbacks.
local function isQuestReadyForTurnIn(comp, questID, info)
    if info then
        if info.isComplete or info.isCompleted then
            return true
        end
        -- if we have a questLogIndex and the compatibility wrapper exposes a "IsQuestComplete" method, prefer that
        if comp and comp.IsQuestComplete and info.questLogIndex then
            local ok, val = pcall(comp.IsQuestComplete, comp, info.questLogIndex)
            if ok and val then
                return true
            end
        end
    end

    -- fallback to C_QuestLog APIs (safe pcall)
    if questID and C_QuestLog and C_QuestLog.IsComplete then
        local ok, val = pcall(C_QuestLog.IsComplete, questID)
        if ok and val then
            return true
        end
    end
    -- Also consider quests that are ready to turn-in as effectively 'complete' for the
    -- purposes of `completeQuestXP` totals similar to WeakAuras behavior.
    if questID and comp and comp.ReadyForTurnIn then
        local ok, val = pcall(comp.ReadyForTurnIn, comp, questID)
        if ok and val then
            return true
        end
    end
    if questID and C_QuestLog and C_QuestLog.ReadyForTurnIn then
        local ok, val = pcall(C_QuestLog.ReadyForTurnIn, questID)
        if ok and val then
            return true
        end
    end
    if questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, flagged = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok and flagged then
            return true
        end
    end

    return false
end

-- Choose best XP source (index-based preferred)
local function readXPForQuest(comp, idx, info)
    -- prefer index-based scaled XP if available
    if comp.GetQuestLogRewardXP then
        local ok, xp = pcall(comp.GetQuestLogRewardXP, comp, idx)
        if ok and xp and xp > 0 then
            return xp, "index"
        end
    end
    -- fallback to questID-based DB value
    if comp.GetQuestRewardXP and info and info.questID then
        local ok, xp = pcall(comp.GetQuestRewardXP, comp, idx, info.questID)
        if ok and xp and xp > 0 then
            return xp, "byID"
        end
    end
    -- last resort: info.rewardXP or similar
    local raw = info and (info.rewardXP or info.value or info.xp) or 0
    return (raw or 0), "info"
end

-- Build or refresh the per-quest cache; returns computed totals
local function buildQuestCache(force)
    local comp = Addon.Compatibility
    if not comp or not comp.GetNumQuestLogEntries then
        -- if Compatibility not available, clear cache
        questCache.perQuest = {}
        questCache.totals = {0, 0, 0}
        questCache.timestamp = GetTime()
        questCache.ready = false
        return questCache.totals
    end

    local numEntries = comp:GetNumQuestLogEntries() or 0
    if numEntries <= 0 then
        questCache.perQuest = {}
        questCache.totals = {0, 0, 0}
        questCache.timestamp = GetTime()
        questCache.ready = true
        return questCache.totals
    end

    local totalQuestXP, completeQuestXP, incompleteQuestXP = 0, 0, 0
    local counted = {}

    -- iterate and populate perQuest entries
    for i = 1, numEntries do
        local info = comp:GetQuestInfo(i)
        if info and not info.isHeader and not info.isHidden then
            local key = makeQuestKey(info, i)
            if not counted[key] then
                counted[key] = true
                local xp, source = readXPForQuest(comp, i, info)
                -- Use the XP only if positive
                if xp and xp > 0 then
                    -- Mark stable if we used index API (considered canonical)
                    local stable = (source == "index")
                    local prev = questCache.perQuest[key]
                    if prev and prev.xp == xp and prev.stable then
                        -- keep stable true, xp identical
                        stable = true
                    end
                    questCache.perQuest[key] = {
                        xp = xp,
                        complete = isQuestReadyForTurnIn(comp, info.questID, info),
                        stable = stable
                    }
                    if questCache.perQuest[key].complete then
                        completeQuestXP = completeQuestXP + xp
                    else
                        incompleteQuestXP = incompleteQuestXP + xp
                    end
                    totalQuestXP = totalQuestXP + xp
                end
            end
        end
    end

    questCache.totals = {totalQuestXP, completeQuestXP, incompleteQuestXP}
    questCache.timestamp = GetTime()
    questCache.ready = true
    return questCache.totals
end

-- Invalidate the quest cache (clear per-quest entries and totals)
function QuestXP:InvalidateQuestCache()
    questCache.perQuest = {}
    questCache.totals = nil
    questCache.timestamp = 0
    questCache.ready = false
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_INVALIDATED)
    end
end

-- tiny event frame for invalidation & rebuild scheduling
local function ensureCacheListeners()
    if QuestXP._listenerFrame then
        return
    end
    local frame = CreateFrame("Frame")
    QuestXP._listenerFrame = frame

    local function doDelayedRebuild(delay)
        delay = delay or 0.8
        if C_Timer and C_Timer.After then
            C_Timer.After(
                delay,
                function()
                    buildQuestCache(true)
                    -- notify the system to refresh UI
                    if Addon.EventBus and Addon.EventBus.Emit then
                        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT or "QUESTS:CACHE_REBUILT")
                        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE or "XPBAR:BROADCAST_UPDATE")
                    end
                end
            )
        else
            buildQuestCache(true)
            if Addon.EventBus and Addon.EventBus.Emit then
                Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT or "QUESTS:CACHE_REBUILT")
                Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE or "XPBAR:BROADCAST_UPDATE")
            end
        end
    end

    local function onEvent(_, event, ...)
        -- Invalidate cache on any quest/log related events and schedule rebuild
        QuestXP:InvalidateQuestCache()

        if event == "PLAYER_ENTERING_WORLD" then
            doDelayedRebuild(1.0)
        elseif event == "QUEST_TURNED_IN" then
            -- QUEST_TURNED_IN can arrive before quest log updates; use shorter delay to refresh quickly
            doDelayedRebuild(0.1)
        else
            -- small delay to allow server to populate scaled values
            doDelayedRebuild(0.5)
        end
    end

    frame:SetScript("OnEvent", onEvent)
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    frame:RegisterEvent("QUEST_TURNED_IN")
end

ensureCacheListeners()

-- Public API: returns totals, using cache and rebuild if needed
function QuestXP:GetQuestXP(forceRefresh)
    local comp = Addon.Compatibility
    if not comp or not comp.GetNumQuestLogEntries then
        -- no comp; return zeros
        return 0, 0, 0
    end

    -- if forced or cache expired, rebuild
    local now = GetTime()
    if forceRefresh or not questCache.totals or ((now - questCache.timestamp) > questCache.TTL) then
        buildQuestCache(forceRefresh)
    end

    if questCache.totals then
        return questCache.totals[1], questCache.totals[2], questCache.totals[3]
    end

    return 0, 0, 0
end

-- Public helper: return raw per-quest table (read-only)
function QuestXP:GetPerQuestData()
    return questCache.perQuest
end

-- Public helper: get per-quest entry by questID
function QuestXP:GetQuestByID(questID)
    if not questID then
        return nil
    end
    local key = tostring(questID)
    return questCache.perQuest[key]
end

-- Public helper: force an invalidate + schedule rebuild now or after specified delay
function QuestXP:Rebuild(delay)
    QuestXP:InvalidateQuestCache()
    delay = delay or 0.5
    if C_Timer and C_Timer.After then
        C_Timer.After(
            delay,
            function()
                buildQuestCache(true)
                if Addon.EventBus and Addon.EventBus.Emit then
                    Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT or "QUESTS:CACHE_REBUILT")
                    Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE or "XPBAR:BROADCAST_UPDATE")
                end
            end
        )
    else
        buildQuestCache(true)
        if Addon.EventBus and Addon.EventBus.Emit then
            Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT or "QUESTS:CACHE_REBUILT")
            Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE or "XPBAR:BROADCAST_UPDATE")
        end
    end
end

function QuestXP:GetQuestCounts()
    self:GetQuestXP()
    if questCache.totals then
        return questCache.totals[2] or 0, questCache.totals[3] or 0
    end
    return 0, 0
end

return QuestXP
