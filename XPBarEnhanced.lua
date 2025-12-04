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
    QUESTS_CACHE_REBUILT = "QUESTS:CACHE_REBUILT",
    XPBAR_ANIMATION_CONTEXT = "XPBAR:ANIMATION_CONTEXT"
}

Addon.OptionsCategory = "XP Bar Enhanced"

-- Core modules
Addon.Config = Addon.Config or {}
Addon.Database = Addon.Database or {}
Addon.Session = Addon.Session or {}
Addon.Utils = Addon.Utils or {}

-- State
Addon.state =
    Addon.state or
    {
        requestingTimePlayed = false,
        xpGainDisabled = false,
        defaultXPBarHidden = false
    }

-- Database reference
Addon.db = Addon.db or {}

-- UI namespaces
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

