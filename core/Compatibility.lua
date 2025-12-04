-- Compatibility.lua
-- Thin wrapper around quest APIs for Retail client

local Addon = XPBarEnhanced
local Compatibility = {}

---Return number of quest log entries
function Compatibility:GetNumQuestLogEntries()
    return C_QuestLog.GetNumQuestLogEntries() or 0
end

---Return quest info table for the given index
function Compatibility:GetQuestInfo(index)
    return C_QuestLog.GetInfo(index)
end

---Return the XP reward for a quest by questID
function Compatibility:GetQuestRewardXP(index, questID)
    if questID then
        return GetQuestLogRewardXP(questID) or 0
    end
    return 0
end

---Return whether the quest is marked complete
function Compatibility:IsQuestComplete(questID)
    return C_QuestLog.IsComplete(questID)
end

---Return whether the quest can be turned in
function Compatibility:ReadyForTurnIn(questID)
    return C_QuestLog.ReadyForTurnIn(questID)
end

Addon.Compatibility = Compatibility
return Compatibility

