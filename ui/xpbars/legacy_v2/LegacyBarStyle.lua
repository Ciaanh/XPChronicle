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
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function LegacyBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    if self.StatusBar then
        self.StatusBar:SetValue(iterationData.currentRatio)
    end
end

--- Update visual effects - flash overlay animation
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function LegacyBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end

    local flashData = iterationData.flashData
    if flashData and flashData.active and flashData.currentAlpha > 0 then
        -- Get user-defined color based on rested state (matches V1 behavior)
        local XPBarColors = _G.XPBarColors
        local hasRestedXP = eventContext and eventContext.hasRestedXP
        local colorKey = hasRestedXP and Color.Rested or Color.XpBar
        local color = XPBarColors:GetUserColor(colorKey)

        -- Apply flash color with current alpha
        gainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
        gainFlash:Show()
    else
        gainFlash:Hide()
    end
    
    -- Apply quest overlay alpha reduction during flash
    if iterationData.questOverlayAlpha and self.StatusBar then
        local questOverlayComplete = self.StatusBar.QuestOverlayComplete
        local questOverlayIncomplete = self.StatusBar.QuestOverlayIncomplete
        
        if questOverlayComplete and iterationData.questOverlayCompleteInitialAlpha then
            local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
            questOverlayComplete:SetAlpha(newAlpha)
        end
        
        if questOverlayIncomplete and iterationData.questOverlayIncompleteInitialAlpha then
            local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
            questOverlayIncomplete:SetAlpha(newAlpha)
        end
    end
end

-------------------------------------------------------------------
-- V2 UNIFIED RENDER PATTERN (Phase 2: Refactor)
-------------------------------------------------------------------

--- Single render method for legacy bar (V2 unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function LegacyBarStyleTemplate:RenderBar(context)
    if XPBarDebugLog then XPBarDebugLog:Log("LegacyBar", "RenderBar called") end
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Calculate target ratio (use currentXP as canonical field)
    local targetRatio = 0
    if context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end

    -- Render at final position (no animation decision - BaseMixin handles that)
    if XPBarDebugLog then XPBarDebugLog:Log("LegacyBar", "RenderBar calling RenderBarFrame with ratio:", targetRatio) end
    self:RenderBarFrame(targetRatio, context)

    -- Update overlays (always update, even during animation)
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

    -- Update text
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

--- Render all bar elements for a single animation frame
--- Called once for instant updates
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function LegacyBarStyleTemplate:RenderBarFrame(currentRatio, context)
    -- 1. MAIN BAR (at current animation position)
    if self.StatusBar then
        self.StatusBar:SetValue(currentRatio)
    end

    -- Update tracked ratio
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    -- 2. BAR COLORS (apply based on rested state)
    if self.UpdateBarColors then
        self:UpdateBarColors(context)
    end

    -- Note: Overlays and text are currently updated outside this method
end

-------------------------------------------------------------------
-- TRIGGER IMPLEMENTATION
-------------------------------------------------------------------

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    animation = {
        enableAnimations = true,
        flashOnGain = true
    },
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
