# XPBarEnhanced V1 Animation Architecture Documentation

## Overview

This document provides a detailed technical overview of the animation system used in the V1 architecture of XPBarEnhanced. It covers all four bar styles (Legacy, Flat, Vertical, and Circular), documenting the UI elements involved, event flows, and function workflows for each animation type.

**Document Version**: 1.0  
**Architecture Version**: V1 (pre-V2 migration)  
**Last Updated**: November 6, 2025

---

## Table of Contents

1. [Core Animation System](#core-animation-system)
2. [Legacy Bar Style Animations](#legacy-bar-style-animations)
3. [Flat Bar Style Animations](#flat-bar-style-animations)
4. [Vertical Bar Style Animations](#vertical-bar-style-animations)
5. [Circular Bar Style Animations](#circular-bar-style-animations)
6. [Common Animation Workflows](#common-animation-workflows)
7. [Animation Constants & Configuration](#animation-constants--configuration)

---

## Core Animation System

### Architecture Overview

The V1 animation system is built on a shared base mixin (`XPBarMixinBase`) that provides common animation functionality, with each bar style extending and overriding specific methods for style-specific effects.

### Global Animation Driver

**File**: `ui/xpbar/XPBarMixinBase.lua`

The animation system uses a centralized frame-driven approach:

```
Addon._AnimationDriver (Frame)
├── bars = {} (tracked bar instances)
├── AddBar(bar) - Register bar for animation updates
├── RemoveBar(bar) - Unregister bar
└── OnUpdate(elapsed) - Frame callback that updates all registered bars
```

**Purpose**: Prevents per-bar `OnUpdate` conflicts where other code might replace frame handlers, ensuring animations remain active.

### Animation State Container

Each bar maintains an `animation` state object:

```lua
{
    -- Bar fill animation
    isAnimating = false,          -- Whether bar is currently animating
    startRatio = 0,               -- Animation start value (0-1)
    targetRatio = 0,              -- Animation target value (0-1)
    startTime = 0,                -- GetTime() when animation started
    duration = 0,                 -- Animation duration in seconds
    pauseUntil = 0,               -- Timestamp for pause-on-hover
    
    -- Flash effect
    flashingXPGain = false,       -- Whether flash is active
    flashStartTime = 0,           -- Flash start timestamp
    flashDuration = 0,            -- Flash duration
    isRestedGain = false,         -- Whether this is a rested XP gain
    isLevelUpFlash = false,       -- Gold flash for level-up
    
    -- Context (immutable)
    context = nil,                -- XP change context object
    metadata = nil,               -- Legacy compatibility field
    
    -- Previous state
    previousXP = 0                -- Last known XP value
}
```

### Key UI Elements (Common)

All bar styles share these common elements:

1. **Container Frame** (`*XPBarContainerMixin`)
   - Parent frame that handles positioning and dragging
   - Contains the bar view and overlay frames
   - Manages visibility and position storage

2. **Bar Frame** (`*XPBarMixin`)
   - Main view that renders XP progress
   - Inherits from `XPBarMixinBase`
   - Registers events and handles animation

3. **Text Overlays**
   - `LevelText` - Current player level
   - `XPText` - Current/Max XP values
   - `PercentText` - Percentage completion
   - `RateText` - XP per hour
   - `SessionText` - Session statistics

4. **Flash Overlay** (`GainFlash`)
   - Additive blend mode texture
   - Flashes on XP gain or level-up
   - Color varies by gain type (normal/rested/level-up)

---

## Legacy Bar Style Animations

### Overview

**Files**: 
- `ui/xpbar/styles/LegacyXPBarMixin.lua`
- `ui/xpbar/styles/LegacyXPBar.xml`

The Legacy bar mimics Blizzard's original XP bar with atlas textures and smooth fill animations.

### UI Elements

**XML Structure**:
```xml
LegacyXPBarContainer
├── Bar (LegacyXPBarMixin)
│   ├── StatusBar (WoW StatusBar widget)
│   │   ├── Background (atlas: UI-HUD-ExperienceBar-Background)
│   │   ├── BarTexture (Interface\TargetingFrame\UI-StatusBar)
│   │   ├── ExhaustionLevelFillBar (Rested overlay)
│   │   ├── QuestOverlayComplete (Orange overlay)
│   │   ├── QuestOverlayIncomplete (Yellow overlay)
│   │   └── ExhaustionTick (Rested marker button)
│   ├── GainFlash (Flash overlay)
│   └── OverlayFrame
│       ├── LevelText
│       ├── XPText
│       └── PercentText
└── BelowBarTextContainer
    ├── RateText
    ├── SessionText
    └── QuestSummaryText
```

### Animation Types

#### 1. Smooth Bar Fill Animation

**Trigger Events**:
- `PLAYER_XP_UPDATE` (via XPBar controller)
- XP gains from quests, kills, etc.

**Workflow**:

```
1. Event: PLAYER_XP_UPDATE
   └─> XPBar:HandleXPUpdate()
       └─> Creates immutable context object
           └─> LegacyXPBarMixin:AnimateXPChange(context)

2. AnimateXPChange(context)
   ├─> Updates state.currentXP, state.maxXP
   ├─> Computes startRatio, targetRatio
   ├─> TriggerXPGainFlash(isRested) if gain > 0
   └─> AnimateToRatio(targetRatio, context)

3. AnimateToRatio(targetRatio, context)
   ├─> Checks ShouldAnimateChange() rules
   │   ├─> Delta too small (<0.1%)? → Instant
   │   ├─> User disabled animations? → Instant
   │   ├─> Inactive view? → Instant
   │   └─> Otherwise → Animate
   ├─> Calculates duration from delta
   ├─> Sets animation state
   └─> Registers with AnimationDriver

4. AnimationDriver OnUpdate Loop (60 FPS)
   └─> XPBarMixinBase:OnAnimationUpdate(elapsed)
       ├─> Calculates progress (elapsed / duration)
       ├─> Applies easing function
       ├─> Interpolates currentRatio
       └─> SetDisplayValue(currentRatio)
           └─> UpdateStatusBarValue(ratio)
               └─> StatusBar:SetValue(ratio)
```

**Duration Calculation**:
```lua
-- Linear scaling based on change magnitude
MIN_DURATION = 0.3 seconds
MAX_DURATION = 2.0 seconds
duration = MIN + (delta * (MAX - MIN))
duration = duration / speedMultiplier  -- User setting
duration = clamp(duration, 0.25, 2.0)
```

**Easing Function**:
```lua
-- Default: Ease Out Quad
function easeOut(t)
    return 1 - (1 - t)^2
end
```

#### 2. XP Gain Flash

**Trigger**: XP gain detected during `AnimateXPChange`

**Workflow**:

```
1. TriggerXPGainFlash(isRested)
   ├─> Sets flashingXPGain = true
   ├─> flashStartTime = GetTime()
   ├─> flashDuration = 0.5 seconds (2 * half period)
   ├─> isRestedGain = isRested
   └─> Registers with AnimationDriver

2. AnimationDriver calls UpdateFlashEffect(now, elapsed)
   ├─> Calculate elapsed time since start
   ├─> If < half period (0.25s):
   │   └─> Fade in: alpha = (elapsed / 0.25) * 0.5
   ├─> If >= half period:
   │   └─> Fade out: alpha = (1 - fadeProgress) * 0.5
   └─> SetFlashAlpha(alpha)

3. SetFlashAlpha(alpha)
   ├─> If isRestedGain:
   │   └─> Color = Rested color (cyan)
   ├─> Else:
   │   └─> Color = XP bar color (purple)
   ├─> GainFlash:SetColorTexture(r, g, b, alpha)
   └─> GainFlash:Show()

4. When elapsed >= flashDuration:
   ├─> flashingXPGain = false
   ├─> SetFlashAlpha(0)
   └─> GainFlash:Hide()
```

**Flash Parameters**:
- Half Period: 0.25 seconds
- Max Alpha: 0.5
- Total Duration: 0.5 seconds
- Blend Mode: ADD

#### 3. Level-Up Celebration

**Trigger**: `PLAYER_LEVEL_UP` event

**Workflow**:

```
1. Event: PLAYER_LEVEL_UP(newLevel)
   └─> OnLevelUp(newLevel)
       ├─> Updates state.level, state.maxLevel
       ├─> Cancels ongoing animations
       ├─> Hides flash overlay
       ├─> If celebration enabled:
       │   └─> PlayLevelUpCelebration(newLevel)
       └─> Else: FullUpdate()

2. PlayLevelUpCelebration(newLevel)
   ├─> speedMultiplier = db.celebrationSpeed
   │   ├─> "fast" → 0.7x
   │   ├─> "normal" → 1.0x
   │   └─> "slow" → 1.5x
   ├─> TriggerLevelUpFlash(speedMultiplier)
   │   ├─> flashingXPGain = true
   │   ├─> isLevelUpFlash = true
   │   ├─> flashDuration = 1.0 * speedMultiplier
   │   └─> Registers with AnimationDriver
   └─> Schedule FullUpdate after 1.0 * speedMultiplier

3. SetFlashAlpha(alpha) [during level-up flash]
   ├─> If isLevelUpFlash:
   │   └─> Color = Gold (1.0, 0.84, 0.0)
   └─> GainFlash:SetColorTexture(1.0, 0.84, 0.0, alpha)
```

#### 4. StatusBar Color Transitions

**No Animation**: Color changes are instant when rested state changes.

**Workflow**:
```
UpdateStatusBarColor()
├─> If isFullyRested:
│   └─> StatusBar:SetStatusBarColor(restedColor)
├─> Else if isRested:
│   └─> StatusBar:SetStatusBarColor(restedColor)
└─> Else:
    └─> StatusBar:SetStatusBarColor(normalColor)
```

---

## Flat Bar Style Animations

### Overview

**Files**: 
- `ui/xpbar/styles/FlatXPBarMixin.lua`
- `ui/xpbar/styles/FlatXPBar.xml`

The Flat bar uses solid colors and modern styling with the same animation system as Legacy.

### UI Elements

**XML Structure**:
```xml
FlatXPBarContainer
├── Bar (FlatXPBarMixin)
│   ├── Background (solid black, 0.5 alpha)
│   ├── StatusBar (WHITE8X8 texture)
│   │   ├── RestedOverlay (cyan, 0.54 alpha)
│   │   ├── QuestOverlayComplete (orange, 0.8 alpha)
│   │   └── QuestOverlayIncomplete (yellow, 0.85 alpha)
│   ├── GainFlash (additive blend)
│   └── OverlayFrame
│       ├── LevelText
│       ├── XPText
│       └── PercentText
└── BelowBarTextContainer
    ├── RateText
    ├── SessionText
    └── QuestSummaryText
```

### Animation Types

The Flat bar uses **identical animation workflows** to the Legacy bar:

1. **Smooth Bar Fill** - Same as Legacy
2. **XP Gain Flash** - Same as Legacy
3. **Level-Up Celebration** - Same as Legacy
4. **Color Transitions** - Instant (same as Legacy)

### Differences from Legacy

1. **Visual Style**: Uses `WHITE8X8` texture with `SetColorTexture()` instead of atlas textures
2. **Color Application**: Colors applied via `SetStatusBarColor()` and `SetVertexColor()`
3. **Overlay Positioning**: Overlays use pixel-based widths calculated from ratios

**Color Update**:
```lua
UpdateStatusBarColor()
├─> color = XPBarColors:GetUserColor(Color.XpBar)
└─> StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
```

---

## Vertical Bar Style Animations

### Overview

**Files**: 
- `ui/xpbar/styles/VerticalXPBarMixin.lua`
- `ui/xpbar/styles/VerticalXPBar.xml`

The Vertical bar features unique **gravity-based falling animations** where new XP "falls down" from the top of the bar.

### UI Elements

**XML Structure**:
```xml
VerticalXPBarContainer (60x300)
└── Bar (VerticalXPBarMixin)
    ├── Background (black, 0.5 alpha)
    ├── FilledTexture (current XP, bottom-up)
    ├── FallingTexture (animated new XP segment)
    ├── RestedOverlay (cyan overlay)
    ├── QuestOverlayComplete (orange)
    ├── QuestOverlayIncomplete (yellow)
    ├── particlePool[] (8 particles for impact)
    ├── LevelText (top)
    ├── PercentText (center)
    └── XPPerHourText (bottom)
```

**Texture Sublevels** (draw order):
```
VERTICAL_SUBLEVEL_FILL = 0        (FilledTexture - base XP)
VERTICAL_SUBLEVEL_REST = 1        (RestedOverlay)
VERTICAL_SUBLEVEL_QUEST = 3       (Quest overlays)
VERTICAL_SUBLEVEL_FALLING = 4     (FallingTexture - animated)
```

### Animation Types

#### 1. Falling XP Animation

**Trigger**: XP gain detected

**Workflow**:

```
1. UpdateBarFill(currentXP, maxXP)
   ├─> Calculates percentage = currentXP / maxXP
   ├─> If currentXP > lastXP AND not isFalling:
   │   └─> AnimateFallingXP(oldValue, newValue, maxValue)
   └─> Else: Direct update (instant)

2. AnimateFallingXP(oldValue, newValue, maxValue)
   ├─> Sets isFalling = true
   ├─> Calculates segment height:
   │   └─> segmentHeight = (gainedXP / maxValue) * barHeight
   ├─> Positions FallingTexture at top:
   │   ├─> SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
   │   └─> SetHeight(segmentHeight)
   ├─> Sets brighter color:
   │   └─> color * 1.3 (clamped to 1.0)
   ├─> Calculates target position:
   │   └─> targetY = -(barHeight - currentFillHeight - segmentHeight)
   └─> Starts per-frame animation:
       └─> SetScript("OnUpdate", fallAnimationHandler)

3. Fall Animation OnUpdate(frame, elapsed)
   ├─> elapsedTime = GetTime() - startTime
   ├─> progress = min(elapsedTime / FALL_DURATION, 1)
   ├─> easedProgress = EaseOut(progress)
   ├─> currentY = startY + (targetY - startY) * easedProgress
   ├─> FallingTexture:SetPoint("TOPLEFT", 0, currentY)
   └─> If progress >= 1:
       ├─> SetScript("OnUpdate", nil)
       └─> OnFallComplete(oldValue, newValue, maxValue)

4. OnFallComplete(oldValue, newValue, maxValue)
   ├─> FallingTexture:Hide()
   ├─> Updates FilledTexture to new height
   ├─> PlayImpactEffect()
   ├─> PlayBounceAnimation()
   └─> isFalling = false
```

**Constants**:
```lua
FALL_DURATION = 0.4 seconds
BOUNCE_HEIGHT = 5 pixels
BOUNCE_DURATION = 0.1 seconds
PARTICLE_COUNT = 8
```

**Easing**:
```lua
-- Quadratic ease-out (deceleration)
function EaseOut(progress)
    return 1 - (1 - progress) * (1 - progress)
end
```

#### 2. Impact Particle Effect

**Trigger**: Called when falling XP segment reaches target

**Workflow**:

```
1. PlayImpactEffect()
   ├─> Calculates impact point:
   │   └─> impactY = barHeight - fillHeight
   ├─> For each particle in particlePool (8 particles):
   │   ├─> Calculates direction:
   │   │   ├─> angle = 2π * (i / PARTICLE_COUNT)
   │   │   ├─> speed = 50 + random() * 30
   │   │   ├─> dx = cos(angle) * speed
   │   │   └─> dy = sin(angle) * speed
   │   ├─> Positions at impact point
   │   ├─> Sets XP bar color
   │   ├─> particle:Show()
   │   └─> Creates ticker for physics simulation:
   │       └─> C_Timer.NewTicker(0.016, particleUpdate)
   └─> particleUpdate (per particle):
       ├─> elapsed = GetTime() - startTime
       ├─> If elapsed > 0.5: Hide particle
       ├─> Calculate position:
       │   ├─> x = startX + dx * elapsed
       │   └─> y = startY + dy * elapsed - (200 * elapsed²)
       ├─> alpha = 1 - (elapsed / 0.5)
       └─> Updates particle position and alpha
```

**Physics**:
- Radial scatter pattern (360° distribution)
- Initial velocity: 50-80 pixels/second
- Gravity: 200 pixels/second² downward
- Fade duration: 0.5 seconds
- Update rate: ~60 FPS (0.016s interval)

#### 3. Bounce Animation

**Trigger**: Called when falling XP segment reaches target

**Workflow**:

```
1. PlayBounceAnimation()
   ├─> Stores original height
   ├─> Timer 1 (immediate):
   │   └─> SetHeight(originalHeight + BOUNCE_HEIGHT)
   └─> Timer 2 (after BOUNCE_DURATION):
       └─> SetHeight(originalHeight)

Timeline:
t=0s:    originalHeight
t=0s:    originalHeight + 5 (bounce up)
t=0.1s:  originalHeight (settle)
```

**Parameters**:
- Bounce Height: 5 pixels
- Bounce Duration: 0.1 seconds
- Timing: Immediate bounce, settle after duration

#### 4. Standard Animations

The Vertical bar also uses the common animation system for:
- **Bar fill animation** (when no fall animation needed)
- **XP Gain Flash** (same as Legacy/Flat)
- **Level-Up Celebration** (same as Legacy/Flat)

---

## Circular Bar Style Animations

### Overview

**Files**: 
- `ui/xpbar/styles/CircularXPBarMixin.lua`
- `ui/xpbar/styles/CircularXPBar.xml`

The Circular bar renders as a **segmented ring** that fills clockwise with smooth arc animations and glow effects.

### UI Elements

**XML Structure**:
```xml
CircularXPBarContainer (256x256)
└── Bar (CircularXPBarMixin)
    ├── BorderRing (PNG: assets/border.png)
    ├── CenterBG (PNG: assets/center.png)
    ├── GlowOverlay (PNG: assets/glow.png, hidden)
    ├── segments[] (60 textures)
    ├── restedSegments[] (60 textures)
    ├── questCompleteSegments[] (60 textures)
    ├── questIncompleteSegments[] (60 textures)
    ├── LevelText (center-top)
    ├── PercentText (center)
    └── RateText (center-bottom)
```

**Segment Parameters**:
```lua
RING_SEGMENTS = 60               -- Total segments
RING_RADIUS_PX = 97              -- Placement radius
SEGMENT_WIDTH_PX = 4             -- Segment width
SEGMENT_HEIGHT_PX = 15           -- Segment height
```

**Sublevels** (draw order):
```
RING_REST_SUBLEVEL = 1           (rested segments)
RING_QUEST_SUBLEVEL = 2          (quest segments - above rested)
```

### Animation Types

#### 1. Arc Fill Animation

**Trigger**: XP gain detected

**Workflow**:

```
1. UpdateBarFill(currentXP, maxXP)
   ├─> progress = currentXP / maxXP
   ├─> If progress > lastProgress AND not isAnimating:
   │   ├─> targetProgress = progress
   │   └─> AnimateArcFill()
   └─> Else: SetArcProgress(progress)

2. AnimateArcFill()
   ├─> Sets isAnimating = true
   ├─> Stores startProgress, targetProgress
   ├─> Stores startTime = GetTime()
   └─> SetScript("OnUpdate", arcAnimationHandler)

3. Arc Animation OnUpdate(frame, elapsed)
   ├─> elapsedTime = GetTime() - startTime
   ├─> animProgress = min(elapsedTime / ARC_SMOOTH_DURATION, 1)
   ├─> easedProgress = 1 - (1 - animProgress)²
   ├─> currentProgress = start + (target - start) * easedProgress
   ├─> SetArcProgress(currentProgress)
   └─> If animProgress >= 1:
       ├─> SetScript("OnUpdate", nil)
       ├─> lastProgress = targetProgress
       └─> isAnimating = false

4. SetArcProgress(progress)
   ├─> segmentsToShow = floor(progress * RING_SEGMENTS + 0.5)
   ├─> For i = 1 to RING_SEGMENTS:
   │   ├─> If i <= segmentsToShow:
   │   │   ├─> Apply color (normal or rested)
   │   │   └─> segment:Show()
   │   └─> Else:
   │       └─> segment:Hide()
   └─> Updates segment colors
```

**Duration**: 
- `ARC_SMOOTH_DURATION = 0.5 seconds`

**Easing**:
```lua
-- Ease-out quad
easedProgress = 1 - (1 - animProgress)²
```

#### 2. Segment Positioning

**Setup** (OnLoad):

```
CreateRingSegments()
└─> For i = 1 to RING_SEGMENTS:
    ├─> Creates segment texture
    └─> PositionSegments()

PositionSegments()
├─> For i = 1 to RING_SEGMENTS:
│   ├─> Calculates angle:
│   │   ├─> startAngle = π/2 (6 o'clock)
│   │   └─> angle = startAngle + (i-1)/60 * 2π
│   ├─> Calculates position:
│   │   ├─> xOff = cos(angle) * RING_RADIUS_PX
│   │   └─> yOff = sin(angle) * RING_RADIUS_PX * direction
│   ├─> Calculates rotation:
│   │   └─> rotation = (direction * angle) + startAngle
│   ├─> Sets segment position:
│   │   └─> SetPoint("CENTER", self, "CENTER", xOff, yOff)
│   └─> Rotates segment:
│       └─> texture:SetRotation(rotation)
└─> Applies to all segment types (XP, rested, quest)
```

**Coordinate System**:
- Origin: Frame center
- Start: 6 o'clock (bottom, angle = π/2)
- Direction: Clockwise (yOff inverted)
- Full circle: 2π radians (360°)

#### 3. Glow Pulse Effect

**Trigger**: XP gain with glow enabled (style-specific)

**Workflow**:

```
1. PlayGlowPulse()
   ├─> Cancels existing glow animation
   ├─> GlowOverlay:SetAlpha(0)
   ├─> GlowOverlay:Show()
   ├─> startTime = GetTime()
   ├─> _glowAnimating = true
   └─> SetScript("OnUpdate", glowAnimationHandler)

2. Glow Animation OnUpdate(frame, elapsed)
   ├─> elapsed = GetTime() - startTime
   ├─> Phase 1 - Fade In (0 to 0.2s):
   │   ├─> progress = elapsed / GLOW_FADE_IN_DURATION
   │   ├─> alpha = progress * GLOW_MAX_ALPHA
   │   └─> GlowOverlay:SetAlpha(alpha)
   ├─> Phase 2 - Hold (0.2s to 0.7s):
   │   └─> GlowOverlay:SetAlpha(GLOW_MAX_ALPHA)
   ├─> Phase 3 - Fade Out (0.7s to 1.0s):
   │   ├─> fadeProgress = (elapsed - fadeIn - hold) / fadeOut
   │   ├─> alpha = GLOW_MAX_ALPHA * (1 - fadeProgress)
   │   └─> GlowOverlay:SetAlpha(alpha)
   └─> Phase 4 - Complete (>1.0s):
       ├─> GlowOverlay:Hide()
       ├─> GlowOverlay:SetAlpha(0)
       ├─> _glowAnimating = false
       └─> SetScript("OnUpdate", nil)
```

**Glow Parameters**:
```lua
GLOW_FADE_IN_DURATION = 0.2 seconds
GLOW_HOLD_DURATION = 0.5 seconds
GLOW_FADE_OUT_DURATION = 0.3 seconds
GLOW_MAX_ALPHA = 0.6
Total Duration = 1.0 seconds
```

**Timeline**:
```
t=0.0s:  alpha=0.0  (start)
t=0.2s:  alpha=0.6  (hold begins)
t=0.7s:  alpha=0.6  (fade out begins)
t=1.0s:  alpha=0.0  (complete)
```

#### 4. Rested Arc Update

**Trigger**: XP or rested state changes

**Workflow**:

```
UpdateRestedArc(currentXP, maxXP)
├─> restedXP = GetXPExhaustion() or 0
├─> If restedXP > 0:
│   ├─> Calculates progress:
│   │   ├─> currentProgress = currentXP / maxXP
│   │   └─> restedProgress = min((currentXP + restedXP) / maxXP, 1)
│   ├─> Accounts for quest offset:
│   │   └─> questCompleteCount (from layout)
│   ├─> Calculates segment range:
│   │   ├─> currentSegment = floor(currentProgress * 60)
│   │   ├─> restedSegment = floor(restedProgress * 60)
│   │   ├─> restedStart = currentSegment + questCompleteCount
│   │   └─> restedEnd = restedSegment + questCompleteCount
│   ├─> Shows rested segments:
│   │   └─> For i = restedStart+1 to restedEnd:
│   │       ├─> Apply rested color
│   │       └─> segment:Show()
│   └─> Hides non-rested segments
└─> Else: Hide all rested segments
```

**Positioning Rules**:
- Rested starts **after** current XP fill
- Rested starts **after** quest complete overlays
- Rested extends to (current + quest + rested) position
- Uses ADD blend mode with 0.3 alpha

#### 5. Quest Arc Overlays

**Workflow**:

```
UpdateQuestArc(layout)
├─> Computes segment ranges:
│   └─> ComputeQuestSegmentRanges(layout)
│       ├─> currentSegment = floor(currentProgress * 60)
│       ├─> completeCount = max(1, floor(ratio * 60))
│       ├─> incompleteCount = max(1, floor(ratio * 60))
│       ├─> Builds completeIndices array
│       └─> Builds incompleteIndices array
├─> Hides all segments
├─> Shows complete segments:
│   └─> For each idx in completeIndices:
│       ├─> SetColorTexture(orange)
│       └─> Show()
└─> Shows incomplete segments:
    └─> For each idx in incompleteIndices:
        ├─> SetColorTexture(yellow)
        └─> Show()
```

**Rendering Order**:
1. Base XP segments (sublevel 0)
2. Rested segments (sublevel 1)
3. Quest segments (sublevel 2)
4. Falling/glow overlays (higher levels)

---

## Common Animation Workflows

### 1. XP Change Detection

**Central Handler** (shared by all styles):

```
XPBar Controller:
1. PLAYER_XP_UPDATE event
   └─> XPBar:HandleXPUpdate()

2. HandleXPUpdate()
   ├─> currentXP = UnitXP("player")
   ├─> maxXP = UnitXPMax("player")
   ├─> previousXP = Addon._lastKnownXP
   ├─> Creates immutable context:
   │   {
   │       xpBefore = previousXP,
   │       xpAfter = currentXP,
   │       xpMax = maxXP,
   │       xpGained = currentXP - previousXP,
   │       level = UnitLevel("player"),
   │       isRested = (GetXPExhaustion() or 0) > 0,
   │       isFullyRested = <calculated>,
   │       timestamp = GetTime()
   │   }
   ├─> Updates Addon._lastKnownXP = currentXP
   └─> Calls active view:
       └─> view:AnimateXPChange(context)
```

### 2. Animation Retargeting

When XP gain happens during active animation:

```
AnimateXPChange(context) while isAnimating:
├─> Detects self.animation.isAnimating == true
├─> Aggregates contexts:
│   {
│       xpBefore = old context.xpBefore,  -- Keep original start
│       xpAfter = new context.xpAfter,    -- New target
│       xpGained = newAfter - oldBefore,  -- Total gain
│       isLevelUp = old OR new,
│       source = "aggregated"
│   }
├─> Stores aggregated context
└─> AnimateToRatio(newTargetRatio, aggregatedContext)
    ├─> Calculates visual start from current animation progress
    ├─> Recalculates duration from new delta
    └─> Restarts animation from current position
```

**Result**: Smooth retargeting without jarring resets.

### 3. Animation Cleanup

**OnHide** (all styles):

```
OnHide()
├─> CleanupTimers()
│   ├─> Cancels _textInitTimer
│   ├─> Cancels _celebrationTimer
│   ├─> Cancels _animationTicker
│   ├─> Cancels _bounceUpTimer (Vertical)
│   ├─> Cancels _bounceDownTimer (Vertical)
│   └─> Cancels particle tickers (Vertical)
├─> SetScript("OnUpdate", nil)
│   └─> Stops per-frame animations
├─> UnsubscribeFromEvents()
│   └─> Unregisters all event handlers
└─> AnimationDriver:RemoveBar(self)
    └─> Unregisters from global driver
```

### 4. Pause on Hover

**Trigger**: `OnEnter` event

```
OnEnter()
└─> PauseAnimation()
    ├─> If pauseOnHover enabled:
    │   └─> animation.pauseUntil = GetTime() + 0.5
    └─> Animation driver checks pauseUntil before updating
```

**Resume**: Automatic when timestamp expires (no manual resume needed)

---

## Animation Constants & Configuration

### Global Constants

```lua
-- XPBarMixinBase.lua
ANIMATION_CONSTANTS = {
    -- Flash effect
    GAIN_FLASH_HALF_PERIOD_SECONDS = 0.25,
    GAIN_FLASH_MAX_ALPHA = 0.5,
    PAUSE_SECONDS = 0.5,
    
    -- Speed configuration
    DEFAULT_ANIMATION_SPEED = 1.0,
    
    -- Duration bounds
    MIN_ANIMATION_DURATION = 0.3,
    MAX_ANIMATION_DURATION = 2.0,
    ENFORCED_MIN_DURATION = 0.25,
    
    -- Thresholds
    ANIMATION_THRESHOLD = 0.001,    -- 0.1% minimum change
    INSTANT_THRESHOLD = 0.95,       -- Unused in current build
}
```

### Style-Specific Constants

**Vertical Bar**:
```lua
FALL_DURATION = 0.4
BOUNCE_HEIGHT = 5
BOUNCE_DURATION = 0.1
PARTICLE_COUNT = 8
```

**Circular Bar**:
```lua
RING_SEGMENTS = 60
ARC_SMOOTH_DURATION = 0.5

CIRCULAR_BAR_STYLE = {
    RING_RADIUS_PX = 97,
    SEGMENT_WIDTH_PX = 4,
    SEGMENT_HEIGHT_PX = 15,
    
    GLOW_FADE_IN_DURATION = 0.2,
    GLOW_FADE_OUT_DURATION = 0.3,
    GLOW_HOLD_DURATION = 0.5,
    GLOW_MAX_ALPHA = 0.6,
}
```

### User Configuration

**SavedVariables** (`Addon.db`):

```lua
{
    -- Animation settings
    enableAnimations = true,           -- Enable/disable all animations
    animationSpeed = 1.0,              -- Speed multiplier (0.5 = half, 2.0 = double)
    animationEasing = "easeOut",       -- Easing function (linear|easeOut|easeInOut)
    flashOnGain = true,                -- Enable XP gain flash
    pauseOnHover = true,               -- Pause animation on mouseover
    
    -- Level-up celebration
    levelUpCelebration = true,         -- Enable celebration
    celebrationSpeed = "normal",       -- Speed (fast|normal|slow)
}
```

### Animation Decision Tree

```
ShouldAnimateChange(currentRatio, newRatio, config):
├─> If !config.enabled → INSTANT (user disabled)
├─> If delta < 0.001 → INSTANT (too small)
├─> If not active view → INSTANT (prevent duplicate animations)
└─> Otherwise → ANIMATE
```

---

## Event Flow Diagrams

### XP Gain Event Flow

```
┌─────────────────┐
│  WoW API Event  │
│ PLAYER_XP_UPDATE│
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│  XPBar Controller   │
│ HandleXPUpdate()    │
│ Creates context     │
└────────┬────────────┘
         │
         ▼
┌──────────────────────┐
│  Active View Mixin   │
│ AnimateXPChange()    │
│ Checks retargeting   │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  XPBarMixinBase      │
│ AnimateToRatio()     │
│ Sets animation state │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  Animation Driver    │
│ OnUpdate (60 FPS)    │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  Style Rendering     │
│ SetDisplayValue()    │
│ Updates UI elements  │
└──────────────────────┘
```

### Level-Up Event Flow

```
┌─────────────────┐
│  WoW API Event  │
│ PLAYER_LEVEL_UP │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│  Bar Mixin          │
│ OnLevelUp(newLevel) │
│ Cancels animations  │
└────────┬────────────┘
         │
         ▼
┌──────────────────────┐
│ PlayLevelUpCelebration│
│ TriggerLevelUpFlash() │
└────────┬──────────────┘
         │
         ▼
┌──────────────────────┐
│  Animation Driver    │
│ OnUpdate (60 FPS)    │
│ Gold flash animation │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  Delayed Update      │
│ C_Timer.NewTimer()   │
│ FullUpdate() after 1s│
└──────────────────────┘
```

---

## Performance Considerations

### Frame-Driven Updates

- **60 FPS**: Assumes standard WoW frame rate
- **Single Driver**: One `OnUpdate` handler for all bars
- **Conditional Cleanup**: Driver auto-stops when no bars animating

### Memory Management

- **Timer Cleanup**: All timers canceled in `OnHide`
- **Event Unsubscription**: Events unregistered when hidden
- **Texture Pooling**: Circular bar reuses 60 segment textures
- **Particle Pooling**: Vertical bar reuses 8 particle textures

### Optimization Techniques

1. **Localized Math Functions**: Heavy math operations use local aliases
   ```lua
   local math_cos = math.cos
   local math_sin = math.sin
   ```

2. **Early Exit**: Inactive views skip animation updates

3. **Aggregation**: Rapid XP gains aggregated into single animation

4. **Clamping**: All animations clamped to prevent infinite loops

---

## Migration Notes (V1 → V2)

This V1 architecture has significant code duplication across styles:
- ~2,825 lines across 4 bar styles
- ~70% shared logic duplicated per style
- Event handling repeated in each mixin

The V2 architecture addresses this through:
- Composition-based mixins (reusable components)
- Shared animation system (no per-style duplication)
- ~83% code reduction per style
- Immutable context pattern (prevents bugs)

For V2 migration details, see `MIGRATION_PLAN.md`.

---

## Appendix: Function Reference

### XPBarMixinBase (Shared)

| Function | Purpose | Used By |
|----------|---------|---------|
| `InitializeAnimationState()` | Creates animation state object | All styles |
| `AnimateXPChange(context)` | Handles XP change events | All styles |
| `AnimateToRatio(ratio, metadata)` | Starts bar fill animation | All styles |
| `OnAnimationUpdate(elapsed)` | Frame-driven animation tick | Animation Driver |
| `TriggerXPGainFlash(isRested)` | Starts flash effect | All styles |
| `UpdateFlashEffect(now, elapsed)` | Updates flash alpha | All styles |
| `SetFlashAlpha(alpha)` | Sets flash texture alpha | Style-specific override |
| `ShouldAnimateChange()` | Decides instant vs animated | All styles |
| `CalculateAnimationDuration()` | Computes duration from delta | All styles |
| `ApplyEasing(t)` | Applies easing function | All styles |

### Legacy/Flat Specific

| Function | Purpose |
|----------|---------|
| `UpdateStatusBarValue(ratio)` | Sets StatusBar widget value |
| `UpdateStatusBarColor()` | Updates bar color |
| `UpdateVisuals()` | Refreshes visual state |

### Vertical Specific

| Function | Purpose |
|----------|---------|
| `AnimateFallingXP(old, new, max)` | Starts gravity animation |
| `OnFallComplete(old, new, max)` | Handles landing |
| `PlayImpactEffect()` | Creates particle scatter |
| `PlayBounceAnimation()` | Bounces bar on impact |
| `UpdateBarFill(currentXP, maxXP)` | Updates vertical fill |

### Circular Specific

| Function | Purpose |
|----------|---------|
| `CreateRingSegments()` | Creates 60 segment textures |
| `PositionSegments()` | Arranges segments in circle |
| `AnimateArcFill()` | Starts arc animation |
| `SetArcProgress(progress)` | Shows/hides segments |
| `UpdateRestedArc(xp, max)` | Updates rested segments |
| `UpdateQuestArc(layout)` | Updates quest segments |
| `PlayGlowPulse()` | Animates glow overlay |
| `RotateTexture(texture, rotation)` | Rotates segment |

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-06 | Initial comprehensive documentation |

---

**End of Documentation**
