# XP Bar Enhanced

**Version:** 2.0.0  
**Author:** Ciaanh

An enhanced XP bar addon for World of Warcraft that tracks quest XP, leveling statistics, and provides detailed progress information.

> **Note:** Inspired by Luxthos - Experience Bar which I used a lot but I decided to make it a standalone addon when it was announced that WeakAura will not have a version for Midnight.

## Architecture

For detailed information about the addon's architecture, event flow, and module interactions, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Features

### XP Bar Display
- **Two Bar Styles**: Choose between Legacy (Blizzard-style) or Flat (modern, draggable) XP bar
- **Quest XP Overlays**: Visual indicators showing XP from completed quests
- **Rested XP Visualization**: Clear display of rested bonus
- **Real-time Updates**: Smooth bar animations on XP gain
- **Comprehensive Tooltip**: Hover for detailed XP info, time estimates, and quest summary

### Statistics Tracking
- **Session Statistics**: Track XP/hour, kills, quests completed, and session duration
- **Level Progress**: XP to next level, kills needed, quests needed
- **Historical Data**: Persistent tracking across sessions
- **Dual-Page Display**: Separate views for level stats and session stats

### Customization
- **Fully Configurable Colors**: Customize all bar elements (XP, rested, background, quest overlays)
- **Text Display Options**: Show/hide level, XP amount, percentage, XP rate, session time
- **Bar Style Selection**: Switch between Legacy and Flat styles on the fly
- **Position Control**: Draggable bars with position persistence

### User Controls
- **Ctrl+Drag**: Move frames (Flat bar, Stats window)
- **Alt+Click**: Open options panel
- **Ctrl+Click**: Toggle statistics window
- **Slash Commands**: Full command-line control

## Installation

1. Download the addon
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/XPBarEnhanced/`
3. Restart World of Warcraft or type `/reload`
4. Configure via `/xpbe options`

## Usage

### Basic Operations

**Open Options Panel:**
- Game Menu → Interface → AddOns → XP Bar Enhanced
- Alt+Click on XP bar
- Type `/xpbe options`

**Toggle Statistics Window:**
- Ctrl+Click on XP bar
- Type `/xpbe stats`

**Move Frames:**
- Hold Ctrl and drag the Flat XP bar or Stats window

**Reset Settings:**
- Type `/xpbe reset` (requires confirmation)

### Slash Commands

| Command | Description |
|---------|-------------|
| `/xpbe` | Show help |
| `/xpbe help` | Show command list |
| `/xpbe options` | Open options panel |
| `/xpbe stats` | Toggle statistics window |
| `/xpbe reset` | Reset all settings to defaults |

### Configuration Options

**Bar Style:**
- Legacy: Traditional Blizzard-style bar (replaces default XP bar)
- Flat: Modern, draggable bar with independent positioning

**Display Elements:**
- Show/hide level number
- Show/hide XP amount (current/max)
- Show/hide percentage
- Show/hide XP rate (XP per hour)
- Show/hide session time
- Show/hide quest XP overlays

**Colors:**
- XP bar color
- Rested XP color
- Background color
- Quest overlay colors (up to 10 quests)
- All colors customizable via color picker

**Bar Behavior:**
- Hide Blizzard default XP bar
- Lock bar position (prevent dragging)
- Bar visibility settings

## Architecture

XPBarEnhanced follows a **feature-based modular architecture**:

```
Core Layer (Foundation)
  ↓
UI Common Layer (Shared Utilities)
  ↓
Feature Modules (XP Bar, Stats, Options)
```

**See [ARCHITECTURE.md](ARCHITECTURE.md)** for complete technical documentation.

### Contributing

Contributions are welcome! Please:
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the design
2. Follow the feature-based module pattern
3. Test thoroughly before submitting
4. Update documentation for significant changes

### Adding a New Bar Style

1. Create `ui/xpbar/NewStyleMixin.lua`
2. Extend `XPBarMixinBase`
3. Implement required methods: `Initialize()`, `Update()`, `ApplyBarColor()`
4. Create XML template: `ui/xpbar/NewStyle.xml`
5. Register in `XPBar.lua`: `barStyles.newstyle = "NewStyleMixin"`
6. Add option to `Config.lua` defaults

## Requirements

- **WoW Version:** Retail (The War Within and later)
- **Dependencies:** None (includes required libraries)

## Credits

**Inspired by:**
- Luxthos - Experience Bar (WeakAura)

**Libraries Used:**
- AceLocale-3.0
- LibStub

## License

MIT License - See [LICENSE](LICENSE) file for details

## Support

- **Issues:** GitHub Issues
- **Documentation:** See `docs/` directory
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)

## Author

**Ciaanh**

---

**Version:** 1.0.0  
**Status:** Stable  
**Last Updated:** October 16, 2025
