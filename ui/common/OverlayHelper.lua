-- OverlayHelper.lua
-- Centralize quest overlay and color logic used by various XP bar views

local Addon = XPBarEnhanced
local OverlayHelper = {}

-- Returns formatted quest summary text given quest xp values and max xp
---Format quest summary text used by various views
function OverlayHelper:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, opts)
    opts = opts or {}
    local decimals = opts.decimals or 1
    local db = Addon.db or {}
    local questOverlaysEnabled = db.showQuestXP ~= false
    local showComplete = db.showCompleteQuestOverlay ~= false
    local showIncomplete = db.showIncompleteQuestOverlay == true

    if not maxXP or maxXP <= 0 then return "" end
    if not questOverlaysEnabled then return "" end

    local parts = {}

    if showComplete and completeXP and completeXP > 0 then
        local completePercent = Addon.XPBar and Addon.XPBar:FormatPercent(completeXP, maxXP, decimals) or "0%"
        local completeText = completePercent
        if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
            completeText = Addon.XPBar:ColorText(completePercent, Addon.Colors.Key.QuestComplete)
        end
        table.insert(parts, string.format("Completed Quests: %s", completeText))
    end

    if restedXP and restedXP > 0 and maxXP and maxXP > 0 then
        local restedPercent = Addon.XPBar and Addon.XPBar:FormatPercent(restedXP, maxXP, 0) or "0%"
        local restedText = restedPercent
        if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
            restedText = Addon.XPBar:ColorText(restedPercent, Addon.Colors.Key.XpBarRested)
        end
        table.insert(parts, string.format("Rested: %s", restedText))
    end

    if showIncomplete and incompleteXP and incompleteXP > 0 then
        local incompletePercent = Addon.XPBar and Addon.XPBar:FormatPercent(incompleteXP, maxXP, decimals) or "0%"
        local incompleteText = incompletePercent
        if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
            incompleteText = Addon.XPBar:ColorText(incompletePercent, Addon.Colors.Key.QuestIncomplete)
        end
        table.insert(parts, string.format("Incomplete Quests: %s", incompleteText))
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, " - ")
end

Addon.OverlayHelper = OverlayHelper
return OverlayHelper
