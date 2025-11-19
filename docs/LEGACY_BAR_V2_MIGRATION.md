# Classic Bar  Migration Plan

**Date**: November 7, 2025  
**Phase**: Phase 2 - Classic Bar Migration  
**Status**: ✅ IMPLEMENTATION COMPLETE

**Implementation Details**:
- Files: `ui/xpbars/classic/ClassicBarStyle.lua` (192 LOC), `ClassicBarTemplate.xml` (233 LOC)
- Integration: XML includes Lua via `<Script file="ClassicBarStyle.lua"/>`, XML in TOC
- Registration: Style key `"classic"` registered with StyleBuilder
- Code Reduction: -59% (469 → 192 LOC)

---

## Migration Overview

### Objective
Port the Classic Bar (Blizzard-style) from V1 architecture to  mixin-based composition system.

### Why Classic Bar First?
- Simplest style after Flat Bar (no custom animations)
- **Static positioning** (different from Flat Bar's draggable system)
- Uses standard AnimationManager (no custom animation code needed)
- Good test of  architecture with different positioning strategy

### Key Differences from Flat Bar 
| Aspect | Flat Bar  | Classic Bar  |
|--------|-------------|---------------|
| **Positioning** | Draggable (PositionMixin) | Static (anchored to Blizzard bar) |
| **Size** | Fixed 565x11 | Fixed 565x11 (matches Blizzard) |
| **Animations** | AnimationManager | AnimationManager (same) |
| **Textures** | Solid colors | Solid colors (atlas removed in V1) |
| **Container** | Simple Frame | ClassicXPBarContainerMixin (positioning logic) |

---

## V1 Classic Bar Analysis

### File Structure (Current V1)
```
ui/xpbar/styles/
├── ClassicXPBarMixin.lua (469 lines)
│   ├── ExhaustionTickMixin (~15 lines)
│   ├── ClassicXPBarContainerMixin (~100 lines) - Positioning logic
│   └── ClassicXPBarMixin (~354 lines) - Bar implementation
└── ClassicXPBar.xml (184 lines)
    ├── ClassicXPBarTemplate (main bar)
    ├── ClassicXPBarContainerTemplate (container with border)
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
   - `ClassicXPBarContainerMixin` handles positioning
   - Wire up text elements from OverlayFrame
   - Below-bar text containers (rate, session, quest summary)

4. **Standard Overlays**
   - Rested: `ExhaustionLevelFillBar` (solid texture, customizable color)
   - Quest Complete: `QuestOverlayComplete` (solid texture, customizable color)
   - Quest Incomplete: `QuestOverlayIncomplete` (solid texture, customizable color)
   - Exhaustion Tick: `ExhaustionTick` (atlas-based marker)

5. **Animation (V1 Classic)**
   - Uses XPBarMixinBase animation system
   - Flash on XP gain (customizable color)
   - Value smoothing via StatusBar

### Code That Will Be Removed (V1 → )
- ❌ Event handling (handled by BaseMixin)
- ❌ Animation logic (handled by AnimationManager)
- ❌ Tooltip management (handled by TooltipMixin)
- ❌ Color update methods (handled by PaintMixin)
- ❌ Text formatting (handled by TextMixin)
- ❌ State calculations (handled by ContextBuilder)

### Code That Will Be Retained (V1 → )
- ✅ Static positioning logic (`PositionToMatchBlizzardBar`)
- ✅ Container initialization (`OnLoad`, retry timer)
- ✅ Text element wiring (`WireTextElements`)
- ✅ `ApplyAnimationStep` implementation ( contract)
- ✅ XML visual structure (with minor adjustments)

---

##  Architecture Plan

### Directory Structure (New)
```
ui/xpbars/classic/
├── ClassicBarStyle.lua (~150 lines estimated)
│   ├── Style configuration
│   ├── Positioning methods (static, non-draggable)
│   ├── ApplyAnimationStep implementation
│   └── StyleBuilder registration
├── ClassicBarTemplate.xml (~180 lines)
│   ├── ClassicBarTemplate (main bar frame)
│   └── Visual layers (StatusBar, overlays, text)
└── _includes.xml (2 lines)
    └── References to Lua and XML
```

### Mixin Composition
```lua
-- ClassicBarStyle uses:
XPBarMixinBase        -- Event orchestration, Trigger/Action methods
+ InteractionMixin       -- Mouse handling (Alt+Click, Ctrl+Click)
+ LayoutMixin            -- Overlay positioning (standard algorithms)
+ PaintMixin             -- Color application
+ PositionMixin          -- Positioning (static mode: isDraggable=false)
+ TextMixin              -- Text formatting, real-time updates
+ TooltipMixin           -- Tooltip management
+ VisualsMixin           -- Visual element orchestration
+ ClassicBarStyleTemplate -- Style-specific implementation
```

**Note on Positioning**: 
- Classic Bar uses the same `PositionMixin` as Flat Bar
- Static positioning achieved via `isDraggable = false` config
- PositionMixin already supports both draggable and static modes
- No custom positioning mixin needed

---

## Implementation Steps

### Step 1: Create Directory Structure ⏳
```bash
mkdir ui/xpbars/classic
```

Files to create:
- `ClassicBarStyle.lua` - Main style implementation
- `ClassicBarTemplate.xml` - Visual structure
- `_includes.xml` - File references

### Step 2: Implement ClassicBarStyle.lua ⏳

**Structure**:
```lua
-- Header: Dependencies check
-- Debug system (optional, for development)
-- ClassicBarStyleTemplate:
--   - ApplyAnimationStep(stepContext) - StatusBar + Flash
--   - GetAnimationConfig() - Animation settings
--   - (Optional) Override action methods if needed
-- Style configuration table
-- StyleBuilder.RegisterStyle() call
```

**Key Method**: `ApplyAnimationStep`
```lua
function ClassicBarStyleTemplate:ApplyAnimationStep(stepContext)
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

### Step 3: Create ClassicBarTemplate.xml ⏳

**Based on**: V1 `ClassicXPBar.xml` with  simplification (following FlatBarTemplate pattern)

**Key Design Decision: Eliminate Container Completely**

After analyzing Flat Bar 's structure, we can place the border frame atlas directly on the main frame as a texture layer, eliminating the container wrapper entirely.

**V1 Classic Structure**:
```
ClassicXPBarContainerTemplate (571x17)
├── Border frame atlas (OVERLAY layer)
└── ClassicXPBarTemplate (565x11, offset 1,5 inside container)
    └── StatusBar (565x10)
        └── ExhaustionTick (Button, 10x14)
```

** Classic Structure** (No Container):
```
ClassicBarTemplate (571x17) - single frame, no nesting!
├── Border frame atlas (OVERLAY layer - same as V1)
├── Flash overlay (OVERLAY layer)
├── StatusBar (565x11, offset 1,5 inside frame) - V1 size
│   ├── Background atlas (UI-HUD-ExperienceBar-Fill)
│   ├── Rested overlay (solid texture)
│   ├── Quest overlays (solid textures)
│   └── ExhaustionTick (Button, 10x14) - atlas-based marker
├── OverlayFrameTextContainer (on-bar text)
└── BelowBarTextContainer (below-bar text)
```
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
   - V1: `ClassicXPBarContainerTemplate` wraps `ClassicXPBarTemplate` (nested)
   - : Single `ClassicBarTemplate` frame (flat, like FlatBarTemplate)
   - Border frame atlas is just a texture layer on main frame

2. **Frame size includes border space** (V1 dimensions preserved)
   - Frame: 571x17 (accommodates border)
   - StatusBar: 565x11 (V1 bar size - matches original exactly)
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

4. **StatusBar texture uses atlas** (V1 approach, not solid color)
   ```xml
   <StatusBar parentKey="StatusBar">
       <BarTexture atlas="UI-HUD-ExperienceBar-Fill" useAtlasSize="false"/>
   </StatusBar>
   ```

5. **ExhaustionTick included** (V1 structure preserved)
   - Button element inside StatusBar (V1 structure)
   - Size: 10x14 (V1 size)
   - Anchored to rested overlay right edge
   - Normal + Highlight textures (atlas-based)
   - Uses ExhaustionTickMixin for tooltip

6. **Positioning via PositionMixin** (static mode)
   - `isDraggable = false` in style config
   - PositionMixin handles both static and draggable modes
   - No custom positioning mixin needed

7. **Mixin declaration**:  composition pattern
   ```xml
   <Frame name="ClassicBarTemplate" virtual="true" 
          mixin="ClassicBarStyleTemplate"
          frameStrata="LOW" enableMouse="true">
   ```

8. **Simplified scripts**: Only  contract methods
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
<Frame name="ClassicBarTemplate" virtual="true" mixin="ClassicBarStyleTemplate" 
       frameStrata="LOW" enableMouse="true" fixedFrameStrata="true">
    <Size x="571" y="17"/>
    <Layers>
        <!-- Border frame atlas - on main frame, not container -->
        <Layer level="OVERLAY">
            <Texture parentKey="BorderFrame" atlas="UI-HUD-ExperienceBar-Frame" 
                     useAtlasSize="true"/>
        </Layer>
        
        <!-- Flash overlay (covers StatusBar area, V1 match) -->
        <Layer level="OVERLAY" textureSubLevel="3">
            <Texture parentKey="GainFlash" hidden="true">
                <Anchors>
                    <Anchor point="TOPLEFT" x="1" y="-6"/>
                    <Anchor point="BOTTOMRIGHT" x="-5" y="5"/>
                </Anchors>
            </Texture>
        </Layer>
    </Layers>
    <Frames>
        <!-- StatusBar offset inside frame to accommodate border (V1 size: 565x11) -->
        <StatusBar parentKey="StatusBar" minValue="0" maxValue="1" defaultValue="0">
            <Size x="565" y="11"/>
            <Anchors>
                <Anchor point="BOTTOMLEFT" x="1" y="5"/>
            </Anchors>
            <!-- StatusBar texture: atlas (V1 approach) -->
            <BarTexture atlas="UI-HUD-ExperienceBar-Fill" useAtlasSize="false"/>
            
            <Layers>
                <!-- Rested overlay -->
                <Layer level="ARTWORK" textureSubLevel="1">
                    <Texture parentKey="ExhaustionLevelFillBar" hidden="true" 
                             file="Interface\Buttons\WHITE8X8">
                        <Anchors>
                            <Anchor point="TOPLEFT"/>
                            <Anchor point="BOTTOMLEFT"/>
                        </Anchors>
                    </Texture>
                </Layer>
                
                <!-- Quest overlays (complete + incomplete) -->
                <Layer level="ARTWORK" textureSubLevel="2">
                    <Texture parentKey="QuestOverlayComplete" hidden="true" 
                             file="Interface\Buttons\WHITE8X8">
                        <Anchors>
                            <Anchor point="TOPLEFT"/>
                            <Anchor point="BOTTOMLEFT"/>
                        </Anchors>
                    </Texture>
                </Layer>
                
                <Layer level="ARTWORK" textureSubLevel="3">
                    <Texture parentKey="QuestOverlayIncomplete" hidden="true" 
                             file="Interface\Buttons\WHITE8X8">
                        <Anchors>
                            <Anchor point="TOPLEFT"/>
                            <Anchor point="BOTTOMLEFT"/>
                        </Anchors>
                    </Texture>
                </Layer>
            </Layers>
            
            <Frames>
                <!-- Exhaustion Tick (rested XP marker) - V1 structure preserved -->
                <Button parentKey="ExhaustionTick" hidden="true" frameStrata="MEDIUM" 
                        mixin="ExhaustionTickMixin">
                    <Size x="10" y="14"/>
                    <Anchors>
                        <Anchor point="CENTER" relativeKey="$parent.ExhaustionLevelFillBar" 
                                relativePoint="RIGHT"/>
                    </Anchors>
                    <NormalTexture parentKey="Normal" atlas="UI-HUD-ExperienceBar-Frame-Pip"/>
                    <HighlightTexture parentKey="Highlight" 
                                     atlas="UI-HUD-ExperienceBar-Frame-Pip-Mouseover" 
                                     alphaMode="ADD"/>
                    <Scripts>
                        <OnEnter method="OnEnter"/>
                        <OnLeave function="GameTooltip_Hide"/>
                    </Scripts>
                </Button>
            </Frames>
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
- ✅ StatusBar size 565x11 matches V1 exactly
- ✅ StatusBar uses atlas texture `UI-HUD-ExperienceBar-Fill` (V1 approach)
- ✅ ExhaustionTick included with V1 structure (Button inside StatusBar)
- ✅ Frame size (571x17) includes border space (same as V1)
- ✅ No functional loss - positioning via PositionMixin (static mode)
- ✅ Consistent with Flat Bar  pattern (no container nesting)
- ✅ Simpler XML structure (~140 lines vs V1's 184 lines)

### Step 4: Register with StyleBuilder ⏳

**In ClassicBarStyle.lua**:
```lua
XPBarStyleBuilder.RegisterStyle("classic", {
    template = "ClassicBarTemplate",
    displayName = "Classic (Blizzard-style)",
    description = "Classic Blizzard experience bar style",
    mixins = {
        XPBarMixinBase,
        XPBarInteractionMixin,
        XPBarLayoutMixin,
        XPBarPaintMixin,
        XPBarPositionMixin,      -- Static mode (isDraggable=false)
        XPBarTextMixin,
        XPBarTooltipMixin,
        XPBarVisualsMixin,
        ClassicBarStyleTemplate
    },
    config = {
        isDraggable = false,      -- IMPORTANT: Static positioning (anchored to Blizzard bar)
        savePosition = false,     -- No position persistence needed
        defaultSize = { width = 565, height = 11 },
        animations = {
            enabled = true,
            flashOnGain = true
        }
    }
})
```

### Step 5: Update Includes ⏳

**In main `Frames.xml`**:
```xml
<!--  Classic Bar -->
<Include file="ui\xpbars\classic\_includes.xml"/>
```

**Create `ui/xpbars/classic/_includes.xml`**:
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="ClassicBarStyle.lua"/>
    <Include file="ClassicBarTemplate.xml"/>
</Ui>
```

### Step 6: Update .toc File ⏳

Add after Flat Bar  includes:
```toc
# Classic Bar 
ui\xpbars\classic\_includes.xml
```

**Note**: No custom positioning mixin needed - PositionMixin handles static mode via `isDraggable=false`

---

## Testing Checklist

### Visual Elements
- [ ] StatusBar renders correctly with atlas texture (UI-HUD-ExperienceBar-Fill)
- [ ] StatusBar size matches V1 (565x11)
- [ ] Border frame atlas visible (UI-HUD-ExperienceBar-Frame)
- [ ] Rested overlay positioned correctly (after current XP)
- [ ] Quest complete overlay visible when quests ready
- [ ] Quest incomplete overlay visible with incomplete quest progress
- [ ] Exhaustion tick positioned at rested XP end (Button, 10x14)
- [ ] Exhaustion tick tooltip works on hover
- [ ] Flash overlay covers StatusBar area correctly

### Positioning
- [ ] Bar anchored to Blizzard's MainStatusTrackingBarContainer
- [ ] Position matches V1 Classic bar exactly (TOP anchor, 0, 5 offset)
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
1. Enable both V1 Classic and  Classic (temporary dual-load)
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
- ✅ No -specific bugs or artifacts
- ✅ Performance equal or better

---

## Migration Benefits

### Code Reduction
- **V1 Classic**: 469 lines (Lua) + 184 lines (XML) = **653 lines total**
- ** Classic**: ~180 lines (Lua) + ~140 lines (XML) = **~320 lines estimated**
- **Reduction**: ~51% (333 lines saved)

**Note**: XML is significantly shorter than V1 because:
- **No container wrapper** (saves ~40 lines)
  - Container template eliminated entirely
  - Border frame atlas moved to main frame as texture layer
  - Follows Flat Bar  pattern (single frame, no nesting)
- Container positioning logic removed (moved to ClassicPositionMixin)
- Text wiring removed (handled by TextMixin)
- Event scripts simplified ( contract methods only)

**Lua breakdown**:
- ClassicBarStyle.lua: ~150 lines (ApplyAnimationStep + GetAnimationConfig)
- ClassicPositionMixin.lua: ~30 lines (static positioning)
- V1 had 469 lines →  has 180 lines (62% reduction)

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

If  Classic has issues:
1. Keep V1 Classic code intact during migration
2. Toggle back to V1 via config: `Addon.Config.barStyle = "classic"` (V1)
3.  can be disabled without affecting V1
4. Full rollback: Remove  files, restore .toc/.xml includes

---

## Timeline

**Estimated Duration**: 2-3 days

### Day 1: Structure & Implementation
- [ ] Create directory structure
- [ ] Implement ClassicBarStyle.lua
- [ ] Create ClassicBarTemplate.xml (with ExhaustionTick)
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
1. ✅  Classic Bar visually identical to V1
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
