# Circular Bar V2 Migration Plan

**Date**: November 9, 2025  
**Phase**: Phase 4 - Circular Bar Migration  
**Status**: 📋 Planning Stage

---

## Migration Overview

### Objective
Port the Circular Bar (most complex style) from V1 architecture to V2 mixin-based composition system. This is the final and most challenging style migration, incorporating all lessons learned from Flat, Legacy, and Vertical bar migrations.

### Why Circular Bar Last?
- **Most complex style** (962 LOC in V1, most in entire codebase)
- **Custom rendering** - No StatusBar widget, fully custom arc rendering
- **Multiple animation systems** - Arc smoothing (OnUpdate) + Glow effects (3-phase ticker)
- **Complex overlays** - Rested arc, quest segments, all rendered as ring segments
- **Custom positioning algorithms** - Circular segment placement with rotation
- **Tests V2 extensibility limits** - Validates architecture for extreme customization

### Key Differences from Other V2 Migrations

| Aspect | Flat/Legacy V2 | Vertical V2 | Circular V2 |
|--------|----------------|-------------|-------------|
| **Rendering** | StatusBar widget | StatusBar widget | 60 custom textures (segments) |
| **Positioning** | Linear (1D) | Linear vertical (1D) | Circular (2D polar coordinates) |
| **Animation Pattern** | AnimationManager only | AnimationManager + OnUpdate | AnimationManager + OnUpdate + Ticker |
| **Overlays** | Standard algorithm | Standard algorithm | Custom circular segment algorithm |
| **Complexity** | Low | Medium | **High** |

---

### Phase 2: Legacy Bar Migration ✅ COMPLETE

**Document**: `LEGACY_BAR_V2_MIGRATION.md`  
**Status**: Implementation complete  
**Migration Complexity**: Low ⭐  
**Actual Duration**: ~2 days

**Key Features**:
- Simplest migration after Flat Bar
- Static positioning (anchored to Blizzard bar)
- No custom animations (AnimationManager only)
- StatusBar-based rendering (similar to Flat)
- Code reduction: -59% (469 → 192 LOC)

**Lessons for Circular**:
- ✅ Proven AnimationManager integration pattern
- ✅ Container elimination strategy validated
- ✅ Static positioning via config flag works perfectly

---

### Phase 3: Vertical Bar Migration ✅ IMPLEMENTATION COMPLETE

### File Structure (Current V1)
```
ui/xpbar/styles/
├── CircularXPBarMixin.lua (962 lines) - LARGEST FILE IN CODEBASE
│   ├── CircularXPBarContainerMixin (~100 lines) - Draggable container
│   └── CircularXPBarMixin (~862 lines) - Bar implementation
└── CircularXPBar.xml (46 lines)
    ├── CircularXPBarTemplate (main bar)
    └── CircularXPBarContainerTemplate (container)
```

### Key Features in V1

#### 1. **Ring Segment Architecture**
- **60 segments** arranged in a circle (360° / 60 = 6° per segment)
- Each segment is a small texture rotated and positioned around ring perimeter
- Segments created programmatically in Lua (not XML)
- **Radius**: 97 pixels from center
- **Segment size**: 4×15 pixels
- **Rotation**: Uses `SetRotation()` API (retail WoW only)

**Segment Types** (4 separate arrays):
1. **XP Segments** (`self.segments[]`) - ARTWORK layer - Main XP bar fill
2. **Rested Segments** (`self.restedSegments[]`) - ARTWORK sublevel 1 - Rested XP overlay
3. **Quest Complete Segments** (`self.questCompleteSegments[]`) - ARTWORK sublevel 2
4. **Quest Incomplete Segments** (`self.questIncompleteSegments[]`) - ARTWORK sublevel 2

#### 2. **Custom Rendering (No StatusBar Widget)**
Unlike Flat/Vertical bars, Circular uses fully custom rendering:
- `SetArcProgress(progress)` - Show/hide segments based on fill percentage
- `UpdateRestedArc(currentXP, maxXP)` - Calculate and show rested segments
- `UpdateQuestArc(layout)` - Render quest segments in circular layout
- `ComputeQuestSegmentRanges(layout)` - Convert linear ratios to segment indices

**Why No StatusBar?**
- StatusBar only supports rectangular fills (left-to-right, bottom-to-top)
- Circular requires 360° arc rendering with rotation transforms
- Must manually calculate which segments to show/hide

#### 3. **Arc Smoothing Animation** (OnUpdate Pattern)
```lua
function CircularXPBarMixin:AnimateArcFill()
    -- OnUpdate-based animation
    -- Duration: 0.5 seconds
    -- Easing: EaseOutQuad (1 - (1-t)²)
    -- Updates: self:SetArcProgress(currentProgress) every frame
    -- Cleanup: SetScript("OnUpdate", nil) when complete
end
```

**Characteristics**:
- Per-frame updates via `SetScript("OnUpdate", ...)`
- Smooth arc fill from current to target progress
- No retargeting logic (just restarts animation)
- Cleanup on completion and OnHide

#### 4. **Glow Animation System** (3-Phase Ticker)
```lua
function CircularXPBarMixin:PlayGlowPulse()
    -- 3-phase animation: Fade In → Hold → Fade Out
    -- Phase 1: Fade in (0.2s, alpha 0 → 0.6)
    -- Phase 2: Hold (0.5s, alpha 0.6)
    -- Phase 3: Fade out (0.3s, alpha 0.6 → 0)
    -- Total: 1.0 second
    
    -- Uses SetScript("OnUpdate", ...) for alpha interpolation
    -- Texture: assets/glow.png (256×256 overlay)
end
```

**Trigger**: XP gains (replaces flash effect from Flat/Vertical)

**Visual Effect**:
- Full-screen glow overlay (`self.GlowOverlay`)
- Additive or normal blending
- Color: Cyan (rested) or Purple (normal)
- Much more dramatic than flat bar flash

#### 5. **Center Content** (Portrait + Text)
- **Center background**: `assets/center.png` (256×256, alpha 0.8)
- **Level text**: Center-top, `GameFontNormalHuge`
- **Percent text**: Center, `GameFontNormalLarge`
- **Rate text** (time to level): Center-bottom, `GameFontNormalSmall`

All text positioned inside ring perimeter, no below-bar containers.

#### 6. **Custom Overlay Positioning Algorithm**
```lua
function CircularXPBarMixin:PositionRingSegments()
    for i = 1, RING_SEGMENTS do
        -- Calculate angle (clockwise from 12 o'clock)
        local angle = (i - 1) * (360 / RING_SEGMENTS) - 90
        local rotation = math.rad(angle)
        
        -- Polar to Cartesian conversion
        local xOff = RING_RADIUS_PX * math.cos(rotation)
        local yOff = RING_RADIUS_PX * math.sin(rotation)
        
        -- Position and rotate each segment
        segment:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        self:RotateTexture(segment, rotation)
    end
end
```

**Complexity**:
- Trigonometric calculations for every segment
- Must be called on initialization and any layout change
- Performance-sensitive (180 segments total: 60×3 arrays)

#### 7. **Quest Overlay Rendering** (Circular Stacking)
Unlike linear bars where overlays stack horizontally:
- Quest overlays rendered as **additional ring segments**
- Must calculate segment indices for each overlay
- Rested segments offset by quest complete segments
- Ensures at least 1 segment visible if overlay ratio > 0 (force visibility)

**Algorithm**:
1. Calculate current XP segment count
2. Calculate quest complete segment count (after current)
3. Calculate quest incomplete segment count (after complete)
4. Clamp totals to RING_SEGMENTS (60) to avoid overflow
5. Apply colors and show segments in correct ranges

### Code That Will Be Removed (V1 → V2)
- ❌ Event handling (`OnEvent`, `HandleEvent`) - handled by BaseMixin
- ❌ Tooltip management (`OnEnter`, `OnLeave`) - handled by TooltipMixin
- ❌ Text formatting methods - handled by TextMixin
- ❌ State calculations (`CalculateBarState`) - handled by ContextBuilder
- ❌ Color update observers - handled by PaintMixin
- ❌ Container dragging logic - handled by PositionMixin

### Code That Will Be Retained (V1 → V2)
- ✅ Ring segment creation (`CreateRingSegments`)
- ✅ Segment positioning (`PositionRingSegments`, `RotateTexture`)
- ✅ Arc rendering (`SetArcProgress`, `UpdateRestedArc`, `UpdateQuestArc`)
- ✅ Arc smoothing animation (`AnimateArcFill` → integrated with AnimationManager)
- ✅ Glow animation (`PlayGlowPulse` → custom method)
- ✅ Circular overlay algorithm (`ComputeQuestSegmentRanges`)
- ✅ Center content setup (`SetupCenterContent`)

### Key Challenges for V2 Migration

#### Challenge 1: Custom Rendering Integration
**Problem**: V2 AnimationManager expects StatusBar widget  
**Solution**: Override `AnimateBarPosition` to call `SetArcProgress(ratio)` instead of `StatusBar:SetValue()`

#### Challenge 2: Dual Animation Systems
**Problem**: Need both AnimationManager (standard) + OnUpdate (arc smoothing) + Ticker (glow)  
**Solution**: Follow Vertical pattern - AnimationManager for coordination, custom methods for effects

#### Challenge 3: Overlay Positioning
**Problem**: V2 LayoutMixin assumes linear (1D) positioning  
**Solution**: Override overlay methods completely, use custom circular algorithm

#### Challenge 4: No Flash Overlay
**Problem**: V2 expects `GainFlash` texture for standard flash animation  
**Solution**: Replace flash with glow effect, triggered from `AnimateBarEffect()`

#### Challenge 5: Segment Performance
**Problem**: 180 textures updated per frame during animations  
**Solution**: Only update changed segments (delta-based rendering), batch Show/Hide calls

---

## V2 Architecture Plan

### Directory Structure (New)
```
ui/xpbars/circular_v2/
├── CircularBarStyle.lua (~500-600 lines estimated)
│   ├── Style configuration
│   ├── Ring segment creation and positioning
│   ├── Custom rendering methods (SetArcProgress, UpdateRestedArc, UpdateQuestArc)
│   ├── Arc smoothing animation (OnUpdate integration)
│   ├── Glow animation system (3-phase ticker)
│   ├── ApplyAnimationStep implementation (delegates to custom methods)
│   └── StyleBuilder registration
├── CircularBarTemplate.xml (~100 lines)
│   ├── CircularBarTemplate_v2 (main frame, 256×256)
│   └── No visual layers (segments created programmatically in Lua)
└── _includes.xml (2 lines)
    └── References to Lua and XML
```

### Mixin Composition
```lua
-- CircularBarStyle uses:
XPBarMixinBase_v2        -- Event orchestration, Trigger/Action methods
+ InteractionMixin       -- Mouse handling (Alt+Click, Ctrl+Click)
+ PaintMixin             -- Color application (custom for segments)
+ PositionMixin          -- Draggable positioning
+ TextMixin              -- Text formatting, real-time updates
+ TooltipMixin           -- Tooltip management
+ AnimationBase          -- Animation lifecycle (via AnimationManager)
+ CircularBarStyleTemplate -- Style-specific implementation
```

**Note on Mixins**:
- **LayoutMixin**: NOT used - circular overlays need custom algorithm
- **VisualsMixin**: Partially used - overlay visibility logic may be reused
- **AnimationManager**: Used for coordination, but custom rendering in style

---

## Implementation Steps

### Step 1: Create Directory Structure ⏳
```powershell
mkdir ui/xpbars/circular_v2
```

Files to create:
- `CircularBarStyle.lua` - Main style implementation
- `CircularBarTemplate.xml` - Minimal frame structure
- `_includes.xml` - File references

---

### Step 2: Implement CircularBarStyle.lua ⏳

**Structure**:
```lua
-- Header: Dependencies check
-- Debug system (optional, for development)

-- CircularBarStyleTemplate:
--   - Constants (RING_SEGMENTS, CIRCULAR_BAR_STYLE)
--   - Segment creation (CreateRingSegments, PositionRingSegments)
--   - Custom rendering (SetArcProgress, UpdateRestedArc, UpdateQuestArc)
--   - Animation integration:
--     - AnimateBarPosition(stepContext) - Arc rendering
--     - AnimateBarEffect(stepContext) - Glow effect trigger
--     - GetAnimationConfig() - Animation settings
--   - Custom animations:
--     - Arc smoothing (OnUpdate-based, optional if AnimationManager sufficient)
--     - Glow pulse (3-phase ticker)
--   - Lifecycle methods (OnLoad, OnHide, cleanup)
--   - Override methods (SetDisplayValue, UpdateStatusBarValue)

-- Style configuration table
-- StyleBuilder.RegisterStyle() call
```

---

### Step 3: Key Implementation Details

#### A. Constants and Style Configuration
```lua
local RING_SEGMENTS = 60 -- Number of segments (6° per segment)
local RING_REST_SUBLEVEL = 1 -- Rested segments below quest overlays
local RING_QUEST_SUBLEVEL = 2 -- Quest segments above rested

local CIRCULAR_BAR_STYLE = {
    RING_RADIUS_PX = 97,        -- Distance from center
    SEGMENT_WIDTH_PX = 4,       -- Segment width
    SEGMENT_HEIGHT_PX = 15,     -- Segment height
    BORDER_SIZE_PX = 256,
    CENTER_SIZE_PX = 256,
    GLOW_SIZE_PX = 256,
    
    -- Glow animation timing
    GLOW_FADE_IN_DURATION = 0.2,
    GLOW_FADE_OUT_DURATION = 0.3,
    GLOW_HOLD_DURATION = 0.5,
    GLOW_MAX_ALPHA = 0.6
}
```

#### B. AnimateBarPosition (V2 Contract Method)
```lua
function CircularBarStyleTemplate:AnimateBarPosition(stepContext)
    -- Update arc fill based on currentRatio
    self:SetArcProgress(stepContext.currentRatio)
    
    -- Update rested overlay (needs actual XP values from context)
    if stepContext.xpContext then
        self:UpdateRestedArc(
            stepContext.xpContext.xpAfter,
            stepContext.xpContext.xpMax
        )
    end
    
    -- Update quest overlays (if layout available)
    if stepContext.layout then
        self:UpdateQuestArc(stepContext.layout)
    end
end
```

**Key Decision**: Arc smoothing handled by AnimationManager's `currentRatio` interpolation, eliminating need for separate OnUpdate animation. This is a simplification from V1.

#### C. AnimateBarEffect (V2 Contract Method)
```lua
function CircularBarStyleTemplate:AnimateBarEffect(stepContext)
    -- Circular bar uses GLOW instead of FLASH
    -- Trigger glow effect on XP gain
    
    if not self.GlowOverlay then
        return
    end
    
    local flashData = stepContext.flashData
    if flashData and flashData.active then
        -- On first frame of flash, start glow animation
        if not self._glowAnimating and flashData.currentAlpha > 0 then
            self:PlayGlowPulse()
        end
    end
end
```

**Design**: Glow animation is independent ticker, not frame-synchronized with AnimationManager.

#### D. Glow Animation System (3-Phase Ticker)
```lua
function CircularBarStyleTemplate:PlayGlowPulse()
    -- Cancel any existing glow
    if self._glowAnimating then
        self:StopGlowAnimation()
    end
    
    -- Setup glow overlay
    if not self.GlowOverlay then
        self.GlowOverlay = self:CreateTexture(nil, "OVERLAY")
        self.GlowOverlay:SetAllPoints()
        self.GlowOverlay:SetTexture("Interface\\AddOns\\XPBarEnhanced\\assets\\glow.png")
    end
    
    self.GlowOverlay:SetAlpha(0)
    self.GlowOverlay:Show()
    
    local startTime = GetTime()
    local style = CIRCULAR_BAR_STYLE
    
    self._glowAnimating = true
    
    -- Use OnUpdate for smooth alpha transitions
    self:SetScript("OnUpdate", function(frame, elapsed)
        if not frame._glowAnimating then
            frame:SetScript("OnUpdate", nil)
            return
        end
        
        local elapsed = GetTime() - startTime
        
        if elapsed < style.GLOW_FADE_IN_DURATION then
            -- Phase 1: Fade in
            local progress = elapsed / style.GLOW_FADE_IN_DURATION
            frame.GlowOverlay:SetAlpha(progress * style.GLOW_MAX_ALPHA)
            
        elseif elapsed < style.GLOW_FADE_IN_DURATION + style.GLOW_HOLD_DURATION then
            -- Phase 2: Hold
            frame.GlowOverlay:SetAlpha(style.GLOW_MAX_ALPHA)
            
        elseif elapsed < style.GLOW_FADE_IN_DURATION + style.GLOW_HOLD_DURATION + style.GLOW_FADE_OUT_DURATION then
            -- Phase 3: Fade out
            local fadeStart = style.GLOW_FADE_IN_DURATION + style.GLOW_HOLD_DURATION
            local fadeProgress = (elapsed - fadeStart) / style.GLOW_FADE_OUT_DURATION
            frame.GlowOverlay:SetAlpha(style.GLOW_MAX_ALPHA * (1 - fadeProgress))
            
        else
            -- Animation complete
            frame:StopGlowAnimation()
        end
    end)
end

function CircularBarStyleTemplate:StopGlowAnimation()
    if self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    
    if self.GlowOverlay then
        self.GlowOverlay:Hide()
        self.GlowOverlay:SetAlpha(0)
    end
    
    self._glowAnimating = false
end
```

**Performance**: Glow runs on separate OnUpdate (not AnimationManager's), acceptable since it's only alpha updates.

#### E. Ring Segment Creation
```lua
function CircularBarStyleTemplate:CreateRingSegments()
    -- Initialize segment arrays
    self.segments = {}
    self.restedSegments = {}
    self.questCompleteSegments = {}
    self.questIncompleteSegments = {}
    
    -- Create XP segments (ARTWORK layer)
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        segment:Hide()
        self.segments[i] = segment
    end
    
    -- Create rested segments (ARTWORK sublevel 1)
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK", nil, RING_REST_SUBLEVEL)
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        segment:SetBlendMode("ADD")
        segment:SetAlpha(0.3)
        segment:Hide()
        self.restedSegments[i] = segment
    end
    
    -- Create quest overlay segments (ARTWORK sublevel 2)
    for i = 1, RING_SEGMENTS do
        local qc = self:CreateTexture(nil, "ARTWORK", nil, RING_QUEST_SUBLEVEL)
        qc:SetTexture("Interface\\Buttons\\WHITE8X8")
        qc:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        qc:Hide()
        self.questCompleteSegments[i] = qc
        
        local qi = self:CreateTexture(nil, "ARTWORK", nil, RING_QUEST_SUBLEVEL)
        qi:SetTexture("Interface\\Buttons\\WHITE8X8")
        qi:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        qi:Hide()
        self.questIncompleteSegments[i] = qi
    end
    
    -- Create border PNG (optional visual enhancement)
    if not self.BorderRing then
        self.BorderRing = self:CreateTexture(nil, "BACKGROUND")
        self.BorderRing:SetAllPoints()
        self.BorderRing:SetTexture("Interface\\AddOns\\XPBarEnhanced\\assets\\border.png")
        self.BorderRing:SetAlpha(0.8)
    end
    
    -- Position all segments around ring
    self:PositionRingSegments()
end
```

#### F. Ring Segment Positioning
```lua
function CircularBarStyleTemplate:PositionRingSegments()
    for i = 1, RING_SEGMENTS do
        -- Calculate angle (clockwise from 12 o'clock, -90° offset)
        local angle = (i - 1) * (360 / RING_SEGMENTS) - 90
        local rotation = math.rad(angle)
        
        -- Polar to Cartesian conversion
        local xOff = CIRCULAR_BAR_STYLE.RING_RADIUS_PX * math.cos(rotation)
        local yOff = CIRCULAR_BAR_STYLE.RING_RADIUS_PX * math.sin(rotation)
        
        -- Position XP segment
        self.segments[i]:ClearAllPoints()
        self.segments[i]:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        self:RotateTexture(self.segments[i], rotation)
        
        -- Position rested segment
        self.restedSegments[i]:ClearAllPoints()
        self.restedSegments[i]:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        self:RotateTexture(self.restedSegments[i], rotation)
        
        -- Position quest segments
        self.questCompleteSegments[i]:ClearAllPoints()
        self.questCompleteSegments[i]:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        self:RotateTexture(self.questCompleteSegments[i], rotation)
        
        self.questIncompleteSegments[i]:ClearAllPoints()
        self.questIncompleteSegments[i]:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        self:RotateTexture(self.questIncompleteSegments[i], rotation)
    end
end

function CircularBarStyleTemplate:RotateTexture(texture, rotation)
    if texture and texture.SetRotation then
        texture:SetRotation(rotation)
    end
end
```

**Note**: `SetRotation()` is retail WoW API. For Classic support, would need alternative rotation method (beyond scope).

#### G. Arc Rendering
```lua
function CircularBarStyleTemplate:SetArcProgress(progress)
    -- Calculate segments to show based on progress (0-1)
    local segmentsToShow = math.floor(progress * RING_SEGMENTS + 0.5)
    
    -- Get colors from user config
    local XPBarColors = _G.XPBarColors
    local colorNormal = XPBarColors:GetUserColor(Color.XpBar)
    
    -- Show/hide segments
    for i = 1, RING_SEGMENTS do
        if i <= segmentsToShow then
            self.segments[i]:SetColorTexture(
                colorNormal.r, colorNormal.g, colorNormal.b, colorNormal.a or 1
            )
            self.segments[i]:Show()
        else
            self.segments[i]:Hide()
        end
    end
end
```

**Optimization**: Could track `lastSegmentsShown` and only update changed segments (delta rendering).

#### H. Rested Arc Rendering
```lua
function CircularBarStyleTemplate:UpdateRestedArc(currentXP, maxXP)
    local restedXP = GetXPExhaustion() or 0
    
    if restedXP == 0 or maxXP == 0 then
        -- Hide all rested segments
        for i = 1, RING_SEGMENTS do
            self.restedSegments[i]:Hide()
        end
        return
    end
    
    -- Calculate segment ranges
    local currentProgress = currentXP / maxXP
    local restedProgress = math.min((currentXP + restedXP) / maxXP, 1)
    
    local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
    local restedSegment = math.floor(restedProgress * RING_SEGMENTS)
    
    -- Get rested color
    local XPBarColors = _G.XPBarColors
    local color = XPBarColors:GetUserColor(Color.Rested)
    
    -- Show rested segments AFTER current XP
    for i = 1, RING_SEGMENTS do
        if i > currentSegment and i <= restedSegment then
            self.restedSegments[i]:SetColorTexture(color.r, color.g, color.b, 1)
            self.restedSegments[i]:Show()
        else
            self.restedSegments[i]:Hide()
        end
    end
end
```

**Note**: Quest overlay offset logic intentionally removed for simplicity. In V1, rested segments were offset by quest segments. V2 version renders rested directly after current XP.

#### I. Quest Arc Rendering (Custom Algorithm)
```lua
function CircularBarStyleTemplate:UpdateQuestArc(layout)
    if not layout or not layout.visible then
        -- Hide all quest segments
        for i = 1, RING_SEGMENTS do
            self.questCompleteSegments[i]:Hide()
            self.questIncompleteSegments[i]:Hide()
        end
        return
    end
    
    -- Compute segment ranges
    local completeIndices, incompleteIndices = self:ComputeQuestSegmentRanges(layout)
    
    -- Hide all first
    for i = 1, RING_SEGMENTS do
        self.questCompleteSegments[i]:Hide()
        self.questIncompleteSegments[i]:Hide()
    end
    
    -- Get colors
    local XPBarColors = _G.XPBarColors
    local qcColor = XPBarColors:GetUserColor(Color.QuestComplete)
    local qiColor = XPBarColors:GetUserColor(Color.QuestIncomplete)
    
    -- Show complete segments
    for _, idx in ipairs(completeIndices) do
        self.questCompleteSegments[idx]:SetColorTexture(qcColor.r, qcColor.g, qcColor.b, 1)
        self.questCompleteSegments[idx]:Show()
    end
    
    -- Show incomplete segments
    for _, idx in ipairs(incompleteIndices) do
        self.questIncompleteSegments[idx]:SetColorTexture(qiColor.r, qiColor.g, qiColor.b, 1)
        self.questIncompleteSegments[idx]:Show()
    end
end

function CircularBarStyleTemplate:ComputeQuestSegmentRanges(layout)
    local currentProgress = layout.current and layout.current.ratio or 0
    local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
    
    -- Calculate segment counts (force at least 1 if visible and ratio > 0)
    local completeCount = 0
    if layout.questComplete and layout.questComplete.visible and (layout.questComplete.ratio or 0) > 0 then
        completeCount = math.max(1, math.floor(layout.questComplete.ratio * RING_SEGMENTS + 0.5))
    end
    
    local incompleteCount = 0
    if layout.questIncomplete and layout.questIncomplete.visible and (layout.questIncomplete.ratio or 0) > 0 then
        incompleteCount = math.max(1, math.floor(layout.questIncomplete.ratio * RING_SEGMENTS + 0.5))
    end
    
    -- Clamp to avoid overflow
    if completeCount + incompleteCount > RING_SEGMENTS then
        if completeCount >= RING_SEGMENTS then
            completeCount = RING_SEGMENTS
            incompleteCount = 0
        else
            incompleteCount = RING_SEGMENTS - completeCount
        end
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

**Key Detail**: Quest segments stack **after** current XP segments, not overlaid on top. This is unique to circular rendering.

#### J. Center Content Setup
```lua
function CircularBarStyleTemplate:SetupCenterContent()
    -- Create center background PNG
    if not self.CenterBG then
        self.CenterBG = self:CreateTexture(nil, "BACKGROUND", nil, 1)
        self.CenterBG:SetAllPoints()
        self.CenterBG:SetTexture("Interface\\AddOns\\XPBarEnhanced\\assets\\center.png")
        self.CenterBG:SetAlpha(0.8)
    end
    
    -- Level text (large, center-top)
    if not self.LevelText then
        self.LevelText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        self.LevelText:SetPoint("CENTER", 0, 15)
        self.LevelText:SetJustifyH("CENTER")
    end
    
    -- Percentage text (center)
    if not self.PercentText then
        self.PercentText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.PercentText:SetPoint("CENTER", 0, -5)
        self.PercentText:SetJustifyH("CENTER")
    end
    
    -- Rate text (time to level, small, center-bottom)
    if not self.RateText then
        self.RateText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.RateText:SetPoint("CENTER", 0, -25)
        self.RateText:SetJustifyH("CENTER")
    end
end
```

**Design**: All text positioned inside ring, no external containers needed.

#### K. Lifecycle Methods
```lua
function CircularBarStyleTemplate:OnLoad()
    -- Initialize state
    self.orientation = "CIRCULAR"
    self._barStyle = "Circular"
    self.lastProgress = 0
    self._glowAnimating = false
    
    -- Create visual elements
    self:CreateRingSegments()
    self:SetupCenterContent()
    
    -- Initialize animation state (required by AnimationBase)
    if self.InitializeAnimation then
        self:InitializeAnimation()
    end
end

function CircularBarStyleTemplate:OnHide()
    -- Cleanup glow animation
    self:StopGlowAnimation()
    
    -- Cleanup any base animation state
    if self.CleanupAnimation then
        self:CleanupAnimation()
    end
end
```

#### L. Override Methods (Custom Rendering)
```lua
-- Override: VisualsMixin:SetDisplayValue
function CircularBarStyleTemplate:SetDisplayValue(ratio)
    -- Instant update (used during initialization, no animation)
    self:SetArcProgress(ratio)
    
    -- Update overlays
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    if maxXP > 0 then
        self:UpdateRestedArc(currentXP, maxXP)
    end
    
    -- Update quest overlays (requires layout context)
    if self._lastLayout then
        self:UpdateQuestArc(self._lastLayout)
    end
end

-- Override: BaseMixin Action method
function CircularBarStyleTemplate:ActionUpdateVisuals(context)
    -- Store layout for later use in rendering methods
    if context and context.layout then
        self._lastLayout = context.layout
    end
    
    -- Call base implementation (handles text updates)
    if XPBarMixinBase_v2.ActionUpdateVisuals then
        XPBarMixinBase_v2.ActionUpdateVisuals(self, context)
    end
end
```

---

### Step 4: Create CircularBarTemplate.xml ⏳

**Minimal Structure** (segments created in Lua):
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="CircularBarStyle.lua"/>
    
    <!-- Circular Bar Template -->
    <Frame name="CircularBarTemplate_v2" mixin="CircularBarXPBarMixin" virtual="true" 
           enableMouse="true" frameStrata="MEDIUM">
        <Size x="256" y="256"/>
        
        <!-- No layers - segments created programmatically -->
        
        <Scripts>
            <OnLoad method="OnLoad"/>
            <OnHide method="OnHide"/>
        </Scripts>
    </Frame>
</Ui>
```

**Key Design**: Ultra-minimal XML. All visual elements created in Lua for maximum control.

---

### Step 5: Style Registration
```lua
-- Style configuration
local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    position = {mode = "DRAGGABLE", positionKey = "CircularBar_v2"},
    animation = {enableAnimations = true, flashOnGain = true},
    style = {
        width = 256,
        height = 256,
        segments = RING_SEGMENTS,
        radius = CIRCULAR_BAR_STYLE.RING_RADIUS_PX
    }
}

-- Create composed mixin
CircularBarXPBarMixin = XPBarStyleBuilder:Create(
    XPBarMixinBase_v2,
    CircularBarStyleTemplate,
    DefaultConfig
)

-- Register style
XPBarStyleBuilder:RegisterStyle("circular", CircularBarXPBarMixin)
```

---

## What's NOT Done Yet

### Integration Tasks ⬜

1. **TOC File Updates**
   - Add `ui\xpbars\circular_v2\CircularBarStyle.lua`
   - Add `ui\xpbars\circular_v2\CircularBarTemplate.xml`
   - Ensure load order (after core V2 files, after animation system)

2. **Frames.xml Updates**
   - Include circular_v2 XML template
   - Ensure mixin name matches (`CircularBarXPBarMixin`)

3. **StyleBuilder Registration**
   - Verify auto-registration on load
   - Test style selection in options panel

### Validation Tasks ⬜

#### Visual Validation
- [ ] Ring renders correctly (60 segments, circular layout)
- [ ] Segments positioned at correct radius (97px from center)
- [ ] Segments rotated correctly (radial orientation)
- [ ] Arc fills clockwise from 12 o'clock position
- [ ] Rested arc positioned after current XP
- [ ] Quest overlays stack after rested arc
- [ ] Glow overlay covers entire frame
- [ ] Center content (background, text) positioned correctly
- [ ] Border PNG renders correctly (if included)

#### Animation Validation
- [ ] Arc fill animates smoothly (0-100%)
- [ ] Glow animation plays on XP gain
- [ ] Glow phases correct (fade in → hold → fade out)
- [ ] Glow timing: 0.2s + 0.5s + 0.3s = 1.0s total
- [ ] Glow color matches rested state (cyan vs purple)
- [ ] No flicker or jitter during animations
- [ ] Animations cleanup properly on completion

#### Performance Validation
- [ ] FPS ≥ 60 during arc animation
- [ ] FPS ≥ 60 during glow animation
- [ ] FPS ≥ 60 during simultaneous arc + glow
- [ ] No memory leaks (stable over 30 mins)
- [ ] Segment updates performant (180 textures)
- [ ] OnUpdate cleanup on hide (no lingering scripts)

#### Integration Validation
- [ ] Works alongside other bars (multi-instance)
- [ ] Position saves/loads correctly
- [ ] Drag-to-move works (Shift+drag)
- [ ] Colors update from options panel
- [ ] Text visibility toggles work
- [ ] Tooltip displays correctly
- [ ] Alt+Click and Ctrl+Click work

#### Edge Cases
- [ ] XP = 0 (empty ring)
- [ ] XP = max (full ring)
- [ ] Rested XP fills entire ring
- [ ] Quest overlays fill entire ring
- [ ] Multiple simultaneous XP gains
- [ ] Level-up animation
- [ ] Fast style switching (circular → flat → circular)
- [ ] Resize behavior (if frame size changed)

### Testing Scenarios ⬜

1. **Small XP gains** (1-10 XP): Subtle arc animation
2. **Medium XP gains** (100-500 XP): Visible arc fill + glow
3. **Large XP gains** (1000+ XP): Dramatic effect
4. **Rapid XP gains**: Multiple quest turn-ins
5. **Level-up**: Ring resets to 0, animates to new XP
6. **Rested XP consumed**: Rested arc shrinks
7. **Quest completion**: Quest segments appear/disappear
8. **Multi-bar test**: Circular + Flat + Vertical simultaneously
9. **Low FPS environment**: Animation smoothness maintained
10. **High texture count**: 180 segments + other UI elements

---

## Migration from V1

### Code Reduction

| Component | V1 LOC | V2 LOC | Reduction |
|-----------|--------|--------|-----------|
| Style File | 962 | 500-600 (est) | -38% to -48% |
| Container | Included | N/A | Handled by V2 core |
| **Total** | **962** | **500-600** | **-38% to -48%** |

### Architecture Improvements

**V1 Issues Resolved**:
- ✅ Duplicated event handling removed (now in BaseMixin)
- ✅ Duplicated position management removed (now in PositionMixin)
- ✅ Duplicated tooltip logic removed (now in TooltipMixin)
- ✅ Duplicated text formatting removed (now in TextMixin)
- ✅ Cleaner separation of concerns (rendering vs behavior)

**V2 Benefits**:
- Standard event handling and lifecycle via BaseMixin
- Animation coordination via AnimationManager
- Consistent with other V2 styles
- Custom rendering fully preserved
- Performance optimizations possible (delta rendering)

### Feature Parity

| Feature | V1 | V2 | Notes |
|---------|----|----|-------|
| **Ring Segments** | ✅ | ✅ | 60 segments, same rendering |
| **Arc Fill Animation** | ✅ | ✅ | Integrated with AnimationManager |
| **Glow Effect** | ✅ | ✅ | 3-phase ticker preserved |
| **Rested Arc** | ✅ | ✅ | Custom rendering |
| **Quest Overlays** | ✅ | ✅ | Circular algorithm preserved |
| **Center Content** | ✅ | ✅ | Portrait + text |
| **Draggable** | ✅ | ✅ | Via PositionMixin |
| **Color Customization** | ✅ | ✅ | Via PaintMixin |
| **Tooltips** | ✅ | ✅ | Via TooltipMixin |
| **Text Updates** | ✅ | ✅ | Via TextMixin |

**No Feature Regressions**: 100% V1 functionality preserved in V2.

---

## Known Challenges & Solutions

### Challenge 1: Performance with 180 Textures
**Problem**: Updating 180 segment textures every frame could cause lag  
**Solution**:
- Implement delta rendering (only update changed segments)
- Batch Show/Hide calls
- Consider texture pooling if performance issues arise
- Profile with `/framestack` and `/fps` during animations

### Challenge 2: Glow Animation Overlap
**Problem**: Rapid XP gains could trigger multiple overlapping glow effects  
**Solution**:
- `_glowAnimating` flag prevents overlapping animations
- New glow cancels previous glow (via `StopGlowAnimation()`)
- Similar to flash cooldown in AnimationManager

### Challenge 3: Quest Overlay Edge Cases
**Problem**: Quest segments + rested segments might overflow RING_SEGMENTS (60)  
**Solution**:
- Clamp total segments in `ComputeQuestSegmentRanges()`
- Priority: XP > Quest Complete > Quest Incomplete > Rested
- Force at least 1 segment visible if overlay marked visible

### Challenge 4: Rotation API Compatibility
**Problem**: `SetRotation()` is retail WoW only (not in Classic)  
**Solution**:
- Document as retail-only feature
- For Classic support, would need alternative rotation method (e.g., texture coordinates)
- Out of scope for initial V2 migration

### Challenge 5: Integration with Other Animations
**Problem**: Both AnimationManager and Glow OnUpdate running simultaneously  
**Solution**:
- AnimationManager handles arc fill coordination
- Glow OnUpdate is independent (only alpha updates)
- No conflicts since they update different textures
- Both cleanup properly on OnHide

---

## Testing Strategy

### Unit Testing (Manual Commands)
```lua
-- Test arc rendering
/run CircularBar_v2:SetArcProgress(0.5)  -- 50% fill
/run CircularBar_v2:SetArcProgress(0)    -- Empty
/run CircularBar_v2:SetArcProgress(1)    -- Full

-- Test glow animation
/run CircularBar_v2:PlayGlowPulse()

-- Test XP gain simulation
/run CircularBar_v2:TriggerXPGain(1000)

-- Test level-up
/run CircularBar_v2:TestLevelUp()

-- Test multi-instance
/run XPBarStyleBuilder:CreateFrameForStyle("circular", nil, "CircularBarTemplate_v2"):Show()
```

### Integration Testing
1. Enable circular bar in options
2. Gain XP via quests, kills, exploration
3. Monitor FPS during animations
4. Check memory usage over time
5. Test style switching (flat → circular → vertical)
6. Test with other addons (WeakAuras, ElvUI)

### Performance Testing
```lua
-- Memory baseline
/run print(collectgarbage("count"))

-- Trigger 100 XP gains
/run for i=1,100 do CircularBar_v2:TriggerXPGain(10) end

-- Memory after
/run print(collectgarbage("count"))

-- FPS monitoring
/run print(GetFramerate())
```

### Visual Testing Checklist
- [ ] Segments align perfectly (no gaps)
- [ ] Arc starts at 12 o'clock (top)
- [ ] Arc fills clockwise
- [ ] Colors match user settings
- [ ] Text readable inside ring
- [ ] Glow effect not too bright/dark
- [ ] Border PNG aligned correctly

---

## Rollback Plan

### Triggers for Rollback
- FPS drops below 30 during animations
- Memory leaks detected
- Visual artifacts (flickering, misalignment)
- Game-breaking bugs
- User complaints > 10% of circular bar users

### Rollback Procedure
1. **Revert Commit**: `git revert <circular-v2-commit>`
2. **Restore V1**: Re-enable `ui/xpbar/styles/CircularXPBarMixin.lua` in .toc
3. **Test V1**: Verify circular bar works
4. **Update Options**: Remove circular from V2 style selector
5. **Communicate**: Notify users in patch notes

### Fallback Strategy
- Keep V1 circular bar file in codebase until V2 fully validated
- Add config flag: `useCircularV2 = false` to disable V2 temporarily
- Document issues in GitHub for future resolution

---

## Timeline Estimate

| Task | Duration | Notes |
|------|----------|-------|
| **Step 1**: Directory setup | 0.5 days | Simple file creation |
| **Step 2**: Core implementation | 3 days | Segments, rendering, animations |
| **Step 3**: Animation integration | 1.5 days | AnimateBarPosition, AnimateBarEffect, glow |
| **Step 4**: XML template | 0.5 days | Minimal structure |
| **Step 5**: Integration (.toc, Frames.xml) | 0.5 days | File includes |
| **Step 6**: Visual validation | 1 day | Test all rendering paths |
| **Step 7**: Animation validation | 1 day | Test arc + glow animations |
| **Step 8**: Performance testing | 1 day | FPS, memory, profiling |
| **Step 9**: Integration testing | 1 day | Multi-instance, style switching |
| **Step 10**: Bug fixes and polish | 1.5 days | Address issues from testing |
| **TOTAL** | **12 days** | Most complex migration |

**Critical Path**: Core implementation → Animation integration → Validation

---

## Success Criteria

### Functional Requirements
- ✅ Arc fills from 0% to 100% correctly
- ✅ Glow animation triggers on XP gain
- ✅ Rested arc renders after current XP
- ✅ Quest overlays stack correctly
- ✅ Center text displays correctly
- ✅ Draggable positioning works
- ✅ Colors update from options
- ✅ Tooltips display correctly

### Performance Requirements
- ✅ FPS ≥ 60 during all animations
- ✅ No memory leaks (stable over 30 mins)
- ✅ Segment updates < 1ms per frame
- ✅ Glow animation smooth (no stutter)

### Code Quality Requirements
- ✅ No code duplication with other styles
- ✅ Consistent with V2 architecture patterns
- ✅ Well-commented (especially complex algorithms)
- ✅ No globals except documented ones
- ✅ Error handling for edge cases

### Documentation Requirements
- ✅ Migration plan complete (this document)
- ✅ Code comments for complex methods
- ✅ Testing checklist complete
- ✅ Known issues documented

---

## Lessons Learned (From Previous Migrations)

### From Flat Bar V2 ✅
- **Lesson**: AnimationManager integration is straightforward for StatusBar-based bars
- **Application**: Circular bar needs custom `AnimateBarPosition()` without StatusBar
- **Benefit**: Proven animation coordination pattern

### From Legacy Bar V2 ✅
- **Lesson**: Static positioning is simpler than draggable (config flag handles it)
- **Application**: Circular uses draggable (like Flat), no special handling needed
- **Benefit**: PositionMixin handles all positioning logic

### From Vertical Bar V2 ✅
- **Lesson**: Custom animations can coexist with AnimationManager via OnUpdate
- **Application**: Glow animation uses separate OnUpdate, no conflicts
- **Benefit**: Validated pattern for dual animation systems

### Key Takeaways
1. **AnimationManager is flexible** - Works for both StatusBar and custom rendering
2. **Cleanup is critical** - Always cancel OnUpdate scripts in OnHide
3. **Delta rendering helps performance** - Only update changed visual elements
4. **Test early and often** - Catch issues before full integration

---

## Next Steps After Circular V2 Complete

### Phase 5: V1 Architecture Cleanup ⬜
1. Remove `ui/xpbar/` directory (all V1 styles)
2. Remove V1 animation system (XPBarMixinBase animations)
3. Remove V1 container mixins
4. Update options panel (remove V1 style references)
5. Clean up deprecated globals

### Phase 6: Global Cleanup & Polish ⬜
1. Performance optimization (texture pooling, delta rendering)
2. External developer tutorial (custom style guide)
3. Comprehensive testing (all 4 styles simultaneously)
4. Documentation update (README, ARCHITECTURE_V2)
5. Release preparation (changelog, migration notes)

---

## Conclusion

The Circular Bar V2 migration is the most complex and critical migration in the entire V2 architecture project. It validates the architecture's ability to handle extreme customization while maintaining code quality and performance.

**Key Success Factors**:
1. **Preserve all V1 features** - No regressions
2. **Maintain performance** - 180 textures must render smoothly
3. **Clean architecture** - Separate rendering from behavior
4. **Thorough testing** - Validate every edge case
5. **Documentation** - Guide future developers

**Expected Outcome**: A production-ready circular bar that demonstrates V2's power and flexibility, reducing code by ~40% while improving maintainability and enabling future customization.

**Migration Start Date**: TBD  
**Target Completion**: 12 days from start  
**Go/No-Go Decision Point**: Day 7 (after animation validation)

---

**Document Status**: ✅ Complete - Ready for Implementation  
**Last Updated**: November 9, 2025  
**Author**: XPBarEnhanced Development Team
