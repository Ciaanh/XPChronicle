-- XPBarEnhanced - XPBarVisualsMixin
-- Aggregates LayoutMixin and PaintMixin for backwards compatibility

XPBarVisualsMixin = {}

local Addon = XPBarEnhanced

XPBarVisualsMixin.__metadata = {
    name = "XPBarVisualsMixin",
    version = "2.0.0",
    provides = {
        "UpdateCurrentXPBar",
        "UpdateRestedOverlay",
        "UpdateQuestCompleteOverlay",
        "UpdateQuestIncompleteOverlay",
        "UpdateExhaustionTick",
        "UpdateFlashOverlay",
        "UpdateOverlays",
        "UpdateBars"
    }
}

function XPBarVisualsMixin:UpdateCurrentXPBar(context, barName)
    if self.UpdateBarLayout then
        self:UpdateBarLayout(context, barName)
    end
    if self.UpdateBarColors then
        self:UpdateBarColors(context, barName)
    end
end

function XPBarVisualsMixin:UpdateBars(context)
    if not context then
        error("UpdateBars requires an explicit immutable context")
    end
    if self.UpdateCurrentXPBar then
        self:UpdateCurrentXPBar(context)
        return
    end
    if self.StatusBar then
        local ratio = 0
        if context.xpMax and context.xpMax > 0 then
            ratio = (context.currentXP or 0) / context.xpMax
        end
        self.StatusBar:SetValue(ratio)
    end
end

function XPBarVisualsMixin:UpdateRestedOverlay(context, overlayName)
    if self.UpdateRestedOverlayLayout then
        self:UpdateRestedOverlayLayout(context, overlayName)
    end
    if self.UpdateRestedOverlayColor then
        self:UpdateRestedOverlayColor(overlayName)
    end
end

function XPBarVisualsMixin:UpdateQuestCompleteOverlay(context, overlayName)
    if self.UpdateQuestCompleteOverlayLayout then
        self:UpdateQuestCompleteOverlayLayout(context, overlayName)
    end
    if self.UpdateQuestCompleteOverlayColor then
        self:UpdateQuestCompleteOverlayColor(overlayName)
    end
end

function XPBarVisualsMixin:UpdateQuestIncompleteOverlay(context, overlayName)
    if self.UpdateQuestIncompleteOverlayLayout then
        self:UpdateQuestIncompleteOverlayLayout(context, overlayName)
    end
    if self.UpdateQuestIncompleteOverlayColor then
        self:UpdateQuestIncompleteOverlayColor(overlayName)
    end
end

function XPBarVisualsMixin:UpdateExhaustionTick(context, tickName)
    if self.UpdateExhaustionTickLayout then
        self:UpdateExhaustionTickLayout(context, tickName)
    end
end

function XPBarVisualsMixin:UpdateFlashOverlay(context, flashName)
    flashName = flashName or "GainFlash"
    local flash = self[flashName]
    if not flash then
        return
    end
end

function XPBarVisualsMixin:UpdateOverlays(context)
    if not context then
        return
    end
    if self.UpdateRestedOverlay then
        self:UpdateRestedOverlay(context)
    end
    if self.UpdateQuestCompleteOverlay then
        self:UpdateQuestCompleteOverlay(context)
    end
    if self.UpdateQuestIncompleteOverlay then
        self:UpdateQuestIncompleteOverlay(context)
    end
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick(context)
    end
end

-- BuildVisuals is implemented by PaintMixin - don't override it here
-- function XPBarVisualsMixin:BuildVisuals()
-- end

-- ApplyStyle is implemented by PaintMixin - don't override it here
-- function XPBarVisualsMixin:ApplyStyle(styleConfig)
-- end

return XPBarVisualsMixin
