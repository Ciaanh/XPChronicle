# XPBarEnhanced - Architecture & Event Flow

This document describes the current architecture of the XPBarEnhanced addon and provides a detailed, step-by-step event flow (with files and functions) for the main AddOn lifecycle events and visual update flows. The aim is to make it easier to remove duplicate code, simplify the structure, and prepare a safe release.

---

## Summary


---

## High-level components

- Core AddOn manager: `XPBarEnhanced.lua`
  - Registers top-level events and maps them to `eventHandlers`.
  - Handles `ADDON_LOADED`, `PLAYER_LOGIN`, and other core events.
  - Delegates to `Addon.BarManager` (canonical UI manager/controller) and `Addon.Session` etc. Legacy `Addon.XPBar` calls are kept only in `core/XPBarShim.lua` for compatibility.

- XP controller: `ui/xpbar/XPBar.lua` (module `XPBar`)
  - Centralized controller for XP display.
  - Registers an XP event frame (`RegisterXPEvents`) to handle `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION` etc.
  - Provides `BroadcastUpdate(context)` for compatibility; the canonical pub/sub mechanism is `Addon.EventBus` with event names from `core/EventNames.lua` (e.g., `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)` and `Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, id, handler)`).
  - Manages quest event caching (`RegisterQuestEvents`) and periodic updates (via `C_Timer.NewTicker`).
  - Maintains `currentView` compatibility for legacy single-view behavior while broadcasting updates to observers.

- ContextBuilder: `ui/ContextBuilder.lua`
  - Builds immutable context objects for events (`BuildXPChangeContext`, `BuildLevelUpContext`, `MakeImmutable`).
  - Includes dynamic core state, quest XP, session snapshot and DB config (display flags).

- Base mixins & behaviors:
  - `ui/mixins/BaseMixin.lua` (global `XPBarMixinBase`) — provides `Refresh`, `FullUpdate`, `OnLoad`, `OnShow`, `OnHide`, `RegisterCommonEvents`, and the `TriggerBarRefresh(context)` orchestration.
  - `ui/xpbar/XPBarMixinBase.lua` (local `XPBarMixinBase`) — a second base with additional animation state and functions specific to XPBar behavior, including `AnimateXPChange`, animation dispatching, `InitializeState`, and a local `_AnimationDriver` implementation.

- Animation stack:
  - `ui/mixins/animation/AnimationManager.lua` — Single animation manager that provides `AnimateTo()` and on-update mechanics.
  - `ui/mixins/animation/AnimationBase.lua` — Mixin helper that calls `Addon.AnimationManager:AnimateTo` and implements `StartAnimation` and `ApplyAnimationStep`.
  - `XPBarMixinBase.lua` contains a legacy `Addon._AnimationDriver` that also drives per-frame `OnAnimationUpdate` calls.

- Styles & mixins:
  - Styles live under `ui/styles/` with visual templates and style-specific Lua. They are composed using `ui/StyleBuilder.lua` and contain specific rendering/visual logic (Flat, Classic, Vertical, Circular).
  - Each style is implemented as a mixin (e.g., `FlatXPBarMixin`, `ClassicXPBarMixin`, `CircularXPBarMixin`). They inherit from a base mixin and animation/visual mixins.

- Test harness & dev helpers: `ui/test.lua`
  - Bar Manager: `ui/BarManager.lua` — new manager that creates/initializes the selected style frame, handles showing/hiding style frames, and applies `hideBlizzardBar` visibility logic by default. It exposes `SetStyle` and `GetCurrentStyle` and is intended to be the canonical place for style lifecycle management.
  - Provides Slash commands and test frame generation for debugging (create/destroy test frames, simulate flashes, etc.).


## Event Names & EventBus (Canonical)

- `core/EventNames.lua` exposes canonical event names for the addon and is available at `Addon.EventNames`.
- Use `Addon.EventBus` for publish/subscribe event handling and `Addon.EventNames` for string constants. Examples:
  - `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, context)` — broadcast update for XPBar views
  - `Addon.EventBus:Register(Addon.EventNames.CONFIG_UPDATED, id, configHandler)` — subscribe to fine-grained config changes
  - `Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_INVALIDATED, ctx)` — quest cache invalidation

Using `EventNames` avoids duplicate string literals in code and documentation and ensures there's one source of truth for domain events.
---

## Event Registration Map (who registers which events)

-- `XPBarEnhanced.lua` (global event frame, lines ~150..250): **now limited** to lifecycle events such as `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` and `PLAYER_LOGOUT` and maps them to `eventHandlers.*`. Module-specific events (e.g., XP events) are registered by the module that owns them (for example, `XPBar:RegisterXPEvents()` handles `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, and `UPDATE_EXHAUSTION`).

- `XPBar:RegisterXPEvents()` (ui/xpbar/XPBar.lua: ~975..1006): creates `self.xpEventFrame` and registers `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_ENTERING_WORLD` for controller-centric handling (calls `XPBar:HandleXPUpdate`, `XPBar:OnLevelUp`, etc.).

- `XPBar:RegisterQuestEvents()` (ui/xpbar/XPBar.lua): creates `self.questEventFrame` and registers `QUEST_*` events.

- `BaseMixin:RegisterCommonEvents` in `ui/mixins/BaseMixin.lua` (lines around 165..185): registers `PLAYER_ENTERING_WORLD`, `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING`, `TIME_PLAYED_MSG`. (This is a per-frame registration path.)

- `XPBarMixinBase:RegisterCommonEvents` in `ui/xpbar/XPBarMixinBase.lua` (lines around 240..276): registers the same events but explicitly removes `PLAYER_XP_UPDATE` registration (legacy comment shows it was removed), however it still includes `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_ENTERING_WORLD`, `PLAYER_UPDATE_RESTING`, `TIME_PLAYED_MSG`, and quest events through `RegisterQuestEvents()`.

- `ui/stats/Stats.lua` registers `PLAYER_XP_UPDATE` and quest/time played events (for stats updates).

- Many style mixins rely on the base mixins to register events via `RegisterCommonEvents()`, or they explicitly call `self:RegisterEvent()` for certain widget-level events.

**Key conflicts / duplicates**: `PLAYER_XP_UPDATE` is currently handled at least in three places: (1) global AddOn event frame in `XPBarEnhanced.lua`, (2) `XPBar` controller `xpEventFrame` in `XPBar.lua`, and (3) per-frame (some frames via `ui/mixins/BaseMixin.lua`) when `RegisterCommonEvents` executes. This is the main duplication we should eliminate.

---

## Detailed Event Flow (step-by-step)

Below, each event is broken down with the call sequence and the specific files/functions invoked. Where multiple pathways exist (i.e., duplicates), the document explains the flow and the resulting behavior.

### ADDON_LOADED

1. WoW fires `ADDON_LOADED`.
2. `XPBarEnhanced.lua` (global event handler): `eventHandlers.OnAddonLoaded(name)` runs → only runs when `name == "XPBarEnhanced"`
   - Calls `Addon.Database:Initialize()` (if present)
   - Calls `Addon.Config:Initialize()`
   - Sets `Addon.db = XPBarEnhancedDB or {}`
   - Reads `Addon.Database:IsXPGainDisabled()` to set `Addon.state.xpGainDisabled`
   - Prints a localized loaded message via `Addon.Utils.Print()`
3. No more AddOn-level pipeline. Initialization completes.

### PLAYER_LOGIN

1. WoW fires `PLAYER_LOGIN`.
2. `XPBarEnhanced.lua` event handler `OnPlayerLogin` executes:
   - `Addon.Session:Initialize()`
  - `Addon.BarManager:Initialize()` ---> See `BarManager:Initialize()` below
   - `Addon.Stats:Initialize()`
   - `Addon.Options:Initialize()`

3. UI component initialization chain:
   - `XPBar:Initialize()` (ui/xpbar/XPBar.lua: ~900..999)
     - Calls `RegisterXPEvents()` to create `xpEventFrame` (frame: registers `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION` and `PLAYER_ENTERING_WORLD`)
     - Calls `StartPeriodicUpdates()` (interval text updates for XP rate / session text)
     - Calls `RegisterQuestEvents()` to create `questEventFrame` and register `QUEST_*` events
     - Loads saved `Addon.db.barStyle` and calls `SetBarStyle(style, true)` to show the correct style container
    - Calls `Update()` (which calls `currentView.FullUpdate()` and emits via `EventBus` using `Addon.EventNames.XPBAR_BROADCAST_UPDATE` for broadcast updates)

   - Each style container's `OnLoad()` runs during XML/Factory creation (if created by the template or by style builder):
     - `FlatXPBarContainerMixin:OnLoad` – container init + `FlatXPBarMixin:OnLoad()` calls `self:InitializeState()` and `self:RegisterCommonEvents()` (or `XPBarMixinBase:RegisterCommonEvents`).
     - `Classic`/`Vertical`/`Circular` similar.

4. Net effect: At `PLAYER_LOGIN`, the AddOn initializes containers, registers controllers and per-frame events, and triggers a first update for displayed bars.

### PLAYER_ENTERING_WORLD

**Two pathways**:

A) Global AddOn pathway (`XPBarEnhanced.lua`):
  - `eventHandlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)` → `Addon.Session:OnEnteringWorld()`, `Addon.BarManager:OnEnteringWorld(...)` or `Addon.EventBus` emit (the controller's `OnEnteringWorld` used to be in the legacy XPBar) which invalidates quest cache and triggers updates as necessary.

B) `XPBar` XP event frame pathway (`XPBar:RegisterXPEvents`):
   - `xpEventFrame.OnEvent` sees `PLAYER_ENTERING_WORLD` → sets `Addon._lastKnownXP` and `Addon._lastKnownLevel` to `UnitXP('player')` and `UnitLevel('player')` so the immediate next XP gain animation has a proper `xpBefore` snapshot.

Per-view/pathway: base mixins' OnEvent may pick up `PLAYER_ENTERING_WORLD` and perform `FullUpdate()` only if they are the active view.

### PLAYER_XP_UPDATE (Main focus)

This event is **registered/handled** in multiple locations. Sequence summary:

1. Blizzard triggers `PLAYER_XP_UPDATE`.

2. Global AddOn event frame (`XPBarEnhanced.lua`) `eventHandlers.OnPlayerXPUpdate()` runs:
  - `Addon.Session:OnXPUpdate()` (Update session; persistent tracking)
  - The controller's `OnXPUpdate` (now handled by `Addon.BarManager`/XPBarController) calls `Update()` and then broadcasts via `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)` for views to update:
    - If `XPBar.currentView` exists, call `currentView:FullUpdate()` (classic single-view compatibility path)
    - `XPBar:BroadcastUpdate()` builds context via `XPBarContextBuilder.BuildXPChangeContext("BROADCAST_UPDATE")` and emits it via `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, context)` so subscribers can `FullUpdate(context)`.

3. Controller XP event frame (`XPBar.xpEventFrame`) `OnEvent` — defined in `XPBar:RegisterXPEvents()` — sees `PLAYER_XP_UPDATE` and calls `XPBar:HandleXPUpdate()` (central animation path):
   - `XPBar:HandleXPUpdate()` builds a per-gain immutable context using `Addon._lastKnownXP`, `UnitXP('player')`, `UnitXPMax`, `GetXPExhaustion`, and `UnitLevel`; then sets a `context` object with fields: `xpBefore`, `xpAfter`, `xpMax`, `xpGained`, `isLevelUp`, `isRested`, `isFullyRested`, etc.
   - `XPBar:HandleXPUpdate()` dispatches to `activeView.AnimateXPChange(context)` when `activeView` implements `AnimateXPChange`. This triggers `XPBarMixinBase:AnimateXPChange(context)` which prepares `self.animation.context` (aggregates or retargets if another animation is active) and eventually calls `AnimateToRatio(target, context)`. `AnimateToRatio` uses either the legacy driver (`Addon._AnimationDriver`) or the unified `Addon.AnimationManager` depending on the implementation. `AnimateToRatio` sets up the animation in the manager for per-frame updates.

4. Per-frame mixins: If `RegisterCommonEvents()` from `ui/mixins/BaseMixin.lua` is used by a view, that registration will pick up `PLAYER_XP_UPDATE` and call `BaseMixin:OnEvent` for that view. `OnEvent` will call the `XPBarContextBuilder.BuildXPChangeContext(event)` and pass context to `TriggerBarRefresh(context)` which either does animation via `StartAnimation()` or immediate `RenderBar()`.

5. Stats frame: `ui/stats/Stats.lua` `OnEvent` listens for `PLAYER_XP_UPDATE` to update stats displays.

6. Test frames and any external consumers may register for `PLAYER_XP_UPDATE` and react accordingly.

Key side effects:
- `XPBar:HandleXPUpdate()` and `XPBar:OnXPUpdate()` both run on the same underlying `PLAYER_XP_UPDATE` event; this creates duplicate update paths (controller animation vs broadcast/full updates).
- Per-frame `PLAYER_XP_UPDATE` registration (in `ui/mixins/BaseMixin.lua`) can cause extra processing (which should be consolidated).
- The context built via `XPBarContextBuilder.BuildXPChangeContext` is used by the broadcast/updater functions and by per-frame handlers.
- `Addon._lastKnownXP` and `ContextBuilder._lastXP` track snapshots for gain calculations. Be careful about race conditions when multiple handlers change or rely on these snapshots.

### PLAYER_LEVEL_UP

1. Blizzard fires `PLAYER_LEVEL_UP` with new level argument.

2. Addon event frame (`XPBarEnhanced.lua`) `eventHandlers.OnPlayerLevelUp(level)` is called:
   - `Addon.Session:OnLevelUp(level)`
  - `Addon.BarManager`/`XPBarController` `OnLevelUp(level)` → invalidates quest cache and triggers `self:Update()` (same as `OnXPUpdate` update-path).

3. Controller `xpEventFrame` sees `PLAYER_LEVEL_UP` and triggers `XPBar:OnLevelUp(level)` as well.

4. Per-view `XPBarMixinBase:HandleEvent` sees `PLAYER_LEVEL_UP` and calls `self:OnLevelUp(level)` which stops animations and performs level-up celebration or a `FullUpdate()`.

**Note**: Both controller and per-view handlers run; keep only one authoritative path where possible.

### UPDATE_EXHAUSTION & PLAYER_UPDATE_RESTING

1. Both central `xpEventFrame` and per-view `RegisterCommonEvents()` register `UPDATE_EXHAUSTION` and `PLAYER_UPDATE_RESTING`.

2. On this event, `XPBar.RegisterXPEvents` `xpEventFrame` will call `if self.currentView and self.currentView.FullUpdate then self.currentView:FullUpdate() end` or similar.

3. Per-view `HandleEvent` will call `self:UpdateBarDisplay()` and `self:UpdateQuestSummaryText()` so that rested overlays and UI are updated.

Recommendation: Keep per-view `UpdateBarDisplay()` and `UpdateQuestSummaryText()` as is; only register one path for the event, probably the per-view path since rested UX is view-specific.

### QUEST events (QUEST_ACCEPTED, QUEST_REMOVED, QUEST_TURNED_IN, QUEST_LOG_UPDATE, UNIT_QUEST_LOG_CHANGED, QUEST_WATCH_UPDATE)

Paths:
- XPBar controller registers a dedicated `questEventFrame` that calls `XPBar:OnQuestEvent(event, ...)` which invalidates quest cache and schedules `XPBar:Update()` (broadcast to views) after 0.5s.
- Per-view BaseMixin or XPBarMixinBase registers listener for quest events (via `RegisterQuestEvents`) and calls `HandleEvent` which calls `self:UpdateBarDisplay()` or triggers a `FullUpdate()`.

Recommendation: Use controller-only quest event handling for global updates and leave view-local overlays (colors, visuals) only to the view's `UpdateRestedOverlay` and `UpdateQuestCompleteOverlay` when `FullUpdate` or `Refresh` occurs.

### TIME_PLAYED_MSG

- Registered in `UI/mixins/BaseMixin.lua` and `ui/xpbar/XPBarMixinBase.lua` to update session time. Also tracked in `Addon.Session` for time tracking.

---

## Frame lifecycle & style creation

- Styles are registered via `ui/StyleBuilder.lua`. The `CreateFrameForStyle` function will create the UI frame using an XML template or by a provided factory and then will call `frame:OnLoad()` if present.
- During `OnLoad()` of each style container:
  - It hides the container until `XPBar` controller calls `SetBarStyle` to show it.
  - Mixins call `InitializeState()` or `InitializeAnimation` and `RegisterCommonEvents()`.
  - `BaseMixin.OnLoad()` subscribes to the `EventBus` with `Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, observerId, handler)`. Legacy `Addon.XPBar:RegisterObserver` calls are deprecated — the `core/XPBarShim.lua` continues to provide a compatibility surface that proxies to `EventBus` and `BarManager`.
  - Styles call `FullUpdate` or `Refresh()` to initialize visuals.
- `OnShow()` and `OnHide()` manage timers, event registration, and `UnsubscribeFromEvents` or `CleanupTimers`.

## Animation flows

- `XPBar:HandleXPUpdate()` (controller) builds an immutable `context` and calls `activeView.AnimateXPChange(context)`.
- `XPBarMixinBase:AnimateXPChange(context)` updates the view's `animation.context` and calls `AnimateToRatio(targetRatio, context)` (calls `self:AnimateToRatio(...)`).
- `AnimationBase:StartAnimation(...)` delegates to `Addon.AnimationManager:AnimateTo(bar, targetRatio, xpContext, config)` which sets up `anim.isAnimating`, `anim.startTime`, `duration`, and registers the frame with the manager.
- `Addon.AnimationManager` sets an `OnUpdate` ticker and calls `AnimationBase:ApplyAnimationStep(iterationData, eventContext)` per frame which calls style-specific `AnimateBarPosition` and `AnimateBarEffect` for visuals.
- `XPBarMixinBase` contains a legacy `Addon._AnimationDriver` that registers bars and calls `XPBarMixinBase.OnAnimationUpdate(b, elapsed)` which is a legacy per-bar driver and may still be used in the codebase in some places.

**Conflict**: `Addon.AnimationManager` (the preferred manager) and `Addon._AnimationDriver` (legacy) both aim to drive animations. Consolidate to `Addon.AnimationManager` to avoid duplication.

---

## Duplication hotspots and recommended cleanup steps

1. Duplicate `PLAYER_XP_UPDATE` handling
  - Remove `PLAYER_XP_UPDATE` from the global per-view registration (i.e., ensure `ui/mixins/BaseMixin:RegisterCommonEvents()` does not register it). Use the controller `XPBar:RegisterXPEvents()` + central `XPBar:HandleXPUpdate()` + `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, context)` for broadcast updates, or prefer per-style `PLAYER_XP_UPDATE` with `EventBus` to publish the update.
   - Keep `Addon.eventFrame` top-level mapping if it is needed for session-level operations, but ensure `XPBar:OnXPUpdate()` doesn't trigger the same animation path (or remove `XPBar:OnXPUpdate()` and handle Update only via handle xp event; or make `OnXPUpdate()` simply call `BroadcastUpdate` and `HandleXPUpdate()` once). Prefer `XPBar:HandleXPUpdate()` as the single path for building immutable animation contexts and playing animations; use `BroadcastUpdate` for non-animated broadcast updates (full updates).

2. Base mixin duplication (`ui/mixins/BaseMixin.lua` vs `ui/xpbar/XPBarMixinBase.lua`)
   - Decide on one `XPBarMixinBase` implementation (prefer the `ui/xpbar/XPBarMixinBase.lua` for XP-specific features and animation) and remove the other or rename it to avoid collision.
   - Update `StyleBuilder` to use only one canonical base mixin in `StyleBuilder:Create(...)`.

3. Animation managers
   - Consolidate to `Addon.AnimationManager` (existing `AnimationManager` in `ui/mixins/animation/AnimationManager.lua`) and remove `Addon._AnimationDriver` legacy implementation in `ui/xpbar/XPBarMixinBase.lua`.
   - Update `XPBarMixinBase` to call `Addon.AnimationManager` via `AnimationBase:StartAnimation`.

4. Broadcast & `Update()` distinction
   - Keep `XPBar:HandleXPUpdate()` for animation-specific path and `XPBar:BroadcastUpdate(context)` for broadcast updates resulting from config changes, `FullUpdate` and `SetBarStyle`. Avoid calling both as a result of a single event.

5. Tests & dev-only code
   - Remove/test harness and dev-only functions inside `ui/test.lua` or gate them behind `Addon.db.devMode` so they are excluded from release.

6. `currentView` legacy path
   - Remove `XPBar.currentView` if the new observer pattern is canonical; keep a short compatibility shim to migrate saved settings into new style registration.

7. Global namespace pollution
   - Remove `_G.*` references used solely for dev/testing or compatibility where possible.

---

## Suggested refactor sequence for a safe release

Step 1: Remove per-view `PLAYER_XP_UPDATE` registration
- Edit `ui/mixins/BaseMixin.lua` `RegisterCommonEvents` to exclude `PLAYER_XP_UPDATE` and ensure all style mixins use `XPBar:HandleXPUpdate` and `BroadcastUpdate`.

Step 2: Consolidate base mixin
- Choose one `XPBarMixinBase` file (prefer `ui/xpbar/XPBarMixinBase.lua`) to keep. Remove or rename `ui/mixins/BaseMixin.lua` to avoid duplicated definitions and confusion.
- Update style mixins and `StyleBuilder` to reference the chosen base mixin.

Step 3: Consolidate animation driver
- Remove `Addon._AnimationDriver` (legacy) from `ui/xpbar/XPBarMixinBase.lua` and update animation calls to go through `Addon.AnimationManager`.

Step 4: Replace `currentView` as the default view
- Ensure `XPBar:Update()` uses `BroadcastUpdate()` and does not rely on the `currentView` single-view path.
- Provide a migration path to map `Addon.db.barStyle` to the registered style observer(s).

Step 5: Remove `ui/test.lua` (or gate behind a `devMode` setting)
- Remove from `XPBarEnhanced.toc` or guard its initialization via `Addon.db.devMode`.

Step 6: Re-run test harness (manual) and verify the following:
- Standard event flows for XP gain (`PLAYER_XP_UPDATE`) produce one consistent animation and one full update.
- `SetBarStyle` still controls which style containers are shown.
- Quest overlays and resting state are updated exactly once per relevant event.

---

## Migration and compatibility suggestions

- Add `Addon.db.legacyMode = true/false` (default `false`). When `true`, the AddOn keeps the legacy single-view behavior and per-view `PLAYER_XP_UPDATE` registration for one release cycle to prevent breaking user setups. When `false`, prefer the observer/broadcast/centralized animation manager.
- Provide an upgrade path to migrate saved `Addon.db.barStyle` and `Addon.db.barPosition` saved variables to the new system if the container naming changes.
- Keep the `XPBarTextFormatter` compatibility table for a release so third-party code relying on it won't break.

---

## Appendix: Quick reference (files & key functions)

-- `XPBarEnhanced.lua` — top-level event mapping / `eventHandlers` now call `Addon.BarManager` and/or publish to `Addon.EventBus` rather than directly calling `Addon.XPBar.*`.
  - `eventHandlers:OnAddonLoaded()`
  - `eventHandlers:OnPlayerLogin()` -> `Addon.BarManager:Initialize()`
  - `eventHandlers:OnPlayerXPUpdate()` -> `Addon.BarManager` or `Addon.EventBus` handlers — `OnXPUpdate()` is handled by `BarManager`/controller and the update is broadcast with `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, context)`.

- `ui/xpbar/XPBar.lua` — main controller
  - `XPBar:RegisterXPEvents()` - creates `xpEventFrame`: listens for `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_ENTERING_WORLD` and runs `HandleXPUpdate` and related handlers
  - `XPBar:HandleXPUpdate()` - central animation path (builds immutable `context` and calls `activeView.Animator...`)
  - `XPBar:BroadcastUpdate(context)` - builds context and emits it via `Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, context)` so subscribers receive the context and `FullUpdate(context)` call can be made.
  - `Addon.EventBus` is the preferred mechanism for subscribing/publishing updates (`Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, id, handler)` / `Addon.EventBus:Unregister(Addon.EventNames.XPBAR_BROADCAST_UPDATE, id)`).
  - `XPBar:RegisterQuestEvents()` - quest events and scheduled updates (0.5s delay)

- `ui/ContextBuilder.lua` — context builder
  - `BuildXPChangeContext`, `BuildLevelUpContext`, `MakeImmutable` (creates immutable contexts)

- `ui/mixins/BaseMixin.lua` — global base mixin (REGISTER COMMON EVENTS here if intended to be used)
  - `RegisterCommonEvents()` registers `PLAYER_XP_UPDATE` and other events (duplicate with XPBar controller)
  - `OnEvent(event, ...)` builds context and calls `TriggerBarRefresh(context)`
  - `TriggerBarRefresh(context)` orchestrates immediate vs animated render, requiring `RenderBar` or `StartAnimation`.

- `ui/xpbar/XPBarMixinBase.lua` — second specialized base mixin
  - `RegisterCommonEvents()` does not register `PLAYER_XP_UPDATE` (LEGACY comment)
  - `HandleEvent` updates UI state and now defers to either `Addon.BarManager`'s centralized handler or observes `Addon.EventBus` broadcasts to react to `PLAYER_XP_UPDATE`. Legacy calls to `Addon.XPBar` are no longer used by internal code.
  - `AnimateXPChange(context)` for the central animated path
  - Contains a legacy `_AnimationDriver` implementation (see `InitializeAnimationState()`)

- `ui/mixins/animation/AnimationManager.lua` & `AnimationBase.lua`
  - `AnimationBase:StartAnimation` delegates to `Addon.AnimationManager:AnimateTo` for `StartAnimation`.
  - `AnimationManager` handles `OnUpdate` ticks and calls `ApplyAnimationStep` for each bar.

- `ui/test.lua` — test harness and `Addon.Tests *` functions; should be gated/removed for release.

---

If you'd like, I can:
- Draft and prepare PRs for each of the recommended steps (e.g., removing `PLAYER_XP_UPDATE` from `ui/mixins/BaseMixin.lua`, consolidating to `XPBarMixinBase` + rewire `StyleBuilder`), or
- Produce a smaller focused PR: "Remove per-view PLAYER_XP_UPDATE registration and make XPBar controller the single xpUpdate source" and a short test plan to validate the change.

Let me know which PR(s) you want first and I will prepare the patches.

---

Document generated by GitHub Copilot (Raptor mini preview) — last scanned: workspace 2025-11-20

