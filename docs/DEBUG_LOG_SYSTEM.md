# XPBarEnhanced Debug Log System

## Overview

The debug log system captures all initialization and animation flow logs into a circular buffer that can be dumped on demand via chat commands. This is essential for troubleshooting initialization issues and animation problems in  bars.

## Features

- **Circular buffer**: Stores last 500 log entries automatically
- **Timestamped entries**: Each log has precise timing (GetTime())
- **Categorized logs**: Logs are tagged by component (BaseMixin, CircularBar, ClassicBar, Animation)
- **Chat commands**: Easy dump and management via `/xpbdebug` or `/xpbd`
- **Zero performance impact when disabled**: Can be toggled on/off

## Chat Commands

```
/xpbdebug help            - Show all available commands
/xpbdebug dump            - Dump ALL logs to chat (may be long!)
/xpbdebug recent [N]      - Dump last N logs (default: 20)
/xpbdebug clear           - Clear the log buffer
/xpbdebug enable          - Enable debug logging
/xpbdebug disable         - Disable debug logging
/xpbdebug stats           - Show buffer statistics

Alias: /xpbd              - Short form of /xpbdebug
```

## Usage Workflow

### 1. Enable Debug Logging (if needed)
```
/xpbd enable
```

### 2. Trigger the Issue
- For initialization issues: `/reload`
- For animation issues: Kill a mob to gain XP

### 3. Dump Recent Logs
```
/xpbd recent 50
```
This shows the last 50 log entries, which should capture the entire initialization or animation sequence.

### 4. Analyze the Output

Look for the following sequences:

#### Normal Initialization Flow (Circular ):
```
[time] [BaseMixin] OnLoad called
[time] [BaseMixin] OnLoad calling initial Refresh
[time] [BaseMixin] Refresh called
[time] [BaseMixin] Refresh context built: true
[time] [BaseMixin] TriggerBarRefresh called
[time] [BaseMixin] TriggerBarRefresh calling RenderBar
[time] [CircularBar] RenderBar called
[time] [CircularBar] RenderBar shouldAnimate: false
[time] [CircularBar] RenderBar instant update, calling RenderBarFrame
[time] [CircularBar] RenderBarFrame called with ratio: 0.45
[time] [CircularBar] SetArcProgress called with progress 0.45
```

#### Normal Animation Flow (Classic/FlatBar/Vertical ):
```
[time] [ClassicBar] RenderBar called
[time] [ClassicBar] RenderBar shouldAnimate: true
[time] [ClassicBar] RenderBar starting animation
[time] [ClassicBar] RenderBar config.enableAnimations: true
[time] [AnimationBase] StartAnimation called for ClassicBar targetRatio: 0.52 enableAnimations: true
[time] [AnimationBase] StartAnimation delegating to AnimationManager
[time] [AnimationBase] ApplyAnimationStep called for ClassicBar
[time] [AnimationBase] ApplyAnimationStep called for ClassicBar
... (repeated per frame)
```

### 5. Clear Buffer (optional)
```
/xpbd clear
```

## Log Categories

| Category | Component | What it logs |
|----------|-----------|--------------|
| `BaseMixin` | Base  functionality | OnLoad, Refresh, TriggerBarRefresh calls |
| `CircularBar` | Circular  style | RenderBar, RenderBarFrame, SetArcProgress, AnimateBarPosition |
| `ClassicBar` | Classic  style | RenderBar, RenderBarFrame |
| `VerticalBar` | Vertical  style | RenderBar, RenderBarFrame |
| `FlatBar` | FlatBar  style | RenderBar, RenderBarFrame |
| `AnimationBase` | Animation mixin | StartAnimation, ApplyAnimationStep |
| `AnimationManager` | Animation driver | AnimateTo, OnUpdate (if added) |

## Troubleshooting Common Issues

### Issue: Circular  bar not displaying on load

**Expected logs:**
- `[CircularBar] RenderBar called`
- `[CircularBar] RenderBar shouldAnimate: false`
- `[CircularBar] RenderBarFrame called with ratio: X`
- `[CircularBar] SetArcProgress called with progress X`

**If missing:**
- Check if `[BaseMixin] OnLoad called` appears → If not, XML template issue
- Check if `[BaseMixin] TriggerBarRefresh calling RenderBar` appears → If not, RenderBar method not implemented
- Check if `shouldAnimate` is `true` instead of `false` → Context builder issue

### Issue: Classic/FlatBar/Vertical  XP gains not animated

**Expected logs:**
- `[ClassicBar] RenderBar shouldAnimate: true`
- `[ClassicBar] RenderBar config.enableAnimations: true`
- `[AnimationBase] StartAnimation called`
- `[AnimationBase] ApplyAnimationStep called` (repeated multiple times)

**If missing animation:**
- Check `shouldAnimate` flag → Should be `true` for XP gain events
- Check `config.enableAnimations` → Should be `true` (check DefaultConfig in style file)
- If StartAnimation called but no ApplyAnimationStep → AnimationManager issue

## Integration Points

The debug log is integrated at these key points:

1. **BaseMixin.lua**:
   - `OnLoad()` - Bar initialization
   - `Refresh()` - Manual refresh
   - `TriggerBarRefresh()` - Render dispatch

2. **CircularBarStyle.lua**:
   - `OnLoad()` - Style-specific init
   - `RenderBar()` - Render decision
   - `RenderBarFrame()` - Actual rendering
   - `SetArcProgress()` - Segment calculation
   - `AnimateBarPosition()` - Animation callback

3. **ClassicBarStyle.lua** (and other  styles):
   - `RenderBar()` - Render decision
   - `RenderBarFrame()` - Actual rendering

4. **AnimationBase.lua**:
   - `StartAnimation()` - Animation start
   - `ApplyAnimationStep()` - Per-frame callback

## Memory Usage

- Each log entry: ~100 bytes (timestamp + category + message)
- Buffer capacity: 500 entries
- Total memory: ~50 KB (negligible)

The circular buffer automatically overwrites old entries, so memory usage is constant.

## Performance

- **When enabled**: Minimal overhead (string formatting + table insert)
- **When disabled**: Zero overhead (early return in Log() method)
- **Recommendation**: Enable only when troubleshooting

## Future Enhancements

Potential additions:
- Export logs to SavedVariables for bug reports
- Filter logs by category
- Highlight errors/warnings
- Automatic capture on errors
- Integration with Logger.lua for unified logging
