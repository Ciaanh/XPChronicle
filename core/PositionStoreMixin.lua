local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

-- If canonical UI mixin exists, alias and return immediately
if Addon.UI.Mixins.PositionStoreMixin then
    Addon.Mixins = Addon.Mixins or {}
    Addon.Mixins.PositionStoreMixin = Addon.UI.Mixins.PositionStoreMixin
    _G.PositionStoreMixin = Addon.UI.Mixins.PositionStoreMixin
    return Addon.UI.Mixins.PositionStoreMixin
end

-- Pure alias-only shim: no fallback implementation provided here.
return
