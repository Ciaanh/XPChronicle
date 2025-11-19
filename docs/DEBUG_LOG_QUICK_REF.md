# Debug Log Quick Reference

## Quick Start

```
/reload                    # Trigger initialization
/xpbd recent 30           # Show last 30 logs
```

## Common Commands

| Command | Description |
|---------|-------------|
| `/xpbd recent 20` | Show last 20 logs (default) |
| `/xpbd dump` | Show ALL logs (may be very long!) |
| `/xpbd clear` | Clear the buffer |
| `/xpbd stats` | Show buffer info |
| `/xpbd enable` | Turn on logging |
| `/xpbd disable` | Turn off logging |

## What to Look For

### Circular  Not Displaying

**Check this sequence:**
1. `[BaseMixin] OnLoad called` ✓
2. `[BaseMixin] Refresh called` ✓
3. `[CircularBar] RenderBar called` ✓
4. `[CircularBar] RenderBarFrame called` ✓
5. `[CircularBar] SetArcProgress called` ✓

**Missing any? → That's where it breaks!**

### Classic/FlatBar/Vertical Not Animating

**Check this sequence:**
1. `[ClassicBar] RenderBar shouldAnimate: true` ✓
2. `[ClassicBar] RenderBar config.enableAnimations: true` ✓
3. `[AnimationBase] StartAnimation called` ✓
4. `[AnimationBase] ApplyAnimationStep called` (multiple times) ✓

**If shouldAnimate is false → Check ContextBuilder**
**If enableAnimations is false → Check DefaultConfig**
**If ApplyAnimationStep not called → Check AnimationManager**

## Log Format

```
[time] [Category] Message value1, value2
```

Example:
```
[123.456] [CircularBar] RenderBar shouldAnimate: false
```

- **time**: Game time since login (GetTime())
- **Category**: Component name (BaseMixin, CircularBar, etc.)
- **Message**: What happened
- **values**: Additional data

## Buffer Info

- **Capacity**: 500 entries
- **Type**: Circular (auto-overwrites old entries)
- **Memory**: ~50 KB
- **Performance**: Minimal when enabled, zero when disabled
