# V2 Architecture OnLoad Workflow Comparison

This document visualizes the initialization workflow differences between Circular V2 and other V2 styles.

## Common Base Flow (All V2 Styles)

```
┌─────────────────────────────────────────────────────────────┐
│ Frame Created (XML or programmatic)                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ OnLoad() Event Fired                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Style-Specific OnLoad()                                     │
│ - Initialize style-specific data                           │
│ - Create visual elements (segments, textures, etc.)        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ XPBarMixinBase_v2.OnLoad(self)                             │
│ - Initialize animation system                              │
│ - Initialize position behavior                             │
│ - Register common events (PLAYER_XP_UPDATE, etc.)         │
│ - Register as observer for broadcast updates              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ self:Refresh()                                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH") │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ self:TriggerBarRefresh(context)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ self:RenderBar(context)                                     │
│ ⚠️  This is where styles diverge!                           │
└─────────────────────────────────────────────────────────────┘
```

## Legacy/Vertical V2 Flow (Working)

```
┌─────────────────────────────────────────────────────────────┐
│ LegacyBarStyleTemplate / VerticalBarStyleTemplate          │
│ ⚠️  NO custom OnLoad - relies on base flow only            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Base OnLoad() → Refresh() → RenderBar(context)             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
╔═════════════════════════════════════════════════════════════╗
║ RenderBar(context)                                          ║
╠═════════════════════════════════════════════════════════════╣
║ 1. Calculate targetRatio from context                      ║
║    targetRatio = currentXP / xpMax                          ║
║                                                             ║
║ 2. Animation Decision                                       ║
║    if context.shouldAnimate then                            ║
║       StartAnimation(targetRatio, xpContext, config)        ║
║    else                                                     ║
║       RenderBarFrame(targetRatio, context)                  ║
║                                                             ║
║ 3. ✅ Update Overlays (ALWAYS)                              ║
║    UpdateRestedOverlay(context)                             ║
║    UpdateQuestCompleteOverlay(context)                      ║
║    UpdateQuestIncompleteOverlay(context)                    ║
║    UpdateExhaustionTick(context)                            ║
║                                                             ║
║ 4. ✅ Update Text (ALWAYS)                                  ║
║    UpdateTexts(context)                                     ║
╚═════════════════════════════════════════════════════════════╝
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ RenderBarFrame(currentRatio, context)                       │
│ - StatusBar:SetValue(currentRatio)                          │
│ - SetCurrentRatio(currentRatio)                             │
│ - UpdateBarColors(context)                                  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ ✅ Bar fully rendered with:                                 │
│    - Correct fill level                                     │
│    - All overlays visible                                   │
│    - All text displayed                                     │
└─────────────────────────────────────────────────────────────┘
```

## Circular V2 Flow (Broken - Current State)

```
┌─────────────────────────────────────────────────────────────┐
│ CircularBarStyleTemplate                                    │
│ ⚠️  Has custom OnLoad with duplicate render call           │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
╔═════════════════════════════════════════════════════════════╗
║ CircularBarStyleTemplate:OnLoad()                          ║
╠═════════════════════════════════════════════════════════════╣
║ 1. Initialize circular-specific data                        ║
║    - self.segments = {}                                     ║
║    - self.cachedRestedXP = 0  (❌ Empty cache)              ║
║    - self.cachedCompleteQuestXP = 0                         ║
║                                                             ║
║ 2. CreateRingSegments()                                     ║
║    - Creates 100 segment textures                           ║
║    - All initialized with EMPTY_SEGMENT_COLOR               ║
║                                                             ║
║ 3. Call Base OnLoad                                         ║
║    XPBarMixinBase_v2.OnLoad(self)                          ║
║    └─> Refresh() → RenderBar(context)  [FIRST CALL]        ║
║                                                             ║
║ 4. ❌ Duplicate Manual RenderBar Call                       ║
║    context = BuildXPChangeContext("PLAYER_ENTERING_WORLD") ║
║    self:RenderBar(context)  [SECOND CALL]                  ║
╚═════════════════════════════════════════════════════════════╝
                      │
                      ▼
╔═════════════════════════════════════════════════════════════╗
║ RenderBar(context) - FIRST/SECOND CALL                     ║
╠═════════════════════════════════════════════════════════════╣
║ 1. Calculate targetRatio                                    ║
║    targetRatio = currentXP / xpMax                          ║
║                                                             ║
║ 2. ⚠️  Check _currentRatio (nil on first load)             ║
║    if not self._currentRatio then                          ║
║       SetCurrentRatio(targetRatio)                          ║
║       RenderBarFrame(targetRatio, context)                  ║
║       return  ❌ EARLY EXIT!                                ║
║                                                             ║
║ 3. ❌ Never Reached on First Load:                          ║
║    - Animation decision code                                ║
║    - UpdateRestedOverlay(context)                           ║
║    - UpdateQuestCompleteOverlay(context)                    ║
║    - UpdateQuestIncompleteOverlay(context)                  ║
║    - UpdateExhaustionTick(context)                          ║
║    - UpdateTexts(context)  [at RenderBar level]            ║
╚═════════════════════════════════════════════════════════════╝
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ RenderBarFrame(targetRatio, context)                        │
│ Called before early return                                  │
├─────────────────────────────────────────────────────────────┤
│ 1. SetArcProgress(targetRatio, hasRestedXP)                │
│    ❌ Uses EMPTY cached overlay data:                       │
│       - self.cachedRestedXP = 0                             │
│       - self.cachedCompleteQuestXP = 0                      │
│       - self.cachedIncompleteQuestXP = 0                    │
│    Result: All segments remain EMPTY_SEGMENT_COLOR          │
│                                                             │
│ 2. SetCurrentRatio(currentRatio)                            │
│                                                             │
│ 3. UpdateTexts(context) ⚠️  Called but may fail             │
│    Text methods may depend on overlays being updated first  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ ❌ Bar rendered INCOMPLETE:                                 │
│    - Segments show empty/background color                   │
│    - No rested overlay (cached data = 0)                    │
│    - No quest overlays (cached data = 0)                    │
│    - Text may be missing or incorrect                       │
└─────────────────────────────────────────────────────────────┘
```

## Circular V2 Flow After XP Event (Works)

```
┌─────────────────────────────────────────────────────────────┐
│ OnEvent("PLAYER_XP_UPDATE")                                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ BuildXPChangeContext("PLAYER_XP_UPDATE")                    │
│ → TriggerBarRefresh(context) → RenderBar(context)          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
╔═════════════════════════════════════════════════════════════╗
║ RenderBar(context) - Subsequent Call                       ║
╠═════════════════════════════════════════════════════════════╣
║ 1. Calculate targetRatio                                    ║
║                                                             ║
║ 2. Check _currentRatio                                      ║
║    if not self._currentRatio then  ← FALSE (exists now!)   ║
║    ✅ No early return!                                      ║
║                                                             ║
║ 3. Animation Decision                                       ║
║    if context.shouldAnimate then                            ║
║       StartAnimation(targetRatio, xpContext, config)        ║
║    else                                                     ║
║       RenderBarFrame(targetRatio, context)                  ║
║                                                             ║
║ 4. ❌ Still Missing! (Design Issue)                         ║
║    - UpdateRestedOverlay(context)                           ║
║    - UpdateQuestCompleteOverlay(context)                    ║
║    - UpdateExhaustionTick(context)                          ║
║    - UpdateTexts(context)                                   ║
╚═════════════════════════════════════════════════════════════╝
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ ⚠️  Wait, why does it work after XP events then?           │
│                                                             │
│ Because overlay caches GET UPDATED by different events:     │
│ - UPDATE_EXHAUSTION → UpdateRestedOverlay()                 │
│ - QUEST_LOG_UPDATE → UpdateQuestCompleteOverlay()           │
│                                                             │
│ These events populate the cached data that SetArcProgress   │
│ uses, so subsequent RenderBar calls have valid data!        │
└─────────────────────────────────────────────────────────────┘
```

## The Key Difference

### Working Styles (Legacy/Vertical)
```
RenderBar()
  ├─ Animation logic
  ├─ RenderBarFrame()  [position only]
  ├─ UpdateRestedOverlay()      ← Updates overlay data AND visuals
  ├─ UpdateQuestCompleteOverlay() ← Updates overlay data AND visuals
  ├─ UpdateExhaustionTick()     ← Updates tick position
  └─ UpdateTexts()              ← Updates all text elements
```

### Broken Circular
```
RenderBar()
  └─ if first load: RenderBarFrame() → return ❌
     [Overlay/text updates never reached]

RenderBarFrame()
  ├─ SetArcProgress()  ← Uses EMPTY cached overlay data
  └─ UpdateTexts()     ← May work but overlays not updated
```

### Fixed Circular (Proposed)
```
RenderBar()
  ├─ if first load: initialize _currentRatio (no return!)
  ├─ Animation logic
  ├─ RenderBarFrame()             ← position only
  ├─ UpdateRestedOverlay()        ← Updates cache AND visuals ✅
  ├─ UpdateQuestCompleteOverlay() ← Updates cache AND visuals ✅
  ├─ UpdateQuestIncompleteOverlay() ← Updates cache AND visuals ✅
  ├─ UpdateExhaustionTick()       ← Updates tick ✅
  └─ UpdateTexts()                ← Updates text ✅
```

## Cached Overlay Data Flow

The circular bar uses a caching pattern that requires overlay update methods to be called:

```
UpdateRestedOverlay(context)
  ├─ Calculate restedXP from context
  ├─ self.cachedRestedXP = restedXP  ← POPULATES CACHE
  └─ self.cachedHasRestedXP = (restedXP > 0)

SetArcProgress(progress, hasRestedXP)
  ├─ Use self.cachedRestedXP  ← READS FROM CACHE
  ├─ Use self.cachedCompleteQuestXP
  ├─ Use self.cachedIncompleteQuestXP
  └─ Calculate segment colors based on cached values

❌ Problem: If overlay update methods are never called,
   caches remain at initialized zero values!
```

## Summary

| Aspect | Legacy/Vertical | Circular (Current) | Circular (Fixed) |
|--------|-----------------|-------------------|------------------|
| Custom OnLoad | No | Yes (duplicate call) | Yes (no duplicate) |
| Early return | No | Yes (breaks flow) | No |
| Overlay updates | In RenderBar | Never on first load | In RenderBar |
| Text updates | In RenderBar | In RenderBarFrame | In RenderBar |
| First load | ✅ Works | ❌ Broken | ✅ Works |
| XP events | ✅ Works | ✅ Works (by luck) | ✅ Works |
| Pattern consistency | ✅ Standard | ❌ Non-standard | ✅ Standard |
