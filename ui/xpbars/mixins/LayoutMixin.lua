-- XPBarEnhanced - XPBarLayoutMixin
-- Responsibilities: size, position, anchoring, visibility calculations for bars and overlays

---@class XPBarLayoutMixin
XPBarLayoutMixin = {}

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- MIXIN METADATA
-------------------------------------------------------------------

XPBarLayoutMixin.__metadata = {
	name = "XPBarLayoutMixin",
	version = "1.0.0",
	provides = {
		"UpdateBarLayout",
		"UpdateRestedOverlayLayout",
		"UpdateQuestCompleteOverlayLayout",
		"UpdateQuestIncompleteOverlayLayout",
		"UpdateExhaustionTickLayout",
		"CalculateBarRatio",
		"CalculateOverlayBounds",
		"CalculateRestedBounds",
		"ValidateBarWidth"
	}
}

-------------------------------------------------------------------
-- LAYOUT CALCULATION HELPERS
-------------------------------------------------------------------

--- Calculate XP bar fill ratio (0-1)
---@param currentXP number Current XP value
---@param maxXP number Maximum XP for level
---@return number ratio Fill ratio between 0 and 1
function XPBarLayoutMixin:CalculateBarRatio(currentXP, maxXP)
	if not maxXP or maxXP <= 0 then
		return 0
	end
	return math.min(1, math.max(0, (currentXP or 0) / maxXP))
end

--- Calculate overlay bounds (offset and width in pixels)
---@param startXP number Starting XP position
---@param overlayXP number Amount of XP the overlay represents
---@param maxXP number Maximum XP for level
---@param barWidth number Total bar width in pixels
---@return number offsetPixels Offset from left edge
---@return number widthPixels Width of overlay
function XPBarLayoutMixin:CalculateOverlayBounds(startXP, overlayXP, maxXP, barWidth)
	if not maxXP or maxXP <= 0 or not barWidth or barWidth <= 0 then
		return 0, 0
	end
	
	local startRatio = math.min(1, math.max(0, (startXP or 0) / maxXP))
	local overlayRatio = math.min(1, math.max(0, (overlayXP or 0) / maxXP))
	
	local offsetPixels = math.floor(startRatio * barWidth)
	local widthPixels = math.floor(overlayRatio * barWidth)
	
	return offsetPixels, widthPixels
end

--- Calculate rested overlay bounds accounting for quest overlays
---@param context table Context with XP values
---@param barWidth number Total bar width in pixels
---@return number offsetPixels Offset from left edge
---@return number widthPixels Width of rested overlay
---@return boolean visible Whether overlay should be shown
function XPBarLayoutMixin:CalculateRestedBounds(context, barWidth)
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local completeQuestXP = context.completeQuestXP or 0
	local isFullyRested = context.isFullyRested or false
	
	-- Calculate remaining XP to next level
	local remainingXP = math.max(0, maxXP - currentXP)
	
	-- Calculate offset after completed quest XP
	local questOffset = math.min(completeQuestXP, remainingXP)
	local offsetPixels = math.floor((questOffset / maxXP) * barWidth)
	
	-- Calculate remaining space after quest offset
	local remainingAfterQuest = remainingXP - questOffset
	local restedXPClamped = math.min(restedXP, remainingAfterQuest)
	
	-- Only show if has rested XP, not fully rested, and has space
	local visible = (restedXP > 0) and not isFullyRested and (restedXPClamped > 0)
	
	if not visible then
		return 0, 0, false
	end
	
	-- Calculate rested overlay width
	local restedRatio = restedXPClamped / maxXP
	local restedPixels = math.floor(restedRatio * barWidth)
	
	-- Ensure we don't exceed bar width
	if offsetPixels + restedPixels <= barWidth + 1 then
		return offsetPixels, math.max(1, restedPixels), true
	else
		local remainingWidth = math.max(0, barWidth - offsetPixels)
		if remainingWidth > 1 then
			return offsetPixels, remainingWidth, true
		else
			return 0, 0, false
		end
	end
end

--- Validate and get bar width from config or frame
---@param frame table The frame to check
---@return number barWidth Width in pixels
function XPBarLayoutMixin:ValidateBarWidth(frame)
	local barWidth = 565 -- default
	
	if frame.__xpbar_config and frame.__xpbar_config.style and frame.__xpbar_config.style.width then
		barWidth = frame.__xpbar_config.style.width
	elseif frame.StatusBar and frame.StatusBar.GetWidth then
		barWidth = frame.StatusBar:GetWidth() or barWidth
	end
	
	return barWidth
end

-------------------------------------------------------------------
-- BAR LAYOUT METHODS
-------------------------------------------------------------------

--- Update status bar layout (size/position, not color)
---@param context table Context with currentXP, xpMax
---@param barName string|nil StatusBar name (default: "StatusBar")
function XPBarLayoutMixin:UpdateBarLayout(context, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]
	
	if not bar then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateBarLayout: bar not found - " .. barName)
		end
		return
	end
	
	-- Calculate and set fill ratio
	local ratio = self:CalculateBarRatio(context.currentXP, context.xpMax)
	
	if bar.SetValue then
		bar:SetValue(ratio)
	end
end

-------------------------------------------------------------------
-- OVERLAY LAYOUT METHODS
-------------------------------------------------------------------

--- Update rested overlay position/size/visibility (not color)
---@param context table Context with restedXP, currentXP, xpMax
---@param overlayName string|nil Overlay name (default: "RestedOverlay")
function XPBarLayoutMixin:UpdateRestedOverlayLayout(context, overlayName)
	overlayName = overlayName or "RestedOverlay"
	local overlay = self[overlayName]
	
	if not overlay then
		return
	end
	
	-- Respect context-level toggle
	if context and context.showRestedOverlay == false then
		overlay:Hide()
		return
	end
	
	-- Calculate layout
	local barWidth = self:ValidateBarWidth(self)
	local offsetPixels, widthPixels, visible = self:CalculateRestedBounds(context, barWidth)
	
	overlay:SetShown(visible)
	
	if visible then
		overlay:ClearAllPoints()
		overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
		overlay:SetWidth(widthPixels)
	end
end

--- Update completed quest overlay position/size/visibility (not color)
---@param context table Context with completeQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function XPBarLayoutMixin:UpdateQuestCompleteOverlayLayout(context, overlayName)
	overlayName = overlayName or "QuestOverlayComplete"
	local overlay = self[overlayName]
	
	if not overlay then
		return
	end
	
	local completeXP = context.completeQuestXP or 0
	local showComplete = context.showCompleteQuestOverlay
	
	local visible = false
	if showComplete and (completeXP and completeXP > 0) then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)
		
		local questXPClamped = math.min(completeXP, remainingXP)
		local barWidth = self:ValidateBarWidth(self)
		
		local offsetPixels, widthPixels = self:CalculateOverlayBounds(currentXP, questXPClamped, maxXP, barWidth)
		
		overlay:ClearAllPoints()
		overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
		overlay:SetWidth(math.max(1, widthPixels))
		visible = true
	end
	
	overlay:SetShown(visible)
end

--- Update incomplete quest overlay position/size/visibility (not color)
---@param context table Context with incompleteQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayIncomplete")
function XPBarLayoutMixin:UpdateQuestIncompleteOverlayLayout(context, overlayName)
	overlayName = overlayName or "QuestOverlayIncomplete"
	local overlay = self[overlayName]
	
	if not overlay then
		return
	end
	
	local completeQuestXP = context.completeQuestXP or 0
	local incompleteQuestXP = context.incompleteQuestXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	
	-- Determine visibility setting (default to true if not explicitly disabled)
	local db = Addon and Addon.db or {}
	local showIncomplete
	if context and context.showIncompleteQuestOverlay ~= nil then
		showIncomplete = context.showIncompleteQuestOverlay
	else
		local config = self.__xpbar_config or {}
		if config.showIncompleteQuestOverlay ~= nil then
			showIncomplete = config.showIncompleteQuestOverlay == true
		else
			showIncomplete = (db.showIncompleteQuestOverlay ~= false)
		end
	end
	
	-- Account for complete quest overlay
	remainingXP = math.max(0, remainingXP - completeQuestXP)
	local questXPClamped = math.min(incompleteQuestXP, remainingXP)
	local ratio = questXPClamped / maxXP
	local visible = showIncomplete and incompleteQuestXP > 0 and ratio >= 0.01
	
	overlay:SetShown(visible)
	
	if visible then
		local barWidth = self:ValidateBarWidth(self)
		local startXP = currentXP + completeQuestXP
		local offsetPixels, widthPixels = self:CalculateOverlayBounds(startXP, questXPClamped, maxXP, barWidth)
		
		overlay:ClearAllPoints()
		overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
		overlay:SetWidth(math.max(1, widthPixels))
	end
end

--- Update exhaustion tick marker position/visibility (not color)
---@param context table Context with restedXP
---@param tickName string|nil Tick name (default: "ExhaustionTick")
function XPBarLayoutMixin:UpdateExhaustionTickLayout(context, tickName)
	tickName = tickName or "ExhaustionTick"
	local tick = self[tickName]
	
	if not tick then
		return
	end
	
	-- Respect context-level toggle
	if context and context.showExhaustionTick == false then
		tick:Hide()
		return
	end
	
	-- Calculate visibility
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	
	local restedXPClamped = math.min(restedXP, remainingXP)
	local restedRatio = restedXPClamped / maxXP
	
	-- Show tick when rested ratio is between 1% and 99%
	local visible = restedXP > 0 and restedRatio >= 0.01 and restedRatio <= 0.99
	tick:SetShown(visible)
	
	if visible then
		-- Position at the end of rested overlay
		local restedOverlay = self.RestedOverlay or self.RestedLevel or self.ExhaustionLevelFillBar
		if restedOverlay then
			tick:ClearAllPoints()
			tick:SetPoint("CENTER", restedOverlay, "RIGHT", 0, 0)
		end
	end
end

return XPBarLayoutMixin
