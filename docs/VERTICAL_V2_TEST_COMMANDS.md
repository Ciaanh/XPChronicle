# Vertical Bar  Test Commands

## Overview

Test commands have been added to create and test the Vertical Bar  implementation without needing to integrate it into the main addon yet.

## Test Commands

### Create Vertical Bar
```
/xptest vertical
```
Creates a test instance of the Vertical Bar  with:
- Full animation support (AnimationManager + gravity)
- Observer pattern registration
- Live XP tracking
- Gravity animation with particle effects

The frame will be stored globally as `VerticalBar` for easy access.

### Destroy Vertical Bar
```
/xptest verticaldestroy
```
Cleanup and remove the vertical bar test frame:
- Unregisters from observer pattern
- Cleans up event handlers
- Hides and removes frame
- Clears global reference

### Test Animation
```
/xptest flash
```
Triggers an XP gain flash animation on any active test bar (including vertical). This will trigger:
- Standard flash effect (via AnimationManager)
- Gravity animation (falling XP segment)
- Particle effects (8 particles on impact)
- Bounce effect (5px upward, 0.1s)

### View Context
```
/xptest context
```
Prints current XP context information including:
- Current/Max XP
- Rested XP
- Quest overlay status
- Level information

### Help
```
/xptest help
```
Shows all available test commands.

## Test Workflow

1. **Create the bar:**
   ```
   /xptest vertical
   ```

2. **Observe initial state:**
   - Bar appears on screen (default: left-center)
   - Shows current XP progress
   - Vertical orientation (60x300 pixels)

3. **Test gravity animation:**
   ```
   /xptest flash
   ```
   Or gain actual XP in-game (kill mob, complete quest, etc.)

4. **Observe animations:**
   - XP segment "falls" from top (0.4s duration)
   - Particles scatter on impact (8 particles)
   - Bounce effect (5px up, settles back)
   - Flash overlay (standard AnimationManager)

5. **Test positioning:**
   - Shift+Left-Click and drag to move
   - Position should persist across /reload

6. **Test multi-instance:**
   ```
   /xptest create   (flat bar)
   /xptest vertical (vertical bar)
   ```
   Both bars should update simultaneously on XP gains.

7. **Cleanup:**
   ```
   /xptest verticaldestroy
   ```

## Implementation Details

### Files Modified

1. **`ui/xpbars/tests/test.lua`**
   - Added `CreateVerticalTestBar()` function (55 lines)
   - Added `DestroyVerticalTestBar()` function (25 lines)
   - Exported to `Addon.Tests` namespace

2. **`core/Core.lua`**
   - Added `/xptest vertical` command handler
   - Added `/xptest verticaldestroy` command handler
   - Updated help text

### Frame Creation

The test uses `XPBarStyleBuilder:CreateFrameForStyle()`:
```lua
frame = XPBarStyleBuilder:CreateFrameForStyle("vertical", nil, "VerticalBarTemplate")
```

This requires:
- `VerticalBarStyle.lua` to be loaded (style registration)
- `VerticalBarTemplate` template defined in XML
- StyleBuilder to be initialized

### Observer Pattern

The test bar registers as an observer:
```lua
VerticalTestObserverId = Addon.XPBar:RegisterObserver(frame, "vertical_test")
```

This means:
- Bar receives XP updates automatically
- Works alongside other bars (multi-instance)
- Clean separation from main bar controller

### Global Access

Test frame is stored globally:
```lua
_G.VerticalBar = frame
```

You can access it directly for debugging:
```lua
/dump VerticalBar
/dump VerticalBar.gravityState
/dump VerticalBar.animation
```

## Testing Checklist

### Visual Tests
- [ ] Bar fills from bottom to top
- [ ] Falling segment appears at top
- [ ] Falling segment animates to current position
- [ ] Particles spawn at impact point
- [ ] Particles scatter in 360° pattern
- [ ] Bounce effect visible
- [ ] Flash overlay shows on XP gain

### Animation Tests
- [ ] Gravity timing correct (0.4s fall)
- [ ] Particle lifetime correct (0.5s)
- [ ] Bounce timing correct (0.1s)
- [ ] Flash timing correct (0.5s via AnimationManager)
- [ ] No animation conflicts
- [ ] Smooth retargeting on rapid XP gains

### Performance Tests
- [ ] FPS ≥ 60 during animations
- [ ] No memory leaks (check after 30 mins)
- [ ] OnUpdate pauses when not falling
- [ ] Particles cleanup properly

### Integration Tests
- [ ] Works alongside flat bar
- [ ] Position saves/loads correctly
- [ ] Drag-to-move works (Shift+drag)
- [ ] Colors match config
- [ ] Text displays correctly

## Known Limitations

1. **Requires style registration:** The vertical bar style must be registered with StyleBuilder before the test command works.

2. **Template must exist:** The `VerticalBarTemplate` XML template must be loaded via TOC/Frames.xml.

3. **Dev mode only:** Test commands are intended for development/testing, not production use.

## Next Steps

Once testing is complete:

1. Add vertical includes to TOC file
2. Add vertical template to Frames.xml
3. Verify auto-registration on load
4. Run full validation checklist
5. Document any issues found
6. Update migration plan status

---

**Created:** November 9, 2025  
**Status:** Test commands ready for use  
**Related:** VERTICAL_MIGRATION.md
