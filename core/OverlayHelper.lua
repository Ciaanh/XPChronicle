-- OverlayHelper.lua
-- Centralize quest overlay and color logic used by various XP bar views

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Helpers = Addon.UI.Helpers or {}

-- If the UI helper exists, alias and return it
if Addon.UI.Helpers and Addon.UI.Helpers.OverlayHelper then
    Addon.OverlayHelper = Addon.UI.Helpers.OverlayHelper
    _G.OverlayHelper = Addon.UI.Helpers.OverlayHelper
    return Addon.UI.Helpers.OverlayHelper
end

-- Pure alias-only shim: no fallback provided here.
return
