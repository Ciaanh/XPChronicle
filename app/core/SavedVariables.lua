local Addon = XPBarEnhanced
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

-- Migration from XPChronicle to XPBarEnhanced
local function migrateFromXPChronicle()
    -- Check if old data exists and new data doesn't
    if XPChronicleDB and not XPBarEnhancedDB then
        XPBarEnhancedDB = XPChronicleDB
        
        -- Notify user
        C_Timer.After(2, function()
            print("|cff33ff99XP Bar Enhanced|r: Settings migrated from XP Bar Enhanced")
        end)
        
        -- Clean up old variable after 5 seconds
        C_Timer.After(5, function()
            XPChronicleDB = nil
        end)
        
        return true
    end
    return false
end

function SavedVariables:EnsureDefaults(defaults)
    -- Attempt migration first
    migrateFromXPChronicle()
    
    if not XPBarEnhancedDB then
        XPBarEnhancedDB = {}
    end

    if Utils and Utils.MergeDefaults then
        Utils.MergeDefaults(XPBarEnhancedDB, defaults)
    end

    Addon.db = XPBarEnhancedDB
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
