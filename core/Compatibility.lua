-- Compatibility.lua
-- Small helper to detect the current client and provide compatibility shims

local Addon = XPBarEnhanced
local Compatibility = {}

-- Basic detection using presence of common APIs. In-game these globals exist.
local function detectClassic()
    -- If the C_QuestLog namespace is missing we are likely on older Classic builds
    if not C_QuestLog then
        return true
    end
    return false
end

Compatibility.IsClassic = detectClassic()
Compatibility.IsRetail = not Compatibility.IsClassic

-- Provide a safe wrapper to query quest APIs which may vary between builds
---Return number of quest log entries available on this client
function Compatibility:GetNumQuestLogEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local n = C_QuestLog.GetNumQuestLogEntries()
        return n or 0
    elseif GetNumQuestLogEntries then
        local n = GetNumQuestLogEntries()
        return n or 0
    end
    return 0
end

-- Get a normalized quest info table. Prefer the C_QuestLog API where present but
-- fall back to older global APIs when running on Classic-style clients.
---Return a normalized quest info table for the given index
function Compatibility:GetQuestInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        return C_QuestLog.GetInfo(index)
    end

    if GetQuestLogTitle then
        -- Older API returns multiple values; normalize into a single table
        local title,
            level,
            tag,
            isHeader,
            isCollapsed,
            isComplete,
            frequency,
            questID,
            startEvent,
            displayQuestID,
            isOnMap = GetQuestLogTitle(index)
        if not title then
            return nil
        end
        return {
            title = title,
            level = level,
            tag = tag,
            isHeader = isHeader,
            isCollapsed = isCollapsed,
            isComplete = (isComplete == 1 or isComplete == true),
            questID = questID,
            isOnMap = isOnMap
        }
    end

    return nil
end

-- Get the XP reward for a quest in a compatibility-safe way. Some APIs accept
-- questID whereas older globals expected an index; try the common global first
-- and fallback safely.
---Return the XP reward for a quest (compat-mode). Accepts either a quest log index or questID.
function Compatibility:GetQuestRewardXP(indexOrIdentifier, questID)
    -- indexOrIdentifier: usually the quest log index (1..N)
    -- questID: the numeric questID when available (may be nil on some clients)
    if not indexOrIdentifier and not questID then
        return 0
    end

    -- Prefer passing questID to GetQuestLogRewardXP when available (Retail often accepts questID)
    if GetQuestLogRewardXP and questID then
        local ok, xp = pcall(GetQuestLogRewardXP, questID)
        if ok and type(xp) == "number" then
            return xp or 0
        end
    end

    -- Fall back to passing the quest log index if that exists in this client
    if GetQuestLogRewardXP and indexOrIdentifier then
        local ok, xp = pcall(GetQuestLogRewardXP, indexOrIdentifier)
        if ok and type(xp) == "number" then
            return xp or 0
        end
    end

    -- As a last resort, try to read a likely XP field from C_QuestLog.GetInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo and indexOrIdentifier then
        local ok, info = pcall(C_QuestLog.GetInfo, indexOrIdentifier)
        if ok and info then
            -- Try a few common field names that different clients may use
            local xp = info.xpReward or info.rewardXP or info.xp or info.xpAmount
            if type(xp) == "number" and xp > 0 then
                return xp or 0
            end
        end
    end

    -- Compatibility fallback: on some Retail clients GetQuestLogRewardXP only returns
    -- a non-zero value for the currently selected quest. The WeakAuras implementation
    -- selects each quest entry before reading reward XP; replicate that safely here
    -- when an index is available.
    if indexOrIdentifier and SelectQuestLogEntry and GetQuestLogSelection and GetQuestLogRewardXP then
        local ok, sel
        -- Save current selection if possible
        local savedSel
        ok, savedSel = pcall(GetQuestLogSelection)
        savedSel = ok and savedSel or nil

        -- Try selecting the requested index and read reward XP
        local xi = indexOrIdentifier
        local okSel, okXP, xpVal
        okSel = pcall(SelectQuestLogEntry, xi)
        if okSel then
            okXP, xpVal = pcall(GetQuestLogRewardXP, questID or xi)
            if okXP and type(xpVal) == "number" and xpVal > 0 then
                -- Restore original selection if we saved one
                if savedSel and SelectQuestLogEntry then
                    pcall(SelectQuestLogEntry, savedSel)
                end
                -- Hide potential static popups that may have been triggered by the selection
                if StaticPopup_Hide then
                    pcall(StaticPopup_Hide, "ABANDON_QUEST")
                end
                return xpVal or 0
            end
        end

        -- Restore selection even if reading failed
        if savedSel and SelectQuestLogEntry then
            pcall(SelectQuestLogEntry, savedSel)
        end
        if StaticPopup_Hide then
            pcall(StaticPopup_Hide, "ABANDON_QUEST")
        end
    end

    return 0
end

-- Common wrappers for completion/turn-in checks
---Return whether the quest is marked complete on this client (compat layer)
function Compatibility:IsQuestComplete(questID)
    if C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(questID)
    end
    return false
end

---Return whether the quest can be turned in on this client
function Compatibility:ReadyForTurnIn(questID)
    if C_QuestLog and C_QuestLog.ReadyForTurnIn then
        return C_QuestLog.ReadyForTurnIn(questID)
    end
    return false
end

-- Expose to Addon namespace
Addon.Compatibility = Compatibility
return Compatibility
