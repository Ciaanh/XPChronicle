-- XP Bar Enhanced - Core.lua

local ADDON_NAME = "XPBarEnhanced"

-- Initialize addon namespace
XPBarEnhanced = XPBarEnhanced or {}
local Addon = XPBarEnhanced
Addon.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

Addon.EventNames = {
    XPBAR_BROADCAST_UPDATE = "XPBAR:BROADCAST_UPDATE",
    CONFIG_UPDATED = "CONFIG:UPDATED",
    COLORS_UPDATED = "COLORS:UPDATED",
    QUESTS_CACHE_INVALIDATED = "QUESTS:CACHE_INVALIDATED",
    XPBAR_ANIMATION_CONTEXT = "XPBAR:ANIMATION_CONTEXT"
}

-- Core modules
Addon.Config = Addon.Config or {}
Addon.Database = Addon.Database or {}
Addon.Session = Addon.Session or {}
Addon.Utils = Addon.Utils or {}

-- Features
Addon.Features = Addon.Features or {}

-- Event lifecycle is now split into core/AddOnLifecycle.lua

-- Slash Commands (moved to core/AddOnCommands.lua)

-- Slash command handling moved to core/AddOnCommands.lua

-- Register slash commands
-- Slash command registration moved to core/AddOnCommands.lua

-- Public API moved to core/AddOnPublicAPI.lua

---Register a feature module with a short name
-- Public API moved to core/AddOnPublicAPI.lua
