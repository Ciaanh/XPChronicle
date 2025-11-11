-- XP Bar Enhanced - Legacy Bar Style v2
-- Blizzard-style XP bar with border frame and atlas textures
-- Static positioning (anchored to Blizzard's MainStatusTrackingBarContainer)

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase_v2 then
    error(
        "LegacyBarStyle: v2 core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Legacy Bar style template: follows V2 composition pattern
local LegacyBarStyleTemplate = {}

-------------------------------------------------------------------
-- V2 ANIMATION IMPLEMENTATION (StatusBar-based with atlas texture)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param stepContext table: Step context with currentRatio
function LegacyBarStyleTemplate:AnimateBarPosition(stepContext)
    if self.StatusBar then
        self.StatusBar:SetValue(stepContext.currentRatio)
    end
end

--- Update visual effects - flash overlay animation
-- @param stepContext table: Step context with flashData
function LegacyBarStyleTemplate:AnimateBarEffect(stepContext)
    -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end

    local flashData = stepContext.flashData
    if flashData and flashData.active and flashData.currentAlpha > 0 then
        -- Get user-defined color based on rested state (matches V1 behavior)
        local XPBarColors = _G.XPBarColors
        local hasRestedXP = stepContext.xpContext and stepContext.xpContext.hasRestedXP
        local colorKey = hasRestedXP and Color.Rested or Color.XpBar
        local color = XPBarColors:GetUserColor(colorKey)

        -- Apply flash color with current alpha
        gainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
        gainFlash:Show()
    else
        gainFlash:Hide()
    end
    
    -- Apply quest overlay alpha reduction during flash
    if stepContext.questOverlayAlpha and self.StatusBar then
        local questOverlayComplete = self.StatusBar.QuestOverlayComplete
        local questOverlayIncomplete = self.StatusBar.QuestOverlayIncomplete
        
        if questOverlayComplete and stepContext.questOverlayCompleteInitialAlpha then
            local newAlpha = stepContext.questOverlayCompleteInitialAlpha * stepContext.questOverlayAlpha
            questOverlayComplete:SetAlpha(newAlpha)
        end
        
        if questOverlayIncomplete and stepContext.questOverlayIncompleteInitialAlpha then
            local newAlpha = stepContext.questOverlayIncompleteInitialAlpha * stepContext.questOverlayAlpha
            questOverlayIncomplete:SetAlpha(newAlpha)
        end
    end
end

-------------------------------------------------------------------
-- TRIGGER IMPLEMENTATION
-------------------------------------------------------------------

--- Trigger: Update current XP bar display
-- @param context table XP context from ContextBuilder (flat structure)
function LegacyBarStyleTemplate:UpdateCurrentXPBar(context)
    if not context then
        error("UpdateCurrentXPBar requires an explicit immutable context")
    end

    -- Calculate target ratio
    local targetRatio = 0
    if context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end

    -- Get animation config
    local config = self:GetAnimationConfig()

    -- Build XP context for animation system (match FlatBar pattern)
    local xpContext = {
        xpBefore = context.xpBefore or context.previousXP or 0,
        xpAfter = context.xpAfter or context.currentXP or 0,
        xpMax = context.xpMax or 1,
        xpGained = context.xpGained or 0,
        restedXP = context.restedXP or 0,
        isResting = context.isResting or false,
        hasRestedXP = context.hasRestedXP or false,
        level = context.level or 1,
        timestamp = GetTime()
    }

    -- Start animation (delegates to AnimationManager via AnimationBase)
    if self.StartAnimation then
        self:StartAnimation(targetRatio, xpContext, config)
    else
        -- Fallback: instant update if animation system not available
        if self.StatusBar then
            self.StatusBar:SetValue(targetRatio)
        end
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end

    -- Update bar colors (non-animated visuals)
    if self.UpdateBarColors then
        self:UpdateBarColors(context)
    end
end

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    position = {mode = "STATIC", positionKey = "LegacyBar_v2"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
LegacyBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, LegacyBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("legacy_v2", LegacyBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create Legacy Bar frame programmatically.
function XPBarEnhanced_CreateLegacyBarFrame()
    local styleKey = "legacy_v2"

    local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "LegacyBarTemplate")
    frame:Show()

    _G.LegacyBar_v2 = frame -- Global reference

    return frame
end
