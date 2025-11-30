-- XPBarEnhanced - XPBarPaintMixin
-- Responsibilities: colors, textures, visual styling for bars and overlays

---@class XPBarPaintMixin
XPBarPaintMixin = {}

local Addon = XPBarEnhanced
local XPBarColors = _G.XPBarColors

-------------------------------------------------------------------
-- COLOR APPLICATION METHODS
-------------------------------------------------------------------

--- Update status bar color based on rested state
---@param context table Context with hasRestedXP or restedXP field
---@param barName string|nil StatusBar name (default: "StatusBar")
function XPBarPaintMixin:UpdateBarColors(context, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]

	if not bar then
		return
	end

	-- Select color based on whether player has rested XP (not just in resting area)
	-- Use hasRestedXP field if available, otherwise check restedXP > 0
	local hasRestedXP = context.hasRestedXP or (context.restedXP and context.restedXP > 0)
	local colorKey = hasRestedXP and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Update rested overlay color
---@param overlayName string|nil Overlay name (default: "RestedOverlay")
function XPBarPaintMixin:UpdateRestedBarColor(overlayName)
	overlayName = overlayName or "RestedOverlay"
	-- Try main frame first, then StatusBar (for flatbar compatibility)
	local overlay = self[overlayName] or (self.StatusBar and self.StatusBar[overlayName])

	if not overlay then
		return
	end

	local color = XPBarColors:GetUserColor(Color.Rested)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
end

--- Update completed quest overlay color
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function XPBarPaintMixin:UpdateQuestCompleteBarColor(overlayName)
	overlayName = overlayName or "QuestOverlayComplete"
	local overlay = self[overlayName]

	if not overlay then
		return
	end

	local color = XPBarColors:GetUserColor(Color.QuestComplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
end

--- Update incomplete quest overlay color
---@param overlayName string|nil Overlay name (default: "QuestOverlayIncomplete")
function XPBarPaintMixin:UpdateQuestIncompleteBarColor(overlayName)
	overlayName = overlayName or "QuestOverlayIncomplete"
	local overlay = self[overlayName]

	if not overlay then
		return
	end

	local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
end

-------------------------------------------------------------------
-- TEXTURE APPLICATION METHODS
-------------------------------------------------------------------

--- Apply texture to status bar
---@param texture string|nil Texture path or name
---@param barName string|nil StatusBar name (default: "StatusBar")
function XPBarPaintMixin:ApplyBarTexture(texture, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]

	if not bar or not bar.SetStatusBarTexture then
		return
	end

	if texture then
		bar:SetStatusBarTexture(texture)
	end
end

-------------------------------------------------------------------
-- VISUAL BUILD & STYLE METHODS
-------------------------------------------------------------------

--- Validate XML contract and initialize element state
--- BaseMixin does NOT create UI elements - it validates the XML contract
function XPBarPaintMixin:BuildVisuals()
	-- Alias overlays and text elements.
	-- Note: some styles (e.g., circular) do not use a StatusBar; they place
	-- on-bar text elements directly on the frame. Support both cases.

	-- Alias overlays expected as children of StatusBar when present
	if self.StatusBar then
		self.RestedOverlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
		self.QuestOverlayComplete = self.QuestOverlayComplete or (self.StatusBar and self.StatusBar.QuestOverlayComplete)
		self.QuestOverlayIncomplete =
		self.QuestOverlayIncomplete or (self.StatusBar and self.StatusBar.QuestOverlayIncomplete)
		self.ExhaustionTick = self.ExhaustionTick or (self.StatusBar and self.StatusBar.ExhaustionTick)
		self.GainFlash = self.GainFlash or (self.StatusBar and self.StatusBar.GainFlash)
	else
		-- Attempt to alias frame-level overlays if style put them on the frame
		self.RestedOverlay = self.RestedOverlay or self.RestedOverlay
		self.QuestOverlayComplete = self.QuestOverlayComplete or self.QuestOverlayComplete
		self.QuestOverlayIncomplete = self.QuestOverlayIncomplete or self.QuestOverlayIncomplete
		self.ExhaustionTick = self.ExhaustionTick or self.ExhaustionTick
		self.GainFlash = self.GainFlash or self.GainFlash
	end

	-- Alias ON-BAR text children. Prefer an explicit container; fall back to the frame
	local onBarTextContainer = self.OverlayFrameTextContainer or self
	if onBarTextContainer then
		if not self.XPText and onBarTextContainer.XPText then
			self.XPText = onBarTextContainer.XPText
		end
		if not self.PercentText and onBarTextContainer.PercentText then
			self.PercentText = onBarTextContainer.PercentText
		end
		if not self.LevelText and onBarTextContainer.LevelText then
			self.LevelText = onBarTextContainer.LevelText
		end
	end

	-- Alias BELOW-BAR text children (if style uses BelowBarTextContainer)
	if self.BelowBarTextContainer then
		if not self.RateText and self.BelowBarTextContainer.RateText then
			self.RateText = self.BelowBarTextContainer.RateText
		end
		if not self.SessionText and self.BelowBarTextContainer.SessionText then
			self.SessionText = self.BelowBarTextContainer.SessionText
		end
		if not self.QuestSummaryText and self.BelowBarTextContainer.QuestSummaryText then
			self.QuestSummaryText = self.BelowBarTextContainer.QuestSummaryText
		end
	end

	-- Apply text visibility from config (delegate to text mixin if available)
	if self.UpdateTextVisibility then
		local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
		self:UpdateTextVisibility(context)
	end

	--  Architecture: Initialize user colors immediately after XML elements are aliased
	-- This ensures user-configured colors override XML defaults
	self:InitializeColors()
end

--- Initialize all colors from user configuration
---  Architecture: Called once during BuildVisuals to override XML defaults
function XPBarPaintMixin:InitializeColors()
	if not XPBarColors then
		return
	end

	-- Initialize overlay colors (read from user config, not XML)
	if self.RestedOverlay then
		local color = XPBarColors:GetUserColor(Color.Rested)
		self.RestedOverlay:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	if self.QuestOverlayComplete then
		local color = XPBarColors:GetUserColor(Color.QuestComplete)
		self.QuestOverlayComplete:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	if self.QuestOverlayIncomplete then
		local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
		self.QuestOverlayIncomplete:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	-- Note: StatusBar color (XpBar/XpBarRested) is set dynamically in UpdateBarColors based on rested state
	-- We don't set it here because it changes based on context
end

--- Apply basic style configuration (size, texture, color)
---@param styleConfig table Style configuration
function XPBarPaintMixin:ApplyStyle(styleConfig)
	if not styleConfig then
		return
	end

	-- Apply a statusbar texture if provided
	if styleConfig.barTexture then
		self:ApplyBarTexture(styleConfig.barTexture)
	end
end

return XPBarPaintMixin
