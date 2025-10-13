local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Services = Addon.App.Services or {}

local SavedVariables = Addon.App.Core and Addon.App.Core.SavedVariables

local LevelHistoryService = {}

function LevelHistoryService:Initialize()
    if not SavedVariables then
        return
    end

    SavedVariables:EnsureDefaults(Addon.defaults)
end

function LevelHistoryService:GetLevelTable()
    if not SavedVariables then
        return nil
    end

    local levelData = SavedVariables:GetLevelData()
    local playerKey = SavedVariables:GetPlayerKey()
    levelData[playerKey] = levelData[playerKey] or {}
    return levelData[playerKey]
end

function LevelHistoryService:GetLevelDuration(level)
    local tableForPlayer = self:GetLevelTable()
    if not tableForPlayer or not tableForPlayer[level] then
        return 0
    end

    local levelInfo = tableForPlayer[level]
    if levelInfo.levelStart and levelInfo.levelEnd then
        return levelInfo.levelEnd - levelInfo.levelStart
    end

    return 0
end

function LevelHistoryService:OnLevelUp(newLevel)
    local tableForPlayer = self:GetLevelTable()
    if not tableForPlayer then
        return
    end

    local oldLevel = newLevel - 1
    if tableForPlayer[oldLevel] then
        tableForPlayer[oldLevel].levelEnd = time()
        tableForPlayer[oldLevel].maxXP = tableForPlayer[oldLevel].maxXP or UnitXPMax("player")
    end

    tableForPlayer[newLevel] = tableForPlayer[newLevel] or {}
    tableForPlayer[newLevel].levelStart = time()
    tableForPlayer[newLevel].xpAtStart = UnitXP("player")
end

Addon.App.Services.LevelHistoryService = LevelHistoryService
