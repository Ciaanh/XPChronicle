# XP Chronicle - Architecture Documentation

## Overview

XP Chronicle is a World of Warcraft addon that provides an enhanced experience tracking interface with two visual styles: Legacy (Blizzard-style) and Flat (modern, minimalist). The addon features comprehensive XP tracking, quest overlay visualization, session statistics, and extensive customization options.

## Core Architecture

### Layer Structure

```
┌─────────────────────────────────────────┐
│           User Interface                │
│  (XML Templates + Lua Mixins)           │
├─────────────────────────────────────────┤
│         Feature Controllers             │
│  (XPBar, Options, Stats)                │
├─────────────────────────────────────────┤
│            Services Layer               │
│  (Session, TimePlayed, LevelHistory,    │
│   QuestXP, EventSystem)                 │
├─────────────────────────────────────────┤
│          Core Foundation                │
│  (Addon, Config, SavedVariables,        │
│   Defaults, Locale, Logger, Utils)      │
└─────────────────────────────────────────┘
```

## Directory Structure

```
XPChronicle/
├── app/
│   ├── core/              # Foundation layer
│   │   ├── Addon.lua      # Main addon namespace and initialization
│   │   ├── Config.lua     # Configuration management
│   │   ├── Defaults.lua   # Default values
│   │   ├── Locale.lua     # Localization system
│   │   ├── Logger.lua     # Logging utility
│   │   ├── SavedVariables.lua  # Save/load system
│   │   └── Utils.lua      # General utilities
│   │
│   ├── config/            # Configuration management
│   │   ├── Config.lua     # Main config interface
│   │   ├── OptionsMetadata.lua  # Options schema
│   │   └── SlashCommands.lua    # Slash command handlers
│   │
│   ├── features/          # Feature controllers
│   │   ├── options/       # Options panel controller
│   │   ├── stats/         # Statistics controller
│   │   └── xpbar/         # XP bar controller
│   │
│   └── services/          # Service layer
│       ├── EventSystem.lua       # Event bus
│       ├── LevelHistoryService.lua  # Level tracking
│       ├── QuestXPService.lua    # Quest XP calculation
│       ├── SessionService.lua    # Session management
│       └── TimePlayedService.lua # Time tracking
│
├── ui/                    # User interface layer
│   ├── xpbar/             # XP bar components
│   │   ├── FlatXPBar.xml          # Flat bar template
│   │   ├── FlatXPBarMixin.lua     # Flat bar behavior
│   │   ├── LegacyXPBar.xml        # Legacy bar template
│   │   ├── LegacyXPBarMixin.lua   # Legacy bar behavior
│   │   ├── XPBarColors.lua        # Color management
│   │   ├── XPBarMixinBase.lua     # Shared bar logic
│   │   ├── XPBarTextFormatter.lua # Text formatting
│   │   ├── XPBarTooltip.lua       # Tooltip system
│   │   └── XPBarView.lua          # View coordinator
│   │
│   ├── options/           # Options panel UI
│   ├── stats/             # Statistics frame UI
│   ├── components/        # Reusable UI components
│   └── mixins/            # UI behavior mixins
│
├── locales/               # Localization files
│   └── enUS.lua
│
└── libs/                  # Third-party libraries
    ├── LibStub/
    └── AceLocale-3.0/
```

## Key Components

### 1. XP Bar System

#### Bar Styles

**Legacy Bar (Blizzard-style)**
- Location: `ui/xpbar/LegacyXPBar.xml` + `LegacyXPBarMixin.lua`
- Features: Traditional Blizzard appearance, rested XP marker, quest overlays
- Dimensions: 565x11 pixels
- Position: Fixed at bottom center of screen
- Customization: Fully user-configurable colors via color picker

**Flat Bar (Modern style)**
- Location: `ui/xpbar/FlatXPBar.xml` + `FlatXPBarMixin.lua`
- Features: Clean design, draggable, quest overlays, text below bar
- Dimensions: 565x30 pixels
- Position: User-adjustable (Shift+Drag to move)
- Customization: Fully user-configurable colors via color picker

#### Shared Systems

**XPBarMixinBase** (`ui/xpbar/XPBarMixinBase.lua`)
- Shared logic for both bar styles
- Quest overlay management
- XP calculation and display
- Event handling
- Animation system (gain flash, rested pulse)

**XPBarColors** (`ui/xpbar/XPBarColors.lua`)
- Centralized color management
- User-configured colors with defaults
- Color categories: XP bar, rested XP, quest complete/incomplete, flash, background, text

**XPBarTextFormatter** (`ui/xpbar/XPBarTextFormatter.lua`)
- Text generation for all display elements
- Formats: XP progress, level, percentage, rate, session time, quest summary
- Configurable display options

**XPBarTooltip** (`ui/xpbar/XPBarTooltip.lua`)
- Comprehensive tooltip information
- Shows: Current XP, remaining XP, session stats, time estimates, quest XP, rested state
- Dynamic hints based on context

### 2. Controller System

**XPBarController** (`app/features/xpbar/XPBarController.lua`)
- Manages bar visibility and style switching
- Handles position reset and locking
- Coordinates between view and services
- Quest event management

**OptionsController** (`app/features/options/OptionsController.lua`)
- Options panel event handling
- Color picker management
- Settings synchronization
- Real-time preview updates

**StatsController** (`app/features/stats/StatsController.lua`)
- Statistics frame management
- Data aggregation
- Display formatting

### 3. Service Layer

**SessionService** (`app/services/SessionService.lua`)
- Tracks session XP gains
- Manages session start/end
- Calculates XP per hour rate
- Level time tracking

**TimePlayedService** (`app/services/TimePlayedService.lua`)
- Requests time played data from server
- Throttles requests to avoid spam
- Provides real-time elapsed time estimation

**QuestXPService** (`app/services/QuestXPService.lua`)
- Calculates XP for completed quests
- Caches quest information
- Handles quest log updates

**LevelHistoryService** (`app/services/LevelHistoryService.lua`)
- Records level-up events
- Stores historical data
- Provides level progression tracking

**EventSystem** (`app/services/EventSystem.lua`)
- Internal event bus for addon communication
- Decouples components
- Event: `OPTION_CHANGED`, `SESSION_UPDATED`, `XP_UPDATED`, etc.

### 4. Configuration System

**Config** (`app/config/Config.lua`)
- Centralized configuration API
- Validates and applies settings
- Handles color conversion (hex ↔ RGBA)
- Manages saved variables

**Defaults** (`app/core/Defaults.lua`)
- Default values for all settings
- Default colors for all UI elements
- Default bar position and behavior

**OptionsMetadata** (`app/config/OptionsMetadata.lua`)
- Schema definition for options
- Validation rules
- UI generation metadata

### 5. UI Mixins

**PositionStoreMixin** (`ui/mixins/PositionStoreMixin.lua`)
- Saves/loads frame position
- Handles position restoration

**DraggableFrameMixin** (`ui/mixins/DraggableFrameMixin.lua`)
- Implements frame dragging
- Modifier key support (Shift+Drag)
- Drag start/stop callbacks

**ColorPickerMixin** (`ui/components/ColorPickerMixin.lua`)
- Color picker button behavior
- Integrates with Blizzard color picker
- Real-time color preview

## Data Flow

### Initialization Flow

```
1. Addon:OnLoad()
   ↓
2. Load SavedVariables
   ↓
3. Initialize Services
   ↓
4. Initialize Controllers
   ↓
5. Register Events
   ↓
6. Initialize UI Views
   ↓
7. Show appropriate bar style
```

### XP Update Flow

```
PLAYER_XP_UPDATE (WoW Event)
   ↓
XPBarMixinBase:OnEvent()
   ↓
SessionService:Update()
   ↓
XPBarView:Update()
   ↓
Update bar fill, text, overlays
```

### Option Change Flow

```
User clicks checkbox/slider
   ↓
OptionsPanel XML handler
   ↓
Config:SetOptionKey()
   ↓
OptionsController:OnOptionChanged()
   ↓
EventSystem:Fire("OPTION_CHANGED")
   ↓
XPBar:Update() / Stats:Update()
```

### Color Change Flow

```
User opens color picker
   ↓
ColorPickerMixin:OnClick()
   ↓
Blizzard ColorPickerFrame shows
   ↓
User selects color
   ↓
OptionsController:OnColorChanged()
   ↓
Config:SetColor()
   ↓
Addon.XPBar:Update()
   ↓
XPBarColors:GetUserColor()
   ↓
Bar applies new colors
```

## Customization System

### Color Configuration

All colors are user-configurable through the options panel:

**XP Bar Colors:**
- Main XP bar fill
- Rested XP fill
- Quest complete overlay
- Quest incomplete overlay
- Gain flash effect
- Background
- Text colors

**Storage:**
- Saved in: `XPChronicleDB.colors[key]`
- Format: `{r, g, b, a}` (0.0-1.0 range)
- Accessed via: `XPC_XPBarColors:GetUserColor(key)`

### Position Configuration

**Legacy Bar:**
- Fixed position (bottom center of screen)
- Not user-movable by design

**Flat Bar:**
- Default: center
- User-adjustable: Shift+Drag to move
- Position saved in: `XPChronicleDB.barPosition`
- Lock option available to prevent accidental moves

### Text Display Options

Configurable elements:
- Show/hide level text
- Show/hide XP text (with remaining XP toggle)
- Show/hide percentage
- Show/hide XP rate
- Show/hide session time
- Show/hide quest summary

## Event System

### WoW Events (Registered)

- `ADDON_LOADED` - Addon initialization
- `PLAYER_LOGIN` - Character login
- `PLAYER_XP_UPDATE` - XP change
- `PLAYER_LEVEL_UP` - Level increase
- `UPDATE_EXHAUSTION` - Rested XP change
- `QUEST_LOG_UPDATE` - Quest log change
- `QUEST_TURNED_IN` - Quest completion
- `QUEST_ACCEPTED` - New quest
- `QUEST_REMOVED` - Quest abandoned
- `TIME_PLAYED_MSG` - Server response with time played

### Internal Events (EventSystem)

- `OPTION_CHANGED` - Setting changed
- `SESSION_UPDATED` - Session data updated
- `XP_UPDATED` - XP calculation updated
- `QUEST_XP_CHANGED` - Quest XP cache invalidated

## Best Practices

### Code Organization

1. **Separation of Concerns**: UI, logic, and data are separated into distinct layers
2. **Single Responsibility**: Each file/class has one clear purpose
3. **Dependency Injection**: Services are passed to controllers, not accessed globally
4. **Event-Driven**: Components communicate via events, not direct calls

### Performance

1. **Throttling**: Time played requests are throttled to avoid server spam
2. **Caching**: Quest XP is cached and only recalculated when needed
3. **Lazy Loading**: Components initialize only when needed
4. **Efficient Updates**: Only visible elements are updated

### Maintainability

1. **Clear Naming**: Descriptive function and variable names
2. **Documentation**: Key functions have comments explaining purpose
3. **Consistent Patterns**: Similar problems solved similarly
4. **Modular Design**: Features can be modified independently

## Extension Points

### Adding New Bar Styles

1. Create XML template in `ui/xpbar/`
2. Create Lua mixin implementing standard interface
3. Mix in `XPC_XPBarMixinBase` for shared logic
4. Add style option to `OptionsMetadata.lua`
5. Update `XPBarController:ShowBarStyle()`

### Adding New Services

1. Create service file in `app/services/`
2. Initialize in `Addon:InitializeServices()`
3. Register needed events
4. Fire internal events for state changes
5. Provide public API for features

### Adding New Options

1. Add default value to `Defaults.lua`
2. Add metadata to `OptionsMetadata.lua`
3. Add UI control to `OptionsPanel.xml`
4. Handle in `OptionsController.lua`
5. Implement in relevant feature

## Testing Considerations

### Key Test Scenarios

1. **XP Gain**: Verify bar updates correctly on XP gain
2. **Level Up**: Verify bar resets and session continues
3. **Rested XP**: Verify rested display and exhaustion
4. **Quest Overlays**: Verify quest XP overlays appear correctly
5. **Bar Switching**: Verify smooth transition between styles
6. **Position Saving**: Verify position persists across sessions
7. **Color Changes**: Verify colors update immediately
8. **Options Reset**: Verify reset buttons restore defaults

### Edge Cases

- Max level (bar should hide by default)
- 0 XP (new character)
- Rested XP exhaustion (marker disappears)
- Multiple rapid XP gains (quest turn-ins)
- No quests in log (overlays hidden)
- Invalid saved data (fallback to defaults)

## Future Considerations

### Potential Enhancements

- Additional bar styles (circular, radial, etc.)
- More quest overlay visualization options
- Export/import color themes
- Performance profiling mode
- Integration with other addons (via LibStub)
- Additional statistics tracking
- Historical data visualization

### Scalability

- Modular design supports adding new features
- Event system allows decoupled components
- Service layer can be extended without UI changes
- Color system supports unlimited custom colors

---

**Last Updated**: October 14, 2025
**Version**: 1.0.0
**Maintainer**: Ciaanh
