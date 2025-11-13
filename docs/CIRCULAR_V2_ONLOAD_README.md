# Circular V2 OnLoad Bug - Documentation Set

## TL;DR

**Bug:** Circular V2 XP bar appears empty on initial load until an XP event occurs.

**Cause:** Early return in `RenderBar` prevents overlay update methods from running, leaving cached overlay data at zero.

**Fix:** Remove the early return and add overlay/text updates after animation decision (matching Legacy/Vertical pattern).

## Quick Start

1. **Need to fix it now?** → Read `CIRCULAR_V2_ONLOAD_QUICK_REF.md`
2. **Want to understand first?** → Read `CIRCULAR_V2_ONLOAD_FIX.md`
3. **Need visual diagrams?** → Read `CIRCULAR_V2_ONLOAD_VISUAL.md`
4. **Want full analysis?** → Read `CIRCULAR_V2_ONLOAD_ISSUE.md`

## Documentation Files

| File | Purpose | Size |
|------|---------|------|
| **CIRCULAR_V2_ONLOAD_README.md** | This overview (start here) | Quick |
| **CIRCULAR_V2_ONLOAD_QUICK_REF.md** | Quick reference with code fixes | Medium |
| **CIRCULAR_V2_ONLOAD_FIX.md** | Executive summary and solution | Medium |
| **CIRCULAR_V2_ONLOAD_VISUAL.md** | Visual diagrams and flowcharts | Medium |
| **CIRCULAR_V2_ONLOAD_ISSUE.md** | Deep technical analysis | Long |
| **V2_ONLOAD_WORKFLOW_COMPARISON.md** | Detailed workflow comparison | Long |
| **CIRCULAR_V2_ONLOAD_INDEX.md** | Full documentation index | Medium |

## The Problem

```
WHAT USERS SEE:
┌─────────────────────────────────────┐
│  Circular XP Bar on Login/Reload    │
├─────────────────────────────────────┤
│                                     │
│     ⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫               │
│   ⚫             ⚫              │
│  ⚫               ⚫             │
│ ⚫      ❌ Empty   ⚫            │
│  ⚫               ⚫             │
│   ⚫             ⚫              │
│     ⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫⚫               │
│                                     │
│         No Text                     │
│         No XP Value                 │
│                                     │
└─────────────────────────────────────┘

Bar remains empty until:
- Killing a mob (XP gain)
- Completing a quest
- Any player event
```

## The Root Cause

### Issue 1: Early Return
```lua
function CircularBarStyleTemplate:RenderBar(context)
    if not self._currentRatio then
        self:SetCurrentRatio(targetRatio)
        self:RenderBarFrame(targetRatio, context)
        return  -- ❌ STOPS HERE on first load!
    end
    
    -- These are never reached:
    -- UpdateRestedOverlay()
    -- UpdateQuestCompleteOverlay()
    -- UpdateTexts()
end
```

### Issue 2: Empty Cache
```lua
-- OnLoad initializes caches to zero
self.cachedRestedXP = 0
self.cachedCompleteQuestXP = 0

-- SetArcProgress uses these empty values
local restedXP = self.cachedRestedXP  -- 0!
-- Result: Empty segments
```

### Issue 3: No Initialization
Unlike Legacy/Vertical, circular never populates the overlay cache on first load because the early return prevents `UpdateRestedOverlay()` and similar methods from running.

## The Fix

**One-line summary:** Remove early return, add overlay/text updates.

**Code change:**
```lua
function CircularBarStyleTemplate:RenderBar(context)
    -- ... existing code ...
    
    if not self._currentRatio then
        self:SetCurrentRatio(targetRatio)
        -- ❌ DELETE: return
        -- ✅ Continue to updates below
    end

    -- Animation decision
    if context.shouldAnimate then
        self:StartAnimation(targetRatio, xpContext, config)
    else
        self:RenderBarFrame(targetRatio, context)
    end
    
    -- ✅ ADD: Update overlays (like Legacy/Vertical)
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
    
    -- ✅ ADD: Update text
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

## What Changes

| Before | After |
|--------|-------|
| Early return on first load | No early return |
| No overlay updates | Overlay updates always run |
| Text updates only in RenderBarFrame | Text updates in RenderBar too |
| Empty cache on first render | Populated cache on first render |
| Bar appears empty on load | Bar renders correctly on load |

## Testing Checklist

- [ ] `/reload` - bar displays immediately
- [ ] Login - bar displays immediately  
- [ ] Bar shows correct fill level (50% → half filled)
- [ ] Rested overlay visible (if you have rested XP)
- [ ] Text displays (XP value, %, level, rate)
- [ ] Exhaustion tick visible (if rested XP available)
- [ ] Gain XP - animation works
- [ ] No Lua errors (`/console scriptErrors 1`)

## Files to Modify

**Single file:** `ui/xpbars/circular_v2/CircularBarStyle.lua`

**Two changes:**
1. Fix `RenderBar` method (lines ~437-475)
2. Fix `OnLoad` method (lines ~70-77) - remove duplicate call

## Impact

- **Risk:** Low (aligns with existing Legacy/Vertical pattern)
- **Benefit:** Fixes critical UX bug
- **Breaking changes:** None (same behavior, just working correctly)
- **Performance:** Neutral/positive (removes duplicate call)

## Why This Matters

The circular bar is a popular style choice. Having it appear broken on load creates a poor user experience and makes the addon look buggy. This fix ensures all V2 styles work consistently and correctly from the moment they load.

## Related Documentation

### V2 Architecture
- `V2_ARCHITECTURE_REFACTOR_PROPOSAL.md` - Overall V2 design
- `ARCHITECTURE_V2.md` - Architecture overview
- `CIRCULAR_V2_MIGRATION.md` - Circular V2 migration plan

### Other V2 Styles
- `LEGACY_BAR_V2_MIGRATION.md` - Legacy bar (reference for working pattern)
- `VERTICAL_V2_MIGRATION.md` - Vertical bar (reference for working pattern)

### Animation System
- `V2_ANIMATION_COMPARISON.md` - Animation architecture
- `V2_ANIMATION_STATUS.md` - Implementation status

## Questions?

1. **Why does it work after XP events?**  
   Other events (UPDATE_EXHAUSTION, QUEST_LOG_UPDATE) populate the cache through separate code paths.

2. **Why only circular is affected?**  
   Only circular uses the cached overlay pattern and has the early return.

3. **Can't we just populate cache in OnLoad?**  
   We could, but the proper fix is to follow the established pattern: update overlays in RenderBar every time.

4. **What about performance?**  
   Overlay updates are lightweight and already run on every XP event in Legacy/Vertical. No performance concern.

## Next Steps

1. Read the quick reference: `CIRCULAR_V2_ONLOAD_QUICK_REF.md`
2. Apply the code changes
3. Test thoroughly
4. Mark as resolved in `CIRCULAR_V2_CHECKLIST.md`

---

**Documentation Created:** Based on analysis of v2 architecture initialization workflows

**Status:** Ready for implementation

**Priority:** High (critical UX bug)
