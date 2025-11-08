# Legacy Bar Layer & Frame Positioning Comparison

## Overview
This document provides a detailed comparison of the layer and frame positioning across three XP bar implementations:
- **Legacy Bar V2** (Current implementation)
- **Legacy Bar V1** (Previous implementation)
- **Blizzard XP Bar** (Native implementation reference)

---

## 1. LEGACY BAR V2 (Current - Single Frame Architecture)

### Main Frame Structure
```
Frame "LegacyBarTemplate" (frameStrata="LOW", size: config-driven 571x17)
├─ Frames (no layers on main frame)
│  ├─ StatusBar (anchored with insets, calculated ~565x11)
│  ├─ OverlayFrameTextContainer (frameStrata="MEDIUM", 571x11)
│  ├─ BelowBarTextContainer (frameStrata="MEDIUM", 565x30)
│  ├─ BorderFrame (frameStrata="MEDIUM", fills parent 571x17)
│  └─ FlashFrame (frameStrata="LOW", inset ~565x11)
```

### Detailed Layer Hierarchy

#### **StatusBar Frame** (parentKey="StatusBar")
- **Position**: `TOPLEFT (3, -3)` to `BOTTOMRIGHT (-3, 3)` - inset from main frame
- **Size**: Calculated from anchors (571-6=565 width, 17-6=11 height)
- **Effective Size**: ~565x11
- **FrameStrata**: LOW (inherited)
- **Layers**:
  1. **BACKGROUND**:
     - `Background` texture (atlas: UI-HUD-ExperienceBar-Background)
     - Position: `TOPLEFT (1, 0)` to `BOTTOMRIGHT (-1, 1)` - inset within StatusBar
     - Effective Size: ~563x10 (StatusBar size minus 1px insets)
  2. **ARTWORK textureSubLevel="1"**:
     - `ExhaustionLevelFillBar` (rested XP overlay, file: WHITE8X8)
     - Size: `0x11` (width animated, height explicit)
     - Position: `BOTTOMLEFT (0, 0)`
  3. **OVERLAY textureSubLevel="1"**:
     - `QuestOverlayComplete` (file: WHITE8X8)
     - Size: `0x11` (width animated)
     - Position: `BOTTOMLEFT (0, 0)`
  4. **OVERLAY textureSubLevel="2"**:
     - `QuestOverlayIncomplete` (file: WHITE8X8)
     - Size: `0x11` (width animated)
     - Position: `BOTTOMLEFT (0, 0)`
- **Child Frames**:
  - `ExhaustionTick` Button (frameStrata="MEDIUM", size: 10x14)
    - Position: `CENTER` of `ExhaustionLevelFillBar` RIGHT edge

#### **FlashFrame** (parentKey="FlashFrame")
- **Position**: `TOPLEFT (3, -3)` to `BOTTOMRIGHT (-3, 3)` - matches StatusBar area
- **Size**: Calculated from anchors, matches StatusBar (~565x11)
- **FrameStrata**: LOW (same as StatusBar, renders after due to XML order)
- **Layers**:
  - **OVERLAY**:
    - `GainFlash` texture (color texture, hidden by default)
    - Position: Fills entire FlashFrame

#### **BorderFrame** (parentKey="BorderFrame")
- **Position**: `TOPLEFT` to `BOTTOMRIGHT` - fills entire main frame
- **Size**: Matches parent frame (571x17)
- **FrameStrata**: MEDIUM (renders on top of LOW strata elements)
- **Layers**:
  - **ARTWORK**:
    - `Texture` (atlas: UI-HUD-ExperienceBar-Frame, useAtlasSize=true)
    - Atlas Native Size: 571x17
    - Position: `CENTER`

#### **OverlayFrameTextContainer** (parentKey="OverlayFrameTextContainer")
- **Position**: `CENTER (0, 0)` - centered on main frame
- **Size**: `571x11`
- **FrameStrata**: MEDIUM
- **Layers**:
  - **ARTWORK textureSubLevel="5"**:
    - `LevelText` FontString: `LEFT (8, 0)`
    - `XPText` FontString: `CENTER (0, 0)`
    - `PercentText` FontString: `RIGHT (-8, 0)`

#### **BelowBarTextContainer** (parentKey="BelowBarTextContainer")
- **Position**: `TOPLEFT` relative to main frame's `BOTTOMLEFT (0, -2)`
- **Size**: `565x30`
- **FrameStrata**: MEDIUM
- **Layers**:
  - **ARTWORK**:
    - `RateText` FontString: `TOPLEFT (0, 0)`
    - `SessionText` FontString: `TOPRIGHT (0, 0)`
    - `QuestSummaryText` FontString: `TOP (0, -12)`

### Rendering Order (Bottom to Top)
1. **LOW Strata**:
   - StatusBar (BACKGROUND, ARTWORK, OVERLAY layers)
   - FlashFrame (OVERLAY layer) - renders on top of StatusBar
2. **MEDIUM Strata**:
   - ExhaustionTick Button
   - OverlayFrameTextContainer (text on bar)
   - BelowBarTextContainer (text below bar)
   - BorderFrame (border on top)

---

## 2. LEGACY BAR V1 (Container Architecture)

### Container Structure
```
Frame "XPC_LegacyXPBarContainerTemplate" (size: 571x17)
├─ Layers
│  └─ OVERLAY: BarFrameTexture (border atlas)
└─ Frames
   ├─ Bar (inherits XPC_LegacyXPBarTemplate, positioned at BOTTOMLEFT 1,5)
   └─ BelowBarTextContainer
```

### Bar Template Structure
```
Frame "XPC_LegacyXPBarTemplate" (frameStrata="LOW", size: 565x11)
├─ Layers
│  └─ OVERLAY textureSubLevel="3": GainFlash
└─ Frames
   ├─ StatusBar (size: 565x10, position: BOTTOMLEFT 0,0)
   └─ OverlayFrame (frameStrata="MEDIUM", setAllPoints)
```

### Detailed Layer Hierarchy

#### **Container Frame** (XPC_LegacyXPBarContainerTemplate)
- **Size**: `571x17` (explicit)
- **FrameStrata**: Not specified (likely MEDIUM or inherits from parent)
- **Layers**:
  - **OVERLAY**:
    - `BarFrameTexture` (atlas: UI-HUD-ExperienceBar-Frame, useAtlasSize=true)
    - Atlas Native Size: 571x17
    - Position: Implicit (fills frame)

#### **Bar Frame** (XPC_LegacyXPBarTemplate)
- **Position within container**: `BOTTOMLEFT (1, 5)` - 1px left, 5px up from container bottom
- **Size**: `565x11` (explicit)
- **FrameStrata**: LOW
- **Layers**:
  - **OVERLAY textureSubLevel="3"**:
    - `GainFlash` texture
    - Size: Fills bar frame (565x11)
    - Position: `TOPLEFT` to `BOTTOMRIGHT` (fills bar frame)

#### **StatusBar** (within Bar Frame)
- **Size**: `565x10` (explicit)
- **Position**: `BOTTOMLEFT (0, 0)` and `BOTTOMRIGHT (0, 0)` - bottom-aligned, 1px shorter than bar frame
- **Effective Position in Container**: BOTTOMLEFT (1, 5) + (0, 0) = BOTTOMLEFT (1, 5)
- **Layers**:
  1. **BACKGROUND**:
     - `Background` texture (atlas: UI-HUD-ExperienceBar-Background)
     - Size: Fills StatusBar (565x10)
     - Position: `TOPLEFT` to `BOTTOMRIGHT` (fills StatusBar)
  2. **ARTWORK textureSubLevel="-1"**:
     - `ExhaustionLevelFillBar` (file: UI-StatusBar)
     - Size: `0x10` (width animated, height explicit)
     - Position: `BOTTOMLEFT (0, 0)`
  3. **OVERLAY textureSubLevel="1"**:
     - `QuestOverlayComplete` (file: UI-StatusBar)
     - Size: `0x10` (width animated)
  4. **OVERLAY textureSubLevel="2"**:
     - `QuestOverlayIncomplete` (file: UI-StatusBar)
     - Size: `0x10` (width animated)
- **Child Frames**:
  - `ExhaustionTick` Button (frameStrata="MEDIUM", size: 10x14)

#### **OverlayFrame** (within Bar Frame)
- **Position**: `setAllPoints="true"` - fills entire bar frame
- **Size**: Matches bar frame (565x11)
- **FrameStrata**: MEDIUM
- **Layers**:
  - **ARTWORK textureSubLevel="5"**:
    - `LevelText`: `LEFT (8, 1)`
    - `XPText`: `CENTER (0, 1)`
    - `PercentText`: `RIGHT (-8, 1)`

### Rendering Order (Bottom to Top)
1. **LOW Strata** (Bar Frame):
   - StatusBar layers (BACKGROUND → ARTWORK → OVERLAY)
   - GainFlash (OVERLAY textureSubLevel=3 on bar frame)
2. **MEDIUM Strata**:
   - OverlayFrame (text on bar)
   - ExhaustionTick
3. **Container Frame** (strata not specified, likely MEDIUM or LOW):
   - Border texture (OVERLAY layer on container)

---

## 3. BLIZZARD XP BAR (Reference)

### Estimated Structure (Based on V1 Implementation)
Blizzard's StatusTrackingBar system likely uses:

```
StatusTrackingBarContainer (similar to MainStatusTrackingBarContainer)
├─ Border Frame/Texture (top layer)
└─ StatusBar
   ├─ Background
   ├─ Fill Bar (XP progress)
   ├─ Rested overlay
   └─ ExhaustionTick
```

**Key Characteristics**:
- Border rendered as separate overlay layer or frame
- StatusBar contains all progress visualization
- Tick marker at MEDIUM+ strata for hover interaction
- Text overlays at higher strata for visibility

---

## KEY DIFFERENCES

### Architecture

| Aspect | V2 | V1 | Blizzard |
|--------|----|----|----------|
| **Structure** | Single frame | Container + Bar | Container system |
| **Main Frame Size** | 571x17 (config) | Container: 571x17 | Variable |
| **Bar Size** | Anchor-based (~565x11) | Explicit: 565x11 | ~565x11 |
| **Border** | Separate BorderFrame (MEDIUM) | Container layer (OVERLAY) | Container layer |

### Flash Positioning

| Implementation | Flash Location | Flash Strata | Flash Position |
|----------------|----------------|--------------|----------------|
| **V2** | FlashFrame (separate) | LOW | Inset (3,-3) matches StatusBar |
| **V1** | Bar frame layer | LOW | Fills bar frame (565x11) |
| **Blizzard** | Likely separate overlay | MEDIUM+ | Covers bar area |

### Border Positioning

| Implementation | Border Location | Border Strata | Border Size |
|----------------|-----------------|---------------|-------------|
| **V2** | BorderFrame.Texture | MEDIUM | useAtlasSize=true, centered |
| **V1** | Container.BarFrameTexture | Container strata | useAtlasSize=true |
| **Blizzard** | Container overlay | MEDIUM+ | Wraps entire bar |

### StatusBar Background Insets

| Implementation | Background Insets | Reason |
|----------------|-------------------|---------|
| **V2** | TOPLEFT (1,0), BOTTOMRIGHT (-1,1) | Prevent bleeding outside border |
| **V1** | None (fills StatusBar) | StatusBar explicitly sized within container |
| **Blizzard** | Likely none | Precise container/bar sizing |

### Text Positioning

| Implementation | On-Bar Text | Below-Bar Text |
|----------------|-------------|----------------|
| **V2** | OverlayFrameTextContainer (MEDIUM, 571x11 centered) | BelowBarTextContainer (MEDIUM, relative to BOTTOMLEFT) |
| **V1** | OverlayFrame (MEDIUM, setAllPoints on bar) | BelowBarTextContainer (on container) |
| **Blizzard** | Separate overlay frame (MEDIUM+) | Separate frame |

---

## LAYER ORDER VISUALIZATION

### V2 Rendering Stack (Bottom to Top)
```
┌─────────────────────────────────────────┐
│ MEDIUM STRATA                            │
│ ┌───────────────────────────────────┐   │
│ │ BorderFrame (ARTWORK)              │   │ ← Border on top
│ │   Atlas: UI-HUD-ExperienceBar-Frame│   │
│ └───────────────────────────────────┘   │
│ ┌───────────────────────────────────┐   │
│ │ OverlayFrameTextContainer (ARTWORK)│   │ ← Text visible
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ LOW STRATA                               │
│ ┌───────────────────────────────────┐   │
│ │ FlashFrame (OVERLAY)               │   │ ← Flash under border
│ │   GainFlash texture                │   │
│ └───────────────────────────────────┘   │
│ ┌───────────────────────────────────┐   │
│ │ StatusBar (BACKGROUND→OVERLAY)     │   │ ← Base bar
│ │   - Background atlas               │   │
│ │   - ExhaustionLevelFillBar         │   │
│ │   - QuestOverlays                  │   │
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### V1 Rendering Stack (Bottom to Top)
```
┌─────────────────────────────────────────┐
│ CONTAINER FRAME                          │
│ ┌───────────────────────────────────┐   │
│ │ OVERLAY: BarFrameTexture           │   │ ← Border on container
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ MEDIUM STRATA (on bar frame)            │
│ ┌───────────────────────────────────┐   │
│ │ OverlayFrame (ARTWORK)             │   │ ← Text visible
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ LOW STRATA (bar frame)                   │
│ ┌───────────────────────────────────┐   │
│ │ OVERLAY: GainFlash                 │   │ ← Flash on bar layer
│ └───────────────────────────────────┘   │
│ ┌───────────────────────────────────┐   │
│ │ StatusBar (BACKGROUND→OVERLAY)     │   │ ← Base bar
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

## SIZE COMPARISON TABLE

### Frame Sizes

| Frame/Element | V2 Size | V1 Size | Notes |
|---------------|---------|---------|-------|
| **Main/Container Frame** | 571x17 (config) | 571x17 (explicit) | Same |
| **Bar Frame** | N/A (single frame) | 565x11 (explicit) | V2 has no separate bar frame |
| **StatusBar** | ~565x11 (anchored) | 565x10 (explicit) | V2 calculated from insets, V1 explicit |
| **StatusBar Position** | TOPLEFT (3,-3) to BOTTOMRIGHT (-3,3) | BOTTOMLEFT (0,0) in bar frame at (1,5) | V2 inset, V1 offset in container |
| **Background Texture** | ~563x10 (inset 1px) | 565x10 (fills StatusBar) | V2 adds safety inset |
| **ExhaustionLevelFillBar** | 0x11 (animated width) | 0x10 (animated width) | V2 is 1px taller |
| **QuestOverlays** | 0x11 (animated width) | 0x10 (animated width) | V2 is 1px taller |
| **ExhaustionTick** | 10x14 | 10x14 | Same |
| **BorderFrame/Texture** | 571x17 (atlas native) | 571x17 (atlas native) | Same |
| **FlashFrame/Texture** | ~565x11 (matches StatusBar) | 565x11 (fills bar frame) | Effectively same coverage |
| **OverlayTextContainer** | 571x11 (explicit) | 565x11 (setAllPoints on bar) | V2 is 6px wider |
| **BelowTextContainer** | 565x30 (explicit) | Variable (template) | Both use same template |

### Effective Visual Sizes

| Visual Element | V2 Visible Area | V1 Visible Area | Delta |
|----------------|-----------------|-----------------|-------|
| **Total Frame** | 571x17 | 571x17 | ✅ Same |
| **XP Fill Bar** | ~565x11 | 565x10 | V2 is 1px taller |
| **Border** | 571x17 | 571x17 | ✅ Same |
| **Rested Overlay** | 0-565 x 11 | 0-565 x 10 | V2 is 1px taller |
| **Flash Effect** | ~565x11 | 565x11 | ✅ Same |
| **Text Area (on-bar)** | 571x11 | 565x11 | V2 is 6px wider (centered) |

### Position Offsets

| Element | V2 Offset from Main | V1 Offset from Container | Calculation |
|---------|---------------------|--------------------------|-------------|
| **StatusBar Top-Left** | (3, -3) | (1, 5) | V2: 3px right, 3px down; V1: 1px right, 5px up |
| **StatusBar Bottom-Right** | (-3, 3) | (566, 15) | V2: 3px from edges; V1: explicit container position |
| **Border** | (0, 0) centered | (0, 0) fills container | V2 and V1 both fill their respective frames |
| **Flash** | (3, -3) matches StatusBar | (0, 0) fills bar frame | V2 inset, V1 fills |
| **On-Bar Text** | (0, 0) centered | (0, 0) setAllPoints | V2 centered on main, V1 fills bar |

### Critical Dimensions

```
V2 LAYOUT:
┌─────────────────────────────────────┐
│ Main Frame: 571x17                   │ (config-driven)
│ ┌─────────────────────────────────┐ │
│ │ StatusBar: ~565x11 at (3,-3)     │ │ (anchor-based)
│ │ ┌─────────────────────────────┐ │ │
│ │ │ Background: ~563x10 (inset) │ │ │ (1px inset within StatusBar)
│ │ └─────────────────────────────┘ │ │
│ │ Flash: ~565x11 at (3,-3)        │ │ (matches StatusBar)
│ └─────────────────────────────────┘ │
│ Border: 571x17 MEDIUM strata        │ (separate frame, full size)
└─────────────────────────────────────┘

V1 LAYOUT:
┌─────────────────────────────────────┐
│ Container: 571x17                    │ (explicit)
│ Border: 571x17 OVERLAY layer        │ (container layer)
│ ┌─────────────────────────────────┐ │
│ │ Bar: 565x11 at (1,5)            │ │ (explicit, positioned in container)
│ │ Flash: 565x11 OVERLAY layer     │ │ (bar frame layer)
│ │ ┌─────────────────────────────┐ │ │
│ │ │ StatusBar: 565x10 at (0,0)  │ │ │ (explicit, bottom-aligned in bar)
│ │ │ Background: 565x10 (fills)  │ │ │ (fills StatusBar)
│ │ └─────────────────────────────┘ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## POSITIONING COMPARISON TABLE

| Element | V2 Position | V1 Position | Delta |
|---------|-------------|-------------|-------|
| **Main Frame** | Size from config (571x17) | Container: 571x17 explicit | Same effective size |
| **StatusBar** | Anchors: TOPLEFT (3,-3), BOTTOMRIGHT (-3,3) | Size: 565x10, Position: BOTTOMLEFT (0,0) | V2 uses insets, V1 explicit size |
| **Background Texture** | TOPLEFT (1,0), BOTTOMRIGHT (-1,1) within StatusBar | TOPLEFT, BOTTOMRIGHT (fills StatusBar) | V2 adds 1px inset |
| **Flash** | FlashFrame at (3,-3) inset, OVERLAY layer | Bar frame layer OVERLAY sub=3 | V2 separate frame, same coverage |
| **Border** | BorderFrame MEDIUM strata, centered atlas | Container OVERLAY layer, useAtlasSize | V2 separate frame vs container layer |
| **On-Bar Text** | OverlayFrameTextContainer centered (0,0) | OverlayFrame setAllPoints on bar | V2 centered, V1 fills bar |
| **ExhaustionTick** | CENTER of ExhaustionLevelFillBar RIGHT | Same | Identical |

---

## ISSUES & SOLUTIONS

### Issue 1: Flash Not Visible
**Problem**: FlashFrame originally at HIGH strata rendered above border  
**Solution**: Changed FlashFrame to LOW strata with same insets as StatusBar  
**Result**: Flash visible above StatusBar but under BorderFrame (MEDIUM)

### Issue 2: Background Bleeding Outside Border
**Problem**: StatusBar Background texture extending beyond visible bar area  
**Solution**: Added 1px inset to Background anchors: TOPLEFT (1,0), BOTTOMRIGHT (-1,1)  
**Result**: Background stays within border frame

### Issue 3: Border Size Mismatch
**Problem**: V2 border appeared smaller than V1  
**Solution**: Used `useAtlasSize="true"` and centered atlas to match native size  
**Result**: Border matches V1 appearance

---

## RECOMMENDATIONS

### For Consistency with V1:
1. ✅ Use same StatusBar size (565x11 effective area)
2. ✅ Position flash to cover StatusBar but not border
3. ✅ Use MEDIUM strata for border to overlay StatusBar
4. ✅ Keep ExhaustionTick at MEDIUM for hover interaction

### For Performance:
- V2's separate FlashFrame is clean but adds one more frame
- V1's layer-based flash is more efficient
- Consider: Move flash back to main frame layers if strata ordering allows

### For Maintainability:
- V2's explicit BorderFrame is clearer than V1's container layer
- Separate FlashFrame makes animation logic cleaner
- Current architecture is more modular for future changes
