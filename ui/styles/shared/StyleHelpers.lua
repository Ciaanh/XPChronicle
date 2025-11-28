-- StyleHelpers.lua
-- Shared helper functions for XP Bar style mixins to reduce duplication

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.StyleHelpers = Addon.UI.StyleHelpers or {}

local StyleHelpers = {}

-- Calculate a normalized ratio from context
function StyleHelpers.CalculateTargetRatio(context)
    local targetRatio = 0
    if context and context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end
    return targetRatio
end

-- Shared render base used by multiple styles. Calls RenderBarFrame then overlay and text updates.
function StyleHelpers.RenderBarBase(self, context)
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

-- Common StatusBar animation handler
function StyleHelpers.AnimateStatusBarPosition(self, iterationData, eventContext)
    if self.StatusBar and iterationData and iterationData.currentRatio then
        self.StatusBar:SetValue(iterationData.currentRatio)
    end
end

-- Shared visual effect (gain flash) implementation
function StyleHelpers.AnimateGainFlash(self, iterationData, eventContext)
    local flashData = iterationData and iterationData.flashData
    -- attempt to find GainFlash on StatusBar first, fallback to frame GainFlash
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end
    if flashData and flashData.active and flashData.currentAlpha and flashData.currentAlpha > 0 then
        local XPBarColors = _G.XPBarColors
        local hasRestedXP = eventContext and eventContext.hasRestedXP
        local colorKey = hasRestedXP and Color.Rested or Color.XpBar
        local color = XPBarColors and XPBarColors.GetUserColor and XPBarColors:GetUserColor(colorKey)
        if color then
            gainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
        else
            gainFlash:SetColorTexture(1, 1, 1, flashData.currentAlpha)
        end
        gainFlash:Show()
    else
        gainFlash:Hide()
    end

    if iterationData and iterationData.questOverlayAlpha then
        if self.StatusBar then
            local complete = self.StatusBar.QuestOverlayComplete
            local incomplete = self.StatusBar.QuestOverlayIncomplete
            if complete and iterationData.questOverlayCompleteInitialAlpha then
                local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
                complete:SetAlpha(newAlpha)
            end
            if incomplete and iterationData.questOverlayIncompleteInitialAlpha then
                local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
                incomplete:SetAlpha(newAlpha)
            end
        else
            -- frame-level overlays
            if self.QuestOverlayComplete and iterationData.questOverlayCompleteInitialAlpha then
                local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
                self.QuestOverlayComplete:SetAlpha(newAlpha)
            end
            if self.QuestOverlayIncomplete and iterationData.questOverlayIncompleteInitialAlpha then
                local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
                self.QuestOverlayIncomplete:SetAlpha(newAlpha)
            end
        end
    end
end

-- Shared RenderFrame logic for StatusBar-based styles
function StyleHelpers.RenderBarFrameCommon(self, currentRatio, context)
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

Addon.UI.StyleHelpers = StyleHelpers
return StyleHelpers
