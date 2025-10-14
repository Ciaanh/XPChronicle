# Floating text to detail the gained XP with the source (kill, gathering, exploration, quest...) and the amount coming form rested status

**Visual Design**:

-   Floating combat text in center of screen showing detailed XP gain information
-   Animated text that scrolls upward and fades out
-   Color-coded based on XP source and rested bonus status
-   Optional icon indicators for different XP sources

**Information Displayed**:

-   **Total XP Gained**: Main number prominently displayed
-   **XP Source**: Text label identifying source type
    -   Quest completion
    -   Mob kill (with creature name)
    -   Exploration discovery
    -   Gathering (herb/ore/skin)
    -   Profession skill-up
    -   Dungeon/raid completion
    -   Bonus objectives
-   **Rested Bonus**: Separate line showing amount from rested XP
    -   Different color (light blue) to distinguish from base XP
    -   Format: "+XXX (Rested)" or "XXX + XXX Rested"

**Visual Features**:

-   **Animation**: Scrolls upward from center screen
-   **Fade**: Starts at full opacity, fades out over 2-3 seconds
-   **Stacking**: Multiple XP gains stack vertically
-   **Color Coding**:
    -   Normal XP: White or yellow
    -   Rested XP component: Light blue
    -   Large gains (quests): Gold
    -   Critical/bonus XP: Orange
-   **Font**: Configurable size and style
-   **Position**: Customizable (center, above character, custom offset)

**Configuration Options**:

-   Enable/disable floating XP text
-   Show/hide XP source labels
-   Show/hide rested bonus breakdown
-   Animation speed (slow, normal, fast)
-   Text size multiplier
-   Display duration (1-5 seconds)
-   Vertical offset from center
-   Minimum XP threshold to display (filter small gains)
-   Combine rapid gains within X seconds

**Technical Implementation**:

-   Hook XP gain events (CHAT_MSG_COMBAT_XP_GAIN, PLAYER_XP_UPDATE)
-   Parse combat log for XP source information
-   Create floating font string frames (pooled for performance)
-   Animate using OnUpdate with GetTime() calculations
-   Track rested XP changes to separate bonus component
-   Debounce rapid small gains to avoid spam

**Data Integration**:

-   Use existing XP tracking from XPBarController
-   Leverage QuestXPService for quest XP data
-   Track XP source in session stats for analytics
-   Store per-source XP breakdown in session data

**Examples**:

```
+2,450 XP
Quest: "Defend the Village"
+612 Rested

+150 XP
Kill: Plainstrider
+75 Rested

+1,000 XP
Exploration: Stormwind Harbor

+50 XP
Herbalism: Peacebloom
```

---

# Font Customization

**Customizable Properties**:

- **Font Face**: Dropdown of WoW fonts
  - Friz Quadrata (Default)
  - Arial Narrow
  - Morpheus
  - Skurri
  - Adventure
- **Font Size**: Slider (8-24)
- **Font Outline**: None, Normal, Thick
- **Font Shadow**: Toggle
- **Text Color**: Color picker for each text element
- **Apply to**: All text, or per-element (level, XP, percent, rested)

**Configuration**:
- Font customization section in options
- Live preview of changes
- Reset to defaults button


# Auto-Hide at Max Level

**Behavior Options**:

- **Always Show**: Bar visible even at max level (default for backward compatibility)
- **Auto-Hide**: Hide bar completely when reaching max level
- **Show on Hover**: Bar hidden but appears on mouseover
- **Minimal Mode**: Show simplified version (no XP, just level)

**Configuration**:
- Dropdown selector in options
- Takes effect immediately on level check
- Can be toggled at any time