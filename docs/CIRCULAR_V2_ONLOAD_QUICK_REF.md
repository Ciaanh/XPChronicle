# Circular V2 OnLoad Analysis - Quick Reference

## Problem
Circular V2 bar doesn't display correctly on initial load - bar and text remain empty until an XP event occurs.

## Root Causes

### 1. Early Return in RenderBar (Primary Issue)
**Location:** `CircularBarStyle.lua:447-453`

```lua
if not self._currentRatio then
    self:SetCurrentRatio(targetRatio)
    self:RenderBarFrame(targetRatio, context)
    return  -- ❌ Exits before overlay/text updates!
end
```

**Impact:** Overlay update methods (`UpdateRestedOverlay`, etc.) are never called, leaving cached overlay data at zero.

### 2. Duplicate RenderBar Call in OnLoad (Secondary Issue)
**Location:** `CircularBarStyle.lua:70-76`

```lua
function CircularBarStyleTemplate:OnLoad()
    -- ... setup ...
    XPBarMixinBase_v2.OnLoad(self)  -- Calls Refresh() → RenderBar()
    
    -- ❌ Duplicate call
    local context = XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD")
    self:RenderBar(context)
end
```

**Impact:** RenderBar is called twice on load, both hitting the early return path.

### 3. Cached Overlay Pattern Without Initialization
**Location:** `CircularBarStyle.lua:SetArcProgress`

```lua
-- SetArcProgress reads from cached data
local restedXP = self.cachedRestedXP or 0  -- ❌ Zero on first load!
local completeQuestXP = self.cachedCompleteQuestXP or 0
local incompleteQuestXP = self.cachedIncompleteQuestXP or 0
```

**Impact:** Segments are drawn using empty cache values, resulting in empty/background colored ring.

## Architecture Comparison

| Feature | Legacy/Vertical V2 | Circular V2 (Current) |
|---------|-------------------|----------------------|
| Custom OnLoad | ❌ No | ✅ Yes |
| Early return in RenderBar | ❌ No | ✅ Yes (bug) |
| Overlay updates in RenderBar | ✅ Always | ❌ Never (early return) |
| Text updates in RenderBar | ✅ Yes | ❌ No (in RenderBarFrame) |
| Cached overlay data | ❌ Not used | ✅ Yes (requires init) |
| Works on first load | ✅ Yes | ❌ No |

## Fix Strategy

### Required Changes

**File:** `ui/xpbars/circular_v2/CircularBarStyle.lua`

#### Change 1: Fix RenderBar Method
Remove early return and add overlay/text updates (lines 437-475):

```lua
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Calculate target ratio
    local curXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1
    local targetRatio = (maxXP > 0) and (curXP / maxXP) or 0

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
        -- ❌ REMOVE: return
        -- ✅ Continue to overlay/text updates
    end

    -- ANIMATION DECISION (use context flags)
    if context.shouldAnimate then
        -- Start animation
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
        local config = self:GetAnimationConfig()
        self:StartAnimation(targetRatio, xpContext, config)
    else
        -- Instant update - render all elements at final position
        self:RenderBarFrame(targetRatio, context)
    end
    
    -- ✅ ADD: Update overlays (matches Legacy/Vertical pattern)
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
    
    -- ✅ ADD: Update text (matches Legacy/Vertical pattern)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

#### Change 2: Fix OnLoad Method
Remove duplicate RenderBar call (lines 49-77):

```lua
function CircularBarStyleTemplate:OnLoad()
    -- Circular bar specific setup
    self.segments = {}
    self.segmentTypes = {}
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

    -- Call base OnLoad first (initializes animation system)
    if XPBarMixinBase_v2 and XPBarMixinBase_v2.OnLoad then
        XPBarMixinBase_v2.OnLoad(self)
    end
    
    -- ❌ REMOVE THIS BLOCK:
    -- Build initial context and render
    -- if XPBarContextBuilder then
    --     local context = XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD")
    --     if context and self.RenderBar then
    --         self:RenderBar(context)
    --     end
    -- end
end
```

## Testing Plan

### Manual Testing
1. `/reload` or logout/login
2. Verify bar shows correct fill level immediately
3. Verify rested overlay appears (if you have rested XP)
4. Verify text displays (XP, %, level, etc.)
5. Verify exhaustion tick shows (if you have rested XP)
6. Gain XP and verify animation works
7. Check for Lua errors: `/console scriptErrors 1`

### Test Cases
- [ ] Fresh login with no rested XP
- [ ] Fresh login with rested XP
- [ ] Fresh login with quest XP overlays enabled
- [ ] `/reload` with rested XP
- [ ] `/reload` at 0% XP
- [ ] `/reload` at 50% XP
- [ ] `/reload` at 99% XP
- [ ] Gain XP (kill mob) - verify animation
- [ ] Complete quest - verify animation
- [ ] Rest to gain rested XP
- [ ] Exhaust rested XP

## Related Files

- **Primary:** `ui/xpbars/circular_v2/CircularBarStyle.lua`
- **Reference:** `ui/xpbars/legacy_v2/LegacyBarStyle.lua` (working pattern)
- **Reference:** `ui/xpbars/vertical_v2/VerticalBarStyle.lua` (working pattern)
- **Base:** `ui/xpbars/BaseMixin.lua` (common OnLoad/event flow)
- **Context:** `ui/xpbars/ContextBuilder.lua` (context building)

## Documentation Files Created

1. **CIRCULAR_V2_ONLOAD_ISSUE.md** - Detailed technical analysis
2. **CIRCULAR_V2_ONLOAD_FIX.md** - Executive summary with fix
3. **V2_ONLOAD_WORKFLOW_COMPARISON.md** - Visual workflow diagrams
4. **CIRCULAR_V2_ONLOAD_QUICK_REF.md** - This quick reference (you are here)

## Why It Works After XP Events

Even though the fix is needed, the bar **does** work after XP events occur because:

1. Different events populate the cached data:
   - `UPDATE_EXHAUSTION` → calls `UpdateRestedOverlay()` → populates `cachedRestedXP`
   - `QUEST_LOG_UPDATE` → calls `UpdateQuestCompleteOverlay()` → populates `cachedCompleteQuestXP`
2. Once cached data is populated, `SetArcProgress()` has valid values to use
3. Subsequent `RenderBar` calls don't hit the early return (because `_currentRatio` exists)

**This is why the bug only affects initial load!**

## Key Takeaway

The circular bar uses a **cached overlay pattern** that requires overlay update methods to populate the cache. The early return prevents these methods from being called on first load, leaving the cache empty. The fix ensures overlay updates happen on every render, just like Legacy/Vertical styles.
