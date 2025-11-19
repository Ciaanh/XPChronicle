-- OverlayHelper.lua
-- Centralize quest overlay and color logic used by various XP bar views

local Addon = XPBarEnhanced
local OverlayHelper = {}

-- Ensure localization table exists to avoid nil indexing
Addon.L = Addon.L or {}
local L = Addon.L

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

    -- Include quest counts even when XP amounts are zero so users know there are
    -- completed/incomplete quests that simply award no XP (useful for repeatable
    -- or reputation-only quests). Pull counts from XPBar module if available.
    local completeCount, incompleteCount = 0, 0
    if Addon.XPBar and type(Addon.XPBar.GetQuestCounts) == "function" then
        completeCount, incompleteCount = Addon.XPBar:GetQuestCounts()
    end

    if showComplete and ((completeXP and completeXP > 0) or (completeCount and completeCount > 0)) then
        if completeXP and completeXP > 0 then
            local completePercent = Addon.XPBar and Addon.XPBar:FormatPercent(completeXP, maxXP, decimals) or "0%"
            local completeText = completePercent
            if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
                completeText = Addon.XPBar:ColorText(completePercent, Addon.Colors.Key.QuestComplete)
            end
            if completeCount and completeCount > 0 then
                -- Build a localized count string and append it (avoid duplicating the numeric value)
                local t1 = (type(L["TT_QUEST"]) == "string") and L["TT_QUEST"] or "%d quest"
                local tN = (type(L["TT_QUESTS"]) == "string") and L["TT_QUESTS"] or "%d quests"
                local countText = (completeCount == 1) and string.format(t1, completeCount) or string.format(tN, completeCount)
                completeText = string.format("%s - %s", completeText, countText)
            end
            table.insert(parts, string.format("Completed Quests: %s", completeText))
        else
            -- XP is zero but there are completed quests; show the count only
            if completeCount and completeCount > 0 then
                local t1 = (type(L["TT_QUEST"]) == "string") and L["TT_QUEST"] or "%d quest"
                local tN = (type(L["TT_QUESTS"]) == "string") and L["TT_QUESTS"] or "%d quests"
                local countText = (completeCount == 1) and string.format(t1, completeCount) or string.format(tN, completeCount)
                table.insert(parts, string.format("Completed Quests: %s", countText))
            end
        end
    end

    if restedXP and restedXP > 0 and maxXP and maxXP > 0 then
        local restedPercent = Addon.XPBar and Addon.XPBar:FormatPercent(restedXP, maxXP, 0) or "0%"
        local restedText = restedPercent
        if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
            restedText = Addon.XPBar:ColorText(restedPercent, Addon.Colors.Key.XpBarRested)
        end
        table.insert(parts, string.format("Rested: %s", restedText))
    end

    if showIncomplete and ((incompleteXP and incompleteXP > 0) or (incompleteCount and incompleteCount > 0)) then
        if incompleteXP and incompleteXP > 0 then
            local incompletePercent = Addon.XPBar and Addon.XPBar:FormatPercent(incompleteXP, maxXP, decimals) or "0%"
            local incompleteText = incompletePercent
            if Addon.XPBar and Addon.Colors and Addon.Colors.Key then
                incompleteText = Addon.XPBar:ColorText(incompletePercent, Addon.Colors.Key.QuestIncomplete)
            end
            if incompleteCount and incompleteCount > 0 then
                local countText = (incompleteCount == 1) and string.format(L["TT_QUEST"] or "%d quest", incompleteCount) or string.format(L["TT_QUESTS"] or "%d quests", incompleteCount)
                incompleteText = string.format("%s - %s", incompleteText, countText)
            end
            table.insert(parts, string.format("Incomplete Quests: %s", incompleteText))
        else
            if incompleteCount and incompleteCount > 0 then
                local t1 = (type(L["TT_QUEST"]) == "string") and L["TT_QUEST"] or "%d quest"
                local tN = (type(L["TT_QUESTS"]) == "string") and L["TT_QUESTS"] or "%d quests"
                local countText = (incompleteCount == 1) and string.format(t1, incompleteCount) or string.format(tN, incompleteCount)
                table.insert(parts, string.format("Incomplete Quests: %s", countText))
            end
        end
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, " - ")
end

Addon.OverlayHelper = OverlayHelper
return OverlayHelper
