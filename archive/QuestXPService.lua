local Addon = XPBarEnhanced
Addon.App = Addon.App or {}
Addon.App.Services = Addon.App.Services or {}

local QuestXPService = {
    cacheTTL = 0.5,
}

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

    if C_QuestLog then
        if C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
            return true
        end

        if C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then
            return true
        end
    end

    if areObjectivesComplete(questID) then
        return true
    end

    return false
end

function QuestXPService:InvalidateCache()
    self.cache = nil
end

function QuestXPService:GetQuestXP(forceRefresh)
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        return 0, 0, 0
    end

    if not forceRefresh then
        local cache = self.cache
        if cache then
            local now = (GetTime and GetTime()) or time()
            local ttl = self.cacheTTL or 0.5
            if cache.timestamp and (now - cache.timestamp) < ttl then
                return cache.totalQuestXP, cache.completeQuestXP, cache.incompleteQuestXP
            end
        end
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    if not numEntries or numEntries <= 0 then
        local timestamp = (GetTime and GetTime()) or time()
        self.cache = {
            totalQuestXP = 0,
            completeQuestXP = 0,
            incompleteQuestXP = 0,
            timestamp = timestamp,
        }
        return 0, 0, 0
    end

    local totalQuestXP = 0
    local completeQuestXP = 0
    local incompleteQuestXP = 0
    
    -- Quest counts for tooltip display
    local completeQuestCount = 0
    local incompleteQuestCount = 0
    
    -- Track unique quest IDs to prevent double-counting
    local countedQuests = {}

    local getSelection = rawget(_G, "GetQuestLogSelection")
    local selectQuest = rawget(_G, "SelectQuestLogEntry")
    local getRewardXP = rawget(_G, "GetQuestLogRewardXP")
    local originalSelection = getSelection and getSelection() or nil
    local usedSelectQuest = false

    local setSelectedQuest = C_QuestLog.SetSelectedQuest
    local getSelectedQuest = C_QuestLog.GetSelectedQuest
    local originalSelectedQuest = getSelectedQuest and getSelectedQuest() or nil
    local usedSetSelectedQuest = false

    local getQuestLogRewardXP = C_QuestLog.GetQuestLogRewardXP
    local getQuestRewardXP = C_QuestLog.GetQuestRewardXP

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        -- Filter out headers AND hidden quests (like the Quest_Counter addon does)
        if info and not info.isHeader and not info.isHidden then
            local questID = info.questID
            if questID then
                local xp = 0

                if getQuestLogRewardXP then
                    xp = getQuestLogRewardXP(questID) or 0
                end

                if xp <= 0 and getQuestRewardXP then
                    xp = getQuestRewardXP(questID) or 0
                end

                if xp <= 0 and (getRewardXP or getQuestRewardXP) then
                    if setSelectedQuest then
                        local ok = pcall(setSelectedQuest, questID)
                        if ok then
                            usedSetSelectedQuest = true
                        end
                    elseif selectQuest then
                        selectQuest(info.questLogIndex or i)
                        usedSelectQuest = true
                    end

                    if getRewardXP then
                        xp = getRewardXP() or 0
                    end

                    if xp <= 0 and getQuestRewardXP then
                        xp = getQuestRewardXP(questID) or 0
                    end
                end

                if xp and xp > 0 then
                    -- Only process this quest if we haven't already counted it
                    if not countedQuests[questID] then
                        countedQuests[questID] = true
                        
                        totalQuestXP = totalQuestXP + xp
                        
                        local isComplete = isQuestReadyForTurnIn(questID, info)
                        
                        if isComplete then
                            completeQuestXP = completeQuestXP + xp
                            completeQuestCount = completeQuestCount + 1
                        else
                            incompleteQuestXP = incompleteQuestXP + xp
                            incompleteQuestCount = incompleteQuestCount + 1
                        end
                    end
                end
            end
        end
    end

    if usedSetSelectedQuest and setSelectedQuest then
        if originalSelectedQuest then
            pcall(setSelectedQuest, originalSelectedQuest)
        else
            pcall(setSelectedQuest, 0)
        end
    end

    if usedSelectQuest and selectQuest and originalSelection then
        selectQuest(originalSelection)
    end

    self.cache = {
        totalQuestXP = totalQuestXP,
        completeQuestXP = completeQuestXP,
        incompleteQuestXP = incompleteQuestXP,
        completeQuestCount = completeQuestCount,
        incompleteQuestCount = incompleteQuestCount,
        timestamp = (GetTime and GetTime()) or time(),
    }

    return totalQuestXP, completeQuestXP, incompleteQuestXP
end

-- Get quest counts (number of quests in each category)
function QuestXPService:GetQuestCounts(forceRefresh)
    -- Ensure cache is populated
    self:GetQuestXP(forceRefresh)
    
    if self.cache then
        return self.cache.completeQuestCount or 0, self.cache.incompleteQuestCount or 0
    end
    
    return 0, 0
end

Addon.App.Services.QuestXPService = QuestXPService
