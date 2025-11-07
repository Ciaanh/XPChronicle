# Legacy Bar V2 Migration Plan

**Date**: November 7, 2025  
**Phase**: Phase 2 - Legacy Bar Migration  
**Status**: 🔄 Preparation Stage

---

## Migration Overview

### Objective
Port the Legacy Bar (Blizzard-style) from V1 architecture to V2 mixin-based composition system.

### Why Legacy Bar First?
- Simplest style after Flat Bar (no custom animations)
- **Static positioning** (different from Flat Bar's draggable system)
- Uses standard AnimationManager (no custom animation code needed)
- Good test of V2 architecture with different positioning strategy

### Key Differences from Flat Bar V2
| Aspect | Flat Bar V2 | Legacy Bar V2 |
|--------|-------------|---------------|
| **Positioning** | Draggable (PositionMixin) | Static (anchored to Blizzard bar) |
| **Size** | Fixed 565x11 | Fixed 565x11 (matches Blizzard) |
| **Animations** | AnimationManager | AnimationManager (same) |
| **Textures** | Solid colors | Solid colors (atlas removed in V1) |
| **Container** | Simple Frame | LegacyXPBarContainerMixin (positioning logic) |

---

## V1 Legacy Bar Analysis

### File Structure (Current V1)
```
ui/xpbar/styles/
├── LegacyXPBarMixin.lua (469 lines)
│   ├── ExhaustionTickMixin (~15 lines)
│   ├── LegacyXPBarContainerMixin (~100 lines) - Positioning logic
│   └── LegacyXPBarMixin (~354 lines) - Bar implementation
└── LegacyXPBar.xml (184 lines)
    ├── LegacyXPBarTemplate (main bar)
    ├── LegacyXPBarContainerTemplate (container with border)
    └── Below-bar text containers
```

### Key Features in V1
1. **Static Positioning** (`PositionToMatchBlizzardBar`)
   - Anchors to `MainStatusTrackingBarContainer`
   - Retry logic with timer (handles race conditions)
   - No dragging, no position persistence

2. **Color Customization** (added after initial implementation)
   - All colors customizable via XPBarColors
   - Solid color textures (no atlases)
   - Flash colors based on rested state

3. **Container Management**
   - `LegacyXPBarContainerMixin` handles positioning
   - Wire up text elements from OverlayFrame
   - Below-bar text containers (rate, session, quest summary)

4. **Standard Overlays**
   - Rested: `ExhaustionLevelFillBar` (solid texture, customizable color)
   - Quest Complete: `QuestOverlayComplete` (solid texture, customizable color)
   - Quest Incomplete: `QuestOverlayIncomplete` (solid texture, customizable color)
   - Exhaustion Tick: `ExhaustionTick` (atlas-based marker)

5. **Animation (V1 Legacy)**
   - Uses XPBarMixinBase animation system
   - Flash on XP gain (customizable color)
   - Value smoothing via StatusBar

### Code That Will Be Removed (V1 → V2)
- ❌ Event handling (handled by BaseMixin)
- ❌ Animation logic (handled by AnimationManager)
- ❌ Tooltip management (handled by TooltipMixin)
- ❌ Color update methods (handled by PaintMixin)
- ❌ Text formatting (handled by TextMixin)
- ❌ State calculations (handled by ContextBuilder)

### Code That Will Be Retained (V1 → V2)
- ✅ Static positioning logic (`PositionToMatchBlizzardBar`)
- ✅ Container initialization (`OnLoad`, retry timer)
- ✅ Text element wiring (`WireTextElements`)
- ✅ `ApplyAnimationStep` implementation (V2 contract)
- ✅ XML visual structure (with minor adjustments)

---

## V2 Architecture Plan

### Directory Structure (New)
```
ui/xpbars/legacy_v2/
├── LegacyBarStyle.lua (~150 lines estimated)
│   ├── Style configuration
│   ├── Positioning methods (static, non-draggable)
│   ├── ApplyAnimationStep implementation
│   └── StyleBuilder registration
├── LegacyBarTemplate.xml (~180 lines)
│   ├── LegacyBarTemplate (main bar frame)
│   └── Visual layers (StatusBar, overlays, text)
└── _includes.xml (2 lines)
    └── References to Lua and XML
```

### Mixin Composition
```lua
-- LegacyBarStyle uses:
XPBarMixinBase_v2        -- Event orchestration, Trigger/Action methods
+ InteractionMixin       -- Mouse handling (Alt+Click, Ctrl+Click)
+ LayoutMixin            -- Overlay positioning (standard algorithms)
+ PaintMixin             -- Color application
+ TextMixin              -- Text formatting, real-time updates
+ TooltipMixin           -- Tooltip management
+ VisualsMixin           -- Visual element orchestration
+ LegacyPositionMixin    -- NEW: Static positioning (custom for Legacy)
+ LegacyBarStyleTemplate -- Style-specific implementation
```

### New Positioning Mixin

**Create**: `ui/xpbars/mixins/LegacyPositionMixin.lua`

This will be a **minimal mixin** specifically for Legacy Bar's static positioning:

```lua
-- LegacyPositionMixin.lua
-- Static positioning for Legacy Bar (anchored to Blizzard's XP bar)

local LegacyPositionMixin = {}

function LegacyPositionMixin:InitializePosition()
    -- Position to match Blizzard's XP bar immediately
    self:PositionToMatchBlizzardBar()
    
    -- Retry after 0.5s in case Blizzard UI not fully loaded
    self._positionTimer = C_Timer.NewTimer(0.5, function()
        if self and self.PositionToMatchBlizzardBar then
            self:PositionToMatchBlizzardBar()
        end
    end)
end

function LegacyPositionMixin:PositionToMatchBlizzardBar()
    local container = _G.MainStatusTrackingBarContainer
    if not container then
        return
    end
    
    self:ClearAllPoints()
    self:SetPoint("TOP", container, "TOP", 0, 5)
end

function LegacyPositionMixin:OnHide()
    -- Cleanup timer
    if self._positionTimer then
        self._positionTimer:Cancel()
        self._positionTimer = nil
    end
end

return LegacyPositionMixin
```

**Rationale**: 
- Flat Bar uses `PositionMixin` (draggable, persistence)
- Legacy Bar needs **static positioning** (non-draggable, anchored to Blizzard)
- Custom mixin avoids conflicts with PositionMixin's dragging logic

---

## Implementation Steps

### Step 1: Create Directory Structure ⏳
```bash
mkdir ui/xpbars/legacy_v2
```

Files to create:
- `LegacyBarStyle.lua` - Main style implementation
- `LegacyBarTemplate.xml` - Visual structure
- `_includes.xml` - File references

### Step 2: Create LegacyPositionMixin ⏳
**File**: `ui/xpbars/mixins/LegacyPositionMixin.lua`

**Purpose**: Handle static positioning anchored to Blizzard's XP bar

**Methods**:
- `InitializePosition()` - Position to Blizzard bar with retry
- `PositionToMatchBlizzardBar()` - Anchor to MainStatusTrackingBarContainer
- `OnHide()` - Cleanup timer

### Step 3: Implement LegacyBarStyle.lua ⏳

**Structure**:
```lua
-- Header: Dependencies check
-- Debug system (optional, for development)
-- LegacyBarStyleTemplate:
--   - ApplyAnimationStep(stepContext) - StatusBar + Flash
--   - GetAnimationConfig() - Animation settings
--   - (Optional) Override action methods if needed
-- Style configuration table
-- StyleBuilder.RegisterStyle() call
```

**Key Method**: `ApplyAnimationStep`
```lua
function LegacyBarStyleTemplate:ApplyAnimationStep(stepContext)
    -- 1. Update StatusBar value (smooth fill animation)
    if self.StatusBar then
        self.StatusBar:SetValue(stepContext.currentRatio)
    end
    
    -- 2. Update flash overlay (fade in/out animation)
    if self.GainFlash and stepContext.flashData then
        local flashData = stepContext.flashData
        if flashData.active and flashData.currentAlpha > 0 then
            -- Get color based on rested state
            local hasRestedXP = stepContext.xpContext and stepContext.xpContext.hasRestedXP
            local colorKey = hasRestedXP and Color.Rested or Color.XpBar
            local color = XPBarColors:GetUserColor(colorKey)
            
            self.GainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
            self.GainFlash:Show()
        else
            self.GainFlash:Hide()
        end
    end
end
```

### Step 4: Create LegacyBarTemplate.xml ⏳

**Based on**: V1 `LegacyXPBar.xml` with V2 simplification (following FlatBarTemplate_v2 pattern)

**Key Design Decision: Eliminate Container Completely**

After analyzing Flat Bar V2's structure, we can place the border frame atlas directly on the main frame as a texture layer, eliminating the container wrapper entirely.

**V1 Legacy Structure**:
```
LegacyXPBarContainerTemplate (571x17)
├── Border frame atlas (OVERLAY layer)
└── LegacyXPBarTemplate (565x11, offset 1,5 inside container)
    └── StatusBar (565x10)
```

**V2 Legacy Structure** (No Container):
```
LegacyBarTemplate (571x17) - single frame, no nesting!
├── Border frame atlas (OVERLAY layer - same as V1)
├── Flash overlay (OVERLAY layer)
├── StatusBar (565x10, offset 1,5 inside frame)
│   ├── Background atlas
│   ├── Rested overlay
│   ├── Quest overlays
│   └── Exhaustion tick
├── OverlayFrameTextContainer (on-bar text)
└── BelowBarTextContainer (below-bar text)
```

**Key Changes from V1**:

1. **No Container Wrapper** (major simplification)
   - V1: `LegacyXPBarContainerTemplate` wraps `LegacyXPBarTemplate` (nested)
   - V2: Single `LegacyBarTemplate` frame (flat, like FlatBarTemplate_v2)
   - Border frame atlas is just a texture layer on main frame

2. **Frame size includes border space**
   - Frame: 571x17 (accommodates border)
   - StatusBar: 565x10 (actual bar size)
   - StatusBar offset: (1,5) positions bar inside border area

3. **Border as texture layer** (not container)
   ```xml
   <Layers>
       <Layer level="OVERLAY">
           <Texture parentKey="BorderFrame" atlas="UI-HUD-ExperienceBar-Frame" 
                    useAtlasSize="true"/>
       </Layer>
   </Layers>
   ```

4. **Positioning logic in mixin**
   - Container OnLoad/OnShow logic → `LegacyPositionMixin:InitializePosition()`
   - No container scripts needed
   - Positioning operates directly on main frame

5. **Mixin declaration**: V2 composition pattern
   ```xml
   <Frame name="LegacyBarTemplate" virtual="true" 
          mixin="LegacyBarStyleTemplate"
          frameStrata="LOW" enableMouse="true">
   ```

6. **Simplified scripts**: Only V2 contract methods
   ```xml
   <Scripts>
       <OnLoad method="OnLoad"/>
       <OnShow method="OnShow"/>
       <OnHide method="OnHide"/>
       <OnEnter method="OnEnter"/>
       <OnLeave method="OnLeave"/>
       <OnMouseUp method="OnMouseUp"/>
   </Scripts>
   ```

**XML Structure Template**:
```xml
<Frame name="LegacyBarTemplate" virtual="true" mixin="LegacyBarStyleTemplate" 
       frameStrata="LOW" enableMouse="true" fixedFrameStrata="true">
    <Size x="571" y="17"/>
    <Layers>
        <!-- Border frame atlas - on main frame, not container -->
        <Layer level="OVERLAY">
            <Texture parentKey="BorderFrame" atlas="UI-HUD-ExperienceBar-Frame" 
                     useAtlasSize="true"/>
        </Layer>
        
        <!-- Flash overlay (above border) -->
        <Layer level="OVERLAY" textureSubLevel="3">
            <Texture parentKey="GainFlash" hidden="true">
                <Anchors>
                    <Anchor point="TOPLEFT" x="1" y="-5"/>
                    <Anchor point="BOTTOMRIGHT" x="-5" y="1"/>
                </Anchors>
            </Texture>
        </Layer>
    </Layers>
    <Frames>
        <!-- StatusBar offset inside frame to accommodate border -->
        <StatusBar parentKey="StatusBar" minValue="0" maxValue="1" defaultValue="0">
            <Size x="565" y="10"/>
            <Anchors>
                <Anchor point="BOTTOMLEFT" x="1" y="5"/>
            </Anchors>
            <!-- StatusBar layers: background atlas, overlays, etc. -->
        </StatusBar>
        
        <!-- Text containers -->
        <Frame parentKey="OverlayFrameTextContainer">...</Frame>
        <Frame parentKey="BelowBarTextContainer">...</Frame>
    </Frames>
</Frame>
```

**Why This Works**:
- ✅ Border frame atlas is purely visual (texture layer)
- ✅ StatusBar offset (1,5) leaves room for border (same as V1)
- ✅ Frame size (571x17) includes border space (same as V1)
- ✅ No functional loss - positioning moves to LegacyPositionMixin
- ✅ Consistent with Flat Bar V2 pattern (no container nesting)
- ✅ Simpler XML structure (~140 lines vs V1's 184 lines)

### Step 5: Register with StyleBuilder ⏳

**In LegacyBarStyle.lua**:
```lua
XPBarStyleBuilder.RegisterStyle("legacy_v2", {
    template = "LegacyBarTemplate",
    displayName = "Legacy (Blizzard-style)",
    description = "Classic Blizzard experience bar style",
    mixins = {
        XPBarMixinBase_v2,
        XPBarInteractionMixin,
        XPBarLayoutMixin,
        XPBarPaintMixin,
        XPBarTextMixin,
        XPBarTooltipMixin,
        XPBarVisualsMixin,
        LegacyPositionMixin,  -- Custom positioning
        LegacyBarStyleTemplate
    },
    config = {
        isDraggable = false,  -- IMPORTANT: Static positioning only
        savePosition = false, -- No position persistence
        defaultSize = { width = 565, height = 11 },
        animations = {
            enabled = true,
            flashOnGain = true
        }
    }
})
```

### Step 6: Update Includes ⏳

**In main `Frames.xml`**:
```xml
<!-- V2 Legacy Bar -->
<Include file="ui\xpbars\legacy_v2\_includes.xml"/>
```

**Create `ui/xpbars/legacy_v2/_includes.xml`**:
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="LegacyBarStyle.lua"/>
    <Include file="LegacyBarTemplate.xml"/>
</Ui>
```

### Step 7: Update .toc File ⏳

Add after Flat Bar V2 includes:
```toc
# Legacy Bar V2
ui\xpbars\mixins\LegacyPositionMixin.lua
ui\xpbars\legacy_v2\_includes.xml
```

---

## Testing Checklist

### Visual Elements
- [ ] StatusBar renders correctly (solid color texture)
- [ ] Background atlas texture visible
- [ ] Rested overlay positioned correctly (after current XP)
- [ ] Quest complete overlay visible when quests ready
- [ ] Quest incomplete overlay visible with incomplete quest progress
- [ ] Exhaustion tick positioned at rested XP end
- [ ] Flash overlay covers full bar area

### Positioning
- [ ] Bar anchored to Blizzard's MainStatusTrackingBarContainer
- [ ] Position matches V1 Legacy bar exactly (TOP anchor, 0, 5 offset)
- [ ] Position persists across /reload
- [ ] Bar follows if Blizzard bar moves (Edit Mode)
- [ ] NOT draggable (no drag cursor, no position save)

### Behavior
- [ ] XP gains update bar fill smoothly (AnimationManager)
- [ ] Level up resets bar to 0 (instant, no "drain")
- [ ] Rested state changes update overlay immediately
- [ ] Quest tracking updates quest overlays
- [ ] Tooltip shows correct XP values on hover

### Animations (AnimationManager)
- [ ] XP gain triggers flash effect (0.5s duration)
- [ ] Level up triggers flash effect
- [ ] Bar value smoothly interpolates (no instant jumps except level-up)
- [ ] Multiple rapid XP gains aggregate smoothly (retargeting)
- [ ] Flash cooldown prevents double flash (100ms)
- [ ] Periodic refresh (xpGained=0) does NOT trigger flash

### Text
- [ ] Level text displays correctly (left-aligned)
- [ ] XP text displays correctly (center-aligned)
- [ ] Percent text displays correctly (right-aligned)
- [ ] Below-bar text: Rate, Session, Quest Summary
- [ ] Real-time text updates (1-second ticker)

### Options Integration
- [ ] Color changes apply immediately
- [ ] Animation toggle works (enable/disable)
- [ ] Text visibility toggles work
- [ ] Settings persist across /reload

### Performance
- [ ] No FPS drops during animations
- [ ] No memory leaks (timer cleanup on hide)
- [ ] No errors in /console scriptErrors 1

---

## Side-by-Side Comparison Test

### Test Procedure
1. Enable both V1 Legacy and V2 Legacy (temporary dual-load)
2. Position them side-by-side
3. Gain XP (kill mobs, complete quests)
4. Compare:
   - Flash timing (should be identical: 0.5s)
   - Bar fill animation (should match)
   - Overlay positioning (pixel-perfect)
   - Colors (should be identical)
   - Text updates (should sync)

### Validation Criteria
- ✅ Visual appearance identical
- ✅ Animation timing identical
- ✅ No V2-specific bugs or artifacts
- ✅ Performance equal or better

---

## Migration Benefits

### Code Reduction
- **V1 Legacy**: 469 lines (Lua) + 184 lines (XML) = **653 lines total**
- **V2 Legacy**: ~180 lines (Lua) + ~140 lines (XML) = **~320 lines estimated**
- **Reduction**: ~51% (333 lines saved)

**Note**: XML is significantly shorter than V1 because:
- **No container wrapper** (saves ~40 lines)
  - Container template eliminated entirely
  - Border frame atlas moved to main frame as texture layer
  - Follows Flat Bar V2 pattern (single frame, no nesting)
- Container positioning logic removed (moved to LegacyPositionMixin)
- Text wiring removed (handled by TextMixin)
- Event scripts simplified (V2 contract methods only)

**Lua breakdown**:
- LegacyBarStyle.lua: ~150 lines (ApplyAnimationStep + GetAnimationConfig)
- LegacyPositionMixin.lua: ~30 lines (static positioning)
- V1 had 469 lines → V2 has 180 lines (62% reduction)

### Shared Code Reuse
- Event handling: BaseMixin (reused)
- Animation system: AnimationManager (reused)
- Context building: ContextBuilder (reused)
- Tooltip: TooltipMixin (reused)
- Text formatting: TextMixin (reused)
- Color management: PaintMixin (reused)
- Overlay positioning: LayoutMixin (reused)

### Maintenance Impact
- Single source of truth for animations (AnimationManager)
- Consistent timing across all styles (38 frames, 0.494s)
- Centralized bug fixes benefit all styles
- Easier to add new features (update mixins, not individual styles)

---

## Rollback Plan

If V2 Legacy has issues:
1. Keep V1 Legacy code intact during migration
2. Toggle back to V1 via config: `Addon.Config.barStyle = "legacy"` (V1)
3. V2 can be disabled without affecting V1
4. Full rollback: Remove V2 files, restore .toc/.xml includes

---

## Timeline

**Estimated Duration**: 2-3 days

### Day 1: Structure & Implementation
- [ ] Create directory structure
- [ ] Implement LegacyPositionMixin
- [ ] Implement LegacyBarStyle.lua
- [ ] Create LegacyBarTemplate.xml
- [ ] Update includes and .toc

### Day 2: Testing & Refinement
- [ ] Visual testing (side-by-side with V1)
- [ ] Animation testing (flash timing, smoothness)
- [ ] Positioning testing (anchoring, persistence)
- [ ] Options integration testing
- [ ] Bug fixes and polish

### Day 3: Validation & Documentation
- [ ] Complete validation checklist
- [ ] Performance testing
- [ ] Code review
- [ ] Update documentation
- [ ] Mark Phase 2 complete ✅

---

## Success Criteria

Phase 2 is complete when:
1. ✅ V2 Legacy Bar visually identical to V1
2. ✅ Animation timing matches V1 exactly (0.5s flash)
3. ✅ Static positioning works correctly (anchored to Blizzard bar)
4. ✅ All validation checklist items pass
5. ✅ No regressions compared to V1
6. ✅ Code reduction achieved (~50%)
7. ✅ Documentation updated

---

## Next Phase

After Phase 2 completion:
- **Phase 3**: Vertical Bar Migration (custom gravity animations)
- **Challenge**: First style with custom animations (Pattern 2: AnimationManager + OnUpdate)

---

**Prepared By**: XPBarEnhanced Development Team  
**Date**: November 7, 2025  
**Status**: Ready to begin implementation 🚀
