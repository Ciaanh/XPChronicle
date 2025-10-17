local Addon = XPBarEnhanced
Addon.App = Addon.App or {}
Addon.App.Core = Addon.App.Core or {}

local Logger = {}

function Logger:Error(message, ...)
    local errorMessage = string.format(message, ...)
    error(errorMessage)
end

Addon.App.Core.Logger = Logger
