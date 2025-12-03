# XP Bar Enhanced

XP Bar Enhanced is a World of Warcraft add-on that replaces and augments the default XP bar with richer visuals, quest XP overlays, session statistics, and customizable colors.

## Features

- Multiple bar styles (classic, flat, vertical, circular)
- Quest XP overlay and completion summaries
- Session tracking and statistics view
- Color customization and presets

## Quickstart

1. Drop the `XPBarEnhanced` folder into your AddOns directory
2. Start or reload WoW
3. Use `/xpbe` to open options or `/xpbe stats` to view statistics

## Developer Notes

- Event names are defined in `XPBarEnhanced.lua` as `Addon.EventNames`.
- Prefer `Addon.EventBus` for cross-module publish/subscribe and use the constants from `Addon.EventNames` to avoid string literal duplication. Example:

```lua
Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, "myHandler", function(ctx)
    -- handle context
end)

Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
```

