# Animation System Refactor Plan - Detailed Implementation
## Unified RenderBarFrame Integration with Context Optimization

**Created**: November 11, 2025  
**Target**: XP Bar Enhanced  Animation Architecture  
**Goals**: 
1. Integrate RenderBarFrame with AnimationManager
2. Optimize context structure and usage
3. Remove deprecated ApplyAnimationStep pattern
4. Achieve dynamic overlay animations

---

## Executive Summary

### Current Issues
1. **Split Animation Pattern**: 3 methods (ApplyAnimationStep → AnimateBarPosition + AnimateBarEffect)
2. **Static Overlays**: Overlays don't react during animation frames
3. **Context Subsetting**: Full context lost when passing to AnimationManager (xpContext subset)
4. **Redundant Data**: Context contains duplicate fields and unnecessary data
5. **Immutability Overhead**: Context made immutable but then cloned for animation frames

### Proposed Solutions
1. **Unified Rendering**: AnimationManager calls `RenderBarFrame(currentRatio, context)` directly
2. **Dynamic Updates**: All elements (bar + overlays + text) update every frame
3. **Full Context Preservation**: Pass complete context to AnimationManager
4. **Context Optimization**: Simplify context structure, reduce duplication
5. **Lazy Context Creation**: Build animation frame contexts efficiently

### Expected Benefits
- **40% fewer method calls** during animation (1 method vs 3)
- **30% smaller context objects** through optimization
- **Dynamic overlays** that react to bar position every frame
- **Simpler codebase** with unified rendering pattern
- **Better performance** through reduced object creation

---

## Phase 1: Context Structure Optimization

### 1.1 Problem Analysis

**Current Context Structure Issues**:

```lua
-- BaseContext created by BuildBaseContext (~30 fields)
{
    -- Core game state (8 fields)
    currentXP, xpMax, remainingXP, level, restedXP, 
    isResting, hasRestedXP, isFullyRested,
    
    -- Event metadata (3 fields)
    event, timestamp, source,
    
    -- Display flags (13 fields) - OPTIMIZATION OPPORTUNITY
    showXPText, showLevelText, showPercentage, 
    showQuestXP, showCompleteQuestOverlay, showIncompleteQuestOverlay,
    showRestedOverlay, showExhaustionTick, 
    showSessionTimeText, showLevelTimeText, 
    showXPPerHourText, showTimeToLevelText,
    
    -- Configuration (3 fields) - OPTIMIZATION OPPORTUNITY
    percentDecimals, abbreviateNumbers, 
    showRemainingXP, showQuestPercent,
    
    -- Extended by event-specific builders:
    -- XP Change adds: 17+ fields
    -- Level Up adds: 12+ fields
    -- Quest/Rested adds: 5+ fields
}
```

**Problems**:
1. **Too Many Fields**: 30+ fields in base context, 45+ after extension
2. **Display Flags Repeated**: Same 13 flags in every context (rarely change)
3. **Config Values Repeated**: Same 3 config values in every context (static)
4. **Unnecessary Fields**: `event`, `timestamp`, `source` rarely used
5. **Duplicate Calculations**: `remainingXP = xpMax - currentXP` (can be calculated on demand)

**Impact**:
- 📊 **~1KB per context object** (45 fields × 8 bytes overhead + string keys)
- 🔄 **60+ context objects/second** during animation (60 FPS)
- 💾 **~60KB/sec memory churn** during animation
- ⏱️ **Copy overhead** for immutability + animation frame contexts

---

### 1.2 Optimized Context Structure

#### Core Principle: Separate Static from Dynamic

**Level 1: Static Config (Created Once, Shared)**
```lua
-- Created once on addon load, referenced by all contexts
XPBarStaticConfig = {
    -- Display flags (13 fields)
    showXPText = true,
    showLevelText = true,
    showPercentage = true,
    showQuestXP = true,
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    showRestedOverlay = true,
    showExhaustionTick = true,
    showSessionTimeText = true,
    showLevelTimeText = true,
    showXPPerHourText = true,
    showTimeToLevelText = true,
    
    -- Configuration (4 fields)
    percentDecimals = 1,
    abbreviateNumbers = true,
    showRemainingXP = false,
    showQuestPercent = false
}

-- Updated when user changes settings
function UpdateStaticConfig()
    local db = XPBarEnhanced.db
    for key in pairs(XPBarStaticConfig) do
        if db[key] ~= nil then
            XPBarStaticConfig[key] = db[key]
        end
    end
end
```

**Level 2: Core Context (Dynamic Game State)**
```lua
-- Minimal context with only dynamic fields
CoreContext = {
    -- Core XP state (5 fields) - 40 bytes
    currentXP = 1234,
    xpMax = 5000,
    level = 45,
    restedXP = 500,
    hasRestedXP = true,
    
    -- Quest state (2 fields) - 16 bytes
    completeQuestXP = 300,
    incompleteQuestXP = 150,
    
    -- Session state (4 fields) - 32 bytes
    sessionXP = 2000,
    sessionSeconds = 1800,
    levelSeconds = 3600,
    xpPerHour = 4000,
    
    -- Reference to static config (1 field) - 8 bytes
    config = XPBarStaticConfig,
    
    -- Total: 12 fields, ~96 bytes (vs 1KB before)
}
```

**Level 3: Event Context (Core + Event Flags)**
```lua
-- Extended for specific events
XPChangeContext = {
    -- Include all CoreContext fields via metatable inheritance
    __index = CoreContext,
    
    -- Event-specific fields (6 fields) - 48 bytes
    xpBefore = 1000,
    xpAfter = 1234,
    xpGained = 234,
    hasGainedXP = true,
    shouldAnimate = true,
    shouldFlash = true,
    
    -- Total: 18 fields (12 core + 6 event), ~144 bytes
}
```

**Level 4: Animation Frame Context (Event + Animation State)**
```lua
-- Created for each animation frame
AnimationFrameContext = {
    -- Reference to event context (inheritance)
    __index = XPChangeContext,
    
    -- Animation state (4 fields) - 32 bytes
    currentRatio = 0.5,
    isFlashing = true,
    flashAlpha = 0.8,
    flashPhase = "hold",
    
    -- Total: 22 fields (18 + 4), ~176 bytes (vs 1KB+ before)
}
```

**Benefits**:
- ✅ **82% size reduction**: 176 bytes vs 1KB per frame context
- ✅ **Shared static data**: Config referenced, not copied
- ✅ **Inheritance chain**: Avoids field duplication
- ✅ **Fast creation**: Only 4 new fields per frame
- ✅ **Memory efficient**: 60 FPS × 176 bytes = ~10KB/sec (vs 60KB/sec)

---

### 1.3 Implementation: Context Builder Refactor

**File**: `ContextBuilder.lua`

#### Step 1: Create Static Config Management
```lua
-------------------------------------------------------------------
-- STATIC CONFIGURATION (SHARED)
-------------------------------------------------------------------

--- Static configuration shared by all contexts
--- Created once, updated when settings change
XPBarStaticConfig = {
    -- Display flags (default values)
    showXPText = true,
    showLevelText = true,
    showPercentage = true,
    showQuestXP = true,
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    showRestedOverlay = true,
    showExhaustionTick = true,
    showSessionTimeText = true,
    showLevelTimeText = true,
    showXPPerHourText = true,
    showTimeToLevelText = true,
    
    -- Configuration
    percentDecimals = 1,
    abbreviateNumbers = true,
    showRemainingXP = false,
    showQuestPercent = false
}

--- Update static config from database
--- Call this when user changes settings
function ContextBuilder.UpdateStaticConfig()
    local AddonGlobal = _G["XPBarEnhanced"]
    local db = AddonGlobal and AddonGlobal.db
    
    if not db then
        return
    end
    
    -- Helper to get boolean from db with default fallback
    local function getBool(key, default)
        local dbValue = db[key]
        if dbValue ~= nil then
            if default == true then
                return dbValue ~= false
            else
                return dbValue == true
            end
        else
            return default == true
        end
    end
    
    -- Update all config fields
    XPBarStaticConfig.showXPText = getBool("showXPText", true)
    XPBarStaticConfig.showLevelText = getBool("showLevelText", true)
    XPBarStaticConfig.showPercentage = getBool("showPercentage", true)
    XPBarStaticConfig.showQuestXP = getBool("showQuestXP", true)
    XPBarStaticConfig.showCompleteQuestOverlay = getBool("showCompleteQuestOverlay", true)
    XPBarStaticConfig.showIncompleteQuestOverlay = getBool("showIncompleteQuestOverlay", false)
    XPBarStaticConfig.showRestedOverlay = getBool("showRestedOverlay", true)
    XPBarStaticConfig.showExhaustionTick = getBool("showExhaustionTick", true)
    XPBarStaticConfig.showSessionTimeText = getBool("showSessionTimeText", true)
    XPBarStaticConfig.showLevelTimeText = getBool("showLevelTimeText", true)
    XPBarStaticConfig.showXPPerHourText = getBool("showXPPerHourText", true)
    XPBarStaticConfig.showTimeToLevelText = getBool("showTimeToLevelText", true)
    
    XPBarStaticConfig.percentDecimals = db.percentDecimals or 1
    XPBarStaticConfig.abbreviateNumbers = getBool("abbreviateNumbers", true)
    XPBarStaticConfig.showRemainingXP = getBool("showRemainingXP", false)
    XPBarStaticConfig.showQuestPercent = getBool("showQuestPercent", false)
end
```

#### Step 2: Simplified Core Context Builder
```lua
--- Build minimal core context with only dynamic state
--- @param coreState table Core XP state from GetCoreState()
--- @return table coreContext Minimal context with game state
function ContextBuilder.BuildCoreContext(coreState)
    local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()
    
    -- Get session stats
    local AddonGlobal = _G["XPBarEnhanced"]
    local sessionXP = 0
    local levelSeconds = 0
    
    if AddonGlobal and AddonGlobal.Session then
        local session = AddonGlobal.Session:GetCurrent()
        if session then
            sessionXP = session.gainedXP or 0
            
            if session.realLevelTime and session.realLevelTime > 0 then
                levelSeconds = session.realLevelTime
                -- Add elapsed time for real-time accuracy
                if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
                    local elapsed = time() - session.lastTimePlayedRequest
                    levelSeconds = levelSeconds + elapsed
                end
            end
        end
    end
    
    local sessionStart = (AddonGlobal and AddonGlobal.Session and 
                          AddonGlobal.Session:GetCurrent().sessionStart) or time()
    local sessionSeconds = time() - sessionStart
    
    local xpPerHour = ContextBuilder.CalculateXPPerHour(
        sessionStart, sessionXP, levelSeconds, coreState.currentXP
    )
    
    -- OPTIMIZED: Only 12 dynamic fields
    return {
        -- Core XP state (5 fields)
        currentXP = coreState.currentXP,
        xpMax = coreState.xpMax,
        level = coreState.level,
        restedXP = coreState.restedXP,
        hasRestedXP = coreState.hasRestedXP,
        
        -- Quest state (2 fields)
        completeQuestXP = completeQuestXP,
        incompleteQuestXP = incompleteQuestXP,
        
        -- Session state (4 fields)
        sessionXP = sessionXP,
        sessionSeconds = sessionSeconds,
        levelSeconds = levelSeconds,
        xpPerHour = xpPerHour,
        
        -- Reference to shared static config (1 field)
        config = XPBarStaticConfig
    }
end
```

#### Step 3: Event-Specific Context Builders with Inheritance
```lua
--- Build XP change context using inheritance
--- @param event string Event name
--- @return table context Event context with XP change data
function ContextBuilder.BuildXPChangeContext(event, ...)
    local coreState = ContextBuilder.GetCoreState()
    local coreContext = ContextBuilder.BuildCoreContext(coreState)
    
    local xpGained, lastXP = ContextBuilder.ComputeXPGained(
        coreState.currentXP, coreState.xpMax
    )
    
    -- Create event context with inheritance from core
    local eventContext = {
        -- XP change data (6 fields)
        xpBefore = lastXP,
        xpAfter = coreState.currentXP,
        xpGained = xpGained,
        hasGainedXP = (xpGained and xpGained > 0),
        shouldAnimate = (xpGained and xpGained > 0),
        shouldFlash = (xpGained and xpGained > 0),
    }
    
    -- Set up inheritance: eventContext inherits from coreContext
    setmetatable(eventContext, { __index = coreContext })
    
    return ContextBuilder.MakeImmutable(eventContext)
end

--- Build level-up context using inheritance
--- @param event string Event name
--- @param newLevel number New player level
--- @return table context Event context with level-up data
function ContextBuilder.BuildLevelUpContext(event, newLevel)
    local coreState = ContextBuilder.GetCoreState()
    local coreContext = ContextBuilder.BuildCoreContext(coreState)
    
    -- Reset XP tracking
    ContextBuilder._lastXP = coreState.currentXP
    ContextBuilder._lastMaxXP = coreState.xpMax
    
    -- Create event context with inheritance
    local eventContext = {
        -- Level-up data (5 fields)
        oldLevel = (newLevel or coreState.level) - 1,
        newLevel = newLevel or coreState.level,
        hasGainedXP = (coreState.currentXP and coreState.currentXP > 0),
        hasLeveledUp = true,
        shouldAnimate = true,
        shouldFlash = (coreState.currentXP and coreState.currentXP > 0),
    }
    
    setmetatable(eventContext, { __index = coreContext })
    
    return ContextBuilder.MakeImmutable(eventContext)
end

--- Build rested change context using inheritance
--- @param event string Event name
--- @return table context Event context for rested change
function ContextBuilder.BuildRestedContext(event, ...)
    local coreState = ContextBuilder.GetCoreState()
    local coreContext = ContextBuilder.BuildCoreContext(coreState)
    
    -- Create event context with inheritance
    local eventContext = {
        -- Rested event flags (4 fields)
        hasGainedXP = false,
        shouldAnimate = false,
        shouldFlash = false,
        restedChanged = true,
    }
    
    setmetatable(eventContext, { __index = coreContext })
    
    return ContextBuilder.MakeImmutable(eventContext)
end

--- Build quest change context using inheritance
--- @param event string Event name
--- @return table context Event context for quest change
function ContextBuilder.BuildQuestContext(event, ...)
    local coreState = ContextBuilder.GetCoreState()
    local coreContext = ContextBuilder.BuildCoreContext(coreState)
    
    -- Create event context with inheritance
    local eventContext = {
        -- Quest event flags (4 fields)
        hasGainedXP = false,
        shouldAnimate = false,
        shouldFlash = false,
        questsChanged = true,
    }
    
    setmetatable(eventContext, { __index = coreContext })
    
    return ContextBuilder.MakeImmutable(eventContext)
end
```

#### Step 4: Optimized Immutability
```lua
--- Make context immutable using optimized metatable
--- Preserves inheritance chain while preventing modification
--- @param context table Context to make immutable
--- @return table immutableContext Protected context
function ContextBuilder.MakeImmutable(context)
    -- If context already has metatable (inheritance), preserve it
    local existingMeta = getmetatable(context)
    local existingIndex = existingMeta and existingMeta.__index
    
    return setmetatable({}, {
        __index = function(t, k)
            -- Check own fields first
            local value = rawget(context, k)
            if value ~= nil then
                return value
            end
            -- Then check inherited fields
            if existingIndex then
                return existingIndex[k]
            end
            return nil
        end,
        __newindex = function(t, k, v)
            error(string.format(
                "Attempt to modify immutable context field '%s'", 
                tostring(k)
            ), 2)
        end,
        __metatable = false
    })
end
```

**Benefits of Refactored Context**:
- ✅ **18 fields** in event context (vs 45+ before)
- ✅ **~144 bytes** per event context (vs 1KB+ before)
- ✅ **Static config shared** across all contexts
- ✅ **Inheritance chain** avoids field duplication
- ✅ **Faster creation** with fewer allocations

---

## Phase 2: Animation Frame Context Optimization

### 2.1 Lazy Frame Context Creation

**Problem**: Creating full context clone for every animation frame (60 FPS)

**Solution**: Create minimal frame context that inherits from event context

```lua
-------------------------------------------------------------------
-- ANIMATION FRAME CONTEXT
-------------------------------------------------------------------

--- Create animation frame context with minimal new fields
--- Inherits from event context to avoid duplication
--- @param eventContext table Base event context
--- @param currentRatio number Current animation progress ratio
--- @param flashState table Flash state { isFlashing, flashAlpha, flashPhase }
--- @return table frameContext Animation frame context
function ContextBuilder.BuildAnimationFrameContext(eventContext, currentRatio, flashState)
    -- Create minimal frame context (only 4 new fields)
    local frameContext = {
        currentRatio = currentRatio,
        isFlashing = flashState.isFlashing or false,
        flashAlpha = flashState.flashAlpha or 0,
        flashPhase = flashState.flashPhase or nil,
    }
    
    -- Inherit from event context
    setmetatable(frameContext, { __index = eventContext })
    
    -- No need for immutability on frame contexts (short-lived, internal only)
    return frameContext
end
```

**Benefits**:
- ✅ **Only 4 new fields** per frame (vs 45+ if cloning full context)
- ✅ **~32 bytes** per frame context (vs 1KB+ before)
- ✅ **No immutability overhead** (short-lived, internal)
- ✅ **Inherits all event/core/config data** automatically

---

### 2.2 Flash State Management

**Current**: Flash state scattered across animation state

**Proposed**: Centralized flash state calculation

```lua
-------------------------------------------------------------------
-- FLASH STATE CALCULATION
-------------------------------------------------------------------

--- Calculate flash state for current time
--- @param animation table Animation state
--- @param now number Current time (GetTime())
--- @return table flashState { isFlashing, flashAlpha, flashPhase }
function ContextBuilder.CalculateFlashState(animation, now)
    if not animation.isFlashing then
        return {
            isFlashing = false,
            flashAlpha = 0,
            flashPhase = nil
        }
    end
    
    local elapsed = now - animation.flashStartTime
    local duration = animation.flashDuration or 1.0
    
    if elapsed >= duration then
        return {
            isFlashing = false,
            flashAlpha = 0,
            flashPhase = nil
        }
    end
    
    -- Calculate flash phase and alpha
    -- Phases: fade_in (0-0.2s), hold (0.2-0.8s), fade_out (0.8-1.0s)
    local fadeInDuration = 0.2
    local holdDuration = 0.6
    local fadeOutDuration = 0.2
    
    local alpha = 0
    local phase = nil
    
    if elapsed < fadeInDuration then
        -- Fade in
        phase = "fade_in"
        alpha = elapsed / fadeInDuration
    elseif elapsed < (fadeInDuration + holdDuration) then
        -- Hold
        phase = "hold"
        alpha = 1.0
    else
        -- Fade out
        phase = "fade_out"
        local fadeOutElapsed = elapsed - (fadeInDuration + holdDuration)
        alpha = 1.0 - (fadeOutElapsed / fadeOutDuration)
    end
    
    return {
        isFlashing = true,
        flashAlpha = math.max(0, math.min(1, alpha)),
        flashPhase = phase
    }
end
```

---

## Phase 3: AnimationManager Integration

### 3.1 Preserve Full Event Context

**Current Problem**: AnimationManager receives `xpContext` (subset of fields)

**Solution**: Pass full event context to AnimationManager

**File**: `FlatBarStyle.lua`, `CircularBarStyle.lua`, etc.

#### Before (Current)
```lua
function FlatBarStyle:RenderBar(context)
    if context.shouldAnimate then
        -- Create subset xpContext (loses display flags!)
        local xpContext = {
            xpBefore = context.xpBefore,
            xpAfter = context.xpAfter,
            xpMax = context.xpMax,
            xpGained = context.xpGained,
            restedXP = context.restedXP,
            hasRestedXP = context.hasRestedXP,
            isResting = context.isResting,
            level = context.level,
            timestamp = context.timestamp
        }
        
        self:StartAnimation(targetRatio, xpContext, config)
    end
end
```

#### After (Optimized)
```lua
function FlatBarStyle:RenderBar(context)
    if context.shouldAnimate then
        local targetRatio = CalculateTargetRatio(context)
        local config = self:GetAnimationConfig()
        
        -- Pass FULL context (already optimized, small size)
        self:StartAnimation(targetRatio, context, config)
    else
        local finalRatio = context.currentXP / context.xpMax
        self:RenderBarFrame(finalRatio, context)
    end
end
```

**Benefits**:
- ✅ No subset creation (saves allocation)
- ✅ Full context available during animation
- ✅ Display flags preserved
- ✅ Simpler code

---

### 3.2 AnimationManager: Store and Use Full Context

**File**: `AnimationManager.lua`

#### Step 1: Update AnimateTo to Store Full Context
```lua
--- Start animation to target ratio
--- @param bar table Bar instance with animation state
--- @param targetRatio number Target ratio (0.0-1.0)
--- @param eventContext table FULL event context (optimized structure)
--- @param config table Animation config { enableAnimations, flashOnGain }
function AnimationManager:AnimateTo(bar, targetRatio, eventContext, config)
    local now = GetTime()
    
    -- Ensure animation state exists
    if not bar.animation then
        bar.animation = {
            isAnimating = false,
            startRatio = 0,
            targetRatio = 0,
            startTime = 0,
            duration = 0,
            isFlashing = false,
            flashStartTime = 0,
            flashDuration = 0,
            eventContext = nil  -- NEW: Store full event context
        }
    end
    
    local anim = bar.animation
    
    -- CRITICAL: Store full event context for animation frames
    anim.eventContext = eventContext
    
    -- Detect level-up (ratio wraps from ~1.0 to ~0.0)
    local isLevelUp = false
    if bar.GetCurrentRatio then
        local currentRatio = bar:GetCurrentRatio() or 0
        if currentRatio > 0.9 and targetRatio < 0.1 then
            isLevelUp = true
        end
    end
    
    -- Handle retargeting
    if anim.isAnimating then
        local progress = (now - anim.startTime) / anim.duration
        if progress >= 1.0 then
            anim.startRatio = anim.targetRatio
        else
            -- Continue from current position
            local easedProgress = AnimationUtils.EaseOutQuad(progress, 0, 1, 1)
            anim.startRatio = anim.startRatio + 
                              (anim.targetRatio - anim.startRatio) * easedProgress
        end
        anim.targetRatio = targetRatio
    else
        -- Fresh animation
        anim.startRatio = bar:GetCurrentRatio() or 0
        anim.targetRatio = targetRatio
    end
    
    -- Calculate delta
    local delta = math.abs(targetRatio - anim.startRatio)
    
    -- Check if should animate
    local shouldAnimate, reason = AnimationUtils.ShouldAnimate(delta, config)
    
    if not shouldAnimate then
        -- Instant update: call RenderBarFrame directly
        if bar.RenderBarFrame then
            bar:RenderBarFrame(targetRatio, eventContext)
        end
        
        -- Handle instant flash if XP gained
        if config.flashOnGain and eventContext.hasGainedXP then
            local inCooldown = anim.flashCooldownUntil and now < anim.flashCooldownUntil
            if not anim.isFlashing and not inCooldown then
                anim.isFlashing = true
                anim.flashStartTime = now
                anim.flashDuration = AnimationUtils.GetFlashTotalDuration()
                self:Register(bar)
            end
        end
        
        -- Update tracked ratio
        if bar.SetCurrentRatio then
            bar:SetCurrentRatio(targetRatio)
        end
        
        return
    end
    
    -- Start animation
    anim.isAnimating = true
    anim.startTime = now
    anim.duration = AnimationUtils.CalculateDuration(delta, config)
    
    -- Start flash if XP gained
    if config.flashOnGain and eventContext.hasGainedXP then
        local inCooldown = anim.flashCooldownUntil and now < anim.flashCooldownUntil
        if not anim.isFlashing and not inCooldown then
            anim.isFlashing = true
            anim.flashStartTime = now
            anim.flashDuration = AnimationUtils.GetFlashTotalDuration()
        end
    end
    
    -- Register for OnUpdate
    self:Register(bar)
end
```

#### Step 2: Update OnUpdate to Call RenderBarFrame
```lua
--- Update all registered bars (called every frame)
--- @param elapsed number Time since last update
function AnimationManager:OnUpdate(elapsed)
    local now = GetTime()
    local i = 1
    
    while i <= #self.registeredBars do
        local bar = self.registeredBars[i]
        local shouldUnregister = self:UpdateBarAnimation(bar, now)
        
        if shouldUnregister then
            table.remove(self.registeredBars, i)
        else
            i = i + 1
        end
    end
    
    -- Pause driver if no bars left
    if #self.registeredBars == 0 then
        self.driver:Hide()
    end
end

--- Update single bar animation
--- @param bar table Bar instance
--- @param now number Current time (GetTime())
--- @return boolean shouldUnregister True if animation complete and should unregister
function AnimationManager:UpdateBarAnimation(bar, now)
    local anim = bar.animation
    
    if not anim then
        return true  -- No animation state, unregister
    end
    
    -- Calculate animation progress
    local animationComplete = false
    local currentRatio = anim.targetRatio
    
    if anim.isAnimating then
        local elapsed = now - anim.startTime
        local progress = math.min(elapsed / anim.duration, 1.0)
        local easedProgress = AnimationUtils.EaseOutQuad(progress, 0, 1, 1)
        currentRatio = anim.startRatio + (anim.targetRatio - anim.startRatio) * easedProgress
        
        if progress >= 1.0 then
            anim.isAnimating = false
            animationComplete = true
        end
    end
    
    -- Calculate flash state
    local flashState = ContextBuilder.CalculateFlashState(anim, now)
    
    if not flashState.isFlashing then
        anim.isFlashing = false
        if animationComplete then
            -- Set flash cooldown
            anim.flashCooldownUntil = now + 0.5
        end
    end
    
    -- Build animation frame context (optimized: only 4 new fields)
    local frameContext = ContextBuilder.BuildAnimationFrameContext(
        anim.eventContext,  -- Stored full event context
        currentRatio,
        flashState
    )
    
    -- UNIFIED CALL: RenderBarFrame (replaces ApplyAnimationStep)
    if bar.RenderBarFrame then
        bar:RenderBarFrame(currentRatio, frameContext)
    else
        -- Fallback to old pattern (backward compat)
        if bar.ApplyAnimationStep then
            local stepContext = AnimationUtils.BuildStepContext(
                bar, now, bar:GetAnimationConfig(), frameContext
            )
            bar:ApplyAnimationStep(stepContext)
        end
    end
    
    -- Update tracked ratio
    if bar.SetCurrentRatio then
        bar:SetCurrentRatio(currentRatio)
    end
    
    -- Unregister if both animation and flash complete
    return (not anim.isAnimating and not anim.isFlashing)
end
```

**Benefits**:
- ✅ Full event context available every frame
- ✅ Calls RenderBarFrame directly (unified pattern)
- ✅ Optimized frame context creation (32 bytes)
- ✅ Flash state calculated efficiently
- ✅ Fallback to old pattern for backward compat

---

## Phase 4: Bar Style RenderBarFrame Updates

### 4.1 FlatBarStyle Dynamic Rendering

**File**: `FlatBarStyle.lua`

```lua
--- Render bar frame at current animation position
--- Called for instant updates OR every animation frame
--- @param currentRatio number Current bar ratio (0.0-1.0)
--- @param context table Full context with all state
function FlatBarStyle:RenderBarFrame(currentRatio, context)
    -- 1. BAR POSITION (at current animation ratio)
    if self.StatusBar then
        self.StatusBar:SetMinMaxValues(0, 1)
        self.StatusBar:SetValue(currentRatio)
    end
    
    -- 2. BAR COLORS (based on rested state)
    if self.UpdateBarColors then
        self:UpdateBarColors(context)
    end
    
    -- 3. FLASH OVERLAY (integrated with context)
    if context.isFlashing and context.flashAlpha > 0 then
        if self.GainFlash then
            local color = context.hasRestedXP and Color.Rested or Color.XpBar
            self.GainFlash:SetColorTexture(
                color.r, color.g, color.b, context.flashAlpha
            )
            self.GainFlash:Show()
        end
        
        -- Dim quest overlays during flash (dynamic effect!)
        local overlayAlpha = 1.0 - (context.flashAlpha * 0.5)
        if self.QuestOverlayComplete then
            self.QuestOverlayComplete:SetAlpha(overlayAlpha)
        end
        if self.QuestOverlayIncomplete then
            self.QuestOverlayIncomplete:SetAlpha(overlayAlpha)
        end
    else
        if self.GainFlash then
            self.GainFlash:Hide()
        end
        -- Restore overlay alpha
        if self.QuestOverlayComplete then
            self.QuestOverlayComplete:SetAlpha(1.0)
        end
        if self.QuestOverlayIncomplete then
            self.QuestOverlayIncomplete:SetAlpha(1.0)
        end
    end
    
    -- 4. OVERLAYS (react to current bar position!)
    -- Calculate animated XP position
    local animatedXP = currentRatio * context.xpMax
    
    -- Create animation context with current XP
    -- Use inheritance to avoid copying all fields
    local animContext = {
        currentXP = animatedXP,  -- Override with animated position
        currentRatio = currentRatio  -- Add for convenience
    }
    setmetatable(animContext, { __index = context })
    
    -- Render overlays with animated position (DYNAMIC!)
    if self.UpdateRestedOverlay and context.config.showRestedOverlay then
        self:UpdateRestedOverlay(animContext)
    end
    
    if self.UpdateQuestCompleteOverlay and context.config.showCompleteQuestOverlay then
        self:UpdateQuestCompleteOverlay(animContext)
    end
    
    if self.UpdateQuestIncompleteOverlay and context.config.showIncompleteQuestOverlay then
        self:UpdateQuestIncompleteOverlay(animContext)
    end
    
    if self.UpdateExhaustionTick and context.config.showExhaustionTick then
        self:UpdateExhaustionTick(animContext)
    end
    
    -- 5. TEXT (updates every frame during animation)
    if self.UpdateTexts then
        self:UpdateTexts(animContext)
    end
end
```

**Key Features**:
- ✅ Bar position at `currentRatio` (animated)
- ✅ Flash overlay integrated with `context.flashAlpha`
- ✅ Quest overlays dim during flash (dynamic effect)
- ✅ **Overlays react to animated position** (rested shrinks as bar grows!)
- ✅ Text updates every frame
- ✅ Uses `context.config` for display flags (shared static config)

---

### 4.2 CircularBarStyle Dynamic Rendering

**File**: `CircularBarStyle.lua`

```lua
--- Render circular bar at current animation position
--- @param currentRatio number Current bar ratio (0.0-1.0)
--- @param context table Full context with all state
function CircularBarStyle:RenderBarFrame(currentRatio, context)
    -- 1. ARC PROGRESS (all segments calculated together)
    -- Calculate animated XP for segment positioning
    local animatedXP = currentRatio * context.xpMax
    
    -- Create animation context
    local animContext = {
        currentXP = animatedXP,
        currentRatio = currentRatio
    }
    setmetatable(animContext, { __index = context })
    
    -- SetArcProgress renders all segments in one pass (already optimal!)
    self:SetArcProgress(currentRatio, context.hasRestedXP, animContext)
    
    -- 2. FLASH (integrated into context)
    if context.isFlashing and context.flashAlpha > 0 then
        if self.GainFlash then
            self.GainFlash:SetAlpha(context.flashAlpha)
            self.GainFlash:Show()
        end
    else
        if self.GainFlash then
            self.GainFlash:Hide()
        end
    end
    
    -- 3. TEXT (updates every frame)
    if self.UpdateTexts then
        self:UpdateTexts(animContext)
    end
end

--- Update arc progress for circular bar
--- Now receives full context for access to all state
--- @param progress number Current progress ratio (0.0-1.0)
--- @param hasRestedXP boolean Whether player has rested XP
--- @param context table Full context with all state
function CircularBarStyle:SetArcProgress(progress, hasRestedXP, context)
    -- Calculate current XP based on progress
    local currentXP = progress * context.xpMax
    
    -- All segment calculations use currentXP (animated position)
    -- This makes segments react dynamically during animation!
    
    -- Calculate segment types (current, rested, quest)
    local segments = self:CalculateSegments(currentXP, context)
    
    -- Render all segments in one pass (already optimal!)
    self:RenderSegments(segments, hasRestedXP, context)
end
```

**Key Features**:
- ✅ SetArcProgress already optimal (renders all segments together)
- ✅ Segments calculated from animated `currentXP`
- ✅ Flash integrated with `context.flashAlpha`
- ✅ Text updates every frame
- ✅ Minimal changes needed (already had good pattern!)

---

### 4.3 Classic and Vertical Styles

Apply same pattern as FlatBarStyle (identical structure, different orientations).

---

## Phase 5: AnimationBase Optimization

### 5.1 Current Issues

**Problems**:
1. **Abstract Methods**: `ApplyAnimationStep` → `AnimateBarPosition` + `AnimateBarEffect` creates deep call stack
2. **Fallback Logic**: Duplicate AnimationManager logic in `StartAnimation`
3. **Context Array**: Stores `contexts` array (not needed with optimized context)
4. **174 lines**: Too large for what is essentially an interface

**Goal**: Reduce AnimationBase to **pure interface** (~40 lines)

---

### 5.2 Optimization: Remove Abstract Methods

**File**: `AnimationBase.lua`

#### Before (Current - 174 lines)
```lua
--- Apply animation step (called every frame by AnimationManager)
function AnimationBase:ApplyAnimationStep(stepContext)
    self:AnimateBarPosition(stepContext)
    self:AnimateBarEffect(stepContext)
end

-- Abstract methods (must be implemented by styles)
function AnimationBase:AnimateBarPosition(stepContext)
    error("AnimateBarPosition must be implemented by bar style")
end

function AnimationBase:AnimateBarEffect(stepContext)
    error("AnimateBarEffect must be implemented by bar style")
end

-- Fallback logic
function AnimationBase:StartAnimation(targetRatio, xpContext, config)
    if not Addon.AnimationManager then
        -- 30 lines of fallback logic
        local instantContext = { ... }
        self:ApplyAnimationStep(instantContext)
        return
    end
    Addon.AnimationManager:AnimateTo(self, targetRatio, xpContext, config)
end
```

#### After (Optimized - 40 lines)
```lua
--- Start animation to target ratio
--- Delegates to AnimationManager (required)
function AnimationBase:StartAnimation(targetRatio, eventContext, config)
    if not Addon.AnimationManager then
        error("AnimationManager not available")
    end
    
    Addon.AnimationManager:AnimateTo(self, targetRatio, eventContext, config)
end

-- REMOVED: ApplyAnimationStep (replaced by RenderBarFrame in styles)
-- REMOVED: AnimateBarPosition (merged into RenderBarFrame)
-- REMOVED: AnimateBarEffect (merged into RenderBarFrame)
-- REMOVED: Fallback logic (AnimationManager always available)
-- REMOVED: OnAnimationComplete (not used)
```

**Changes**:
- ✅ Remove `ApplyAnimationStep` method
- ✅ Remove abstract methods (`AnimateBarPosition`, `AnimateBarEffect`)
- ✅ Remove fallback logic (fail fast if AnimationManager missing)
- ✅ Store `eventContext` instead of `contexts` array
- ✅ Simplify to pure interface (~40 lines, 77% reduction)

---

### 5.3 Remove Implementations from Bar Styles

**Files to update**:
- `CircularBarStyle.lua` - Remove `ApplyAnimationStep`, `AnimateBarPosition`, `AnimateBarEffect`
- `FlatBarStyle.lua` - Remove implementations
- `ClassicBarStyle.lua` - Remove implementations
- `VerticalBarStyle.lua` - Remove implementations

**Each style removes ~30 lines** of abstract method implementations.

---

## Phase 6: AnimationUtils Optimization

### 6.1 Current Issues

**Problems**:
1. **BuildStepContext**: Creates large objects (20+ fields, 400 bytes) 60 times/sec
2. **AggregateContexts**: Rarely used, complex logic for edge case
3. **DetectLevelUp**: Not needed (hasLeveledUp flag in context)
4. **255 lines**: Too large for utilities module

**Goal**: Reduce AnimationUtils to **pure math utilities** (~80 lines)

---

### 6.2 Optimization: Move Context Building to ContextBuilder

**File**: `AnimationUtils.lua`

#### Before (Current - 255 lines)
```lua
--- Build step context for ApplyAnimationStep
function AnimationUtils.BuildStepContext(bar, now, config, xpContext)
    local anim = bar.animation
    
    -- 100+ lines of context building
    local stepContext = {
        currentRatio = ...,
        targetRatio = ...,
        startRatio = ...,
        progress = ...,
        startTime = ...,
        currentTime = ...,
        elapsedTime = ...,
        duration = ...,
        flashData = { ... },  -- 50 lines of flash calculation
        isFlashing = ...,
        questOverlayAlpha = ...,
        config = config,
        xpContext = xpContext
    }
    
    return stepContext
end

--- Aggregate multiple contexts during retargeting
function AnimationUtils.AggregateContexts(contexts)
    -- 30 lines of aggregation logic
end

--- Detect level-up
function AnimationUtils.DetectLevelUp(context)
    return context.xpAfter < context.xpBefore
end
```

#### After (Optimized - 80 lines)
```lua
-- Keep ONLY math utilities

--- Calculate animation duration based on ratio delta
function AnimationUtils.CalculateDuration(delta)
    -- Math only
end

--- Ease-out quadratic easing function
function AnimationUtils.EaseOutQuad(t, b, c, d)
    -- Math only
end

--- Check if a change should be animated
function AnimationUtils.ShouldAnimate(delta, config)
    -- Simple threshold check
end

--- Get total flash duration
function AnimationUtils.GetFlashTotalDuration()
    return ANIMATION_CONSTANTS.GAIN_FLASH_FADE_IN_DURATION +
           ANIMATION_CONSTANTS.GAIN_FLASH_HOLD_DURATION +
           ANIMATION_CONSTANTS.GAIN_FLASH_FADE_OUT_DURATION
end

--- Get animation constants
function AnimationUtils.GetConstants()
    return ANIMATION_CONSTANTS
end

-- REMOVED: BuildStepContext (moved to ContextBuilder.BuildAnimationFrameContext)
-- REMOVED: AggregateContexts (not needed with full context preservation)
-- REMOVED: DetectLevelUp (hasLeveledUp flag in context)
```

**Changes**:
- ✅ Move `BuildStepContext` → `ContextBuilder.BuildAnimationFrameContext`
- ✅ Remove `AggregateContexts` (not needed with optimized context)
- ✅ Remove `DetectLevelUp` (flag already in context)
- ✅ Keep only math utilities (~80 lines, 69% reduction)

---

### 6.3 Add Methods to ContextBuilder

**File**: `ContextBuilder.lua`

```lua
--- Create animation frame context with minimal new fields
--- Inherits from event context to avoid duplication
--- @param eventContext table Base event context
--- @param currentRatio number Current animation progress ratio
--- @param flashState table Flash state { isFlashing, flashAlpha, flashPhase }
--- @return table frameContext Animation frame context
function ContextBuilder.BuildAnimationFrameContext(eventContext, currentRatio, flashState)
    -- Create minimal frame context (only 4 new fields)
    local frameContext = {
        currentRatio = currentRatio,
        isFlashing = flashState.isFlashing or false,
        flashAlpha = flashState.flashAlpha or 0,
        flashPhase = flashState.flashPhase or nil,
    }
    
    -- Inherit from event context
    setmetatable(frameContext, { __index = eventContext })
    
    return frameContext
end

--- Calculate flash state for current time
--- @param animation table Animation state
--- @param now number Current time (GetTime())
--- @return table flashState { isFlashing, flashAlpha, flashPhase }
function ContextBuilder.CalculateFlashState(animation, now)
    if not animation.isFlashing then
        return {
            isFlashing = false,
            flashAlpha = 0,
            flashPhase = nil
        }
    end
    
    local elapsed = now - animation.flashStartTime
    local duration = animation.flashDuration or 1.0
    
    if elapsed >= duration then
        return {
            isFlashing = false,
            flashAlpha = 0,
            flashPhase = nil
        }
    end
    
    -- Use AnimationUtils constants
    local constants = AnimationUtils.GetConstants()
    local fadeInDuration = constants.GAIN_FLASH_FADE_IN_DURATION
    local holdDuration = constants.GAIN_FLASH_HOLD_DURATION
    local fadeOutDuration = constants.GAIN_FLASH_FADE_OUT_DURATION
    local maxAlpha = constants.GAIN_FLASH_MAX_ALPHA
    
    -- Calculate phase and alpha
    local alpha = 0
    local phase = nil
    
    if elapsed < fadeInDuration then
        phase = "fade_in"
        alpha = (elapsed / fadeInDuration) * maxAlpha
    elseif elapsed < (fadeInDuration + holdDuration) then
        phase = "hold"
        alpha = maxAlpha
    else
        phase = "fade_out"
        local fadeOutElapsed = elapsed - (fadeInDuration + holdDuration)
        alpha = maxAlpha * (1.0 - (fadeOutElapsed / fadeOutDuration))
    end
    
    return {
        isFlashing = true,
        flashAlpha = math.max(0, math.min(1, alpha)),
        flashPhase = phase
    }
end
```

---

## Phase 7: Cleanup and Removal

### 7.1 Files to Update

**AnimationBase.lua**:
- Remove ~130 lines (abstract methods + fallback logic)
- Result: ~40 lines (pure interface)

**AnimationUtils.lua**:
- Remove ~175 lines (context building + aggregation)
- Result: ~80 lines (math utilities only)

**ContextBuilder.lua**:
- Add ~100 lines (BuildAnimationFrameContext + CalculateFlashState)
- Net: +100 lines (but better organization)

**All Bar Styles** (Circular, Flat, Classic, Vertical):
- Remove ~30 lines each (ApplyAnimationStep implementations)
- Result: ~120 lines removed total

**Net Code Reduction**: ~325 lines removed across all files

---

## Phase 6: Testing and Validation

### 6.1 Test Cases

**Test 1: XP Gain Animation**
```
1. Kill mob (gain ~100 XP)
2. Verify:
   ✅ Bar animates smoothly from old to new position
   ✅ Flash appears and fades (1 second)
   ✅ Rested overlay shrinks as bar grows (dynamic!)
   ✅ Quest overlays dim during flash
   ✅ Text updates every frame
   ✅ Animation completes at correct position
```

**Test 2: Level-Up Animation**
```
1. Level up (bar wraps from 100% to 0% + new XP)
2. Verify:
   ✅ Bar animates from 100% to new position
   ✅ Flash appears if new XP > 0
   ✅ Overlays recalculate for new level
   ✅ Level text updates immediately
   ✅ No glitches during wrap-around
```

**Test 3: Rapid XP Gains (Retargeting)**
```
1. Kill multiple mobs quickly
2. Verify:
   ✅ Animation retargets smoothly
   ✅ No stuttering or jumping
   ✅ Flash only triggers once (cooldown works)
   ✅ Overlays continue reacting smoothly
```

**Test 4: Rested State Change**
```
1. Enter/leave resting area
2. Verify:
   ✅ No bar animation (instant update)
   ✅ Rested overlay appears/disappears
   ✅ Bar color changes if configured
   ✅ No flash
```

**Test 5: Quest Complete**
```
1. Complete quest (XP reward)
2. Verify:
   ✅ Bar animates to new position
   ✅ Quest overlay adjusts dynamically
   ✅ Flash appears
   ✅ Text shows quest XP
```

**Test 6: Performance (60 FPS)**
```
1. Start long animation (large XP gain)
2. Monitor:
   ✅ Maintains 60 FPS during animation
   ✅ No frame drops
   ✅ Memory allocation stable (~10KB/sec)
   ✅ CPU usage < 1% for bar updates
```

### 6.2 Performance Benchmarks

**Context Size**:
- ❌ Before: ~1KB per event context, ~60KB/sec during animation
- ✅ After: ~144 bytes per event context, ~10KB/sec during animation
- **Result**: 83% reduction in memory churn

**Method Calls per Frame**:
- ❌ Before: ApplyAnimationStep → AnimateBarPosition + AnimateBarEffect = 3 calls
- ✅ After: RenderBarFrame = 1 call
- **Result**: 66% reduction in method calls

**Overlay Updates**:
- ❌ Before: Updated once (static during animation)
- ✅ After: Updated every frame (dynamic during animation)
- **Result**: Better visual quality with same performance

---

## Implementation Timeline

### Week 1: Context Optimization
- [ ] Day 1-2: Implement static config management
- [ ] Day 3-4: Refactor ContextBuilder with inheritance
- [ ] Day 5: Implement animation frame context helpers
- [ ] Day 6-7: Testing and validation

### Week 2: AnimationManager + Utilities Optimization
- [ ] Day 1-2: Update AnimationManager to store full context
- [ ] Day 3: Implement RenderBarFrame calls in AnimationManager
- [ ] Day 4: Optimize AnimationBase (remove abstract methods)
- [ ] Day 5: Optimize AnimationUtils (move to ContextBuilder)
- [ ] Day 6-7: Testing and validation

### Week 3: Bar Style Updates
- [ ] Day 1-2: Update FlatBarStyle RenderBarFrame
- [ ] Day 3: Update CircularBarStyle RenderBarFrame
- [ ] Day 4: Update ClassicBarStyle RenderBarFrame
- [ ] Day 5: Update VerticalBarStyle RenderBarFrame
- [ ] Day 6-7: Remove old ApplyAnimationStep implementations

### Week 4: Cleanup and Polish
- [ ] Day 1-2: Final code cleanup and documentation
- [ ] Day 3-4: Performance testing and optimization
- [ ] Day 5-6: Bug fixes and edge cases
- [ ] Day 7: Final validation and release prep

---

## Migration Strategy

### Backward Compatibility

**Approach**: Maintain fallback to old pattern during transition

```lua
-- In AnimationManager:UpdateBarAnimation
if bar.RenderBarFrame then
    -- NEW: Unified rendering
    bar:RenderBarFrame(currentRatio, frameContext)
else
    -- OLD: Fallback to ApplyAnimationStep
    if bar.ApplyAnimationStep then
        local stepContext = AnimationUtils.BuildStepContext(
            bar, now, config, frameContext
        )
        bar:ApplyAnimationStep(stepContext)
    end
end
```

**Remove fallback** once all bar styles updated.

---

## Expected Results

### Performance Improvements
- ✅ **83% smaller contexts**: 176 bytes vs 1KB
- ✅ **83% less memory churn**: ~10KB/sec vs ~60KB/sec
- ✅ **66% fewer method calls**: 1 vs 3 per frame
- ✅ **Stable 60 FPS**: No frame drops during animation

### Code Quality Improvements
- ✅ **Unified pattern**: Same method for instant and animated
- ✅ **Simpler codebase**: 1 method vs 3 abstract methods
- ✅ **Less duplication**: Shared static config
- ✅ **Better documentation**: Clear, consistent pattern
- ✅ **~775 lines removed**: AnimationBase (77%), AnimationUtils (69%), styles (30 lines each)

### Feature Improvements
- ✅ **Dynamic overlays**: React to bar position every frame
- ✅ **Integrated flash**: Part of context, not separate system
- ✅ **Live text updates**: Shows animated values during animation
- ✅ **Visual effects**: Quest overlays dim during flash

### Code Reduction Summary

| Component | Before | After | Reduction |
|-----------|--------|-------|-----------|
| **ContextBuilder.lua** | 495 lines | 595 lines | +100 lines (better organization) |
| **AnimationBase.lua** | 174 lines | 40 lines | **-134 lines (77%)** |
| **AnimationUtils.lua** | 255 lines | 80 lines | **-175 lines (69%)** |
| **CircularBarStyle.lua** | 686 lines | ~656 lines | **-30 lines** |
| **FlatBarStyle.lua** | ~280 lines | ~250 lines | **-30 lines** |
| **ClassicBarStyle.lua** | ~280 lines | ~250 lines | **-30 lines** |
| **VerticalBarStyle.lua** | ~280 lines | ~250 lines | **-30 lines** |
| **Context size** | 1KB/event | 144 bytes/event | **-86%** |
| **Frame context** | 1KB/frame | 176 bytes/frame | **-83%** |
| **Method calls/frame** | 8 | 3 | **-62%** |

**Total Net Reduction**: **~325 lines** removed (excluding ContextBuilder additions)

**Total Code Improvement**:
- AnimationBase: **77% smaller**
- AnimationUtils: **69% smaller**
- Contexts: **83-86% smaller**
- Method calls: **62% fewer**
- Overall: **Simpler, faster, more maintainable**

---

## Risks and Mitigation

### Risk 1: Breaking Existing Animations
**Mitigation**: Maintain fallback to old pattern, test each style individually

### Risk 2: Performance Regression
**Mitigation**: Benchmark before/after, optimize if needed

### Risk 3: Context Access Errors
**Mitigation**: Comprehensive testing, validate inheritance chain works

### Risk 4: Flash Behavior Changes
**Mitigation**: Test flash separately, ensure timing matches old behavior

---

## Conclusion

This refactor plan achieves:
1. **Unified Rendering**: Single RenderBarFrame method for instant and animated updates
2. **Optimized Contexts**: 83% size reduction through inheritance and shared config
3. **Dynamic Overlays**: All elements update every frame during animation
4. **Cleaner Code**: Removes split ApplyAnimationStep pattern
5. **Better Performance**: Fewer allocations, method calls, and memory churn

The implementation is structured in phases to maintain stability and allow incremental testing. The backward compatibility approach ensures the addon continues working during the transition period.
