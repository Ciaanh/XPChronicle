local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Services = Addon.App.Services or {}

local TimePlayedService = {}
local timePlayedTicker

local function clearTicker()
    if timePlayedTicker then
        timePlayedTicker:Cancel()
        timePlayedTicker = nil
    end
    Addon.state.requestingTimePlayed = false
end

function TimePlayedService:RequestTimePlayed()
    if Addon.state.requestingTimePlayed then
        return
    end

    clearTicker()
    Addon.state.requestingTimePlayed = true

    if C_Timer and C_Timer.NewTimer then
        timePlayedTicker = C_Timer.NewTimer(0.5, function()
            RequestTimePlayed()
        end)
    else
        RequestTimePlayed()
    end
end

function TimePlayedService:ClearRequest()
    clearTicker()
end

Addon.App.Services.TimePlayedService = TimePlayedService
