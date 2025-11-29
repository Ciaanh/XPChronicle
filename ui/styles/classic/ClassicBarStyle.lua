-- XP Bar Enhanced - Classic Bar Style
-- Blizzard-style XP bar with border frame and atlas textures
-- Static positioning (anchored to Blizzard's MainStatusTrackingBarContainer)

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "ClassicBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Classic Bar style template: follows  composition pattern
local ClassicBarStyleTemplate = {}

-------------------------------------------------------------------
--  ANIMATION IMPLEMENTATION (StatusBar-based with atlas texture)
-------------------------------------------------------------------

-- --- Update bar position - smooth fill animation
-- -- @param iterationData table: Per-frame iteration data with currentRatio
-- -- @param eventContext table: Immutable event context
-- function ClassicBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
--     local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
--     local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
--     if StyleHelpers and StyleHelpers.AnimateStatusBarPosition then
--         StyleHelpers.AnimateStatusBarPosition(self, iterationData, eventContext)
--     end
-- end

-- --- Update visual effects - flash overlay animation
-- -- @param iterationData table: Per-frame iteration data with flashData
-- -- @param eventContext table: Immutable event context
-- function ClassicBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
--     -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
--     local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
--     local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
--     if StyleHelpers and StyleHelpers.AnimateGainFlash then
--         StyleHelpers.AnimateGainFlash(self, iterationData, eventContext)
--     end
-- end

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

-- --- Single render method for classic bar ( unified pattern)
-- --- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
-- ---@param context table Immutable context with all state and flags
-- function ClassicBarStyleTemplate:RenderBar(context)
--     local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
--     local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
--     if StyleHelpers and StyleHelpers.RenderBarBase then
--         StyleHelpers.RenderBarBase(self, context)
--     end
-- end

-- --- Render all bar elements for a single animation frame
-- --- Called once for instant updates
-- ---@param currentRatio number Current animation progress (0-1), or final ratio for instant
-- ---@param context table Immutable context with all state and flags
-- function ClassicBarStyleTemplate:RenderBarFrame(currentRatio, context)
--     local AddonLocal = rawget(_G, "XPBarEnhanced") or Addon
--     local StyleHelpers = (AddonLocal and AddonLocal.UI and AddonLocal.UI.StyleHelpers) or nil
--     if StyleHelpers and StyleHelpers.RenderBarFrameCommon then
--         StyleHelpers.RenderBarFrameCommon(self, currentRatio, context)
--     end

--     -- Note: Overlays and text are currently updated outside this method
-- end

-------------------------------------------------------------------
-- TRIGGER IMPLEMENTATION
-------------------------------------------------------------------

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
    position = {mode = "STATIC", positionKey = "ClassicBar"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
ClassicBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, ClassicBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("classic", ClassicBarXPBarMixin)
