local Addon = XPBarEnhanced

local Logger = {}

function Logger:Error(message, ...)
    local errorMessage = string.format(message, ...)
    error(errorMessage)
end

Addon.Logger = Logger
