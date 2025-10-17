-- XP Bar Enhanced - XP Bar Text Formatter
-- Formats text overlays for XP bars with number abbreviation, time formatting, etc.

local Addon = XPBarEnhanced
local L = Addon.L

XPC_XPBarTextFormatter = {}

-----------------------------------
-- Number Formatting
-----------------------------------

function XPC_XPBarTextFormatter:AbbreviateNumber(num, decimals)
	if not num then return "0" end
	
	decimals = decimals or 1
	
	-- < 1,000: Show as-is
	if num < 1000 then
		return tostring(math.floor(num))
	end
	
	-- 1,000 - 999,999: Show with K
	if num < 1000000 then
		local k = num / 1000
		return string.format("%." .. decimals .. "fK", k)
	end
	
	-- 1,000,000 - 999,999,999: Show with M
	if num < 1000000000 then
		local m = num / 1000000
		return string.format("%.2fM", m)
	end
	
	-- >= 1,000,000,000: Show with B
	local b = num / 1000000000
	return string.format("%.2fB", b)
end

function XPC_XPBarTextFormatter:FormatNumber(num, abbreviate)
	if not num then return "0" end
	
	if abbreviate then
		return self:AbbreviateNumber(num)
	else
		-- Use Blizzard's BreakUpLargeNumbers if available
		if BreakUpLargeNumbers then
			return BreakUpLargeNumbers(num)
		else
			return tostring(math.floor(num))
		end
	end
end

-----------------------------------
-- Time Formatting
-----------------------------------

function XPC_XPBarTextFormatter:FormatTime(seconds, short)
	if not seconds or seconds <= 0 then
		return short and "0s" or "0 seconds"
	end
	
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	
	if short then
		-- Short format: "2d 5h" or "1h 30m" or "45m" or "30s"
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
		-- Long format: "2 days 5 hours" or "1 hour 30 minutes"
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
		
		if #parts == 0 then
			return "0 seconds"
		end
		
		return table.concat(parts, " ")
	end
end

-----------------------------------
-- Percent Formatting
-----------------------------------

function XPC_XPBarTextFormatter:FormatPercent(value, maxValue, decimals)
	if not value or not maxValue or maxValue == 0 then
		return "0%"
	end
	
	decimals = decimals or 1
	local percent = (value / maxValue) * 100
	
	return string.format("%." .. decimals .. "f%%", percent)
end

-----------------------------------
-- Text Builder Methods
-----------------------------------

function XPC_XPBarTextFormatter:GetLevelText(level)
	if not level then
		level = UnitLevel("player")
	end
	
	return string.format("Level %d", level)
end

function XPC_XPBarTextFormatter:GetXPText(currentXP, maxXP, abbreviate, showRemaining)
	if not currentXP or not maxXP then
		return ""
	end
	
	local current = self:FormatNumber(currentXP, abbreviate)
	local max = self:FormatNumber(maxXP, abbreviate)
	
	if showRemaining then
		local remaining = self:FormatNumber(maxXP - currentXP, abbreviate)
		return string.format("%s / %s (%s)", current, max, remaining)
	else
		return string.format("%s / %s", current, max)
	end
end

function XPC_XPBarTextFormatter:GetPercentText(currentXP, maxXP, decimals, showQuestPercent, questXP)
	if not currentXP or not maxXP then
		return "0%"
	end
	
	local percent = self:FormatPercent(currentXP, maxXP, decimals)
	
	if showQuestPercent and questXP and questXP > 0 then
		local withQuest = currentXP + questXP
		local questPercent = self:FormatPercent(withQuest, maxXP, decimals)
		return string.format("%s (%s)", percent, questPercent)
	else
		return percent
	end
end

function XPC_XPBarTextFormatter:GetXPRateText(xpPerHour, abbreviate)
	if not xpPerHour or xpPerHour <= 0 then
		return "Calculating..."
	end
	
	local rate = self:FormatNumber(xpPerHour, abbreviate)
	return string.format("%s XP/Hour", rate)
end

function XPC_XPBarTextFormatter:GetTimeToLevelText(secondsToLevel, prefix)
	if not secondsToLevel or secondsToLevel <= 0 then
		return "N/A"
	end
	
	-- Cap at 99+ hours for display
	if secondsToLevel > 356400 then -- 99 hours
		return "99+ hours"
	end
	
	local timeStr = self:FormatTime(secondsToLevel, true)
	
	if prefix then
		return string.format("%s: %s", prefix, timeStr)
	else
		return timeStr
	end
end

function XPC_XPBarTextFormatter:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, decimals)
	if not maxXP or maxXP <= 0 then
		return ""
	end
	
	-- Check configuration to see what should be shown
	local Addon = XPBarEnhanced
	local db = Addon.db or {}
	local questOverlaysEnabled = db.showQuestXP ~= false  -- Default: true (master toggle)
	local showComplete = db.showCompleteQuestOverlay ~= false  -- Default: true
	
	local parts = {}
	decimals = decimals or 1
	
	-- Get dynamic colors from user's customized bar colors
	local completeColor = XPC_XPBarColors and XPC_XPBarColors:GetUserTextColor(Color.QuestComplete) or "|cFFF2A633"
	local restedColor = XPC_XPBarColors and XPC_XPBarColors:GetUserTextColor(Color.Rested) or "|cFF00CCFF"
	local resetColor = "|r"
	
	-- Quest completion percentage (only if enabled and has XP)
	if questOverlaysEnabled and showComplete and completeXP and completeXP > 0 then
		local completePercent = self:FormatPercent(completeXP, maxXP, decimals)
		table.insert(parts, string.format("Completed Quests: %s%s%s", 
			completeColor, completePercent, resetColor))
	end
	
	-- Rested percentage
	if restedXP and restedXP > 0 and maxXP and maxXP > 0 then
		local restedPercent = self:FormatPercent(restedXP, maxXP, 0)
		table.insert(parts, string.format("Rested: %s%s%s", 
			restedColor, restedPercent, resetColor))
	end
	
	if #parts == 0 then
		return ""
	end
	
	return table.concat(parts, " - ")
end

function XPC_XPBarTextFormatter:GetSessionTimeText(sessionSeconds, prefix)
	if not sessionSeconds then
		return ""
	end
	
	local timeStr = self:FormatTime(sessionSeconds, true)
	
	if prefix then
		return string.format("%s: %s", prefix, timeStr)
	else
		return timeStr
	end
end

function XPC_XPBarTextFormatter:GetLevelTimeText(levelSeconds, prefix)
	if not levelSeconds then
		return ""
	end
	
	local timeStr = self:FormatTime(levelSeconds, true)
	
	if prefix then
		return string.format("%s: %s", prefix, timeStr)
	else
		return timeStr
	end
end

function XPC_XPBarTextFormatter:GetCombinedRateText(xpPerHour, timeToLevel, abbreviate)
	local ratePart = self:GetXPRateText(xpPerHour, abbreviate)
	local timePart = self:GetTimeToLevelText(timeToLevel)
	
	if ratePart == "Calculating..." and timePart == "N/A" then
		return "Calculating..."
	elseif ratePart == "Calculating..." then
		return "Leveling in: " .. timePart
	elseif timePart == "N/A" then
		return ratePart
	else
		-- Format: "Leveling in: {time} ({rate})"
		-- Format rate for parentheses (remove " XP/Hour" suffix and add K suffix for >10K)
		local rate = xpPerHour
		local rateStr
		if rate > 10000 then
			rateStr = string.format("%.1fK", rate / 1000)
		else
			rateStr = self:FormatNumber(rate, false)
		end
		return string.format("Leveling in: %s (%s XP/Hour)", timePart, rateStr)
	end
end

function XPC_XPBarTextFormatter:GetCombinedSessionText(sessionSeconds, levelSeconds)
	local sessionPart = self:GetSessionTimeText(sessionSeconds, "Session")
	local levelPart = self:GetLevelTimeText(levelSeconds, "This Level")
	
	local parts = {}
	
	if sessionPart ~= "" then
		table.insert(parts, sessionPart)
	end
	
	if levelPart ~= "" then
		table.insert(parts, levelPart)
	end
	
	if #parts == 0 then
		return ""
	end
	
	return table.concat(parts, " - ")
end

function XPC_XPBarTextFormatter:GetSessionXPText(sessionXP, abbreviate)
    if not sessionXP or sessionXP <= 0 then
        return ""
    end

    local xp = self:FormatNumber(sessionXP, abbreviate)
    return string.format("Session: %s XP", xp)
end

function XPC_XPBarTextFormatter:GetRestedStatusText(restedXP, maxXP)
    if not restedXP or restedXP <= 0 or not maxXP or maxXP <= 0 then
        return "Not Rested"
    end

    local restedPercent = self:FormatPercent(restedXP, maxXP, 0)
    return string.format("Rested: %s", restedPercent)
end

function XPC_XPBarTextFormatter:GetQuestXPText(completeXP, incompleteXP, abbreviate)
    if not completeXP and not incompleteXP then
        return ""
    end

    local parts = {}
    if completeXP and completeXP > 0 then
        table.insert(parts, string.format("Complete: %s", self:FormatNumber(completeXP, abbreviate)))
    end

    if incompleteXP and incompleteXP > 0 then
        table.insert(parts, string.format("Incomplete: %s", self:FormatNumber(incompleteXP, abbreviate)))
    end

    if #parts == 0 then
        return ""
    end

    return "Quest XP: " .. table.concat(parts, " / ")
end

function XPC_XPBarTextFormatter:GetHintText(frame)
	-- Match the hints from XPBarEnhancedBar tooltip
	local hints = {}
	
	-- Add drag hint if frame or its container supports dragging
	-- For Flat bar: the container (parent) is draggable
	-- For Legacy bar: not draggable (fixed position)
	local isDraggable = false
	if frame then
		local container = frame:GetParent()
		-- Check if container is draggable OR if frame itself is draggable
		isDraggable = (container and container:IsMovable()) or frame:IsMovable()
	end
	
	if isDraggable then
		table.insert(hints, "Shift + Drag to move")
	end
	
	table.insert(hints, "Alt + Click to open options")
	table.insert(hints, "Ctrl + Click to toggle stats")
	
	return table.concat(hints, "\n")
end
