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

    -- Call base OnLoad (initializes animation system and calls Refresh)
    -- Base OnLoad will handle the initial RenderBar call via Refresh()
    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "Calling base OnLoad") end
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
--  ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "AnimateBarPosition called", iterationData.currentRatio) end
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
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "AnimateBarEffect called", tostring(flashData)) end
    local flashActive = flashData and flashData.active and flashData.currentAlpha > 0
    if flashActive then
        -- Show glow with animated alpha
        self.GainFlash:SetAlpha(flashData.currentAlpha)
        self.GainFlash:Show()
        -- Apply quest overlay dimming for circular segments by reapplying
        -- segment colors with overlayAlpha = iterationData.questOverlayAlpha
        if iterationData and iterationData.questOverlayAlpha then
            local currentRatio = self._currentRatio or self.lastProgress or 0
            -- Recompute colors with overlayAlpha multiplier
            self:SetArcProgress(currentRatio, eventContext, iterationData.questOverlayAlpha)
        end
        -- Track that we've seen a flash so that we can restore on completion even
        -- if iterationData.questOverlayAlpha is not provided on the final frame
        self._hadFlash = true
    else
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "Hide glow") end
        self.GainFlash:Hide()
        -- Ensure segments are at normal alpha when flash ends.
        -- Some styles use iterationData.questOverlayAlpha; circular may not
        -- receive a non-nil value in iterationData. Track the transition from
        -- an active flash to ended flash with _hadFlash and force a restore so
        -- we don't leave dimmed segments around.
        if self._hadFlash then
            local currentRatio = self._currentRatio or self.lastProgress or 0
            self:SetArcProgress(currentRatio, eventContext, 1.0)
            self._hadFlash = nil
        end
    end
end

-------------------------------------------------------------------
-- OPTIMIZED SEGMENT MANAGEMENT
-------------------------------------------------------------------

--- Set arc progress and calculate all segment types in one pass
-- @param progress number: Progress ratio (0-1)
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:SetArcProgress(progress, context, overlayAlpha)
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "SetArcProgress called with progress", tostring(progress), "showQuestXP:", tostring(context and context.showQuestXP), "completeQuestXP:", tostring((context and context.completeQuestXP) or self.cachedCompleteQuestXP)) end
    -- Calculate current XP segments (1 segment = 1%)
    local currentXPSegments = math.floor(progress * 100 + 0.5)

    -- Get current XP and max for ratio calculations
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")

    -- Prefer context values first, fall back to cached or DB values
    local restedXP = (context and context.restedXP) or self.cachedRestedXP or 0
    local completeQuestXP = (context and context.completeQuestXP) or self.cachedCompleteQuestXP or 0
    local incompleteQuestXP = (context and context.incompleteQuestXP) or self.cachedIncompleteQuestXP or 0

    -- Overlay config flags: prefer context values if provided, otherwise DB as fallback
    local Addon = XPBarEnhanced
    local db = (Addon and Addon.Database) and Addon.Database:GetDB()
    local showQuestXP = true
    local showComplete = true
    local showIncomplete = false
    if context and context.showQuestXP ~= nil then
        showQuestXP = context.showQuestXP
    elseif db and db.showQuestXP ~= nil then
        showQuestXP = db.showQuestXP ~= false
    end
    if context and context.showCompleteQuestOverlay ~= nil then
        showComplete = context.showCompleteQuestOverlay
    elseif db and db.showCompleteQuestOverlay ~= nil then
        showComplete = db.showCompleteQuestOverlay ~= false
    end
    if context and context.showIncompleteQuestOverlay ~= nil then
        showIncomplete = context.showIncompleteQuestOverlay
    elseif db and db.showIncompleteQuestOverlay ~= nil then
        showIncomplete = db.showIncompleteQuestOverlay == true
    end

    -- Compute whether we have rested XP, prefer context then cached
    local hasRestedXP = (context and context.hasRestedXP) or self.cachedHasRestedXP or (restedXP and restedXP > 0)

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
    self:UpdateSegmentColors(progress, hasRestedXP, overlayAlpha)
end

--- Apply colors to segments based on their type
-- @param hasRestedXP boolean: Whether player has rested XP available
function CircularBarStyleTemplate:UpdateSegmentColors(progress, hasRestedXP, overlayAlpha)
    local XPBarColors = _G.XPBarColors
    local colorNormal = XPBarColors:GetUserColor(Color.XpBar)
    local colorRested = XPBarColors:GetUserColor(Color.Rested)
    local colorXpBarRested = XPBarColors:GetUserColor(Color.XpBarRested)
    local colorQuestComplete = XPBarColors:GetUserColor(Color.QuestComplete)
    local colorQuestIncomplete = XPBarColors:GetUserColor(Color.QuestIncomplete)

    -- Use provided progress or fallback
    progress = progress or self._currentRatio or self.lastProgress or 0

    -- Use parameter or fallback to cached value
    hasRestedXP = hasRestedXP or self.cachedHasRestedXP or false
    overlayAlpha = overlayAlpha or 1.0

    -- Use Rested color for current XP bar when player has rested XP (matches flatbar)
    local currentXPColor = hasRestedXP and colorXpBarRested or colorNormal

    -- Determine progress (prefer current ratio from animation, fall back to lastProgress)
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
                        color = {r=colorQuestComplete.r, g=colorQuestComplete.g, b=colorQuestComplete.b, a=(colorQuestComplete.a or 1) * overlayAlpha}
                    end
                elseif segType == SEGMENT_TYPE.QUEST_INCOMPLETE then
                    -- Use exact color from config
                    if colorQuestIncomplete and colorQuestIncomplete.r then
                        color = {r=colorQuestIncomplete.r, g=colorQuestIncomplete.g, b=colorQuestIncomplete.b, a=(colorQuestIncomplete.a or 1) * overlayAlpha}
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
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "Refresh override called") end
    
    -- Build context
    if not XPBarContextBuilder then
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "ERROR: XPBarContextBuilder not found") end
        return
    end

    local context = XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")

    if not context then
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "ERROR: Context building failed") end
        return
    end

    -- Call TriggerBarRefresh ( method name)
    if self.TriggerBarRefresh then
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "Calling TriggerBarRefresh") end
        self:TriggerBarRefresh(context)
    else
        if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "ERROR: TriggerBarRefresh not found") end
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
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "RenderBar called") end
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

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

    -- Defensive: if quest XP is disabled, ensure cached values are cleared
    if context and context.showQuestXP == false then
        self.cachedCompleteQuestXP = 0
        self.cachedIncompleteQuestXP = 0
    end

    -- Render at final position (no animation decision - BaseMixin handles that)
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "RenderBar calling RenderBarFrame with ratio:", targetRatio) end
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
    if XPBarDebugLog then XPBarDebugLog:Log("CircularBar", "RenderBarFrame called with ratio:", currentRatio) end
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

    -- Store rested data for SetArcProgress to use
    if context.showRestedOverlay == false then
        self.cachedRestedXP = 0
        self.cachedHasRestedXP = false
    else
        self.cachedRestedXP = context.restedXP or 0
        self.cachedHasRestedXP = context.hasRestedXP or false
    end

    -- Force a redraw so rested overlay changes are reflected immediately
    local currentRatio = self._currentRatio or self.lastProgress or 0
    self:SetArcProgress(currentRatio, context)
end

--- Override UpdateQuestCompleteOverlay to store quest complete data for segment coloring
function CircularBarStyleTemplate:UpdateQuestCompleteOverlay(context)
    if not context then
        return
    end

    -- Store quest complete data for SetArcProgress to use
    if context.showQuestXP == false then
        -- If quest XP is disabled in context, clear cached values
        self.cachedCompleteQuestXP = 0
    else
        self.cachedCompleteQuestXP = context.completeQuestXP or 0
    end

    -- Force a redraw to ensure segments respond immediately when toggling showQuestXP
    local currentRatio = self._currentRatio or self.lastProgress or 0
    self:SetArcProgress(currentRatio, context)
end

--- Override UpdateQuestIncompleteOverlay to store quest incomplete data for segment coloring
function CircularBarStyleTemplate:UpdateQuestIncompleteOverlay(context)
    if not context then
        return
    end

    -- Store quest incomplete data for SetArcProgress to use
    if context.showQuestXP == false then
        -- If quest XP is disabled in context, clear cached values
        self.cachedIncompleteQuestXP = 0
    else
        self.cachedIncompleteQuestXP = context.incompleteQuestXP or 0
    end

    -- Force a redraw to ensure segments respond immediately when toggling showQuestXP
    local currentRatio = self._currentRatio or self.lastProgress or 0
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
