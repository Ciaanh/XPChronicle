local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Core = Addon.App.Core or {}

local Logger = {}
Logger.level = "ERROR"

local function getAddonName()
    if Addon.L then
        return Addon.L("ADDON_NAME")
    end
    return "XP Chronicle"
end

local function log(prefix, message, ...)
    if not message then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    print(string.format("|cFFFF5555%s [%s]:|r %s", getAddonName(), prefix, message))
end

function Logger:Error(message, ...)
    --log("ERROR", message, ...)
    local errorMessage = string.format(message, ...)
    error(errorMessage)
end

Addon.App.Core.Logger = Logger
