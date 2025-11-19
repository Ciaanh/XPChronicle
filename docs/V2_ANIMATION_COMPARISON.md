#  Flat Bar — XP Gain Animation Implementation Plan

**Purpose**: Implement the complete  animation stack for the **Flat bar style** with smooth XP bar fill, gain flash effects, retargeting, and level-up handling. Classic bar specificities are documented for future migration.

**Scope**: Complete animation system for Flat bar (uses WoW StatusBar widget). Classic, Circular, and Vertical styles will be migrated later using the same foundation.

## Executive summary

- **V1 reference**: V1 Flat bar implements smooth bar fill (0.3–2.0s with easeOut quad) and XP gain flash (0.5s additive overlay, purple/cyan color) on top of a shared `XPBarMixinBase` and global `AnimationDriver`. Flat uses WoW StatusBar widget for rendering with solid color texture.
- ** independence**:  will have its **own** animation module completely separate from V1. Copy V1 helper functions (easing, duration calculation) into  rather than sharing code.
- **Architecture**: Build a standalone  AnimationManager (single shared OnUpdate driver) + AnimationBase mixin + per-bar animation state. Flat style provides concrete implementations of AnimateBarPosition and AnimateBarEffect.
- **Initial implementation**: Flat bar only with full feature set (smooth fill, flash, retargeting, level-up handling). Other styles (Classic, Circular, Vertical) will be migrated later.
- **Classic bar notes**: Classic bar uses identical animation logic to Flat bar (both StatusBar-based), only differing in visual texture (atlas vs solid color). Documented for future migration reference.

## Contract (what to deliver)

**Inputs**:
- Immutable XP change context: `{ xpBefore, xpAfter, xpMax, xpGained, isRested, timestamp }`
- User animation config: `{ enableAnimations, animationSpeed, flashOnGain }`

**Outputs / Effects**:
- **Smooth bar fill**: Interpolate from startRatio → targetRatio with easeOut quad easing.
- **XP gain flash**: Additive overlay flash (0.5s total: 0.25s fade in, 0.25s fade out, max alpha 0.5). Color: rested (cyan `0.0, 0.4, 0.8`) or normal (purple `0.58, 0.0, 0.55`).
- **Retargeting**: Smoothly retarget to new ratio when XP gain arrives during animation, aggregate contexts.
- **Level-up handling**: Detect level-up, cancel animations, reset bar, animate to new position.
- **Instant mode**: If animations disabled or delta < 0.001 (0.1%), update bar instantly with no animation.
- **Cleanup**: Deterministic unregister and state reset on Hide/style change.

**Error modes / constraints**:

- If `enableAnimations = false`, all updates are instant.
- Delta < 0.001 threshold → instant update (avoid wasting CPU on tiny changes).
- Level-up detection: `xpAfter < xpBefore` indicates level-up, must reset bar position.
- Retargeting during animation: must preserve smooth motion, avoid visual jumps.
- Must use shared AnimationDriver OnUpdate (no per-bar SetScript) for stability.

## V1 behaviours to replicate (Flat bar, StatusBar-based)

The Flat bar in V1 uses the following animation behaviors:

1. **Smooth Bar Fill**
   - Duration formula: `MIN_DURATION + (delta * (MAX_DURATION - MIN_DURATION))` where delta = |targetRatio - startRatio|.
   - Constants: MIN=0.3s, MAX=2.0s, apply user speed multiplier, clamp final to [0.25, 2.0].
   - Easing: easeOut quad `t → 1 - (1-t)²`.
   - Update method: `StatusBar:SetValue(ratio)` to update fill.

2. **XP Gain Flash**
   - Triggered when `xpGained > 0`.
   - Half-period: 0.25s (fade in), 0.25s (fade out), total 0.5s.
   - Max alpha: 0.5, blend mode: ADD.
   - Color: if `isRested` → cyan `(0.0, 0.4, 0.8)`, else → purple `(0.58, 0.0, 0.55)`.
   - Implementation: `GainFlash` texture overlay with additive blending.

3. **Retargeting** (required)
   - When new XP gain arrives during active animation, aggregate contexts and smoothly retarget to new ratio.
   - Restart animation from current visual position to new target without jarring reset.
   - Preserve accumulated XP gain information for context.

4. **Level-Up Handling** (required)
   - Detect level-up when `xpAfter < xpBefore` (XP resets on level).
   - Cancel current animations cleanly.
   - Reset bar to 0, then animate to new XP position.
   - Update level display immediately.

### Classic bar specificities (for future migration reference)

Classic bar uses **identical animation logic** to Flat bar with one key difference:
- **Visual texture**: Classic uses atlas texture (`"UI-HUD-ExperienceBar-Fill"`) via `StatusBar:SetStatusBarTexture()`, while Flat uses solid color via `StatusBar:SetStatusBarColor(r, g, b)`.
- **Animation code**: 100% identical to Flat bar (same StatusBar:SetValue, same GainFlash overlay, same helpers).
- **Migration strategy**: When migrating Classic bar to  later, copy Flat bar's three animation methods (`ApplyAnimationStep`, `AnimateBarPosition`, `AnimateBarEffect`) verbatim. Only bar initialization/styling differs.

3. **Retargeting** (required)
   - When new XP gain arrives during active animation, aggregate contexts and smoothly retarget to new ratio.
   - Restart animation from current visual position to new target without jarring reset.
   - Preserve accumulated XP gain information for context.

4. **Level-Up Handling** (required)
   - Detect level-up when `xpAfter < xpBefore` (XP resets on level).
   - Cancel current animations cleanly.
   - Reset bar to 0, then animate to new XP position.
   - Update level display immediately.

##  architecture design

**Principle**:  animation code is completely independent of V1. Copy helpers from V1 where needed rather than sharing. Support multiple styles (Classic and Flat implemented now, Circular/Vertical later) through a unified animation base with style-specific apply implementations.

**Components**:

1. **AnimationManager** (`ui/xpbars/animation/AnimationManager.lua`)
   - Single shared AnimationDriver frame with OnUpdate.
   - Manages registered bars and per-frame animation updates.
   - Provides: `Register(bar)`, `Unregister(bar)`, `AnimateTo(bar, targetRatio, context, config)`.
   - Handles retargeting and level-up detection.
   - Copied helpers: `CalculateDuration(delta, speedMultiplier)`, `EaseOutQuad(t)`.

2. **Per-bar animation state** (stored in bar instance)
   - `animation = { isAnimating, startRatio, targetRatio, startTime, duration, flashStartTime, flashDuration, flashColor, isFlashing, context, accumulatedXP }`
   - `accumulatedXP` tracks total XP gained during retargeting for accurate context aggregation.

3. **AnimationBase mixin** (`ui/xpbars/animation/AnimationBase.lua`)
   - Common animation behavior that all styles inherit.
   - Provides: `InitializeAnimation()`, `StartAnimation(targetRatio, context, config)`, `CleanupAnimation()`.
   - Defines `ApplyAnimationStep(stepContext)` which orchestrates calls to bar position and effect updates.
   - **Does NOT implement rendering** — delegates to style via concrete update functions.

4. **Style-specific implementations** (Flat bar for initial implementation)
   - `ApplyAnimationStep(self, stepContext)` — orchestrates the animation step by calling:
     - `AnimateBarPosition(stepContext)` — updates bar fill based on currentRatio.
     - `AnimateBarEffect(stepContext)` — applies visual effects (flash overlay).
   - **Flat bar**: Implements all three methods for StatusBar-based rendering with solid color texture.
   - **Future styles**: Classic (copy Flat's methods, only styling differs), Circular (custom rendering), Vertical (custom rendering).

**Step Context Structure**:

The `stepContext` passed to `ApplyAnimationStep` contains all interpolated values, timing information, and metadata needed for rendering:

```lua
stepContext = {
    -- Core interpolated values
    currentRatio = 0.5,           -- Current interpolated fill ratio (0-1)
    targetRatio = 0.75,           -- Final target ratio
    startRatio = 0.25,            -- Starting ratio when animation began
    progress = 0.3,               -- Animation progress (0-1, linear)
    easedProgress = 0.51,         -- Eased progress (0-1, after easing function)
    
    -- Timing information
    startTime = 12345.0,          -- GetTime() when animation started
    currentTime = 12345.3,        -- Current GetTime()
    elapsedTime = 0.3,            -- Time elapsed since animation start (currentTime - startTime)
    duration = 1.0,               -- Total animation duration in seconds
    
    -- Flash timing (if flashing)
    flashStartTime = 12345.0,     -- GetTime() when flash started
    flashDuration = 0.5,          -- Total flash duration in seconds
    flashElapsed = 0.3,           -- Time elapsed since flash start
    
    -- Flash data (if flashing)
    isFlashing = true,
    flashAlpha = 0.4,             -- Current flash alpha (0-0.5)
    flashColor = {r=0.58, g=0.0, b=0.55},  -- Flash color (normal/rested)
    
    -- Configuration
    animationSpeed = 1.0,         -- Speed multiplier from config
    enableAnimations = true,      -- Whether animations are enabled
    flashOnGain = true,           -- Whether flash effect is enabled
    
    -- Context (immutable, from original XP change)
    xpContext = {
        xpBefore = 1000,
        xpAfter = 1200,
        xpMax = 5000,
        xpGained = 200,
        isRested = false,
        timestamp = 12345.67
    }
}
```

**Style implementations**:

Each style mixin implements three methods:

1. **`ApplyAnimationStep(stepContext)`** — orchestrates the animation step:

   ```lua
   function StyleMixin:ApplyAnimationStep(stepContext)
       self:AnimateBarPosition(stepContext)
       self:AnimateBarEffect(stepContext)
   end
   ```

2. **`AnimateBarPosition(stepContext)`** — updates bar fill/segments:
   - **Classic bar**: Updates StatusBar:SetValue(currentRatio).
   - **Flat bar**: Updates StatusBar:SetValue(currentRatio).
   - **Circular style** (future): Shows/hides ring segments based on currentRatio; could use timing for custom easing per segment.
   - **Vertical style** (future): Updates fill texture height; could use elapsedTime for physics-based falling animation.

3. **`AnimateBarEffect(stepContext)`** — applies visual effects:
   - **Classic bar**: Shows/hides flash overlay with color/alpha based on flashElapsed.
   - **Flat bar**: Shows/hides flash overlay with color/alpha based on flashElapsed.
   - **Circular style** (future): Shows/hides glow overlay with alpha; could use timing for custom pulse patterns.
   - **Vertical style** (future): Could trigger particle effects based on progress, bounce animation based on elapsedTime, etc.

**API**:

```lua
-- Register bar with style implementation
AnimationManager:Register(bar)
-- bar must have AnimationBase mixed in and implement ApplyAnimationStep

-- Trigger animation to target ratio
AnimationManager:AnimateTo(bar, targetRatio, context, config)
-- context: { xpBefore, xpAfter, xpMax, xpGained, isRested, timestamp }
-- config: { enableAnimations, animationSpeed, flashOnGain }

-- Unregister (called on Hide)
AnimationManager:Unregister(bar)
```

**Event flow**:

```text
1.  XP update event
   └─> ContextBuilder creates context { xpBefore, xpAfter, xpMax, xpGained, isRested }

2. Style mixin (Flat/Circular) receives context
   └─> If xpGained > 0:
       └─> AnimationManager:AnimateTo(self, targetRatio, context, config)

3. AnimationManager:AnimateTo()
   ├─> Checks for level-up: if xpAfter < xpBefore:
   │   ├─> Cancel current animation
   │   ├─> Reset bar to 0 via ApplyAnimationStep
   │   ├─> Update level display
   │   └─> Recalculate targetRatio with new maxXP
   ├─> Checks if currently animating (retargeting case):
   │   ├─> If isAnimating:
   │   │   ├─> Aggregate contexts:
   │   │   │   - Keep original startRatio from first animation
   │   │   │   - Update targetRatio to new target
   │   │   │   - Accumulate xpGained values
   │   │   │   - Preserve isRested if any gain was rested
   │   │   ├─> Recalculate duration from current position to new target
   │   │   ├─> Update animation state with new target
   │   │   └─> Continue animation smoothly
   ├─> Checks ShouldAnimate(delta, config) → instant or animate
   ├─> If instant:
   │   ├─> Creates stepContext with currentRatio = targetRatio
   │   ├─> Calls bar:ApplyAnimationStep(stepContext)
   │   └─> return
   ├─> If animate:
   │   ├─> Sets bar.animation state (startRatio, targetRatio, startTime, duration)
   │   ├─> If flashOnGain: sets flash state (flashStartTime, flashColor, isFlashing)
   │   └─> Ensures AnimationDriver OnUpdate is running

4. AnimationDriver OnUpdate (60 FPS)
   └─> For each registered bar:
       ├─> UpdateBarAnimation(bar, now)
       │   ├─> elapsedTime = now - bar.animation.startTime
       │   ├─> progress = elapsedTime / bar.animation.duration
       │   ├─> easedProgress = EaseOutQuad(progress)
       │   ├─> currentRatio = startRatio + (targetRatio - startRatio) * easedProgress
       │   ├─> If flashing:
       │   │   ├─> flashElapsed = now - bar.animation.flashStartTime
       │   │   ├─> Calculate flashAlpha (fade in/out)
       │   │   └─> Add flash timing and data to stepContext
       │   ├─> Build stepContext:
       │   │   {
       │   │       -- Interpolated values
       │   │       currentRatio = currentRatio,
       │   │       targetRatio = bar.animation.targetRatio,
       │   │       startRatio = bar.animation.startRatio,
       │   │       progress = progress,
       │   │       easedProgress = easedProgress,
       │   │       -- Timing
       │   │       startTime = bar.animation.startTime,
       │   │       currentTime = now,
       │   │       elapsedTime = elapsedTime,
       │   │       duration = bar.animation.duration,
       │   │       -- Flash timing (if applicable)
       │   │       flashStartTime = bar.animation.flashStartTime,
       │   │       flashDuration = bar.animation.flashDuration,
       │   │       flashElapsed = flashElapsed,
       │   │       -- Flash data
       │   │       isFlashing = bar.animation.isFlashing,
       │   │       flashAlpha = flashAlpha,
       │   │       flashColor = bar.animation.flashColor,
       │   │       -- Config
       │   │       animationSpeed = config.animationSpeed,
       │   │       enableAnimations = config.enableAnimations,
       │   │       flashOnGain = config.flashOnGain,
       │   │       -- Original context
       │   │       xpContext = bar.animation.context
       │   │   }
       │   ├─> bar:ApplyAnimationStep(stepContext)  ← Style-specific rendering
       │   └─> If progress >= 1 and not flashing: mark complete, cleanup
       └─> If no bars animating: pause driver
```

## Files to change (proposal)

**New files** (to be created):

- `ui/xpbars/animation/AnimationManager.lua` — core animation driver, registration, per-frame update loop, retargeting, and level-up detection.
- `ui/xpbars/animation/AnimationBase.lua` — mixin providing common animation behavior, calls style-specific ApplyAnimationStep.
- `ui/xpbars/animation/AnimationUtils.lua` — copied V1 helpers: `CalculateDuration`, `EaseOutQuad`, `ShouldAnimate`, `BuildStepContext`, `AggregateContexts`, `DetectLevelUp`.

**Modified files** (Classic and Flat bar integration):

- `ui/xpbars/BaseMixin.lua` — mix in AnimationBase, add animation state initialization, registration/unregistration hooks (OnShow/OnHide).
- `ui/xpbars/styles/ClassicBar.lua` (or existing classic style file):
  - Implement `ApplyAnimationStep(stepContext)` — orchestrator.
  - Implement `AnimateBarPosition(stepContext)` — updates StatusBar:SetValue(currentRatio).
  - Implement `AnimateBarEffect(stepContext)` — shows/hides flash overlay, can use flashElapsed for custom timing.
  - Wire XP update to call `AnimationManager:AnimateTo`.
- `ui/xpbars/styles/ClassicBar.xml` (or template file) — add `GainFlash` texture (simple white texture, additive blend mode) if not already present.
- `ui/xpbars/styles/FlatBar.lua` (or existing flat style file):
  - Implement `ApplyAnimationStep(stepContext)` — orchestrator.
  - Implement `AnimateBarPosition(stepContext)` — updates StatusBar:SetValue(currentRatio).
  - Implement `AnimateBarEffect(stepContext)` — shows/hides flash overlay, can use flashElapsed for custom timing.
  - Wire XP update to call `AnimationManager:AnimateTo`.
- `ui/xpbars/styles/FlatBar.xml` (or template file) — add `GainFlash` texture (simple white texture, additive blend mode) if not already present.
- `ui/xpbars/_includes.xml` (or equivalent) — include `AnimationManager.lua`, `AnimationBase.lua`, and `AnimationUtils.lua`.

**Future migration files** (not in this phase):

- `ui/xpbars/styles/ClassicBar.lua` — will copy Flat bar's three animation methods verbatim (only texture styling differs).
- `ui/xpbars/styles/CircularBar.lua` — will implement custom animation methods for segment rendering.
- `ui/xpbars/styles/VerticalBar.lua` — will implement custom animation methods for falling animation.

**V1 files** (reference only, no changes):

- `ui/xpbar/XPBarMixinBase.lua` — copy helpers from here, do not modify.

## Edge cases and tests

**Edge cases to cover** (Flat bar, StatusBar-based):

1. **Rapid successive gains (retargeting)** — aggregate contexts, keep original start, update target, recalculate duration from current position.
2. **Level-up during animation** — detect `xpAfter < xpBefore`, cancel animation, reset to 0, start fresh animation to new XP position.
3. **Level-up without animation** — when player is max level or XP tracking disabled.
4. **Disabled animations** — instant update path via `ApplyAnimationStep` with final ratio, no flash.
5. **Small delta (< 0.001)** — instant update even if animations enabled.
6. **View hidden while animating** — unregister, cancel timers, reset state.
7. **Config change mid-animation** — respect new speed multiplier on next animation; current animation completes with old settings.
8. **StatusBar-specific edge cases**:
   - StatusBar edge values (0.0, 1.0).
   - Flash overlay visibility and z-order.
   - StatusBar minValue/maxValue range (should be 0-1 for ratios).
9. **Multiple rapid level-ups** — ensure each level-up properly resets the bar.
10. **XP loss** (rare but possible) — handle negative xpGained gracefully.

**Note:** Classic bar will share these edge cases when migrated (identical StatusBar-based logic).

**Proposed tests** (manual in-game checks for Flat bar):

- **Single XP gain** (quest turn-in): verify smooth fill and flash overlay.
- **Rapid gains** (kill multiple mobs quickly): verify retargeting, smooth transition to new target without jumps.
- **Level-up** (reach next level): verify bar resets to 0, then animates to new XP position.
- **Disable animations** in config: verify instant updates.
- **Hide bar while animating**: verify no errors, cleanup successful.
- **Config change during animation**: change speed setting, verify next animation uses new speed.
- **Multiple rapid level-ups** (if testable with rapid XP potions): verify each level-up resets properly.

**Future migration QA:** When migrating Classic bar, repeat all tests above and verify visual parity with Flat bar (only texture should differ).

## Performance considerations

- **Single global OnUpdate**: AnimationDriver frame with one SetScript("OnUpdate") for all bars.
- **Early exit**: if no bars animating, driver pauses itself.
- **Minimal allocations**: reuse local variables in OnUpdate loop, pre-allocate animation state table on Register.
- **Threshold check**: skip animation for delta < 0.001 to avoid wasting CPU.

## Implementation plan & effort estimate

**Phase 1 — Core animation system** (2–3 days):

- Create `ui/xpbars/animation/AnimationManager.lua`:
  - AnimationDriver frame with OnUpdate.
  - Register/Unregister/AnimateTo API.
  - Per-frame update loop that builds stepContext and calls bar:ApplyAnimationStep.
  - **Retargeting logic**: detect ongoing animation, aggregate contexts, recalculate duration.
  - **Level-up detection**: detect `xpAfter < xpBefore`, reset bar, start fresh animation.
- Create `ui/xpbars/animation/AnimationBase.lua`:
  - Mixin providing InitializeAnimation, StartAnimation, CleanupAnimation.
  - Defines ApplyAnimationStep contract (abstract method).
- Create `ui/xpbars/animation/AnimationUtils.lua`:
  - Copy `CalculateDuration`, `EaseOutQuad`, `ShouldAnimate`, `BuildStepContext` from V1.
  - Add `AggregateContexts` helper for retargeting.
  - Add `DetectLevelUp` helper.
- Mix AnimationBase into BaseMixin.
- Add animation state initialization in BaseMixin.
- Include animation files in `_includes.xml`.

**Phase 2 — Flat bar implementation** (1–2 days):

- Add flash texture to Flat bar XML (simple additive overlay) if not already present.
- Implement three methods in Flat style mixin:
  - `ApplyAnimationStep(stepContext)` — calls AnimateBarPosition and AnimateBarEffect.
  - `AnimateBarPosition(stepContext)` — updates StatusBar:SetValue(stepContext.currentRatio).
  - `AnimateBarEffect(stepContext)` — if flashing, shows flash with color/alpha; else hides flash.
- Wire XP update events to call `AnimationManager:AnimateTo`.
- Manual tests: single gain, rapid gains with retargeting, level-up, disabled animations, hide during animation.

**Phase 3 — Polish and hardening** (1–2 days):

- Add edge case handling for XP loss, multiple rapid level-ups.
- Add inline comments and documentation.
- Add `ui/xpbars/animation/README.md` with API contract and usage examples.
- Verify cleanup logic for all edge cases.
- Performance profiling (ensure minimal overhead on OnUpdate).
- Add config toggle `db.AnimationsEnabled` (default false initially) for staged rollout.

**Phase 4 — QA and rollout** (1 day):

- Manual QA for all test cases (see tests section above).
- Fix any issues found during QA.
- Enable `db.AnimationsEnabled` by default.
- Document migration path for other styles (Classic, Circular, Vertical) in separate migration doc.

**Total estimate for Flat bar  animation**: **4–6 days**.

**Future migration** (not in this phase):

- Classic style: **1 day** (copy Flat bar's three methods verbatim, only texture styling differs).
- Circular style: **2–3 days** (implement custom animation methods for segment rendering, test retargeting).
- Vertical style: **3–4 days** (implement custom animation methods for falling animation, particles).

## Rollout & testing checklist

1. Implement Phase 1 (core animation system with AnimationBase, retargeting, level-up).
2. Implement Phase 2 (Flat bar: ApplyAnimationStep, AnimateBarPosition, AnimateBarEffect).
3. Add config toggle `db.AnimationsEnabled` (default false) for staged rollout.
4. Manual QA for Flat bar:
   - Turn in quest → verify smooth fill + flash.
   - Kill 3–5 mobs rapidly → verify retargeting, smooth transition without jumps.
   - Level up → verify bar resets to 0, animates to new XP position.
   - Disable animations → verify instant update via ApplyAnimationStep.
   - Hide bar while animating → verify cleanup, no errors.
   - Change speed setting during animation → verify next animation uses new speed.
5. Implement Phase 3 (polish and hardening).
6. Final QA pass with all edge cases.
7. Enable `db.AnimationsEnabled` by default after successful QA.
8. Document migration path for Classic, Circular, and Vertical styles in separate doc.

## Backward compatibility notes

- **V1 independence**:  animation code does not touch V1 files (`ui/xpbar/*`). V1 bars continue to use `XPBarMixinBase.lua` and existing AnimationDriver.
- **No shared code**: Copy helpers from V1 into  `AnimationUtils.lua`. Accept duplication; refactor later if needed.
- **Config separation**:  uses same config keys (`enableAnimations`, `animationSpeed`, `flashOnGain`) but reads them independently in  animation module.

## Suggested follow-ups / low-risk extras

- Add `ui/xpbars/animation/README.md` with API contract, stepContext structure, and usage examples for implementing ApplyAnimationStep, AnimateBarPosition, and AnimateBarEffect.
- Add simple Lua unit tests for `CalculateDuration`, `EaseOutQuad`, and `BuildStepContext` (if project has test harness).
- Add inline comments in AnimationManager and AnimationBase for maintainability.
- Document the three-method contract (ApplyAnimationStep, AnimateBarPosition, AnimateBarEffect) with example implementations for Flat and Circular styles.

---

## Example implementations

### Flat style

```lua
-- Orchestrator
function FlatBarMixin:ApplyAnimationStep(stepContext)
    self:AnimateBarPosition(stepContext)
    self:AnimateBarEffect(stepContext)
end

-- Bar position update
function FlatBarMixin:AnimateBarPosition(stepContext)
    self.StatusBar:SetValue(stepContext.currentRatio)
end

-- Visual effects
function FlatBarMixin:AnimateBarEffect(stepContext)
    if stepContext.isFlashing then
        local color = stepContext.flashColor
        self.GainFlash:SetColorTexture(color.r, color.g, color.b, stepContext.flashAlpha)
        self.GainFlash:Show()
    else
        self.GainFlash:Hide()
    end
    
    -- Could use stepContext.flashElapsed for custom timing patterns:
    -- e.g., pulse rate based on flashElapsed, or custom easing
end
```

### Circular style (future migration reference)

```lua
-- Orchestrator
function CircularBarMixin:ApplyAnimationStep(stepContext)
    self:AnimateBarPosition(stepContext)
    self:AnimateBarEffect(stepContext)
end

-- Bar position update
function CircularBarMixin:AnimateBarPosition(stepContext)
    local segmentsToShow = math.floor(stepContext.currentRatio * self.RING_SEGMENTS + 0.5)
    for i = 1, self.RING_SEGMENTS do
        if i <= segmentsToShow then
            self.segments[i]:Show()
        else
            self.segments[i]:Hide()
        end
    end
    
    -- Could use stepContext.elapsedTime for per-segment delay/wave effects:
    -- e.g., each segment appears with slight delay based on its index and elapsedTime
end

-- Visual effects
function CircularBarMixin:AnimateBarEffect(stepContext)
    if stepContext.isFlashing then
        self.GlowOverlay:SetAlpha(stepContext.flashAlpha)
        self.GlowOverlay:Show()
    else
        self.GlowOverlay:Hide()
    end
    
    -- Could use stepContext timing for custom glow patterns:
    -- e.g., pulsing glow with period based on flashDuration,
    -- or rotation speed based on animationSpeed config
end
```

### Classic style (future migration reference)

**Implementation note:** When migrating Classic bar, use the **exact same three methods as Flat bar**. The only difference is texture initialization:
- Classic: `StatusBar:SetStatusBarTexture("UI-HUD-ExperienceBar-Fill")` during bar setup
- Flat: `StatusBar:SetStatusBarColor(r, g, b)` during bar setup

Animation code is 100% identical to Flat bar shown above.

---

**Document revision**: 2025-11-06  
**Prepared for implementation**: Complete  animation stack for Flat bar style with retargeting and level-up handling. Classic, Circular, and Vertical styles will be migrated in future phases using this foundation.
