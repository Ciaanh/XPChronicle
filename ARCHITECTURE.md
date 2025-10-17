# XP Bar Enhanced - Architecture Documentation

## Event Flow & UI Update Pipeline

### WoW Events → Core Dispatcher → Modules → UI Update

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         WoW Client Events                                 │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    Core.lua Event Dispatcher                              │
│                    (eventMap + OnEvent handler)                          │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌──────────────┐ ┌──────────┐ ┌────────────┐
            │   Session    │ │  XPBar   │ │   Stats    │
            │   Tracking   │ │  Module  │ │   Window   │
            └──────────────┘ └──────────┘ └────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │   XPBarMixinBase      │
                        │   (Shared Logic)      │
                        └───────────────────────┘
                                    │
                        ┌───────────┴───────────┐
                        ▼                       ▼
                ┌──────────────┐        ┌──────────────┐
                │ LegacyXPBar  │        │  FlatXPBar   │
                │   (Skinned)  │        │  (Custom)    │
                └──────────────┘        └──────────────┘
```

---

## WoW Events Registered

### Initialization Events

#### `ADDON_LOADED`
**Trigger:** When the addon's files are loaded  
**Handler:** `OnAddonLoaded(addonName)`  
**Flow:**
1. Verify it's our addon (`addonName == "XPBarEnhanced"`)
2. Initialize Database module → Load SavedVariables
3. Initialize Config module
4. Set `Addon.db` reference
5. Restore XP gain disabled state
6. Print "Loaded!" message

**Result:** Core data structures ready

---

#### `PLAYER_LOGIN`
**Trigger:** Player has fully logged in  
**Handler:** `OnPlayerLogin()`  
**Flow:**
1. Initialize Session tracking module
2. Initialize XPBar module (creates frames)
3. Initialize Stats window
4. Initialize Options panel

**Result:** All UI components created and ready

---

#### `PLAYER_ENTERING_WORLD`
**Trigger:** Player enters world (login, reload, loading screen)  
**Handler:** `OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)`  
**Flow:**
1. Session: Reset session state if initial login
2. XPBar: Request time played, update display, apply saved position
3. XPBar: Show/hide based on max level setting

**Result:** UI reflects current game state

---

### XP Tracking Events

#### `PLAYER_XP_UPDATE`
**Trigger:** Player gains/loses XP  
**Handler:** `OnPlayerXPUpdate()`  
**Flow:**
1. **Session Module:**
   - Calculate XP gained since last update
   - Update session statistics (total XP, XP/hour)
   - Track level progress

2. **XPBar Module:**
   - Invalidate quest cache (quest rewards may have changed)
   - Update XP bar display
   - Trigger animations if enabled

3. **Stats Module:**
   - Refresh statistics window if open
   - Update session metrics display

**UI Updates:**
- Bar fill animates to new XP value
- Percentage text updates
- Tooltip shows new progress
- Quest overlays recalculated

---

#### `PLAYER_LEVEL_UP`
**Trigger:** Player levels up  
**Handler:** `OnPlayerLevelUp(level)`  
**Flow:**
1. **Session Module:**
   - Record level-up time
   - Reset level XP tracking
   - Create new level entry in database

2. **XPBar Module:**
   - Play celebration animation (if enabled)
   - Reset bar to 0%
   - Update level text

3. **Stats Module:**
   - Archive previous level statistics
   - Start tracking new level

**UI Updates:**
- Level-up animation plays
- Bar resets with celebration effects
- Level number updates
- Statistics reset for new level

---

### Rested XP Events

#### `UPDATE_EXHAUSTION`
**Trigger:** Rested XP amount changes  
**Handler:** `OnUpdateExhaustion()`  
**Flow:**
1. XPBar: Update rested XP overlay
2. XPBar: Recalculate rested percentage
3. XPBar: Update tooltip with new rested state

**UI Updates:**
- Blue rested overlay adjusts width
- Tooltip shows updated rested XP amount
- Rested state indicator updates

---

#### `PLAYER_UPDATE_RESTING`
**Trigger:** Player enters/leaves rested area (inn, city)  
**Handler:** `OnPlayerUpdateResting()`  
**Flow:**
1. XPBar: Same as `UPDATE_EXHAUSTION`

**UI Updates:**
- Rested state indicator (zzz icon in tooltip)

---

### Time Tracking Events

#### `TIME_PLAYED_MSG`
**Trigger:** Response to `/played` command (auto-requested on load)  
**Handler:** `OnTimePlayedMsg(totalTime, levelTime)`  
**Flow:**
1. **Session Module:**
   - Store total time played
   - Store time at current level
   - Calculate accurate XP/hour rates

2. **Stats Module:**
   - Update time-based statistics
   - Calculate estimated time to level

**UI Updates:**
- Stats window shows accurate times
- XP/hour calculations improved
- "Time to Level" estimate updated

---

### XP Gain Control Events

#### `ENABLE_XP_GAIN` / `DISABLE_XP_GAIN`
**Trigger:** Player toggles XP gain (max level feature)  
**Handlers:** `OnEnableXPGain()` / `OnDisableXPGain()`  
**Flow:**
1. Update `Addon.state.xpGainDisabled` flag
2. Save state to database
3. XPBar adjusts display if needed

**UI Updates:**
- Bar may hide/show based on max level setting
- Tooltip indicates XP gain disabled state

---

## Module Update Flow

### When XP is Gained:

```
PLAYER_XP_UPDATE event fires
         │
         ├─> Session:OnXPUpdate()
         │   ├─> Calculate gained XP
         │   ├─> Update session totals
         │   └─> Recalculate XP/hour
         │
         ├─> XPBar:OnXPUpdate()
         │   ├─> Invalidate quest cache
         │   ├─> Call UpdateAllText()
         │   ├─> Call UpdateBarFill()
         │   │   ├─> Calculate current/max XP
         │   │   ├─> Calculate quest XP overlays
         │   │   ├─> Animate bar to new value
         │   │   └─> Update rested overlay
         │   └─> Refresh tooltip
         │
         └─> Stats:OnXPUpdate()
             ├─> Update current XP display
             ├─> Update remaining XP
             ├─> Update XP/hour rate
             └─> Update time to level
```

### UI Refresh Cascade:

```
XPBar:Update() called
         │
         ├─> UpdateBarFill()
         │   ├─> Bar:SetMinMaxValues()
         │   ├─> Bar:SetValue() (with animation)
         │   └─> UpdateBarOverlayColors()
         │
         ├─> UpdateTextVisibility()
         │   ├─> Show/hide text based on settings
         │   └─> Position text elements
         │
         └─> UpdateAllText()
             ├─> LevelText → "Level X"
             ├─> XPText → "1,234 / 5,678"
             ├─> PercentageText → "21.7%"
             ├─> XPPerHourText → "1.2K XP/hr"
             ├─> LevelTimeText → "2h 34m"
             ├─> SessionTimeText → "45m"
             └─> TimeToLevelText → "1h 23m"
```

---

## Data Flow: Database → Memory → UI

### Initialization:
```
SavedVariables (XPBarEnhancedDB)
         │
         ├─> Database:Initialize()
         │   └─> Merge defaults with saved data
         │
         ├─> Session:Initialize()
         │   ├─> Load session data
         │   └─> Load level history
         │
         └─> XPBar:Initialize()
             ├─> Create bar frames
             ├─> Apply saved position
             └─> Apply saved colors
```

### Runtime Updates:
```
User gains XP
         │
         ├─> Session updates in-memory data
         │   └─> Auto-saves to Addon.db every update
         │
         ├─> XPBar reads from Addon.db
         │   ├─> Session data (XP/hour, times)
         │   ├─> Settings (show/hide options)
         │   └─> Colors (bar fill colors)
         │
         └─> Stats reads from Addon.db
             ├─> Session statistics
             ├─> Level history
             └─> Calculated metrics
```

### Persistence:
```
Addon.db (in-memory reference to XPBarEnhancedDB)
         │
         ├─> Settings: colors, bar style, options
         ├─> Session data: XP, times, rates
         ├─> Level history: per-level tracking
         └─> Bar position: x, y coordinates
         │
         └─> Auto-saved by WoW on:
             ├─> /reload
             ├─> Logout
             └─> Clean exit
```

---

## Key Design Patterns

### 1. Event → Handler → Module Pattern
- **Core.lua** receives WoW events
- **eventMap** translates event names to handler methods
- **Handlers** dispatch to appropriate modules
- **Modules** update their data and trigger UI updates

### 2. Separation of Concerns
- **Session**: Tracks XP gains, time played, rates
- **XPBar**: Displays bar, handles animations, quest overlays
- **Stats**: Displays detailed statistics window
- **Config**: Manages settings and defaults
- **Database**: Persists data to SavedVariables

### 3. Mixin-Based Views
- **XPBarMixinBase**: Shared logic for both bar styles
- **LegacyXPBarMixin**: Skinned Blizzard bar
- **FlatXPBarMixin**: Custom draggable bar
- Both use same base methods, different visuals

### 4. Direct Module Access
- Old: `Addon.App.Services.Database`
- New: `Addon.Database`
- Cleaner, more readable, less nesting

---

## Performance Considerations

### Throttling & Debouncing:
- Quest cache invalidated on XP update (recalculated on next tooltip)
- Animations use WoW's built-in smoothing
- Stats window only updates when visible

### Lazy Loading:
- Quest data fetched only when tooltip shown
- Colors initialized once, cached in module
- Options panel created on first open

### Memory Management:
- Old data archived in level history
- Session data reset on new session
- No persistent timers (event-driven only)

---

## Common Flows

### Gaining XP from a Quest:
1. Quest completed → XP awarded
2. `PLAYER_XP_UPDATE` fires
3. Session calculates gained XP
4. XPBar invalidates quest cache
5. Bar animates to new value
6. Quest overlay recalculates (completed quest removed)
7. Tooltip updates with new remaining quests
8. Stats window updates if open

### Leveling Up:
1. XP reaches max → Level increases
2. `PLAYER_LEVEL_UP` fires with new level
3. Session archives old level data
4. XPBar plays celebration animation
5. Bar resets to 0% with sparkles
6. Level text updates
7. Stats creates new level entry
8. Time to level recalculates

### Opening Stats Window:
1. User clicks bar (Ctrl+Click) or uses `/xpbe stats`
2. Stats:Toggle() called
3. If closed → Stats:Show()
4. Stats:Update() refreshes all displays
5. Window shows current session data
6. Updates continue on `PLAYER_XP_UPDATE`

---

## Dependencies

### Required Libraries:
- **LibStub**: Library management
- **AceLocale-3.0**: Localization support

### Module Dependencies:
```
Core.lua
  ├─> Database.lua (SavedVariables management)
  ├─> Session.lua (XP tracking)
  ├─> Utils.lua (helper functions)
  ├─> Logger.lua (error handling)
  ├─> Colors.lua (color management)
  └─> Config.lua (settings & defaults)

XPBar.lua
  ├─> Session.lua (for XP data)
  ├─> Config.lua (for settings)
  └─> Colors.lua (for bar colors)

Stats.lua
  ├─> Session.lua (for statistics)
  ├─> Utils.lua (for formatting)
  └─> Config.lua (for settings)

Options.lua
  ├─> Config.lua (for option metadata)
  └─> Colors.lua (for color picker)
```

---

## File Structure

```
XPBarEnhanced/
├── core/                    # Core systems
│   ├── Core.lua             # Event dispatcher, initialization
│   ├── Database.lua         # SavedVariables management
│   ├── Session.lua          # XP/time tracking
│   ├── Config.lua           # Settings & defaults
│   ├── Colors.lua           # Color management
│   ├── Utils.lua            # Helper functions
│   └── Logger.lua           # Error logging
│
├── ui/                      # UI components
│   ├── xpbar/
│   │   ├── XPBar.lua        # Bar controller & quest service
│   │   ├── XPBarMixinBase.lua   # Shared bar logic
│   │   ├── LegacyXPBarMixin.lua # Skinned Blizzard bar
│   │   └── FlatXPBarMixin.lua   # Custom draggable bar
│   │
│   ├── stats/
│   │   └── Stats.lua        # Statistics window
│   │
│   ├── options/
│   │   └── Options.lua      # Settings panel
│   │
│   └── common/              # Shared UI utilities
│       ├── FrameUtils.lua
│       ├── DraggableFrameMixin.lua
│       └── PositionStoreMixin.lua
│
├── locales/                 # Translations
│   └── enUS.lua             # English strings
│
├── libs/                    # External libraries
│   ├── LibStub/
│   └── AceLocale-3.0/
│
└── Frames.xml               # Frame templates
```

---

## Testing Checklist

### Events:
- [ ] Gain XP → Bar animates
- [ ] Level up → Celebration animation
- [ ] Enter rested area → Rested overlay updates
- [ ] Request time played → Stats update

### UI:
- [ ] Switch bar styles → Both work
- [ ] Move Flat bar → Position saved
- [ ] Change colors → Colors persist
- [ ] Toggle options → Settings saved

### Data:
- [ ] Session tracks correctly
- [ ] Level history saved
- [ ] /reload preserves data
- [ ] Quest XP calculated correctly

---

*Last Updated: October 2025 - v2.0.0*
