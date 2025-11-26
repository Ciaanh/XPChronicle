-- XP Bar Enhanced - VerticalBar Style
-- Vertical XP bar with StatusBar widget using vertical orientation
-- Integrates with  AnimationManager for standard effects

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "VerticalBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local VerticalBarStyleTemplate = {}

-------------------------------------------------------------------
--  ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
-- Note: This is called by AnimationManager for standard smooth bar fill
function VerticalBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    if not self.StatusBar then
        return
    end

    -- Update the StatusBar value (0 to 1 ratio)
    -- StatusBar with vertical orientation handles the visual rendering
    self.StatusBar:SetValue(iterationData.currentRatio)
end

--- Update visual effects - flash overlay animation
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function VerticalBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    if not self.GainFlash then
        return
    end

    local flashData = iterationData.flashData
    if flashData and flashData.active and flashData.currentAlpha > 0 then
        -- Get user-defined color based on rested state
        local XPBarColors = _G.XPBarColors
        local hasRestedXP = eventContext and eventContext.hasRestedXP
        local colorKey = hasRestedXP and Color.Rested or Color.XpBar
        local color = XPBarColors:GetUserColor(colorKey)

        -- Show flash with user color and animated alpha
        self.GainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
        self.GainFlash:Show()
    else
        self.GainFlash:Hide()
    end
end

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN (Phase 2: Refactor)
-------------------------------------------------------------------

--- Single render method for vertical bar ( unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function VerticalBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Calculate target ratio (use currentXP as canonical field)
    local targetRatio = 0
    if context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end

    -- Render at final position (no animation decision - BaseMixin handles that)
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
function VerticalBarStyleTemplate:RenderBarFrame(currentRatio, context)
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
-- OVERRIDES for the vertical layout
-------------------------------------------------------------------

--- Override main bar color for vertical orientation (uses StatusBar SetStatusBarColor)
function VerticalBarStyleTemplate:UpdateBarColors(context, barName)
    if not self.StatusBar then
        return
    end

    -- Select color based on whether player has rested XP
    local XPBarColors = _G.XPBarColors
    local hasRestedXP = context.hasRestedXP or (context.restedXP and context.restedXP > 0)
    local colorKey = hasRestedXP and Color.XpBarRested or Color.XpBar
    local color = XPBarColors:GetUserColor(colorKey)

    -- Use SetStatusBarColor for StatusBar widget
    self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
end

--- Override rested overlay color for vertical orientation
function VerticalBarStyleTemplate:UpdateRestedOverlayColor(overlayName)
    overlayName = overlayName or "RestedOverlay"
    local overlay = self[overlayName]

    if not overlay then
        return
    end

    local XPBarColors = _G.XPBarColors
    local color = XPBarColors:GetUserColor(Color.Rested)

    -- Use SetVertexColor for WHITE8X8 texture
    overlay:SetVertexColor(color.r, color.g, color.b, color.a or 0.3)
end

--- Override quest complete overlay color
function VerticalBarStyleTemplate:UpdateQuestCompleteOverlayColor(overlayName)
    overlayName = overlayName or "QuestOverlayComplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local XPBarColors = _G.XPBarColors
    local color = XPBarColors:GetUserColor(Color.QuestComplete)
    overlay:SetVertexColor(color.r, color.g, color.b, color.a or 0.85)
end

--- Override quest incomplete overlay color
function VerticalBarStyleTemplate:UpdateQuestIncompleteOverlayColor(overlayName)
    overlayName = overlayName or "QuestOverlayIncomplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local XPBarColors = _G.XPBarColors
    local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
    overlay:SetVertexColor(color.r, color.g, color.b, color.a or 0.85)
end

--- Override quest complete overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateQuestCompleteOverlayLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayComplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local Addon = XPBarEnhanced
    local completeXP = context.completeQuestXP or 0

    -- Get visibility flags from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay

    local visible = false
    if showQuestXP and showComplete and (completeXP and completeXP > 0) then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local questXPClamped = math.min(completeXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()

            -- Vertical: calculate Y offset and height
            local currentRatio = currentXP / maxXP
            local yOffset = barHeight * currentRatio -- Start at top of current XP
            local height = barHeight * ratio

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

--- Override quest incomplete overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateQuestIncompleteOverlayLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayIncomplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local Addon = XPBarEnhanced
    local completeQuestXP = context.completeQuestXP or 0
    local incompleteQuestXP = context.incompleteQuestXP or 0

    -- Get visibility flags from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)

        -- Only subtract complete quest XP if that overlay is actually showing
        if showQuestXP and showComplete and completeQuestXP > 0 then
            remainingXP = math.max(0, remainingXP - completeQuestXP)
        end

        local questXPClamped = math.min(incompleteQuestXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()

            -- Vertical: calculate start Y position (current XP + complete quest XP if showing)
            local startXP = currentXP
            if showQuestXP and showComplete and completeQuestXP > 0 then
                startXP = startXP + completeQuestXP
            end

            local startRatio = startXP / maxXP
            local yOffset = barHeight * startRatio
            local height = barHeight * ratio

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

--- Override rested overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateRestedOverlayLayout(context)
    if not self.RestedOverlay then
        return
    end

    local Addon = XPBarEnhanced
    local restedXP = context.restedXP or 0
    local showRested = Addon.ConfigHelper.GetShowRestedOverlay(context)

    -- Get quest overlay visibility from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showRested and restedXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local restedXPClamped = math.min(restedXP, remainingXP)

        -- Calculate quest offset (how much space quest overlays take)
        local questOffset = 0
        local completeQuestXP = context.completeQuestXP or 0
        local incompleteQuestXP = context.incompleteQuestXP or 0

        -- Add complete quest XP if showing
        if showQuestXP and showComplete and completeQuestXP > 0 then
            local completeQuestClamped = math.min(completeQuestXP, remainingXP)
            questOffset = questOffset + completeQuestClamped
        end

        -- Add incomplete quest XP if showing
        if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
            local remainingAfterComplete = math.max(0, remainingXP - questOffset)
            local incompleteQuestClamped = math.min(incompleteQuestXP, remainingAfterComplete)
            questOffset = questOffset + incompleteQuestClamped
        end

        -- Vertical: total height from bottom (current XP + quest overlays + rested XP)
        -- The rested overlay is behind everything, so it extends from 0 to (current + quests + rested)
        local totalXP = currentXP + questOffset + restedXPClamped
        local totalRatio = math.min(totalXP / maxXP, 1.0)

        if totalRatio >= 0.01 then
            local barHeight = self:GetHeight()
            local height = barHeight * totalRatio

            self.RestedOverlay:ClearAllPoints()
            self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            self.RestedOverlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    self.RestedOverlay:SetShown(visible)
end

--- Override percent text to show only current XP percentage (no quest percent)
function VerticalBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText then
        return
    end

    local currentXP = context.currentXP or 0
    local maxXP = context.xpMax or 1
    local percent = maxXP > 0 and ((currentXP / maxXP) * 100) or 0

    -- Simple format: just the current XP percentage
    self.PercentText:SetFormattedText("%.1f%%", percent)
end

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

-- Default configuration for vertical bar
local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    animation = {
        enableAnimations = true,
        flashOnGain = true
    },
    position = {mode = "DRAGGABLE", positionKey = "VerticalBar"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
VerticalBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, VerticalBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("vertical", VerticalBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create VerticalBar frame programmatically.
function XPBarEnhanced_CreateVerticalBarFrame()
    local styleKey = "vertical"

    local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "VerticalBarTemplate")
    frame:Show()

    _G.VerticalBar = frame -- Global reference

    return frame
end
