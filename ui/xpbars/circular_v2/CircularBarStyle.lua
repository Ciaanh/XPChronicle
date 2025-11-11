-- XP Bar Enhanced - CircularBar Style v2
-- Circular progress ring with optimized 100-segment system
-- Integrates with V2 AnimationManager for standard effects

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase_v2 then
    error(
        "CircularBarStyle: v2 core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local RING_SEGMENTS = 100 -- Number of segments (1 segment = 1%)

local SEGMENT_TYPE = {
    EMPTY = 0, -- Background/transparent segment
    CURRENT_XP = 1, -- Current XP (main bar color)
    RESTED = 2, -- Rested XP overlay
    QUEST_COMPLETE = 3, -- Complete quest XP
    QUEST_INCOMPLETE = 4 -- Incomplete quest XP
}

-- Background color for empty segments (slight transparency to show ring structure)
local EMPTY_SEGMENT_COLOR = {r = 0.1, g = 0.1, b = 0.1, a = 0.3}

local CIRCULAR_BAR_STYLE = {
    RING_RADIUS_PX = 97, -- Distance from center to segment center (placement radius)
    SEGMENT_WIDTH_PX = 4, -- Width of each segment in pixels
    SEGMENT_HEIGHT_PX = 15 -- Height of each segment in pixels
}

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local CircularBarStyleTemplate = {}

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function CircularBarStyleTemplate:OnLoad()
    -- Circular bar specific setup
    self.segments = {} -- Single set of segments
    self.segmentTypes = {} -- Track type of each segment
    self.lastProgress = 0
    self.targetProgress = 0
    self.isAnimating = false

    -- Initialize cached overlay data
    self.cachedRestedXP = 0
    self.cachedCompleteQuestXP = 0
    self.cachedIncompleteQuestXP = 0
    self.cachedHasRestedXP = false

    -- Create ring segments (initialized with background color)
    self:CreateRingSegments()

    if XPBarMixinBase_v2 and XPBarMixinBase_v2.OnLoad then
        XPBarMixinBase_v2.OnLoad(self)
    end
end

-------------------------------------------------------------------
-- SEGMENT CREATION AND POSITIONING
-------------------------------------------------------------------

function CircularBarStyleTemplate:CreateRingSegments()
    -- Create single set of segments (no separate arrays for rested/quest)
    local color = EMPTY_SEGMENT_COLOR
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        -- segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetTexture("Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar")
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        -- Initialize with background color to show ring structure
        segment:SetVertexColor(color.r, color.g, color.b, color.a)
        segment:Show()
        self.segments[i] = segment
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Position all segments in a circle
    self:PositionSegments()
end

function CircularBarStyleTemplate:PositionSegments()
    local clockwise = -1
    local placementRadius = CIRCULAR_BAR_STYLE.RING_RADIUS_PX

    -- Localize heavy math functions for the inner loop
    local math_cos = math.cos
    local math_sin = math.sin
    local math_pi = math.pi

    -- Start at 6 o'clock (bottom) and increase angle -> clockwise in WoW (y positive = down)
    local startAngle = math_pi / 2
    local fullCircle = 2 * math_pi

    for i = 1, RING_SEGMENTS do
        local angle = startAngle + ((i - 1) / RING_SEGMENTS) * fullCircle

        -- Offsets relative to frame center (use CENTER anchor)
        local xOff = math_cos(angle) * placementRadius
        local yOff = math_sin(angle) * placementRadius * clockwise
        local rotation = (clockwise * angle) + startAngle

        -- Position segment
        local segment = self.segments[i]
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
    end
end

-------------------------------------------------------------------
-- V2 ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param stepContext table: Step context with currentRatio, xpContext
function CircularBarStyleTemplate:AnimateBarPosition(stepContext)
    -- Update the arc progress with current ratio
    -- Pass hasRestedXP from xpContext to ensure correct coloring
    local hasRestedXP = stepContext.xpContext and stepContext.xpContext.hasRestedXP or false
    self:SetArcProgress(stepContext.currentRatio, hasRestedXP)
end

--- Update visual effects - glow overlay animation
-- @param stepContext table: Step context with flashData
function CircularBarStyleTemplate:AnimateBarEffect(stepContext)
    -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end

    local flashData = stepContext.flashData
    if flashData and flashData.active and flashData.currentAlpha > 0 then
        -- Show glow with animated alpha
        self.GainFlash:SetAlpha(flashData.currentAlpha)
        self.GainFlash:Show()
    else
        print("CircularBarStyleTemplate: Hide glow")
        self.GainFlash:Hide()
    end
end

-------------------------------------------------------------------
-- OPTIMIZED SEGMENT MANAGEMENT
-------------------------------------------------------------------

--- Set arc progress and calculate all segment types in one pass
-- @param progress number: Progress ratio (0-1)
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:SetArcProgress(progress, hasRestedXP)
    -- Calculate current XP segments (1 segment = 1%)
    local currentXPSegments = math.floor(progress * 100 + 0.5)

    -- Get current XP and max for ratio calculations
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")

    -- Use cached overlay data from overlay update methods
    local restedXP = self.cachedRestedXP or 0
    local completeQuestXP = self.cachedCompleteQuestXP or 0
    local incompleteQuestXP = self.cachedIncompleteQuestXP or 0

    -- Get overlay config
    local Addon = XPBarEnhanced
    local showComplete = true
    local showIncomplete = false
    local showQuestXP = true

    if Addon and Addon.Database then
        local db = Addon.Database:GetDB()
        if db then
            showQuestXP = db.showQuestXP ~= false
            showComplete = db.showCompleteQuestOverlay ~= false
            showIncomplete = db.showIncompleteQuestOverlay == true
        end
    else
    end

    -- Initialize all segments as empty
    for i = 1, RING_SEGMENTS do
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Set current XP segments
    for i = 1, currentXPSegments do
        self.segmentTypes[i] = SEGMENT_TYPE.CURRENT_XP
    end

    -- Calculate remaining XP space for overlays
    local remainingXP = math.max(0, maxXP - currentXP)

    -- Calculate quest complete overlay segments (if enabled)
    if showQuestXP and showComplete and completeQuestXP > 0 then
        local completeXPClamped = math.min(completeQuestXP, remainingXP)
        local completeRatio = completeXPClamped / maxXP
        local questCompleteSegments = math.floor(completeRatio * 100 + 0.5)

        -- Quest complete starts after current XP
        for i = currentXPSegments + 1, math.min(currentXPSegments + questCompleteSegments, RING_SEGMENTS) do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_COMPLETE
        end

        -- Reduce remaining XP
        remainingXP = math.max(0, remainingXP - completeXPClamped)
    else
    end

    -- Calculate quest incomplete overlay segments (if enabled)
    if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
        local incompleteXPClamped = math.min(incompleteQuestXP, remainingXP)
        local incompleteRatio = incompleteXPClamped / maxXP
        local questIncompleteSegments = math.floor(incompleteRatio * 100 + 0.5)

        -- Quest incomplete starts after quest complete
        local startSegment = currentXPSegments + 1
        if showComplete and completeQuestXP > 0 then
            local completeXPClamped = math.min(completeQuestXP, maxXP - currentXP)
            local completeSegments = math.floor((completeXPClamped / maxXP) * 100 + 0.5)
            startSegment = currentXPSegments + completeSegments + 1
        end

        for i = startSegment, math.min(startSegment + questIncompleteSegments - 1, RING_SEGMENTS) do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_INCOMPLETE
        end

        -- Reduce remaining XP
        remainingXP = math.max(0, remainingXP - incompleteXPClamped)
    end

    -- Calculate rested overlay segments (if rested XP exists)
    if restedXP > 0 and remainingXP > 0 then
        local restedXPClamped = math.min(restedXP, remainingXP)
        local restedRatio = restedXPClamped / maxXP
        local restedSegments = math.floor(restedRatio * 100 + 0.5)

        -- Calculate start position after current XP + quest overlays
        local startSegment = currentXPSegments + 1
        if showQuestXP and showComplete and completeQuestXP > 0 then
            local completeXPClamped = math.min(completeQuestXP, maxXP - currentXP)
            local completeSegments = math.floor((completeXPClamped / maxXP) * 100 + 0.5)
            startSegment = startSegment + completeSegments
        end
        if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
            local totalRemaining = maxXP - currentXP
            if showComplete and completeQuestXP > 0 then
                totalRemaining = totalRemaining - math.min(completeQuestXP, totalRemaining)
            end
            local incompleteXPClamped = math.min(incompleteQuestXP, totalRemaining)
            local incompleteSegments = math.floor((incompleteXPClamped / maxXP) * 100 + 0.5)
            startSegment = startSegment + incompleteSegments
        end

        -- Rested segments
        for i = startSegment, math.min(startSegment + restedSegments - 1, RING_SEGMENTS) do
            -- Only set if not already set by quest overlays
            if self.segmentTypes[i] == SEGMENT_TYPE.EMPTY then
                self.segmentTypes[i] = SEGMENT_TYPE.RESTED
            end
        end
    else
    end

    -- Now apply colors to all segments based on their type
    self:UpdateSegmentColors(hasRestedXP)
end

--- Apply colors to segments based on their type
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:UpdateSegmentColors(hasRestedXP)
    local XPBarColors = _G.XPBarColors
    local colorNormal = XPBarColors:GetUserColor(Color.XpBar)
    local colorRested = XPBarColors:GetUserColor(Color.Rested)
    local colorXpBarRested = XPBarColors:GetUserColor(Color.XpBarRested)
    local colorQuestComplete = XPBarColors:GetUserColor(Color.QuestComplete)
    local colorQuestIncomplete = XPBarColors:GetUserColor(Color.QuestIncomplete)

    -- Use parameter or fallback to cached value
    hasRestedXP = hasRestedXP or self.cachedHasRestedXP or false

    -- Use Rested color for current XP bar when player has rested XP (matches flatbar_v2)
    local currentXPColor = hasRestedXP and colorXpBarRested or colorNormal

    -- Determine progress (prefer current ratio from animation, fall back to lastProgress)
    local progress = self._currentRatio or self.lastProgress or 0
    local totalSegments = RING_SEGMENTS
    local filled = math.floor(progress * totalSegments + 0.5)

    for i = 1, totalSegments do
        local segment = self.segments[i]
        if not segment then
            -- missing texture, skip
        else
            -- default empty appearance
            local color = EMPTY_SEGMENT_COLOR

            if i <= filled then
                -- fully filled by current XP - use exact color from config
                if currentXPColor and currentXPColor.r then
                    color = currentXPColor
                end
            else
                -- not part of main fill; check overlay type
                local segType = self.segmentTypes[i]
                if segType == SEGMENT_TYPE.QUEST_COMPLETE then
                    -- Use exact color from config
                    if colorQuestComplete and colorQuestComplete.r then
                        color = colorQuestComplete
                    end
                elseif segType == SEGMENT_TYPE.QUEST_INCOMPLETE then
                    -- Use exact color from config
                    if colorQuestIncomplete and colorQuestIncomplete.r then
                        color = colorQuestIncomplete
                    end
                elseif segType == SEGMENT_TYPE.RESTED then
                    -- Use exact color from config with ADD blend mode (v1 behavior)
                    if colorRested and colorRested.r then
                        color = colorRested
                    end
                else
                    -- EMPTY remains default
                end
            end

            -- Apply appearance: SetColorTexture for RGB only, SetAlpha separately
            segment:SetVertexColor(color.r, color.g, color.b, color.a)
            segment:Show()
        end
    end
end

-------------------------------------------------------------------
-- OVERRIDE: Refresh with logging
-------------------------------------------------------------------

function CircularBarStyleTemplate:Refresh()
    -- Build context
    if not XPBarContextBuilder then
        return
    end

    local context = XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")

    if not context then
        return
    end

    -- Call TriggerXPChanged
    if self.TriggerXPChanged then
        self:TriggerXPChanged(context)
    else
    end
end

-------------------------------------------------------------------
-- OVERRIDE: FullUpdate - handle option changes
-------------------------------------------------------------------

function CircularBarStyleTemplate:FullUpdate(context)
    -- Prevent re-entrant calls
    if self._isUpdating then
        return
    end
    self._isUpdating = true

    -- Use provided context or build fresh one
    if not context then
        context = XPBarContextBuilder.BuildXPChangeContext("FULL_UPDATE")
    end

    -- Update cached overlay data from context
    -- This is critical when options change (e.g., showCompleteQuestOverlay toggled)
    if self.UpdateRestedOverlay then
        self:UpdateRestedOverlay(context)
    end

    if self.UpdateQuestCompleteOverlay then
        self:UpdateQuestCompleteOverlay(context)
    end

    if self.UpdateQuestIncompleteOverlay then
        self:UpdateQuestIncompleteOverlay(context)
    end

    -- Re-render bar with updated cached data
    local currentXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1
    local ratio = maxXP > 0 and (currentXP / maxXP) or 0
    local hasRestedXP = context.hasRestedXP or false

    self:SetArcProgress(ratio, hasRestedXP)

    -- Update visuals (text, etc.)
    if self.UpdateVisuals then
        self:UpdateVisuals(context)
    end

    -- Update text visibility in case options changed
    if self.UpdateTextVisibility then
        self:UpdateTextVisibility(context)
    end

    self._isUpdating = nil
end

-------------------------------------------------------------------
-- OVERRIDE: Bar Update with V2 Animation
-------------------------------------------------------------------

--- Update bar with animation (overrides VisualsMixin)
-- @param context table: Immutable XP context
function CircularBarStyleTemplate:UpdateCurrentXPBar(context)
    if not context then
        error("UpdateCurrentXPBar requires an explicit immutable context")
    end

    -- Determine canonical current XP value for V2 contexts (prefer xpAfter)
    local curXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1

    -- Calculate target ratio using xpAfter (preferred)
    local targetRatio = 0
    if maxXP and maxXP > 0 then
        targetRatio = (curXP or 0) / maxXP
    end

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        local initialRatio = targetRatio
        if self.SetCurrentRatio then
            self:SetCurrentRatio(initialRatio)
        end
        -- Set initial visual state using cached overlay data
        local hasRestedXP = context.hasRestedXP or false
        self:SetArcProgress(initialRatio, hasRestedXP)
    end

    -- Build XP context for animation system (like flatbar - NO quest data here)
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

    -- Get animation config
    local config = self:GetAnimationConfig()

    -- Start animation (delegates to AnimationManager via AnimationBase)
    if self.StartAnimation then
        self:StartAnimation(targetRatio, xpContext, config)
    else
        self:SetArcProgress(targetRatio)
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end
end

-------------------------------------------------------------------
-- OVERRIDES for circular layout
-------------------------------------------------------------------

--- Override main bar layout for circular orientation (deprecated, use UpdateCurrentXPBar)
function CircularBarStyleTemplate:UpdateBarLayout(context, barName)
    -- Calculate target fill ratio
    local currentXP = context.currentXP or 0
    local maxXP = context.xpMax or 1
    local targetRatio = maxXP > 0 and (currentXP / maxXP) or 0

    -- Build XP context for animation system
    local xpContext = {
        xpBefore = context.xpBefore or context.currentXP or 0,
        xpAfter = context.xpAfter or context.currentXP or 0,
        xpMax = context.xpMax or 1,
        xpGained = context.xpGained or 0,
        restedXP = context.restedXP or 0,
        isResting = context.isResting or false,
        hasRestedXP = context.hasRestedXP or false,
        level = context.level or 1,
        timestamp = GetTime()
    }

    -- Get animation config
    local config = self:GetAnimationConfig()

    -- Start animation (delegates to AnimationManager via AnimationBase)
    if self.StartAnimation then
        self:StartAnimation(targetRatio, xpContext, config)
    else
        -- Fallback: instant update if animation system not available
        self:SetArcProgress(targetRatio)
    end
end

--- Override UpdateRestedOverlay to store rested data for segment coloring
function CircularBarStyleTemplate:UpdateRestedOverlay(context)
    if not context then
        return
    end

    -- Store rested data for SetArcProgress to use
    self.cachedRestedXP = context.restedXP or 0
    self.cachedHasRestedXP = context.hasRestedXP or false
end

--- Override UpdateQuestCompleteOverlay to store quest complete data for segment coloring
function CircularBarStyleTemplate:UpdateQuestCompleteOverlay(context)
    if not context then
        return
    end

    -- Store quest complete data for SetArcProgress to use
    self.cachedCompleteQuestXP = context.completeQuestXP or 0
end

--- Override UpdateQuestIncompleteOverlay to store quest incomplete data for segment coloring
function CircularBarStyleTemplate:UpdateQuestIncompleteOverlay(context)
    if not context then
        return
    end

    -- Store quest incomplete data for SetArcProgress to use
    self.cachedIncompleteQuestXP = context.incompleteQuestXP or 0
end

--- Override UpdateVisuals to trigger text updates
function CircularBarStyleTemplate:UpdateVisuals(context)
    if not context then
        return
    end

    -- Update text content with context
    if self.UpdateTexts then
        self:UpdateTexts(context)
    else
    end
end

--- Override text update methods to match v1 circular format (simple values, not full formatted text)
function CircularBarStyleTemplate:UpdateLevelText(context)
    if not self.LevelText then
        return
    end

    -- v1 shows just the level number, not "Level XX"
    local level = (context and context.level) or UnitLevel("player")
    self.LevelText:SetText(tostring(level))
end

function CircularBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText or not context then
        return
    end

    -- v1 shows simple percentage like "45.2%" without quest XP additions
    local maxv = context.xpMax or 1
    local current = context.currentXP or 0

    if XPBarTextFormatter then
        local Addon = XPBarEnhanced
        local decimals = 1
        if Addon and Addon.Database then
            local db = Addon.Database:GetDB()
            if db then
                decimals = db.percentDecimals or 1
            end
        end

        -- Use simple percent formatting (no quest additions)
        local percent = (maxv > 0) and (current / maxv * 100) or 0
        self.PercentText:SetText(string.format("%." .. decimals .. "f%%", percent))
    end
end

function CircularBarStyleTemplate:UpdateRateText(context)
    if not self.RateText or not XPBarTextFormatter then
        return
    end

    -- v1 only shows time to level (not XP/hour)
    local Addon = XPBarEnhanced
    local showTimeToLevel = true

    if Addon and Addon.Database then
        local db = Addon.Database:GetDB()
        if db then
            showTimeToLevel = db.showTimeToLevelText ~= false
        end
    end

    if not showTimeToLevel then
        self.RateText:SetText("")
        return
    end

    -- Get time to level from context or Session service
    local timeToLevel = (context and context.timeToLevel) or 0
    if timeToLevel == 0 and Addon.Session and Addon.Session.GetTimeToLevel then
        timeToLevel = Addon.Session:GetTimeToLevel()
    end

    if timeToLevel > 0 then
        self.RateText:SetText(XPBarTextFormatter:GetTimeToLevelText(timeToLevel))
    else
        self.RateText:SetText("")
    end
end

--- Override bar color update (handled in UpdateSegmentColors)
function CircularBarStyleTemplate:UpdateBarColors(context, barName)
    -- Colors are now applied in UpdateSegmentColors during SetArcProgress
    -- This is kept for compatibility but does nothing
end

--- Override OnHide to clean up animations
function CircularBarStyleTemplate:OnHide()
    -- Cancel any running per-frame arc animation
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    self.isAnimating = false

    -- Call base cleanup
    if XPBarMixinBase_v2 and XPBarMixinBase_v2.OnHide then
        XPBarMixinBase_v2.OnHide(self)
    end
end

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
    position = {mode = "DRAGGABLE", positionKey = "CircularBar_v2"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
CircularBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, CircularBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("circular", CircularBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create CircularBar frame programmatically.
function XPBarEnhanced_CreateCircularBarFrame()
    local styleKey = "circular"

    local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "CircularBarTemplate_v2")
    frame:Show()

    _G.CircularBar_v2 = frame -- Global reference

    return frame
end
