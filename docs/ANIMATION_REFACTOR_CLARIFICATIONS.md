# Animation Refactor Key Clarifications

**Date**: November 11, 2025  
**Purpose**: Clarify critical design decisions for animation system refactor

---

## 1. Two Independent Animation Workflows

### Critical Distinction

The animation system has **TWO INDEPENDENT workflows**, not one:

#### Workflow 1: Bar Position Animation

- **Purpose**: Smooth bar fill from current position to target position
- **Trigger**: XP change events (PLAYER_XP_UPDATE)
- **Duration**: Calculated based on ratio delta (0.5-2.0 seconds)
- **Lifecycle**: Starts → Updates every frame → Completes when `progress >= 1.0`
- **State**: `isAnimating`, `startRatio`, `targetRatio`, `startTime`, `duration`
- **Iteration Data**: `currentRatio` (calculated from easing function each frame)

#### Workflow 2: Flash Gain Effect

- **Purpose**: Visual feedback for XP gain
- **Trigger**: XP gain events with `xpGained > 0` AND `config.flashOnGain`
- **Duration**: Fixed 1.0 second (fade in 0.2s + hold 0.3s + fade out 0.5s)
- **Lifecycle**: Starts → Updates every frame → Completes when `flashElapsed >= flashDuration`
- **State**: `isFlashing`, `flashStartTime`, `flashDuration`
- **Iteration Data**: `flashAlpha`, `flashPhase` (calculated from elapsed time each frame)

### Key Facts

- Both workflows can run **simultaneously** (bar animating while flash active)
- Both workflows can run **independently**:
  - Flash-only: Instant bar update with flash effect
  - Bar-only: Animate bar without flash
- Both workflows are driven by `AnimationManager:OnUpdate` (60 FPS)
- Each workflow has its own completion condition
- Flash has cooldown (100ms) to prevent rapid restart
- Bar animation can be retargeted, flash cannot

### Why This Matters

Previous documentation conflated these into a single "animation" concept, which:

- Made it unclear when flash should start/stop
- Suggested flash was tied to bar animation lifecycle
- Confused the state management (mixed bar state with flash state)

---

## 2. Immutable Context vs Iteration Data

### Critical Distinction

The animation system separates **immutable context** (created once) from **per-frame iteration data** (calculated each frame):

#### Immutable Animation Context

**Created**: Once per animation start by `ContextBuilder.BuildXPChangeContext()`  
**Stored**: In `bar.animation.eventContext`  
**Lifetime**: Entire animation duration (both workflows)  
**Contains**:

- Event state: `hasGainedXP`, `xpGained`, `hasRestedXP`
- Display flags: `showRestedOverlay`, `showQuestXP`, `showXPText`
- Game state: `currentXP`, `xpMax`, `restedXP`, `level`
- Quest state: `completeQuestXP`, `incompleteQuestXP`
- Static config reference: `context.config` (shared across all contexts)

**Never modified** during animation - immutable!

#### Iteration Data (Per Frame)

**Created**: Every frame during `AnimationManager:UpdateBarAnimation`  
**Stored**: Nowhere - passed as parameters  
**Lifetime**: Single frame  
**Contains**:

- `currentRatio` - Current bar position (from easing function)
- `flashAlpha` - Current flash opacity (from flash elapsed time)
- `flashPhase` - Flash stage: "fade_in", "hold", or "fade_out"

**Calculated fresh each frame** - zero allocation!

### Why This Matters

Previous documentation suggested creating "frame contexts" with these values, which:

- Would allocate 60+ objects per second (memory churn)
- Mixed immutable state with mutable iteration data
- Made it unclear what data persists vs what changes
- Created confusion about context "aggregation" during retargeting

### Correct Pattern

```lua
-- ONCE per animation start
function AnimationManager:AnimateTo(bar, targetRatio, eventContext, config)
    bar.animation.eventContext = eventContext  -- Immutable, store reference
    bar.animation.startRatio = currentRatio
    bar.animation.targetRatio = targetRatio
    -- ...
end

-- EVERY frame during animation
function AnimationManager:UpdateBarAnimation(bar, now)
    local eventContext = bar.animation.eventContext  -- Immutable reference
    
    -- Calculate iteration data (not stored)
    local currentRatio = CalculateCurrentRatio(bar.animation, now)
    local flashAlpha, flashPhase = CalculateFlashState(bar.animation, now)
    
    -- Pass iteration data as parameters
    bar:RenderBarFrame(currentRatio, eventContext, flashAlpha, flashPhase)
end
```

**Benefits**:

- ✅ Zero allocation per frame (no context objects created)
- ✅ Clear separation: context = state, parameters = iteration data
- ✅ Immutable context never modified
- ✅ Easy to add new iteration parameters without context changes

---

## 3. No Fallback Pattern - Clean Break

### Design Decision

**NO FALLBACK PATTERNS** - Fail fast, clean break.

### What This Means

**AnimationBase**:

```lua
function AnimationBase:StartAnimation(targetRatio, eventContext, config)
    if not Addon.AnimationManager then
        error("AnimationManager required for animations")
    end
    Addon.AnimationManager:AnimateTo(self, targetRatio, eventContext, config)
end
```

**NO**:

- ~~Fallback to old `ApplyAnimationStep` pattern~~
- ~~Gradual transition with backward compatibility~~
- ~~`if bar.RenderBarFrame then ... else ...`~~

**AnimationManager**:

```lua
function AnimationManager:UpdateBarAnimation(bar, now)
    -- Calculate iteration data
    local currentRatio = ...
    local flashAlpha, flashPhase = ...
    
    -- Direct call - no fallback
    bar:RenderBarFrame(currentRatio, eventContext, flashAlpha, flashPhase)
end
```

**NO**:

- ~~Check if RenderBarFrame exists~~
- ~~Fall back to BuildStepContext + ApplyAnimationStep~~
- ~~Maintain old pattern during transition~~

### Why This Matters

Previous documentation mentioned "backward compatibility fallback" which:

- Would require maintaining two code paths
- Would make the refactor incremental (more risky)
- Would leave dead code to clean up later
- Would create confusion about which pattern to use

### Implementation Strategy

1. Update all 4 bar styles simultaneously
2. Remove old methods (ApplyAnimationStep, AnimateBarPosition, AnimateBarEffect)
3. Test thoroughly before commit
4. Version control allows rollback if needed
5. Clean break = less code to maintain

---

## 4. Context Aggregation Not Needed

### Why Previous Implementation Had Aggregation

Old pattern created "step contexts" for each retargeting event:

```lua
-- OLD: Store array of contexts during retargeting
bar.animation.contexts = {xpContext1, xpContext2, xpContext3}

-- OLD: Aggregate all contexts each frame
local aggregatedContext = AnimationUtils.AggregateContexts(bar.animation.contexts)

-- OLD: Use aggregated context for rendering
bar:ApplyAnimationStep(BuildStepContext(..., aggregatedContext))
```

### Why This Is No Longer Needed

With immutable event context:

```lua
-- NEW: Store single immutable context
bar.animation.eventContext = eventContext  -- Created once at animation start

-- NEW: Retargeting only updates animation state (not context)
if bar.animation.isAnimating then
    -- Update current position (for smooth retargeting)
    bar.animation.startRatio = CalculateCurrentRatio(bar.animation, now)
    -- Update target
    bar.animation.targetRatio = newTargetRatio
    -- Context unchanged!
end

-- NEW: Use original context every frame
bar:RenderBarFrame(currentRatio, bar.animation.eventContext, flashAlpha, flashPhase)
```

### Benefits

- ✅ No aggregation logic needed
- ✅ Original event context preserved throughout animation
- ✅ Retargeting is simple state update
- ✅ Flash decision made once (based on original context)
- ✅ Simpler code, easier to understand

### Why This Matters

Previous documentation mentioned removing `AggregateContexts` but didn't explain why it's not needed, which:

- Made it seem like a risky removal
- Left uncertainty about retargeting behavior
- Didn't clarify that retargeting only updates animation state, not context

---

## 5. RenderBarFrame Signature

### Correct Signature

```lua
function BarStyle:RenderBarFrame(currentRatio, context, flashAlpha, flashPhase)
    -- currentRatio: number (0.0-1.0) - current bar fill percentage
    -- context: table (immutable) - event context with all state
    -- flashAlpha: number (0.0-1.0) - current flash opacity (0 = no flash)
    -- flashPhase: string|nil - "fade_in", "hold", "fade_out", or nil
end
```

### Why Iteration Data As Parameters

**Not** embedded in context:

```lua
-- ❌ WRONG: Iteration data in context
function RenderBarFrame(currentRatio, context)
    if context.flashAlpha > 0 then  -- Would require creating new context object
        -- ...
    end
end

-- ✅ CORRECT: Iteration data as parameters
function RenderBarFrame(currentRatio, context, flashAlpha, flashPhase)
    if flashAlpha > 0 then  -- Parameters are free (no allocation)
        -- ...
    end
end
```

### Benefits

- ✅ Zero allocation per frame
- ✅ Clear separation of concerns
- ✅ Easy to add new iteration parameters
- ✅ Context remains immutable
- ✅ Same pattern for instant and animated updates (just pass 0 for flash)

---

## Summary of Changes to Documentation

### ANIMATION_REFACTOR_ANALYSIS.md

1. ✅ Added "Animation Workflows" section explaining two independent workflows
2. ✅ Renamed "Context Preservation" to "Animation Context vs Iteration Data"
3. ✅ Clarified immutable context vs per-frame iteration data
4. ✅ Updated AnimationManager examples to show parameter passing
5. ✅ Removed fallback patterns from examples
6. ✅ Updated RenderBarFrame signature to include flashAlpha, flashPhase

### ANIMATION_REFACTOR_SUMMARY.md

1. ✅ Added "Animation Workflows" section at top
2. ✅ Updated "What's Being Optimized" to clarify context vs iteration data
3. ✅ Removed mentions of "frame context" creation
4. ✅ Clarified "zero allocation per frame" benefit
5. ✅ Removed fallback pattern from Phase 2 validation
6. ✅ Removed "Remove backward compatibility fallback" from Phase 6
7. ✅ Added independent workflow testing to Phase 6
8. ✅ Updated RenderBarFrame signature in Phase 5
9. ✅ Updated Risk Mitigation to remove fallback strategy

### ANIMATION_REFACTOR_PLAN.md

(Will be updated similarly with full code examples)

---

## Key Takeaways

1. **Two Workflows**: Bar animation and flash animation are independent with separate lifecycles
2. **Immutable Context**: Created once, never modified, referenced every frame
3. **Iteration Data**: Calculated per frame, passed as parameters, zero allocation
4. **No Fallback**: Clean break, fail fast, all styles updated simultaneously
5. **No Aggregation**: Immutable context eliminates need for context aggregation during retargeting

These clarifications ensure the refactor achieves maximum performance (zero allocation per frame) while maintaining clean, maintainable code!
