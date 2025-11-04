-- XPBarEnhanced - XPBarPaintMixin
-- Responsibilities: colors, textures, visual styling for bars and overlays

---@class XPBarPaintMixin
XPBarPaintMixin = {}

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- MIXIN METADATA
-------------------------------------------------------------------

XPBarPaintMixin.__metadata = {
	name = "XPBarPaintMixin",
	version = "1.0.0",
	provides = {
		"UpdateBarColors",
		"UpdateRestedOverlayColor",
		"UpdateQuestCompleteOverlayColor",
		"UpdateQuestIncompleteOverlayColor",
		"ApplyBarTexture",
		"BuildVisuals",
		"ApplyStyle"
	}
}

-------------------------------------------------------------------
-- COLOR APPLICATION METHODS
-------------------------------------------------------------------

--- Update status bar color based on rested state
---@param context table Context with isRested flag
---@param barName string|nil StatusBar name (default: "StatusBar")
function XPBarPaintMixin:UpdateBarColors(context, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]
	
	if not bar then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateBarColors: bar not found - " .. barName)
		end
		return
	end
	
	-- Select color based on rested state
	local colorKey = context.isRested and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Update rested overlay color
---@param overlayName string|nil Overlay name (default: "RestedOverlay")
function XPBarPaintMixin:UpdateRestedOverlayColor(overlayName)
	overlayName = overlayName or "RestedOverlay"
	local overlay = self[overlayName]
	
	if not overlay then
		return
	end
	
	local color = XPBarColors:GetUserColor(Color.Rested)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
end

--- Update completed quest overlay color
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function XPBarPaintMixin:UpdateQuestCompleteOverlayColor(overlayName)
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
function XPBarPaintMixin:UpdateQuestIncompleteOverlayColor(overlayName)
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
	-- Require StatusBar (XML contract)
	if not self.StatusBar then
		if Addon and Addon.Logger then
			Addon.Logger:Error("BuildVisuals: StatusBar missing from XML for " .. (self:GetName() or "<unnamed>"))
		end
		return
	end
	
	-- Alias overlays expected as children of StatusBar
	self.RestedOverlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
	self.QuestOverlayComplete = self.QuestOverlayComplete or (self.StatusBar and self.StatusBar.QuestOverlayComplete)
	self.QuestOverlayIncomplete = self.QuestOverlayIncomplete or (self.StatusBar and self.StatusBar.QuestOverlayIncomplete)
	self.ExhaustionTick = self.ExhaustionTick or (self.StatusBar and self.StatusBar.ExhaustionTick)
	self.GainFlash = self.GainFlash or (self.StatusBar and self.StatusBar.GainFlash)
	
	-- Alias ON-BAR text children
	local onBarTextContainer = self.OverlayFrameTextContainer
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
	
	-- Log missing optional overlays (development visibility)
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
		if not self.RateText then
			Addon.Logger:Debug("BuildVisuals: RateText missing (expected in BelowBarTextContainer)")
		end
		if not self.SessionText then
			Addon.Logger:Debug("BuildVisuals: SessionText missing (expected in BelowBarTextContainer)")
		end
		if not self.QuestSummaryText then
			Addon.Logger:Debug("BuildVisuals: QuestSummaryText missing (expected in BelowBarTextContainer)")
		end
	end
	
	-- Apply text visibility from config (delegate to text mixin if available)
	if self.UpdateTextVisibility then
		self:UpdateTextVisibility(nil)
	end
end

--- Apply basic style configuration (size, texture, color)
---@param styleConfig table Style configuration
function XPBarPaintMixin:ApplyStyle(styleConfig)
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
	if styleConfig.barTexture then
		self:ApplyBarTexture(styleConfig.barTexture)
	end
	
	-- Other style params left for style-specific mixins (borders, corner radius, fonts)
	if Addon and Addon.Logger then
		Addon.Logger:Debug("ApplyStyle applied basic style for " .. (self:GetName() or "<unnamed>"))
	end
end

return XPBarPaintMixin
