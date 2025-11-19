# Classic Bar V1 vs  - Size and Positioning Comparison

## Architecture Overview

### V1 Architecture (Container + Bar)
```
ClassicXPBarContainer (571x17)
├── BarFrameTexture (OVERLAY layer - border atlas)
├── Bar (ClassicXPBarTemplate) (565x11) - CENTER anchor
│   ├── GainFlash (OVERLAY layer on main frame)
│   └── StatusBar (fills parent via anchors)
│       ├── Background (BACKGROUND layer)
│       ├── ExhaustionLevelFillBar (ARTWORK layer)
│       ├── QuestOverlayComplete (OVERLAY layer)
│       ├── QuestOverlayIncomplete (OVERLAY layer)
│       └── ExhaustionTick (Button frame)
├── OverlayFrame (MEDIUM strata, setAllPoints)
│   ├── LevelText
│   ├── XPText
│   └── PercentText
└── BelowBarTextContainer (separate template)
    ├── RateText
    ├── SessionText
    └── QuestSummaryText
```

###  Architecture (Single Frame)
```
ClassicBarTemplate (571x17)
├── StatusBar (565x15) - CENTER anchor
│   ├── Background (BACKGROUND layer)
│   ├── ExhaustionLevelFillBar (ARTWORK layer)
│   ├── QuestOverlayComplete (OVERLAY layer)
│   ├── QuestOverlayIncomplete (OVERLAY layer)
│   └── ExhaustionTick (Button frame)
├── OverlayFrameTextContainer (MEDIUM strata)
│   ├── LevelText
│   ├── XPText
│   └── PercentText
├── BelowBarTextContainer
│   ├── RateText
│   ├── SessionText
│   └── QuestSummaryText
├── BorderFrame (MEDIUM strata)
│   └── Texture (border atlas)
└── FlashFrame (LOW strata)
    └── GainFlash
```

---

## Frame Size Comparison

### Main Frames

| Component | V1 |  | Difference |
|-----------|----|----|------------|
| **Container/Main Frame** | 571x17 | 571x17 | ✅ **SAME** |
| **Bar/Inner Frame** | 565x11 | N/A (no separate bar frame) |  uses main frame directly |
| **StatusBar** | Fills parent (565x~11) | 565x15 | ⚠️ ** is 4px taller** |

### Key Difference:
- **V1**: Has a 2-level structure (Container → Bar → StatusBar)
  - Container: 571x17
  - Bar: 565x11 (6px inset from container)
  - StatusBar: Fills Bar frame via anchors
  
- ****: Has a flat structure (Main Frame → StatusBar)
  - Main Frame: 571x17
  - StatusBar: 565x15 (explicitly sized, centered)

---

## StatusBar Analysis

### V1 StatusBar
```xml
<StatusBar parentKey="StatusBar" minValue="0" maxValue="1" defaultValue="0">
    <Anchors>
        <Anchor point="TOPLEFT" x="0" y="0"/>
        <Anchor point="BOTTOMRIGHT" x="0" y="0"/>
    </Anchors>
```
- **Size**: Fills parent frame (565x11) via anchors
- **Position**: TOPLEFT to BOTTOMRIGHT (fills Bar frame)
- **Effective Size**: ~565x11 (inherits from Bar frame)

###  StatusBar
```xml
<StatusBar parentKey="StatusBar" minValue="0" maxValue="1" defaultValue="0">
    <Size x="565" y="15"/>
    <Anchors>
        <Anchor point="CENTER" x="0" y="0"/>
    </Anchors>
```
- **Size**: Explicitly set to 565x15
- **Position**: Centered in main frame (571x17)
- **Effective Size**: 565x15

### ⚠️ Critical Difference
- **V1 StatusBar height**: ~11px (bar frame height)
- ** StatusBar height**: 15px (explicitly set)
- **Difference**:  is **4 pixels taller**

---

## Overlay Textures Comparison

### Rested XP Overlay (ExhaustionLevelFillBar)

| Property | V1 |  | Match? |
|----------|----|----|--------|
| Texture File | `Interface\TargetingFrame\UI-StatusBar` | `Interface\Buttons\WHITE8X8` | ❌ Different |
| Height | 10px | 11px | ❌  is 1px taller |
| Anchor Point | LEFT (0, 0) | LEFT (0, 0) | ✅ Same |
| Layer | ARTWORK textureSubLevel="-1" | ARTWORK textureSubLevel="1" | ❌ Different sublevel |
| Color | rgb(0.0, 0.5, 1.0, 0.5) | rgb(0.0, 0.5, 1.0, 0.5) | ✅ Same |

### Quest Complete Overlay

| Property | V1 |  | Match? |
|----------|----|----|--------|
| Texture File | `Interface\TargetingFrame\UI-StatusBar` | `Interface\Buttons\WHITE8X8` | ❌ Different |
| Height | 10px | 11px | ❌  is 1px taller |
| Anchor Point | LEFT (0, 0) | LEFT (0, 0) | ✅ Same |
| Layer | OVERLAY textureSubLevel="1" | OVERLAY textureSubLevel="1" | ✅ Same |
| Color | rgba(1.0, 0.59, 0.0, 0.8) | rgba(1.0, 0.59, 0.0, 0.8) | ✅ Same |

### Quest Incomplete Overlay

| Property | V1 |  | Match? |
|----------|----|----|--------|
| Texture File | `Interface\TargetingFrame\UI-StatusBar` | `Interface\Buttons\WHITE8X8` | ❌ Different |
| Height | 10px | 11px | ❌  is 1px taller |
| Anchor Point | LEFT (0, 0) | LEFT (0, 0) | ✅ Same |
| Layer | OVERLAY textureSubLevel="2" | OVERLAY textureSubLevel="2" | ✅ Same |
| Color | rgba(1.0, 0.82, 0.31, 0.6) | rgba(1.0, 0.82, 0.31, 0.6) | ✅ Same |

---

## Flash Effect Comparison

### V1 Flash (GainFlash)
```xml
<Layer level="OVERLAY" textureSubLevel="3">
    <Texture parentKey="GainFlash" hidden="true">
        <Anchors>
            <Anchor point="TOPLEFT"/>
            <Anchor point="BOTTOMRIGHT"/>
        </Anchors>
```
- **Location**: Layer on main Bar frame (565x11)
- **Size**: Fills parent via anchors (565x11)
- **Strata**: Inherits from Bar frame (LOW)
- **Position**: On the Bar frame itself

###  Flash (FlashFrame.GainFlash)
```xml
<Frame parentKey="FlashFrame" frameStrata="LOW" enableMouse="false">
    <Size x="570" y="11"/>
    <Anchors>
        <Anchor point="CENTER" x="0" y="0"/>
    </Anchors>
    <Layers>
        <Layer level="OVERLAY">
            <Texture parentKey="GainFlash" hidden="true">
```
- **Location**: Separate FlashFrame (570x11)
- **Size**: 570x11 (5px wider than V1!)
- **Strata**: LOW (explicit)
- **Position**: Centered in main frame

### ⚠️ Critical Difference
- **V1 Flash size**: 565x11 (matches Bar)
- ** Flash size**: 570x11 (5px wider than StatusBar!)
- **Difference**:  flash extends 2.5px on each side beyond StatusBar

---

## Border Frame Comparison

### V1 Border (BarFrameTexture)
```xml
<!-- On Container frame (571x17) -->
<Layer level="OVERLAY">
    <Texture parentKey="BarFrameTexture" atlas="UI-HUD-ExperienceBar-Frame" useAtlasSize="true"/>
</Layer>
```
- **Location**: Layer on Container frame
- **Size**: Atlas size (auto-sized by atlas)
- **Strata**: Inherits from Container (LOW)
- **Position**: Implicit (layer on container)

###  Border (BorderFrame)
```xml
<Frame parentKey="BorderFrame" frameStrata="MEDIUM" enableMouse="false">
    <Anchors>
        <Anchor point="TOPLEFT"/>
        <Anchor point="BOTTOMRIGHT"/>
    </Anchors>
    <Layers>
        <Layer level="ARTWORK">
            <Texture parentKey="Texture" atlas="UI-HUD-ExperienceBar-Frame" useAtlasSize="true">
                <Anchors>
                    <Anchor point="CENTER"/>
                </Anchors>
```
- **Location**: Separate BorderFrame
- **Size**: Fills parent (571x17)
- **Strata**: MEDIUM (explicit)
- **Position**: Fills main frame, atlas centered

### ✅ Functional Match
Both use the same atlas and achieve similar visual results, though  uses a separate frame at MEDIUM strata for better layering control.

---

## Text Elements Comparison

### On-Bar Text Container

| Property | V1 (OverlayFrame) |  (OverlayFrameTextContainer) | Match? |
|----------|-------------------|--------------------------------|--------|
| Frame Type | Frame | Frame | ✅ Same |
| Strata | MEDIUM | MEDIUM | ✅ Same |
| Size | setAllPoints="true" (565x11) | 571x11 (explicit) | ❌  is 6px wider |
| Position | setAllPoints to Bar | CENTER anchor | ❌ Different |
| Text Y Offset | y="1" | y="0" | ❌ V1 has 1px vertical offset |

### Text Elements (LevelText, XPText, PercentText)

| Element | V1 Position |  Position | Match? |
|---------|-------------|-------------|--------|
| **LevelText** | LEFT (8, 1) | LEFT (8, 0) | ⚠️ V1 has 1px y-offset |
| **XPText** | CENTER (0, 1) | CENTER (0, 0) | ⚠️ V1 has 1px y-offset |
| **PercentText** | RIGHT (-8, 1) | RIGHT (-8, 0) | ⚠️ V1 has 1px y-offset |

All text elements in V1 have a **1px upward offset** (y="1") that  lacks (y="0").

### Below-Bar Text Container

| Property | V1 |  | Match? |
|----------|----|----|--------|
| Size | Inherited from template | 565x30 | N/A |
| Position | TOP→BOTTOM (0, 0) | TOPLEFT→BOTTOMLEFT (0, -2) | ⚠️  has 2px gap |
| Text Elements | Same structure | Same structure | ✅ Same |

---

## Exhaustion Tick (Rested Marker)

| Property | V1 |  | Match? |
|----------|----|----|--------|
| Size | 10x12 | 10x12 | ✅ Same |
| Anchor | CENTER of ExhaustionLevelFillBar RIGHT | CENTER of ExhaustionLevelFillBar RIGHT | ✅ Same |
| Atlas | UI-HUD-ExperienceBar-Frame-Pip | UI-HUD-ExperienceBar-Frame-Pip | ✅ Same |
| Strata | MEDIUM | MEDIUM | ✅ Same |

---

## Rendering Order (Z-Index)

### V1 Rendering Stack (Bottom to Top)
```
LOW Strata:
  1. Container Background
  2. StatusBar (fills Bar frame 565x11)
     - Background texture (BACKGROUND layer)
     - ExhaustionLevelFillBar (ARTWORK)
     - QuestOverlayComplete (OVERLAY sub=1)
     - QuestOverlayIncomplete (OVERLAY sub=2)
  3. GainFlash (OVERLAY sub=3 on Bar frame)
  4. BarFrameTexture (OVERLAY on Container)

MEDIUM Strata:
  5. OverlayFrame with text elements
  6. ExhaustionTick (Button)
```

###  Rendering Stack (Bottom to Top)
```
LOW Strata:
  1. StatusBar (565x15)
     - Background texture (BACKGROUND layer)
     - ExhaustionLevelFillBar (ARTWORK)
     - QuestOverlayComplete (OVERLAY sub=1)
     - QuestOverlayIncomplete (OVERLAY sub=2)
  2. FlashFrame (570x11)
     - GainFlash (OVERLAY)

MEDIUM Strata:
  3. OverlayFrameTextContainer with text
  4. BorderFrame with border atlas
  5. ExhaustionTick (Button)
  6. BelowBarTextContainer
```

### Key Difference
V1 has flash as a layer on the Bar frame,  has flash as a separate frame, allowing for precise control over rendering order.

---

## Summary of Size Discrepancies

### Critical Issues
1. **StatusBar Height**:  is 15px vs V1's ~11px (**4px taller**)
2. **FlashFrame Width**:  is 570px vs V1's 565px (**5px wider**)
3. **Overlay Texture Heights**:  overlays are 11px vs V1's 10px (**1px taller**)
4. **Text Y-Offset**: V1 has y="1" offset,  has y="0" (**1px difference**)

### Visual Impact
The 4px height difference in the StatusBar is the most significant discrepancy and will cause:
- Different fill ratios (same XP percentage appears more filled in )
- Overlays positioned differently vertically
- Potential misalignment with border atlas

### Recommendations
To achieve visual parity with V1:
1. Change  StatusBar height from 15px to 11px
2. Change  FlashFrame width from 570px to 565px
3. Change  overlay heights from 11px to 10px
4. Add y="1" offset to  text elements (or verify if y="0" is intentional)

---

## Width Analysis

| Component | V1 |  | Notes |
|-----------|----|----|-------|
| Container/Main | 571 | 571 | ✅ Same |
| Bar/StatusBar | 565 | 565 | ✅ Same width |
| Flash | 565 | 570 | ⚠️  wider |
| Border | Auto (atlas) | Auto (atlas) | ✅ Same |
| Text Container | 565 (setAllPoints) | 571 | ⚠️  wider |

---

## Height Analysis

| Component | V1 |  | Notes |
|-----------|----|----|-------|
| Container/Main | 17 | 17 | ✅ Same |
| Bar/StatusBar | 11 | 15 | ⚠️ ** is 4px taller** |
| Flash | 11 | 11 | ✅ Same |
| Overlays | 10 | 11 | ⚠️  is 1px taller |

---

## Conclusion

The main visual differences between V1 and  stem from:

1. **Architecture**:  uses a flatter structure (single main frame vs container+bar)
2. **StatusBar Height**: 's 15px vs V1's 11px creates visible fill ratio differences
3. **Flash Positioning**:  uses a separate frame (more control) but is 5px wider
4. **Text Offset**: V1 has 1px upward text offset that  lacks

**For exact V1 parity, the StatusBar height in  should be changed from 15px to 11px.**
