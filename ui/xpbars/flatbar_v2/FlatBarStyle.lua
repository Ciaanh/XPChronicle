-- XP Bar Enhanced - FlatBar Style v2
-- Minimal style file: XML owns visual creation via contract.
-- Only provides config and registration. No overrides needed for standard flat layout.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase_v2 then
	error(
		"FlatBarStyle: v2 core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
	)
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Minimal style template: don't duplicate aliasing; rely on BaseMixin
local FlatBarStyleTemplate = {}

-------------------------------------------------------------------
-- V2 ANIMATION IMPLEMENTATION (StatusBar-based)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param stepContext table: Step context with currentRatio
-- Note: Rested overlay animates automatically because it's positioned BEHIND the StatusBar
--       with width = currentXP + restedXP (set once at animation start). As the StatusBar
--       fill animates from old to new currentXP, it progressively reveals/covers the rested
--       overlay beneath it, creating smooth animation without any per-frame updates.
function FlatBarStyleTemplate:AnimateBarPosition(stepContext)
	if self.StatusBar then
		self.StatusBar:SetValue(stepContext.currentRatio)
	end
end

--- Update visual effects - flash overlay animation
-- @param stepContext table: Step context with flashData
function FlatBarStyleTemplate:AnimateBarEffect(stepContext)
	if not self.GainFlash then
		return
	end

	local flashData = stepContext.flashData
	if flashData and flashData.active and flashData.currentAlpha > 0 then
		-- Get user-defined color based on rested state (matches V1 behavior)
		-- Use Rested color if player had rested XP available (meaning the gain consumed rested bonus)
		local XPBarColors = _G.XPBarColors
		local hasRestedXP = stepContext.xpContext and stepContext.xpContext.hasRestedXP
		local colorKey = hasRestedXP and Color.Rested or Color.XpBar
		local color = XPBarColors:GetUserColor(colorKey)

		-- Show flash with user color and animated alpha (fades to 0)
		self.GainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
		self.GainFlash:Show()
	else
		-- Hide flash when not active, complete, or alpha is 0
		self.GainFlash:Hide()
	end
	
	-- Apply quest overlay alpha reduction during flash
	if stepContext.questOverlayAlpha then
		if self.QuestOverlayComplete and stepContext.questOverlayCompleteInitialAlpha then
			local newAlpha = stepContext.questOverlayCompleteInitialAlpha * stepContext.questOverlayAlpha
			self.QuestOverlayComplete:SetAlpha(newAlpha)
		end
		
		if self.QuestOverlayIncomplete and stepContext.questOverlayIncompleteInitialAlpha then
			local newAlpha = stepContext.questOverlayIncompleteInitialAlpha * stepContext.questOverlayAlpha
			self.QuestOverlayIncomplete:SetAlpha(newAlpha)
		end
	end
end

--- Get animation configuration from database
-- @return table: Animation config { enableAnimations, flashOnGain }
function FlatBarStyleTemplate:GetAnimationConfig()
	-- First check for frame-specific config
	local frameConfig = self.__xpbar_config
	if frameConfig and frameConfig.animation then
		local anim = frameConfig.animation
		return {
			enableAnimations = anim.enableAnimations ~= false, -- Default true
			flashOnGain = anim.flashOnGain ~= false -- Default true
		}
	end

	-- Fall back to global database
	local Addon = XPBarEnhanced
	local db = Addon and Addon.Database and Addon.Database:GetDB()

	if db then
		return {
			enableAnimations = db.enableAnimations ~= false, -- Default true
			flashOnGain = db.flashOnGain ~= false -- Default true
		}
	end

	-- Fallback default config
	return {
		enableAnimations = true,
		flashOnGain = true
	}
end

-------------------------------------------------------------------
-- OVERRIDE: Bar Update with V2 Animation
-------------------------------------------------------------------

--- Update bar with animation (overrides VisualsMixin)
-- @param context table: Immutable XP context
function FlatBarStyleTemplate:UpdateCurrentXPBar(context)
	if not context then
		error("UpdateCurrentXPBar requires an explicit immutable context")
	end

	-- Calculate target ratio
	local targetRatio = 0
	if context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end

	-- Initialize current ratio if not set (TRULY first update, not just currentRatio == 0)
	if not self._initializedBar then
		self._initializedBar = true

		-- Get current StatusBar value as starting point
		if self.StatusBar then
			local currentValue = self.StatusBar:GetValue()
			if currentValue and currentValue > 0 and self.SetCurrentRatio then
				self:SetCurrentRatio(currentValue)
			end
		end
	end

	-- Build XP context for animation system
	local xpContext = {
		xpBefore = context.xpBefore or context.previousXP or 0,
		xpAfter = context.xpAfter or context.currentXP or 0,
		xpMax = context.xpMax or 1,
		xpGained = context.xpGained or 0,
		restedXP = context.restedXP or 0,
		isResting = context.isResting or false,
		hasRestedXP = context.hasRestedXP or false,
		level = context.level or 1,
		timestamp = GetTime()
	}

	-- Get animation config
	local config = self:GetAnimationConfig()

	-- Start animation (delegates to AnimationManager via AnimationBase)
	if self.StartAnimation then
		self:StartAnimation(targetRatio, xpContext, config)
	else
		-- Fallback: instant update if animation system not available
		if self.StatusBar then
			self.StatusBar:SetValue(targetRatio)
		end
		-- Update tracked ratio
		if self.SetCurrentRatio then
			self:SetCurrentRatio(targetRatio)
		end
	end

	-- Update bar colors (non-animated visuals)
	if self.UpdateBarColors then
		self:UpdateBarColors(context)
	end
end
-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
	interaction = {enabled = true},
	tooltip = {enabled = true},
	position = {mode = "DRAGGABLE", positionKey = "FlatBar_v2"},
	style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, FlatBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("flat", FlatBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create FlatBar frame programmatically.
function XPBarEnhanced_CreateFlatBarFrame()
	local styleKey = "flat"

	local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "FlatBarTemplate_v2")
	frame:Show()

	_G.FlatBar_v2 = frame -- Global reference

	return frame
end
