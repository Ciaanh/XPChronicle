local ADDON_NAME = "XPChronicle"
local XPC = XPChronicle

-- Get AceLocale instance
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

-- ============================================================================
-- Locale Helper Module
-- ============================================================================
local Locale = {}

-- Get localized string
function Locale:Get(key, ...)
    if not L then
        return key
    end
    
    local text = L[key]
    
    if not text then
        if XPC.App.Core.Logger then
            XPC.App.Core.Logger:Error("Missing locale key: " .. tostring(key))
        end
        return key
    end
    
    -- Handle format strings
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    
    return text
end

-- ============================================================================
-- Export
-- ============================================================================
XPC.App = XPC.App or {}
XPC.App.Core = XPC.App.Core or {}
XPC.App.Core.Locale = Locale

-- Also provide global shorthand
XPC.L = function(key, ...)
    return Locale:Get(key, ...)
end
