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

	--  approach: Rested overlay BEHIND StatusBar, starts from 0
	-- Width = currentXP + questOverlays + restedXP, so the visible portion shows beyond filled bar and quests
	-- This way it animates automatically as currentXP changes

	-- Hide if no rested XP or fully rested (>= 150% threshold)
	if restedXP <= 0 or isFullyRested then
		return 0, 0, false
	end

	-- Get quest overlay visibility from context (single source of truth)
	local showQuestXP = context.showQuestXP
	local showComplete = context.showCompleteQuestOverlay
	local showIncomplete = context.showIncompleteQuestOverlay

	-- Calculate quest offset: how much space the quest overlays take up
	local questOffset = 0
	local completeQuestXP = context.completeQuestXP or 0
	local incompleteQuestXP = context.incompleteQuestXP or 0

	-- Add complete quest XP if that overlay is showing
	if showQuestXP and showComplete and completeQuestXP > 0 then
		local remainingXP = math.max(0, maxXP - currentXP)
		local completeQuestClamped = math.min(completeQuestXP, remainingXP)
		questOffset = questOffset + completeQuestClamped
	end

	-- Add incomplete quest XP if that overlay is showing
	if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
		local remainingXP = math.max(0, maxXP - currentXP - questOffset)
		local incompleteQuestClamped = math.min(incompleteQuestXP, remainingXP)
		questOffset = questOffset + incompleteQuestClamped
	end

	-- Calculate total width: current XP + quest overlays + rested XP
	-- This positions the rested overlay to extend beyond both current bar and quest overlays
	local totalXP = currentXP + questOffset + restedXP

	-- Clamp to max XP (can't show beyond 100%)
	local totalXPClamped = math.min(totalXP, maxXP)

	-- Calculate pixel width from 0 to (currentXP + questOffset + restedXP)
	local totalRatio = totalXPClamped / maxXP
	local totalPixels = math.floor(totalRatio * barWidth)

	-- Must be wider than current XP + quests to be visible
	local currentPlusQuestsXP = currentXP + questOffset
	local currentPlusQuestsRatio = currentPlusQuestsXP / maxXP
	local currentPlusQuestsPixels = math.floor(currentPlusQuestsRatio * barWidth)

	if totalPixels > currentPlusQuestsPixels then
		-- Start from 0 (BOTTOMLEFT anchor), width extends to currentXP + questOffset + restedXP
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
function XPBarLayoutMixin:UpdateRestedBarLayout(context, overlayName)
	overlayName = overlayName or "RestedOverlay"
	-- Try main frame first, then StatusBar (for flatbar compatibility)
	local overlay = self[overlayName] or (self.StatusBar and self.StatusBar[overlayName])

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
		-- : No offset needed, always starts from BOTTOMLEFT (0,0)
		-- Width = currentXP + questOffset + restedXP
		overlay:SetWidth(widthPixels)
	end
end

--- Update completed quest overlay position/size/visibility (not color)
---@param context table Context with completeQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function XPBarLayoutMixin:UpdateQuestCompleteBarLayout(context, overlayName)
	overlayName = overlayName or "QuestOverlayComplete"
	local overlay = self[overlayName]

	if not overlay then
		return
	end

	local completeXP = context.completeQuestXP or 0

	-- Get visibility flags from context (single source of truth)
	local showQuestXP = context.showQuestXP
	local showComplete = context.showCompleteQuestOverlay

	local visible = false
	if showQuestXP and showComplete and (completeXP and completeXP > 0) then
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
function XPBarLayoutMixin:UpdateQuestIncompleteBarLayout(context, overlayName)
	overlayName = overlayName or "QuestOverlayIncomplete"
	local overlay = self[overlayName]

	if not overlay then
		return
	end

	local completeQuestXP = context.completeQuestXP or 0
	local incompleteQuestXP = context.incompleteQuestXP or 0

	-- Get visibility flags from context (single source of truth)
	local showQuestXP = context.showQuestXP
	local showComplete = context.showCompleteQuestOverlay
	local showIncomplete = context.showIncompleteQuestOverlay

	local visible = false
	if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)

		-- Only subtract complete quest XP if that overlay is actually showing
		if showQuestXP and showComplete and completeQuestXP > 0 then
			remainingXP = math.max(0, remainingXP - completeQuestXP)
		end

		local questXPClamped = math.min(incompleteQuestXP, remainingXP)
		local ratio = questXPClamped / maxXP

		if ratio >= 0.01 then
			local barWidth = self:ValidateBarWidth(self)

			-- Calculate start position: current XP + complete quest XP (only if complete overlay showing)
			local startXP = currentXP
			if showQuestXP and showComplete and completeQuestXP > 0 then
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
	-- Try main frame first, then StatusBar (for classic compatibility)
	local tick = self[tickName] or (self.StatusBar and self.StatusBar[tickName])

	if not tick then
		return
	end

	-- Respect context-level toggle
	if context and (context.showExhaustionTick == false or context.showRestedOverlay == false) then
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
		-- Try multiple locations: main frame, StatusBar, or classic names
		local restedOverlay =
			self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay) or self.RestedLevel or
			self.ExhaustionLevelFillBar or
			(self.StatusBar and self.StatusBar.ExhaustionLevelFillBar)

		if restedOverlay then
			-- Preserve any offsets set by XML anchors (e.g., y-offset) so designer tweaks aren't lost
			local origPoint, origRelTo, origRelPoint, origX, origY = tick:GetPoint(1)
			local xOff = origX or 0
			local yOff = origY or 0
			tick:ClearAllPoints()
			tick:SetPoint("CENTER", restedOverlay, "RIGHT", xOff, yOff)
		end
	end
end

return XPBarLayoutMixin
