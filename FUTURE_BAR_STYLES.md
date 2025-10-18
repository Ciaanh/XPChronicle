# Future Bar Styles - Design Proposals

This document outlines potential new XP bar styles for XP Bar Enhanced, with implementation notes and design considerations.

---

## 1. Vertical Falling Bar (⭐ Your Request)

### Visual Concept

```
┌─────┐
│     │  ← Maximum XP (level cap)
│     │
│─────│  ← Current XP (before gain)
│█████│  ⬇ New XP "falls down" with animation
│█████│
│█████│
│█████│  ← Fills from top to bottom
│█████│
└─────┘
     ⬆ Empty (0 XP)
```

### Description

A vertical bar where:
- Bar fills from **top to bottom** (inverted)
- When you gain XP, new segments **fall down** like liquid or sand
- Visual metaphor: XP "accumulates" at the bottom
- Rested XP shown as lighter overlay falling alongside main XP

### Animation Details

**On XP Gain:**
1. New XP segment appears at the top (empty area)
2. Segment animates downward (0.3-0.5 seconds)
3. "Splashes" slightly when reaching the filled area
4. Ripple effect spreads through filled portion
5. Particles scatter at impact point (optional)

**Visual Effects:**
- Smooth easing (gravity-like acceleration)
- Particle trails during fall
- Color gradient during fall (brighter → normal)
- Slight bounce/rebound on impact

### Implementation Notes

**Frame Structure:**
```lua
VerticalXPBarMixin = {}

-- Frame hierarchy:
-- VerticalXPBar (main frame)
--   ├─ Background (solid color)
--   ├─ FilledTexture (current XP)
--   ├─ FallingTexture (animated new XP)
--   ├─ RestedOverlay (rested bonus)
--   ├─ ParticlePool (impact effects)
--   └─ TextOverlays (level, %, etc.)
```

**Key Methods:**
```lua
function VerticalXPBarMixin:AnimateFallingXP(oldValue, newValue)
    local diff = newValue - oldValue
    local barHeight = self:GetHeight()
    
    -- Create falling segment
    local fallingSegment = self.FallingTexture
    local segmentHeight = (diff / maxXP) * barHeight
    
    -- Start at top
    fallingSegment:SetHeight(segmentHeight)
    fallingSegment:SetPoint("TOP", self, "TOP", 0, 0)
    fallingSegment:Show()
    
    -- Animate downward to current XP level
    local targetY = -(barHeight * (oldValue / maxXP))
    
    self:AnimateSegmentFall(fallingSegment, 0, targetY, function()
        -- On complete: merge with main bar
        self:UpdateFilledHeight(newValue)
        self:PlayImpactEffect()
        fallingSegment:Hide()
    end)
end

function VerticalXPBarMixin:AnimateSegmentFall(texture, startY, endY, callback)
    -- Use AnimationGroup for smooth falling
    local ag = texture:CreateAnimationGroup()
    
    -- Translation with gravity-like easing
    local translate = ag:CreateAnimation("Translation")
    translate:SetOffset(0, endY - startY)
    translate:SetDuration(0.4)
    translate:SetSmoothing("OUT")  -- Accelerate (gravity)
    
    -- Slight bounce on impact
    local bounce = ag:CreateAnimation("Translation")
    bounce:SetOffset(0, 5)  -- Bounce up slightly
    bounce:SetDuration(0.1)
    bounce:SetOrder(2)
    
    local settle = ag:CreateAnimation("Translation")
    settle:SetOffset(0, -5)  -- Settle back down
    settle:SetDuration(0.1)
    settle:SetOrder(3)
    
    ag:SetScript("OnFinished", callback)
    ag:Play()
end
```

**Customization Options:**
- Bar width (narrow/medium/wide)
- Position (left/right side of screen)
- Animation speed (fast/normal/slow)
- Particle effects (on/off)
- Fall direction (top-down or bottom-up variant)

---

## 2. Circular Progress Ring

### Visual Concept

```
        ┌────────┐
      ╱            ╲
    │      89      │   ← Level number in center
    │    ████████  │   ← Percentage text
    │  ┌────────┐  │
    │  │ 12.5K  │  │   ← XP/hour rate
    │  └────────┘  │
      ╲            ╱
        └────────┘

    Ring fills clockwise from top (12 o'clock)
    Rested XP shown as lighter ring segment ahead
```

### Description

A circular ring that fills clockwise:
- Clean, modern look
- Compact footprint
- Easy to place anywhere on screen
- Ring thickness customizable
- Center displays key stats

### Animation Details

- Smooth arc fill animation
- Glow pulse when XP gained
- Level-up: Ring completes and bursts with particles
- Color gradient along the arc (customizable)

### Implementation Notes

**Technical Approach:**
- Use Texture with rotation/clipping
- Or construct arc from multiple segments
- AnimationGroup for smooth arc progression

**Pros:**
- Very compact
- Unique visual style
- Easy to scan at a glance

**Cons:**
- Less space for text overlays
- Harder to judge exact progress than horizontal bar
- More complex rendering (arc clipping)

---

## 3. Segmented Block Bar

### Visual Concept

```
┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
│█│█│█│█│█│█│█│█│█│▓│▓│▓│ │ │ │ │ │ │ │ │
└─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘
 ████████████ Current XP
         ▓▓▓▓▓ Rested XP
```

### Description

A bar divided into discrete blocks:
- Each block represents a percentage (e.g., 5% per block)
- Blocks fill left-to-right
- Visual feedback for progress milestones
- Quest XP overlays shown as highlighted block groups

### Animation Details

- Blocks fill one at a time with slight delay (cascade effect)
- Each block "pops" when filled (scale animation)
- Color pulse on completion
- Rested blocks glow softly

### Implementation Notes

**Frame Structure:**
```lua
-- Create 20 blocks (5% each)
for i = 1, 20 do
    local block = CreateFrame("Frame", nil, parent)
    block:SetSize(blockWidth, blockHeight)
    block.Fill = block:CreateTexture(nil, "ARTWORK")
    -- Position blocks side-by-side
end
```

**Pros:**
- Clear progress milestones
- Satisfying "pop" feedback
- Retro/arcade aesthetic

**Cons:**
- Less precise than smooth bar
- More frames to manage (performance consideration)
- Block count determines granularity

---

## 4. Dual-Line Progress Bar

### Visual Concept

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Level 89
████████████████████▓▓▓▓▓▓░░░░░░░░░░░ 65.3% (12,345 / 18,900)
───────────────────────────────────── Session: 2h 15m | 1.2K XP/hr
```

### Description

Two horizontal bars stacked:
- **Top bar**: Current level progress (main XP bar)
- **Bottom bar**: Session progress (XP gained this session)
- Both bars share width, different heights
- Bottom bar resets each session, visual "mini-goal"

### Use Case

Great for players who care about session progress:
- "How much have I gained this session?"
- Clear session vs. overall progress
- Motivation to complete "one more bar"

---

## 5. Minimalist Numeric Display

### Visual Concept

```
┌─────────────────┐
│  Lv 89 - 65.3% │
│  1.2K XP/hr    │
└─────────────────┘
```

### Description

Ultra-minimal approach:
- No bar at all, just text
- Compact single-line or two-line display
- Updates color based on rested status
- Glow effect on XP gain

### Use Case

For players who:
- Want maximum screen space
- Prefer numeric feedback
- Have memorized level requirements
- Don't need visual bar

---

## 6. Quest-Focused Overlay Bar

### Visual Concept

```
┌──────────────────────────────────────────────────┐
│████████████▓▓▓▓▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│     ↑       ↑   ↑                                │
│  Current  Rest Quest (3 quests = 18% of level)  │
└──────────────────────────────────────────────────┘

🟠 Quest 1: 1,250 XP
🟡 Quest 2: 980 XP
🟡 Quest 3: 1,150 XP
─────────────────────
   Total: 3,380 XP (18% of level)
```

### Description

Bar specifically designed to highlight quest XP:
- Prominent quest overlay segments
- Quest list below bar with individual contributions
- Color-coded by quest difficulty
- Hover shows quest names
- Click to open quest log

### Use Case

Perfect for quest-focused leveling:
- Visual planning: "These 3 quests will give me 18%"
- Immediate feedback on quest value
- Motivation to complete quest chains

---

## 7. Split Experience Bar

### Visual Concept

```
┌──────────────────┐    ┌─────────────┐
│████████████▓▓▓▓▓│    │████▒▒░░░░░░│
│ Combat XP: 45%  │    │ Quest: 20% │
└──────────────────┘    └─────────────┘

Total Progress: 65% to Level 90
```

### Description

Two separate mini-bars tracking different XP sources:
- Left bar: Combat/mob XP
- Right bar: Quest XP
- Shows breakdown of leveling methods
- Useful for analyzing leveling efficiency

### Use Case

For players who want to understand:
- "Am I leveling more from quests or combat?"
- Compare efficiency of different activities
- Optimize leveling strategy

---

## Implementation Priority Recommendation

### High Priority (Implement First)

1. **Vertical Falling Bar** - Your requested feature, unique and satisfying
   - Estimated effort: 2-3 days
   - Complexity: Medium (animation system)
   - Impact: High (unique visual appeal)

2. **Circular Progress Ring** - Modern, compact, popular style
   - Estimated effort: 2-3 days
   - Complexity: Medium-High (arc rendering)
   - Impact: Medium-High (appeals to minimalist players)

### Medium Priority

3. **Segmented Block Bar** - Distinct aesthetic, good feedback
   - Estimated effort: 1-2 days
   - Complexity: Low-Medium (multiple frame management)
   - Impact: Medium (niche appeal)

4. **Quest-Focused Overlay Bar** - Enhances existing feature
   - Estimated effort: 2 days
   - Complexity: Medium (quest integration)
   - Impact: Medium (complements existing features)

### Lower Priority (Nice to Have)

5. **Dual-Line Progress Bar** - Session tracking focus
6. **Minimalist Numeric Display** - Very niche
7. **Split Experience Bar** - Analytics focus

---

## Shared Architecture Considerations

### Mixin Structure (Reuse Existing Pattern)

All new bar styles should extend `XPBarMixinBase`:

```lua
-- New file: ui/xpbar/VerticalXPBarMixin.lua
VerticalXPBarMixin = CreateFromMixins(XPBarMixinBase)

function VerticalXPBarMixin:OnLoad()
    XPBarMixinBase.OnLoad(self)  -- Call base initialization
    -- Vertical-specific setup
end

function VerticalXPBarMixin:UpdateBarFill(currentXP, maxXP)
    -- Override with vertical-specific rendering
    -- Implement falling animation
end

-- Reuse from base:
-- - UpdateAllText()
-- - UpdateTooltip()
-- - GetQuestXP()
-- - Color management
```

### Config Integration

Add bar style option to `Config.lua`:

```lua
barStyle = {
    name = Addon.L["OPT_BAR_STYLE"],
    type = "dropdown",
    default = "Legacy",
    values = {
        "Legacy",
        "Flat",
        "Vertical",      -- NEW
        "Circular",      -- NEW
        "Segmented",     -- NEW
        "QuestFocus",    -- NEW
    },
    order = 2,
}
```

### XML Templates

Create frame templates in `Frames.xml`:

```xml
<!-- Vertical Bar Template -->
<Frame name="VerticalXPBarTemplate" mixin="VerticalXPBarMixin" virtual="true">
    <Size x="60" y="300"/>
    <Layers>
        <Layer level="BACKGROUND">
            <Texture parentKey="Background"/>
        </Layer>
        <Layer level="ARTWORK">
            <Texture parentKey="FilledTexture"/>
            <Texture parentKey="FallingTexture"/>
            <Texture parentKey="RestedOverlay"/>
        </Layer>
        <Layer level="OVERLAY">
            <FontString parentKey="LevelText" inherits="GameFontNormal"/>
            <FontString parentKey="PercentText" inherits="GameFontNormalSmall"/>
        </Layer>
    </Layers>
</Frame>
```

---

## User Feedback & Testing

### Beta Testing Checklist

For each new style:
- [ ] Smooth animations at 60 FPS
- [ ] Readable text at all UI scales
- [ ] Quest overlays work correctly
- [ ] Rested XP clearly visible
- [ ] Position saves/loads correctly
- [ ] Tooltip updates properly
- [ ] No Lua errors on XP gain
- [ ] Level-up animation works
- [ ] Color customization applies
- [ ] Works with max level characters

### Accessibility Considerations

- Color-blind friendly color options
- Option to disable animations (motion sensitivity)
- High contrast mode for text
- Scalable UI elements
- Screen reader compatibility (text fallbacks)

---

## Technical Notes

### Performance Optimization

- Use object pooling for particles
- Limit active animations (max 3 concurrent)
- Throttle updates (max 10 FPS for non-critical updates)
- Lazy-load unused bar styles
- Reuse textures across bar types

### Animation System

Consider creating a shared animation utility:

```lua
-- core/AnimationUtils.lua
Addon.AnimationUtils = {}

function Addon.AnimationUtils:CreateFallingAnimation(texture, params)
    -- Reusable falling animation logic
end

function Addon.AnimationUtils:CreateGlowPulse(frame, params)
    -- Reusable glow effect
end

function Addon.AnimationUtils:CreateBounceAnimation(frame, params)
    -- Reusable bounce effect
end
```

Benefits:
- Consistent animation feel across styles
- Easier to maintain
- Smaller per-style code
- Reusable for other UI elements

---

## Mockup Assets Needed

For each proposed style, create:
1. Static mockup image (PNG)
2. Animated GIF showing XP gain
3. Level-up celebration animation
4. Settings panel preview
5. Comparison image (all styles side-by-side)

This will help users choose their preferred style.

---

## Release Strategy

### Phase 1 (v1.1.0): Vertical Falling Bar
- Main feature: Vertical bar with falling animation
- Polish existing Legacy/Flat styles
- Add animation speed options

### Phase 2 (v1.2.0): Circular Ring
- Add circular progress ring style
- Shared animation utilities
- Performance improvements

### Phase 3 (v1.3.0): Additional Styles
- Segmented block bar
- Quest-focused overlay bar
- User voting on next style

---

*Last Updated: October 2025*
*Status: Proposal Stage - Ready for Implementation*
