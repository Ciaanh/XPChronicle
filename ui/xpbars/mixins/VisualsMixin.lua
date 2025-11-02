-- XPBarEnhanced - XPBarVisualsMixin
-- Responsibilities: status bar updates, overlays, exhaustion tick, flash, overlay aggregation, bar size/color handling

---@class XPBarVisualsMixin
XPBarVisualsMixin = {}

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- BAR UPDATE METHODS
-------------------------------------------------------------------

--- Update current XP bar from context
---@param context table Context with currentXP, xpMax
---@param barName string|nil StatusBar name (default: "StatusBar")
function XPBarVisualsMixin:UpdateCurrentXPBar(context, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]

	if not bar then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateCurrentXPBar: bar not found - " .. barName)
		end
		return
	end

	-- Calculate ratio (0-1)
	local ratio = 0
	if context.xpMax and context.xpMax > 0 then
		ratio = (context.currentXP or 0) / context.xpMax
	end

	-- Update value (expect a ratio between 0 and 1)
	if self.StatusBar then
		self.StatusBar:SetValue(ratio)
	end

	-- Update color based on rested state
	local colorKey = context.isRested and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Default implementation: update StatusBar values/colors.
-- Styles may override to provide custom bar rendering (e.g. circular).
---@param context table Immutable context (required)
function XPBarVisualsMixin:UpdateBars(context)
	if not context then
		error("UpdateBars requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local ratio = (context.currentXP and maxv > 0) and (context.currentXP / maxv) or 0

	-- Prefer style-specific updater when provided. Some styles override
	-- UpdateCurrentXPBar to handle complex rendering (circular, animated, etc.).
	if self.UpdateCurrentXPBar then
		self:UpdateCurrentXPBar(context)
		return
	end

	if self.StatusBar then
		self.StatusBar:SetValue(ratio)
	end
end

-------------------------------------------------------------------
-- OVERLAY UPDATE METHODS
-------------------------------------------------------------------

--- Update rested overlay position/size/visibility
---@param context table Context with restedXP, currentXP, xpMax
---@param overlayName string|nil Overlay name (default: "RestedOverlay")
function XPBarVisualsMixin:UpdateRestedOverlay(context, overlayName)
	overlayName = overlayName or "RestedOverlay"
	local overlay = self[overlayName]

	if not overlay then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateRestedOverlay: overlay not found - " .. overlayName)
		end
		return
	end

	-- Respect context-level toggle when provided (fallbacks preserved)
	if context and context.showRestedOverlay == false then
		overlay:Hide()
		return
	end

	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.Rested)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)

	-- Calculate visibility and positioning
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local completeQuestXP = context.completeQuestXP or 0
	local remainingXP = math.max(0, maxXP - currentXP)
	local isFullyRested = context.isFullyRested or false

	-- Calculate offset after completed quest XP (matching current implementation)
	local questOffset = math.min(completeQuestXP, remainingXP)
	local barWidth = self.__xpbar_config.style and self.__xpbar_config.style.width or 565
	local offsetPixels = math.floor((questOffset / maxXP) * barWidth)

	-- Calculate remaining space after offset
	local remainingAfterQuest = remainingXP - questOffset

	-- Only show if:
	-- 1. Has rested XP
	-- 2. Not fully rested
	-- 3. Rested XP + completed quest doesn't exceed remaining XP
	local restedXPClamped = math.min(restedXP, remainingAfterQuest)
	local visible = (restedXP > 0) and not isFullyRested and (restedXPClamped > 0)

	overlay:SetShown(visible)

	if visible then
		-- Calculate rested overlay width
		local restedRatio = restedXPClamped / maxXP
		local restedPixels = math.floor(restedRatio * barWidth)

		-- Ensure we don't exceed bar width
		if offsetPixels + restedPixels <= barWidth + 1 then
			overlay:ClearAllPoints()
			overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
			overlay:SetWidth(math.max(1, restedPixels))
		else
			local remainingWidth = math.max(0, barWidth - offsetPixels)
			if remainingWidth > 1 then
				overlay:ClearAllPoints()
				overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
				overlay:SetWidth(remainingWidth)
			else
				overlay:Hide()
			end
		end
	end
end

--- Update completed quest overlay
---@param context table Context with completeQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function XPBarVisualsMixin:UpdateQuestCompleteOverlay(context, overlayName)
	overlayName = overlayName or "QuestOverlayComplete"
	local overlay = self[overlayName]

	if not overlay then
		-- Quest overlays are optional, don't warn
		return
	end

	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.QuestComplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)

	-- Calculate visibility
	local completeXP = context.completeQuestXP or 0
	local db = Addon.db or {}
	local showComplete = context.showCompleteQuestOverlay

	local visible = false
	if showComplete and (completeXP and completeXP > 0) then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)

		-- Default behavior: show complete quest overlay unless disabled in either per-frame config or global settings
		local questXPClamped = math.min(completeXP, remainingXP)
		local ratio = questXPClamped / maxXP

		-- Position after current XP
		local barWidth = self.StatusBar:GetWidth()

		local currentRatio = currentXP / maxXP
		local currentPixels = math.floor(currentRatio * barWidth)
		local questPixels = math.floor(ratio * barWidth)

		overlay:SetPoint("BOTTOMLEFT", currentPixels, 0)
		overlay:SetWidth(math.max(1, questPixels))
		visible = true
	else
		visible = false
	end

	overlay:SetShown(visible)
end

--- Update incomplete quest overlay
---@param context table Context with incompleteQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayIncomplete")
function XPBarVisualsMixin:UpdateQuestIncompleteOverlay(context, overlayName)
	overlayName = overlayName or "QuestOverlayIncomplete"
	local overlay = self[overlayName]

	if not overlay then
		-- Quest overlays are optional, don't warn
		return
	end

	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)

	-- Calculate visibility
	local completeQuestXP = context.completeQuestXP or 0
	local incompleteQuestXP = context.incompleteQuestXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)

	-- Determine whether to show incomplete quest overlay. Prefer context flag, then per-frame config, then global setting
	local db = Addon and Addon.db or {}
	local showIncomplete
	if context and context.showIncompleteQuestOverlay ~= nil then
		showIncomplete = context.showIncompleteQuestOverlay
	else
		local config = self.__xpbar_config or {}
		if config.showIncompleteQuestOverlay ~= nil then
			showIncomplete = config.showIncompleteQuestOverlay == true
		else
			showIncomplete = (db.showIncompleteQuestOverlay == true)
		end
	end

	-- Account for complete quest overlay
	remainingXP = math.max(0, remainingXP - completeQuestXP)
	local questXPClamped = math.min(incompleteQuestXP, remainingXP)
	local ratio = questXPClamped / maxXP
	local visible = showIncomplete and incompleteQuestXP > 0 and ratio >= 0.01

	overlay:SetShown(visible)

	if visible then
		-- Position after current XP + complete quest overlay
		local barWidth = 565
		local currentRatio = currentXP / maxXP
		local completeRatio = completeQuestXP / maxXP
		local startPixels = math.floor((currentRatio + completeRatio) * barWidth)
		local questPixels = math.floor(ratio * barWidth)

		overlay:SetPoint("BOTTOMLEFT", startPixels, 0)
		overlay:SetWidth(math.max(1, questPixels))
	end
end

--- Update exhaustion tick marker position/visibility
---@param context table Context with restedXP
---@param tickName string|nil Tick name (default: "ExhaustionTick")
function XPBarVisualsMixin:UpdateExhaustionTick(context, tickName)
	tickName = tickName or "ExhaustionTick"
	local tick = self[tickName]

	if not tick then
		-- Exhaustion tick is optional, don't warn
		return
	end

	-- Respect context-level toggle when provided
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
			tick:SetPoint("CENTER", restedOverlay, "RIGHT", 0, 0)
		end
	end
end

--- Update flash overlay (optional)
---@param context table Context object
---@param flashName string|nil Flash overlay name (default: "GainFlash")
function XPBarVisualsMixin:UpdateFlashOverlay(context, flashName)
	flashName = flashName or "GainFlash"
	local flash = self[flashName]

	if not flash then
		-- Flash overlay is optional, don't warn
		return
	end

	-- Flash update is typically handled by animation mixin
	-- This method exists for style override if needed
end

--- Default overlay aggregation; calls specific overlay updaters.
-- Styles can override UpdateRestedOverlay, UpdateQuestCompleteOverlay, etc.
---@param context table|nil
function XPBarVisualsMixin:UpdateOverlays(context)
	-- require explicit context; fallback builds minimal snapshot from current state
	local ctx = context
	if not ctx then
	end

	-- Call overlay update hooks (they handle missing overlays internally)
	if self.UpdateRestedOverlay then
		self:UpdateRestedOverlay(ctx)
	end
	if self.UpdateQuestCompleteOverlay then
		self:UpdateQuestCompleteOverlay(ctx)
	end
	if self.UpdateQuestIncompleteOverlay then
		self:UpdateQuestIncompleteOverlay(ctx)
	end
	if self.UpdateExhaustionTick then
		self:UpdateExhaustionTick(ctx)
	end
end

-------------------------------------------------------------------
-- VISUAL BUILD & STYLE METHODS
-------------------------------------------------------------------

--- Validate XML contract and initialize element state.
--- BaseMixin does NOT create UI elements - it validates the XML contract.
--- Styles must override if they need to create elements programmatically.
function XPBarVisualsMixin:BuildVisuals()
	-- Require StatusBar (XML contract)
	if not self.StatusBar then
		if Addon and Addon.Logger then
			Addon.Logger:Error("BuildVisuals: StatusBar missing from XML for " .. (self:GetName() or "<unnamed>"))
		end
		return
	end

	-- Alias overlays that are expected as children of StatusBar.
	-- Do NOT create UI elements here; XML must provide them.
	self.RestedOverlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
	self.QuestOverlayComplete = self.QuestOverlayComplete or (self.StatusBar and self.StatusBar.QuestOverlayComplete)
	self.QuestOverlayIncomplete = self.QuestOverlayIncomplete or (self.StatusBar and self.StatusBar.QuestOverlayIncomplete)
	self.ExhaustionTick = self.ExhaustionTick or (self.StatusBar and self.StatusBar.ExhaustionTick)
	self.GainFlash = self.GainFlash or (self.StatusBar and self.StatusBar.GainFlash)

	-- Alias overlay frame text children (if style uses a TextContainer)
	if not self.XPText and self.TextContainer and self.TextContainer.XPText then
		self.XPText = self.TextContainer.XPText
	end
	if not self.PercentText and self.TextContainer and self.TextContainer.PercentText then
		self.PercentText = self.TextContainer.PercentText
	end
	if not self.LevelText and self.TextContainer and self.TextContainer.LevelText then
		self.LevelText = self.TextContainer.LevelText
	end

	-- Log missing optional overlays (development-time visibility)
	if Addon and Addon.Logger then
		if not self.RestedOverlay then
			Addon.Logger:Debug("BuildVisuals: RestedOverlay missing (expected as StatusBar child)")
		end
		if not self.QuestOverlayComplete then
			Addon.Logger:Debug("BuildVisuals: QuestOverlayComplete missing (expected as StatusBar child)")
		end
		if not self.QuestOverlayIncomplete then
			Addon.Logger:Debug("BuildVisuals: QuestOverlayIncomplete missing (expected as StatusBar child)")
		end
		if not self.ExhaustionTick then
			Addon.Logger:Debug("BuildVisuals: ExhaustionTick missing (expected as StatusBar child)")
		end
		if not self.GainFlash then
			Addon.Logger:Debug("BuildVisuals: GainFlash missing (expected as StatusBar child)")
		end
		if not self.XPText then
			Addon.Logger:Debug("BuildVisuals: XPText missing (expected in TextContainer)")
		end
		if not self.PercentText then
			Addon.Logger:Debug("BuildVisuals: PercentText missing (expected in TextContainer)")
		end
		if not self.LevelText then
			Addon.Logger:Debug("BuildVisuals: LevelText missing (expected in TextContainer)")
		end
	end

	-- Apply text visibility from config (delegate to text mixin if available)
	if self.UpdateTextVisibility then
		self:UpdateTextVisibility(nil)
	end
end

--- Apply basic style configuration (size, basic bar texture/color)
---@param styleConfig table
function XPBarVisualsMixin:ApplyStyle(styleConfig)
	if not styleConfig then
		return
	end

	-- Apply size to main frame and StatusBar if provided
	if styleConfig.width and styleConfig.height then
		self:SetSize(styleConfig.width, styleConfig.height)
		if self.StatusBar then
			self.StatusBar:SetSize(styleConfig.width, styleConfig.height)
		end
	end

	-- Apply a statusbar texture if provided
	if styleConfig.barTexture and self.StatusBar and self.StatusBar.SetStatusBarTexture then
		self.StatusBar:SetStatusBarTexture(styleConfig.barTexture)
	end

	-- Other style params are left for the style mixin to handle (borders, corner radius, fonts)
	if Addon and Addon.Logger then
		Addon.Logger:Debug("ApplyStyle applied basic style for " .. (self:GetName() or "<unnamed>"))
	end
end

return XPBarVisualsMixin
