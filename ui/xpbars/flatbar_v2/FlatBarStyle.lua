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
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
-- Note: Rested overlay animates automatically because it's positioned BEHIND the StatusBar
--       with width = currentXP + restedXP (set once at animation start). As the StatusBar
--       fill animates from old to new currentXP, it progressively reveals/covers the rested
--       overlay beneath it, creating smooth animation without any per-frame updates.
function FlatBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
	if self.StatusBar then
		self.StatusBar:SetValue(iterationData.currentRatio)
	end
end

--- Update visual effects - flash overlay animation
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function FlatBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
	if not self.GainFlash then
		return
	end

	local flashData = iterationData.flashData
	if flashData and flashData.active and flashData.currentAlpha > 0 then
		-- Get user-defined color based on rested state (matches V1 behavior)
		-- Use Rested color if player had rested XP available (meaning the gain consumed rested bonus)
		local XPBarColors = _G.XPBarColors
		local hasRestedXP = eventContext and eventContext.hasRestedXP
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
	if iterationData.questOverlayAlpha then
		if self.QuestOverlayComplete and iterationData.questOverlayCompleteInitialAlpha then
			local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
			self.QuestOverlayComplete:SetAlpha(newAlpha)
		end
		
		if self.QuestOverlayIncomplete and iterationData.questOverlayIncompleteInitialAlpha then
			local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
			self.QuestOverlayIncomplete:SetAlpha(newAlpha)
		end
	end
end

-------------------------------------------------------------------
-- V2 UNIFIED RENDER PATTERN (Phase 2: Refactor)
-------------------------------------------------------------------

--- Single render method for flat bar (NEW unified pattern)
--- Handles layout, colors, animation, and text in one pass
---@param context table Immutable context with all state and flags
function FlatBarStyleTemplate:RenderBar(context)
	if not context then
		error("RenderBar requires an explicit immutable context")
	end

	-- Calculate target ratio
	local targetRatio = 0
	if context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end

	-- Initialize current ratio if not set (first update after creation)
	if not self._initializedBar then
		self._initializedBar = true
		if self.StatusBar then
			local currentValue = self.StatusBar:GetValue()
			if currentValue and currentValue > 0 and self.SetCurrentRatio then
				self:SetCurrentRatio(currentValue)
			end
		end
	end

	-- ANIMATION DECISION (use context flags)
	if context.shouldAnimate then
		-- Start animation - AnimationManager will call RenderBarFrame on each tick
		-- Note: We don't have RenderBarFrame integrated with AnimationManager yet,
		-- so animation still uses old AnimateBarPosition/AnimateBarEffect pattern
		-- This is a transitional implementation
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
		local config = self:GetAnimationConfig()
		self:StartAnimation(targetRatio, xpContext, config)
	else
		-- Instant update - render all elements at final position
		self:RenderBarFrame(targetRatio, context)
	end

	-- Update overlays (always update, even during animation)
	-- TODO: In future, move these into RenderBarFrame so they animate
	if self.UpdateRestedOverlay then
		self:UpdateRestedOverlay(context)
	end
	if self.UpdateQuestCompleteOverlay then
		self:UpdateQuestCompleteOverlay(context)
	end
	if self.UpdateQuestIncompleteOverlay then
		self:UpdateQuestIncompleteOverlay(context)
	end
	if self.UpdateExhaustionTick then
		self:UpdateExhaustionTick(context)
	end

	-- Update text
	if self.UpdateTexts then
		self:UpdateTexts(context)
	end
end

--- Render all bar elements for a single animation frame
--- Called once for instant updates (animation will be integrated later)
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function FlatBarStyleTemplate:RenderBarFrame(currentRatio, context)
	-- 1. MAIN BAR (at current animation position)
	if self.StatusBar then
		self.StatusBar:SetValue(currentRatio)
	end

	-- Update tracked ratio
	if self.SetCurrentRatio then
		self:SetCurrentRatio(currentRatio)
	end

	-- 2. BAR COLORS (apply based on rested state)
	if self.UpdateBarColors then
		self:UpdateBarColors(context)
	end

	-- Note: Overlays and text are currently updated outside this method
	-- TODO Phase 3: Integrate overlay rendering here so they animate every frame
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
