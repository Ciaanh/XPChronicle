-- XPBarEnhanced - XPBarVisualsMixin
-- Provides overlay update methods (layout + color combined)
-- Used by style RenderBar methods to update individual overlays

XPBarVisualsMixin = {}

local Addon = XPBarEnhanced

--- Update rested overlay (layout + color)
function XPBarVisualsMixin:UpdateRestedOverlay(context, overlayName)
    if self.UpdateRestedOverlayLayout then
        self:UpdateRestedOverlayLayout(context, overlayName)
    end
    if self.UpdateRestedOverlayColor then
        self:UpdateRestedOverlayColor(overlayName)
    end
end

--- Update quest complete overlay (layout + color)
function XPBarVisualsMixin:UpdateQuestCompleteOverlay(context, overlayName)
    if self.UpdateQuestCompleteOverlayLayout then
        self:UpdateQuestCompleteOverlayLayout(context, overlayName)
    end
    if self.UpdateQuestCompleteOverlayColor then
        self:UpdateQuestCompleteOverlayColor(overlayName)
    end
end

--- Update quest incomplete overlay (layout + color)
function XPBarVisualsMixin:UpdateQuestIncompleteOverlay(context, overlayName)
    if self.UpdateQuestIncompleteOverlayLayout then
        self:UpdateQuestIncompleteOverlayLayout(context, overlayName)
    end
    if self.UpdateQuestIncompleteOverlayColor then
        self:UpdateQuestIncompleteOverlayColor(overlayName)
    end
end

--- Update exhaustion tick position
function XPBarVisualsMixin:UpdateExhaustionTick(context, tickName)
    if self.UpdateExhaustionTickLayout then
        self:UpdateExhaustionTickLayout(context, tickName)
    end
end

return XPBarVisualsMixin
