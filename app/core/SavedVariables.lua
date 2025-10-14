local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Core = Addon.App.Core or {}

local Utils = Addon.Utils
local SavedVariables = {}

local function safeIsXPUserDisabled()
    if IsXPUserDisabled then
        return IsXPUserDisabled()
    end
    return false
end

function SavedVariables:EnsureDefaults(defaults)
    if not XPChronicleDB then
        XPChronicleDB = {}
    end

    if Utils and Utils.MergeDefaults then
        Utils.MergeDefaults(XPChronicleDB, defaults)
    end

    Addon.db = XPChronicleDB
    Addon.db.sessionData = Addon.db.sessionData or {}

    local playerName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    local playerKey = string.format("%s-%s", playerName, realmName)
    Addon.playerKey = playerKey
end

function SavedVariables:GetDB()
    return Addon.db or {}
end

function SavedVariables:GetSessionData()
    local db = self:GetDB()
    db.sessionData = db.sessionData or {}
    return db.sessionData
end

function SavedVariables:GetPlayerKey()
    -- Generate playerKey on-demand if not yet initialized
    if not Addon.playerKey then
        local playerName = UnitName("player") or "Unknown"
        local realmName = GetRealmName() or "Unknown"
        Addon.playerKey = string.format("%s-%s", playerName, realmName)
    end
    return Addon.playerKey
end

function SavedVariables:IsXPGainDisabled()
    Addon.state.xpGainDisabled = safeIsXPUserDisabled()
    return Addon.state.xpGainDisabled
end

function SavedVariables:SetXPGainDisabled(disabled)
    Addon.state.xpGainDisabled = disabled
end

Addon.App.Core.SavedVariables = SavedVariables
