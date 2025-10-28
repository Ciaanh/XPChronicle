-- XP Bar Enhanced - Style Builder (v2)
-- Composition utility for creating style mixins via CreateFromMixins

-------------------------------------------------------------------
-- GLOBAL STYLE BUILDER
-------------------------------------------------------------------

---@class XPBarStyleBuilder
XPBarStyleBuilder = {}

local StyleBuilder = XPBarStyleBuilder

-------------------------------------------------------------------
-- BUILDER API
-------------------------------------------------------------------

--- Create a composed style mixin using CreateFromMixins
--- Composition order: Base → Behaviors → StyleTemplate (style wins on method collision)
---@param baseMixin table Base mixin (XPBarMixinBase_v2)
---@param styleTemplate table Style-specific visual methods
---@param config table Configuration for behaviors and style
---@return table composedMixin Composed mixin ready for global registration
function StyleBuilder:Create(baseMixin, styleTemplate, config)
	-- Validate inputs
	if not baseMixin then
		error("StyleBuilder:Create - baseMixin is required")
	end
	if not styleTemplate then
		error("StyleBuilder:Create - styleTemplate is required")
	end
	config = config or {}
	
	-- Build behavior mixin list based on config
	local behaviorMixins = self:BuildBehaviorList(config)
	
	-- Compose: Base → Behaviors → Style (style methods override)
	local mixins = { baseMixin }
	for _, behavior in ipairs(behaviorMixins) do
		table.insert(mixins, behavior)
	end
	table.insert(mixins, styleTemplate)
	
	-- Use CreateFromMixins to compose all mixins
	local composedMixin = CreateFromMixins(unpack(mixins))
	
	-- Store config on composed mixin for runtime access
	composedMixin.__xpbar_config = config
	
	return composedMixin
end

--- Build list of behavior mixins based on config flags
---@param config table Configuration object
---@return table behaviorMixins Array of behavior mixin tables
function StyleBuilder:BuildBehaviorList(config)
	local behaviors = {}
	
	-- Animation mixin (optional, default enabled)
	if config.animation ~= false then
		if XPBarAnimationMixin then
			table.insert(behaviors, XPBarAnimationMixin)
		end
	end
	
	-- Interaction mixin (optional, default enabled)
	if config.interaction ~= false then
		if XPBarInteractionMixin then
			table.insert(behaviors, XPBarInteractionMixin)
		end
	end
	
	-- Tooltip mixin (optional, default enabled)
	if config.tooltip ~= false then
		if XPBarTooltipMixin then
			table.insert(behaviors, XPBarTooltipMixin)
		end
	end
	
	-- Position mixin (always included, mode determined by config)
	if XPBarPositionMixin then
		table.insert(behaviors, XPBarPositionMixin)
	end
	
	return behaviors
end

--- Validate configuration object
--- Provides helpful warnings for common config errors
---@param config table Configuration to validate
---@return boolean valid True if config is valid
function StyleBuilder:ValidateConfig(config)
	if not config then
		return true -- nil config is valid (uses defaults)
	end
	
	if type(config) ~= "table" then
		error("StyleBuilder:ValidateConfig - config must be a table")
		return false
	end
	
	-- Validate position config
	if config.position then
		if config.position.mode and config.position.mode ~= "STATIC" and config.position.mode ~= "DRAGGABLE" then
			print("WARNING: Invalid position.mode '" .. tostring(config.position.mode) .. "' - expected 'STATIC' or 'DRAGGABLE'")
		end
		
		if config.position.mode == "DRAGGABLE" and not config.position.positionKey then
			print("WARNING: position.mode is DRAGGABLE but position.positionKey not specified - position will not be saved")
		end
	end
	
	return true
end

return StyleBuilder
