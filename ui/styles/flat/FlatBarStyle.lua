-- XP Bar Enhanced - FlatBar Style
-- Minimal style file: XML owns visual creation via contract.
-- Only provides config and registration. No overrides needed for standard flat layout.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
	error("FlatBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc.")
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Minimal style template: don't duplicate aliasing; rely on BaseMixin
local FlatBarStyleTemplate = {}

-------------------------------------------------------------------
--  ANIMATION IMPLEMENTATION (StatusBar-based)
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
--  UNIFIED RENDER PATTERN (Phase 2: Refactor)
-------------------------------------------------------------------

--- Single render method for flat bar ( unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function FlatBarStyleTemplate:RenderBar(context)
	if not context then
		error("RenderBar requires an explicit immutable context")
	end

	-- Calculate target ratio (use currentXP as canonical field)
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

	-- Render at final position (no animation decision - BaseMixin handles that)
	self:RenderBarFrame(targetRatio, context)

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
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
	interaction = {enabled = true},
	tooltip = {enabled = true},
	animation = {
		enableAnimations = true,
		flashOnGain = true
	},
	position = {mode = "DRAGGABLE", positionKey = "FlatBar"},
	style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, FlatBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("flat", FlatBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create FlatBar frame programmatically.
function XPBarEnhanced_CreateFlatBarFrame()
	local styleKey = "flat"

	local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "FlatBarTemplate")
	frame:Show()

	_G.FlatBar = frame -- Global reference

	return frame
end
