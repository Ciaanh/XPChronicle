-- AddOnLifecycle.lua
-- Lifecycle handlers extracted from XPBarEnhanced.lua

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

local eventFrame = CreateFrame("Frame")

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
    print(Addon.L["ADDON_LOADED"])
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
    if Addon.BarManager and Addon.BarManager.Initialize then
        Addon.BarManager:Initialize()
    end

    -- Initialize Minimap Button
    if Addon.MinimapButton and Addon.MinimapButton.Initialize then
        Addon.MinimapButton:Initialize()
    end

    local options = Addon.Options
    if options and options.Initialize then
        options:Initialize()
    end
end

function eventHandlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if Addon.Session and Addon.Session.OnEnteringWorld then
        Addon.Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        Addon.QuestXP:InvalidateQuestCache()
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.OnEnteringWorld then
        Addon.BarManager:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
end

function eventHandlers:OnPlayerLevelUp(level)
    if Addon.Session and Addon.Session.OnLevelUp then
        Addon.Session:OnLevelUp(level)
    end
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        Addon.QuestXP:InvalidateQuestCache()
    end
    -- Always call BarManager to check if we hit max level and need to hide the bar
    if Addon.BarManager and Addon.BarManager.OnLevelUp then
        Addon.BarManager:OnLevelUp(level)
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
    local stats = Addon.Stats
    if stats and stats.OnLevelUp then
        stats:OnLevelUp(level)
    end
end

function eventHandlers:OnPlayerXPUpdate()
    -- Deprecated: this top-level event handler is intentionally no longer
    -- registered. XP update events are handled by dedicated modules.
    -- Kept as a no-op for backward compatibility in case external code calls it.
end

function eventHandlers:OnUpdateExhaustion()
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.OnRestedChanged then
        Addon.BarManager:OnRestedChanged()
    end
end

function eventHandlers:OnPlayerUpdateResting()
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.OnRestedChanged then
        Addon.BarManager:OnRestedChanged()
    end
end

function eventHandlers:OnTimePlayedMsg(totalTime, levelTime)
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
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.Shutdown then
        Addon.BarManager:Shutdown()
    end
end

local eventMap = {
    ADDON_LOADED = "OnAddonLoaded",
    PLAYER_LOGIN = "OnPlayerLogin",
    PLAYER_ENTERING_WORLD = "OnPlayerEnteringWorld",
    ENABLE_XP_GAIN = "OnEnableXPGain",
    DISABLE_XP_GAIN = "OnDisableXPGain",
    PLAYER_LOGOUT = "OnPlayerLogout"
}

eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        local handlerName = eventMap[event]
        if handlerName and eventHandlers[handlerName] then
            local success, err = pcall(eventHandlers[handlerName], eventHandlers, ...)
            if not success then
                error("Event handler failed for " .. event .. ": " .. tostring(err))
            end
        end
    end
)

for event in pairs(eventMap) do
    eventFrame:RegisterEvent(event)
end

return eventHandlers
