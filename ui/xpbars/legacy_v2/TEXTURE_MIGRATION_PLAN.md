# Legacy Bar V2 - Custom Texture Migration Plan

## Current State Analysis

### Current Textures in Legacy Bar V2

| Element | Current Texture | Location |
|---------|----------------|----------|
| **StatusBar Fill** | `Interface\TargetingFrame\UI-StatusBar` | Line 21 (BarTexture) |
| **Background** | `atlas="UI-HUD-ExperienceBar-Background"` | Line 26 |
| **Border** | `atlas="UI-HUD-ExperienceBar-Frame"` | Line 177 |
| **Exhaustion Tick** | `atlas="UI-HUD-ExperienceBar-Frame-Pip"` | Line 78 |
| **Tick Highlight** | `atlas="UI-HUD-ExperienceBar-Frame-Pip-Mouseover"` | Line 79 |
| **Overlays** | `Interface\Buttons\WHITE8X8` | Lines 37, 47, 57 (Rested, Quest Complete, Quest Incomplete) |

### Available Custom Assets

Located in `assets/` folder:

| File | Purpose | Expected Usage |
|------|---------|----------------|
| `StatusBar.png` | StatusBar fill texture | Replace `Interface\TargetingFrame\UI-StatusBar` |
| `legacy-background.png` | StatusBar background | Replace `UI-HUD-ExperienceBar-Background` atlas |
| `legacy-border.png` | Border frame | Replace `UI-HUD-ExperienceBar-Frame` atlas |
| `Tick.png` | Exhaustion tick normal | Replace `UI-HUD-ExperienceBar-Frame-Pip` atlas |
| `Tick-highlight.png` | Exhaustion tick mouseover | Replace `UI-HUD-ExperienceBar-Frame-Pip-Mouseover` atlas |
| `border.png` | (Unknown usage) | Possibly alternative border? |
| `center.png` | (Unknown usage) | Possibly center decoration? |
| `glow.png` | (Unknown usage) | Possibly glow effect? |

---

## Migration Plan

### Phase 1: Replace StatusBar Fill Texture

**Current:**
```xml
<BarTexture file="Interface\TargetingFrame\UI-StatusBar"/>
```

**Change to:**
```xml
<BarTexture file="Interface\AddOns\XPBarEnhanced\assets\StatusBar"/>
```

**Impact:**
- Changes the visual appearance of the XP bar fill
- May affect how colors are rendered (depending on texture design)
- No size changes needed

---

### Phase 2: Replace Background Texture

**Current:**
```xml
<Texture parentKey="Background" atlas="UI-HUD-ExperienceBar-Background">
    <Anchors>
        <Anchor point="TOPLEFT"/>
        <Anchor point="BOTTOMRIGHT"/>
    </Anchors>
</Texture>
```

**Change to:**
```xml
<Texture parentKey="Background" file="Interface\AddOns\XPBarEnhanced\assets\legacy-background">
    <Anchors>
        <Anchor point="TOPLEFT"/>
        <Anchor point="BOTTOMRIGHT"/>
    </Anchors>
</Texture>
```

**Impact:**
- No longer uses Blizzard atlas
- Background will use custom texture
- May need to verify texture coordinates if tiling is needed
- Anchors remain the same (fills StatusBar)

**Important Note:**
When switching from atlas to file, remove `atlas=` and `useAtlasSize` attributes, use `file=` instead.

---

### Phase 3: Replace Border Texture

**Current:**
```xml
<Texture parentKey="Texture" atlas="UI-HUD-ExperienceBar-Frame" useAtlasSize="true">
    <Anchors>
        <Anchor point="CENTER"/>
    </Anchors>
</Texture>
```

**Change to:**
```xml
<Texture parentKey="Texture" file="Interface\AddOns\XPBarEnhanced\assets\legacy-border">
    <Anchors>
        <Anchor point="CENTER"/>
    </Anchors>
</Texture>
```

**Impact:**
- Border will use custom texture
- **CRITICAL**: Need to verify border texture dimensions match expected size (571x17)
- May need to add explicit size if `useAtlasSize` was auto-sizing
- Recommend adding `<Size x="571" y="17"/>` if texture doesn't auto-size correctly

**Potential Issue:**
If `legacy-border.png` has different dimensions than the Blizzard atlas, the border may not align properly with the StatusBar. Test carefully.

---

### Phase 4: Replace Exhaustion Tick Textures

**Current:**
```xml
<NormalTexture parentKey="Normal" atlas="UI-HUD-ExperienceBar-Frame-Pip"/>
<HighlightTexture parentKey="Highlight" atlas="UI-HUD-ExperienceBar-Frame-Pip-Mouseover" alphaMode="ADD"/>
```

**Change to:**
```xml
<NormalTexture parentKey="Normal" file="Interface\AddOns\XPBarEnhanced\assets\Tick"/>
<HighlightTexture parentKey="Highlight" file="Interface\AddOns\XPBarEnhanced\assets\Tick-highlight" alphaMode="ADD"/>
```

**Impact:**
- Tick appearance will use custom textures
- **CRITICAL**: Verify tick size matches Button size (10x14)
- Blizzard atlases auto-size; custom files may need explicit sizing

**Potential Issue:**
If tick textures are different dimensions, add `useAtlasSize="false"` and ensure Button size (10x14) is correct.

---

## Implementation Steps

### Step 1: Backup Current Template
Create backup of `LegacyBarTemplate.xml` before making changes.

### Step 2: Test Texture Loading
Before full migration, test that WoW can load the custom textures:
```lua
-- Test in-game with /run
local t = UIParent:CreateTexture()
t:SetTexture("Interface\\AddOns\\XPBarEnhanced\\assets\\StatusBar")
print("Texture loaded:", t:GetTexture())
```

### Step 3: Update XML (Sequential Changes)

**Change Order (Recommended):**

1. **StatusBar Fill** (lowest risk)
   - Line 21: Change BarTexture
   - Test: `/reload` and verify bar appears correctly

2. **Background** (low risk)
   - Line 26: Change Background texture from atlas to file
   - Test: Verify background appears behind bar fill

3. **Exhaustion Tick** (medium risk)
   - Lines 78-79: Change tick textures
   - Test: Gain rested XP and verify tick appears

4. **Border** (highest risk - most visible)
   - Line 177: Change border from atlas to file
   - Test: Verify border frames bar correctly and doesn't clip

### Step 4: Size Verification

After each change, verify:
- Bar dimensions: 563x11 (StatusBar)
- Frame dimensions: 571x17 (Main frame)
- Tick dimensions: 10x14 (Exhaustion tick)
- Border dimensions: Should match frame (571x17)

### Step 5: Test Scenarios

1. **Basic Display**
   - Bar shows correctly at various XP levels
   - Background visible
   - Border frames everything correctly

2. **Rested XP**
   - Rested overlay renders correctly
   - Exhaustion tick appears at correct position
   - Tick highlight shows on mouseover

3. **Quest Overlays**
   - Complete quest overlay visible
   - Incomplete quest overlay visible
   - Overlays positioned correctly over StatusBar

4. **Flash Effect**
   - XP gain flash appears on top of bar
   - Flash under border (correct layering)

5. **Text Rendering**
   - On-bar text readable
   - Below-bar text positioned correctly

---

## Texture File Path Format

WoW expects textures without file extensions in XML:

**Correct:**
```xml
file="Interface\AddOns\XPBarEnhanced\assets\StatusBar"
```

**Incorrect:**
```xml
file="Interface\AddOns\XPBarEnhanced\assets\StatusBar.png"
```

WoW automatically appends `.blp` or tries `.png`/`.tga` depending on client version.

---

## Potential Issues & Solutions

### Issue 1: Texture Not Loading
**Symptom:** Bar appears blank or uses fallback texture

**Solutions:**
1. Verify file path uses backslashes `\`
2. Verify file exists in assets folder
3. Verify file extension is `.png` or `.blp`
4. Check for typos in filename

### Issue 2: Border Misalignment
**Symptom:** Border doesn't frame StatusBar correctly

**Solutions:**
1. Add explicit size to border texture:
   ```xml
   <Texture parentKey="Texture" file="...">
       <Size x="571" y="17"/>
   ```
2. Adjust border position with x/y offsets in anchor
3. Verify custom border texture dimensions match expected size

### Issue 3: Tick Wrong Size
**Symptom:** Exhaustion tick appears too large/small

**Solutions:**
1. Add explicit size to textures:
   ```xml
   <NormalTexture file="..." useAtlasSize="false">
       <Size x="10" y="14"/>
   </NormalTexture>
   ```
2. Adjust Button size to match texture
3. Rescale texture file if necessary

### Issue 4: Colors Not Applying
**Symptom:** StatusBar color customization not working

**Solutions:**
1. Verify custom StatusBar.png supports color tinting
2. Check texture uses appropriate blend mode
3. May need to change texture from RGB to grayscale for tinting

### Issue 5: Background Tiling
**Symptom:** Background texture repeats or stretches incorrectly

**Solutions:**
1. Add texture coordinates:
   ```xml
   <TexCoords left="0" right="1" top="0" bottom="1"/>
   ```
2. Ensure texture dimensions match StatusBar (563x11)
3. Use `horizTile` or `vertTile` if intentional tiling needed

---

## Unknown Assets Investigation

Three assets have unclear purposes:
- `border.png` - May be alternative border design
- `center.png` - May be center decoration or divider
- `glow.png` - May be glow effect for XP gains or level-ups

**Recommendations:**
1. Examine files visually to determine purpose
2. Check original design docs or reference materials
3. Consider if these are for future features
4. May be used for V1 or other bar styles

---

## Rollback Plan

If migration causes issues:

1. Keep backup of original template
2. Revert changes in reverse order (border → tick → background → statusbar)
3. Use version control (git) to track changes
4. Document each change for easier debugging

---

## Testing Checklist

After full migration:

- [ ] StatusBar displays at 0% XP
- [ ] StatusBar displays at 50% XP
- [ ] StatusBar displays at 100% XP
- [ ] Background visible behind bar
- [ ] Border frames bar correctly
- [ ] No gaps between border and bar
- [ ] Rested XP overlay shows when rested
- [ ] Exhaustion tick appears when rested
- [ ] Tick highlight works on mouseover
- [ ] Tick tooltip appears
- [ ] Quest complete overlay works
- [ ] Quest incomplete overlay works
- [ ] Flash effect appears on XP gain
- [ ] Flash renders under border
- [ ] On-bar text readable
- [ ] Below-bar text positioned correctly
- [ ] Colors apply correctly to bar
- [ ] Bar scales correctly at different UI scales
- [ ] No texture errors in BugSack

---

## File Changes Summary

**Files to Modify:**
- `ui/xpbars/legacy_v2/LegacyBarTemplate.xml`

**Lines to Change:**
- Line 21: BarTexture file path
- Line 26: Background texture (atlas → file)
- Line 78: Exhaustion tick normal texture (atlas → file)
- Line 79: Exhaustion tick highlight texture (atlas → file)  
- Line 177: Border texture (atlas → file)

**Total Changes:** 5 texture replacements

**Estimated Time:** 30-60 minutes (including testing)

**Risk Level:** Low-Medium (mostly visual changes, no logic changes)

---

## Next Steps

1. **Review assets folder** - Visually inspect all texture files
2. **Decide on implementation approach**:
   - Option A: Change all textures at once (faster but harder to debug)
   - Option B: Change one at a time with testing (slower but safer)
3. **Create backup** of LegacyBarTemplate.xml
4. **Begin implementation** following steps above
5. **Test thoroughly** with checklist
6. **Document** any issues or adjustments needed

---

## Questions to Resolve

1. What are `border.png`, `center.png`, and `glow.png` for?
2. Do custom textures match expected dimensions?
3. Do custom textures support color tinting?
4. Should V1 Legacy Bar also use these textures?
5. Are there performance considerations with custom textures vs atlases?

