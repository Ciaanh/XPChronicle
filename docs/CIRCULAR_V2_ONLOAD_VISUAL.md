# Circular V2 OnLoad Issue - Visual Summary

## The Bug in One Picture

```
INITIALIZATION FLOW COMPARISON
═══════════════════════════════════════════════════════════════

LEGACY/VERTICAL V2 (✅ WORKS)          CIRCULAR V2 (❌ BROKEN)
─────────────────────────────          ─────────────────────────

OnLoad()                               OnLoad()
  │                                      │
  ├─> Base OnLoad()                      ├─> Initialize segments
  │     ├─> Init animation               │     (all empty/background)
  │     ├─> Register events              │
  │     └─> Refresh()                    ├─> Base OnLoad()
  │           │                          │     ├─> Init animation
  │           └─> RenderBar()            │     ├─> Register events
  │                 │                    │     └─> Refresh()
  │                 ├─> Position bar     │           │
  │                 ├─> Update overlays ✅│           └─> RenderBar()
  │                 └─> Update text ✅   │                 │
  │                                      │                 ├─> Check _currentRatio (nil)
  │                                      │                 ├─> RenderBarFrame()
  └─> ✅ BAR FULLY RENDERED              │                 │     ├─> SetArcProgress()
                                         │                 │     │     └─> Uses EMPTY cache! ❌
                                         │                 │     └─> UpdateTexts()
                                         │                 └─> return ❌ EARLY EXIT!
                                         │
                                         ├─> ❌ Duplicate RenderBar()
                                         │     (also hits early exit)
                                         │
                                         └─> ❌ BAR SHOWS EMPTY
                                               (overlays never updated)
```

## The Problem Chain

```
┌──────────────────────────────────────────────────────────────┐
│ 1. OnLoad creates segments with EMPTY_SEGMENT_COLOR          │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. RenderBar called with _currentRatio = nil                 │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Early return executed before overlay updates              │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. RenderBarFrame called with empty cached overlay data      │
│    - self.cachedRestedXP = 0                                 │
│    - self.cachedCompleteQuestXP = 0                          │
│    - self.cachedIncompleteQuestXP = 0                        │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. SetArcProgress uses empty cache values                    │
│    → All segments remain EMPTY_SEGMENT_COLOR                 │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ ❌ RESULT: Empty/background colored ring with no text        │
└──────────────────────────────────────────────────────────────┘
```

## The Fix Chain

```
┌──────────────────────────────────────────────────────────────┐
│ 1. OnLoad creates segments with EMPTY_SEGMENT_COLOR          │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. RenderBar called with _currentRatio = nil                 │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Initialize _currentRatio (NO EARLY RETURN!) ✅             │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Animation decision → RenderBarFrame()                      │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. Update overlays (BEFORE SetArcProgress) ✅                 │
│    - UpdateRestedOverlay() → populates cachedRestedXP        │
│    - UpdateQuestCompleteOverlay() → populates cache          │
│    - UpdateQuestIncompleteOverlay() → populates cache        │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. RenderBarFrame calls SetArcProgress with populated cache  │
│    → Segments colored correctly                              │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 7. Update text ✅                                             │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ ✅ RESULT: Fully rendered bar with correct colors and text   │
└──────────────────────────────────────────────────────────────┘
```

## Code Location Heatmap

```
CircularBarStyle.lua
═══════════════════════════════════════════════════════════════

Lines 49-77:  OnLoad()
              ├─> Initialize segments          ✅ OK
              ├─> CreateRingSegments()         ✅ OK
              ├─> Base OnLoad (calls Refresh)  ✅ OK
              └─> ❌ Duplicate RenderBar call  ← FIX: REMOVE THIS

Lines 437-475: RenderBar()
              ├─> Calculate targetRatio        ✅ OK
              ├─> if not _currentRatio:        
              │     └─> RenderBarFrame()       
              │         return ❌               ← FIX: REMOVE RETURN
              │
              ├─> Animation decision           ✅ OK (never reached on first load)
              └─> ❌ Missing overlay/text      ← FIX: ADD THESE
                  updates here

Lines 483-500: RenderBarFrame()
              ├─> SetArcProgress()             ⚠️  Uses cached data
              ├─> SetCurrentRatio()            ✅ OK
              └─> UpdateTexts()                ✅ OK (but overlays not updated)
```

## Execution Timeline

```
TIME: OnLoad
════════════════════════════════════════════════════════════════════════════

BROKEN (Current)                      FIXED (Proposed)
───────────────────────────────────── ─────────────────────────────────────

T0: OnLoad starts                     T0: OnLoad starts
  ├─ segments = {} (empty)              ├─ segments = {} (empty)
  └─ cachedRestedXP = 0                 └─ cachedRestedXP = 0

T1: Base OnLoad → Refresh             T1: Base OnLoad → Refresh
  └─> RenderBar (1st call)              └─> RenderBar

T2: RenderBar #1                      T2: RenderBar
  ├─ _currentRatio = nil                ├─ _currentRatio = nil
  ├─ SetCurrentRatio(0.5)               ├─ SetCurrentRatio(0.5)
  ├─ RenderBarFrame()                   ├─ RenderBarFrame()
  │   ├─ SetArcProgress()               │   ├─ SetArcProgress()
  │   │   └─ cachedRestedXP = 0 ❌      │   │   └─ cachedRestedXP = 0
  │   └─ UpdateTexts()                  │   └─ UpdateTexts()
  └─ return ❌ EXIT                     ├─ UpdateRestedOverlay() ✅
                                        │   └─ cachedRestedXP = 1500
T3: Custom OnLoad RenderBar (2nd)     ├─ UpdateQuestCompleteOverlay() ✅
  ├─ _currentRatio = 0.5 (exists)      ├─ UpdateTexts() ✅
  ├─ RenderBarFrame()                   └─ Continue...
  │   ├─ SetArcProgress()
  │   │   └─ cachedRestedXP = 0 ❌
  │   └─ UpdateTexts()
  └─ return ❌ EXIT

T4: OnLoad complete
  └─ Bar shows EMPTY ❌                T3: OnLoad complete
                                        └─ Bar shows CORRECT ✅

TIME: First PLAYER_XP_UPDATE
────────────────────────────────────────────────────────────────────────────

T5: UPDATE_EXHAUSTION event           (Not needed - already working)
  └─> UpdateRestedOverlay()
      └─ cachedRestedXP = 1500 ✅

T6: PLAYER_XP_UPDATE event
  └─> RenderBar
      ├─ _currentRatio exists
      ├─ Animation
      └─ SetArcProgress()
          └─ cachedRestedXP = 1500 ✅

T7: Bar shows CORRECT ✅
```

## Memory State During Bug

```
OBJECT STATE AT T4 (After OnLoad, Before XP Event)
═══════════════════════════════════════════════════════════════════════════

BROKEN                                   FIXED
────────────────────────────────────    ────────────────────────────────────

self.segments = {                       self.segments = {
  [1] = Texture {                         [1] = Texture {
    color = (0.1, 0.1, 0.1, 0.3) ❌         color = (0.0, 1.0, 1.0, 1.0) ✅
  },                                      },
  [2] = Texture {                         [2] = Texture {
    color = (0.1, 0.1, 0.1, 0.3) ❌         color = (0.0, 1.0, 1.0, 1.0) ✅
  },                                      },
  ...                                     ...
  [50] = Texture {                        [50] = Texture {
    color = (0.1, 0.1, 0.1, 0.3) ❌         color = (0.0, 1.0, 1.0, 1.0) ✅
  }                                       }
  [51] = Texture {                        [51] = Texture {
    color = (0.1, 0.1, 0.1, 0.3) ❌         color = (0.75, 0.75, 0.75, 0.3) ✅
  }                                       }
  ...                                     ... (rested overlay color)
}                                       }

self.cachedRestedXP = 0 ❌              self.cachedRestedXP = 1500 ✅
self.cachedCompleteQuestXP = 0 ❌       self.cachedCompleteQuestXP = 850 ✅
self._currentRatio = 0.5 ✅             self._currentRatio = 0.5 ✅

Text elements:                          Text elements:
  XPText = "" ❌                          XPText = "1500 / 3000 XP" ✅
  PercentText = "" ❌                     PercentText = "50%" ✅
  LevelText = "" ❌                       LevelText = "Level 60" ✅
  RateText = "" ❌                        RateText = "1500 XP/hr" ✅
```

## The "Why It Works Later" Mystery Solved

```
EVENT FLOW AFTER ONLOAD
═══════════════════════════════════════════════════════════════════════════

Even with the bug, these events eventually populate the cache:

1. UPDATE_EXHAUSTION
   └─> OnEvent("UPDATE_EXHAUSTION")
       └─> BuildRestedContext()
           └─> TriggerBarRefresh()
               └─> RenderBar()
                   ├─ _currentRatio exists (no early return)
                   └─> (but still missing overlay updates!)

   Separately, some code path calls:
   └─> UpdateRestedOverlay()
       └─ self.cachedRestedXP = 1500 ✅

2. QUEST_LOG_UPDATE
   └─> OnEvent("QUEST_LOG_UPDATE")
       └─> BuildQuestContext()
           └─> TriggerBarRefresh()
               └─> RenderBar()
                   └─> (same as above)

   Separately:
   └─> UpdateQuestCompleteOverlay()
       └─ self.cachedCompleteQuestXP = 850 ✅

3. PLAYER_XP_UPDATE (any XP gain)
   └─> RenderBar()
       ├─ _currentRatio exists (no early return)
       └─> SetArcProgress()
           └─ Now uses populated cache ✅

This is why the bar "fixes itself" after a few seconds - various events
populate the cache through side effects, not through the proper RenderBar
flow. It's working by accident, not by design!
```

## Summary: One Line to Fix

```lua
# Before (Broken)
if not self._currentRatio then
    self:SetCurrentRatio(targetRatio)
    self:RenderBarFrame(targetRatio, context)
    return  ← DELETE THIS LINE
end

# After (Fixed)
if not self._currentRatio then
    self:SetCurrentRatio(targetRatio)
    -- Continue to overlay updates below
end
```

**That's it!** Remove one `return` statement and add overlay/text update calls at the end of `RenderBar` (matching Legacy/Vertical pattern).
