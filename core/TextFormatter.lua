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

function TextFormatter:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, opts)
    if Addon.OverlayHelper and Addon.OverlayHelper.GetQuestSummaryText then
        return Addon.OverlayHelper:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, opts)
    end
    return ""
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
