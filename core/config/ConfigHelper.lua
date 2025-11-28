-- ConfigHelper.lua
-- Centralized configuration value resolution with consistent fallback logic
local Addon = XPBarEnhanced
---@class ConfigHelper
local ConfigHelper = {}

function ConfigHelper.GetBooleanValue(context, contextKey, defaultValue)
    if context and context[contextKey] ~= nil then
        local value = context[contextKey]
        return value == true
    end
    return defaultValue == true
end

function ConfigHelper.GetShowCompleteQuestOverlay(context)
    return ConfigHelper.GetBooleanValue(context, "showCompleteQuestOverlay", true)
end

function ConfigHelper.GetShowIncompleteQuestOverlay(context)
    return ConfigHelper.GetBooleanValue(context, "showIncompleteQuestOverlay", false)
end

function ConfigHelper.GetShowLevelText(context)
    return ConfigHelper.GetBooleanValue(context, "showLevelText", true)
end

function ConfigHelper.GetShowXPText(context)
    return ConfigHelper.GetBooleanValue(context, "showXPText", true)
end

function ConfigHelper.GetShowPercentage(context)
    return ConfigHelper.GetBooleanValue(context, "showPercentage", true)
end

function ConfigHelper.GetShowQuestXP(context)
    return ConfigHelper.GetBooleanValue(context, "showQuestXP", true)
end

function ConfigHelper.GetShowXPPerHourText(context)
    return ConfigHelper.GetBooleanValue(context, "showXPPerHourText", true)
end

function ConfigHelper.GetShowTimeToLevelText(context)
    return ConfigHelper.GetBooleanValue(context, "showTimeToLevelText", true)
end

function ConfigHelper.GetShowLevelTimeText(context)
    return ConfigHelper.GetBooleanValue(context, "showLevelTimeText", true)
end

function ConfigHelper.GetShowSessionTimeText(context)
    return ConfigHelper.GetBooleanValue(context, "showSessionTimeText", true)
end

function ConfigHelper.GetShowRestedOverlay(context)
    return ConfigHelper.GetBooleanValue(context, "showRestedOverlay", true)
end

function ConfigHelper.GetShowExhaustionTick(context)
    return ConfigHelper.GetBooleanValue(context, "showExhaustionTick", true)
end

function ConfigHelper.GetAbbreviateNumbers(context)
    return ConfigHelper.GetBooleanValue(context, "abbreviateNumbers", true)
end

function ConfigHelper.GetShowRemainingXP(context)
    return ConfigHelper.GetBooleanValue(context, "showRemainingXP", false)
end

function ConfigHelper.GetShowQuestPercent(context)
    return ConfigHelper.GetBooleanValue(context, "showQuestPercent", false)
end

Addon.ConfigHelper = ConfigHelper
return ConfigHelper
