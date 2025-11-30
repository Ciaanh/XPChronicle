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
