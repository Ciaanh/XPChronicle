-- XP Chronicle Addon bootstrap
XPChronicle = XPChronicle or {}
local Addon = XPChronicle

Addon.App = Addon.App or {}
Addon.App.Core = Addon.App.Core or {}
Addon.App.Config = Addon.App.Config or {}
Addon.App.Services = Addon.App.Services or {}
Addon.App.Features = Addon.App.Features or {}
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Components = Addon.UI.Components or {}
Addon.UI.Views = Addon.UI.Views or {}
Addon.state = Addon.state or {
    requestingTimePlayed = false,
    xpGainDisabled = false,
    defaultXPBarHidden = false,
}
Addon.db = Addon.db or {}

local eventFrame = Addon.eventFrame or CreateFrame("Frame")
Addon.eventFrame = eventFrame
Addon.App.Core.eventHandlers = Addon.App.Core.eventHandlers or {}

local handlers = Addon.App.Core.eventHandlers

local function registerFrameEvent(event)
    if not eventFrame:IsEventRegistered(event) then
        eventFrame:RegisterEvent(event)
    end
end

function Addon:RegisterEvent(event, handler)
    if not event or type(handler) ~= "function" then
        return
    end

    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        registerFrameEvent(event)
    end

    table.insert(list, handler)
end

function Addon:DispatchEvent(event, ...)
    local list = handlers[event]
    if not list then
        return
    end

    local L = function(key, ...) return self.L and self.L(key, ...) or key end

    for index = 1, #list do
        local ok, err = pcall(list[index], ...)
        if not ok and self.App and self.App.Core and self.App.Core.Logger then
            self.App.Core.Logger:Error(L("ERR_EVENT_HANDLER_FAILED", event, err))
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    Addon:DispatchEvent(event, ...)
end)

function Addon:RegisterFeature(name, feature)
    if not name or type(feature) ~= "table" then
        return
    end

    self.App.Features[name] = feature
end

function Addon:GetFeature(name)
    return self.App.Features[name]
end

function Addon:HasFeature(name)
    return self.App.Features[name] ~= nil
end

function Addon:Initialize()
    local Defaults = self.App.Core.Defaults
    local SavedVariables = self.App.Core.SavedVariables
    local Utils = self.Utils
    local L = function(key, ...) return self.L and self.L(key, ...) or key end

    if not SavedVariables or not Defaults then
        if Utils and Utils.Print then
            Utils.Print(L("ERR_INIT_FAILED"))
        end
        return
    end

    SavedVariables:EnsureDefaults(Defaults.defaults)

    self.db = XPChronicleDB
    self.state.xpGainDisabled = SavedVariables:IsXPGainDisabled()

    local SessionService = self.App.Services.SessionService
    if SessionService and SessionService.Initialize then
        SessionService:Initialize()
    end

    local LevelHistoryService = self.App.Services.LevelHistoryService
    if LevelHistoryService and LevelHistoryService.Initialize then
        LevelHistoryService:Initialize()
    end

    self.state.snapshot = nil

    if Utils and Utils.Print then
        Utils.Print(L("ADDON_LOADED"))
    end
end

Addon:RegisterEvent("ADDON_LOADED", function(name)
    if name ~= "XPChronicle" then
        return
    end

    Addon:Initialize()
end)

Addon:RegisterEvent("PLAYER_LOGIN", function()
    local xpbar = Addon:GetFeature("xpbar")
    if xpbar and xpbar.Initialize then
        xpbar:Initialize()
    end

    local stats = Addon:GetFeature("stats")
    if stats and stats.Initialize then
        stats:Initialize()
    end

    local options = Addon:GetFeature("options")
    if options and options.Initialize then
        options:Initialize()
    end
end)

Addon:RegisterEvent("PLAYER_ENTERING_WORLD", function(...)
    local SessionService = Addon.App.Services.SessionService
    if SessionService and SessionService.OnEnteringWorld then
        SessionService:OnEnteringWorld(...)
    end

    local xpbar = Addon:GetFeature("xpbar")
    if xpbar and xpbar.OnEnteringWorld then
        xpbar:OnEnteringWorld(...)
    end
end)

Addon:RegisterEvent("PLAYER_XP_UPDATE", function()
    local SessionService = Addon.App.Services.SessionService
    if SessionService and SessionService.OnXPUpdate then
        SessionService:OnXPUpdate()
    end

    local xpbar = Addon:GetFeature("xpbar")
    if xpbar and xpbar.OnXPUpdate then
        xpbar:OnXPUpdate()
    end

    local stats = Addon:GetFeature("stats")
    if stats and stats.OnXPUpdate then
        stats:OnXPUpdate()
    end
end)

Addon:RegisterEvent("PLAYER_LEVEL_UP", function(level)
    local SessionService = Addon.App.Services.SessionService
    if SessionService and SessionService.OnLevelUp then
        SessionService:OnLevelUp(level)
    end

    local LevelHistoryService = Addon.App.Services.LevelHistoryService
    if LevelHistoryService and LevelHistoryService.OnLevelUp then
        LevelHistoryService:OnLevelUp(level)
    end

    local xpbar = Addon:GetFeature("xpbar")
    if xpbar and xpbar.OnLevelUp then
        xpbar:OnLevelUp(level)
    end

    local stats = Addon:GetFeature("stats")
    if stats and stats.OnLevelUp then
        stats:OnLevelUp(level)
    end
end)

Addon:RegisterEvent("TIME_PLAYED_MSG", function(totalTime, levelTime)
    local SessionService = Addon.App.Services.SessionService
    if SessionService and SessionService.OnTimePlayed then
        SessionService:OnTimePlayed(totalTime, levelTime)
    end

    local stats = Addon:GetFeature("stats")
    if stats and stats.OnTimePlayed then
        stats:OnTimePlayed(totalTime, levelTime)
    end
end)

Addon:RegisterEvent("ENABLE_XP_GAIN", function()
    local SavedVariables = Addon.App.Core.SavedVariables
    if SavedVariables and SavedVariables.SetXPGainDisabled then
        SavedVariables:SetXPGainDisabled(false)
    end
end)

Addon:RegisterEvent("DISABLE_XP_GAIN", function()
    local SavedVariables = Addon.App.Core.SavedVariables
    if SavedVariables and SavedVariables.SetXPGainDisabled then
        SavedVariables:SetXPGainDisabled(true)
    end
end)

-- Public API methods for backward compatibility
-- These methods provide a stable interface for external addons

function Addon:ClearTimePlayedTicker()
    local timeService = self.App.Services.TimePlayedService
    if timeService and timeService.ClearRequest then
        timeService:ClearRequest()
    end
end

function Addon:RequestTimePlayed()
    local timeService = self.App.Services.TimePlayedService
    if timeService and timeService.RequestTimePlayed then
        timeService:RequestTimePlayed()
    end
end

function Addon:ApplyDefaultXPBarVisibility()
    local view = self.UI.Views.XPBar
    if view and view.ApplyDefaultXPBarVisibility then
        view:ApplyDefaultXPBarVisibility()
    end
end
