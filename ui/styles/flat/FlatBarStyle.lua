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

-- --- Update bar position - smooth fill animation
-- -- @param iterationData table: Per-frame iteration data with currentRatio
-- -- @param eventContext table: Immutable event context
-- -- Note: Rested overlay animates automatically because it's positioned BEHIND the StatusBar
-- --       with width = currentXP + restedXP (set once at animation start). As the StatusBar
-- --       fill animates from old to new currentXP, it progressively reveals/covers the rested
-- --       overlay beneath it, creating smooth animation without any per-frame updates.
-- function FlatBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
-- 	local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
-- 	local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
-- 	if StyleHelpers and StyleHelpers.AnimateStatusBarPosition then
-- 		StyleHelpers.AnimateStatusBarPosition(self, iterationData, eventContext)
-- 	end
-- end

-- --- Update visual effects - flash overlay animation
-- -- @param iterationData table: Per-frame iteration data with flashData
-- -- @param eventContext table: Immutable event context
-- function FlatBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
-- 	local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
-- 	local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
-- 	if StyleHelpers and StyleHelpers.AnimateGainFlash then
-- 		StyleHelpers.AnimateGainFlash(self, iterationData, eventContext)
-- 	end
-- end

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

-- --- Single render method for flat bar ( unified pattern)
-- --- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
-- ---@param context table Immutable context with all state and flags
-- function FlatBarStyleTemplate:RenderBar(context)
-- 	local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
-- 	local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
-- 	if StyleHelpers and StyleHelpers.RenderBarBase then
-- 		StyleHelpers.RenderBarBase(self, context)
-- 	end
-- end

-- --- Render all bar elements for a single animation frame
-- --- Called once for instant updates (animation will be integrated later)
-- ---@param currentRatio number Current animation progress (0-1), or final ratio for instant
-- ---@param context table Immutable context with all state and flags
-- function FlatBarStyleTemplate:RenderBarFrame(currentRatio, context)
-- 	local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
-- 	local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
-- 	if StyleHelpers and StyleHelpers.RenderBarFrameCommon then
-- 		StyleHelpers.RenderBarFrameCommon(self, currentRatio, context)
-- 	end

-- 	-- Note: Overlays and text are currently updated outside this method
-- 	-- TODO Phase 3: Integrate overlay rendering here so they animate every frame
-- end

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
