-- XPBarEnhanced - XPBarLayoutMixin
-- Responsibilities: size, position, anchoring, visibility calculations for bars and overlays

---@class XPBarLayoutMixin
XPBarLayoutMixin = {}

local Addon = XPBarEnhanced

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
	local isFullyRested = context.isFullyRested or false
	
	-- V2 approach: Rested overlay BEHIND StatusBar, starts from 0
	-- Width = currentXP + restedXP, so the visible portion shows beyond filled bar
	-- This way it animates automatically as currentXP changes
	
	-- Hide if no rested XP or fully rested (>= 150% threshold)
	if restedXP <= 0 or isFullyRested then
		return 0, 0, false
	end
	
	-- Calculate total width: current XP + rested XP
	-- This positions the rested overlay to extend beyond the current filled bar
	local totalXP = currentXP + restedXP
	
	-- Clamp to max XP (can't show beyond 100%)
	local totalXPClamped = math.min(totalXP, maxXP)
	
	-- Calculate pixel width from 0 to (currentXP + restedXP)
	local totalRatio = totalXPClamped / maxXP
	local totalPixels = math.floor(totalRatio * barWidth)
	
	-- Must be wider than current XP to be visible
	local currentRatio = currentXP / maxXP
	local currentPixels = math.floor(currentRatio * barWidth)
	
	if totalPixels > currentPixels then
		-- Start from 0 (BOTTOMLEFT anchor), width extends to currentXP + restedXP
		return 0, math.max(1, totalPixels), true
	else
		return 0, 0, false
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
	
	-- Calculate layout (returns offset=0, width=total, visible)
	local barWidth = self:ValidateBarWidth(self)
	local offsetPixels, widthPixels, visible = self:CalculateRestedBounds(context, barWidth)
	
	overlay:SetShown(visible)
	
	if visible then
		-- V2: No offset needed, always starts from BOTTOMLEFT (0,0)
		-- Width = currentXP + restedXP
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
	
	local showComplete = Addon.ConfigHelper.GetShowCompleteQuestOverlay(context)
	
	local visible = false
	if showComplete and (completeXP and completeXP > 0) then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)
		local questXPClamped = math.min(completeXP, remainingXP)
		local ratio = questXPClamped / maxXP
		
		if ratio >= 0.01 then
			local barWidth = self:ValidateBarWidth(self)
			local offsetPixels, widthPixels = self:CalculateOverlayBounds(currentXP, questXPClamped, maxXP, barWidth)
			overlay:ClearAllPoints()
			overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
			overlay:SetWidth(math.max(1, widthPixels))
			visible = true
		end
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
	
	local showIncomplete = Addon.ConfigHelper.GetShowIncompleteQuestOverlay(context)
	
	local visible = false
	if showIncomplete and incompleteQuestXP > 0 then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)
		
		-- Only subtract complete quest XP if that overlay is actually showing
		if context.showCompleteQuestOverlay and completeQuestXP > 0 then
			remainingXP = math.max(0, remainingXP - completeQuestXP)
		end
		
		local questXPClamped = math.min(incompleteQuestXP, remainingXP)
		local ratio = questXPClamped / maxXP
		
		if ratio >= 0.01 then
			local barWidth = self:ValidateBarWidth(self)
			
			-- Calculate start position: current XP + complete quest XP (only if complete overlay showing)
			local startXP = currentXP
			if context.showCompleteQuestOverlay and completeQuestXP > 0 then
				startXP = startXP + completeQuestXP
			end
			
			local offsetPixels, widthPixels = self:CalculateOverlayBounds(startXP, questXPClamped, maxXP, barWidth)
			overlay:ClearAllPoints()
			overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
			overlay:SetWidth(math.max(1, widthPixels))
			visible = true
		end
	end
	
	overlay:SetShown(visible)
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
