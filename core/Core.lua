-- XP Bar Enhanced - Core.lua
-- Simplified core system with direct event handlers (Phase 2)

local ADDON_NAME = "XPBarEnhanced"

-- Initialize addon namespace
XPBarEnhanced = XPBarEnhanced or {}
local Addon = XPBarEnhanced

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
Addon.state = Addon.state or {
    requestingTimePlayed = false,
    xpGainDisabled = false,
    defaultXPBarHidden = false,
}

-- Database reference
Addon.db = Addon.db or {}

-- Event frame for WoW events
local eventFrame = CreateFrame("Frame")

-------------------------------------------------------------------
-- Direct Event Handlers (replaces EventBus abstraction)
-------------------------------------------------------------------

local eventHandlers = {}

function eventHandlers:ADDON_LOADED(name)
    if name ~= ADDON_NAME then return end
    
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
    if Addon.Utils and Addon.Utils.Print then
        local L = function(key, ...) return Addon.L and Addon.L(key, ...) or key end
        Addon.Utils.Print(L("ADDON_LOADED"))
    end
end

function eventHandlers:PLAYER_LOGIN()
    -- Initialize session
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end
    
    -- Initialize XP bar (simplified module)
    if Addon.XPBar and Addon.XPBar.Initialize then
        Addon.XPBar:Initialize()
    end
    
    -- Initialize features
    local stats = Addon.Stats
    if stats and stats.Initialize then
        stats:Initialize()
    end
    
    local options = Addon.Options
    if options and options.Initialize then
        options:Initialize()
    end
end

function eventHandlers:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    -- Session handling
    if Addon.Session and Addon.Session.OnEnteringWorld then
        Addon.Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    
    -- XP Bar handling (simplified module)
    if Addon.XPBar and Addon.XPBar.OnEnteringWorld then
        Addon.XPBar:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
end

function eventHandlers:PLAYER_XP_UPDATE()
    -- Session tracking
    if Addon.Session and Addon.Session.OnXPUpdate then
        Addon.Session:OnXPUpdate()
    end
    
    -- Update XP bar (simplified module)
    if Addon.XPBar and Addon.XPBar.OnXPUpdate then
        Addon.XPBar:OnXPUpdate()
    end
    
    -- Update stats
    local stats = Addon.Stats
    if stats and stats.OnXPUpdate then
        stats:OnXPUpdate()
    end
end

function eventHandlers:PLAYER_LEVEL_UP(level)
    -- Session level tracking
    if Addon.Session and Addon.Session.OnLevelUp then
        Addon.Session:OnLevelUp(level)
    end
    
    -- XP bar animation (simplified module)
    if Addon.XPBar and Addon.XPBar.OnLevelUp then
        Addon.XPBar:OnLevelUp(level)
    end
    
    -- Stats update
    local stats = Addon.Stats
    if stats and stats.OnLevelUp then
        stats:OnLevelUp(level)
    end
end

function eventHandlers:UPDATE_EXHAUSTION()
    if Addon.XPBar and Addon.XPBar.OnRestedChanged then
        Addon.XPBar:OnRestedChanged()
    end
end

function eventHandlers:PLAYER_UPDATE_RESTING()
    if Addon.XPBar and Addon.XPBar.OnRestedChanged then
        Addon.XPBar:OnRestedChanged()
    end
end

function eventHandlers:TIME_PLAYED_MSG(totalTime, levelTime)
    -- Session time tracking
    if Addon.Session and Addon.Session.OnTimePlayed then
        Addon.Session:OnTimePlayed(totalTime, levelTime)
    end
    
    -- Stats update
    local stats = Addon.Stats
    if stats and stats.OnTimePlayed then
        stats:OnTimePlayed(totalTime, levelTime)
    end
end

function eventHandlers:ENABLE_XP_GAIN()
    Addon.state.xpGainDisabled = false
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(false)
    end
end

function eventHandlers:DISABLE_XP_GAIN()
    Addon.state.xpGainDisabled = true
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(true)
    end
end

-- Event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        local success, err = pcall(eventHandlers[event], eventHandlers, ...)
        if not success and Addon.Logger and Addon.Logger.Error then
            Addon.Logger:Error("Event handler failed for " .. event .. ": " .. tostring(err))
        end
    end
end)

-- Register all events
for event in pairs(eventHandlers) do
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
    print("  /xpbe |cFFFFFFFFstyle <none|legacy|flat>|r - Change bar style")
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
        local currentStyle = Addon.db.barStyle or "legacy"
        print("|cFF00FF00XP Bar Enhanced:|r Current bar style: " .. currentStyle)
        print("Usage: /xpbe style <none|legacy|flat>")
        return
    end
    
    if style == "none" or style == "legacy" or style == "flat" then
        -- Use simplified XPBar module
        if Addon.XPBar and Addon.XPBar.SetBarStyle then
            Addon.XPBar:SetBarStyle(style)
            print("|cFF00FF00XP Bar Enhanced:|r Bar style set to: " .. style)
        else
            print("|cFFFF0000XP Bar Enhanced:|r XP Bar module not available")
        end
    else
        print("|cFFFF0000XP Bar Enhanced:|r Invalid style. Use: none, legacy, or flat")
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
SlashCmdList["XPBARENHANCED"] = handleSlashCommand

-------------------------------------------------------------------
-- Public API (for backward compatibility and external access)
-------------------------------------------------------------------

function Addon:RegisterFeature(name, feature)
    if not name or type(feature) ~= "table" then
        return
    end
    self.Features[name] = feature
end

function Addon:GetFeature(name)
    return self.Features[name]
end

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

-- Backward compatibility for old namespace structure
Addon.App = Addon.App or {}
Addon.App.Features = Addon.Features
Addon.App.Core = {
    Defaults = Addon.Config,
    SavedVariables = Addon.Database,
}
Addon.App.Services = {
    SessionService = Addon.Session,
    TimePlayedService = Addon.Session,
}
