# Migration Plan: Move to `ui/styles` Bar System, Session Service & Per-Style Event Handling

This document outlines a structured, staged migration plan to change the architecture of XPBarEnhanced to use the new `ui/styles` bar system as canonical, a dedicated `Session` service that registers events only for session data (exposing values through immutable contexts), and per-style event handling implemented with `BaseMixin.lua`.

- Goals

- Consolidate the canonical bar implementation to `ui/styles` and archive `ui/xpbar/styles`.
- Keep global initialization events in `XPBarEnhanced.lua` (ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD).
- Implement a dedicated `Session` service which registers necessary events to compute session state (e.g. xp gained in session, session start time) and expose those values only via the immutable context builder.
- Ensure that player action events that directly affect visuals/animations (XP gain, quest actions, rested changes, level up, etc.) are handled by the new per-style handlers (mixins composed by `ui/StyleBuilder.lua` and `BaseMixin.lua`), not by old central controller code.
- Reduce `ui/xpbar/XPBar.lua` to a compatibility/utility module (no active xp event registration or per-event logic), and ensure `ui/xpbar` bars are archived (kept but not used by default).
- Provide a safe migration plan: staged changes, automated tests, QA checks, deprecation shims, and a rollback path.

- Scope & Impacts

- Files & modules in scope:
  - Core: `XPBarEnhanced.lua` (global init & events)
  - Session service: (use file under `core/Session.lua`)
  - Context builder: `ui/ContextBuilder.lua` (to ingest session data via API)
  - New canonical styles: `ui/styles/*` (Flat, Classic, Circular, Vertical, etc.)
  - Legacy styles to archive: `ui/xpbar/*` under `ui/xpbar/styles` (FlatXPBarMixin, ClassicXPBarMixin, etc.)
  - Legacy controller: `ui/xpbar/XPBar.lua` (cleaned) and `ui/xpbar/XPBarMixinBase.lua` (may be migrated or archived)
  - Base mixins: `ui/mixins/BaseMixin.lua` (per-style event registration and orchestration)
  - Animation stack: `ui/mixins/animation/*` (AnimationManager, AnimationBase)
  - Tests & dev-only: `ui/test.lua` and Slash commands for tests (should be gated or removed)

- Key constraints & rules

- Do not rewrite or change existing behavior without a tested deprecation path.
- The session service registers events necessary for computation; it stores session-level data and exposes it only through ContextBuilder. No direct view-readable global session variables.
- Global initialization events remain in `XPBarEnhanced.lua`.
- `XPBar.lua` remains but is no longer responsible for XP-driven event routing; keep only functions needed for style management and compatibility.
- `ui/styles` are canonical — they must register their own events and handle animations. `ui/xpbar` styles will be archived.

- High-level migration phases

- Phase 0 — Preparation & Tests (create dev flags, tests)
- Phase 1 — Implement Session Service and Immutable Session Integration
- Phase 2 — Per-Style Event Handling Implementation & BaseMixin normalization
- Phase 3 — Move visual logic to `ui/styles` (if needed) & archive `ui/xpbar` styles
- Phase 4 — Review/clean `ui/xpbar/XPBar.lua` (legacy) and confirm the new flows
- Phase 5 — Release-prep: docs, deprecations, QA, removal from `.toc` or gating of test harness

Detailed Steps & Actions

- Phase 0 — Preparation & Tests

- 0.1 Create a `devMode` flag in `Addon.db` with default `false`, used to gate dev/test harness and verbose logs. Update `XPBarEnhanced.toc` or relevant files to only include `ui/test.lua` when `devMode` is true.
- 0.2 Add a set of automated/command test utilities (in `ui/test.lua` or a separate `tests/` folder) to simulate the following events and to test the event flow: `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD`, quest events, `TIME_PLAYED_MSG`.
- 0.3 Add instrumentation/DEBUG logging (via `Addon.Logger` but only under `devMode`) to trace flow and ensure events are only delivered via single, intended handler.
- 0.4 Create a CI job or local test steps to run the manual test harness with those simulated events, capturing the results.

- Phase 1 — Dedicated Session Service & Context Exposure

- 1.1 Create a new `core/Session.lua` or reuse the existing one, clearly document its responsibilities:
  - Track session start time, xp gained since session start, last TIME_PLAYED_MSG, and last XP snapshot (to compute deltas if needed).
  - Register events necessary for session tracking: `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `PLAYER_XP_UPDATE`, `TIME_PLAYED_MSG` (and optionally `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP` for per-level handling).
  - Keep internal state only accessible via internal API (e.g., `Session:GetCurrent()` or `Session:GetSnapshot()`), but do not let views directly consume state — instead, ContextBuilder should use `Session:GetSnapshot()` to include data in the context used for `TriggerBarRefresh` or per-style rendering.
- 1.2 Implementation considerations:
  - Avoid direct references to `_G` in session store; keep the state within `Addon.Session` namespace.
  - Use a safe persistence approach: read/save session info in `Addon.db` to maintain continuity across reloads (optional: session start time should be per-launch only, but the service can save `gainedXP` in the DB to restore in case of reloads).
  - Optimize event rates: session service can `pcall` guarded and ensure it doesn't cause double handling or heavy updates in the UI code.
- 1.3 Tests for session:
  - Simulate `PLAYER_LOGIN`, then simulate `PLAYER_XP_UPDATE` events and verify `Session` accumulates the XP gained in session.
  - Simulate `TIME_PLAYED_MSG` and ensure `Session` updates session time and `Session:GetSnapshot()` returns correct session values.
  - Test property exposure: pull session snapshot only via ContextBuilder and ensure views cannot call `Session` directly unless they are in tests.

- Phase 2 — Migrate Event Registration to Per-Style Handling

- 2.1 Eliminate duplicate global `PLAYER_XP_UPDATE` handling from `XPBarEnhanced.lua` and `XPBar.RegisterXPEvents` — but wait for step-by-step testing. Plan to transfer per-style `PLAYER_XP_UPDATE` handling to `BaseMixin.lua` (per-style) or ensure `BaseMixin` registers view-specific events including `PLAYER_XP_UPDATE`.
- 2.2 Normalize `BaseMixin.lua` to be the canonical per-style event registration and orchestration mixin:
  - `BaseMixin:RegisterCommonEvents()` should include player action events that are *view-level* relevant: `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING`, `TIME_PLAYED_MSG`, quest events (QUEST_ACCEPTED, etc.).
  - It should *also* optionally register `PLAYER_XP_UPDATE` where necessary for that style. If the new design intends that XP updates are handled directly by style mixins, `BaseMixin.RegisterCommonEvents()` should register `PLAYER_XP_UPDATE`.
  - Add an optional per-style setting `__xpbar_config`->`eventModel` defaulting to `perStyle`, or `controller` for hybrid behavior (compatibility mode). This allows for controlled migration and a toggle for legacy behavior if needed.
- 2.3 Update `StyleBuilder` to prefer the canonical `BaseMixin` and to avoid mixing in older, `XPBarMixinBase` types.
- 2.4 Add a `BaseMixin` hook `OnEvent(event, ...)` that organizes the flow at the view level:
  - Build the immutable context via `ContextBuilder`, which composes: core dynamic data, session snapshot from `Session`, quest state, and static DB flags.
  - The `context` is then passed to `TriggerBarRefresh(context)`, which decides on animation vs. immediate render.
- 2.5 Testing:
  - For each view (Flat, Classic, Circular, Vertical): register them and verify `PLAYER_XP_UPDATE` triggers `OnEvent` on that view only once, and animation triggers the expected `AnimateToRatio` and `AnimationManager` flows.
  - Ensure that `ContextBuilder` pulls the session data from `Session` and includes it in the context. Validate that Session's totals match simulated XP gains captured.

- Phase 3 — Move to canonical `ui/styles` system & archive `ui/xpbar/styles`

- 3.1 Confirm all existing behaviors and UI of `ui/xpbar/styles` are replicated or no longer needed. Identify differences:
  - Look for special logic unique to `ui/xpbar` styles that is missing in `ui/styles`; plan to port the minimal functionality into `ui/styles` while preserving the code's visual look.
- 3.2 Implement any missing features in `ui/styles` mixin templates (e.g., layouts, overlays, animations) for parity.
- 3.3 Update `StyleBuilder` registries to recognize canonical `ui/styles` mixins and remove `ui/xpbar/styles` from builder usage.
- 3.4 Archive `ui/xpbar/styles` by moving them to `archived/` or marking them as deprecated and remove them from the `.toc` so they're not loaded into WoW. Keep them in the repository but not part of release (this allows fallback for small issues).
- 3.5 If legacy code relies on `XPBar.lua` being able to manage the `currentView` or set bar style, ensure a compatibility layer exists in `XPBar.lua` to map saved `Addon.db` states: e.g., when migrating, SetBarStyle still accepts `classic`, and maps to showing the new `ui/styles` view.

- Phase 4 — Clean `ui/xpbar/XPBar.lua` (legacy controller)

- 4.1 Remove legacy XP event registration and `HandleXPUpdate` animation dispatch. The new pattern uses per-style event registration and the `Session` service for session data, so `XPBar:RegisterXPEvents()` should stop creating the xpEventFrame for `PLAYER_XP_UPDATE`.
- 4.2 Keep these functions in `XPBar.lua` (if still needed):
  - `SetBarStyle()` — to support `Addon.db.barStyle` for compatibility and for toggling container visibility if desired.
  - `RegisterObserver()`/`UnregisterObserver()` and `BroadcastUpdate(context)` — for global option/colour updates are still useful to inform all scenes to update on config change.
  - `RegisterQuestEvents()` — optionally remain to provide quest caching & `Update()` across views, or shift quest events to per-style (both approaches are possible; prefer per-style for visuals and central for invalidating caches).
- 4.3 Remove/Archive all references to `XPBar.HandleXPUpdate()` and `xpEventFrame` in `XPBar.lua`. If the code references them in many places, leave compatibility wrappers that call new per-style methods.
- 4.4 Add textual warnings to `XPBar.lua` that this is legacy code and should not be altered but may be cleaned further once migration completes.

- Phase 5 — QA & Release

- 5.1 Validation & regression tests: Verify animations, overlays, and rest tick behaviors across all styles.
- 5.2 Manual checks:
  - Use the debug commands in `ui/test.lua` (gated by `devMode`) to create test bars for each `ui/styles` bar and trigger `PLAYER_XP_UPDATE` and `Flash` tests.
  - Ensure session data in contexts is accurate and matches expected numbers after simulated gains.
- 5.3 Integrations: check `Addon.Stats` and `Addon.Config` for any reliance on `XPBar` central `HandleXPUpdate`; if so, change them to listen for `ContextBuilder` or subscribe to `Addon.Session` (or better: to the `BroadcastUpdate` that will be used when appropriate).
- 5.4 Prepare migration release notes and deprecation messages (for add-on users & other developers) and note that `ui/xpbar` style mixins are archived.

- Phase 6 — Rollback & Compatibility

- 6.1 Keep `devMode` toggles or `Addon.db.legacyMode` for 1-2 minor releases to enable a safe rollback path.
- 6.2 The compatibility shim should detect older saved variables that require `ui/xpbar` to remain enabled and when `legacyMode` is set do the mapping and keep `ui/xpbar/XPBar.lua` logic running.
- 6.3 Keep `XPBarEnhanced.toc` pointing to legacy files only in `legacyMode` or remove files from `.toc` otherwise.

Detailed File/Function Actions (developer notes)

- `XPBarEnhanced.lua` - keep global initialization and event mapping.
  - Keep `ADDON_LOADED`, `PLAYER_LOGIN`, and `PLAYER_ENTERING_WORLD` handlers.
  - Ensure `OnPlayerLogin` still delegates to `Addon.XPBar:Initialize()` and `Addon.Session:Initialize()` but no longer triggers xp updates manually; it should only set initial states and ensure new styles are loaded.

- `core/Session.lua` (new or modified existing Session)
  - Responsibilities: register events for session management and keep snapshot values persistently if useful.
  - Expose `GetSnapshot()` API used only by `ContextBuilder`.
  - Events to register: `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `PLAYER_XP_UPDATE` (for delta), `TIME_PLAYED_MSG` (session time), and `PLAYER_LEVEL_UP` (optional for session resets on level).

- `ui/ContextBuilder.lua`:
  - Use `Addon.Session:GetSnapshot()` for session fields (session xp, gained XP, sessionStart, sessionDuration) in `BuildCoreContext` or `BuildXPChangeContext`.
  - Do **not** read `Addon.Session` values directly from views.

- `ui/mixins/BaseMixin.lua`:
  - `RegisterCommonEvents` should be the single place for view event registration; allow `PLAYER_XP_UPDATE` to be included or excluded depending on the style config.
  - `OnEvent` should build the immutable context and call `TriggerBarRefresh(context)`, not mutate any session data.

- `ui/styles/*` (Flat, Classic, Circular, Vertical, etc.)
  - Must implement `OnLoad` using `BaseMixin:OnLoad()` and register necessary events.
  - Implement `AnimateBarPosition` + `AnimateBarEffect` to integrate with `Addon.AnimationManager`.
  - Support `self.__xpbar_config` to control per-style event registration or `shouldAnimate` overrides.

- `ui/xpbar/styles` (FlatXPBarMixin.lua, ClassicXPBarMixin.lua, etc.)
  - Create a TODO for migrating any missing behavior to `ui/styles`.
  - Move unique logic to `ui/styles` version or note differences.
  - Archive these files (move to `archived/` or `deprecated/` folder) before removing from `.toc` and default runtime.

- `ui/xpbar/XPBar.lua`:
  - Remove `RegisterXPEvents` `xpEventFrame` for `PLAYER_XP_UPDATE`.
  - Keep `RegisterQuestEvents()` and `InvalidateQuestCache()` only if they are used to maintain a global cache to avoid repeating expensive `GetQuestLog` calls. Alternative: `Session` or `ContextBuilder` can reuse these caches; keep only tight pieces.
  - Provide small compatibility functions used by external code; mark them deprecated.

- `ui/mixins/animation/*` (AnimationManager & AnimationBase):
  - Keep these as single animation engine used by all styles.
  - Ensure `AnimateTo` and `ApplyAnimationStep` are robust and handle retargeting.

- `ui/test.lua` and test harness: Gate behind `devMode` and remove from `.toc` by default.

QA & Test Plan (Manual & Automated)

- Test Cases

- TC 1: Initial startup and saved variables
  - Load the addon and verify `Addon.Session` initialization, `Addon.Config` loaded, default `barStyle` mapping to `ui/styles`
  - Confirm no duplicate `PLAYER_XP_UPDATE` handling or double animation emissions
- TC 2: XP Gain Animation
  - Simulate `PLAYER_XP_UPDATE` event; confirm `OnEvent` in the view receives one event and `AnimateTo` is called once; confirm AnimationManager drives the animation correctly to the expected targetRatio.
- TC 3: Quest change updates
  - Simulate `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED` and ensure views update overlays and states once per event.
- TC 4: Session service behavior
  - Confirm session service registers events and computes `sessionXP`, `sessionStart`, and `time` and `ContextBuilder` includes them in contexts.
- TC 5: Level up & Rested changes
  - Simulate `PLAYER_LEVEL_UP` and `UPDATE_EXHAUSTION`/`PLAYER_UPDATE_RESTING`; confirm the `OnLevelUp` and rested updates occur and UI changes correctly.
- TC 6: `ui/styles` parity vs `ui/xpbar` styles
  - Confirm visual parity by comparing the default look & behavior. Keep `ui/xpbar` archived for fallback during release.

Automated Regression Tests (where possible)

- Run event-driven tests that simulate the above events and assert the number of calls to `OnEvent`, `AnimateTo`, and `FullUpdate` via internal counters or instrumentation (in dev mode).

- Fallback, Rollback & Release Plan

- Keep `Addon.db.legacyMode` flag to revert to older behavior (central XPBar + xpEventFrame) for at least 2 minor releases.
- Keep `ui/xpbar` styles in `archived/` and optionally load them only if `legacyMode == true`.
- Gradually remove `XPBar:RegisterXPEvents` and `XPBar.HandleXPUpdate` after 2 releases if no issues are observed.

- Migration Checklist

- [ ] Implement `Session` service and expose `Session:GetSnapshot()` API; update `ContextBuilder` to include session fields.
- [ ] Update `UI` `BaseMixin` to be canonical event registration entry point for per-style events;
- [ ] Update `ui/styles/*` to register `PLAYER_XP_UPDATE` and other player events directly and to use `ContextBuilder` + `AnimationManager` to drive UI.
- [ ] Migrate minor differences from `ui/xpbar/styles` to `ui/styles` and port any missing features.
- [ ] Update `XPBar.lua` to remove xpEventFrame; keep `BroadcastUpdate`, `SetBarStyle` and `compat` shims only.
- [ ] Remove 'dev' test loader from `XPBarEnhanced.toc` and ensure test harness can be enabled via `devMode`.
- [ ] QA & integration testing across styles.
- [ ] Release with `legacyMode` default `false`, but allow opt-in `legacyMode` to battle-test.

- Risks & Mitigations

- Risk: Regression in animation or double updates. Mitigation: test harness, devMode instrumentation, step-by-step commit PRs.
- Risk: Visual regression due to differences between `ui/xpbar` and `ui/styles`. Mitigation: verification for each style, port missing pieces, keep `ui/xpbar` archived until `ui/styles` parity is proven.
- Risk: Other addons or exporters rely on `XPBar.lua` or `XPBar` controller behavior, causing breakage. Mitigation: Provide compatibility APIs (helpers) and deprecation logs.

- Open Questions / Next Steps

- Do we want to standardize `PLAYER_XP_UPDATE` only in per-style event registration or provide a single central manager? The above plan standardizes per-style registration.
- Are there use-cases where we need to keep `XPBar:BroadcastUpdate` live for global config updates? Yes — keep for color & config broadcast.
- Should `Session` persist session data across reloads? Decision: Keep sessionStart ephemeral but persist `gainedXP` in DB if requested; the team can choose.

- If you want, I can now:

- Draft targeted PRs for the first small tasks (create `Session` service & update `ContextBuilder`) or
- Create a PR to implement `BaseMixin:RegisterCommonEvents()` change (per-style event registration for XP updates) with `devMode` toggles and tests.

Which task would you like me to begin with first: building the `Session` module, updating `ContextBuilder`, implementing per-style registration in `BaseMixin` or archiving `ui/xpbar/styles`?

---

(Generated by the migration planning tool. No code changes applied.)
