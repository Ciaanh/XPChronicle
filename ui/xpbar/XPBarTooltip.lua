-- XP Chronicle - XP Bar Tooltip Module
-- Shared tooltip logic for both Legacy and Flat XP bars

local Addon = XPChronicle
local L = function(key, ...) return Addon.L and Addon.L(key, ...) or key end

XPC_XPBarTooltip = {}

-- Track the current tooltip owner for refresh support
local currentTooltipOwner = nil

-----------------------------------
-- Utility Functions
-----------------------------------

function XPC_XPBarTooltip:FormatNumber(value)
	return BreakUpLargeNumbers(value)
end

function XPC_XPBarTooltip:FormatTime(seconds)
	if not seconds or seconds <= 0 then
		return L("TT_CALCULATING")
	end
	
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	
	if hours >= 99 then
		return L("TT_OVER_99_HOURS")
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
	end
end

function XPC_XPBarTooltip:CalculateXPPerHour(gainedXP, sessionTimeSeconds)
	if not sessionTimeSeconds or sessionTimeSeconds <= 0 then
		return 0
	end
	
	return math.floor((gainedXP / sessionTimeSeconds) * 3600)
end

function XPC_XPBarTooltip:CalculateTimeToLevel(remainingXP, xpPerHour)
	if not xpPerHour or xpPerHour <= 0 then
		return 0
	end
	
	return math.floor((remainingXP / xpPerHour) * 3600)
end

-----------------------------------
-- Section Builders
-----------------------------------

function XPC_XPBarTooltip:AddXPSection(tooltip)
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local percentXP = math.floor((currentXP / maxXP) * 100)
	local remainingXP = maxXP - currentXP
	local level = UnitLevel("player")
	
	-- Title: Experience (bold, white)
	GameTooltip_SetTitle(tooltip, L("TT_EXPERIENCE"))
	
	-- Current XP: Separated for better readability
	tooltip:AddDoubleLine(
		L("TT_CURRENT") .. ":",
		string.format("%s / %s", self:FormatNumber(currentXP), self:FormatNumber(maxXP)),
		0.7, 0.7, 0.7,  -- Label: lighter gray for contrast
		1.0, 1.0, 1.0   -- Value: bright white
	)
	
	-- Remaining XP: On its own line
	tooltip:AddDoubleLine(
		L("TT_REMAINING") .. ":",
		self:FormatNumber(remainingXP),
		0.7, 0.7, 0.7,  -- Label: lighter gray for contrast
		1.0, 1.0, 1.0   -- Value: bright white
	)
end

function XPC_XPBarTooltip:AddRestedSection(tooltip)
	local restedXP = GetXPExhaustion() or 0
	
	if restedXP <= 0 then
		return  -- Don't show if no rested XP
	end
	
	tooltip:AddLine(" ")  -- Blank line for section separation
	
	local maxXP = UnitXPMax("player")
	local restedPercent = (restedXP / maxXP) * 100
	
	-- Get user's rested color (uses their customized bar color)
	local restedR, restedG, restedB = XPC_XPBarColors:GetUserTooltipColor(Color.Rested)
	
	-- Show Rested and XP on the same line with user's color
	tooltip:AddDoubleLine(
		L("TT_RESTED"),
		string.format("%s (%.0f%%)", self:FormatNumber(restedXP), restedPercent),
		restedR, restedG, restedB,  -- Label: user's rested color
		restedR, restedG, restedB   -- Value: same rested color
	)
	
	if restedPercent > 0 and restedPercent < 10 then
		tooltip:AddLine("  " .. L("TT_RESTED_LOW_WARNING"), 1.0, 0.8, 0.0, true)
	end
end

function XPC_XPBarTooltip:AddQuestSection(tooltip)
	local QuestService = Addon.App.Services and Addon.App.Services.QuestXPService
	if not QuestService then
		return
	end
	
	-- Check configuration to see what should be shown
	local db = Addon.db or {}
	local questOverlaysEnabled = db.showQuestXP ~= false  -- Default: true (master toggle)
	local showComplete = db.showCompleteQuestOverlay ~= false  -- Default: true
	local showIncomplete = db.showIncompleteQuestOverlay == true  -- Default: false
	
	-- If quest overlays are completely disabled, don't show quest section
	if not questOverlaysEnabled then
		return
	end
	
	local totalQuestXP, completeQuestXP, incompleteQuestXP = QuestService:GetQuestXP()
	local completeQuestCount, incompleteQuestCount = QuestService:GetQuestCounts()
	
	-- Only show if there's any quest XP to display
	local hasCompleteToShow = showComplete and completeQuestXP and completeQuestXP > 0
	local hasIncompleteToShow = showIncomplete and incompleteQuestXP and incompleteQuestXP > 0
	
	if not hasCompleteToShow and not hasIncompleteToShow then
		return
	end
	
	local maxXP = UnitXPMax("player")
	
	tooltip:AddLine(" ")  -- Blank line for section separation
	
	-- Show complete quest XP if enabled and available
	if hasCompleteToShow then
		local questPercent = (completeQuestXP / maxXP) * 100
		
		-- Get user's quest color
		local completeR, completeG, completeB = XPC_XPBarColors:GetUserTooltipColor(Color.QuestComplete)
		
		-- Format quest count text (singular vs plural)
		local completeQuestText = completeQuestCount == 1 and L("TT_QUEST"):format(completeQuestCount) or L("TT_QUESTS"):format(completeQuestCount)
		
		-- Show "Completed Quest XP" with the details, using user's color for both label and value
		tooltip:AddDoubleLine(
			L("TT_QUEST_XP_COMPLETE"),
			string.format("%s (%.1f%%) - %s", self:FormatNumber(completeQuestXP), questPercent, completeQuestText),
			completeR, completeG, completeB,  -- Label: user's questComplete color
			completeR, completeG, completeB   -- Value: same questComplete color
		)
	end
	
	-- Show incomplete quest XP if enabled and available
	if hasIncompleteToShow then
		local questPercent = (incompleteQuestXP / maxXP) * 100
		
		-- Get user's incomplete quest color
		local incompleteR, incompleteG, incompleteB = XPC_XPBarColors:GetUserTooltipColor(Color.QuestIncomplete)
		
		-- Format quest count text (singular vs plural)
		local incompleteQuestText = incompleteQuestCount == 1 and L("TT_QUEST"):format(incompleteQuestCount) or L("TT_QUESTS"):format(incompleteQuestCount)
		
		-- Show "Incomplete Quest XP" with the details
		tooltip:AddDoubleLine(
			L("TT_QUEST_XP_INCOMPLETE"),
			string.format("%s (%.1f%%) - %s", self:FormatNumber(incompleteQuestXP), questPercent, incompleteQuestText),
			incompleteR, incompleteG, incompleteB,  -- Label: user color
			incompleteR, incompleteG, incompleteB   -- Value: same color
		)
	end
end

function XPC_XPBarTooltip:AddSessionSection(tooltip)
	local SessionService = Addon.App.Services and Addon.App.Services.SessionService
	if not SessionService then
		return
	end
	
	local session = SessionService:GetSession()
	if not session then
		return
	end
	
	local gainedXP = session.gainedXP or 0
	local sessionStart = session.sessionStart or time()
	local sessionTime = time() - sessionStart
	
	-- ITEM 2: Only show session stats if we have meaningful data
	-- Require at least 30 seconds of session time AND some XP gained
	if sessionTime < 30 or gainedXP < 100 then
		return
	end
	
	-- Check which stats are visible below the bar
	local db = Addon.db or {}
	local showXPPerHourBelow = db.showXPPerHourText == true
	local showTimeToLevelBelow = db.showTimeToLevelText == true
	local showLevelTimeBelow = db.showLevelTimeText == true
	local showSessionTimeBelow = db.showSessionTimeText == true
	
	-- Only show stats in tooltip if they're NOT already visible below the bar
	local hasTooltipStats = false
	
	-- XP/hour - show in tooltip if not visible below bar
	local xpPerHour = self:CalculateXPPerHour(gainedXP, sessionTime)
	if not showXPPerHourBelow and xpPerHour > 0 then
		if not hasTooltipStats then
			tooltip:AddLine(" ")  -- Blank line for section separation
			tooltip:AddLine(L("TT_SESSION_STATS"), 1.0, 0.82, 0.0)  -- Section header in gold
			hasTooltipStats = true
		end
		tooltip:AddDoubleLine(
			"  " .. L("TT_XP_PER_HOUR"),
			self:FormatNumber(xpPerHour),
			0.7, 0.7, 0.7,
			1.0, 0.82, 0.0  -- Gold for value
		)
	end
	
	-- Time to level - show in tooltip if not visible below bar
	local remainingXP = UnitXPMax("player") - UnitXP("player")
	local timeToLevel = self:CalculateTimeToLevel(remainingXP, xpPerHour)
	if not showTimeToLevelBelow and timeToLevel > 0 and xpPerHour > 0 then
		if not hasTooltipStats then
			tooltip:AddLine(" ")  -- Blank line for section separation
			tooltip:AddLine(L("TT_SESSION_STATS"), 1.0, 0.82, 0.0)  -- Section header in gold
			hasTooltipStats = true
		end
		tooltip:AddDoubleLine(
			"  " .. L("TT_TIME_TO_LEVEL"),
			self:FormatTime(timeToLevel),
			0.7, 0.7, 0.7,
			1.0, 0.82, 0.0  -- Gold for emphasis
		)
	end
	
	-- Session time - show in tooltip if not visible below bar
	if not showSessionTimeBelow then
		if not hasTooltipStats then
			tooltip:AddLine(" ")  -- Blank line for section separation
			tooltip:AddLine(L("TT_SESSION_STATS"), 1.0, 0.82, 0.0)  -- Section header in gold
			hasTooltipStats = true
		end
		tooltip:AddDoubleLine(
			"  " .. L("TT_SESSION_TIME"),
			self:FormatTime(sessionTime),
			0.7, 0.7, 0.7,
			1.0, 1.0, 1.0  -- White for value
		)
	end
	
	-- Level time - show in tooltip if not visible below bar
	local levelTime = session.realLevelTime or 0
	if not showLevelTimeBelow and levelTime > 0 then
		if not hasTooltipStats then
			tooltip:AddLine(" ")  -- Blank line for section separation
			tooltip:AddLine(L("TT_SESSION_STATS"), 1.0, 0.82, 0.0)  -- Section header in gold
			hasTooltipStats = true
		end
		tooltip:AddDoubleLine(
			"  " .. L("TT_LEVEL_TIME"),
			self:FormatTime(levelTime),
			0.7, 0.7, 0.7,
			1.0, 1.0, 1.0  -- White for value
		)
	end
end

function XPC_XPBarTooltip:AddHintSection(tooltip, frame)
    tooltip:AddLine(" ")  -- Extra spacing before hints
    tooltip:AddLine(XPC_XPBarTextFormatter:GetHintText(frame), 0.6, 0.6, 0.6, true)  -- Dimmer for subtlety
end

-----------------------------------
-- Main Functions
-----------------------------------

-- ITEM 10: Smart tooltip positioning to prevent screen clipping
function XPC_XPBarTooltip:GetBestAnchor(owner)
	if not owner then
		return "ANCHOR_TOP"  -- Default
	end
	
	-- Get screen height
	local screenHeight = GetScreenHeight() * UIParent:GetEffectiveScale()
	
	-- Get owner's top position
	local ownerTop = owner:GetTop()
	
	if not ownerTop then
		return "ANCHOR_TOP"  -- Default if position unknown
	end
	
	-- If bar is in top 20% of screen → show tooltip below to prevent clipping
	if ownerTop > (screenHeight * 0.8) then
		return "ANCHOR_BOTTOM"
	else
		return "ANCHOR_TOP"  -- Default: show above
	end
end

function XPC_XPBarTooltip:Show(owner, anchorPoint)
	if not owner then
		return
	end
	
	-- Track the owner for refresh support
	currentTooltipOwner = owner
	
	local tooltip = GameTooltip
	
	-- Use smart positioning if no anchor specified
	if not anchorPoint then
		anchorPoint = self:GetBestAnchor(owner)
	end
	
	tooltip:SetOwner(owner, anchorPoint, 0, 0)
	
	-- Add all sections
	self:AddXPSection(tooltip)
	self:AddRestedSection(tooltip)
	self:AddQuestSection(tooltip)
	self:AddSessionSection(tooltip)
	
	-- Always show hints at the end
	self:AddHintSection(tooltip, owner)
	
	tooltip:Show()
end

function XPC_XPBarTooltip:Hide()
	-- Clear the owner tracking when hiding
	currentTooltipOwner = nil
	GameTooltip:Hide()
end

-- Refresh the tooltip if it's currently showing
-- This is called when colors are changed via the color picker
function XPC_XPBarTooltip:Refresh()
	if currentTooltipOwner and GameTooltip:IsShown() and GameTooltip:GetOwner() == currentTooltipOwner then
		-- Re-show the tooltip with the updated colors
		self:Show(currentTooltipOwner)
	end
end
