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

-- Shared render base used by multiple styles. Calls RenderBarFrame then overlay and text updates.
function XPBarVisualsMixin:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end
    local targetRatio = StyleHelpers.CalculateTargetRatio(context)
    if self.RenderBarFrame then
        self:RenderBarFrame(targetRatio, context)
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

    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

-- Shared RenderFrame logic for StatusBar-based styles
function XPBarVisualsMixin:RenderBarFrame(currentRatio, context)
    if self.StatusBar and currentRatio then
        self.StatusBar:SetValue(currentRatio)
    end
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end
    if self.UpdateBarColors then
        self:UpdateBarColors(context)
    end
end




-- Exhaustion tick tooltip behavior: small mixin used by Exhaustion tick buttons
ExhaustionTickMixin = {}

---Find closest ancestor frame representing a bar (provides state and context methods)
local function FindBarAncestor(frame)
    local f = frame and frame:GetParent()
    while f do
        if f and (f.FullUpdate or f.Refresh or f.UpdateBarDisplay) then
            return f
        end
        f = f:GetParent()
    end
    return nil
end

function ExhaustionTickMixin:OnEnter()
    local bar = FindBarAncestor(self)
    if not bar then
        return
    end
    local ctx = nil
    if bar.GetSnapshot and type(bar.GetSnapshot) == "function" then
        ctx = bar:GetSnapshot() -- some styles may expose a snapshot API
    end
    -- Fallback to bar.state
    if not ctx then
        ctx = {
            restedXP = (bar.state and bar.state.restedXP) or (bar.restedXP and bar.restedXP),
            xpMax = (bar.state and bar.state.xpMax) or (bar.xpMax and bar.xpMax)
        }
    end

    local tt = GameTooltip
    if not tt then
        return
    end
    tt:SetOwner(self, "ANCHOR_TOP")
    if ctx and ctx.restedXP and ctx.restedXP > 0 then
        local maxXP = ctx.xpMax or ((type(UnitXPMax) == "function" and UnitXPMax("player")) or 1)
        local percent = (ctx.restedXP / maxXP) * 100
        tt:AddLine("Rested XP", 1, 1, 1)
        tt:AddDoubleLine("Amount:", tostring(ctx.restedXP), 0.8, 0.8, 0.8, 1, 1, 1)
        tt:AddDoubleLine("Percent:", string.format("%.1f%%", percent), 0.8, 0.8, 0.8, 1, 1, 1)
    else
        tt:AddLine("Rested: None", 0.8, 0.8, 0.8)
    end
    tt:Show()
end

function ExhaustionTickMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-- Ensure namespaces exist for backward compatibility
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.Mixins = Addon.Mixins or {}

-- Export mixin
Addon.UI.Mixins.ExhaustionTickMixin = ExhaustionTickMixin
Addon.Mixins.ExhaustionTickMixin = ExhaustionTickMixin
_G.ExhaustionTickMixin = ExhaustionTickMixin

return XPBarVisualsMixin
