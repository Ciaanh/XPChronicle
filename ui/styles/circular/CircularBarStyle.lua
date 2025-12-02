-- XP Bar Enhanced - CircularBar Style
-- Circular progress ring with optimized 100-segment system
-- Integrates with AnimationManager for standard effects

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

local MAX_SEGMENTS = 100 -- Always create this many (pool size)
local DEFAULT_SEGMENTS = 50 -- Default visible segments

local SEGMENT_TYPE = {
    HIDDEN = -1, -- Not displayed (beyond configured count)
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
    SEGMENT_WIDTH_PX = 5, -- Base width of each segment at 100 segments
    SEGMENT_HEIGHT_PX = 15, -- Height of each segment in pixels
    SEGMENT_TEXTURE_PATH_SOLID = "Interface\\Buttons\\WHITE8X8", -- Solid texture for segments
    SEGMENT_TEXTURE_PATH = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar" -- Texture for each segment
}

-- Reference segment count for base width (segments are wider with fewer count)
local REFERENCE_SEGMENT_COUNT = 100

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

--- Get the configured number of segments to display (from saved settings)
-- @return number: Number of segments to display (clamped to 20-100)
function CircularBarStyleTemplate:GetDisplaySegmentCount()
    local Addon = XPBarEnhanced
    local count = DEFAULT_SEGMENTS
    if Addon and Addon.db then
        local saved = Addon.db.circularSegments
        if type(saved) == "number" then
            count = saved
        else
            -- Migrate any boolean/invalid saved values to default
            if saved ~= nil then
                Addon.db.circularSegments = DEFAULT_SEGMENTS
            end
        end
    end
    -- Clamp to valid range
    -- normalize to integer and clamp
    count = math.floor(tonumber(count) or DEFAULT_SEGMENTS)
    return math.max(25, math.min(100, count))
end

--- Calculate segment width based on display count
-- Wider segments for fewer count to maintain visual ring coverage
-- @param displayCount number: Number of segments being displayed
-- @return number: Width in pixels for each segment
function CircularBarStyleTemplate:GetSegmentWidth(displayCount)
    -- Scale width inversely with segment count
    -- At 100 segments: base width (5px)
    -- At 20 segments: 5x wider (25px)
    local baseWidth = CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX
    local scaleFactor = REFERENCE_SEGMENT_COUNT / displayCount
    return baseWidth * scaleFactor
end

function CircularBarStyleTemplate:CreateRingSegments()
    -- Create full pool of segments (all hidden initially)
    local color = EMPTY_SEGMENT_COLOR
    for i = 1, MAX_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(CIRCULAR_BAR_STYLE.SEGMENT_TEXTURE_PATH)
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(color.r, color.g, color.b, color.a)
        segment:Hide() -- Start hidden
        self.segments[i] = segment
        self.segmentTypes[i] = SEGMENT_TYPE.HIDDEN
    end

    -- Position and show only the configured number
    self:RepositionSegments()
end

--- Reposition segments based on current config (called on config change)
function CircularBarStyleTemplate:RepositionSegments()
    local displayCount = self:GetDisplaySegmentCount()
    local clockwise = -1
    local placementRadius = CIRCULAR_BAR_STYLE.RING_RADIUS_PX

    -- Calculate segment width based on count (wider for fewer segments)
    local segmentWidth = self:GetSegmentWidth(displayCount)
    local segmentHeight = CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX

    -- Localize heavy math functions for the inner loop
    local math_cos = math.cos
    local math_sin = math.sin
    local math_pi = math.pi

    -- Start at 6 o'clock (bottom) and increase angle -> clockwise in WoW (y positive = down)
    local startAngle = math_pi / 2
    local fullCircle = 2 * math_pi

    -- Position visible segments
    for i = 1, displayCount do
        local angle = startAngle + ((i - 1) / displayCount) * fullCircle

        -- Offsets relative to frame center (use CENTER anchor)
        local xOff = math_cos(angle) * placementRadius
        local yOff = math_sin(angle) * placementRadius * clockwise
        local rotation = (clockwise * angle) + startAngle

        -- Position and size segment
        local segment = self.segments[i]
        segment:SetSize(segmentWidth, segmentHeight)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
        segment:Show()
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Hide excess segments beyond displayCount
    for i = displayCount + 1, MAX_SEGMENTS do
        local segment = self.segments[i]
        if segment then
            segment:Hide()
            self.segmentTypes[i] = SEGMENT_TYPE.HIDDEN
        end
    end

    -- Re-apply current progress colors after repositioning
    if self.Refresh then
        self:Refresh()
    end
end

-------------------------------------------------------------------
--  ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    -- During level-up Phase 1 (animating to 100%), hide overlays to avoid visual artifacts
    -- The context contains new level data, but we're animating the old level's progress
    local contextToUse = eventContext
    if iterationData.isLevelUpPhase1 then
        -- Create a modified context that hides overlays during Phase 1
        contextToUse = {
            -- Copy essential fields from eventContext
            hasRestedXP = eventContext.hasRestedXP,
            xpMax = eventContext.preLevelXPMax or eventContext.xpMax or 1,
            currentXP = math.floor((iterationData.currentRatio or 0) * (eventContext.preLevelXPMax or eventContext.xpMax or 1)),
            -- Hide all overlays during Phase 1
            showQuestXP = false,
            showCompleteQuestOverlay = false,
            showIncompleteQuestOverlay = false,
            showRestedOverlay = false,
            completeQuestXP = 0,
            incompleteQuestXP = 0,
            restedXP = 0
        }
    end
    
    -- Update the arc progress with current ratio
    -- Pass hasRestedXP from eventContext to ensure correct coloring
    -- Pass complete event context into SetArcProgress to ensure the style
    -- uses fresh flags (showQuestXP, showCompleteQuestOverlay, etc.) during animation.
    self:SetArcProgress(iterationData.currentRatio, contextToUse, iterationData.questOverlayAlpha)
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
        -- Show glow with animated alpha
        self.GainFlash:SetAlpha(flashData.currentAlpha)
        self.GainFlash:Show()
    else
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
-- @param context table: Immutable context with all state and flags
-- @param overlayAlpha number: Optional alpha for overlay segments
function CircularBarStyleTemplate:SetArcProgress(progress, context, overlayAlpha)
    -- Defensive: if context is nil, return silently rather than raising errors.
    if not context then
        return
    end

    local totalSegments = self:GetDisplaySegmentCount()

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

    -- Apply colors
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

    -- Only process visible segments
    local totalSegments = self:GetDisplaySegmentCount()

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
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

-- OVERRIDES
--- Single render method for circular bar ( unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    self._lastLevel = context.level

    -- Calculate target ratio (use currentXP as canonical field)
    local targetRatio = self:CalculateTargetRatio(context)

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end

    -- Update overlays FIRST (always update, matches Classic/Vertical pattern)
    -- These populate the cached overlay data that SetArcProgress uses.
    -- Doing this before the UpdateGainedBar / SetArcProgress call ensures the
    -- Circular style uses the latest context values (e.g., when toggling
    -- quest XP or on level-up) and avoids showing stale overlay colors.
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

    -- Render at final position (no animation decision - BaseMixin handles that)
    self:UpdateGainedBar(targetRatio, context)

    -- Update text (always update, matches Classic/Vertical pattern)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

-- OVERRIDES
--- Render all bar elements for a single animation frame
--- Called by AnimationManager on each tick, or once for instant updates
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:UpdateGainedBar(currentRatio, context)
    -- Pass full context so SetArcProgress can prefer context values and avoid stale cached data
    self:SetArcProgress(currentRatio, context)

    -- Update current ratio tracking
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    if self.UpdateTexts then
        self:UpdateTexts(context)
    end

    -- Note: Overlays are handled inside SetArcProgress for circular bar
    -- SetArcProgress calculates segment types for: current XP, rested, quest complete, quest incomplete
end

-------------------------------------------------------------------
-- OVERRIDES for circular layout
-------------------------------------------------------------------

-- Override UpdateRestedBar to store rested data for segment coloring
function CircularBarStyleTemplate:UpdateRestedBar(context)
    local targetRatio = self:CalculateTargetRatio(context)
    self:SetArcProgress(targetRatio, context)
end

function CircularBarStyleTemplate:UpdateQuestCompleteBar(context)
    if not context then
        return
    end

    local targetRatio = self:CalculateTargetRatio(context)
    self:SetArcProgress(targetRatio, context)
end

function CircularBarStyleTemplate:UpdateQuestIncompleteBar(context)
    local targetRatio = self:CalculateTargetRatio(context)
    self:SetArcProgress(targetRatio, context)
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
    local Addon = XPBarEnhanced

    if not self.PercentText or not context or not Addon.TextFormatter then
        return
    end

    -- shows simple percentage like "45.2%" without quest XP additions
    local maxv = context.xpMax or 1
    local current = context.currentXP or 0
    if Addon.TextFormatter then
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
    local Addon = XPBarEnhanced

    if not self.RateText or not Addon.TextFormatter then
        return
    end

    -- only shows time to level (not XP/hour)
    local showTimeToLevel = Addon.ConfigHelper.GetShowTimeToLevelText(context)

    if not showTimeToLevel then
        self.RateText:SetText("")
        return
    end

    -- Get time to level from context or Session service
    local timeToLevel =
        (context and context.timeToLevel) or
        (Addon.Session and Addon.Session.GetTimeToLevel and Addon.Session:GetTimeToLevel()) or
        0

    if timeToLevel > 0 then
        self.RateText:SetText(Addon.TextFormatter:GetTimeToLevelText(timeToLevel))
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
    totalSegments = totalSegments or self:GetDisplaySegmentCount()

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
    local completeXPUsed = 0
    if
        context.showQuestXP and context.showCompleteQuestOverlay and (context.completeQuestXP or 0) > 0 and
            remainingXP > 0
     then
        completeXPUsed = math.min(context.completeQuestXP, remainingXP)
        remainingXP = math.max(0, remainingXP - completeXPUsed)
    end

    local incompleteXPUsed = 0
    if
        context.showQuestXP and context.showIncompleteQuestOverlay and (context.incompleteQuestXP or 0) > 0 and
            remainingXP > 0
     then
        incompleteXPUsed = math.min(context.incompleteQuestXP, remainingXP)
        remainingXP = math.max(0, remainingXP - incompleteXPUsed)
    end

    local restedXPUsed = 0
    if context.showRestedOverlay and (context.restedXP or 0) > 0 and remainingXP > 0 then
        restedXPUsed = math.min(context.restedXP, remainingXP)
        remainingXP = math.max(0, remainingXP - restedXPUsed)
    end

    -- Compute target total filled segments based on combined XP
    local combinedXP = currentXP + completeXPUsed + incompleteXPUsed + restedXPUsed
    local totalFillSegments = self:CountSegmentsToDisplay((combinedXP / xpMax), totalSegments)

    -- Compute initial floor-based counts for overlays (clamped by available slots)
    local slotsRemaining = totalSegments - currentXPSegments

    local completeCount = 0
    if completeXPUsed > 0 and slotsRemaining > 0 then
        completeCount = self:CountSegmentsToDisplay((completeXPUsed / xpMax), totalSegments)
        completeCount = math.max(0, math.min(completeCount, slotsRemaining))
        slotsRemaining = slotsRemaining - completeCount
    end

    local incompleteCount = 0
    if incompleteXPUsed > 0 and slotsRemaining > 0 then
        incompleteCount = self:CountSegmentsToDisplay((incompleteXPUsed / xpMax), totalSegments)
        incompleteCount = math.max(0, math.min(incompleteCount, slotsRemaining))
        slotsRemaining = slotsRemaining - incompleteCount
    end

    local restedCount = 0
    if restedXPUsed > 0 and slotsRemaining > 0 then
        restedCount = self:CountSegmentsToDisplay((restedXPUsed / xpMax), totalSegments)
        restedCount = math.max(0, math.min(restedCount, slotsRemaining))
        slotsRemaining = slotsRemaining - restedCount
    end

    -- If rounding leaves a deficit compared to combined total, distribute deficit deterministically
    local filled = currentXPSegments + completeCount + incompleteCount + restedCount
    if filled < totalFillSegments then
        local deficit = totalFillSegments - filled
        while deficit > 0 and (completeCount + incompleteCount + restedCount + currentXPSegments) < totalSegments do
            -- Allocate to complete first, then incomplete, then rested
            if
                completeXPUsed > 0 and
                    (completeCount < (totalSegments - currentXPSegments - incompleteCount - restedCount))
             then
                completeCount = completeCount + 1
            elseif
                incompleteXPUsed > 0 and
                    (incompleteCount < (totalSegments - currentXPSegments - completeCount - restedCount))
             then
                incompleteCount = incompleteCount + 1
            elseif
                restedXPUsed > 0 and
                    (restedCount < (totalSegments - currentXPSegments - completeCount - incompleteCount))
             then
                restedCount = restedCount + 1
            else
                -- No place to allocate more; break out
                break
            end
            deficit = deficit - 1
        end
    end

    -- Assign results + starts
    result.completeCount = completeCount
    result.completeStart = currentXPSegments + 1

    result.incompleteCount = incompleteCount
    result.incompleteStart = currentXPSegments + 1 + completeCount

    result.restedCount = restedCount
    result.restedStart = currentXPSegments + 1 + completeCount + incompleteCount

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
