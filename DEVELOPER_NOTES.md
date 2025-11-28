Refactor summary
================

This branch reorganizes XPBarEnhanced to centralize UI components and core services:

- Moved UI mixins, helpers, and frame components to `ui/` (mixins, components, helpers, options, styles).
- Moved service-like logic to `core/services/` (Database, QuestXPService, Session).
- Moved configuration to `core/config/` (Config, ConfigHelper, defaults).
- Removed legacy root `core/*.lua` that duplicated canonical implementations; replaced with clean canonical files or removed entirely.
- Updated `XPBarEnhanced.toc` to load canonical files and maintain XML/global compatibility where required.

Backward compatibility
----------------------

- `Addon.*` fields (e.g., `Addon.Config`, `Addon.Database`, `Addon.Session`, `Addon.UI.Components.FrameUtils`) are still set in canonical modules for code depending on globals.
- XML mixins are still exported via `_G.*` for compatibility (`_G.PositionStoreMixin`, `_G.DraggableFrameMixin`, `_G.FrameUtils`, `_G.OverlayHelper`).

- Behavior change: When a player reaches max level, the BarManager now forces the Blizzard experience bar (style set to `none`) and hides custom AddOn styles. This change ensures consistent UI behavior at max-level.

Next steps & Notes
------------------

- Manually test in-game to validate no runtime differences (dragging, options, saved variables, overlay rendering).
- After verification, remove any remaining compatibility shims in the `core/` root (if any) and tidy `TOC` if not needed.
- Add automated linting and CI checks to catch syntax issues earlier.

If you'd like I can continue with automated QA checks, add a small test harness, or open a PR with these changes.
