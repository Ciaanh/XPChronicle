local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

local DraggableFrameMixin = {}
Addon.UI.Mixins.DraggableFrameMixin = DraggableFrameMixin

function DraggableFrameMixin:EnableDrag(options)
    options = options or {}
    local originalStart = options.onDragStart
    local originalStop = options.onDragStop

    options.onDragStart = function(frame, ...)
        if frame.SaveStoredPosition then
            frame._xpcWasDragging = true
        end
        if originalStart then
            originalStart(frame, ...)
        end
    end

    options.onDragStop = function(frame, ...)
        if originalStop then
            originalStop(frame, ...)
        end
        if frame._xpcWasDragging then
            frame._xpcWasDragging = nil
            frame:SaveStoredPosition()
        end
    end

    -- Get FrameUtils dynamically (not cached at file load time)
    local FrameUtils = Addon.UI.Components and Addon.UI.Components.FrameUtils
    if FrameUtils and FrameUtils.EnableDrag then
        FrameUtils.EnableDrag(self, options)
    end

    -- Mark frame as draggable so other systems (tooltip, hints) can detect it
    self.isDraggable = true
    -- Store modifier/button metadata for hint generation
    if options and options.requireModifier then
        self._xpbeDragModifier = options.requireModifier
    end
    self._xpbeDragButton = (options and options.button) or "LeftButton"
end

-- Export mixin to Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.DraggableFrameMixin = DraggableFrameMixin
_G.DraggableFrameMixin = DraggableFrameMixin

return DraggableFrameMixin
