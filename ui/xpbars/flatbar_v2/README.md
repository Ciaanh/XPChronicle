# FlatBar Style v2

A demonstration style showing the complete v2 architecture implementation.

## Overview

FlatBar is a **linear/horizontal** experience bar that mimics the classic Blizzard XP bar but with enhanced features:

- **Rested overlay**: Shows rested XP as a lighter color overlay
- **Quest overlays**: Displays quest XP gained (complete and incomplete)
- **Exhaustion tick**: Marker showing where rested XP ends
- **Flash effects**: Optional XP gain and level-up animations
- **Interactive tooltips**: Detailed XP, rested, and session stats
- **Draggable**: Optional dragging with saved positions

## Files

- **FlatBarStyleTemplate.lua**: Visual methods (`BuildVisuals`, `UpdateVisuals`)
- **FlatBarStyle.lua**: Composition and registration (`XPBarEnhanced_CreateFlatBarStyle`)
- **FlatBarTemplate.xml**: Frame structure with StatusBar and text overlays
- **README.md**: This file

## Usage

### Creating a FlatBar instance

```lua
-- Method 1: Create from template (simplest)
local bar = CreateFrame("Frame", "MyFlatBar", UIParent, "FlatBarTemplate_v2")
XPBarEnhanced_ApplyFlatBarStyle(bar)

-- Method 2: Create with custom config
local bar = CreateFrame("Frame", "MyFlatBar", UIParent, "FlatBarTemplate_v2")
XPBarEnhanced_ApplyFlatBarStyle(bar, {
	position = {
		mode = "DRAGGABLE",
		positionKey = "MyFlatBar",
	},
	animation = {
		enabled = true,
		xpGainFlash = true,
	},
	style = {
		width = 800,
		height = 15,
	},
})

-- Method 3: Direct mixin application (advanced)
local bar = CreateFrame("Frame", "MyFlatBar", UIParent, "FlatBarTemplate_v2")
Mixin(bar, FlatBarXPBarMixin)
bar.__xpbar_config = { ... }
bar:OnLoad()
```

### Configuration Options

```lua
{
	-- Behavior flags
	animation = {
		enabled = true,
		valueSmoothing = true,
		xpGainFlash = true,
		levelUpFlash = true,
	},
	interaction = {
		enabled = true,
	},
	tooltip = {
		enabled = true,
		provider = nil, -- Uses default
	},
	position = {
		mode = "STATIC", -- "STATIC" or "DRAGGABLE"
		positionKey = "FlatBar_v2",
	},
	
	-- Style-specific config
	style = {
		width = 565,
		height = 11,
		showQuestOverlays = true,
	},
}
```

## Component Composition

FlatBar is composed of the following mixins:

1. **XPBarMixinBase_v2** (core)
   - Event orchestration
   - Trigger/Action pattern
   - Overlay validation
   - Color management

2. **XPBarAnimationMixin** (optional)
   - Value smoothing
   - Flash effects
   - Ease-out animations

3. **XPBarInteractionMixin** (optional)
   - Mouse handlers
   - Click actions (stats, options)

4. **XPBarTooltipMixin** (optional)
   - GameTooltip integration
   - Default content provider

5. **XPBarPositionMixin** (optional)
   - STATIC anchoring
   - DRAGGABLE with persistence

6. **FlatBarStyleTemplate** (visual layer)
   - BuildVisuals(): Create overlays
   - UpdateVisuals(): Update colors/text

## Visual Elements

- **StatusBar**: Main XP progress bar (WoW widget)
- **RestedLevel**: Rested XP overlay (texture)
- **QuestOverlayComplete**: Complete quest XP (texture)
- **QuestOverlayIncomplete**: Incomplete quest XP (texture)
- **ExhaustionTick**: Rested XP end marker (frame)
- **GainFlash**: XP gain flash effect (texture)
- **XPText**: Current/max XP (FontString, left)
- **PercentText**: Percentage (FontString, center)
- **LevelText**: Player level (FontString, right)

## Event Flow

```
PLAYER_XP_UPDATE
   └─> XPBarMixinBase_v2:OnEvent()
         └─> XPBarContextBuilder:BuildXPChangeContext()
               └─> XPBarMixinBase_v2:TriggerXPChanged(context)
                     ├─> UpdateCurrentXPBar(context, "StatusBar")
                     ├─> UpdateMaxXP(context)
                     ├─> UpdateRestedOverlay(context, "RestedLevel")
                     ├─> UpdateQuestCompleteOverlay(context, "QuestOverlayComplete")
                     ├─> UpdateQuestIncompleteOverlay(context, "QuestOverlayIncomplete")
                     ├─> UpdateExhaustionTick(context, "ExhaustionTick")
                     └─> UpdateFlashOverlay(context, "GainFlash")
```

## Customization

### Override Action Methods

```lua
-- Custom XP bar update
function bar:UpdateCurrentXPBar(context, barName)
	local statusBar = self.StatusBar
	if not statusBar then return end
	
	-- Custom logic here
	statusBar:SetMinMaxValues(0, context.maxXP)
	statusBar:SetValue(context.currentXP)
	
	-- Custom color
	statusBar:SetStatusBarColor(1, 0, 0, 1) -- Red
end
```

### Custom Tooltip Provider

```lua
bar.__xpbar_config.tooltip.provider = function(self, tooltip, context)
	tooltip:AddLine("Custom Tooltip")
	tooltip:AddDoubleLine("XP:", context.currentXP)
	return tooltip
end
```

### Custom Flash Animation

```lua
function bar:PlayXPGainAnimation(xpGain)
	-- Custom flash animation
	local flash = self.GainFlash
	if flash then
		flash:Show()
		flash:SetVertexColor(0, 1, 0, 0.5) -- Green flash
		C_Timer.After(0.5, function() flash:Hide() end)
	end
end
```

## Positioning

### STATIC Mode (default)

Anchors to `MainStatusTrackingBarContainer` (Blizzard UI):

```lua
bar:SetPoint("BOTTOMLEFT", MainStatusTrackingBarContainer, "BOTTOMLEFT", 0, 0)
bar:SetPoint("BOTTOMRIGHT", MainStatusTrackingBarContainer, "BOTTOMRIGHT", 0, 0)
```

### DRAGGABLE Mode

Enables dragging with position persistence:

```lua
-- Save position
XPChronicleDB.barPositions["FlatBar_v2"] = {
	point = "BOTTOM",
	relativeTo = "UIParent",
	relativePoint = "BOTTOM",
	x = 0,
	y = 100,
}

-- Reset to default
bar:ResetPosition()
```

## Integration with v2 Architecture

FlatBar demonstrates all v2 architecture features:

1. **ContextBuilder**: Standalone context building with Session integration
2. **StyleBuilder**: Composition utility using `CreateFromMixins`
3. **Base Mixin**: Core event orchestration with Trigger/Action pattern
4. **Behavior Mixins**: Animation, Interaction, Tooltip, Position
5. **Style Template**: Visual methods for building and updating UI

## Testing

See `ui/xpbars/tests/test_v2.lua` for test harness.

## License

Copyright (c) 2025 XPBarEnhanced. Licensed under MIT.
