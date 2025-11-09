# Circular Bar V2 - Quick Implementation Checklist

**Purpose**: Quick reference for implementing Circular Bar V2 migration  
**Full Documentation**: See `CIRCULAR_V2_MIGRATION.md` for complete details  
**Date**: November 9, 2025

---

## Pre-Implementation Checklist

- [ ] Read `CIRCULAR_V2_MIGRATION.md` (full migration plan)
- [ ] Review `VERTICAL_V2_MIGRATION.md` (Pattern 2 animation reference)
- [ ] Review V1 Circular code (`ui/xpbar/styles/CircularXPBarMixin.lua`)
- [ ] Ensure Flat Bar V2 and Vertical Bar V2 are working
- [ ] Backup current state (git commit/branch)

---

## Implementation Steps

### Step 1: Create Directory Structure ☐

```powershell
mkdir "ui/xpbars/circular_v2"
cd "ui/xpbars/circular_v2"
```

Create files:
- `CircularBarStyle.lua`
- `CircularBarTemplate.xml`
- `_includes.xml` (optional, for organization)

---

### Step 2: CircularBarStyle.lua - Core Structure ☐

**Required Sections** (in order):

1. **Header & Dependencies**
   ```lua
   -- Dependency checks
   if not XPBarStyleBuilder or not XPBarMixinBase_v2 then
       error("CircularBarStyle: v2 core not loaded")
   end
   ```

2. **Constants**
   ```lua
   local RING_SEGMENTS = 60
   local RING_REST_SUBLEVEL = 1
   local RING_QUEST_SUBLEVEL = 2
   local CIRCULAR_BAR_STYLE = { ... }
   ```

3. **Style Template**
   ```lua
   local CircularBarStyleTemplate = {}
   ```

4. **V2 Contract Methods** (REQUIRED)
   - `AnimateBarPosition(stepContext)` ← Arc rendering
   - `AnimateBarEffect(stepContext)` ← Glow trigger
   - `GetAnimationConfig()` ← Config from database

5. **Custom Rendering Methods**
   - `CreateRingSegments()` ← 4 segment arrays
   - `PositionRingSegments()` ← Polar to Cartesian
   - `RotateTexture(texture, rotation)` ← Segment rotation
   - `SetArcProgress(progress)` ← Show/hide segments
   - `UpdateRestedArc(currentXP, maxXP)` ← Rested overlay
   - `UpdateQuestArc(layout)` ← Quest overlays
   - `ComputeQuestSegmentRanges(layout)` ← Circular algorithm

6. **Animation Methods**
   - `PlayGlowPulse()` ← 3-phase glow animation
   - `StopGlowAnimation()` ← Cleanup

7. **Lifecycle Methods**
   - `OnLoad()` ← Initialization
   - `OnHide()` ← Cleanup

8. **Override Methods**
   - `SetDisplayValue(ratio)` ← Instant update
   - `ActionUpdateVisuals(context)` ← Store layout

9. **Center Content**
   - `SetupCenterContent()` ← Portrait + text

10. **Config & Registration**
    ```lua
    local DefaultConfig = { ... }
    CircularBarXPBarMixin = XPBarStyleBuilder:Create(...)
    XPBarStyleBuilder:RegisterStyle("circular", CircularBarXPBarMixin)
    ```

---

### Step 3: CircularBarTemplate.xml ☐

**Minimal Structure**:
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="CircularBarStyle.lua"/>
    
    <Frame name="CircularBarTemplate_v2" mixin="CircularBarXPBarMixin" virtual="true">
        <Size x="256" y="256"/>
        <Scripts>
            <OnLoad method="OnLoad"/>
            <OnHide method="OnHide"/>
        </Scripts>
    </Frame>
</Ui>
```

**Note**: All visual elements created in Lua (segments, glow, center content).

---

### Step 4: Integration ☐

**Update XPBarEnhanced.toc**:
```
# Add after other V2 styles
ui\xpbars\circular_v2\CircularBarStyle.lua
ui\xpbars\circular_v2\CircularBarTemplate.xml
```

**Update Frames.xml**:
```xml
<Include file="ui\xpbars\circular_v2\CircularBarTemplate.xml"/>
```

---

### Step 5: Testing ☐

**In-Game Test Commands**:
```lua
-- Create test frame
/run _G.TestCircular = XPBarStyleBuilder:CreateFrameForStyle("circular", nil, "CircularBarTemplate_v2"); TestCircular:Show()

-- Test arc rendering
/run TestCircular:SetArcProgress(0.5)  -- 50%
/run TestCircular:SetArcProgress(1)    -- 100%
/run TestCircular:SetArcProgress(0)    -- Empty

-- Test glow
/run TestCircular:PlayGlowPulse()

-- Test cleanup
/run TestCircular:Hide(); TestCircular:Show()
```

---

## Critical Implementation Details

### Ring Segment Creation

**4 Arrays Total** (60 segments each):
1. `self.segments[]` - XP fill (ARTWORK)
2. `self.restedSegments[]` - Rested overlay (ARTWORK sublevel 1)
3. `self.questCompleteSegments[]` - Quest complete (ARTWORK sublevel 2)
4. `self.questIncompleteSegments[]` - Quest incomplete (ARTWORK sublevel 2)

**Total Textures**: 240 (60×4)

---

### Segment Positioning Algorithm

```lua
for i = 1, RING_SEGMENTS do
    -- Calculate angle (clockwise from 12 o'clock)
    local angle = (i - 1) * (360 / RING_SEGMENTS) - 90
    local rotation = math.rad(angle)
    
    -- Polar to Cartesian
    local xOff = RING_RADIUS_PX * math.cos(rotation)
    local yOff = RING_RADIUS_PX * math.sin(rotation)
    
    -- Position and rotate
    segment:SetPoint("CENTER", self, "CENTER", xOff, yOff)
    self:RotateTexture(segment, rotation)
end
```

**Critical**: All 4 segment arrays must be positioned identically.

---

### AnimateBarPosition (V2 Contract)

```lua
function CircularBarStyleTemplate:AnimateBarPosition(stepContext)
    -- Update arc fill
    self:SetArcProgress(stepContext.currentRatio)
    
    -- Update rested overlay
    if stepContext.xpContext then
        self:UpdateRestedArc(
            stepContext.xpContext.xpAfter,
            stepContext.xpContext.xpMax
        )
    end
    
    -- Update quest overlays
    if stepContext.layout then
        self:UpdateQuestArc(stepContext.layout)
    end
end
```

**Key**: AnimationManager provides `currentRatio` (0-1), we convert to segments.

---

### AnimateBarEffect (V2 Contract)

```lua
function CircularBarStyleTemplate:AnimateBarEffect(stepContext)
    if not self.GlowOverlay then
        return
    end
    
    local flashData = stepContext.flashData
    if flashData and flashData.active then
        -- Start glow on first flash frame
        if not self._glowAnimating and flashData.currentAlpha > 0 then
            self:PlayGlowPulse()
        end
    end
end
```

**Key**: Trigger glow once per XP gain, flag prevents multiple triggers.

---

### Glow Animation (3-Phase Ticker)

```lua
function CircularBarStyleTemplate:PlayGlowPulse()
    -- Cancel existing
    if self._glowAnimating then
        self:StopGlowAnimation()
    end
    
    -- Setup overlay
    self.GlowOverlay:SetAlpha(0)
    self.GlowOverlay:Show()
    
    local startTime = GetTime()
    self._glowAnimating = true
    
    -- OnUpdate driver
    self:SetScript("OnUpdate", function(frame, elapsed)
        local elapsed = GetTime() - startTime
        
        -- Phase 1: Fade in (0.2s)
        if elapsed < 0.2 then
            frame.GlowOverlay:SetAlpha((elapsed / 0.2) * 0.6)
        
        -- Phase 2: Hold (0.5s)
        elseif elapsed < 0.7 then
            frame.GlowOverlay:SetAlpha(0.6)
        
        -- Phase 3: Fade out (0.3s)
        elseif elapsed < 1.0 then
            local fadeProgress = (elapsed - 0.7) / 0.3
            frame.GlowOverlay:SetAlpha(0.6 * (1 - fadeProgress))
        
        -- Complete
        else
            frame:StopGlowAnimation()
        end
    end)
end
```

**Timing**: 0.2s + 0.5s + 0.3s = 1.0s total

---

### Quest Overlay Algorithm

```lua
function CircularBarStyleTemplate:ComputeQuestSegmentRanges(layout)
    local currentProgress = layout.current and layout.current.ratio or 0
    local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
    
    -- Calculate counts (force at least 1 if visible)
    local completeCount = layout.questComplete.visible 
        and math.max(1, math.floor(layout.questComplete.ratio * RING_SEGMENTS + 0.5)) 
        or 0
    
    local incompleteCount = layout.questIncomplete.visible
        and math.max(1, math.floor(layout.questIncomplete.ratio * RING_SEGMENTS + 0.5))
        or 0
    
    -- Clamp to avoid overflow
    if completeCount + incompleteCount > RING_SEGMENTS then
        incompleteCount = RING_SEGMENTS - completeCount
    end
    
    -- Build index arrays
    local completeIndices = {}
    for i = 1, completeCount do
        table.insert(completeIndices, currentSegment + i)
    end
    
    local incompleteIndices = {}
    for i = 1, incompleteCount do
        table.insert(incompleteIndices, currentSegment + completeCount + i)
    end
    
    return completeIndices, incompleteIndices
end
```

**Key**: Quest segments stack AFTER current XP, not overlaid.

---

## Common Pitfalls & Solutions

### Pitfall 1: Segments Not Visible
**Cause**: Not calling `PositionRingSegments()` after creation  
**Solution**: Call in `OnLoad()` after `CreateRingSegments()`

### Pitfall 2: Segments in Wrong Position
**Cause**: Angle calculation offset incorrect  
**Solution**: Use `-90` offset (12 o'clock = 270° in math coords)

### Pitfall 3: Glow Doesn't Stop
**Cause**: Missing cleanup in OnHide  
**Solution**: Call `StopGlowAnimation()` in `OnHide()`

### Pitfall 4: Multiple Glows Overlap
**Cause**: Not checking `_glowAnimating` flag  
**Solution**: Cancel previous glow before starting new one

### Pitfall 5: Quest Overlays Overflow
**Cause**: Not clamping total segment count  
**Solution**: Check `completeCount + incompleteCount > RING_SEGMENTS`, clamp

### Pitfall 6: Memory Leak
**Cause**: OnUpdate script not removed on hide  
**Solution**: Always `SetScript("OnUpdate", nil)` in cleanup

### Pitfall 7: Performance Issues
**Cause**: Updating all 240 segments every frame  
**Solution**: Only update changed segments (delta rendering)

---

## Performance Optimization Checklist

- [ ] Delta rendering (track `lastSegmentsShown`, only update changes)
- [ ] Batch Show/Hide calls (don't call 60 times individually)
- [ ] Profile with `/framestack` during animations
- [ ] Monitor FPS with `/fps` during busy scenes
- [ ] Test memory with `collectgarbage("count")` before/after animations
- [ ] Ensure OnUpdate scripts cleanup properly (no lingering)

---

## Validation Checklist (Quick)

### Visual ☐
- [ ] 60 segments visible, no gaps
- [ ] Arc starts at top (12 o'clock)
- [ ] Arc fills clockwise
- [ ] Colors match user settings

### Animation ☐
- [ ] Arc fill smooth
- [ ] Glow phases correct (fade in → hold → fade out)
- [ ] No flicker or jitter

### Performance ☐
- [ ] FPS ≥ 60 during animations
- [ ] Memory stable
- [ ] No lingering OnUpdate scripts

### Integration ☐
- [ ] Works with other bars
- [ ] Position saves/loads
- [ ] Drag-to-move works

---

## Debugging Commands

```lua
-- Check segment count
/run print("Segments:", #TestCircular.segments)

-- Check current progress
/run print("Progress:", TestCircular.lastProgress)

-- Check glow state
/run print("Glow animating:", TestCircular._glowAnimating)

-- Check OnUpdate script
/run print("OnUpdate:", TestCircular:GetScript("OnUpdate") and "ACTIVE" or "nil")

-- Force cleanup
/run TestCircular:StopGlowAnimation(); TestCircular:SetScript("OnUpdate", nil)

-- Memory check
/run print("Memory (KB):", collectgarbage("count"))
```

---

**Reference Files**

**V1 Circular Bar**: `ui/xpbar/styles/CircularXPBarMixin.lua` (962 LOC)  
**V2 Flat Bar**: `ui/xpbars/flatbar_v2/FlatBarStyle.lua` (225 LOC) ✅  
**V2 Legacy Bar**: `ui/xpbars/legacy_v2/LegacyBarStyle.lua` (192 LOC) ✅  
**V2 Vertical Bar**: `ui/xpbars/vertical_v2/VerticalBarStyle.lua` (380 LOC) ✅  

**Key Patterns**:
- Flat: Pattern 1 (AnimationManager only) ✅
- Legacy: Pattern 1 (AnimationManager only, static positioning) ✅
- Vertical: Pattern 2 (AnimationManager + Custom OnUpdate) ✅
- Circular: Pattern 3 (AnimationManager + OnUpdate + Ticker)

---

## Completion Criteria

### Code Complete ☐
- [ ] All methods implemented
- [ ] No TODOs or placeholders
- [ ] Comments for complex algorithms
- [ ] Error handling for edge cases

### Integration Complete ☐
- [ ] TOC updated
- [ ] Frames.xml updated
- [ ] Style registered with StyleBuilder

### Testing Complete ☐
- [ ] Visual validation passed
- [ ] Animation validation passed
- [ ] Performance validation passed
- [ ] Integration validation passed

### Documentation Complete ☐
- [ ] Code comments added
- [ ] Known issues documented
- [ ] Testing results recorded

---

## Next Steps After Complete

1. **Update V2_MIGRATION_SUMMARY.md** - Mark Circular complete
2. **Begin Phase 5** - V1 cleanup and removal
3. **Update ARCHITECTURE_V2.md** - Add Circular Bar examples
4. **Performance optimization** - Delta rendering, texture pooling

---

## Estimated Timeline

- **Day 1-3**: Core implementation (segments, rendering, animations)
- **Day 4-5**: Animation integration (AnimateBarPosition, AnimateBarEffect, glow)
- **Day 6-7**: Testing and bug fixes
- **Day 8-9**: Performance optimization
- **Day 10-11**: Integration testing and edge cases
- **Day 12**: Final polish and documentation

**Total**: 12 days (as estimated in full migration plan)

---

**Quick Checklist Status**: Ready for Implementation ✅  
**Full Documentation**: `CIRCULAR_V2_MIGRATION.md`  
**Last Updated**: November 9, 2025
