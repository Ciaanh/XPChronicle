# V2 Animation State Refactoring

## Problem

The V2 architecture had a design flaw where animation state was tracked in two places:

1. **`self._currentRatio`** - A property directly on the bar instance
2. **`self.animation`** - The animation context table

This violated the principle that **animation state should be fully encapsulated in the animation context**.

### Issues This Caused

1. **Dual source of truth**: Code had to check both `_currentRatio` and `self.animation` 
2. **Initialization bugs**: `_currentRatio` was used to detect first load, causing race conditions
3. **Architectural inconsistency**: XP data comes from context (immutable), but display ratio was a mutable property
4. **Delta calculation bugs**: Setting `_currentRatio` before animation started caused zero-delta instant updates

## Solution

**Move `currentRatio` into the `animation` context where it belongs.**

### Before (Broken)

```lua
-- AnimationBase.lua
function AnimationBase:InitializeAnimation()
    self.animation = {
        isAnimating = false,
        startRatio = 0,
        targetRatio = 0,
        -- ...
    }
    self._currentRatio = 0  -- ⚠️ Separate property!
end

function AnimationBase:GetCurrentRatio()
    return self._currentRatio or 0  -- ⚠️ Reading separate property
end

function AnimationBase:SetCurrentRatio(ratio)
    self._currentRatio = ratio  -- ⚠️ Writing separate property
end
```

```lua
-- CircularBarStyle.lua
function UpdateSegmentColors(hasRestedXP)
    local progress = self._currentRatio or self.lastProgress or 0  -- ⚠️ Reading separate property
    -- ...
end

function UpdateCurrentXPBar(context)
    if not self._currentRatio then  -- ⚠️ Using for initialization detection
        self:SetCurrentRatio(targetRatio)  -- ⚠️ Causes zero-delta bug!
    end
    -- ...
end
```

### After (Fixed)

```lua
-- AnimationBase.lua
function AnimationBase:InitializeAnimation()
    self.animation = {
        isAnimating = false,
        currentRatio = 0,  -- ✓ Part of animation context!
        startRatio = 0,
        targetRatio = 0,
        -- ...
    }
    -- No separate _currentRatio property
end

function AnimationBase:GetCurrentRatio()
    return self.animation and self.animation.currentRatio or 0  -- ✓ Reading from context
end

function AnimationBase:SetCurrentRatio(ratio)
    if self.animation then
        self.animation.currentRatio = ratio  -- ✓ Writing to context
    end
end
```

```lua
-- CircularBarStyle.lua
function UpdateSegmentColors(hasRestedXP)
    local progress = 0
    if self.animation and self.animation.currentRatio then
        progress = self.animation.currentRatio  -- ✓ Reading from animation context
    elseif self.lastProgress then
        progress = self.lastProgress
    end
    -- ...
end

function UpdateCurrentXPBar(context)
    -- Check animation state, not separate property
    local isFirstInit = not self.animation or self.animation.currentRatio == 0
    
    if isFirstInit then
        -- DON'T set currentRatio here - let animation system handle it!
        self:SetArcProgress(targetRatio, hasRestedXP)  -- ✓ Visual only
    end
    -- ...
end
```

## Benefits

### 1. Single Source of Truth
All animation state lives in `self.animation`:
- `currentRatio` - where the bar is visually (updated every frame)
- `startRatio` - where animation began
- `targetRatio` - where animation is heading
- `isAnimating` - whether animation is active
- `isFlashing` - whether flash effect is active

### 2. Clear Ownership
- **AnimationManager** owns and updates `animation.currentRatio`
- **Bar styles** read from `animation.currentRatio` (read-only)
- **No initialization logic** touches `currentRatio` directly

### 3. Proper Delta Calculation
```lua
-- Initialization doesn't set currentRatio
isFirstInit → currentRatio = 0 (from InitializeAnimation)

-- First animation call
startRatio = GetCurrentRatio() = 0
targetRatio = 0.25
delta = |0.25 - 0| = 0.25  ✓ Non-zero!

-- Animation proceeds smoothly
AnimationManager updates currentRatio every frame: 0.0 → 0.05 → 0.10 → ... → 0.25
```

### 4. No Race Conditions
Initialization flow is now clean:
1. `InitializeAnimation()` → sets `animation.currentRatio = 0`
2. `UpdateCurrentXPBar()` → does NOT touch `currentRatio`
3. `StartAnimation()` → reads `currentRatio = 0`, calculates delta correctly
4. `AnimationManager:OnUpdate()` → updates `currentRatio` every frame

## Changed Files

### Core Animation System
- ✅ `ui/xpbars/mixins/animation/AnimationBase.lua`
  - Moved `currentRatio` into `animation` table
  - Updated `GetCurrentRatio()` and `SetCurrentRatio()` to use context

### Bar Styles
- ✅ `ui/xpbars/circular_v2/CircularBarStyle.lua`
  - Changed initialization detection from `not self._currentRatio` to `not self.animation or self.animation.currentRatio == 0`
  - Updated `UpdateSegmentColors()` to read from `animation.currentRatio`
  - Removed premature `SetCurrentRatio()` call in initialization block

- ✅ `ui/xpbars/flatbar_v2/FlatBarStyle.lua`
  - Changed initialization detection from `not self._currentRatio` to `not self.animation or self.animation.currentRatio == 0`

### Not Changed
- ❌ V1 legacy code (`XPBarMixinBase.lua`, etc.) - still uses `_currentRatio` (separate architecture)
- ❌ Documentation files - preserved for historical reference

## Testing Checklist

- [ ] `/xptest flat` - FlatBar displays correctly on load
- [ ] `/xptest circular` - CircularBar displays correctly on load  
- [ ] Both bars animate smoothly from 0 → current XP on first load
- [ ] Flash animation works on XP gain for both bars
- [ ] Retargeting works (XP gain during animation)
- [ ] Level up animation works correctly
- [ ] Refresh events don't break display
- [ ] No Lua errors in chat

## Architecture Principle

**Animation state belongs in animation context, not as separate properties.**

This refactoring aligns V2 with its core design principle:
- **Immutable XP context** (from XPBarContextBuilder) → passed through update chain
- **Mutable animation state** (in `self.animation`) → owned by AnimationManager
- **Bar styles** are stateless processors that read from contexts

The bar should be a pure function: `f(xpContext, animationContext) → visuals`
