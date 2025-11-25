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
Addon.Logger = Addon.Logger or {}

-- Features
Addon.Features = Addon.Features or {}

-- UI
Addon.UI = Addon.UI or {}

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

-- Event frame for WoW events
local eventFrame = CreateFrame("Frame")

-------------------------------------------------------------------
-- Direct Event Handlers (replaces EventBus abstraction)
-------------------------------------------------------------------

local eventHandlers = {}

function eventHandlers:OnAddonLoaded(name)
    if name ~= ADDON_NAME then
        return
    end

    -- Initialize core systems
    if Addon.Database and Addon.Database.Initialize then
        Addon.Database:Initialize()
    end

    if Addon.Config and Addon.Config.Initialize then
        Addon.Config:Initialize()
    end

    -- Set database reference
    Addon.db = XPBarEnhancedDB or {}

    -- Get XP gain disabled state
    Addon.state.xpGainDisabled = Addon.Database:IsXPGainDisabled()

    -- Print loaded message
    if Addon.Utils and Addon.Utils.Print and Addon.L then
        Addon.Utils.Print(Addon.L["ADDON_LOADED"])
    end
end

function eventHandlers:OnPlayerLogin()
    -- Initialize session
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end

    -- Initialize features
    local stats = Addon.Stats
    if stats and stats.Initialize then
        stats:Initialize()
    end

    -- Initialize XP bar manager / legacy XPBar shim.
    -- Prefer calling the UI BarManager directly if present, fallback to the legacy XPBar shim.
    if Addon.BarManager and Addon.BarManager.Initialize then
        Addon.BarManager:Initialize()
    end

    local options = Addon.Options
    if options and options.Initialize then
        options:Initialize()
    end
end

function eventHandlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    -- Session handling
    if Addon.Session and Addon.Session.OnEnteringWorld then
        Addon.Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    -- Invalidate quest cache and notify observers of entering world
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        Addon.QuestXPService:InvalidateQuestCache()
    end
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUI) or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    elseif Addon.BarManager and Addon.BarManager.OnEnteringWorld then
        Addon.BarManager:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
end

function eventHandlers:OnPlayerXPUpdate()
    -- Deprecated: this top-level event handler is intentionally no longer
    -- registered. XP update events are handled by dedicated modules:
    -- - `XPBar:RegisterXPEvents()` handles animation and view updates;
    -- - `Session:SetupEventFrame()` handles session tracking;
    -- - `Stats:RegisterEventHandlers()` handles stats updates.
    -- We keep this function as a no-op for backward compatibility in case
    -- external code still attempts to call it directly.
end

function eventHandlers:OnPlayerLevelUp(level)
    -- Deprecated: handled by Session, XPBar and Stats modules individually.
    -- Keep for backward compatibility only (no-op if events are handled elsewhere).
    if Addon.Session and Addon.Session.OnLevelUp then
        Addon.Session:OnLevelUp(level)
    end
    -- Invalidate quest cache and broadcast update via EventBus; fallback to shim
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        Addon.QuestXPService:InvalidateQuestCache()
    end
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("PLAYER_LEVEL_UP", level) or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    elseif Addon.BarManager and Addon.BarManager.OnLevelUp then
        Addon.BarManager:OnLevelUp(level)
    end
    local stats = Addon.Stats
    if stats and stats.OnLevelUp then
        stats:OnLevelUp(level)
    end
end

function eventHandlers:OnUpdateExhaustion()
    -- Prefer broadcasting via EventBus; fall back to shim if necessary
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("UPDATE_EXHAUSTION") or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    elseif Addon.BarManager and Addon.BarManager.OnRestedChanged then
        Addon.BarManager:OnRestedChanged()
    end
end

function eventHandlers:OnPlayerUpdateResting()
    -- Prefer broadcasting via EventBus; fall back to shim if necessary
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("PLAYER_UPDATE_RESTING") or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    elseif Addon.BarManager and Addon.BarManager.OnRestedChanged then
        Addon.BarManager:OnRestedChanged()
    end
end

function eventHandlers:OnTimePlayedMsg(totalTime, levelTime)
    -- Deprecated: module-owned (Session/Stats). Kept for compatibility only.
    if Addon.Session and Addon.Session.OnTimePlayed then
        Addon.Session:OnTimePlayed(totalTime, levelTime)
    end
    local stats = Addon.Stats
    if stats and stats.OnTimePlayed then
        stats:OnTimePlayed(totalTime, levelTime)
    end
end

function eventHandlers:OnEnableXPGain()
    Addon.state.xpGainDisabled = false
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(false)
    end
end

function eventHandlers:OnDisableXPGain()
    Addon.state.xpGainDisabled = true
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(true)
    end
end

function eventHandlers:OnPlayerLogout()
    -- Broadcast shutdown to observers and graceful shutdown of sub-systems
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and XPBarContextBuilder.BuildContext("SHUTDOWN") or nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    elseif Addon.BarManager and Addon.BarManager.Shutdown then
        Addon.BarManager:Shutdown()
    end
end

-- Event name to handler mapping
-- Only register AddOn-level lifecycle events here. Events specific to XP
-- (PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, UPDATE_EXHAUSTION, PLAYER_UPDATE_RESTING,
-- TIME_PLAYED_MSG) should be registered by the controller or respective modules
-- (e.g., `XPBar:RegisterXPEvents()` or `Session`), to avoid duplicate handling.
local eventMap = {
    ADDON_LOADED = "OnAddonLoaded",
    PLAYER_LOGIN = "OnPlayerLogin",
    PLAYER_ENTERING_WORLD = "OnPlayerEnteringWorld",
    ENABLE_XP_GAIN = "OnEnableXPGain",
    DISABLE_XP_GAIN = "OnDisableXPGain",
    PLAYER_LOGOUT = "OnPlayerLogout"
}

-- Event dispatcher
eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        local handlerName = eventMap[event]
        if handlerName and eventHandlers[handlerName] then
            local success, err = pcall(eventHandlers[handlerName], eventHandlers, ...)
            if not success and Addon.Logger and Addon.Logger.Error then
                Addon.Logger:Error("Event handler failed for " .. event .. ": " .. tostring(err))
            end
        end
    end
)

-- Register all events
for event in pairs(eventMap) do
    eventFrame:RegisterEvent(event)
end

-------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------

local function printUnknown(command)
    print("|cFFFF0000Unknown command:|r " .. (command or ""))
    print("|cff33ff99XP Bar Enhanced|r - Use /xpbe help for commands")
end

local function showHelp()
    print("|cff33ff99XP Bar Enhanced|r Commands:")
    print("  /xpbe |cFFFFFFFFoptions|r - Open options panel")
    print("  /xpbe |cFFFFFFFFstats|r - Toggle statistics window")
    print("  /xpbe |cFFFFFFFFstyle <none|classic|flat|vertical|circular>|r - Change bar style")
    print("  /xpbe |cFFFFFFFFreset|r - Reset all settings")
    print("  /xpbe |cFFFFFFFFresetstats|r - Reset statistics")
    print("  /xpbe |cFFFFFFFFresetcolors|r - Reset colors to defaults")
    print("  /xpbe |cFFFFFFFFhelp|r - Show this help")
end

local function handleStats()
    local stats = Addon.Stats
    if stats and stats.Toggle then
        stats:Toggle()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Stats feature not available")
    end
end

local function handleOptions()
    if Addon.Config and Addon.Config.OpenOptions then
        Addon.Config:OpenOptions()
    else
        -- Fallback: open via settings
        Settings.OpenToCategory("XP Bar Enhanced")
    end
end

local function handleReset()
    if Addon.Config and Addon.Config.Reset then
        Addon.Config:Reset()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Reset function not available")
    end
end

local function handleResetStats()
    if Addon.Config and Addon.Config.ResetStats then
        Addon.Config:ResetStats()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Reset stats function not available")
    end
end

local function handleResetColors()
    if Addon.defaults and Addon.defaults.colors then
        Addon.db.colors = {}

        -- Copy default colors
        for colorKey, colorValue in pairs(Addon.defaults.colors) do
            Addon.db.colors[colorKey] = {
                r = colorValue.r,
                g = colorValue.g,
                b = colorValue.b,
                a = colorValue.a
            }
        end

        print("|cFF00FF00XP Bar Enhanced:|r Colors reset to defaults. Please /reload")
    else
        print("|cFFFF0000XP Bar Enhanced:|r Could not find default colors")
    end
end

local function handleStyle(style)
    style = string.lower(style or "")

    if style == "" then
        -- Show current style
        local currentStyle = Addon.db.barStyle or "classic"
        print("|cFF00FF00XP Bar Enhanced:|r Current bar style: " .. currentStyle)
        print("Usage: /xpbe style <none|classic|flat>")
        return
    end

    if style == "none" or style == "classic" or style == "flat" or style == "vertical" or style == "circular" then
        -- Use BarManager directly when available, otherwise fallback to simplified XPBar shim
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(style)
            print("|cFF00FF00XP Bar Enhanced:|r Bar style set to: " .. style)
        else
            print("|cFFFF0000XP Bar Enhanced:|r XP Bar module or BarManager not available")
        end
    else
        print("|cFFFF0000XP Bar Enhanced:|r Invalid style. Use: none, classic, flat, vertical, circular")
    end
end

local function handleSlashCommand(message)
    local command, arg = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        showHelp()
    elseif command == "stats" then
        handleStats()
    elseif command == "options" or command == "config" or command == "settings" then
        handleOptions()
    elseif command == "reset" then
        handleReset()
    elseif command == "resetstats" or command == "clearstats" then
        handleResetStats()
    elseif command == "resetcolors" then
        handleResetColors()
    elseif command == "style" or command == "barstyle" or command == "mode" then
        handleStyle(arg)
    else
        printUnknown(command)
    end
end

-- Register slash commands
SLASH_XPBARENHANCED1 = "/xpbe"
SLASH_XPBARENHANCED2 = "/xpbarenhanced"
SLASH_XPBARENHANCED3 = "/xpbar"
SlashCmdList["XPBARENHANCED"] = handleSlashCommand

-------------------------------------------------------------------
-- Public API (for backward compatibility and external access)
-------------------------------------------------------------------

---Register a feature module with a short name
function Addon:RegisterFeature(name, feature)
    if not name or type(feature) ~= "table" then
        return
    end
    self.Features[name] = feature
end

---Return a previously registered feature by name
function Addon:GetFeature(name)
    return self.Features[name]
end

---Return whether a feature with the provided name is registered
function Addon:HasFeature(name)
    return self.Features[name] ~= nil
end

function Addon:ClearTimePlayedTicker()
    if self.Session and self.Session.ClearTimePlayedRequest then
        self.Session:ClearTimePlayedRequest()
    end
end

function Addon:RequestTimePlayed()
    if self.Session and self.Session.RequestTimePlayed then
        self.Session:RequestTimePlayed()
    end
end

function Addon:ApplyDefaultXPBarVisibility()
    local view = self.UI.Views and self.UI.Views.XPBar
    if view and view.ApplyDefaultXPBarVisibility then
        view:ApplyDefaultXPBarVisibility()
    end
end
