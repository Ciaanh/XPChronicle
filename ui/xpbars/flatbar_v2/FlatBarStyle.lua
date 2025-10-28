-- XP Bar Enhanced - FlatBar Style v2
-- Composes mixins and registers the FlatBar style

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

local AddonName = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon("XPBarEnhanced")

-------------------------------------------------------------------
-- STYLE REGISTRATION
-------------------------------------------------------------------

--- Default configuration for FlatBar style
local DefaultConfig = {
	-- Behavior flags
	animation = {
		enabled = true,
		valueSmoothing = true,
		xpGainFlash = true,
		levelUpFlash = true,
	},
	interaction = {
		enabled = true,
	},
	tooltip = {
		enabled = true,
		provider = nil, -- Uses default from TooltipMixin
	},
	position = {
		mode = "STATIC", -- "STATIC" or "DRAGGABLE"
		positionKey = "FlatBar_v2",
	},
	
	-- Style-specific config
	style = {
		width = 565,
		height = 11,
		showQuestOverlays = true,
	},
}

--- Create and register the FlatBar style mixin
---@return table FlatBarXPBarMixin The composed mixin
function XPBarEnhanced_CreateFlatBarStyle()
	-- Get style template
	local styleTemplate = FlatBarStyleTemplate
	
	-- Compose mixin using StyleBuilder
	local mixin = XPBarStyleBuilder:Create(
		XPBarMixinBase_v2,
		styleTemplate,
		DefaultConfig
	)
	
	-- Store composed mixin globally for reuse
	_G.FlatBarXPBarMixin = mixin
	
	return mixin
end

--- Apply the FlatBar mixin to a frame
---@param frame table The frame to apply the mixin to
---@param config table|nil Optional configuration overrides
function XPBarEnhanced_ApplyFlatBarStyle(frame, config)
	if not _G.FlatBarXPBarMixin then
		error("FlatBarXPBarMixin not created. Call XPBarEnhanced_CreateFlatBarStyle first.")
		return
	end
	
	-- Merge config with defaults
	local finalConfig = CopyTable(DefaultConfig)
	if config then
		for k, v in pairs(config) do
			if type(v) == "table" and finalConfig[k] then
				finalConfig[k] = Mixin(finalConfig[k], v)
			else
				finalConfig[k] = v
			end
		end
	end
	
	-- Apply mixin to frame
	Mixin(frame, _G.FlatBarXPBarMixin)
	
	-- Store config on frame
	frame.__xpbar_config = finalConfig
	
	-- Call OnLoad if available
	if frame.OnLoad then
		frame:OnLoad()
	end
	
	return frame
end

-------------------------------------------------------------------
-- AUTOMATIC REGISTRATION
-------------------------------------------------------------------

-- Create the mixin on file load
XPBarEnhanced_CreateFlatBarStyle()
