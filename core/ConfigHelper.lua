-- ConfigHelper.lua
-- Centralized configuration value resolution with consistent fallback logic
-- Ensures identical behavior across TextMixin, LayoutMixin, and ContextBuilder

local Addon = XPBarEnhanced

---@class ConfigHelper
local ConfigHelper = {}

-------------------------------------------------------------------
-- BOOLEAN CONFIGURATION RESOLUTION
-------------------------------------------------------------------

--- Resolve a boolean configuration value with standardized fallback logic
--- Priority: context value -> default value
---
--- ARCHITECTURE: Context is the single source of truth.
--- ContextBuilder populates all values from database during context creation.
--- No database fallback is allowed here - this enforces immutable context pattern.
---
--- @param context table|nil Immutable context object (may be nil)
--- @param contextKey string Key name in context table
--- @param defaultValue boolean Default value when context doesn't have the value
--- @return boolean resolved Final resolved boolean value
---
--- Examples:
---   GetBooleanValue(context, "showCompleteQuestOverlay", true)
---     -> Returns context.showCompleteQuestOverlay if set
---     -> Else returns true (default)
---
function ConfigHelper.GetBooleanValue(context, contextKey, defaultValue)
	-- Priority 1: Context value (if context exists and has explicit value)
	if context and context[contextKey] ~= nil then
		local value = context[contextKey]
		return value == true
	end

	-- Priority 2: Default value
	return defaultValue == true
end

-------------------------------------------------------------------
-- QUEST OVERLAY CONFIGURATION HELPERS
-------------------------------------------------------------------

--- Get showCompleteQuestOverlay with consistent fallback (default: true)
--- @param context table|nil Context object
--- @return boolean show Whether to show complete quest overlay
function ConfigHelper.GetShowCompleteQuestOverlay(context)
	return ConfigHelper.GetBooleanValue(context, "showCompleteQuestOverlay", true)
end

--- Get showIncompleteQuestOverlay with consistent fallback (default: false)
--- @param context table|nil Context object
--- @return boolean show Whether to show incomplete quest overlay
function ConfigHelper.GetShowIncompleteQuestOverlay(context)
	return ConfigHelper.GetBooleanValue(context, "showIncompleteQuestOverlay", false)
end

-------------------------------------------------------------------
-- TEXT VISIBILITY CONFIGURATION HELPERS
-------------------------------------------------------------------

--- Get showLevelText with consistent fallback (default: true)
function ConfigHelper.GetShowLevelText(context)
	return ConfigHelper.GetBooleanValue(context, "showLevelText", true)
end

--- Get showXPText with consistent fallback (default: true)
function ConfigHelper.GetShowXPText(context)
	return ConfigHelper.GetBooleanValue(context, "showXPText", true)
end

--- Get showPercentage with consistent fallback (default: true)
function ConfigHelper.GetShowPercentage(context)
	return ConfigHelper.GetBooleanValue(context, "showPercentage", true)
end

--- Get showQuestXP with consistent fallback (default: true)
function ConfigHelper.GetShowQuestXP(context)
	return ConfigHelper.GetBooleanValue(context, "showQuestXP", true)
end

--- Get showXPPerHourText with consistent fallback (default: true)
function ConfigHelper.GetShowXPPerHourText(context)
	return ConfigHelper.GetBooleanValue(context, "showXPPerHourText", true)
end

--- Get showTimeToLevelText with consistent fallback (default: true)
function ConfigHelper.GetShowTimeToLevelText(context)
	return ConfigHelper.GetBooleanValue(context, "showTimeToLevelText", true)
end

--- Get showLevelTimeText with consistent fallback (default: true)
function ConfigHelper.GetShowLevelTimeText(context)
	return ConfigHelper.GetBooleanValue(context, "showLevelTimeText", true)
end

--- Get showSessionTimeText with consistent fallback (default: true)
function ConfigHelper.GetShowSessionTimeText(context)
	return ConfigHelper.GetBooleanValue(context, "showSessionTimeText", true)
end

-------------------------------------------------------------------
-- OTHER CONFIGURATION HELPERS
-------------------------------------------------------------------

--- Get showRestedOverlay with consistent fallback (default: true)
function ConfigHelper.GetShowRestedOverlay(context)
	return ConfigHelper.GetBooleanValue(context, "showRestedOverlay", true)
end

--- Get showExhaustionTick with consistent fallback (default: true)
function ConfigHelper.GetShowExhaustionTick(context)
	return ConfigHelper.GetBooleanValue(context, "showExhaustionTick", true)
end

--- Get abbreviateNumbers with consistent fallback (default: true)
function ConfigHelper.GetAbbreviateNumbers(context)
	return ConfigHelper.GetBooleanValue(context, "abbreviateNumbers", true)
end

--- Get showRemainingXP with consistent fallback (default: false)
function ConfigHelper.GetShowRemainingXP(context)
	return ConfigHelper.GetBooleanValue(context, "showRemainingXP", false)
end

--- Get showQuestPercent with consistent fallback (default: false)
function ConfigHelper.GetShowQuestPercent(context)
	return ConfigHelper.GetBooleanValue(context, "showQuestPercent", false)
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

Addon.ConfigHelper = ConfigHelper
return ConfigHelper
