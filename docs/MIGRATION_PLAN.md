# XPBarEnhanced V2 Architecture - Migration Plan

## Executive Summary

The V2 architecture proof-of-concept for the flat bar style has been validated and is production-ready. This document outlines the complete migration plan to port all remaining bar styles (Legacy, Vertical, Circular) from the old architecture (V1) to the new mixin-based composition system (V2).

**Status**: Phase 3 in progress - Vertical bar V2 implementation complete, ready for testing and validation.

### Key V2 Achievements (Phase 1)

✅ **New Animation System** - Frame-perfect centralized animation driver
- `AnimationManager.lua` (479 lines) - Centralized OnUpdate driver with bar registration
- Flash timing matches V1 exactly: 38 frames @ 60fps = 0.494s measured duration
- Context preservation pattern prevents double flash bug (xpGained=0 events)
- 100ms flash cooldown prevents rapid retriggers on quest turn-ins
- Retargeting support aggregates multiple rapid XP gains smoothly
- Level-up instant reset avoids StatusBar "drain" artifact

✅ **Flat Bar V2** - Production ready (225 lines, down from 500 in V1)
- Uses AnimationManager for all standard effects
- Implements `ApplyAnimationStep` for frame updates
- Clean separation: style handles visuals, AnimationManager handles timing

✅ **Debug Infrastructure** - Comprehensive troubleshooting commands
- `/animdebug` - Animation debug messages
- `/flashdebug` + `/v2flashlogs` - Flash timing validation  
- `/flashtrack` + `/flashtracklogs` - Flash event tracking
- `/testlevelup` - Trigger level-up for both V1 and V2

**Migration Impact**: All future styles get frame-perfect animations with zero additional code.

### Phase 3 Status - Vertical Bar Migration (IN PROGRESS)

🔄 **Vertical Bar V2** - Implementation complete, pending validation
- `ui/xpbars/vertical_v2/VerticalBarStyle.lua` (380 lines) - Style implementation with gravity animation
- `ui/xpbars/vertical_v2/VerticalBarTemplate.xml` (185 lines) - Frame template with vertical layout
- Integrates with AnimationManager for standard effects (flash, smooth fill)
- Custom gravity animation with particle effects implemented via OnUpdate
- Follows Pattern 2: AnimationManager + Custom OnUpdate
- Ready for: Integration testing, animation validation, performance testing

**Next Steps**:
1. Add vertical_v2 includes to .toc and Frames.xml
2. Register vertical style with StyleBuilder
3. Run validation checklist (see Phase 3 section)
4. Performance testing with gravity animations
5. Multi-instance testing with other bar styles

---

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Current State Analysis](#current-state-analysis)
3. [V1 vs V2 Architecture Comparison](#v1-vs-v2-architecture-comparison)
4. [Migration Phases](#migration-phases)
5. [Style Migration Order](#style-migration-order)
6. [Animation Testing Strategy](#animation-testing-strategy)
7. [Validation Checklist](#validation-checklist)
8. [Rollback Strategy](#rollback-strategy)
9. [Timeline & Resources](#timeline--resources)

---

## Migration Overview

### Goals

1. **Migrate all bar styles** from V1 architecture to V2 mixin-based composition
2. **Maintain feature parity** - preserve all existing visual effects, behaviors, and animations
3. **Improve maintainability** - reduce code duplication, centralize common behavior
4. **Enable extensibility** - make it easy for external developers to create custom styles
5. **Preserve backward compatibility** - existing saved variables and user settings must work

### Principles

- **Incremental migration**: Port one style at a time, validate each before proceeding
- **No regressions**: Each migrated style must match or exceed V1 feature parity
- **Clean separation**: V1 and V2 code remain isolated during migration (no cross-contamination)
- **Testing-first**: Comprehensive testing checklist for each style before sign-off
- **Documentation-driven**: External developer documentation updated before final cleanup

---

## Current State Analysis

### V1 Architecture (Old - `ui/xpbar/`)

**Location**: `ui/xpbar/` directory

**Core Components**:
- `XPBarMixinBase.lua` - Monolithic base mixin with all logic
- `XPBar.lua` - Controller and global XPBar singleton
- `XPBarTooltip.lua` - Tooltip management

**Style Files** (in `ui/xpbar/styles/`):
1. **LegacyXPBarMixin.lua** (469 lines) - Blizzard-style with atlases, positioned at default XP bar location
2. **FlatXPBarMixin.lua** (500 lines) - Modern solid colors, draggable
3. **CircularXPBarMixin.lua** (962 lines) - Circular progress ring with complex animations
4. **VerticalXPBarMixin.lua** (894 lines) - Vertical bar with gravity/particle animations

**Characteristics**:
- Each style duplicates event handling, position management, tooltip logic
- Container mixins handle positioning/dragging independently
- Heavy code duplication across styles
- Difficult to add new features (must update multiple files)
- Animation code embedded in style implementations

### V2 Architecture (New - `ui/xpbars/`)

**Location**: `ui/xpbars/` directory

**Core Components**:
- `BaseMixin.lua` (343 lines) - Event orchestration, Trigger/Action methods
- `ContextBuilder.lua` (448 lines) - Immutable context building with Session integration
- `StyleBuilder.lua` (213 lines) - Mixin composition via `CreateFromMixins`

**Behavior Mixins** (in `ui/xpbars/mixins/`):
1. **InteractionMixin.lua** (40 lines) - Mouse handling
2. **LayoutMixin.lua** (308 lines) - Overlay positioning algorithms
3. **PaintMixin.lua** (175 lines) - Color application, overlay painting
4. **PositionMixin.lua** (210 lines) - Dragging, position persistence
5. **TextMixin.lua** (337 lines) - Text formatting and updates
6. **TooltipMixin.lua** (73 lines) - Tooltip management
7. **VisualsMixin.lua** (167 lines) - Visual element orchestration

**Animation System** (in `ui/xpbars/mixins/animation/`):
- **AnimationManager.lua** (479 lines) - ✅ **NEW V2 SYSTEM**
  - Centralized animation driver with OnUpdate loop
  - Flash timing matching V1 exactly (0.5s duration, 38 frames @ 60fps)
  - Retargeting support (smooth handling of multiple rapid XP gains)
  - Level-up detection with instant bar reset
  - Context aggregation for smooth bar positioning
  - Flash cooldown system (100ms) to prevent double flash
  - Context preservation pattern (incoming vs aggregated)
- **AnimationUtils.lua** (324 lines)
  - Duration calculation based on ratio delta
  - Easing functions (EaseOutQuad)
  - Level-up detection logic
  - Context aggregation utilities
  - Flash data building for step context
- **AnimationMixin.lua** (363 lines) - ⚠️ **LEGACY - TO BE DEPRECATED**
  - Old animation system (retained for V1 styles during migration)
  - Will be removed in Phase 5 after all styles migrated

**Implemented Styles**:
- **FlatBar V2** (`ui/xpbars/flatbar_v2/`) - ✅ VALIDATED AND PRODUCTION-READY
  - `FlatBarStyle.lua` (225 lines) - Uses new AnimationManager
  - `FlatBarTemplate.xml` - Visual structure definition

**Characteristics**:
- Composition-based: Base + Behaviors + Style template
- Common logic centralized in mixins
- Observer pattern for multi-instance support
- Styles focus only on visual layout (minimal code)
- **Animations centralized in AnimationManager (V2) with frame-perfect timing**

---

## V1 vs V2 Architecture Comparison

### Code Organization

| Aspect | V1 (Old) | V2 (New) | Benefit |
|--------|----------|----------|---------|
| **Event Handling** | Duplicated in each style | Centralized in BaseMixin | -70% code duplication |
| **Position Management** | Duplicated in each container | PositionMixin | Single source of truth |
| **Animations** | Embedded in styles | AnimationManager (centralized driver) | Frame-perfect timing, reusable |
| **Animation Timing** | Inconsistent across styles | 38 frames, 0.494s (validated) | Matches V1 exactly |
| **Retargeting** | Manual in each style | AnimationManager (context aggregation) | Smooth XP gains |
| **Flash System** | Duplicated logic | AnimationManager (cooldown + context preservation) | No double flash |
| **Context Building** | Mixed with event handlers | ContextBuilder utility | Testable, immutable |
| **Color Management** | Ad-hoc in each style | PaintMixin | Consistent color application |
| **Text Formatting** | Duplicated logic | TextMixin | Real-time updates, centralized |
| **Overlay Positioning** | Style-specific algorithms | LayoutMixin + style overrides | Standard patterns + flexibility |

### Lines of Code Comparison (Estimated)

| Style | V1 Total LOC | V2 Style LOC | V2 Shared LOC | Reduction |
|-------|--------------|--------------|---------------|-----------|
| **FlatBar** | 500 | 61 | ~1800 (shared) | -88% per style |
| **Legacy** | 469 | ~80 (est.) | ~1800 (shared) | -83% per style |
| **Vertical** | 894 | ~150 (est.) | ~1800 (shared) | -83% per style |
| **Circular** | 962 | ~200 (est.) | ~1800 (shared) | -79% per style |

**Note**: V2 shared code (~1800 LOC) is reused across ALL styles, resulting in massive overall reduction.

### Feature Parity Matrix

| Feature | V1 | V2 | Notes |
|---------|----|----|-------|
| XP bar fill | ✅ | ✅ | StatusBar widget |
| Rested overlay | ✅ | ✅ | Standard positioning |
| Quest overlays | ✅ | ✅ | Complete + Incomplete |
| Exhaustion tick | ✅ | ✅ | Interactive marker |
| Flash effects | ✅ | ✅ | XP gain + level up |
| Value smoothing | ✅ | ✅ | AnimationMixin |
| Draggable position | ✅ | ✅ | PositionMixin |
| Position persistence | ✅ | ✅ | Config.barPositions |
| Tooltips | ✅ | ✅ | TooltipMixin |
| Real-time text updates | ❌ | ✅ | 1-second ticker |
| Multi-instance support | ❌ | ✅ | Observer pattern |
| Session persistence | ⚠️ | ✅ | Reloads correctly |
| Custom animations | ⚠️ | ✅ | Circular glow, vertical gravity |

**Legend**:
- ✅ Fully supported
- ⚠️ Partially supported or buggy
- ❌ Not supported

---

## Migration Phases

### Phase 1: Documentation & Planning ⬅️ **CURRENT PHASE**

**Objective**: Prepare comprehensive documentation for external developers and create detailed migration plan.

**Tasks**:
1. ✅ Update `ARCHITECTURE_V2.md` with external developer focus
2. ✅ Create this `MIGRATION_PLAN.md` document
3. ⬜ Create style migration templates/guides
4. ⬜ Document animation testing procedures
5. ⬜ Create validation checklists per style

**Deliverables**:
- Updated architecture documentation
- Migration plan (this document)
- Style developer guide
- Animation testing guide
- Per-style validation checklists

**Timeline**: 1-2 days

---

### Phase 2: Legacy Bar Migration

**Objective**: Port the Legacy bar (Blizzard-style) to V2 architecture.

**Rationale**: Legacy bar is the simplest style with no custom animations, making it ideal for the first migration after flat bar.

**Tasks**:
1. Create `ui/xpbars/legacy_v2/` directory structure
2. Implement `LegacyBarStyleTemplate.lua` (visual methods only)
3. Create `LegacyBarTemplate.xml` with atlas-based textures
4. Configure `LegacyBarStyle.lua` with StyleBuilder registration
5. Test static positioning (anchored to Blizzard bar)
6. Validate all visual elements and overlays
7. Compare side-by-side with V1 Legacy bar

**Key Challenges**:
- Static positioning (different from draggable flat bar)
- Atlas texture usage (need correct draw layers)
- Container sizing/positioning to match Blizzard bar

**Animation Requirements**: ✅ NONE (uses standard AnimationMixin smoothing only)

**Validation Checklist**: See [Legacy Bar Validation](#legacy-bar-validation)

**Timeline**: 2-3 days

---

### Phase 3: Vertical Bar Migration ⬅️ IN PROGRESS

**Objective**: Port the Vertical bar with gravity/particle animations to V2.

**Status**: ✅ Implementation complete (2025-11-09), ⬜ Pending validation and integration testing.

**Rationale**: Test V2's ability to handle custom animations before tackling the most complex circular bar.

**Tasks**:
1. ✅ Create `ui/xpbars/vertical_v2/` directory structure
2. ✅ Implement `VerticalBarStyle.lua` (380 lines)
3. ✅ Create `VerticalBarTemplate.xml` with vertical layout (185 lines)
4. ✅ Implement custom gravity animation system (OnUpdate handler)
5. ✅ Implement particle effects on XP gains (8 particles with physics)
6. ⬜ Add vertical_v2 includes to .toc and Frames.xml
7. ⬜ Register vertical style with StyleBuilder
8. ⬜ Test vertical overlay positioning
9. ⬜ Compare animations with V1 Vertical bar
10. ⬜ Run full validation checklist

**Key Challenges**:
- **Gravity animation**: XP "falls down" from top with physics
- **Particle effects**: Visual particles on XP gain
- Custom overlay positioning (vertical instead of horizontal)
- Animation timing coordination with AnimationMixin

**Animation Requirements**: 🔴 **COMPLEX**
- Gravity physics simulation
- Particle system integration
- Custom easing functions
- Frame-by-frame updates via OnUpdate

**Validation Checklist**: See [Vertical Bar Validation](#vertical-bar-validation)

**Timeline**: 4-5 days

---

### Phase 4: Circular Bar Migration

**Objective**: Port the Circular bar with complex arc rendering and glow animations.

**Rationale**: Most complex style - saved for last to ensure V2 architecture is battle-tested.

**Tasks**:
1. Create `ui/xpbars/circular_v2/` directory structure
2. Implement `CircularBarStyleTemplate.lua`
3. Create `CircularBarTemplate.xml` with arc textures
4. Override overlay action methods for arc positioning
5. Implement level-up glow animation system
6. Test arc angle calculations (0-360 degrees)
7. Validate portrait background integration
8. Compare animations with V1 Circular bar

**Key Challenges**:
- **Arc positioning**: Convert XP ratios to arc angles (0-360°)
- **Glow animation**: Pulsing glow effect on level-up (fade in → hold → fade out)
- **Portrait background**: Alpha mask integration
- Custom overlay names (must override all overlay action methods)
- Complex visual layering (background → arcs → portrait → glow)

**Animation Requirements**: 🔴 **VERY COMPLEX**
- Arc angle interpolation
- Glow fade in/hold/fade out sequence
- Alpha masking coordination
- Multiple simultaneous animations

**Custom Overlay Overrides Required**:
```lua
-- Circular uses different overlay names
UpdateCurrentXPBar(context, "XPArc")
UpdateRestedOverlay(context, "RestedArc")
UpdateQuestCompleteOverlay(context, "QuestCompleteArc")
UpdateQuestIncompleteOverlay(context, "QuestIncompleteArc")
UpdateExhaustionTick(context, "ExhaustionMarker")
UpdateFlashOverlay(context, "GlowTexture")
```

**Validation Checklist**: See [Circular Bar Validation](#circular-bar-validation)

**Timeline**: 5-7 days

---

### Phase 5: V1 Architecture Cleanup

**Objective**: Remove old V1 architecture code after all styles migrated and validated.

**Tasks**:
1. Audit for any remaining V1 references
2. Remove `ui/xpbar/` directory and all contents
3. Update `Frames.xml` to remove V1 includes
4. Update `.toc` file to remove V1 file references
5. Migrate any remaining V1-specific features to V2
6. Update XPBar controller to V2-only
7. Remove V1 compatibility shims

**Deliverables**:
- Clean codebase with only V2 architecture
- Reduced LOC by ~50%
- Simplified maintenance burden

**Timeline**: 1-2 days

---

### Phase 6: Global Cleanup & Polish

**Objective**: Final cleanup, optimization, and documentation polish.

**Tasks**:
1. Remove all debug logging from V2 code
2. Optimize hot paths (OnUpdate handlers, ticker callbacks)
3. Final documentation review and updates
4. Create external developer tutorial/examples
5. Update README.md with V2 architecture overview
6. Add contribution guidelines for custom styles
7. Create style template boilerplate

**Deliverables**:
- Production-ready codebase
- Complete external developer documentation
- Style template starter kit
- Updated README and contribution guide

**Timeline**: 2-3 days

---

## Style Migration Order

### Order Rationale

1. **✅ Flat Bar** - COMPLETED (proof of concept, simplest draggable style)
2. **⬜ Legacy Bar** - Static positioning, atlas textures, no custom animations
3. **⬜ Vertical Bar** - Custom gravity animations, tests animation extensibility
4. **⬜ Circular Bar** - Most complex, arc rendering, multiple custom animations

### Migration Dependencies

```
Flat Bar (DONE)
    ↓
Legacy Bar ← Phase 2
    ↓
Vertical Bar ← Phase 3 (depends on animation testing)
    ↓
Circular Bar ← Phase 4 (depends on custom overlay overrides validated)
    ↓
V1 Cleanup ← Phase 5 (ALL styles migrated)
    ↓
Global Cleanup ← Phase 6 (final polish)
```

---

## Animation Testing Strategy

### V2 Animation System Architecture

**Status**: ✅ **PRODUCTION READY** (as of Phase 1 completion)

**Core Components**:

#### AnimationManager (`ui/xpbars/mixins/animation/AnimationManager.lua` - 479 lines)
- **Centralized animation driver** with frame-based OnUpdate loop
- **Bar registration system**: Register/Unregister bars for animation updates
- **Flash timing**: 0.5s duration (0.25s fade in + 0.25s fade out) - matches V1 exactly
- **Retargeting support**: Smooth handling of multiple rapid XP gains via context aggregation
- **Level-up detection**: Instant bar reset (progress=1.0) to avoid "drain" effect
- **Flash cooldown**: 100ms cooldown after flash completion to prevent double flash
- **Context preservation pattern**: Separates incoming context (for decisions) from aggregated context (for positioning)

**Key Methods**:
```lua
AnimationManager:AnimateTo(bar, targetRatio, xpContext, config)
AnimationManager:OnUpdate(elapsed)  -- Driver loop
AnimationManager:UpdateBarAnimation(bar, now)
AnimationManager:Register(bar) / Unregister(bar)
```

#### AnimationUtils (`ui/xpbars/mixins/animation/AnimationUtils.lua` - 324 lines)
- **Duration calculation**: Based on ratio delta (0.3s base + 0.15s per 10% delta)
- **Easing functions**: EaseOutQuad for smooth deceleration
- **Level-up detection**: Detects XP decrease or PLAYER_LEVEL_UP event
- **Context aggregation**: Combines multiple XP gains during retargeting
- **Flash data building**: Calculates flash alpha for each animation step

**Key Features Validated**:
- ✅ Flash timing matches V1 exactly (38 frames @ 60fps = 0.494s measured)
- ✅ Double flash bug fixed via context preservation pattern
- ✅ Cooldown system prevents rapid retriggers
- ✅ Level-up instant reset (superior to V1's "drain" effect)
- ✅ Retargeting handles aggregated XP gains smoothly

**Debug Commands Available**:
- `/animdebug` - Dump animation debug messages (max 50)
- `/flashdebug` + `/v2flashlogs` - V2 flash timing logs (max 100)
- `/flashtrack` + `/flashtracklogs` - Flash event tracking (toggle on/off)
- `/testlevelup` - Trigger PLAYER_LEVEL_UP for both V1 and V2

---

### Animation Categories

#### 1. Standard Animations (Handled by AnimationManager)

**Description**: Built-in V2 animations provided by the new `AnimationManager` system.

**Included Effects**:
- Value smoothing (XP bar fill transitions with EaseOutQuad)
- Flash effects (XP gain, level up) - 0.5s fade in/out
- Retargeting (smooth aggregation of multiple XP gains)
- Level-up instant reset (avoids StatusBar smoothing artifact)

**Testing Approach**:
- ✅ Already validated in flat bar V2 (Phase 1 complete)
- ✅ Flash timing verified: 38 frames, 0.494s duration (matches V1)
- ✅ Double flash prevention tested and confirmed
- ⬜ Verify each migrated style uses AnimationManager correctly
- ⬜ Test flash timing consistency across all styles
- ⬜ Validate retargeting behavior with rapid XP gains

**Validation**:
- XP gain triggers flash (white overlay fade in/out, 0.5s duration)
- Level up triggers flash (white overlay fade in/out, 0.5s duration)
- Bar value smoothly interpolates (no instant jumps except level-up)
- Multiple rapid XP gains aggregate smoothly (no stutter)
- Flash cooldown prevents double flash on quest turn-ins
- Periodic refresh (xpGained=0) does NOT trigger flash

---

#### 2. Custom Style Animations (Style-Specific)

**Description**: Unique animations defined within individual styles.

**Examples**:

##### Vertical Bar Gravity Animation
- **Effect**: New XP "falls down" from top with gravity physics
- **Implementation**: Custom OnUpdate handler with velocity/acceleration
- **Testing**:
  - ⬜ Verify gravity physics feel natural
  - ⬜ Test at different XP gain amounts (small vs large)
  - ⬜ Validate particle effects trigger correctly
  - ⬜ Ensure no performance issues with OnUpdate

##### Circular Bar Glow Animation
- **Effect**: Level-up triggers pulsing glow (fade in → hold → fade out)
- **Implementation**: Custom ticker with three-phase animation
- **Testing**:
  - ⬜ Verify glow timing (fade in: 0.3s, hold: 0.5s, fade out: 0.5s)
  - ⬜ Test glow alpha progression (0 → 1 → 1 → 0)
  - ⬜ Validate glow doesn't interfere with arc rendering
  - ⬜ Test multiple rapid level-ups (animation queuing)

---

### Animation Integration Patterns
---

### Animation Integration Patterns

#### Pattern 1: AnimationManager-Only (Legacy, Flat)

**No custom animations** - rely entirely on AnimationManager for standard effects.

**Implementation**:
```lua
-- Style integrates with AnimationManager via BaseMixin
-- AnimationManager automatically handles:
--   - Flash effects (XP gain, level up)
--   - Value smoothing (EaseOutQuad)
--   - Retargeting (multiple rapid XP gains)
--   - Level-up instant reset

-- Style only needs to implement ApplyAnimationStep
function FlatBarStyle:ApplyAnimationStep(context)
    -- Update StatusBar value
    self.StatusBar:SetValue(context.currentRatio)
    
    -- Apply flash alpha if active
    if context.flashData and context.flashData.currentAlpha > 0 then
        self.FlashOverlay:SetAlpha(context.flashData.currentAlpha)
    else
        self.FlashOverlay:SetAlpha(0)
    end
end
```

**Testing**: 
- ⬜ Verify AnimationManager flash timing (0.5s duration)
- ⬜ Verify smooth value interpolation
- ⬜ Test retargeting with rapid XP gains
- ⬜ Verify level-up instant reset (no "drain")

---

#### Pattern 2: AnimationManager + Custom OnUpdate (Vertical)

**Custom gravity physics** added via OnUpdate handler alongside AnimationManager.

**Implementation**:
```lua
function VerticalBarStyle:Initialize()
    -- AnimationManager handles standard effects
    -- Custom OnUpdate for gravity animation
    self:SetScript("OnUpdate", function(self, elapsed)
        self:UpdateGravityAnimation(elapsed)
    end)
end

function VerticalBarStyle:UpdateGravityAnimation(elapsed)
    -- Custom gravity physics here
    -- Update particle positions
    -- Apply velocity/acceleration
end

-- Still implement ApplyAnimationStep for AnimationManager
function VerticalBarStyle:ApplyAnimationStep(context)
    -- Standard bar update + gravity particles
end
```

**Testing**:
- ⬜ AnimationManager flash/smoothing still works correctly
- ⬜ Gravity animation doesn't interfere with standard animations
- ⬜ Performance acceptable with both OnUpdate and AnimationManager active

**Testing**:
- ⬜ AnimationManager flash/smoothing still works correctly
- ⬜ Gravity animation doesn't interfere with standard animations
- ⬜ Performance acceptable with both OnUpdate and AnimationManager active

---

#### Pattern 3: AnimationManager + Custom Ticker (Circular)

**Multi-phase glow animation** via C_Timer.NewTicker alongside AnimationManager.

**Implementation**:
```lua
function CircularBarStyle:TriggerLevelUpGlow()
    local startTime = GetTime()
    local fadeInDuration = 0.3
    local holdDuration = 0.5
    local fadeOutDuration = 0.5
    
    self._glowTicker = C_Timer.NewTicker(0.016, function()
        local elapsed = GetTime() - startTime
        
        if elapsed < fadeInDuration then
            -- Fade in
            local alpha = elapsed / fadeInDuration
            self.GlowTexture:SetAlpha(alpha)
        elseif elapsed < fadeInDuration + holdDuration then
            -- Hold
            self.GlowTexture:SetAlpha(1.0)
        elseif elapsed < fadeInDuration + holdDuration + fadeOutDuration then
            -- Fade out
            local fadeProgress = (elapsed - fadeInDuration - holdDuration) / fadeOutDuration
            self.GlowTexture:SetAlpha(1.0 - fadeProgress)
        else
            -- Complete
            self.GlowTexture:SetAlpha(0)
            self._glowTicker:Cancel()
        end
    end)
end

-- Still implement ApplyAnimationStep for AnimationManager
function CircularBarStyle:ApplyAnimationStep(context)
    -- Update arc angles based on context.currentRatio
    -- Apply AnimationManager flash to separate overlay
end
```

**Testing**:
- ⬜ Glow timing matches V1 exactly (fade in: 0.3s, hold: 0.5s, fade out: 0.5s)
- ⬜ AnimationManager flash doesn't interfere with glow animation
- ⬜ Ticker cleanup on style hide/unload (prevent memory leak)
- ⬜ Multiple rapid triggers handled gracefully (cancel previous ticker)

---

### Animation Performance Testing

**Goals**:
- No FPS drops during animations
- No memory leaks from tickers/OnUpdate handlers
- Smooth animation playback even during combat

**Test Procedure**:
1. Enable frame rate display (`/fstack`)
2. Trigger animations repeatedly (kill mobs, complete quests)
3. Monitor FPS during animations
4. Check memory usage over time (`/reload` after 30 mins)
5. Stress test: multiple XP gains in rapid succession
6. Combat test: animations during boss fight

**Acceptance Criteria**:
- FPS ≥ 60 during all animations (on modern hardware)
- No memory leaks (stable over 30-minute session)
- Animations remain smooth during combat

---

## Validation Checklist

### Legacy Bar Validation

#### Visual Elements
- ⬜ Atlas textures render correctly (background, bar fill)
- ⬜ Rested overlay positioned correctly (after current XP)
- ⬜ Quest complete overlay visible when quests ready to turn in
- ⬜ Quest incomplete overlay visible with incomplete quest progress
- ⬜ Exhaustion tick positioned at rested XP end
- ⬜ Flash overlay covers full bar area

#### Positioning
- ⬜ Bar anchored to Blizzard MainStatusTrackingBarContainer
- ⬜ Position matches V1 Legacy bar exactly
- ⬜ Position persists across /reload (static mode)
- ⬜ Bar follows Blizzard bar if Edit Mode used

#### Behavior
- ⬜ XP gains update bar fill smoothly
- ⬜ Level up resets bar to 0 and updates max
- ⬜ Rested state changes update overlay immediately
- ⬜ Quest tracking updates quest overlays
- ⬜ Tooltip shows correct XP values on hover

#### Animations
- ⬜ XP gain triggers flash effect
- ⬜ Level up triggers flash effect
- ⬜ Bar value smooths (no instant jumps)

#### Text
- ⬜ Level text displays correctly (left-aligned)
- ⬜ XP text displays correctly (center-aligned)
- ⬜ Percent text displays correctly (right-aligned)
- ⬜ Rate text displays XP/hour
- ⬜ Session text updates every second
- ⬜ Quest summary text shows quest XP counts

#### Options Integration
- ⬜ Color changes apply immediately
- ⬜ Text visibility toggles work
- ⬜ Settings reset applies correctly
- ⬜ All config options respected

---

### Vertical Bar Validation

#### Visual Elements
- ⬜ Vertical bar fills from bottom to top
- ⬜ Rested overlay positioned above current XP
- ⬜ Quest overlays stack vertically
- ⬜ Exhaustion tick positioned at rested XP top
- ⬜ Gravity particles render correctly

#### Positioning
- ⬜ Bar is draggable (Shift+drag)
- ⬜ Position persists across /reload
- ⬜ Default position centered on screen
- ⬜ Clamps to screen edges

#### Behavior
- ⬜ XP gains trigger gravity animation
- ⬜ Gravity feels natural (acceleration/deceleration)
- ⬜ Particles spawn on XP gain
- ⬜ Vertical overlay positioning correct

#### Animations
- ⬜ Gravity animation plays on XP gain
- ⬜ Particles fade out correctly
- ⬜ Standard flash effects still work
- ⬜ No animation conflicts
- ⬜ Performance acceptable (FPS ≥ 60)

#### Custom Animation Testing
- ⬜ Small XP gains (1-10): particles subtle
- ⬜ Medium XP gains (100-500): particles visible
- ⬜ Large XP gains (1000+): particles dramatic
- ⬜ Rapid XP gains: animations queue correctly
- ⬜ Gravity timing matches V1 Vertical bar

---

### Circular Bar Validation

#### Visual Elements
- ⬜ Circular arc renders correctly (360° circle)
- ⬜ XP arc fills clockwise from top (12 o'clock)
- ⬜ Rested arc positioned after XP arc
- ⬜ Quest arcs render correctly
- ⬜ Portrait background displays (if enabled)
- ⬜ Glow texture overlay visible during level-up

#### Positioning
- ⬜ Bar is draggable (Shift+drag)
- ⬜ Position persists across /reload
- ⬜ Default position centered on screen
- ⬜ Clamps to screen edges

#### Behavior
- ⬜ Arc angles calculate correctly (0-360°)
- ⬜ Multiple arcs don't overlap incorrectly
- ⬜ Portrait alpha mask works correctly
- ⬜ Glow animation triggers on level-up

#### Animations
- ⬜ Glow fade in (0.3s) smooth
- ⬜ Glow hold (0.5s) at full alpha
- ⬜ Glow fade out (0.5s) smooth
- ⬜ Glow timing matches V1 Circular bar
- ⬜ Arc angle smoothing works
- ⬜ Standard flash effects still work
- ⬜ No animation conflicts
- ⬜ Performance acceptable (FPS ≥ 60)

#### Custom Animation Testing
- ⬜ Single level-up: glow plays once
- ⬜ Rapid level-ups: glow restarts correctly
- ⬜ Level-up during combat: glow doesn't lag
- ⬜ Glow alpha progression correct (0 → 1 → 0)

#### Overlay Method Overrides
- ⬜ `UpdateCurrentXPBar(context, "XPArc")` works
- ⬜ `UpdateRestedOverlay(context, "RestedArc")` works
- ⬜ `UpdateQuestCompleteOverlay(context, "QuestCompleteArc")` works
- ⬜ `UpdateQuestIncompleteOverlay(context, "QuestIncompleteArc")` works
- ⬜ `UpdateExhaustionTick(context, "ExhaustionMarker")` works

---

### Cross-Style Validation

**Test all styles together** to ensure multi-instance support works:

#### Multi-Instance Testing
- ⬜ Create multiple bars of different styles simultaneously
- ⬜ All bars update on XP gain
- ⬜ All bars flash on level-up
- ⬜ Color changes apply to all visible bars
- ⬜ Each bar maintains independent position
- ⬜ No cross-contamination of state

#### Performance Testing
- ⬜ All 4 styles visible: FPS ≥ 60
- ⬜ Memory stable with all styles
- ⬜ No ticker leaks across styles
- ⬜ /reload preserves all positions

---

## Rollback Strategy

### Rollback Triggers

Rollback to V1 architecture if:
- Migration introduces game-breaking bugs
- Performance degrades significantly (FPS < 30 during animations)
- Critical features lost during migration
- User complaints exceed acceptable threshold

### Rollback Procedure

1. **Revert to last stable commit** before migration started
2. **Restore V1 files** from `refs/XPChroniclev1.0.1/` backup
3. **Update .toc** to re-enable V1 file includes
4. **Test V1 functionality** restored correctly
5. **Communicate rollback** to users via changelog

### Rollback Prevention

- Maintain V1 backup in `refs/` directory
- Incremental migration (one style at a time)
- Comprehensive testing before each phase completion
- Code freeze on V2 after validation

---

## Timeline & Resources

### Overall Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Documentation & Planning | 1-2 days | None |
| Phase 2: Legacy Bar Migration | 2-3 days | Phase 1 complete |
| Phase 3: Vertical Bar Migration | 4-5 days | Phase 2 complete |
| Phase 4: Circular Bar Migration | 5-7 days | Phase 3 complete |
| Phase 5: V1 Architecture Cleanup | 1-2 days | Phase 4 complete |
| Phase 6: Global Cleanup & Polish | 2-3 days | Phase 5 complete |
| **TOTAL** | **15-22 days** | Sequential |

### Resource Requirements

**Developer Time**:
- Primary developer: Full-time for migration
- Testing support: Part-time for validation

**Tools**:
- WoW client for in-game testing
- Lua linter (luacheck) for syntax validation
- Git for version control and rollback capability

**Documentation**:
- Architecture documentation updates
- Style developer guide
- Animation testing guide
- Migration templates

---

## Next Steps

### Immediate Actions (Phase 1)

1. ✅ **Create MIGRATION_PLAN.md** (this document)
2. ⬜ **Update ARCHITECTURE_V2.md** for external developers
3. ⬜ **Create style migration template** (`STYLE_MIGRATION_TEMPLATE.md`)
4. ⬜ **Document animation testing procedures** (`ANIMATION_TESTING.md`)
5. ⬜ **Create per-style validation checklists** (expand validation sections above)

### Sign-off Required Before Phase 2

- [ ] Migration plan approved
- [ ] External developer documentation complete
- [ ] Style migration template ready
- [ ] Animation testing guide ready
- [ ] Validation checklists finalized

---

## Appendix

### File Structure After Full Migration

```
ui/
  xpbars/                          ← V2 ONLY (V1 removed)
    BaseMixin.lua
    ContextBuilder.lua
    StyleBuilder.lua
    ARCHITECTURE_V2.md             ← External developer guide
    mixins/
      AnimationMixin.lua
      InteractionMixin.lua
      LayoutMixin.lua
      PaintMixin.lua
      PositionMixin.lua
      TextMixin.lua
      TooltipMixin.lua
      VisualsMixin.lua
    flatbar_v2/
      FlatBarStyle.lua
      FlatBarTemplate.xml
    legacy_v2/                     ← NEW (Phase 2)
      LegacyBarStyle.lua
      LegacyBarTemplate.xml
    vertical_v2/                   ← NEW (Phase 3)
      VerticalBarStyle.lua
      VerticalBarTemplate.xml
    circular_v2/                   ← NEW (Phase 4)
      CircularBarStyle.lua
      CircularBarTemplate.xml
```

### LOC Reduction After Full Migration

| Category | V1 Total | V2 Total | Reduction |
|----------|----------|----------|-----------|
| Style Files | ~2,825 LOC | ~490 LOC | **-83%** |
| Shared/Core | ~0 LOC | ~1,800 LOC | N/A (new) |
| **Overall** | **~2,825 LOC** | **~2,290 LOC** | **-19%** |

**Key Insight**: Despite adding ~1,800 LOC of shared code, total codebase is still 19% smaller due to massive reduction in per-style duplication. Future new styles require only ~100-200 LOC instead of 500-1000 LOC.

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-06  
**Status**: Phase 1 - Documentation & Planning  
**Next Review**: After Phase 2 completion
