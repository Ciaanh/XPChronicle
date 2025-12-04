-- XPBarEnhanced - BarDisplayMixin
-- Provides overlay update methods (layout + color combined)
-- Used by style RenderBar methods to update individual overlays

BarDisplayMixin = {}

local Addon = XPBarEnhanced

--- Update rested overlay (layout + color)
function BarDisplayMixin:UpdateRestedBar(context, overlayName)
    if self.UpdateRestedBarLayout then
        self:UpdateRestedBarLayout(context, overlayName)
    end
    if self.UpdateRestedBarColor then
        self:UpdateRestedBarColor(overlayName)
    end
end

--- Update quest complete overlay (layout + color)
function BarDisplayMixin:UpdateQuestCompleteBar(context, overlayName)
    if self.UpdateQuestCompleteBarLayout then
        self:UpdateQuestCompleteBarLayout(context, overlayName)
    end
    if self.UpdateQuestCompleteBarColor then
        self:UpdateQuestCompleteBarColor(overlayName)
    end
end

--- Update quest incomplete overlay (layout + color)
function BarDisplayMixin:UpdateQuestIncompleteBar(context, overlayName)
    if self.UpdateQuestIncompleteBarLayout then
        self:UpdateQuestIncompleteBarLayout(context, overlayName)
    end
    if self.UpdateQuestIncompleteBarColor then
        self:UpdateQuestIncompleteBarColor(overlayName)
    end
end

--- Update exhaustion tick position
function BarDisplayMixin:UpdateExhaustionTick(context, tickName)
    if self.UpdateExhaustionTickLayout then
        self:UpdateExhaustionTickLayout(context, tickName)
    end
end

-- Shared render base used by multiple styles. Calls UpdateGainedBar then overlay and text updates.
function BarDisplayMixin:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end
    local targetRatio = self:CalculateTargetRatio(context)
    if self.UpdateGainedBar then
        self:UpdateGainedBar(targetRatio, context)
    end

    if self.UpdateRestedBar then
        self:UpdateRestedBar(context)
    end
    if self.UpdateQuestCompleteBar then
        self:UpdateQuestCompleteBar(context)
    end
    if self.UpdateQuestIncompleteBar then
        self:UpdateQuestIncompleteBar(context)
    end
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick(context)
    end

    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

-- Shared RenderFrame logic for StatusBar-based styles
function BarDisplayMixin:UpdateGainedBar(currentRatio, context)
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

return BarDisplayMixin
