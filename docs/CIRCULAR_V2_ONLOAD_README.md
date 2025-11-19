# Circular  OnLoad Bug - Documentation Set

## TL;DR

**Bug:** Circular  XP bar appears empty on initial load until an XP event occurs.

**Cause:** Early return in `RenderBar` prevents overlay update methods from running, leaving cached overlay data at zero.

**Fix:** Remove the early return and add overlay/text updates after animation decision (matching Classic/Vertical pattern).

## Quick Start

1. **Need to fix it now?** → Read `CIRCULAR_ONLOAD_QUICK_REF.md`
2. **Want to understand first?** → Read `CIRCULAR_ONLOAD_FIX.md`
3. **Need visual diagrams?** → Read `CIRCULAR_ONLOAD_VISUAL.md`
4. **Want full analysis?** → Read `CIRCULAR_ONLOAD_ISSUE.md`

## Documentation Files

| File | Purpose | Size |
|------|---------|------|
| **CIRCULAR_ONLOAD_README.md** | This overview (start here) | Quick |
| **CIRCULAR_ONLOAD_QUICK_REF.md** | Quick reference with code fixes | Medium |
| **CIRCULAR_ONLOAD_FIX.md** | Executive summary and solution | Medium |
| **CIRCULAR_ONLOAD_VISUAL.md** | Visual diagrams and flowcharts | Medium |
| **CIRCULAR_ONLOAD_ISSUE.md** | Deep technical analysis | Long |
| **ONLOAD_WORKFLOW_COMPARISON.md** | Detailed workflow comparison | Long |
| **CIRCULAR_ONLOAD_INDEX.md** | Full documentation index | Medium |

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
Unlike Classic/Vertical, circular never populates the overlay cache on first load because the early return prevents `UpdateRestedOverlay()` and similar methods from running.

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
    
    -- ✅ ADD: Update overlays (like Classic/Vertical)
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

**Single file:** `ui/xpbars/circular/CircularBarStyle.lua`

**Two changes:**
1. Fix `RenderBar` method (lines ~437-475)
2. Fix `OnLoad` method (lines ~70-77) - remove duplicate call

## Impact

- **Risk:** Low (aligns with existing Classic/Vertical pattern)
- **Benefit:** Fixes critical UX bug
- **Breaking changes:** None (same behavior, just working correctly)
- **Performance:** Neutral/positive (removes duplicate call)

## Why This Matters

The circular bar is a popular style choice. Having it appear broken on load creates a poor user experience and makes the addon look buggy. This fix ensures all  styles work consistently and correctly from the moment they load.

## Related Documentation

###  Architecture
- `ARCHITECTURE_REFACTOR_PROPOSAL.md` - Overall  design
- `ARCHITECTURE.md` - Architecture overview
- `CIRCULAR_MIGRATION.md` - Circular  migration plan

### Other  Styles
- `CLASSIC_BAR_MIGRATION.md` - Classic bar (reference for working pattern)
- `VERTICAL_MIGRATION.md` - Vertical bar (reference for working pattern)

### Animation System
- `ANIMATION_COMPARISON.md` - Animation architecture
- `ANIMATION_STATUS.md` - Implementation status

## Questions?

1. **Why does it work after XP events?**  
   Other events (UPDATE_EXHAUSTION, QUEST_LOG_UPDATE) populate the cache through separate code paths.

2. **Why only circular is affected?**  
   Only circular uses the cached overlay pattern and has the early return.

3. **Can't we just populate cache in OnLoad?**  
   We could, but the proper fix is to follow the established pattern: update overlays in RenderBar every time.

4. **What about performance?**  
   Overlay updates are lightweight and already run on every XP event in Classic/Vertical. No performance concern.

## Next Steps

1. Read the quick reference: `CIRCULAR_ONLOAD_QUICK_REF.md`
2. Apply the code changes
3. Test thoroughly
4. Mark as resolved in `CIRCULAR_CHECKLIST.md`

---

**Documentation Created:** Based on analysis of  architecture initialization workflows

**Status:** Ready for implementation

**Priority:** High (critical UX bug)
