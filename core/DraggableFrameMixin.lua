-- Shim: draggable frame mixin - back-compat. Real implementation is under ui/mixins/DraggableFrameMixin.lua
local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

-- If the new UI mixin is already loaded then alias it; otherwise provide a minimal shim implementation.
if Addon.UI.Mixins.DraggableFrameMixin then
    Addon.Mixins = Addon.Mixins or {}
    Addon.Mixins.DraggableFrameMixin = Addon.UI.Mixins.DraggableFrameMixin
    _G.DraggableFrameMixin = Addon.UI.Mixins.DraggableFrameMixin
    return Addon.UI.Mixins.DraggableFrameMixin
end

-- Pure alias-only shim: no fallback implementation provided here.
return