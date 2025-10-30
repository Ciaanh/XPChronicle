# FlatBar Style v2# FlatBar Style v2# FlatBar Style v2# FlatBar Style v2 (single-file)



A demonstration of the v2 architecture following strict XML contract principles.



## Architecture OverviewA demonstration of the v2 architecture using a minimal single-file style implementation.



The v2 architecture follows a **contract-based pattern**:



- **XML owns ALL visual creation** (frames, textures, fonts, overlays)## Architecture OverviewA demonstration of the v2 architecture using a minimal single-file style implementation.This style uses the v2 builder pattern with a single Lua file containing the style template

- **BaseMixin validates the contract** (warns if elements missing, does NOT create)

- **Lua owns behavior composition** (mixins for animation, interaction, tooltips, positioning)

- **Styles create reference aliases** in BuildVisuals for nested XML structures

The v2 architecture follows a **contract-based pattern**:(see FlatBarStyle.lua). Visual elements are created in XML; the style implementation should

## XML Contract



Every style MUST provide an XML template that creates all UI elements. BaseMixin validates but does NOT create.

- **XML owns visual creation** (frames, textures, fonts)## Architecture Overviewonly validate/initialize those elements and provide optional overrides for text/overlay formatting.

### Required Elements

- `StatusBar` - main XP bar (StatusBar widget)- **Lua owns behavior composition** (mixins for animation, interaction, tooltips, positioning)



### Recommended Elements for Full Feature Set- **BaseMixin provides defaults** for standard linear layouts with ALL overlays

- Text elements (can be in OverlayFrame or StatusBar):

  - `XPText` - current/max XP display (FontString)- **Styles override only when needed** (e.g., circular layout needs custom overlay positioning)

  - `PercentText` - percentage display (FontString)

  - `LevelText` - level display (FontString)The v2 architecture follows a **contract-based pattern**:Required style methods

  

- Overlay elements (must be children of StatusBar or main frame):## XML Contract

  - `StatusBar.RestedLevel` - rested XP overlay (Texture, ARTWORK layer 1)

  - `StatusBar.QuestOverlayComplete` - completed quest XP (Texture, ARTWORK layer 2)- **XML owns visual creation** (frames, textures, fonts)- BuildVisuals(self)

  - `StatusBar.QuestOverlayIncomplete` - incomplete quest XP (Texture, ARTWORK layer 3)

  - `ExhaustionTick` - rested boundary marker (Frame with texture child)Every style MUST provide an XML template that creates a StatusBar. All other elements are created automatically by BaseMixin if not present in XML.

  - `GainFlash` - flash animation overlay (Texture, OVERLAY layer)

- **Lua owns behavior composition** (mixins for animation, interaction, tooltips, positioning)  - Must validate XML-created elements (StatusBar, overlays, text frames) and set initial state.

**Note:** BaseMixin Action methods expect `self.RestedLevel`, not `self.StatusBar.RestedLevel`. Styles must create aliases in BuildVisuals.

### Required Elements (Minimum)

## Minimal Lua Structure

- `StatusBar` - main XP bar (StatusBar widget)- **BaseMixin provides defaults** for standard linear layouts  - Should NOT create core widgets that are already defined in XML.

For standard linear layouts, BuildVisuals creates reference aliases:



```lua

local FlatBarStyleTemplate = {### Optional Elements (Created by BaseMixin if Missing)- **Styles override only when needed** (e.g., circular layout needs custom overlay positioning)

    BuildVisuals = function(self)

        -- Call BaseMixin validation first- `XPText` - current/max XP display (FontString)

        if XPBarMixinBase_v2.BuildVisuals then

            XPBarMixinBase_v2.BuildVisuals(self)- `PercentText` - percentage display (FontString)Optional style overrides

        end

        - `LevelText` - level display (FontString)

        -- Create aliases: XML creates StatusBar.RestedLevel, but Action methods expect self.RestedLevel

        if self.StatusBar then- `RestedLevel` - rested XP overlay (Texture, created on StatusBar)## XML Contract (Required)- UpdateTexts(self, context)

            if self.StatusBar.RestedLevel then

                self.RestedLevel = self.StatusBar.RestedLevel- `QuestOverlayComplete` - completed quest XP (Texture, created on StatusBar)

            end

            if self.StatusBar.QuestOverlayComplete then- `QuestOverlayIncomplete` - incomplete quest XP (Texture, created on StatusBar)  - Override if you need custom text formatting for XP / percent / level.

                self.QuestOverlayComplete = self.StatusBar.QuestOverlayComplete

            end- `ExhaustionTick` - rested boundary marker (Frame, created on StatusBar)

            if self.StatusBar.QuestOverlayIncomplete then

                self.QuestOverlayIncomplete = self.StatusBar.QuestOverlayIncomplete- `GainFlash` - flash animation overlay (Texture, created on main frame)Every style MUST provide an XML template that creates these elements with exact naming:- UpdateOverlays(self, context)

            end

        end

        

        -- Alias text elements if in OverlayFrame**Note:** BaseMixin automatically creates all overlays to provide full feature parity with existing FlatXPBar. Styles can disable specific overlays via config (`style.showQuestOverlays = false`, etc.)  - Override only if you need custom overlay layout (e.g., circular arc overlays).

        if self.OverlayFrame then

            if self.OverlayFrame.XPText then

                self.XPText = self.OverlayFrame.XPText

            end## Minimal Lua Structure### Required Elements- UpdateBars(self, context)

            if self.OverlayFrame.PercentText then

                self.PercentText = self.OverlayFrame.PercentText

            end

            if self.OverlayFrame.LevelText thenFor standard linear layouts, the style Lua file can be **empty** - just provide config:- `StatusBar` - main XP bar (StatusBar widget)  - Only for non-linear bars (circular). Flat linear bars should use BaseMixin default.

                self.LevelText = self.OverlayFrame.LevelText

            end

        end

    end```lua- `XPText` - current/max XP display (FontString)

}

local FlatBarStyleTemplate = {}  -- Empty template uses all BaseMixin defaults

local DefaultConfig = {

    animation = { enabled = true, valueSmoothing = true, xpGainFlash = true, levelUpFlash = true },- `PercentText` - percentage display (FontString)Guidelines

    interaction = { enabled = true },

    tooltip = { enabled = true },local DefaultConfig = {

    position = { mode = "STATIC", positionKey = "FlatBar_v2" },

    style = { width = 565, height = 11, showQuestOverlays = true },    animation = { enabled = true, valueSmoothing = true, xpGainFlash = true, levelUpFlash = true },- `LevelText` - level display (FontString)- Prefer relying on BaseMixin default UpdateVisuals(context), which calls:

}

    interaction = { enabled = true },

FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, FlatBarStyleTemplate, DefaultConfig)

```    tooltip = { enabled = true },  - UpdateBars(context), UpdateOverlays(context), UpdateTexts(context)



**Total: ~90 lines** (vs. 400+ in legacy implementation = **77.5% reduction**)    position = { mode = "STATIC", positionKey = "FlatBar_v2" },



## When to Override    style = { width = 565, height = 11, showQuestOverlays = true },### Optional Elements (Standard Naming)- Use `XPBarColors:GetUserColor(key)` for colors; never hardcode colors.



Override style methods **only** when you need custom behavior:}



### BuildVisuals(self)- `RestedLevel` - rested XP overlay (Texture)- Keep visual widget creation in XML. Style code should be small and focused.

**Always override** to create reference aliases if XML uses nested structures.

-- Composition happens at addon load via StyleBuilder

BaseMixin default validates contract and warns about missing elements.

FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, FlatBarStyleTemplate, DefaultConfig)- `QuestOverlayComplete` - completed quest XP (Texture)- Ensure this style file is listed after core v2 modules (ContextBuilder, StyleBuilder, BaseMixin, mixins) in the .toc so the style can be created at load time.

### UpdateVisuals(self, context)

**Rarely override** - BaseMixin default delegates to:```

- `UpdateBars(context)` - updates StatusBar ratio

- `UpdateTexts(context)` - formats XPText, PercentText, LevelText- `QuestOverlayIncomplete` - incomplete quest XP (Texture)- If XML references the global mixin by name, ensure the style Lua runs before the XML is parsed in the .toc.

- `UpdateOverlays(context)` - calls Update*Overlay methods

**Total: ~50 lines** (vs. 400+ in legacy implementation = **87.5% reduction**)

Override only for completely custom rendering logic.

- `ExhaustionTick` - rested boundary marker (Frame/Texture)

### UpdateBars(self, context)

Override if you need:## When to Override

- Circular arc positioning (not linear fill)

- Vertical bars (not horizontal)- `GainFlash` - flash animation overlay (Texture)Example usage

- Multiple segmented bars

Override style methods **only** when you need custom behavior:

BaseMixin default: `StatusBar:SetValue(ratio)` where ratio = currentXP/maxXP

- Programmatic:

### UpdateTexts(self, context)

Override if you need:### BuildVisuals(self)

- Custom text formatting (e.g., "Level 60 Mage")

- Different number formatsOverride if you need:## Lua File Structure (Minimal)```lua

- Additional calculated values

- Circular arc overlays

BaseMixin default uses `BreakUpLargeNumbers()` for current/max XP and percentage calculation.

- Custom text positioning algorithmslocal f = CreateFrame("Frame", "MyFlatBar", UIParent, "FlatBarTemplate_v2")

### UpdateOverlays(self, context)

Override if you need:- Non-standard element names in XML

- Circular arc overlays (not rectangular)

- Custom layering logicFor a **standard linear layout** (like FlatBar), the Lua file is minimal:XPBarEnhanced_ApplyFlatBarStyle(f, { position = { mode = "DRAGGABLE", positionKey = "MyBar" } })

- Different overlay positioning algorithms

BaseMixin default assumes XML contract and creates all mandatory overlays.

BaseMixin default calls: `UpdateRestedOverlay`, `UpdateQuestCompleteOverlay`, `UpdateQuestIncompleteOverlay`, `UpdateExhaustionTick`, `UpdateFlashOverlay`

```

## Component Composition

### UpdateVisuals(self, context)

The style is built from **5 components**:

**Rarely override** - BaseMixin default delegates to:```lua

1. **XPBarMixinBase_v2** - Core event handling, default Update* methods, contract validation

2. **AnimationMixin** - Optional smooth value transitions and flash effects- `UpdateBars(context)` - updates StatusBar ratio

3. **InteractionMixin** - Optional mouse interactions (drag, click)

4. **TooltipMixin** - Optional tooltip display- `UpdateTexts(context)` - formats XPText, PercentText, LevelText-- 1. Validate dependencies- XML (mixin reference):

5. **PositionMixin** - Optional position persistence

6. **FlatBarStyleTemplate** - Style-specific reference aliasing and config- `UpdateOverlays(context)` - calls Update*Overlay methods



Composition happens via `XPBarStyleBuilder:Create(base, template, config)` which:if not XPBarStyleBuilder or not XPBarMixinBase_v2 thenPlace FlatBarStyle.lua earlier in .toc than FlatBarTemplate.xml so that the global mixin exists when the frame is created.

- Merges base mixin (defaults + validation)

- Merges behavior mixins (based on config)Override only for completely custom rendering logic.

- Merges style template (aliases + overrides)

- Stores final config in `self.config`    error("Core v2 modules not loaded")```



## Usage### UpdateBars(self, context)



### Production (XML-based)Override if you need:end

```xml

<Frame mixin="FlatBarXPBarMixin" ...>- Circular arc positioning (not linear fill)

    <!-- WoW loads XML → calls OnLoad → BuildVisuals → creates aliases -->

</Frame>- Vertical bars (not horizontal)-- 2. Define config

```

- Multiple segmented barslocal DefaultConfig = {

### Development (Programmatic)

```lua    animation = { enabled = true, ... },

local frame = XPBarEnhanced_ApplyFlatBarStyle(CreateFrame("Frame", "DevTestBar", UIParent), config)

-- Helper function applies mixin and calls BuildVisualsBaseMixin default: `StatusBar:SetMinMaxValues(0, context.maxXP or 1)` and `StatusBar:SetValue(context.currentXP or 0)`    interaction = { enabled = true },

```

    tooltip = { enabled = true },

**Note:** `XPBarEnhanced_ApplyFlatBarStyle` is for testing only. Production usage should use XML `mixin` attribute.

### UpdateTexts(self, context)    position = { mode = "STATIC", positionKey = "FlatBar_v2" },

## Configuration

Override if you need:}

Default config structure (all optional, sensible defaults provided):

- Custom text formatting (e.g., "Level 60 Mage")

```lua

{- Different number formats-- 3. Create mixin (empty template = use all base defaults)

    animation = {

        enabled = true,              -- Enable AnimationMixin- Additional calculated valuesFlatBarXPBarMixin = XPBarStyleBuilder:Create(

        valueSmoothing = true,       -- Smooth XP value changes

        xpGainFlash = true,          -- Flash on XP gain    XPBarMixinBase_v2,

        levelUpFlash = true          -- Flash on level up

    },BaseMixin default uses `BreakUpLargeNumbers()` for current/max XP and percentage calculation.    {}, -- Empty style template

    interaction = {

        enabled = true               -- Enable InteractionMixin (dragging, clicking)    DefaultConfig

    },

    tooltip = {### UpdateOverlays(self, context))

        enabled = true,              -- Enable TooltipMixin

    },

    position = {- Circular arc overlays (not rectangular)

        mode = "STATIC",             -- "STATIC" or "DRAGGABLE"

        positionKey = "FlatBar_v2"   -- Key for XPChronicleDB.barPositions- Custom layering logic**That's it!** No BuildVisuals, no UpdateVisuals needed for standard layouts.

    },

    style = {- Different overlay positioning algorithms

        width = 565,                 -- Bar width

        height = 11,                 -- Bar height## When to Override

        showQuestOverlays = true,    -- Show quest XP overlays

        -- Add style-specific options hereBaseMixin default calls: `UpdateRestedOverlay`, `UpdateQuestCompleteOverlay`, `UpdateQuestIncompleteOverlay`, `UpdateExhaustionTick`, `UpdateFlashOverlay`

    }

}Override style methods **only** when you need custom behavior:

```

## Component Composition

## Event Flow

### 1. Custom Layout (e.g., circular)

```

1. PLAYER_XP_UPDATE event firesThe style is built from **5 components**:```lua

   ↓

2. XPBarContextBuilder:Build() → context = { currentXP, maxXP, level, restedXP, ... }local CircularStyleTemplate = {

   ↓

3. TriggerXPChanged(context) → calls action methods1. **XPBarMixinBase_v2** - Core event handling, default Update* methods, mandatory overlay creation    UpdateRestedOverlay = function(self, context, overlayName)

   ↓

4. UpdateVisuals(context) → delegates to:2. **AnimationMixin** - Optional smooth value transitions and flash effects        -- Custom arc positioning instead of linear pixels

   - UpdateBars(context)     → StatusBar:SetValue(currentXP)

   - UpdateTexts(context)    → XPText:SetText(format), etc.3. **InteractionMixin** - Optional mouse interactions (drag, click)    end,

   - UpdateOverlays(context) → Update*Overlay methods

```4. **TooltipMixin** - Optional tooltip display    



**Key principle:** Context flows **explicitly** through the event pipeline. No caching, no state.5. **PositionMixin** - Optional position persistence    UpdateBars = function(self, context)



## Comparison: Legacy vs v26. **FlatBarStyleTemplate** - Style-specific config and overrides (empty for FlatBar)        -- Update circular progress instead of StatusBar



| Aspect | Legacy Implementation | v2 Implementation | Change |    end,

|--------|----------------------|-------------------|--------|

| **Lines of Code** | ~400 lines | ~90 lines | **-77.5%** |Composition happens via `XPBarStyleBuilder:Create(base, template, config)` which:}

| **Files** | 2 files (Lua + XML) | 2 files (Lua + XML) | Same |

| **XML Responsibility** | Create visuals only | Create ALL visuals + overlays | **Complete** |- Merges base mixin (defaults)```

| **Lua Responsibility** | All logic + setup | Aliases + config + optional overrides | **Focused** |

| **UI Creation** | Mix of XML and Lua | XML only (strict contract) | **Separated** |- Merges behavior mixins (based on config)

| **Code Reuse** | Copy/paste between styles | Inherit from BaseMixin | **Composition** |

| **Custom Layouts** | Full reimplementation | Override specific methods | **Targeted** |- Merges style template (overrides)### 2. Custom Text Formatting

| **Testing** | Reload addon | `/xptest` commands | **Faster** |

| **Maintainability** | High duplication | Single source of truth | **Better** |- Stores final config in `self.config````lua



## Testinglocal CustomTextTemplate = {



Enable v2 testing:## Usage    UpdateTexts = function(self, context)

```lua

XPChronicleConfig.enableDevV2 = true        -- Different number formatting or layout

```

### Production (XML-based)    end,

Available commands:

- `/xptest create` - Create test bar```xml}

- `/xptest destroy` - Remove test bar

- `/xptest reset` - Reset bar position<Frame mixin="FlatBarStyleTemplate" ...>```

- `/xptest show/hide` - Toggle visibility

- `/xptest refresh` - Force visual update    <!-- WoW loads XML → calls OnLoad → BuildVisuals → overlays created by BaseMixin -->

- `/xptest context` - Print current context

- `/xptest session` - Print session stats</Frame>### 3. Non-Standard Element Names

- `/xptest flash` - Test flash animation

- `/xptest levelup` - Test level-up effect``````lua

- `/xptest drag` - Toggle drag mode

- `/xptest help` - Show all commandslocal CustomNamesTemplate = {



## Implementation Notes### Development (Programmatic)    BuildVisuals = function(self)



1. **XML Contract**: XML creates ALL UI elements. BaseMixin validates, never creates. This ensures clean separation.```lua        -- Map custom XML names to contract



2. **Reference Aliasing**: Action methods expect `self.RestedLevel` but XML creates `StatusBar.RestedLevel` as a child. BuildVisuals creates the aliases.local frame = XPBarEnhanced_ApplyFlatBarStyle(CreateFrame("Frame", "DevTestBar", UIParent), config)        self.StatusBar = self.MyCustomProgressBar



3. **Color System**: Always use `XPBarColors:GetUserColor(colorKey)` - never hardcode colors. User preferences are respected.-- Helper function applies mixin and calls BuildVisuals        -- Then call base implementation



4. **Context Passing**: Context is passed explicitly through all method calls. No caching, no shared state.```        XPBarMixinBase_v2.BuildVisuals(self)



5. **Load Order**: Style file must load after core v2 modules (ContextBuilder, StyleBuilder, BaseMixin, mixins) in .toc file.    end,



6. **Minimal Override**: FlatBar only overrides BuildVisuals for aliasing. All Update* methods use BaseMixin defaults because linear layout is standard.**Note:** `XPBarEnhanced_ApplyFlatBarStyle` is for testing only. Production usage should use XML `mixin` attribute.}



## Next Steps```



1. Test in-game with `/xptest` commands## Configuration

2. Verify all overlays display correctly

3. Test drag/drop, tooltips, animations## Component Composition

4. Port circular style (will need BuildVisuals for element creation + UpdateBars override for arc positioning)

5. Deprecate legacy implementation once all styles portedDefault config structure (all optional, sensible defaults provided):


FlatBar is composed via StyleBuilder:

```lua

{1. **XPBarMixinBase_v2** (core)

    animation = {   - Event orchestration

        enabled = true,              -- Enable AnimationMixin   - Trigger → Action pattern

        valueSmoothing = true,       -- Smooth XP value changes   - Default visual updates (UpdateBars, UpdateTexts, UpdateOverlays)

        xpGainFlash = true,          -- Flash on XP gain   - Overlay validation and color management

        levelUpFlash = true          -- Flash on level up

    },2. **XPBarAnimationMixin** (optional, via config)

    interaction = {   - Value smoothing (ease-out)

        enabled = true               -- Enable InteractionMixin (dragging, clicking)   - Flash effects

    },

    tooltip = {3. **XPBarInteractionMixin** (optional, via config)

        enabled = true,              -- Enable TooltipMixin   - Mouse handlers

    },

    position = {4. **XPBarTooltipMixin** (optional, via config)

        mode = "STATIC",             -- "STATIC" or "DRAGGABLE"   - GameTooltip integration

        positionKey = "FlatBar_v2"   -- Key for XPChronicleDB.barPositions   - Default content provider (XP, rested, session stats)

    },

    style = {5. **XPBarPositionMixin** (optional, via config)

        width = 565,                 -- Bar width   - STATIC anchoring (to Blizzard UI)

        height = 11,                 -- Bar height   - DRAGGABLE with position persistence

        showQuestOverlays = true,    -- Show quest XP overlays

        -- Add style-specific options here6. **FlatBarStyleTemplate** (empty for FlatBar)

    }   - No overrides needed for standard linear layout

}

```## Usage



## Event Flow### Production (XML-based, recommended)

```xml

```<!-- FlatBarTemplate.xml -->

1. PLAYER_XP_UPDATE event fires<Frame name="FlatBarTemplate_v2" virtual="true" mixin="FlatBarXPBarMixin">

   ↓    <Frames>

2. XPBarContextBuilder:Build() → context = { currentXP, maxXP, level, restedXP, ... }        <StatusBar parentKey="StatusBar">...</StatusBar>

   ↓    </Frames>

3. TriggerXPChanged(context) → calls action methods</Frame>

   ↓```

4. UpdateVisuals(context) → delegates to:

   - UpdateBars(context)     → StatusBar:SetValue(currentXP)WoW automatically applies the mixin when parsing XML. No Lua code needed at runtime.

   - UpdateTexts(context)    → XPText:SetText(format), etc.

   - UpdateOverlays(context) → Update*Overlay methods### Development/Testing (Programmatic)

``````lua

-- Test harness only - production uses XML mixin attribute

**Key principle:** Context flows **explicitly** through the event pipeline. No caching, no state.local frame = CreateFrame("Frame", "TestBar", UIParent, "FlatBarTemplate_v2")

XPBarEnhanced_ApplyFlatBarStyle(frame, {

## Comparison: Legacy vs v2    position = { mode = "DRAGGABLE" },

    animation = { xpGainFlash = true },

| Aspect | Legacy Implementation | v2 Implementation | Change |})

|--------|----------------------|-------------------|--------|```

| **Lines of Code** | ~400 lines | ~50 lines | **-87.5%** |

| **Files** | 2 files (Lua + XML) | 2 files (Lua + XML) | Same |**Note:** `XPBarEnhanced_ApplyFlatBarStyle` is for test/dev only. It's kept for:

| **XML Responsibility** | Create visuals + setup | Create visuals only | Simplified |- Test harness (programmatic frame creation)

| **Lua Responsibility** | All logic + setup | Config + optional overrides | Focused |- Future virtual template optimization (load only selected style)

| **Overlay Creation** | XML required all overlays | BaseMixin creates if missing | **Mandatory** |

| **Code Reuse** | Copy/paste between styles | Inherit from BaseMixin | **Composition** |## Configuration Options

| **Custom Layouts** | Full reimplementation | Override specific methods | **Targeted** |

| **Testing** | Reload addon | `/xptest` commands | **Faster** |```lua

| **Maintainability** | High duplication | Single source of truth | **Better** |{

    animation = {

## Testing        enabled = true,

        valueSmoothing = true,  -- Ease-out transitions

Enable v2 testing:        xpGainFlash = true,     -- Flash on XP gain

```lua        levelUpFlash = true,    -- Flash on level-up

XPChronicleConfig.enableDevV2 = true    },

```    interaction = {

        enabled = true,         -- Mouse handlers

Available commands:    },

- `/xptest create` - Create test bar    tooltip = {

- `/xptest destroy` - Remove test bar        enabled = true,

- `/xptest reset` - Reset bar position

- `/xptest show/hide` - Toggle visibility    },

- `/xptest refresh` - Force visual update    position = {

- `/xptest context` - Print current context        mode = "STATIC",        -- "STATIC" or "DRAGGABLE"

- `/xptest session` - Print session stats        positionKey = "FlatBar_v2",

- `/xptest flash` - Test flash animation    },

- `/xptest levelup` - Test level-up effect    style = {

- `/xptest drag` - Toggle drag mode        width = 565,

- `/xptest help` - Show all commands        height = 11,

        showQuestOverlays = true,

## Implementation Notes    },

}

1. **Overlay Creation**: All overlays (RestedLevel, Quest overlays, ExhaustionTick, GainFlash) are created by BaseMixin:BuildVisuals() to ensure full feature parity with existing FlatXPBar. Styles can disable via config.```



2. **Color System**: Always use `XPBarColors:GetUserColor(colorKey)` - never hardcode colors. User preferences are respected.## Event Flow



3. **Context Passing**: Context is passed explicitly through all method calls. No caching, no shared state.```

PLAYER_XP_UPDATE

4. **XML Contract**: XML must create StatusBar widget. All other elements are optional and created by BaseMixin if missing.   └─> XPBarMixinBase_v2:OnEvent()

         └─> XPBarContextBuilder:BuildXPChangeContext()

5. **Load Order**: Style file must load after core v2 modules (ContextBuilder, StyleBuilder, BaseMixin, mixins) in .toc file.               └─> XPBarMixinBase_v2:TriggerXPChanged(context)

                     ├─> UpdateCurrentXPBar(context) [Action method]

6. **Empty Template**: FlatBar proves the architecture works - an empty style template is sufficient for standard linear layouts because BaseMixin provides all necessary defaults.                     ├─> UpdateRestedOverlay(context) [Action method]

                     ├─> UpdateQuestOverlays(context) [Action methods]

## Next Steps                     ├─> UpdateExhaustionTick(context) [Action method]

                     └─> UpdateVisuals(context)

1. Test in-game with `/xptest` commands                           ├─> UpdateBars(context)     [Base default]

2. Verify all overlays display correctly                           ├─> UpdateOverlays(context) [Base default]

3. Test drag/drop, tooltips, animations                           └─> UpdateTexts(context)    [Base default]

4. Port circular style (will need UpdateBars override for arc positioning)```

5. Deprecate legacy implementation once all styles ported

## File Organization

```
ui/xpbars/flatbar_v2/
├── FlatBarStyle.lua        # Style registration (minimal, ~80 lines)
├── FlatBarTemplate.xml     # Visual structure (XML contract)
└── README.md              # This file
```

**Removed:** FlatBarStyleTemplate.lua (no longer needed - BaseMixin handles defaults)

## Comparison with Legacy

| Aspect | Legacy FlatBar | FlatBar v2 |
|--------|---------------|------------|
| XML Structure | ✅ Same | ✅ Same (reused) |
| Lua File Count | 1 (FlatXPBarMixin.lua) | 1 (FlatBarStyle.lua) |
| Event Handling | ❌ Monolithic | ✅ Trigger/Action pattern |
| Animations | ❌ Mixed in | ✅ Separate mixin |
| Dragging | ❌ Mixed in | ✅ Separate mixin |
| Tooltips | ❌ Mixed in | ✅ Separate mixin |
| Composition | ❌ Manual | ✅ StyleBuilder |
| Context Objects | ❌ Direct mutation | ✅ Immutable contexts |
| **Lines of Code** | ~400 lines | ~80 lines |

**Key Improvement:** v2 achieves 80% code reduction by relying on BaseMixin defaults and behavior mixins.

## Testing

Test commands:
```
/xptest create     - Create test bar
/xptest context    - View current context
/xptest flash      - Test animations
/xptest drag       - Toggle dragging
/xptest help       - All commands
```

## License

Copyright (c) 2025 XPBarEnhanced. Licensed under MIT.
