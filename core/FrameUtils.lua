local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Components = Addon.UI.Components or {}

-- If the UI FrameUtils exists, alias it and return.
if Addon.UI.Components and Addon.UI.Components.FrameUtils then
    Addon.Mixins = Addon.Mixins or {}
    Addon.Mixins.FrameUtils = Addon.UI.Components.FrameUtils
    _G.FrameUtils = Addon.UI.Components.FrameUtils
    return Addon.UI.Components.FrameUtils
end

-- Pure alias-only shim: no fallback provided here; return nil if UI is not loaded yet.
return
