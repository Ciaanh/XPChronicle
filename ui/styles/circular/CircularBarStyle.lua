-- XP Bar Enhanced - CircularBar Style
-- Circular progress ring with optimized 100-segment system
-- Integrates with  AnimationManager for standard effects

-- what if you were to keep only the bar style and recreate a clean version of the project from the
-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "CircularBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local RING_SEGMENTS = 50 -- Number of segments to display

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
    SEGMENT_WIDTH_PX = 5, -- Width of each segment in pixels
    SEGMENT_HEIGHT_PX = 15, -- Height of each segment in pixels
    SEGMENT_TEXTURE_PATH_SOLID = "Interface\\Buttons\\WHITE8X8", -- Solid texture for segments
    SEGMENT_TEXTURE_PATH = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar" -- Texture for each segment
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

    -- Create ring segments (initialized with background color)
    self:CreateRingSegments()

    -- Call base OnLoad (initializes animation system and calls Refresh)
    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
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
        segment:SetTexture(CIRCULAR_BAR_STYLE.SEGMENT_TEXTURE_PATH)
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(color.r, color.g, color.b, color.a)
        segment:Show()
        self.segments[i] = segment
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

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
--  ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    -- Update the arc progress with current ratio
    -- Pass hasRestedXP from eventContext to ensure correct coloring
    -- Pass complete event context into SetArcProgress to ensure the style
    -- uses fresh flags (showQuestXP, showCompleteQuestOverlay, etc.) during animation.
    self:SetArcProgress(iterationData.currentRatio, eventContext, iterationData.questOverlayAlpha)
end

--- Update visual effects - glow overlay animation
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end

    local flashData = iterationData.flashData
    local flashActive = flashData and flashData.active and flashData.currentAlpha > 0
    if flashActive then
        -- Apply quest overlay dimming for circular segments by reapplying
        -- segment colors with overlayAlpha = iterationData.questOverlayAlpha
        -- if iterationData and iterationData.questOverlayAlpha then
        --     local currentRatio = self._currentRatio or self.lastProgress or 0
        --     -- Recompute colors with overlayAlpha multiplier
        --     self:SetArcProgress(currentRatio, eventContext, iterationData.questOverlayAlpha)
        -- end
        -- Track that we've seen a flash so that we can restore on completion even
        -- if iterationData.questOverlayAlpha is not provided on the final frame
        --self._hadFlash = true
        -- Show glow with animated alpha
        self.GainFlash:SetAlpha(flashData.currentAlpha)
        self.GainFlash:Show()
    else
        -- Ensure segments are at normal alpha when flash ends.
        -- Some styles use iterationData.questOverlayAlpha; circular may not
        -- receive a non-nil value in iterationData. Track the transition from
        -- an active flash to ended flash with _hadFlash and force a restore so
        -- we don't leave dimmed segments around.
        -- if self._hadFlash then
        --     local currentRatio = self._currentRatio or self.lastProgress or 0
        --     self:SetArcProgress(currentRatio, eventContext, 1.0)
        --     self._hadFlash = nil
        -- end
        self.GainFlash:Hide()
    end
end

-------------------------------------------------------------------
-- OPTIMIZED SEGMENT MANAGEMENT
-------------------------------------------------------------------

function CircularBarStyleTemplate:CountSegmentsToDisplay(progress, totalSegments)
    local segments = math.floor(progress * totalSegments)
    segments = math.max(0, math.min(segments, totalSegments))
    return segments
end

--- Set arc progress and calculate all segment types in one pass
-- @param progress number: Progress ratio (0-1)
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:SetArcProgress(progress, context, overlayAlpha)
    -- Require a valid context (do not rebuild or fallback to DB)
    if not context then
        error("SetArcProgress requires an explicit immutable context")
    end

    local totalSegments = RING_SEGMENTS or 100

    -- DO NOT accept overlaySegments from context; compute them internally so
    -- the segment computation remains an internal concern of the style.
    local overlaySegments = self:ComputeOverlaySegments(progress, context, totalSegments)

    -- Reset segment types to empty
    for i = 1, totalSegments do
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Fill current XP
    for i = 1, overlaySegments.currentXPSegments do
        self.segmentTypes[i] = SEGMENT_TYPE.CURRENT_XP
    end

    -- Fill quest complete overlay if present
    if overlaySegments.completeCount and overlaySegments.completeCount > 0 then
        local start = overlaySegments.completeStart
        local last = math.min(start + overlaySegments.completeCount - 1, totalSegments)
        for i = start, last do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_COMPLETE
        end
    end

    -- Fill quest incomplete overlay if present
    if overlaySegments.incompleteCount and overlaySegments.incompleteCount > 0 then
        local start = overlaySegments.incompleteStart
        local last = math.min(start + overlaySegments.incompleteCount - 1, totalSegments)
        for i = start, last do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_INCOMPLETE
        end
    end

    -- Fill rested overlay if present (use only empty segments)
    if overlaySegments.restedCount and overlaySegments.restedCount > 0 then
        local start = overlaySegments.restedStart
        local last = math.min(start + overlaySegments.restedCount - 1, totalSegments)
        for i = start, last do
            if self.segmentTypes[i] == SEGMENT_TYPE.EMPTY then
                self.segmentTypes[i] = SEGMENT_TYPE.RESTED
            end
        end
    end

    -- Apply colors - pass hasRestedXP from the context explicitly
    local hasRestedXP = context.hasRestedXP == true
    self:UpdateSegmentColors(hasRestedXP, overlayAlpha)
end

--- Apply colors to segments based on their type
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:UpdateSegmentColors(hasRestedXP, overlayAlpha)
    local XPBarColors = _G.XPBarColors
    local colorNormal = XPBarColors:GetUserColor(Color.XpBar)
    local colorRested = XPBarColors:GetUserColor(Color.Rested)
    local colorXpBarRested = XPBarColors:GetUserColor(Color.XpBarRested)
    local colorQuestComplete = XPBarColors:GetUserColor(Color.QuestComplete)
    local colorQuestIncomplete = XPBarColors:GetUserColor(Color.QuestIncomplete)

    -- Use provided parameter only; no fallback to persistent cached values
    hasRestedXP = hasRestedXP == true
    overlayAlpha = overlayAlpha or 1.0

    local currentXPColor = hasRestedXP and colorXpBarRested or colorNormal

    -- Determine progress (prefer current ratio from animation, fall back to lastProgress)
    local totalSegments = RING_SEGMENTS

    for i = 1, totalSegments do
        local segment = self.segments[i]
        if not segment then
            -- missing texture, skip
        else
            -- default empty appearance
            local color = EMPTY_SEGMENT_COLOR

            -- not part of main fill; check overlay type
            local segType = self.segmentTypes[i]
            if segType == SEGMENT_TYPE.CURRENT_XP then
                -- Use exact color from config
                if currentXPColor and currentXPColor.r then
                    color = {
                        r = currentXPColor.r,
                        g = currentXPColor.g,
                        b = currentXPColor.b,
                        a = (currentXPColor.a or 1) * overlayAlpha
                    }
                end
            elseif segType == SEGMENT_TYPE.QUEST_COMPLETE then
                -- Use exact color from config
                if colorQuestComplete and colorQuestComplete.r then
                    color = {
                        r = colorQuestComplete.r,
                        g = colorQuestComplete.g,
                        b = colorQuestComplete.b,
                        a = (colorQuestComplete.a or 1) * overlayAlpha
                    }
                end
            elseif segType == SEGMENT_TYPE.QUEST_INCOMPLETE then
                -- Use exact color from config
                if colorQuestIncomplete and colorQuestIncomplete.r then
                    color = {
                        r = colorQuestIncomplete.r,
                        g = colorQuestIncomplete.g,
                        b = colorQuestIncomplete.b,
                        a = (colorQuestIncomplete.a or 1) * overlayAlpha
                    }
                end
            elseif segType == SEGMENT_TYPE.RESTED then
                -- Use exact color from config with ADD blend mode (v1 behavior)
                if colorRested and colorRested.r then
                    color = colorRested
                end
            else
                -- EMPTY remains default
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

    local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")

    if not context then
        return
    end

    -- Call TriggerBarRefresh ( method name)
    if self.TriggerBarRefresh then
        self:TriggerBarRefresh(context)
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

    -- Trigger bar refresh through orchestration layer
    -- RenderBar will update overlays, so we don't do it here (no duplication)
    if self.TriggerBarRefresh then
        self:TriggerBarRefresh(context)
    end

    -- Update text visibility in case options changed
    if self.UpdateTextVisibility then
        self:UpdateTextVisibility(context)
    end

    self._isUpdating = nil
end

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN (Phase 2: Refactor)
-------------------------------------------------------------------

--- Single render method for circular bar ( unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    self._lastLevel = context.level

    -- Calculate target ratio (use currentXP as canonical field)
    local targetRatio = 0
    if context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end

    -- Update overlays FIRST (always update, matches Classic/Vertical pattern)
    -- These populate the cached overlay data that SetArcProgress uses.
    -- Doing this before the RenderBarFrame / SetArcProgress call ensures the
    -- Circular style uses the latest context values (e.g., when toggling
    -- quest XP or on level-up) and avoids showing stale overlay colors.
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

    -- Render at final position (no animation decision - BaseMixin handles that)
    self:RenderBarFrame(targetRatio, context)

    -- Update text (always update, matches Classic/Vertical pattern)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

--- Render all bar elements for a single animation frame
--- Called by AnimationManager on each tick, or once for instant updates
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:RenderBarFrame(currentRatio, context)
    -- 1. MAIN BAR (at current animation position)
    -- Pass full context so SetArcProgress can prefer context values and avoid stale cached data
    self:SetArcProgress(currentRatio, context)

    -- Update current ratio tracking
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    -- 2. TEXT (updates every frame to show animated values)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end

    -- Note: Overlays are handled inside SetArcProgress for circular bar
    -- SetArcProgress calculates segment types for: current XP, rested, quest complete, quest incomplete
    -- This is the IDEAL pattern - all segments calculated and colored in one pass!
end

-------------------------------------------------------------------
-- OVERRIDES for circular layout
---------------------------------------------------------------------- Override UpdateRestedOverlay to store rested data for segment coloring
function CircularBarStyleTemplate:UpdateRestedOverlay(context)
    if not context then
        return
    end

    local currentRatio = (context.currentXP or 0) / context.xpMax
    self:SetArcProgress(currentRatio, context)
end

function CircularBarStyleTemplate:UpdateQuestCompleteOverlay(context)
    if not context then
        return
    end

    local currentRatio = (context.currentXP or 0) / context.xpMax
    self:SetArcProgress(currentRatio, context)
end

function CircularBarStyleTemplate:UpdateQuestIncompleteOverlay(context)
    if not context then
        return
    end

    local currentRatio = (context.currentXP or 0) / context.xpMax
    self:SetArcProgress(currentRatio, context)
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
    if XPBarMixinBase and XPBarMixinBase.OnHide then
        XPBarMixinBase.OnHide(self)
    end
end

-------------------------------------------------------------------
-- OVERLAY HELPERS (must be defined before style registration)
-------------------------------------------------------------------

--- Compute overlay segment ranges purely from provided context (no DB fallback, no persistent cache)
-- @param context table: Immutable context with xp/current/rested/quest values and show flags
-- @param totalSegments number: Number of ring segments (RING_SEGMENTS)
-- @param currentXPSegments number: Number of segments filled by current XP
-- @return table { completeCount, completeStart, incompleteCount, incompleteStart, restedCount, restedStart }
function CircularBarStyleTemplate:ComputeOverlaySegments(progress, context, totalSegments)
    totalSegments = totalSegments or RING_SEGMENTS or 100

    local currentProgress = math.max(0, math.min(progress or 0, 1))

    local currentXPSegments = self:CountSegmentsToDisplay(currentProgress, totalSegments)
    currentXPSegments = math.max(0, math.min(currentXPSegments, totalSegments))

    local result = {
        currentXPSegments = currentXPSegments,
        completeCount = 0,
        completeStart = currentXPSegments + 1,
        incompleteCount = 0,
        incompleteStart = currentXPSegments + 1,
        restedCount = 0,
        restedStart = currentXPSegments + 1
    }

    if not context then
        error("ComputeOverlaySegments requires an explicit immutable context")
    end

    local xpMax = context.xpMax or 0
    if xpMax <= 0 then
        return result
    end

    local currentXP = context.currentXP or 0
    local remainingXP = math.max(0, xpMax - currentXP)

    -- Quest complete overlay
    if
        context.showQuestXP and context.showCompleteQuestOverlay and (context.completeQuestXP or 0) > 0 and
            remainingXP > 0
     then
        local completeXP = math.min(context.completeQuestXP, remainingXP)
        local completeRatio = completeXP / xpMax
        local count = self:CountSegmentsToDisplay(completeRatio, totalSegments)
        count = math.max(0, math.min(count, totalSegments - currentXPSegments))
        result.completeCount = count
        result.completeStart = currentXPSegments + 1
        remainingXP = math.max(0, remainingXP - completeXP)
    end

    -- Quest incomplete overlay
    if
        context.showQuestXP and context.showIncompleteQuestOverlay and (context.incompleteQuestXP or 0) > 0 and
            remainingXP > 0
     then
        local incompleteXP = math.min(context.incompleteQuestXP, remainingXP)
        local incompleteRatio = incompleteXP / xpMax
        local count = self:CountSegmentsToDisplay(incompleteRatio, totalSegments)
        local maxAvailable = totalSegments - currentXPSegments - result.completeCount
        count = math.max(0, math.min(count, maxAvailable))
        result.incompleteCount = count
        result.incompleteStart = currentXPSegments + 1 + result.completeCount
        remainingXP = math.max(0, remainingXP - incompleteXP)
    end

    -- Rested overlay (applies only to empty segments after above overlays)
    if context.showRestedOverlay and (context.restedXP or 0) > 0 and remainingXP > 0 then
        local restedXP = math.min(context.restedXP, remainingXP)
        local restedRatio = restedXP / xpMax
        local count = self:CountSegmentsToDisplay(restedRatio, totalSegments)
        local maxAvailable = totalSegments - currentXPSegments - result.completeCount - result.incompleteCount
        count = math.max(0, math.min(count, maxAvailable))
        result.restedCount = count
        result.restedStart = currentXPSegments + 1 + result.completeCount + result.incompleteCount
    end

    return result
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
    position = {mode = "DRAGGABLE", positionKey = "CircularBar"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
CircularBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, CircularBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("circular", CircularBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create CircularBar frame programmatically.
function XPBarEnhanced_CreateCircularBarFrame()
    local styleKey = "circular"

    local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "CircularBarTemplate")
    frame:Show()

    _G.CircularBar = frame -- Global reference

    return frame
end
