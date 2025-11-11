# V2 BaseMixin Event Workflow Diagram

This document provides a detailed workflow for all registered events in the V2 XPBar architecture, tracking function calls, their order, recursion patterns, and context immutability.

## Context Immutability Legend

- 🟢 **Immutable Context from Builder**: Context created by `XPBarContextBuilder` and frozen with `MakeImmutable()`
- 🟡 **Context Pass-Through**: Same immutable context passed down without modification
- 🔴 **No Context / Reconstructed**: Function called without context or builds fresh context internally
- ⚪ **Optional Context**: Context parameter is optional, may rebuild if not provided

---

## Event Registration Overview

### Common Events (Registered in `RegisterCommonEvents()`)
- `PLAYER_ENTERING_WORLD`
- `PLAYER_XP_UPDATE`
- `PLAYER_LEVEL_UP`
- `UPDATE_EXHAUSTION`
- `PLAYER_UPDATE_RESTING`
- `TIME_PLAYED_MSG`

### Quest Events (Registered in `RegisterQuestEvents()`)
- `QUEST_ACCEPTED`
- `QUEST_REMOVED`
- `QUEST_TURNED_IN`
- `QUEST_LOG_UPDATE`
- `UNIT_QUEST_LOG_CHANGED`
- `QUEST_WATCH_UPDATE`

---

## Workflow 1: PLAYER_ENTERING_WORLD

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUI)
    ↓
2. 🟢 XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUI)
    ├─ GetCoreState() → { currentXP, xpMax, level, restedXP, isResting, hasRestedXP, isFullyRested }
    ├─ ComputeXPGained(currentXP, xpMax) → xpGained, lastXP
    ├─ UpdateSessionWithGain(xpGained) → sessionStart, sessionXP, sessionDuration, xpPerHour
    ├─ GetQuestXP() → completeQuestXP, incompleteQuestXP
    ├─ BuildBaseContext(event, "PLAYER_XP_UPDATE", coreState, nil)
    ├─ ExtendContext(baseContext, { xpBefore, xpAfter, xpGained, questXP, sessionStats })
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerXPChanged(🟢 immutableContext)
    ├─ 4. UpdateCurrentXPBar(🟡 context)
    │   ├─ 5. UpdateBarLayout(🟡 context, barName) [LayoutMixin]
    │   │   └─ Calls AnimationManager.AnimateTo() if animations enabled
    │   │       ├─ Stores context in animation.contexts[]
    │   │       └─ May aggregate contexts on retargeting
    │   └─ 6. UpdateBarColors(🟡 context, barName) [PaintMixin]
    ├─ 7. UpdateRestedOverlay(🟡 context)
    │   ├─ 8. UpdateRestedOverlayLayout(🟡 context, overlayName) [LayoutMixin]
    │   └─ 9. UpdateRestedOverlayColor(overlayName) [PaintMixin] 🔴
    ├─ 10. UpdateQuestCompleteOverlay(🟡 context)
    │   ├─ 11. UpdateQuestCompleteOverlayLayout(🟡 context, overlayName) [LayoutMixin]
    │   └─ 12. UpdateQuestCompleteOverlayColor(overlayName) [PaintMixin] 🔴
    ├─ 13. UpdateQuestIncompleteOverlay(🟡 context)
    │   ├─ 14. UpdateQuestIncompleteOverlayLayout(🟡 context, overlayName) [LayoutMixin]
    │   └─ 15. UpdateQuestIncompleteOverlayColor(overlayName) [PaintMixin] 🔴
    ├─ 16. UpdateExhaustionTick(🟡 context)
    │   └─ 17. UpdateExhaustionTickLayout(🟡 context, tickName) [LayoutMixin]
    └─ 18. UpdateVisuals(🟡 context) [ORCHESTRATOR METHOD]
        ├─ 19. UpdateBars(🟡 context) [VisualsMixin]
        │   └─ Calls UpdateCurrentXPBar(🟡 context) [RECURSIVE CALL to step 4]
        ├─ 20. UpdateOverlays(🟡 context) [VisualsMixin]
        │   ├─ UpdateRestedOverlay(🟡 context) [RECURSIVE CALL to step 7]
        │   ├─ UpdateQuestCompleteOverlay(🟡 context) [RECURSIVE CALL to step 10]
        │   ├─ UpdateQuestIncompleteOverlay(🟡 context) [RECURSIVE CALL to step 13]
        │   └─ UpdateExhaustionTick(🟡 context) [RECURSIVE CALL to step 16]
        └─ 21. UpdateTexts(🟡 context) [TextMixin]
            ├─ 22. UpdateTextVisibility(🟡 context)
            ├─ 23. UpdateXPText(🟡 context)
            ├─ 24. UpdatePercentText(🟡 context)
            ├─ 25. UpdateLevelText(🟡 context)
            ├─ 26. UpdateRateText(🟡 context)
            ├─ 27. UpdateSessionText(🟡 context)
            └─ 28. UpdateQuestSummaryText(🟡 context)
```

### Recursion Analysis
- **RECURSIVE**: Steps 4-17 are called twice:
  1. First directly from `TriggerXPChanged()`
  2. Then again from `UpdateVisuals()` → `UpdateBars()` / `UpdateOverlays()`
- **REASON**: This is a design pattern where Trigger methods update specific elements, then UpdateVisuals() provides a final orchestrated pass

### Context Immutability Issues
- ❌ **Color update methods don't receive context**: Steps 9, 12, 15 (PaintMixin color methods) don't receive context
- ❌ **Animation system stores/aggregates contexts**: AnimationManager stores contexts in `animation.contexts[]` and may aggregate on retargeting
- ✅ **Main flow preserves immutability**: Core context flows through without modification

---

## Workflow 2: PLAYER_XP_UPDATE

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("PLAYER_XP_UPDATE", ...)
    ↓
2. 🟢 XPBarContextBuilder.BuildXPChangeContext("PLAYER_XP_UPDATE", ...)
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerXPChanged(🟢 immutableContext)
    └─ [IDENTICAL TO WORKFLOW 1 - Steps 4-28]
```

### Recursion Analysis
- **Same as Workflow 1**

### Context Immutability Issues
- **Same as Workflow 1**

---

## Workflow 3: PLAYER_LEVEL_UP

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("PLAYER_LEVEL_UP", newLevel)
    ↓
2. 🟢 XPBarContextBuilder.BuildLevelUpContext("PLAYER_LEVEL_UP", newLevel)
    ├─ GetCoreState()
    ├─ GetQuestXP()
    ├─ BuildBaseContext(event, "PLAYER_LEVEL_UP", coreState, nil)
    ├─ ExtendContext(baseContext, { oldLevel, newLevel, questXP, sessionStats })
    ├─ Resets tracking: _lastXP = currentXP, _lastMaxXP = xpMax
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerLevelUp(🟢 immutableContext)
    ├─ 4. UpdateCurrentXPBar(🟡 context)
    │   └─ [Same as Workflow 1, Steps 5-6]
    ├─ 5. UpdateRestedOverlay(🟡 context)
    │   └─ [Same as Workflow 1, Steps 8-9]
    └─ 6. UpdateVisuals(🟡 context)
        ├─ UpdateBars(🟡 context) [RECURSIVE to step 4]
        ├─ UpdateOverlays(🟡 context) [RECURSIVE to step 5]
        └─ UpdateTexts(🟡 context) [Steps 22-28]
```

### Animation Behavior on Level-Up
- **AnimationManager.AnimateTo() detects level-up**: Uses `AnimationUtils.DetectLevelUp(xpContext)`
- **Animation reset sequence**:
  1. Cancels current animation
  2. Instant update to ratio=0 (bar reset)
  3. Starts new animation from 0 to new XP ratio
  4. Triggers flash overlay if configured

### Important: Level-Up XP Gain
**Level-up DOES gain XP!** When a player levels up:
- The bar resets from previous level's max (e.g., 10,000 XP) to 0
- Any XP gained after level-up is shown (e.g., 0 → 350 XP at new level)
- Context should have `hasGainedXP = true` if `currentXP > 0` at new level
- This allows proper animation and flash on level-up with residual XP

Example: Player has 9,950/10,000 XP, kills a mob worth 500 XP
- PLAYER_LEVEL_UP fires (newLevel = 71)
- currentXP = 450 (the 50 remaining + 500 - 10,000 wraparound)
- hasGainedXP should be `true` (player gained 450 XP at new level)
- shouldFlash should be `true` (visual feedback for XP gain)

### Recursion Analysis
- **RECURSIVE**: `UpdateCurrentXPBar` and `UpdateRestedOverlay` called from both `TriggerLevelUp()` and `UpdateVisuals()`

### Context Immutability Issues
- **Same as Workflow 1**

---

## Workflow 4: UPDATE_EXHAUSTION / PLAYER_UPDATE_RESTING

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("UPDATE_EXHAUSTION" | "PLAYER_UPDATE_RESTING", ...)
    ↓
2. 🟢 XPBarContextBuilder.BuildRestedContext(event, ...)
    ├─ GetCoreState()
    ├─ GetQuestXP()
    ├─ BuildBaseContext(event, "RESTED_UPDATE", coreState, nil)
    ├─ ExtendContext(baseContext, { completeQuestXP, incompleteQuestXP })
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerRestedChanged(🟢 immutableContext)
    ├─ 4. UpdateRestedOverlay(🟡 context)
    │   └─ [Same as Workflow 1, Steps 8-9]
    ├─ 5. UpdateExhaustionTick(🟡 context)
    │   └─ [Same as Workflow 1, Step 17]
    └─ 6. UpdateVisuals(🟡 context)
        ├─ UpdateBars(🟡 context)
        ├─ UpdateOverlays(🟡 context) [RECURSIVE to steps 4-5]
        └─ UpdateTexts(🟡 context)
```

### Recursion Analysis
- **RECURSIVE**: `UpdateRestedOverlay` and `UpdateExhaustionTick` called from both `TriggerRestedChanged()` and `UpdateVisuals()` → `UpdateOverlays()`

### Context Immutability Issues
- **Same as Workflow 1**

---

## Workflow 5: Quest Events (QUEST_ACCEPTED, QUEST_REMOVED, QUEST_TURNED_IN, etc.)

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("QUEST_*", ...)
    ↓
2. 🟢 XPBarContextBuilder.BuildQuestContext(event, ...)
    ├─ GetCoreState()
    ├─ GetQuestXP()
    ├─ BuildBaseContext(event, "QUEST_UPDATE", coreState, nil)
    ├─ ExtendContext(baseContext, { completeQuestXP, incompleteQuestXP })
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerQuestChanged(🟢 immutableContext)
    ├─ 4. UpdateQuestCompleteOverlay(🟡 context)
    │   └─ [Same as Workflow 1, Steps 11-12]
    ├─ 5. UpdateQuestIncompleteOverlay(🟡 context)
    │   └─ [Same as Workflow 1, Steps 14-15]
    └─ 6. UpdateVisuals(🟡 context)
        ├─ UpdateBars(🟡 context)
        ├─ UpdateOverlays(🟡 context) [RECURSIVE to steps 4-5]
        └─ UpdateTexts(🟡 context)
```

### Recursion Analysis
- **RECURSIVE**: Quest overlay methods called from both `TriggerQuestChanged()` and `UpdateVisuals()` → `UpdateOverlays()`

### Context Immutability Issues
- **Same as Workflow 1**

---

## Workflow 6: TIME_PLAYED_MSG

### Event Flow
```
[WoW Event System]
    ↓
1. OnEvent("TIME_PLAYED_MSG", totalTime, levelTime)
    ↓
2. [NO CONTEXT BUILT - Data stored in Session service]
    └─ Session service stores totalTime and levelTime
    └─ ContextBuilder uses this indirectly in future XP calculations
```

### Notes
- This event does **NOT** trigger any visual updates
- Data is stored for use in session calculations
- Future `BuildXPChangeContext()` calls will use this data

---

## Workflow 7: Manual Refresh (Refresh() method)

### Event Flow
```
[User/System Call]
    ↓
1. Refresh()
    ↓
2. 🟢 XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")
    └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. TriggerXPChanged(🟢 immutableContext)
    └─ [IDENTICAL TO WORKFLOW 1]
```

---

## Workflow 8: Full Update (FullUpdate() method)

### Event Flow
```
[XPBar Controller Call]
    ↓
1. FullUpdate(⚪ context)
    ├─ Check re-entrancy guard (_isUpdating)
    └─ Set _isUpdating = true
    ↓
2. IF context provided:
       Use 🟢 immutableContext from caller
   ELSE:
       🟢 XPBarContextBuilder.BuildXPChangeContext("FULL_UPDATE")
       └─ MakeImmutable(context) → **IMMUTABLE CONTEXT CREATED** 🟢
    ↓
3. UpdateVisuals(🟡 context)
    └─ [See Workflow 1, Steps 19-28]
    ↓
4. UpdateTextVisibility(🟡 context)
    └─ [Step 22 from Workflow 1]
    ↓
5. Clear _isUpdating flag
```

### Re-entrancy Protection
- **Guard**: `_isUpdating` flag prevents recursive FullUpdate calls
- **Use Case**: Options panel changes trigger FullUpdate on multiple bars simultaneously

### Context Immutability Issues
- ✅ **Properly supports provided context**: Can receive pre-built context from broadcaster

---

## Workflow 9: Periodic Text Refresh (OnShow Ticker)

### Event Flow
```
[C_Timer.NewTicker every 2.5 seconds]
    ↓
1. IF bar:IsShown():
    ├─ 2. UpdateSessionText(🔴 nil)
    │   └─ Internally rebuilds fresh context from current game state
    │       └─ Session service computes fresh time values
    └─ 3. UpdateRateText(🔴 nil)
        └─ Internally rebuilds fresh context from current game state
            └─ Calculates XP/hour and time to level
```

### Context Immutability Issues
- ❌ **NO CONTEXT PROVIDED**: Ticker calls text methods with `nil` context
- ❌ **RECONSTRUCTION REQUIRED**: Each method must rebuild context from scratch
- **IMPACT**: Methods like `UpdateSessionText` and `UpdateRateText` must handle `nil` context gracefully

---

## Animation System Context Flow

### AnimationManager.AnimateTo() Detailed Flow
```
1. AnimateTo(bar, targetRatio, 🟢 xpContext, config)
    ├─ Store 🟢 incomingXpContext (CRITICAL: for flash decision)
    ├─ IF level-up detected:
    │   ├─ Cancel current animation
    │   ├─ Reset bar to 0 (instant update)
    │   ├─ Start new animation from 0 to new ratio
    │   └─ Use 🟢 xpContext for flash decision
    ├─ ELSE IF retargeting (animation in progress):
    │   ├─ Append 🟢 xpContext to animation.contexts[]
    │   ├─ Aggregate contexts: AnimationUtils.AggregateContexts(contexts[])
    │   │   └─ Creates NEW aggregated context (sum of xpGained, etc.)
    │   ├─ Calculate current visual position for smooth retargeting
    │   └─ Use 🟡 aggregatedContext for bar positioning
    │       └─ BUT use 🟢 incomingXpContext for flash decision
    ├─ ELSE (fresh animation):
    │   └─ Store 🟢 xpContext in animation.contexts[1]
    ├─ Calculate shouldAnimate
    └─ IF instant update:
        ├─ Build instantContext { currentRatio, targetRatio, progress=1.0, xpContext }
        └─ Call bar.ApplyAnimationStep(🟡 instantContext)
            ├─ AnimateBarPosition(🟡 stepContext)
            └─ AnimateBarEffect(🟡 stepContext)
```

### OnUpdate Frame Tick
```
[Every frame during animation]
    ↓
1. AnimationManager:OnUpdate(elapsed)
    └─ For each registered bar:
        ├─ Calculate progress (elapsed / duration)
        ├─ Apply easing: easedProgress = EaseOutQuad(progress)
        ├─ Calculate currentRatio (interpolated)
        ├─ Build flash data if flashing
        ├─ Build stepContext {
        │       currentRatio,
        │       targetRatio,
        │       startRatio,
        │       progress,
        │       timing data,
        │       🟢 xpContext (from animation.contexts),
        │       flashData,
        │       config
        │   }
        └─ Call bar:ApplyAnimationStep(🟡 stepContext)
            ├─ AnimateBarPosition(🟡 stepContext)
            │   └─ Style-specific implementation (StatusBar:SetValue, etc.)
            └─ AnimateBarEffect(🟡 stepContext)
                └─ Style-specific implementation (GainFlash alpha, etc.)
```

### Context Aggregation (AnimationUtils.AggregateContexts)
```
Function: AggregateContexts(contexts[])
    ├─ Sums xpGained across all contexts
    ├─ Uses most recent context for static values (level, xpMax, etc.)
    └─ Returns NEW context object (NOT immutable)
    
⚠️ IMMUTABILITY BROKEN: Aggregation creates mutable context
```

---

## Critical Issues for Animation Workflow Improvement

### Issue 1: Context Aggregation Breaks Immutability
**Problem**: `AnimationUtils.AggregateContexts()` creates a NEW context object that is NOT frozen
**Location**: AnimationManager.AnimateTo() during retargeting
**Impact**: Aggregated context can be modified downstream
**Fix Needed**: Wrap aggregated context with `ContextBuilder.MakeImmutable()`

### Issue 2: Color Methods Don't Receive Context
**Problem**: PaintMixin color methods receive only `overlayName`, no context
**Location**: 
- `UpdateRestedOverlayColor(overlayName)` (step 9)
- `UpdateQuestCompleteOverlayColor(overlayName)` (step 12)
- `UpdateQuestIncompleteOverlayColor(overlayName)` (step 15)

**Impact**: Cannot use context for dynamic coloring decisions
**Fix Needed**: Add context parameter to all color methods

### Issue 3: Periodic Text Refresh Has No Context
**Problem**: OnShow ticker calls `UpdateSessionText(nil)` and `UpdateRateText(nil)`
**Location**: OnShow ticker (every 2.5 seconds)
**Impact**: Forces methods to rebuild context, inconsistent with immutable context pattern
**Fix Needed**: Build context once in ticker, pass to both methods

### Issue 4: Animation System Stores Mutable Contexts
**Problem**: AnimationManager stores contexts in `animation.contexts[]` array
**Location**: AnimationManager.AnimateTo() stores incoming xpContext
**Impact**: Context array can be modified, immutability not guaranteed
**Fix Needed**: Deep-freeze contexts before storing in array

### Issue 5: Recursive Calls Create Redundancy
**Problem**: Trigger methods call Update methods, then UpdateVisuals calls same methods again
**Location**: All Trigger methods (TriggerXPChanged, TriggerLevelUp, etc.)
**Impact**: Visual updates happen twice per event (performance cost)
**Design Question**: Is this intentional for progressive updates?

---

## Recommendations for Animation Context Immutability

### 1. Freeze Aggregated Contexts
```lua
-- In AnimationManager.AnimateTo()
local aggregatedContext = AnimationUtils.AggregateContexts(anim.contexts)
aggregatedContext = XPBarContextBuilder.MakeImmutable(aggregatedContext)
```

### 2. Pass Context to Color Methods
```lua
-- Update signature
function PaintMixin:UpdateRestedOverlayColor(context, overlayName)
    local color = self:GetRestedColor(context) -- Use context for decisions
    -- ...
end
```

### 3. Build Context for Periodic Updates
```lua
-- In OnShow ticker
self._textRefreshTicker = C_Timer.NewTicker(2.5, function()
    if self and self:IsShown() then
        local context = XPBarContextBuilder.BuildXPChangeContext("TEXT_REFRESH")
        self:UpdateSessionText(context)
        self:UpdateRateText(context)
    end
end)
```

### 4. Deep-Freeze Animation Context Storage
```lua
-- In AnimationManager.AnimateTo()
table.insert(anim.contexts, XPBarContextBuilder.MakeImmutable(xpContext))
```

### 5. Remove Redundant Trigger Updates (Optional)
```lua
-- Option A: Keep Trigger calls, remove from UpdateVisuals
function BaseMixin:TriggerXPChanged(context)
    -- Update specific elements directly
    self:UpdateCurrentXPBar(context)
    self:UpdateRestedOverlay(context)
    -- ... other specific updates
    
    -- Final visual pass (don't re-update bars/overlays)
    self:UpdateTexts(context)
end

-- Option B: Keep current design (explicit redundancy for progressive updates)
-- Document reason: Trigger methods update data, UpdateVisuals() applies presentation
```

---

## Summary Table: Context Flow by Event

| Event | Context Builder | Immutable | Trigger Method | Visual Updates | Recursion | Issues |
|-------|----------------|-----------|----------------|----------------|-----------|---------|
| PLAYER_ENTERING_WORLD | BuildXPChangeContext | ✅ Yes | TriggerXPChanged | Full | Yes (redundant) | Color methods, aggregation |
| PLAYER_XP_UPDATE | BuildXPChangeContext | ✅ Yes | TriggerXPChanged | Full | Yes (redundant) | Color methods, aggregation |
| PLAYER_LEVEL_UP | BuildLevelUpContext | ✅ Yes | TriggerLevelUp | Partial | Yes (redundant) | Color methods, animation reset |
| UPDATE_EXHAUSTION | BuildRestedContext | ✅ Yes | TriggerRestedChanged | Partial | Yes (redundant) | Color methods |
| PLAYER_UPDATE_RESTING | BuildRestedContext | ✅ Yes | TriggerRestedChanged | Partial | Yes (redundant) | Color methods |
| QUEST_* | BuildQuestContext | ✅ Yes | TriggerQuestChanged | Partial | Yes (redundant) | Color methods |
| TIME_PLAYED_MSG | None | ❌ N/A | None | None | No | Data storage only |
| MANUAL_REFRESH | BuildXPChangeContext | ✅ Yes | TriggerXPChanged | Full | Yes (redundant) | Same as XP_UPDATE |
| FullUpdate() | BuildXPChangeContext or provided | ✅ Yes | UpdateVisuals directly | Full | No | Re-entrancy guard |
| OnShow Ticker | ❌ None | ❌ No | UpdateSessionText, UpdateRateText | Text only | No | **No context provided** |

---

## Complete Call Stack Example: PLAYER_XP_UPDATE Event

```
WoW Event System → "PLAYER_XP_UPDATE"
└─ 1. BaseMixin:OnEvent("PLAYER_XP_UPDATE")
    └─ 2. XPBarContextBuilder.BuildXPChangeContext("PLAYER_XP_UPDATE") → 🟢 IMMUTABLE CONTEXT
        └─ 3. BaseMixin:TriggerXPChanged(context)
            ├─ 4. BaseMixin:UpdateCurrentXPBar(context)
            │   ├─ 5. VisualsMixin:UpdateCurrentXPBar(context)
            │   │   ├─ 6. LayoutMixin:UpdateBarLayout(context, nil)
            │   │   │   └─ 7. AnimationManager:AnimateTo(bar, ratio, context, config)
            │   │   │       ├─ Store context in animation.contexts[]
            │   │   │       └─ Register bar for OnUpdate
            │   │   └─ 8. PaintMixin:UpdateBarColors(context, nil)
            ├─ 9. BaseMixin:UpdateRestedOverlay(context)
            │   ├─ 10. VisualsMixin:UpdateRestedOverlay(context)
            │   │   ├─ 11. LayoutMixin:UpdateRestedOverlayLayout(context, nil)
            │   │   └─ 12. PaintMixin:UpdateRestedOverlayColor(nil) ❌ NO CONTEXT
            ├─ 13. BaseMixin:UpdateQuestCompleteOverlay(context)
            │   └─ [Similar to steps 10-12]
            ├─ 14. BaseMixin:UpdateQuestIncompleteOverlay(context)
            │   └─ [Similar to steps 10-12]
            ├─ 15. BaseMixin:UpdateExhaustionTick(context)
            │   └─ 16. LayoutMixin:UpdateExhaustionTickLayout(context, nil)
            └─ 17. BaseMixin:UpdateVisuals(context)
                ├─ 18. VisualsMixin:UpdateBars(context)
                │   └─ 19. BaseMixin:UpdateCurrentXPBar(context) [RECURSIVE to step 4]
                ├─ 20. VisualsMixin:UpdateOverlays(context)
                │   ├─ 21. BaseMixin:UpdateRestedOverlay(context) [RECURSIVE to step 9]
                │   ├─ 22. BaseMixin:UpdateQuestCompleteOverlay(context) [RECURSIVE to step 13]
                │   ├─ 23. BaseMixin:UpdateQuestIncompleteOverlay(context) [RECURSIVE to step 14]
                │   └─ 24. BaseMixin:UpdateExhaustionTick(context) [RECURSIVE to step 15]
                └─ 25. TextMixin:UpdateTexts(context)
                    ├─ 26. TextMixin:UpdateTextVisibility(context)
                    ├─ 27. TextMixin:UpdateXPText(context)
                    ├─ 28. TextMixin:UpdatePercentText(context)
                    ├─ 29. TextMixin:UpdateLevelText(context)
                    ├─ 30. TextMixin:UpdateRateText(context)
                    ├─ 31. TextMixin:UpdateSessionText(context)
                    └─ 32. TextMixin:UpdateQuestSummaryText(context)

[Later, on frame update if animation active]
AnimationManager OnUpdate Ticker
└─ 33. AnimationManager:OnUpdate(elapsed)
    └─ For registered bar:
        ├─ 34. Build stepContext { currentRatio, progress, flashData, xpContext, ... }
        └─ 35. bar:ApplyAnimationStep(stepContext)
            ├─ 36. AnimationBase:AnimateBarPosition(stepContext)
            │   └─ 37. Style-specific implementation (e.g., StatusBar:SetValue)
            └─ 38. AnimationBase:AnimateBarEffect(stepContext)
                └─ 39. Style-specific implementation (e.g., GainFlash alpha)
```

**Total Function Calls**: 39+ per XP update event (more if multiple bars registered)
**Recursion Depth**: 2 levels (Trigger → Update, UpdateVisuals → Update)
**Context Mutations**: 2 potential points (aggregation, color methods without context)

---

## Conclusion

The V2 BaseMixin architecture successfully implements an immutable context pattern for most of the event workflow. However, there are critical areas where immutability is compromised:

1. **Animation context aggregation** creates mutable contexts
2. **Color methods** don't receive context at all
3. **Periodic text refresh** has no context
4. **Redundant recursive calls** update visuals twice per event

These issues should be addressed to ensure true immutability and improve animation reliability, especially during retargeting scenarios where context aggregation occurs.
