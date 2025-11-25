-- OverlayHelper.lua
-- Centralize quest overlay and color logic used by various XP bar views

local Addon = XPBarEnhanced
local OverlayHelper = {}

local function colorText(text, colorKey)
    if not (Addon and Addon.Colors and Addon.Colors.Get) then
        return tostring(text)
    end
    local c = Addon.Colors:Get(colorKey)
    if not c or not c.r then
        return tostring(text)
    end
    local hex = string.format("|c%02X%02X%02X%02X", math.floor((c.a or 1) * 255), math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
    return hex .. tostring(text) .. "|r"
end

-- Ensure localization table exists to avoid nil indexing
Addon.L = Addon.L or {}
local L = Addon.L

-- Returns formatted quest summary text given quest xp values and max xp
---Format quest summary text used by various views
function OverlayHelper:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, decimals)
    local db = Addon.db or {}
    local questOverlaysEnabled = db.showQuestXP ~= false
    local showComplete = db.showCompleteQuestOverlay ~= false
    local showIncomplete = db.showIncompleteQuestOverlay == true

    if not maxXP or maxXP <= 0 then
        return ""
    end
    if not questOverlaysEnabled then
        return ""
    end

    local parts = {}

    -- Counts
    local completeCount, incompleteCount = 0, 0
    if Addon.QuestXPService and type(Addon.QuestXPService.GetQuestCounts) == "function" then
        completeCount, incompleteCount = Addon.QuestXPService:GetQuestCounts()
    end

    -- Completed
    if showComplete and ((completeXP and completeXP > 0) or (completeCount and completeCount > 0)) then
        if completeXP and completeXP > 0 then
            local completePercent = "0%"
            if Addon.TextFormatter and Addon.TextFormatter.FormatPercent then
                completePercent = Addon.TextFormatter:FormatPercent(completeXP, maxXP, decimals)
            end
            local completeText = colorText(completePercent, Addon.Colors.Key.QuestComplete)
            if completeCount and completeCount > 0 then
                local t1 = L["TT_QUEST"]
                local tN = L["TT_QUESTS"]
                local countText = (completeCount == 1) and string.format(t1, completeCount) or string.format(tN, completeCount)
                completeText = string.format("%s - %s", completeText, countText)
            end
            table.insert(parts, string.format(L["TT_QUESTS_COMPLETE"], completeText))
        else
            if completeCount and completeCount > 0 then
                local t1 = L["TT_QUEST"]
                local tN = L["TT_QUESTS"]
                local countText = (completeCount == 1) and string.format(t1, completeCount) or string.format(tN, completeCount)
                table.insert(parts, string.format(L["TT_QUESTS_COMPLETE"], countText))
            end
        end
    end

    -- Rested
    if restedXP and restedXP > 0 and maxXP and maxXP > 0 then
        local restedPercent = "0%"
        if Addon.TextFormatter and Addon.TextFormatter.FormatPercent then
            restedPercent = Addon.TextFormatter:FormatPercent(restedXP, maxXP, 0)
        end
        local restedText = colorText(restedPercent, Addon.Colors.Key.XpBarRested)
        table.insert(parts, string.format("%s: %s", L["TT_RESTED"], restedText))
    end

    -- Incomplete
    if showIncomplete and ((incompleteXP and incompleteXP > 0) or (incompleteCount and incompleteCount > 0)) then
        if incompleteXP and incompleteXP > 0 then
            local incompletePercent = "0%"
            if Addon.TextFormatter and Addon.TextFormatter.FormatPercent then
                incompletePercent = Addon.TextFormatter:FormatPercent(incompleteXP, maxXP, decimals)
            end
            local incompleteText = colorText(incompletePercent, Addon.Colors.Key.QuestIncomplete)
            if incompleteCount and incompleteCount > 0 then
                local countText = (incompleteCount == 1) and string.format(L["TT_QUEST"], incompleteCount) or string.format(L["TT_QUESTS"], incompleteCount)
                incompleteText = string.format("%s - %s", incompleteText, countText)
            end
            table.insert(parts, string.format(L["TT_QUESTS_INCOMPLETE"], incompleteText))
        else
            if incompleteCount and incompleteCount > 0 then
                local t1 = L["TT_QUEST"]
                local tN = L["TT_QUESTS"]
                local countText = (incompleteCount == 1) and string.format(t1, incompleteCount) or string.format(tN, incompleteCount)
                table.insert(parts, string.format(L["TT_QUESTS_INCOMPLETE"], countText))
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
