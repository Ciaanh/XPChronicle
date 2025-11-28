-- XP Bar Enhanced - TextFormatter
-- Utilities for formatting numbers and times used by the UI and tooltip

local Addon = XPBarEnhanced
Addon.TextFormatter = Addon.TextFormatter or {}
local TextFormatter = Addon.TextFormatter

local L = Addon.L or {}

function TextFormatter:AbbreviateNumber(num, decimals)
    if not num or num == 0 then
        return "0"
    end
    decimals = decimals or 1
    if num < 1000 then
        return tostring(math.floor(num))
    elseif num < 1000000 then
        return string.format("%sK", tostring(math.floor(num / 1000)))
    elseif num < 1000000000 then
        return string.format("%.2fM", num / 1000000)
    else
        return string.format("%.2fB", num / 1000000000)
    end
end

function TextFormatter:FormatNumber(num, abbreviate)
    if not num then
        return "0"
    end
    if abbreviate then
        return self:AbbreviateNumber(num)
    elseif BreakUpLargeNumbers then
        return BreakUpLargeNumbers(num)
    else
        return tostring(math.floor(num))
    end
end

function TextFormatter:FormatTime(seconds, short)
    if not seconds or seconds <= 0 then
        return short and "0s" or "0 seconds"
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if short then
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm", minutes)
        else
            return string.format("%ds", secs)
        end
    else
        local parts = {}
        if days > 0 then
            table.insert(parts, days == 1 and "1 day" or string.format("%d days", days))
        end
        if hours > 0 then
            table.insert(parts, hours == 1 and "1 hour" or string.format("%d hours", hours))
        end
        if minutes > 0 and days == 0 then
            table.insert(parts, minutes == 1 and "1 minute" or string.format("%d minutes", minutes))
        end
        if secs > 0 and hours == 0 and days == 0 then
            table.insert(parts, secs == 1 and "1 second" or string.format("%d seconds", secs))
        end
        return #parts > 0 and table.concat(parts, " ") or "0 seconds"
    end
end

function TextFormatter:FormatPercent(value, maxValue, decimals)
    if not value or not maxValue or maxValue == 0 then
        return "0%"
    end
    decimals = decimals or 1
    local percent = (value / maxValue) * 100
    return string.format("%." .. decimals .. "f%%", percent)
end

function TextFormatter:GetXPRateText(xpPerHour, abbreviate)
    if not xpPerHour or xpPerHour <= 0 then
        return L["TT_CALCULATING"]
    end
    local rate = self:FormatNumber(xpPerHour, abbreviate)
    local xpLabel = L["TT_XP_PER_HOUR"]
    return string.format("%s %s", rate, xpLabel)
end

function TextFormatter:GetTimeToLevelText(secondsToLevel, prefix)
    if not secondsToLevel or secondsToLevel <= 0 then
        return L["TT_NA"]
    end
    if secondsToLevel > 356400 then
        return L["TT_OVER_99_HOURS"]
    end
    local timeStr = self:FormatTime(secondsToLevel, true)
    if prefix then
        return string.format("%s: %s", prefix, timeStr)
    else
        return timeStr
    end
end

function TextFormatter:GetLevelText(level)
    local lvl = level or UnitLevel("player") or 1
    local fmt = L["TT_LEVEL_FMT"]
    return string.format(fmt, tonumber(lvl) or 1)
end

function TextFormatter:GetXPText(currentXP, maxXP, abbreviate, showRemaining)
    if not currentXP or not maxXP then
        return ""
    end
    local current = self:FormatNumber(currentXP, abbreviate)
    local max = self:FormatNumber(maxXP, abbreviate)
    if showRemaining then
        local remaining = self:FormatNumber(maxXP - currentXP, abbreviate)
        return string.format("%s / %s (%s)", current, max, remaining)
    end
    return string.format("%s / %s", current, max)
end

function TextFormatter:GetPercentText(currentXP, maxXP, decimals, showQuestPercent, questXP)
    if not currentXP or not maxXP then
        return "0%"
    end
    local percent = self:FormatPercent(currentXP, maxXP, decimals)
    if showQuestPercent and questXP and questXP > 0 then
        local withQuest = currentXP + questXP
        local questPercent = self:FormatPercent(withQuest, maxXP, decimals)
        return string.format("%s (%s)", percent, questPercent)
    end
    return percent
end

local function colorText(text, colorKey)
    if not (Addon and Addon.Colors and Addon.Colors.Get) then
        return tostring(text)
    end
    local c = Addon.Colors:Get(colorKey)
    if not c or not c.r then
        return tostring(text)
    end
    local hex =
        string.format(
        "|c%02X%02X%02X%02X",
        math.floor((c.a or 1) * 255),
        math.floor(c.r * 255),
        math.floor(c.g * 255),
        math.floor(c.b * 255)
    )
    return hex .. tostring(text) .. "|r"
end

function TextFormatter:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, opts)
    decimals = decimals or 0

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
    if Addon.QuestXP and type(Addon.QuestXP.GetQuestCounts) == "function" then
        completeCount, incompleteCount = Addon.QuestXP:GetQuestCounts()
    end

    -- Completed
    if showComplete and ((completeXP and completeXP > 0) or (completeCount and completeCount > 0)) then
        if completeXP and completeXP > 0 then
            local completePercent = "0%"
            if Addon.TextFormatter and Addon.TextFormatter.FormatPercent then
                completePercent = Addon.TextFormatter:FormatPercent(completeXP, maxXP, decimals)
            end
            local completeText = colorText(completePercent, Addon.Colors.Key.QuestComplete)
            table.insert(parts, string.format(L["TT_QUESTS_COMPLETE"], completeText))
        else
            if completeCount and completeCount > 0 then
                local t1 = L["TT_QUEST"]
                local tN = L["TT_QUESTS"]
                local countText =
                    (completeCount == 1) and string.format(t1, completeCount) or string.format(tN, completeCount)
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
            table.insert(parts, string.format(L["TT_QUESTS_INCOMPLETE"], incompleteText))
        else
            if incompleteCount and incompleteCount > 0 then
                local t1 = L["TT_QUEST"]
                local tN = L["TT_QUESTS"]
                local countText =
                    (incompleteCount == 1) and string.format(t1, incompleteCount) or string.format(tN, incompleteCount)
                table.insert(parts, string.format(L["TT_QUESTS_INCOMPLETE"], countText))
            end
        end
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, " - ")
end

function TextFormatter:GetSessionTimeText(sessionSeconds, label)
    local s = tonumber(sessionSeconds) or 0
    if s <= 0 then
        return ""
    end
    local timeStr = self:FormatTime(s, true)
    if label and label ~= "" then
        return string.format("%s: %s", label, timeStr)
    end
    return timeStr
end

function TextFormatter:GetLevelTimeText(levelSeconds, label)
    local s = tonumber(levelSeconds) or 0
    if s <= 0 then
        return ""
    end
    local timeStr = self:FormatTime(s, true)
    if label and label ~= "" then
        return string.format("%s: %s", label, timeStr)
    end
    return timeStr
end

function TextFormatter:GetSessionXPText(sessionXP, abbreviate)
    if not sessionXP or sessionXP <= 0 then
        return ""
    end
    local xp = self:FormatNumber(sessionXP, abbreviate)
    local sessionLabel = L["TT_SESSION_XP"] or L["TT_SESSION"]
    return string.format("%s: %s", sessionLabel, xp)
end

return TextFormatter
