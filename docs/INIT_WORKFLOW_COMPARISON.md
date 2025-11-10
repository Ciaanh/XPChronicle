# FlatBar v2 vs CircularBar v2 Initialization Workflow Comparison

## FlatBar v2 Initialization Workflow

### Starting from `/xptest flat` command

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. COMMAND EXECUTION                                            │
│    /xptest flat                                                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. FACTORY FUNCTION CALL                                        │
│    XPBarEnhanced_CreateFlatBarFrame()                           │
│    • Called from test_v2.lua                                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. STYLEBUILDER FRAME CREATION                                  │
│    StyleBuilder:CreateFrameForStyle()                           │
│    • styleKey = "flat"                                          │
│    • templateName = "FlatBarTemplate_v2"                        │
│    • config = DefaultConfig                                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. XML TEMPLATE INSTANTIATION                                   │
│    CreateFrame("Frame", nil, UIParent, "FlatBarTemplate_v2")    │
│    • Creates frame with XML-defined children:                   │
│      - StatusBar (with StatusBarTexture)                        │
│      - RestedOverlay                                            │
│      - QuestOverlayComplete/Incomplete                          │
│      - GainFlash                                                │
│      - LevelText, PercentText, RateText                         │
│    • XML sets mixin="FlatBarXPBarMixin"                         │
│    • Mixin already applied by XML                               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. CONFIG STORAGE                                               │
│    frame.__xpbar_config = DefaultConfig                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. FRAME ONLOAD - BaseMixin:OnLoad()                            │
│    (No FlatBar override, uses BaseMixin directly)               │
│                                                                 │
│    A. Initialize animation system                               │
│       → InitializeAnimation()                                   │
│         • Sets up self.animation table                          │
│         • Initializes _currentRatio = nil                       │
│                                                                 │
│    B. Initialize position behavior                              │
│       → InitializePosition()                                    │
│         • Sets up draggable behavior                            │
│                                                                 │
│    C. Register common events                                    │
│       → RegisterCommonEvents()                                  │
│         • PLAYER_XP_UPDATE                                      │
│         • PLAYER_LEVEL_UP                                       │
│         • UPDATE_EXHAUSTION                                     │
│         • QUEST_LOG_UPDATE                                      │
│         • etc.                                                  │
│                                                                 │
│    D. Build visuals (if style provides)                         │
│       → BuildVisuals() - NOT IMPLEMENTED for FlatBar            │
│         (XML already created all visuals)                       │
│                                                                 │
│    E. Apply style config                                        │
│       → ApplyStyle(config.style) - if present                   │
│                                                                 │
│    F. Register as observer                                      │
│       → XPBar:RegisterObserver(self)                            │
│         • For broadcast color/option updates                    │
│                                                                 │
│    G. *** INITIAL REFRESH ***                                   │
│       → self:Refresh()                                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. REFRESH - BaseMixin:Refresh()                                │
│    A. Build context                                             │
│       → XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")│
│         • xpBefore = UnitXP("player")  (e.g., 12500)            │
│         • xpAfter = UnitXP("player")   (e.g., 12500)            │
│         • xpMax = UnitXPMax("player")  (e.g., 50000)            │
│         • xpGained = 0  ← NO GAIN (same before/after)           │
│         • restedXP = GetXPExhaustion() (e.g., 5000)             │
│         • hasRestedXP = true                                    │
│         • level = 70                                            │
│         • event = "MANUAL_REFRESH"                              │
│                                                                 │
│    B. Trigger XP changed                                        │
│       → self:TriggerXPChanged(context)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. TRIGGER XP CHANGED - BaseMixin:TriggerXPChanged()            │
│    Calls ALL update methods with same context:                  │
│                                                                 │
│    A. → UpdateCurrentXPBar(context)         ← PRIMARY BAR       │
│    B. → UpdateRestedOverlay(context)        ← RESTED OVERLAY    │
│    C. → UpdateQuestCompleteOverlay(context) ← QUEST OVERLAY     │
│    D. → UpdateQuestIncompleteOverlay(context)                   │
│    E. → UpdateExhaustionTick(context)       ← EXHAUSTION TICK   │
│    F. → UpdateVisuals(context)              ← TEXT/VISUALS      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. UPDATE CURRENT XP BAR - FlatBarStyleTemplate:UpdateCurrentXPBar()│
│                                                                 │
│    A. Calculate target ratio                                    │
│       targetRatio = currentXP / xpMax                           │
│       = 12500 / 50000 = 0.25 (25%)                              │
│                                                                 │
│    B. Initialize current ratio (first update only)              │
│       if not self._currentRatio or self._currentRatio == 0:    │
│         • Get current StatusBar value (usually 0 initially)     │
│         • SetCurrentRatio(currentValue) - typically 0           │
│       [This only runs ONCE on first call]                       │
│                                                                 │
│    C. Build xpContext for animation                             │
│       xpContext = {                                             │
│         xpBefore = 12500,                                       │
│         xpAfter = 12500,                                        │
│         xpMax = 50000,                                          │
│         xpGained = 0,  ← ZERO because refresh, not real gain   │
│         restedXP = 5000,                                        │
│         hasRestedXP = true,                                     │
│         level = 70                                              │
│       }                                                         │
│                                                                 │
│    D. Get animation config                                      │
│       config = { enableAnimations=true, flashOnGain=true }     │
│                                                                 │
│    E. *** START ANIMATION ***                                   │
│       → self:StartAnimation(targetRatio, xpContext, config)     │
│         (Delegates to AnimationManager)                         │
│                                                                 │
│    F. Update bar colors (non-animated)                          │
│       → self:UpdateBarColors(context)                           │
│         • Sets StatusBar color based on rested state            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. ANIMATION MANAGER - AnimationManager:StartAnimation()       │
│                                                                 │
│    A. Initialize animation state (if needed)                    │
│       if not bar.animation:                                     │
│         bar.animation = {                                       │
│           isAnimating = false,                                  │
│           isFlashing = false,                                   │
│           startRatio = 0,                                       │
│           targetRatio = 0,                                      │
│           contexts = {}                                         │
│         }                                                       │
│                                                                 │
│    B. Preserve incoming context for flash decision              │
│       incomingXpContext = xpContext  (xpGained=0)               │
│                                                                 │
│    C. Setup animation (fresh start, not retargeting)            │
│       anim.startRatio = bar:GetCurrentRatio() or 0  ← 0         │
│       anim.targetRatio = targetRatio = 0.25                     │
│       anim.contexts = {xpContext}                               │
│                                                                 │
│    D. Calculate delta for animation check                       │
│       delta = |targetRatio - startRatio| = |0.25 - 0| = 0.25   │
│                                                                 │
│    E. Check if should animate                                   │
│       → AnimationUtils.ShouldAnimate(delta=0.25, config)        │
│         • If delta < MIN_DELTA (0.001): shouldAnimate = false   │
│         • If animations disabled: shouldAnimate = false         │
│         • delta=0.25 > MIN_DELTA: shouldAnimate = TRUE ✓        │
│                                                                 │
│    F. ANIMATION PATH (delta > MIN_DELTA)                        │
│       • Calculate duration = f(delta) ≈ 0.5 seconds             │
│       • Check flash condition:                                  │
│         willFlash = config.flashOnGain AND xpGained > 0         │
│         = true AND 0 > 0 = FALSE (no flash on refresh)          │
│       • anim.isAnimating = true                                 │
│       • anim.startTime = now                                    │
│       • anim.duration = 0.5                                     │
│       • Register bar for OnUpdate ticks                         │
│       → self:Register(bar)                                      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 11. ANIMATION ONUPDATE - AnimationManager:OnUpdate()            │
│     Called every frame (≈60 FPS) while animating                │
│                                                                 │
│     Every frame:                                                │
│     A. Build step context                                       │
│        → AnimationUtils.BuildStepContext(bar, now, config, xpContext)│
│          • Calculate elapsed time                               │
│          • Calculate progress (0.0 to 1.0)                      │
│          • Apply easing (ease-out-quad)                         │
│          • Calculate currentRatio = lerp(start, target, easedProgress)│
│          • flashData = nil (no flash for xpGained=0)            │
│                                                                 │
│     B. Apply animation step to bar                              │
│        → bar:ApplyAnimationStep(stepContext)                    │
│          ├─→ bar:AnimateBarPosition(stepContext)                │
│          │    • StatusBar:SetValue(stepContext.currentRatio)    │
│          │    • Smoothly animates from 0 → 0.25 over 0.5s       │
│          └─→ bar:AnimateBarEffect(stepContext)                  │
│               • GainFlash:Hide() (no flash)                     │
│                                                                 │
│     C. Update tracked ratio                                     │
│        bar:SetCurrentRatio(stepContext.currentRatio)            │
│                                                                 │
│     When animation completes (progress = 1.0):                  │
│     • anim.isAnimating = false                                  │
│     • Unregister from OnUpdate                                  │
│     • Final visual state: StatusBar at 25% (0.25)               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 12. OVERLAY UPDATES (from step 8)                               │
│     UpdateRestedOverlay(), UpdateQuestOverlays(), etc.          │
│     • Positioning and sizing based on context values            │
│     • RestedOverlay positioned at currentXP                     │
│     • Width = restedXP converted to bar width                   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 13. TEXT UPDATES (from step 8)                                  │
│     UpdateVisuals() → UpdateTexts()                             │
│     • LevelText: "70"                                           │
│     • PercentText: "25.0%"                                      │
│     • RateText: "2.5h" (time to level)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 14. FRAME SHOW                                                  │
│     frame:Show()                                                │
│     • Frame becomes visible with animated bar fill              │
│     • StatusBar animates from 0% → 25% smoothly                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 15. FINAL STATE                                                 │
│     ✓ Frame visible and positioned                              │
│     ✓ StatusBar at 25% (animated fill)                          │
│     ✓ RestedOverlay visible after currentXP                     │
│     ✓ QuestOverlays positioned if quest XP available            │
│     ✓ Text labels showing level, %, rate                        │
│     ✓ Events registered for future XP updates                   │
│     ✓ Animation system ready for next XP gain                   │
└─────────────────────────────────────────────────────────────────┘
```

### Key Points for FlatBar v2:
- **Single OnLoad call**: BaseMixin:OnLoad() is called once
- **Single Refresh call**: BaseMixin:OnLoad() calls Refresh() once
- **XML provides visuals**: StatusBar and all overlays created by XML template
- **Animation system handles fill**: StatusBar value animated from 0 → targetRatio
- **No explicit visual initialization**: Relies on animation system to set initial state

---

## CircularBar v2 Initialization Workflow

### Starting from `/xptest circular` command

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. COMMAND EXECUTION                                            │
│    /xptest circular                                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. FACTORY FUNCTION CALL                                        │
│    XPBarEnhanced_CreateCircularBarFrame()                       │
│    • Called from test_v2.lua                                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. STYLEBUILDER FRAME CREATION                                  │
│    StyleBuilder:CreateFrameForStyle()                           │
│    • styleKey = "circular"                                      │
│    • templateName = "CircularBarTemplate_v2"                    │
│    • config = DefaultConfig                                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. XML TEMPLATE INSTANTIATION                                   │
│    CreateFrame("Frame", nil, UIParent, "CircularBarTemplate_v2")│
│    • Creates frame with XML-defined children:                   │
│      - Background texture                                       │
│      - Border texture                                           │
│      - GainFlash (circular glow)                                │
│      - LevelText, PercentText, RateText (centered)              │
│      - Portrait (character portrait)                            │
│    • XML sets mixin="CircularBarXPBarMixin"                     │
│    • Mixin already applied by XML                               │
│    ⚠️  NO SEGMENTS YET - must be created programmatically       │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. CONFIG STORAGE                                               │
│    frame.__xpbar_config = DefaultConfig                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. FRAME ONLOAD - CircularBarStyleTemplate:OnLoad()             │
│    ⚠️  CUSTOM OVERRIDE - Different order than FlatBar           │
│                                                                 │
│    A. *** Initialize circular-specific properties FIRST ***     │
│       self.orientation = "CIRCULAR"                             │
│       self._barStyle = "Circular"                               │
│       self.segments = {}  ← EMPTY array for 100 segments        │
│       self.segmentTypes = {}                                    │
│       self.lastProgress = 0                                     │
│       self.targetProgress = 0                                   │
│       self.isAnimating = false                                  │
│                                                                 │
│    B. *** Initialize cached overlay data ***                    │
│       self.cachedRestedXP = 0                                   │
│       self.cachedCompleteQuestXP = 0                            │
│       self.cachedIncompleteQuestXP = 0                          │
│       self.cachedHasRestedXP = false                            │
│                                                                 │
│    C. *** CREATE RING SEGMENTS (100 textures) ***               │
│       → self:CreateRingSegments()                               │
│         FOR i = 1 to 100:                                       │
│           • segment = self:CreateTexture()                      │
│           • segment:SetTexture("Interface\\Buttons\\WHITE8X8")  │
│           • segment:SetSize(4, 15) pixels                       │
│           • segment:SetVertexColor(0.1, 0.1, 0.1, 0.3)  ← gray │
│           • Position at angle around circle                     │
│           • Rotate to face outward                              │
│           • self.segments[i] = segment                          │
│           • self.segmentTypes[i] = SEGMENT_TYPE.EMPTY           │
│         All segments visible with empty/gray color              │
│                                                                 │
│    D. *** CALL BASE ONLOAD ***                                  │
│       → XPBarMixinBase_v2.OnLoad(self)                          │
│         (Now proceeds to BaseMixin:OnLoad)                      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. BASE ONLOAD - BaseMixin:OnLoad()                             │
│    (Same as FlatBar from here on)                               │
│                                                                 │
│    A. Initialize animation system                               │
│       → InitializeAnimation()                                   │
│         • Sets up self.animation table                          │
│         • Initializes _currentRatio = nil  ⚠️ KEY STATE         │
│                                                                 │
│    B. Initialize position behavior                              │
│       → InitializePosition()                                    │
│                                                                 │
│    C. Register common events                                    │
│       → RegisterCommonEvents()                                  │
│                                                                 │
│    D. Build visuals                                             │
│       → BuildVisuals() - NOT IMPLEMENTED                        │
│         (Segments already created in step 6C)                   │
│                                                                 │
│    E. Apply style config                                        │
│       → ApplyStyle(config.style)                                │
│                                                                 │
│    F. Register as observer                                      │
│       → XPBar:RegisterObserver(self)                            │
│                                                                 │
│    G. *** INITIAL REFRESH ***                                   │
│       → self:Refresh()                                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. REFRESH - BaseMixin:Refresh()                                │
│    (Identical to FlatBar)                                       │
│                                                                 │
│    A. Build context                                             │
│       → XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")│
│         • xpBefore = 12500                                      │
│         • xpAfter = 12500                                       │
│         • xpMax = 50000                                         │
│         • xpGained = 0  ← NO GAIN                               │
│         • restedXP = 5000                                       │
│         • hasRestedXP = true                                    │
│         • level = 70                                            │
│                                                                 │
│    B. Trigger XP changed                                        │
│       → self:TriggerXPChanged(context)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. TRIGGER XP CHANGED - BaseMixin:TriggerXPChanged()            │
│    Calls ALL update methods with same context:                  │
│                                                                 │
│    A. → UpdateCurrentXPBar(context)         ← PRIMARY RING      │
│    B. → UpdateRestedOverlay(context)        ← CACHE DATA        │
│    C. → UpdateQuestCompleteOverlay(context) ← CACHE DATA        │
│    D. → UpdateQuestIncompleteOverlay(context)                   │
│    E. → UpdateExhaustionTick(context)       ← NO-OP             │
│    F. → UpdateVisuals(context)              ← TEXT              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. UPDATE CURRENT XP BAR - CircularBarStyleTemplate:UpdateCurrentXPBar()│
│                                                                 │
│     A. Calculate target ratio                                   │
│        targetRatio = xpAfter / xpMax                            │
│        = 12500 / 50000 = 0.25 (25%)                             │
│                                                                 │
│     B. ⚠️  INITIALIZATION BLOCK (only if _currentRatio is nil)  │
│        if not self._currentRatio:  ← TRUE on first call         │
│          print("First initialization")                          │
│          • self:SetCurrentRatio(targetRatio) = 0.25             │
│          • hasRestedXP = true                                   │
│          • *** EXPLICIT VISUAL INITIALIZATION ***               │
│            → self:SetArcProgress(0.25, true)                    │
│              [See step 11 for details]                          │
│          • _currentRatio is NOW SET = 0.25  ⚠️                  │
│        [This block ONLY runs on first call]                     │
│                                                                 │
│     C. Build xpContext for animation                            │
│        xpContext = {                                            │
│          xpBefore = 12500,                                      │
│          xpAfter = 12500,                                       │
│          xpMax = 50000,                                         │
│          xpGained = 0,  ← ZERO                                  │
│          restedXP = 5000,                                       │
│          hasRestedXP = true,                                    │
│          level = 70                                             │
│        }                                                        │
│                                                                 │
│     D. Get animation config                                     │
│        config = { enableAnimations=true, flashOnGain=true }    │
│                                                                 │
│     E. *** START ANIMATION ***                                  │
│        → self:StartAnimation(targetRatio=0.25, xpContext, config)│
│          (Delegates to AnimationManager)                        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 11. SETARCPROGRESS - CircularBarStyleTemplate:SetArcProgress()  │
│     ⚠️  CALLED FROM INITIALIZATION BLOCK (step 10B)             │
│     SetArcProgress(progress=0.25, hasRestedXP=true)             │
│                                                                 │
│     A. Calculate segment counts                                 │
│        currentXPSegments = floor(0.25 * 100 + 0.5) = 25         │
│                                                                 │
│     B. Initialize all segment types to EMPTY                    │
│        FOR i = 1 to 100:                                        │
│          self.segmentTypes[i] = SEGMENT_TYPE.EMPTY              │
│                                                                 │
│     C. Set current XP segment types                             │
│        FOR i = 1 to 25:  ← First 25 segments                    │
│          self.segmentTypes[i] = SEGMENT_TYPE.CURRENT_XP         │
│                                                                 │
│     D. Calculate and set overlay segment types                  │
│        • Rested segments (if restedXP > 0)                      │
│        • Quest complete segments (if enabled and > 0)           │
│        • Quest incomplete segments (if enabled and > 0)         │
│        [Uses cachedRestedXP, cachedCompleteQuestXP, etc.]       │
│                                                                 │
│     E. *** APPLY COLORS TO ALL SEGMENTS ***                     │
│        → self:UpdateSegmentColors(hasRestedXP=true)             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 12. UPDATE SEGMENT COLORS                                       │
│     CircularBarStyleTemplate:UpdateSegmentColors(hasRestedXP=true)│
│                                                                 │
│     A. Get colors from XPBarColors                              │
│        colorNormal = blue (normal XP)                           │
│        colorXpBarRested = purple (rested XP bar)                │
│        colorRested = cyan (rested overlay)                      │
│        colorQuestComplete = orange                              │
│        colorQuestIncomplete = yellow                            │
│                                                                 │
│     B. Determine current XP bar color                           │
│        currentXPColor = hasRestedXP ? colorXpBarRested : colorNormal│
│        = colorXpBarRested (purple) ✓                            │
│                                                                 │
│     C. Get progress for coloring decision                       │
│        progress = self._currentRatio = 0.25  ⚠️ USES TRACKED RATIO│
│        filled = floor(0.25 * 100 + 0.5) = 25 segments           │
│                                                                 │
│     D. Color each segment (i = 1 to 100)                        │
│        FOR i = 1 to 100:                                        │
│          segment = self.segments[i]                             │
│          IF i <= filled (i <= 25):                              │
│            • Use currentXPColor (purple)                        │
│            • segment:SetVertexColor(purple.r, g, b, a)          │
│          ELSE (i > 25):                                         │
│            • Check segmentTypes[i]:                             │
│              - QUEST_COMPLETE → orange                          │
│              - QUEST_INCOMPLETE → yellow                        │
│              - RESTED → cyan                                    │
│              - EMPTY → gray (0.1, 0.1, 0.1, 0.3)                │
│            • segment:SetVertexColor(color.r, g, b, a)           │
│          segment:Show()                                         │
│                                                                 │
│     ✓ RESULT: First 25 segments are purple, rest are overlays/empty│
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 13. RETURN TO UpdateCurrentXPBar (step 10E)                     │
│     Now _currentRatio = 0.25 (SET in init block)                │
│     Segments are colored (first 25 purple)                      │
│     Continue to StartAnimation()...                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 14. ANIMATION MANAGER - AnimationManager:StartAnimation()       │
│                                                                 │
│     A. Initialize animation state (if needed)                   │
│        if not bar.animation: [already initialized]              │
│                                                                 │
│     B. Preserve incoming context                                │
│        incomingXpContext = xpContext (xpGained=0)               │
│                                                                 │
│     C. Setup animation                                          │
│        anim.startRatio = bar:GetCurrentRatio() = 0.25  ⚠️       │
│        anim.targetRatio = targetRatio = 0.25                    │
│        anim.contexts = {xpContext}                              │
│                                                                 │
│     D. Calculate delta                                          │
│        delta = |0.25 - 0.25| = 0  ⚠️ ZERO DELTA                │
│                                                                 │
│     E. Check if should animate                                  │
│        → AnimationUtils.ShouldAnimate(delta=0, config)          │
│          delta = 0 < MIN_DELTA (0.001)                          │
│          shouldAnimate = FALSE  ⚠️                              │
│                                                                 │
│     F. ⚠️  INSTANT UPDATE PATH (no animation)                   │
│        Build instant context:                                   │
│        instantContext = {                                       │
│          currentRatio = 0.25,  ← ALREADY AT TARGET              │
│          targetRatio = 0.25,                                    │
│          progress = 1.0,  ← COMPLETE                            │
│          flashData = nil,  ← NO FLASH (xpGained=0)              │
│          xpContext = xpContext                                  │
│        }                                                        │
│                                                                 │
│        • willFlash = false (xpGained=0)                         │
│        • *** APPLY INSTANT STEP ***                             │
│          → bar:ApplyAnimationStep(instantContext)               │
│        • Update tracked ratio (already 0.25)                    │
│        • RETURN immediately (no OnUpdate registration)          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 15. APPLY ANIMATION STEP - AnimationBase:ApplyAnimationStep()   │
│     Called with instantContext (delta=0 path)                   │
│                                                                 │
│     A. Animate bar position                                     │
│        → self:AnimateBarPosition(instantContext)                │
│          • currentRatio = 0.25 (no change)                      │
│          → SetArcProgress(0.25, hasRestedXP=true)               │
│            [Re-applies same coloring - no visual change]        │
│                                                                 │
│     B. Animate bar effect                                       │
│        → self:AnimateBarEffect(instantContext)                  │
│          • flashData = nil                                      │
│          • GainFlash:Hide()                                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 16. OVERLAY UPDATES (from step 9B-D)                            │
│     • UpdateRestedOverlay(context)                              │
│       → self.cachedRestedXP = 5000                              │
│       → self.cachedHasRestedXP = true                           │
│       (No visual update - just caches data)                     │
│                                                                 │
│     • UpdateQuestCompleteOverlay(context)                       │
│       → self.cachedCompleteQuestXP = context.completeQuestXP    │
│       (No visual update - just caches data)                     │
│                                                                 │
│     • UpdateQuestIncompleteOverlay(context)                     │
│       → self.cachedIncompleteQuestXP = context.incompleteQuestXP│
│       (No visual update - just caches data)                     │
│                                                                 │
│     ⚠️  Overlays are already rendered in SetArcProgress (step 11D)│
│         using cached data from previous context                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 17. TEXT UPDATES (from step 9F)                                 │
│     UpdateVisuals() → UpdateTexts()                             │
│     • UpdateLevelText: "70" (just number, not "Level 70")       │
│     • UpdatePercentText: "25.0%" (simple percent)               │
│     • UpdateRateText: "2.5h" (time to level only)               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 18. FRAME SHOW                                                  │
│     frame:Show()                                                │
│     • Frame becomes visible                                     │
│     • Ring with first 25 segments colored (purple)              │
│     • Remaining segments: overlays or empty gray                │
│     • Text labels visible                                       │
│     • NO animation played (delta=0, instant update)             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 19. FINAL STATE                                                 │
│     ✓ Frame visible and positioned                              │
│     ✓ Ring segments: first 25 colored (current XP)              │
│     ✓ Ring segments: 26-X colored (rested/quest overlays)       │
│     ✓ Ring segments: remaining empty (gray)                     │
│     ✓ Text labels showing level, %, rate                        │
│     ✓ Events registered for future XP updates                   │
│     ✓ Animation system ready for next XP gain                   │
└─────────────────────────────────────────────────────────────────┘
```

### Key Points for CircularBar v2:
- **Custom OnLoad**: CircularBar has OnLoad override that runs BEFORE BaseMixin
- **Explicit segment creation**: 100 texture segments created programmatically in OnLoad
- **Explicit visual initialization**: SetArcProgress() called in initialization block
- **Sets _currentRatio in init**: This causes delta=0 in animation system
- **Instant update path**: No animation played because startRatio = targetRatio
- **One-time initialization**: Init block only runs when _currentRatio is nil

---

## Critical Differences Summary

| Aspect | FlatBar v2 | CircularBar v2 |
|--------|-----------|----------------|
| **OnLoad override** | ❌ No (uses BaseMixin directly) | ✅ Yes (custom override) |
| **Visual elements** | Created by XML template | Created programmatically (100 segments) |
| **OnLoad order** | BaseMixin:OnLoad() → Refresh() | CreateSegments() → BaseMixin:OnLoad() → Refresh() |
| **Initialization timing** | Segments BEFORE base OnLoad | Segments BEFORE base OnLoad ✓ |
| **Visual init in UpdateCurrentXPBar** | ❌ No explicit init | ✅ Yes (SetArcProgress in init block) |
| **_currentRatio on first call** | 0 or nil | nil → set to targetRatio |
| **Animation delta on init** | 0.25 (animates) | 0 (instant) |
| **Animation played on init** | ✅ Yes (0 → 0.25 smooth) | ❌ No (instant 0.25 → 0.25) |
| **Overlay rendering** | Separate frame children | Integrated in SetArcProgress |
| **Color updates** | UpdateBarColors() after animation | UpdateSegmentColors() in SetArcProgress |

---

## THE PROBLEM

**CircularBar's initialization block (step 10B) sets `_currentRatio = targetRatio` BEFORE calling StartAnimation.**

This causes:
1. `startRatio = GetCurrentRatio() = 0.25`
2. `targetRatio = 0.25`
3. `delta = 0`
4. `shouldAnimate = false` (delta < MIN_DELTA)
5. Instant update path instead of animation
6. SetArcProgress is called from init block AND from ApplyAnimationStep
7. Visual state is already correct, but no animation feedback

**FlatBar doesn't have this issue because:**
- No explicit SetCurrentRatio in init
- startRatio = GetCurrentRatio() = 0 (StatusBar value)
- targetRatio = 0.25
- delta = 0.25 > MIN_DELTA
- Animation plays smoothly

---

## SOLUTION

**Option 1**: Don't set `_currentRatio` in initialization block - let animation system set it
**Option 2**: Set `_currentRatio = 0` initially, not targetRatio, to create delta
**Option 3**: Skip StartAnimation call during initialization (handle in init block only)

The fix should ensure visual elements are initialized (segments colored) but allow animation system to handle ratio tracking.
