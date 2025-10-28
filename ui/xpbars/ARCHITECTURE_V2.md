# XPBar v2 — Architecture & Migration Plan

This document defines the architecture, composition flow, and migration plan for the XP bar refactor into `XPBarMixinBase_v2` and independent behavior/style mixins.

Important constraints and decisions

- The new base mixin will be globally named `XPBarMixinBase_v2`.
- **Builder pattern**: Style mixins are created via `StyleBuilder:Create(XPBarMixinBase_v2, config)` which uses `CreateFromMixins` to compose base + behaviors + style template into a new global mixin.
- Style mixins are **globally registered** after creation (e.g., `CircularXPBarMixin = StyleBuilder:Create(...)`), and XML templates reference these composed mixins.
- All new runtime code for v2 will be placed under `ui/xpbars` only. No existing files should be modified.
- **No code cleanup during v2 development**: Existing code (Session, Database, current XPBarMixinBase, etc.) must NOT be modified or removed. Cleanup will be done separately after v2 migration is complete.
- Use `XPChronicleDB.barPositions` for position persistence (the `PositionMixin` will read/write `XPChronicleDB.barPositions[positionKey]`).
- **Color management**: Always use `XPBarColors:GetUserColor(colorKey)` to retrieve user-defined colors from the options panel. Never hardcode color values.

Style mixin creation and XML usage

- **Builder pattern approach**:
  - Style files call `StyleBuilder:Create(XPBarMixinBase_v2, styleTemplate, config)` at load time.
  - Builder internally calls `CreateFromMixins(XPBarMixinBase_v2, AnimationMixin, InteractionMixin, PositionMixin, TooltipMixin, styleTemplate)`.
  - Result is a composed mixin registered globally (e.g., `CircularXPBarMixin`).
  - XML templates reference the composed mixin: `<Frame mixin="CircularXPBarMixin">`.
- **Mixin composition order**: Base → Behaviors → Style (style overrides win).
- **No runtime Mixin() calls**: All composition happens once at addon load via CreateFromMixins.

Event registration policy

- The new base must support the same events used by the current `XPBarMixinBase.lua`. The base will expose `RegisterCommonEvents()` and `RegisterQuestEvents()` helpers; styles/mixins request quest events explicitly. See the Event list section below for the full set.

Simplicity and error handling

- Avoid pcall-based error swallowing. Prefer explicit errors so failures are surfaced early during development. Keep implementations simple and easy to read.

Summary

- Add new files under `ui/xpbars/`:
  - `StyleBuilder.lua` — global `XPBarStyleBuilder` for composing style mixins
  - `BaseMixin.lua` (global `XPBarMixinBase_v2`) — event orchestration, default API, Trigger/Action methods
  - `ContextBuilder.lua` — standalone utility module for building immutable context objects (integrates Session methods)
  - `mixins/AnimationMixin.lua` — value smoothing, transitions, and flash effects
  - `mixins/InteractionMixin.lua` — mouse handling, clicks (non-tooltip)
  - `mixins/TooltipMixin.lua` — tooltip provider and GameTooltip management
  - `mixins/PositionMixin.lua` — positioning (STATIC anchored to Blizzard bar | DRAGGABLE with persistence)
  - `flatbar_v2/FlatBarStyleTemplate.lua` — style template (visual methods only)
  - `flatbar_v2/FlatBarStyle.lua` — calls StyleBuilder to create `FlatBarXPBarMixin`
  - `flatbar_v2/FlatBarTemplate.xml` — XML frame template
  - `tests/test_v2.lua` — dev harness (gated by config flag)

Goals

- Use `StyleBuilder` to compose mixins via `CreateFromMixins` at addon load time (not per-frame).
- Extract animation (including flash effects), interaction, tooltip, and positioning logic to dedicated behavior mixins.
- Separate context building into standalone utility module (`ContextBuilder`) that integrates/replaces Session functionality.
- Keep style templates limited to visuals and layout (BuildVisuals, UpdateVisuals, overlay action methods).
- Event handlers in base call `TriggerXXX` methods which orchestrate actions; styles override individual actions or overlay methods, not event handlers.
- Preserve all existing features of the current `XPBarMixinBase` by mapping them into base, ContextBuilder, or appropriate behavior mixins.
- Support all current visual elements: current XP bar, completed quest overlay, incomplete quest overlay, rested overlay, exhaustion tick marker, and flash overlay.


## 1. Component responsibilities (detailed)

### XPBarContextBuilder (`ui/xpbars/ContextBuilder.lua`)

**Standalone utility module** (NOT a mixin) that provides context building functions with integrated Session calculation methods.

Primary responsibilities:

- Expose global `XPBarContextBuilder = {}` table with utility functions.
- Build immutable context objects from game events and player state.
- Integrate/duplicate/replace Session calculation methods (XP rate, time to level, session stats).
- Provide no-dependency context building (does not require Session to exist).

Context building functions:

```lua
-- Build context for XP change events
function XPBarContextBuilder.BuildXPChangeContext(event, ...)
  -- Returns: { xpBefore, xpAfter, xpGained, xpMax, level, currentXP, restedXP, 
  --           completeQuestXP, incompleteQuestXP, timestamp, source, 
  --           xpPerHour, sessionXP, sessionDuration }
end

-- Build context for level-up events
function XPBarContextBuilder.BuildLevelUpContext(event, ...)
  -- Returns: { oldLevel, newLevel, timestamp, xpMax, restedXP, 
  --           completeQuestXP, incompleteQuestXP }
end

-- Build context for rested state change
function XPBarContextBuilder.BuildRestedContext(event, ...)
  -- Returns: { isRested, restedXP, currentXP, xpMax, level, timestamp, 
  --           isFullyRested, completeQuestXP, incompleteQuestXP }
end

-- Build context for quest overlay updates
function XPBarContextBuilder.BuildQuestContext(event, ...)
  -- Returns: { completeQuestXP, incompleteQuestXP, completeCount, incompleteCount,
  --           currentXP, xpMax, level, timestamp }
end
```

Integrated Session calculation methods (duplicated from `core/Session.lua`):

```lua
-- Calculate XP gain rate (XP per hour)
function XPBarContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
  -- Returns: number (XP per hour based on session or level-time fallback)
end

-- Calculate estimated time to next level
function XPBarContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour)
  -- Returns: number (seconds to level up at current rate)
end

-- Build session stats snapshot
function XPBarContextBuilder.BuildSessionStats(sessionStart, sessionXP, realLevelTime, realTotalTime)
  -- Returns: { duration, xpGained, xpPerHour, startTime, realTotalTime, realLevelTime }
end
```

Context shape conventions:

- All contexts are immutable tables (never modified after creation).
- All contexts include `timestamp = time()` for tracking when context was built.
- Contexts include ALL relevant state for their purpose (no partial state).
- Quest XP values (`completeQuestXP`, `incompleteQuestXP`) are always included where relevant.

Integration plan:

- **Phase 1 (v2)**: ContextBuilder duplicates Session calculation methods independently. ContextBuilder has NO dependencies on existing Session, Database, or other core modules.
- **Phase 2 (future, post-migration)**: Refactor `core/Session.lua` to use ContextBuilder internally, Session becomes thin wrapper.
- **Phase 3 (cleanup, post-migration)**: Consider removing Session entirely if all consumers moved to ContextBuilder.
- **IMPORTANT**: During Phase 1 (v2 development), NO existing code should be modified. ContextBuilder must be fully independent to minimize complexity and impact.

### XPBarStyleBuilder (`ui/xpbars/StyleBuilder.lua`)

Primary responsibilities:

- Expose global `XPBarStyleBuilder = {}`.
- Provide `Create(baseMixin, styleTemplate, config)` which:
  - Validates inputs and config.
  - Builds behavior mixin list based on config flags (animation, interaction, tooltip, position mode).
  - Calls `CreateFromMixins(baseMixin, AnimationMixin, InteractionMixin, TooltipMixin, PositionMixin, styleTemplate)`.
  - Returns the composed mixin ready for global registration.
- **Composition order**: Base → AnimationMixin → InteractionMixin → TooltipMixin → PositionMixin → StyleTemplate.
- **Result**: Style methods override behavior/base methods (style wins).

Usage pattern:

```lua
-- In flatbar_v2/FlatBarStyle.lua (loaded at addon init)
local FlatBarStyleTemplate = {} -- Visual methods only
function FlatBarStyleTemplate:BuildVisuals() ... end
function FlatBarStyleTemplate:UpdateVisuals() ... end

local config = {
  animation = { enabled = true, valueSmoothing = 0.2 },
  interaction = { enabled = true },
  tooltip = { enabled = true, provider = MyTooltipProvider },
  position = { mode = "DRAGGABLE", positionKey = "FlatBarXP" }, -- or "STATIC"
}

FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, FlatBarStyleTemplate, config)
```

### XPBarMixinBase_v2 (`ui/xpbars/BaseMixin.lua`)

Primary responsibilities:

- Expose global `XPBarMixinBase_v2 = {}`.
- Provide the public API surface: `SetValue`, `GetValue`, `SetMax`, `GetMax`, `SetColor`, `GetColor`, `Refresh`.
- **Event registration and orchestration**: Register events and dispatch to `TriggerXXX` methods.
- **Use ContextBuilder** to build immutable context objects (does NOT duplicate context building logic).
- Provide default lifecycle methods: `OnLoad`, `OnShow`, `OnHide` stubs/hook points.
- Define abstract visual methods that MUST be provided by the style template:
  - `BuildVisuals(self)` — create textures/fontstrings/frames
  - `UpdateVisuals(self)` — update textures and text based on state
  - `ApplyStyle(self, styleConfig)` — optional style parameters
- Define overlay action methods with default overlay names (CAN be overridden by styles):
  - `UpdateCurrentXPBar(context, barName)` — defaults to "StatusBar"
  - `UpdateRestedOverlay(context, overlayName)` — defaults to "RestedLevel"
  - `UpdateQuestCompleteOverlay(context, overlayName)` — defaults to "QuestOverlayComplete"
  - `UpdateQuestIncompleteOverlay(context, overlayName)` — defaults to "QuestOverlayIncomplete"
  - `UpdateExhaustionTick(context, tickName)` — defaults to "ExhaustionTick"
  - `UpdateFlashOverlay(context, flashName)` — defaults to "GainFlash"

Visual elements supported (based on current implementation analysis):

1. **Current XP Bar** (`StatusBar`) — WoW StatusBar widget representing current XP filled portion
   - Uses native StatusBar:SetValue() for automatic fill animation and smoothing
   - Provides percentage-based fill (0.0 to 1.0) with built-in visual updates
   - Color changes based on rested state via StatusBar:SetStatusBarColor()
   - **Rationale for keeping StatusBar**: Native widget provides optimized smoothing, automatic width calculation, and follows WoW standard pattern. Using overlay would require manual animation and increase code complexity.

2. **Rested Overlay** (`RestedLevel`) — visual overlay showing rested/bonus XP available

3. **Quest Complete Overlay** (`QuestOverlayComplete`) — completed quest XP waiting to be turned in

4. **Quest Incomplete Overlay** (`QuestOverlayIncomplete`) — incomplete quest XP (progress toward completion)

5. **Exhaustion Tick** (`ExhaustionTick`) — marker showing end of rested XP region (button with tooltip)

6. **Flash Overlay** (`GainFlash`) — animation flash effect for XP gains/level-ups

Event list (collected from current implementation)

The base must be compatible with the full set of events currently used by `XPBarMixinBase.lua`:

**Common events** (always registered via `OnLoad`):

- `PLAYER_XP_UPDATE`
- `PLAYER_LEVEL_UP`
- `UPDATE_EXHAUSTION`
- `PLAYER_ENTERING_WORLD`
- `PLAYER_UPDATE_RESTING`
- `TIME_PLAYED_MSG`

**Quest-related events** (registered via behavior mixin OnLoad if quest overlay enabled):

- `QUEST_ACCEPTED`
- `QUEST_REMOVED`
- `QUEST_TURNED_IN`
- `QUEST_LOG_UPDATE`
- `UNIT_QUEST_LOG_CHANGED`
- `QUEST_WATCH_UPDATE`

**Quest-related events** (registered via behavior mixin OnLoad if quest overlay enabled):

- `QUEST_ACCEPTED`
- `QUEST_REMOVED`
- `QUEST_TURNED_IN`
- `QUEST_LOG_UPDATE`
- `UNIT_QUEST_LOG_CHANGED`
- `QUEST_WATCH_UPDATE`

Event orchestration pattern (Trigger/Action separation):

- **Event handlers** (should NOT be overridden by styles):
  - `OnEvent(event, ...)` — dispatcher that calls ContextBuilder and Trigger methods
  - Event handlers do not contain business logic

- **Trigger methods** (orchestrate actions, should NOT be overridden):
  - `TriggerXPChanged(context)` — orchestrates XP change response
    - Calls: `UpdateCurrentXPBar(context)`, `UpdateRestedOverlay(context)`, `UpdateQuestCompleteOverlay(context)`, `UpdateQuestIncompleteOverlay(context)`, `UpdateExhaustionTick(context)`, `PlayXPGainAnimation(context)`, `FlashXPGain(context)`
  - `TriggerLevelUp(context)` — orchestrates level-up response
    - Calls: `UpdateCurrentXPBar(context)`, `UpdateMaxXP(context)`, `UpdateRestedOverlay(context)`, `PlayLevelUpAnimation(context)`, `FlashLevelUp(context)`
  - `TriggerRestedChanged(context)` — orchestrates rested state change
    - Calls: `UpdateRestedOverlay(context)`, `UpdateExhaustionTick(context)`, `UpdateVisuals()`
  - `TriggerQuestChanged(context)` — orchestrates quest overlay updates
    - Calls: `UpdateQuestCompleteOverlay(context)`, `UpdateQuestIncompleteOverlay(context)`, `UpdateVisuals()`

- **Action methods** (CAN be overridden by styles for custom behavior):
  - `UpdateCurrentXPBar(context, barName)` — update main bar value from context (default barName: "StatusBar")
  - `UpdateMaxXP(context)` — update bar max from context
  - `UpdateRestedOverlay(context, overlayName)` — update rested overlay position/size/visibility (default: "RestedLevel")
  - `UpdateQuestCompleteOverlay(context, overlayName)` — update completed quest overlay (default: "QuestOverlayComplete")
  - `UpdateQuestIncompleteOverlay(context, overlayName)` — update incomplete quest overlay (default: "QuestOverlayIncomplete")
  - `UpdateExhaustionTick(context, tickName)` — update exhaustion tick marker position/visibility (default: "ExhaustionTick")
  - `UpdateFlashOverlay(context, flashName)` — update flash overlay (default: "GainFlash")
  - `PlayXPGainAnimation(context)` — trigger gain animation (delegates to AnimationMixin, optional)
  - `PlayLevelUpAnimation(context)` — trigger level-up animation (delegates to AnimationMixin, optional)
  - `FlashXPGain(context)` — trigger flash effect on XP gain (delegates to AnimationMixin, optional)
  - `FlashLevelUp(context)` — trigger flash effect on level-up (delegates to AnimationMixin, optional)

Overlay action method implementation notes:

- **Color retrieval**: Always use `XPBarColors:GetUserColor(colorKey)` to get user-defined colors from options panel.
  - Available color keys (from `core/Colors.lua`): `Color.XpBar`, `Color.XpBarRested`, `Color.Rested`, `Color.QuestComplete`, `Color.QuestIncomplete`
  - Example: `local color = XPBarColors:GetUserColor(Color.Rested); overlay:SetVertexColor(color.r, color.g, color.b, color.a)`
- **Overlay validation**: Methods should validate overlay existence and log warnings if missing (development phase needs meaningful debug info).
  - Example: `if not self[overlayName] then Logger:Warn("Overlay not found: " .. overlayName); return end`
- **Flash effects**: Optional — styles can no-op flash methods if not supporting animations.

Overlay action method signature pattern:

```lua
-- Base provides default implementation with default overlay name
function XPBarMixinBase_v2:UpdateRestedOverlay(context, overlayName)
  overlayName = overlayName or "RestedLevel"  -- Default name
  local overlay = self[overlayName]
  
  -- Validate overlay exists (log warning in development)
  if not overlay then
    if Addon.Logger then
      Addon.Logger:Warn("UpdateRestedOverlay: overlay not found - " .. overlayName)
    end
    return
  end
  
  -- Get user-defined color from options panel
  local color = XPBarColors:GetUserColor(Color.Rested)
  overlay:SetVertexColor(color.r, color.g, color.b, color.a)
  
  -- Calculate position/size from context
  -- Apply to overlay texture
end

-- Style can override to use different overlay name or custom logic
function CircularXPBarStyleTemplate:UpdateRestedOverlay(context, overlayName)
  overlayName = overlayName or "RestedArc"  -- Circular uses different name
  -- Custom circular layout logic
end
```

Context usage pattern:

```lua
-- Base event handler calls ContextBuilder and Trigger
function XPBarMixinBase_v2:OnEvent(event, ...)
  if event == "PLAYER_XP_UPDATE" then
    local context = XPBarContextBuilder.BuildXPChangeContext(event, ...)
    self:TriggerXPChanged(context)
  elseif event == "PLAYER_LEVEL_UP" then
    local context = XPBarContextBuilder.BuildLevelUpContext(event, ...)
    self:TriggerLevelUp(context)
  -- ... more events
  end
end

-- Trigger orchestrates action sequence
function XPBarMixinBase_v2:TriggerXPChanged(context)
  self:UpdateCurrentXPBar(context)
  self:UpdateRestedOverlay(context)
  self:UpdateQuestCompleteOverlay(context)
  self:UpdateQuestIncompleteOverlay(context)
  self:UpdateExhaustionTick(context)
  self:PlayXPGainAnimation(context)
  self:FlashXPGain(context)
end
```


### AnimationMixin (`ui/xpbars/mixins/AnimationMixin.lua`)

Responsibilities:

- Provide methods for value smoothing/tweening: value changes animate over time instead of instant jumps.
- Provide Show/Hide transitions.
- **Flash effects**: Handle flash animations triggered by XP gains, level-ups, etc.
- Expose `PlayAnimation(name, params)` and `StopAnimation(name)` for style customization.
- Provide `OnLoad()` to register as a behavior mixin (no events registered here).

Behavior details:

- Value smoothing: Intercept `SetValue` calls and perform tick-based interpolation over configured duration.
- Flash effects target a dedicated flash frame (created by style in BuildVisuals if flash enabled).
- Animation actions (called by base Trigger methods):
  - `PlayXPGainAnimation(context)` — smooth value transition
  - `PlayLevelUpAnimation(context)` — level-up animation sequence
  - `FlashXPGain(context)` — flash effect on XP gain
- Clean up timers/animations on `OnHide` or when animations complete.


### InteractionMixin (`ui/xpbars/mixins/InteractionMixin.lua`)

Responsibilities:

- Mouse enter/leave handlers for non-tooltip interactions.
- Click handling (click callbacks configurable via config or style override).
- Keyboard or accessibility hooks if needed (optional).
- Provide `OnLoad()` to register as a behavior mixin (no events registered here).
- Does NOT include tooltip management (see TooltipMixin).

Behavior details:

- Provide `OnMouseDown`, `OnMouseUp` handlers.
- Click actions can be overridden by styles for custom behavior.


### TooltipMixin (`ui/xpbars/mixins/TooltipMixin.lua`)

Responsibilities:

- Tooltip management: show GameTooltip on mouse enter, hide on leave.
- Tooltip content provider: configurable via `config.tooltip.provider` or style override.
- Provide `OnLoad()` to register as a behavior mixin (no events registered here).

Behavior details:

- `OnEnter` — show tooltip with content from provider
- `OnLeave` — hide tooltip
- Default tooltip provider shows: current XP, XP to next level, rested XP, level
- Styles can override `GetTooltipContent(context)` for custom tooltip data


### PositionMixin (`ui/xpbars/mixins/Position Mixin.lua`)

Responsibilities:

- Handle positioning in two modes: `STATIC` (anchored to Blizzard MainMenuExpBar) or `DRAGGABLE` (user-movable with persistence).
- Duplicate minimal PositionStore functions but persist to `XPChronicleDB.barPositions` (per user instruction).
- Provide `OnLoad()` to register as a behavior mixin and apply initial position based on config.

Position modes:

- **STATIC**: Frame is anchored to the default Blizzard XP bar position (match current legacy bar behavior).
- **DRAGGABLE**: Frame can be dragged; position is saved to `XPChronicleDB.barPositions[positionKey]` and restored on load.

Persisted storage conventions (DRAGGABLE mode):

- Use `XPChronicleDB = XPChronicleDB or { barPositions = {} }` (ensure parent table exists).
- The config must provide `config.position.positionKey` — a unique string for this bar instance.
- Saved record shape: `XPChronicleDB.barPositions[positionKey] = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 100, y = -50 }`.

Duplicated functions (planned):

- `GetPositionKey(self)` — returns config position key
- `SavePosition(self)` — serializes first anchor and writes to DB (DRAGGABLE mode only)
- `RestorePosition(self)` — read saved record and apply (DRAGGABLE mode only)
- `ClearSavedPosition(self)` — remove stored position
- `ApplyStaticPosition(self)` — anchor to Blizzard MainMenuExpBar (STATIC mode)
- `EnableDragging(self, enabled)` — bind/unbind drag scripts (DRAGGABLE mode only)

Notes:

- These methods intentionally duplicate only needed behavior to avoid touching existing `PositionStoreMixin`.
- The `PositionMixin` will not create or alter other `XPChronicleDB` keys; it operates only in `XPChronicleDB.barPositions`.

### Style mixins (example: FlatBarStyleMixin v2 / `ui/xpbars/flatbar_v2/FlatBarStyleMixin.lua`)

Responsibilities:

- Implement `BuildVisuals(self)` and `UpdateVisuals(self)` to create textures, background, fontstrings and apply the numeric state to visuals.
- **Global registration**: The style mixin is registered globally (e.g., `FlatBarStyleMixin_v2 = {}`), so XML templates can reference it directly via `mixin="FlatBarStyleMixin_v2"`.
- Styles may optionally provide `ApplyStyle(self, styleConfig)` to apply style-specific configuration.
- Styles **CAN override overlay action methods** to use different overlay names or custom layout logic:
  - Override `UpdateRestedOverlay(context, overlayName)` to use custom overlay name (e.g., circular uses "RestedArc" instead of "ExhaustionLevelFillBar")
  - Override `UpdateQuestCompleteOverlay(context, overlayName)` for custom quest overlay handling
  - Override `UpdateExhaustionTick(context, tickName)` for custom tick marker positioning
- Keep all assets and visual constants local to the style folder.

Visual element naming conventions (recommended):

- Flat/Linear bars (default names):
  - `StatusBar` — main XP bar (StatusBar frame)
  - `RestedLevel` — rested overlay texture
  - `QuestOverlayComplete` — completed quest overlay texture
  - `QuestOverlayIncomplete` — incomplete quest overlay texture
  - `ExhaustionTick` — exhaustion tick marker (Button frame)
  - `GainFlash` — flash overlay texture (optional)

- Circular bars (custom names, requires overrides):
  - `XPArc` — main XP arc
  - `RestedArc` — rested overlay arc
  - `QuestCompleteArc` — completed quest overlay arc
  - `QuestIncompleteArc` — incomplete quest overlay arc
  - `ExhaustionMarker` — exhaustion tick marker (different positioning)
  - `FlashTexture` — flash overlay (optional)

Example override for circular layout:

```lua
function CircularXPBarStyleTemplate:UpdateRestedOverlay(context, overlayName)
  overlayName = overlayName or "RestedArc"  -- Use circular-specific name
  local arc = self[overlayName]
  if not arc then return end
  
  -- Custom arc positioning based on context.restedXP
  local startAngle = (context.currentXP / context.xpMax) * 360
  local endAngle = ((context.currentXP + context.restedXP) / context.xpMax) * 360
  arc:SetArcAngles(startAngle, endAngle)
  arc:SetShown(context.restedXP > 0)
end
```


## 2. Visual Element Layer System (Overlay Architecture)

The XP bar consists of multiple visual layers rendered in a specific order to create the complete display. Understanding this layer system is critical for implementing styles correctly.

### Layer Rendering Order (bottom to top)

1. **Background Layer** (`BACKGROUND` draw layer)
   - Background texture/atlas
   - Provides base visual for the bar container

2. **Current XP Bar** (`StatusBar` frame with `BarTexture`)
   - Main filled portion representing current XP
   - Uses StatusBar:SetValue() / SetMinMaxValues() for native percentage-based fill
   - Native widget provides automatic smoothing and animation
   - Color changes based on rested state via StatusBar:SetStatusBarColor()
   - Always retrieve colors using `XPBarColors:GetUserColor(Color.XpBar)` or `Color.XpBarRested`

3. **Rested Overlay** (`RestedLevel` texture, `ARTWORK` layer, sublevel -1)
   - Visual overlay showing rested/bonus XP available
   - Positioned after current XP, sized based on available rested XP
   - Color retrieved via `XPBarColors:GetUserColor(Color.Rested)`
   - Hidden when fully rested or no rested XP available

4. **Quest Complete Overlay** (`QuestOverlayComplete` texture, `OVERLAY` layer, sublevel 1)
   - Shows XP from completed quests waiting to be turned in
   - Positioned after current XP (and after rested if both present)
   - Color retrieved via `XPBarColors:GetUserColor(Color.QuestComplete)`
   - Conditional rendering based on `showCompleteQuestOverlay` config

5. **Quest Incomplete Overlay** (`QuestOverlayIncomplete` texture, `OVERLAY` layer, sublevel 2)
   - Shows XP from incomplete quest progress
   - Positioned after quest complete overlay (if present)
   - Color retrieved via `XPBarColors:GetUserColor(Color.QuestIncomplete)`
   - Conditional rendering based on `showIncompleteQuestOverlay` config

6. **Exhaustion Tick Marker** (`ExhaustionTick` button, `MEDIUM` frame strata)
   - Visual marker showing end of rested XP region
   - Positioned at the right edge of the rested overlay
   - Interactive element (button with OnEnter tooltip)
   - Hidden when rested ratio < 1% or > 99%

7. **Flash Overlay** (`GainFlash` texture, `OVERLAY` layer, sublevel 3)
   - Full-area overlay for flash animation effects
   - Triggers on XP gains and level-ups (optional, styles can no-op flash methods)
   - Typically white texture with animated alpha (fade in/out)
   - Always on top to ensure visibility during animations

8. **Text Overlays** (`ARTWORK` layer, sublevel 5)
   - Level text (left-aligned)
   - XP text (center-aligned)
   - Percent text (right-aligned)
   - Rendered on top of all textures for readability

### Overlay Positioning Algorithm

The base provides a standard algorithm for calculating overlay positions. Styles can override individual overlay action methods to use custom positioning logic.

Standard linear positioning (flat bar):

```lua
-- 1. Current XP bar (fills from left)
local currentRatio = currentXP / maxXP
local currentPixels = currentRatio * barWidth
StatusBar:SetValue(currentRatio)

-- 2. Rested overlay (starts after current XP)
local remainingXP = maxXP - currentXP
local restedXPClamped = min(restedXP, remainingXP)
local restedRatio = restedXPClamped / maxXP
local restedPixels = restedRatio * barWidth
local color = XPBarColors:GetUserColor(Color.Rested)
RestedLevel:SetVertexColor(color.r, color.g, color.b, color.a)
RestedLevel:SetPoint("BOTTOMLEFT", currentPixels, 0)
RestedLevel:SetWidth(restedPixels)

-- 3. Quest complete overlay (starts after rested)
local questCompleteStart = currentPixels + restedPixels
local questCompleteRatio = completeQuestXP / maxXP
local questCompletePixels = questCompleteRatio * barWidth
QuestOverlayComplete:SetPoint("BOTTOMLEFT", questCompleteStart, 0)
QuestOverlayComplete:SetWidth(questCompletePixels)

-- 4. Quest incomplete overlay (starts after quest complete)
local questIncompleteStart = questCompleteStart + questCompletePixels
local questIncompleteRatio = incompleteQuestXP / maxXP
local questIncompletePixels = questIncompleteRatio * barWidth
QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", questIncompleteStart, 0)
QuestOverlayIncomplete:SetWidth(questIncompletePixels)

-- 5. Exhaustion tick (positioned at rested overlay end)
ExhaustionTick:SetPoint("CENTER", RestedLevel, "RIGHT", 0, 0)
ExhaustionTick:SetShown(restedRatio >= 0.01 and restedRatio <= 0.99)
```

Circular positioning example (requires override):

```lua
-- Circular bars use arc angles instead of linear positions
function CircularXPBarStyleTemplate:UpdateRestedOverlay(context, overlayName)
  local arc = self[overlayName or "RestedArc"]
  if not arc then return end
  
  local currentAngle = (context.currentXP / context.xpMax) * 360
  local restedAngle = (context.restedXP / context.xpMax) * 360
  local endAngle = min(currentAngle + restedAngle, 360)
  
  arc:SetStartAngle(currentAngle)
  arc:SetEndAngle(endAngle)
  arc:SetShown(context.restedXP > 0 and not context.isFullyRested)
end
```

### Overlay Visibility Rules

Each overlay has specific visibility conditions that must be enforced:

| Overlay | Show Condition | Hide Condition |
|---------|---------------|----------------|
| RestedLevel | `restedXP > 0 AND restedXP < remainingXP` | `restedXP == 0 OR isFullyRested` |
| QuestOverlayComplete | `config.showComplete AND completeQuestXP > 0 AND ratio >= 0.01` | `!config.showComplete OR completeQuestXP == 0 OR ratio < 0.01` |
| QuestOverlayIncomplete | `config.showIncomplete AND incompleteQuestXP > 0 AND ratio >= 0.01` | `!config.showIncomplete OR incompleteQuestXP == 0 OR ratio < 0.01` |
| ExhaustionTick | `restedXP > 0 AND restedRatio >= 0.01 AND restedRatio <= 0.99` | `restedXP == 0 OR restedRatio < 0.01 OR restedRatio > 0.99` |
| GainFlash | During animation only (optional) | When animation completes or not supported |

### Overlay Color Conventions

All colors must be retrieved from user settings via `XPBarColors:GetUserColor(colorKey)`. Never hardcode color values.

Available color keys (from `core/Colors.lua`):

| Color Key | Usage | Retrieved Via |
|-----------|-------|---------------|
| `Color.XpBar` | StatusBar normal state | `XPBarColors:GetUserColor(Color.XpBar)` |
| `Color.XpBarRested` | StatusBar when player is rested | `XPBarColors:GetUserColor(Color.XpBarRested)` |
| `Color.Rested` | RestedLevel overlay | `XPBarColors:GetUserColor(Color.Rested)` |
| `Color.QuestComplete` | QuestOverlayComplete | `XPBarColors:GetUserColor(Color.QuestComplete)` |
| `Color.QuestIncomplete` | QuestOverlayIncomplete | `XPBarColors:GetUserColor(Color.QuestIncomplete)` |

Color application example:

```lua
-- Get user-defined color from options panel
local color = XPBarColors:GetUserColor(Color.Rested)

-- Apply to texture
texture:SetVertexColor(color.r, color.g, color.b, color.a)

-- Apply to StatusBar
statusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
```

**Note**: Flash overlay typically uses white `{r=1.0, g=1.0, b=1.0}` with animated alpha, but can use user-defined colors if desired.

### Context Requirements for Overlays

Each overlay action method receives a context object with required fields:

```lua
-- Overlay context shape (from ContextBuilder)
context = {
  -- Core XP values (required for all overlays)
  currentXP = number,
  xpMax = number,
  level = number,
  timestamp = number,
  
  -- Rested values (required for rested overlay + exhaustion tick)
  restedXP = number,
  isRested = boolean,
  isFullyRested = boolean,
  
  -- Quest values (required for quest overlays)
  completeQuestXP = number,
  incompleteQuestXP = number,
  completeCount = number,
  incompleteCount = number,
  
  -- Session values (optional, for tooltip/stats)
  xpPerHour = number,
  sessionXP = number,
  sessionDuration = number,
  realLevelTime = number,
  realTotalTime = number,
}
```

## 3. Setup & composition flow (final sequence)

The recommended flow (XML-first with builder pattern) is:

1. **XML template declares the frame and references the style mixin**:

   ```xml
   <Frame name="XPBar_Main_v2" parent="UIParent" mixin="FlatBarStyleMixin_v2" virtual="false">
       <Size x="320" y="18"/>
       <Scripts>
           <OnLoad method="OnLoad"/>
       </Scripts>
   </Frame>
   ```

2. **Style mixin defines OnLoad to call Setup**:

   In `FlatBarStyleMixin_v2`:

   ```lua
   FlatBarStyleMixin_v2 = {}
   
   function FlatBarStyleMixin_v2:OnLoad()
       local config = {
           style = { width = 320, height = 18, barColor = { r = 0.2, g = 0.6, b = 1 } },
           animation = { enabled = true, valueSmoothing = 0.2 },
           interaction = { enabled = true, draggable = true, positionKey = "XPBar_Main_v2" },
       }
       self:Setup(config)
   end
   
   function FlatBarStyleMixin_v2:BuildVisuals()
       -- Create textures, fontstrings, etc.
   end
   
   function FlatBarStyleMixin_v2:UpdateVisuals()
       -- Update bar fill, text, etc. based on self:GetValue() / self:GetMax()
   end
   ```

3. **Inside `self:Setup(config)` (provided by `XPBarMixinBase_v2` after being mixed in)**:

   - Store `config` on `self.__xpbar_config`.
   - Build behavior mixin list based on `config` (e.g., AnimationMixin, InteractionMixin, DraggableMixin).
   - Call `Mixin(self, XPBarMixinBase_v2, unpack(behaviorMixins))` to add base and behaviors to the frame.
   - Register events via `self:RegisterCommonEvents()`.
   - Call `self:BuildVisuals()` (style-provided).
   - Call `self:ApplyStyle(config.style or {})` if present.
   - Seed state via `self:UpdateCurrentXP()` or `initialValue/initialMax`.
   - If draggable requested, call `self:MakeDraggable(true)`.

4. **At this point**, the frame has:
   - Style methods (from `FlatBarStyleMixin_v2`, applied via XML).
   - Base methods (from `XPBarMixinBase_v2`, added by Setup).
   - Behavior methods (from mixins, added by Setup).

Rationale for ordering:

- **XML-first**: Declarative UI definition; style mixin is directly referenced and controls initialization.
- **Builder pattern in Setup**: Frame accumulates mixins in-place; no separate configured object to manage.
- **Style has first opportunity to define methods**: Since the style is applied via XML before Setup runs, style methods are present first. Setup adds base and behaviors, which can provide defaults or be overridden by the style if the style defined those methods upfront.


## 4. Event registration and Update workflow

Event registration rules (strict):

- The base registers only the minimal XP-related events (no other events):
  - `PLAYER_ENTERING_WORLD` — to trigger initial state sync
  - `PLAYER_XP_UPDATE` — current XP updates
  - `PLAYER_LEVEL_UP` — triggers recalculation of max XP and state
  - `UPDATE_EXHAUSTION` — update rested overlay/info

- The base installs an `OnEvent` dispatcher which maps these events to the following generic methods on the bar:
  - `UpdateCurrentXP()` — default: read `GetXP()` and `UnitXPMax("player")`, call `SetMax`/`SetValue`, then `UpdateVisuals()`.
  - `UpdateMaxXP()` — default: read and set max; trigger `UpdateVisuals()`.
  - `UpdateRested()` — default: read `GetXPExhaustion()` and set `self.__rested` then `UpdateVisuals()`.
  - `Refresh()` — a general refresh hook called on `PLAYER_ENTERING_WORLD`.

- No other events are registered by default. If a style or mixin needs more events, it must register them explicitly during `BuildVisuals` or `ApplyStyle`.

Compatibility note:

- During migration, both v1 and v2 bars might be active and registering the same events; that's expected for dev/testing but must be handled by the user when verifying parity.


## 5. Persistence: using `XPChronicleDB.barPositions`

- All position persistence for v2 bars will use the existing `XPChronicleDB.barPositions` table, not a new saved-variables table.
- Expectations/requirements for the saved structure:
  - `XPChronicleDB` must exist in the global saved-variables table for the addon (this is the project's top-level DB).
  - `XPChronicleDB.barPositions` will be a table keyed by `config.interaction.positionKey`.
- `DraggableMixin` will read/write `XPChronicleDB.barPositions[positionKey]` and provide `SavePosition`, `RestorePosition`, `ClearSavedPosition`.

Example usage in config:

```lua
config.interaction = {
  draggable = true,
  positionKey = "XPBar_Main_v2",
}
```

Security: `DraggableMixin` will not modify other `XPChronicleDB` keys.


## 6. Feature extraction mapping (existing `XPBarMixinBase` -> new components)

This section enumerates features known to exist in `XPBarMixinBase` and maps them to the new architecture components. The goal is to ensure we capture all behavior so v2 is functionally equivalent.

Likely features in current `XPBarMixinBase` and their v2 targets:

- **Event registration & XP state sync** → `XPBarMixinBase_v2` (Trigger methods, Action methods)

- **Value storage and getters/setters** → `XPBarMixinBase_v2` (SetValue, GetValue, SetMax, GetMax)

- **Context building from events** → `XPBarContextBuilder` (BuildXPChangeContext, BuildLevelUpContext, BuildRestedContext, BuildQuestContext)

- **Session calculations** (XP rate, time to level, session stats) → `XPBarContextBuilder` (CalculateXPPerHour, CalculateTimeToLevel, BuildSessionStats)

- **Visual update methods** (textures, text) → Style mixin (`BuildVisuals`, `UpdateVisuals`, `ApplyStyle`)

- **Overlay updates** (rested, quest, exhaustion tick, flash) → `XPBarMixinBase_v2` overlay action methods (UpdateRestedOverlay, UpdateQuestCompleteOverlay, UpdateQuestIncompleteOverlay, UpdateExhaustionTick, UpdateFlashOverlay)

- **Dragging and saved position** → `PositionMixin` (duplicated PositionStore funcs; uses `XPChronicleDB.barPositions`)

- **Tooltip and mouse interactions** → `TooltipMixin` (tooltip provider, OnEnter, OnLeave) + `InteractionMixin` (OnClick, OnMouseDown, OnMouseUp)

- **Animations and smoothing** → `AnimationMixin` (value smoothing, show/hide transitions, flash effects)

- **Logger and debug hooks** → base may keep calls to existing `Logger.lua` functions (do not change `Logger.lua`)

- **Config/state persistence beyond positions** (if present) → left to future migration; not in scope for initial v2

Visual elements mapping (current → v2):

| Current Element | Default Name (v2) | Component | Notes |
|----------------|------------------|-----------|-------|
| Main XP bar | `StatusBar` | Base overlay action | UpdateCurrentXPBar(context, "StatusBar") — WoW StatusBar widget |
| Rested overlay | `RestedLevel` | Base overlay action | UpdateRestedOverlay(context, "RestedLevel") |
| Complete quest overlay | `QuestOverlayComplete` | Base overlay action | UpdateQuestCompleteOverlay(context, "QuestOverlayComplete") |
| Incomplete quest overlay | `QuestOverlayIncomplete` | Base overlay action | UpdateQuestIncompleteOverlay(context, "QuestOverlayIncomplete") |
| Exhaustion tick marker | `ExhaustionTick` | Base overlay action | UpdateExhaustionTick(context, "ExhaustionTick") |
| Flash overlay | `GainFlash` | Base overlay action | UpdateFlashOverlay(context, "GainFlash") — optional |

Context integration (Session → ContextBuilder):

| Session Method | ContextBuilder Equivalent | Integration Status |
|---------------|--------------------------|-------------------|
| `Session:GetXPPerHour()` | `ContextBuilder.CalculateXPPerHour()` | Duplicated in v2 |
| `Session:GetTimeToLevel()` | `ContextBuilder.CalculateTimeToLevel()` | Duplicated in v2 |
| `Session:GetStats()` | `ContextBuilder.BuildSessionStats()` | Duplicated in v2 |
| `Session:OnXPUpdate()` | `ContextBuilder.BuildXPChangeContext()` | Integrated into context |
| `Session:OnLevelUp()` | `ContextBuilder.BuildLevelUpContext()` | Integrated into context |
| `Session:OnTimePlayed()` | Context `realLevelTime` / `realTotalTime` | Integrated into context |

If there are additional specialized features in the current base (e.g., custom anchored portraits, reputation tracking, alternate XP sources), they map to:

- Specialized behavior mixins or style-specific code (not part of base). The style or a new mixin will register additional events as necessary.


## 7. Migration plan & steps (concrete)

Phase 0 — Planning (this document):

- Create this architecture document before any code changes.

Phase 1 — Implementation (isolated, non-invasive):

- Add `ui/xpbars/ContextBuilder.lua` (global `XPBarContextBuilder`) implementing context building functions with integrated Session calculations.

- Add `ui/xpbars/BaseMixin.lua` (global `XPBarMixinBase_v2`) implementing `Setup`, event wiring, Trigger/Action methods, overlay action methods, and abstract visual method checks.

- Add behavior mixins:

  - `ui/xpbars/mixins/AnimationMixin.lua`

  - `ui/xpbars/mixins/InteractionMixin.lua`

  - `ui/xpbars/mixins/TooltipMixin.lua`

  - `ui/xpbars/mixins/PositionMixin.lua` (writes to `XPChronicleDB.barPositions`)

- Add StyleBuilder:

  - `ui/xpbars/StyleBuilder.lua` (global `XPBarStyleBuilder`) implementing Create() composition method.

- Add a demonstration style:

  - `ui/xpbars/flatbar_v2/FlatBarStyleTemplate.lua` — visual methods and optional overlay action overrides
  - `ui/xpbars/flatbar_v2/FlatBarStyle.lua` — calls StyleBuilder:Create() to register global FlatBarXPBarMixin
  - `ui/xpbars/flatbar_v2/FlatBarTemplate.xml` — XML template with all visual elements (StatusBar, overlays, tick, flash)
  - `ui/xpbars/flatbar_v2/README.md` — style-specific documentation

- Add test harness:
  - `ui/xpbars/tests/test_v2.lua` — dev harness gated behind `XPChronicleConfig.enableDevV2` flag so it doesn't run in production.

- Keep all new files under `ui/xpbars` only.


Phase 2 — Developer testing (in-client QA):

- Enable the test harness to create a v2 bar.

- Verify parity of behaviors: XP changes, level ups, rested display, quest overlays (complete/incomplete), exhaustion tick positioning, dragging & persistence, tooltips, animation, flash effects.

- Verify all visual elements render correctly: StatusBar, ExhaustionLevelFillBar, QuestOverlayComplete, QuestOverlayIncomplete, ExhaustionTick, GainFlash.

- Verify no extraneous events get registered.

- Verify `XPChronicleDB.barPositions` is updated correctly when dragging.

- Verify ContextBuilder produces correct context shapes with all required fields.

- Verify overlay action methods can be overridden by styles (test with circular layout mock).

Phase 3 — Porting styles incrementally:

- Port the simplest style (flat) to v2 first.

- Compare behavior to legacy style and refine.

- Port more complex styles as needed.

Phase 4 — Integration and final migration:

- When v2 is stable and fully ported, consider switching default bar creation to v2 and removing container layer in a follow-up PR.

- Provide migration documentation for add-on users and contributors.

Rollout strategy

- Opt-in by default for v2 via `flatbar_v2` and the test harness. No changes to existing code paths until v2 is validated.

- Use feature-flagged testing in the saved-variables to allow early adopters to opt in.


## 8. Quality gates and verification

- Syntax check: run a luacheck (or WoW-syntax check) pass for the new files locally before committing.
- Load-time verification in a WoW test client: ensure no load-time errors and that `XPBarMixinBase_v2` is globally available.
- Smoke tests (dev harness in `ui/xpbars/tests/test_v2.lua`): create a bar, simulate XP changes, drag and reload UI, verify restored position.
- Manual QA: level up, gain XP, change rested state and observe visuals.


## 9. Implementation notes & API examples

Example `config` used by style in `OnLoad`:

```lua
local flatV2Config = {
  style = {
    width = 320,
    height = 18,
    barColor = { r = 0.2, g = 0.6, b = 1 },
    backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 0.9 },
  },
  animation = { enabled = true, valueSmoothing = 0.2 },
  interaction = { enabled = true, draggable = true, positionKey = "XPBar_Main_v2", tooltipProvider = function(self) -- Populate tooltip end },
  initialValue = nil, -- nil := read from game state
  initialMax = nil,
}

-- In style mixin OnLoad:
function FlatBarStyleMixin_v2:OnLoad()
    self:Setup(flatV2Config)
end
```

Example XML template:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Frame name="XPBar_Main_v2" parent="UIParent" mixin="FlatBarStyleMixin_v2" virtual="false">
        <Size x="320" y="18"/>
        <Anchors>
            <Anchor point="TOP" relativeTo="UIParent" relativePoint="TOP" x="0" y="-100"/>
        </Anchors>
        <Scripts>
            <OnLoad method="OnLoad"/>
        </Scripts>
    </Frame>
</Ui>
```

API surface exported by a bar instance (after Setup):

`bar:Setup(config)` — builder method that configures the frame (called in OnLoad)

`bar:SetValue(n)`, `bar:GetValue()`

`bar:SetMax(n)`, `bar:GetMax()`

`bar:UpdateCurrentXP()`, `bar:UpdateMaxXP()`, `bar:UpdateRested()`

`bar:MakeDraggable(bool)` — `DraggableMixin`

`bar:PlayAnimation(name)` / `bar:StopAnimation(name)` — `AnimationMixin`

`bar:BuildVisuals()` — style-provided (required)

`bar:UpdateVisuals()` — style-provided (required)

`bar:ApplyStyle(styleConfig)` — style mixin optional


## 10. Edge cases and decisions requiring confirmation

Before implementing, please confirm the following:

1. ✅ **CONFIRMED**: `XPChronicleDB.barPositions` is the correct place to persist positions and the code will assume that `XPChronicleDB` exists (create subtable if missing).

2. ✅ **CONFIRMED**: The exact minimal events list — the plan uses `{ PLAYER_ENTERING_WORLD, PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, UPDATE_EXHAUSTION, PLAYER_UPDATE_RESTING, TIME_PLAYED_MSG }` for common events. Quest events are registered separately when needed.

3. ✅ **CONFIRMED**: Builder pattern — XML templates reference style mixins directly via `mixin="StyleName"`, and the style's `OnLoad` calls `self:Setup(config)` which adds base and behavior mixins to the frame in-place. No separate configured mixin object; frame accumulates all mixins.

4. ✅ **CONFIRMED**: ContextBuilder is standalone utility module (NOT a mixin) that duplicates Session calculation methods independently. Future refactoring will integrate Session to use ContextBuilder.

5. ✅ **CONFIRMED**: Overlay action methods use default overlay names ("StatusBar", "RestedLevel", "QuestOverlayComplete", "QuestOverlayIncomplete", "ExhaustionTick", "GainFlash") but can be overridden by styles to use custom names (e.g., circular layout uses "RestedArc" instead of "RestedLevel").

6. ✅ **CONFIRMED**: All six visual elements must be supported: current XP bar (StatusBar widget), rested overlay, completed quest overlay, incomplete quest overlay, exhaustion tick marker, flash overlay (optional).

7. ✅ **CONFIRMED**: ContextBuilder is fully independent with NO dependencies on existing Session, Database, or other core modules. This minimizes complexity and impact on existing code during v2 development.

8. ✅ **CONFIRMED**: Overlay action methods validate overlay existence and log warnings if missing. Development phase requires meaningful debug information to evaluate failures. Use `Addon.Logger:Warn()` for missing overlays.

9. ✅ **CONFIRMED**: Flash effects are optional. Styles can no-op flash methods (PlayXPGainAnimation, PlayLevelUpAnimation, FlashXPGain, FlashLevelUp) if not supporting animations.


## 11. Next steps after signoff

- Implement files under `ui/xpbars` (ContextBuilder, BaseMixin, StyleBuilder, mixins, flatbar_v2, tests). I will run a local syntax check and add a small dev test harness.

- Iterate on behavior until parity is reached.


---

Document created: `ui/xpbars/ARCHITECTURE_V2.md`

If this matches your expectations, I will proceed to implement the files listed in Phase 1. If anything needs to change (events, persistence name, or the exact mixin ordering), tell me now and I will update this plan before writing code.
