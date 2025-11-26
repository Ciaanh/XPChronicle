-- XP Bar Enhanced - QuestXPService
-- Centralized quest XP calculation and caching service

local Addon = XPBarEnhanced
Addon.QuestXPService = Addon.QuestXPService or {}
local QuestXPService = Addon.QuestXPService

local questCache = { data = nil, timestamp = 0, TTL = 0.5 }

local function areObjectivesComplete(questID)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return false
    end
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if not objectives or #objectives == 0 then
        return false
    end
    for _, objective in ipairs(objectives) do
        if not objective.finished then
            return false
        end
    end
    return true
end

local function isQuestReadyForTurnIn(questID, info)
    if info then
        if info.isComplete or info.isAutoComplete then
            return true
        end
        if info.isOnQuest == false then
            return false
        end
    end

    local comp = Addon.Compatibility
    if comp then
        if comp.IsQuestComplete and comp:IsQuestComplete(questID) then
            return true
        end
        if comp.ReadyForTurnIn and comp:ReadyForTurnIn(questID) then
            return true
        end
    end

    if areObjectivesComplete(questID) then
        return true
    end
    return false
end

function QuestXPService:InvalidateQuestCache()
    questCache.data = nil
    questCache.timestamp = 0
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_INVALIDATED)
    end
end

function QuestXPService:GetQuestXP(forceRefresh)
    local comp = Addon.Compatibility
    if not comp or not comp.GetNumQuestLogEntries then
        return 0, 0, 0
    end

    if not forceRefresh and questCache.data then
        local now = GetTime()
        if (now - questCache.timestamp) < questCache.TTL then
            return questCache.data.totalQuestXP, questCache.data.completeQuestXP, questCache.data.incompleteQuestXP
        end
    end

    local numEntries = comp:GetNumQuestLogEntries()
    if not numEntries or numEntries <= 0 then
        questCache.data = { totalQuestXP = 0, completeQuestXP = 0, incompleteQuestXP = 0, completeQuestCount = 0, incompleteQuestCount = 0 }
        questCache.timestamp = GetTime()
        return 0, 0, 0
    end

    local totalQuestXP, completeQuestXP, incompleteQuestXP = 0, 0, 0
    local completeQuestCount, incompleteQuestCount = 0, 0
    local countedQuests = {}

    for i = 1, numEntries do
        local info = comp:GetQuestInfo(i)
        if info and not info.isHeader and not info.isHidden then
            local key = info.questID or ("idx:" .. tostring(i))
            if not countedQuests[key] then
                countedQuests[key] = true
                local xp = comp.GetQuestRewardXP and comp:GetQuestRewardXP(i, info.questID) or 0
                if xp > 0 then
                    if isQuestReadyForTurnIn(info.questID, info) then
                        completeQuestXP = completeQuestXP + xp
                        completeQuestCount = completeQuestCount + 1
                    else
                        incompleteQuestXP = incompleteQuestXP + xp
                        incompleteQuestCount = incompleteQuestCount + 1
                    end
                    totalQuestXP = totalQuestXP + xp
                end
            end
        end
    end

    questCache.data = {
        totalQuestXP = totalQuestXP,
        completeQuestXP = completeQuestXP,
        incompleteQuestXP = incompleteQuestXP,
        completeQuestCount = completeQuestCount,
        incompleteQuestCount = incompleteQuestCount
    }
    questCache.timestamp = GetTime()

    return totalQuestXP, completeQuestXP, incompleteQuestXP
end

function QuestXPService:GetQuestCounts()
    self:GetQuestXP()
    if questCache.data then
        return questCache.data.completeQuestCount or 0, questCache.data.incompleteQuestCount or 0
    end
    return 0, 0
end

return QuestXPService
