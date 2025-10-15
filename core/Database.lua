-- XP Bar Enhanced - Database.lua
-- Simplified database management (Phase 2)
-- Consolidates: SavedVariables.lua + migration logic

local Addon = XPBarEnhanced
Addon.Database = Addon.Database or {}

local Database = Addon.Database

-------------------------------------------------------------------
-- MIGRATION
-------------------------------------------------------------------

local function migrateFromXPChronicle()
    -- Check if old data exists and new data doesn't
    if XPChronicleDB and not XPBarEnhancedDB then
        XPBarEnhancedDB = XPChronicleDB
        
        -- Notify user
        C_Timer.After(2, function()
            print("|cff33ff99XP Bar Enhanced|r: Settings migrated from XP Chronicle")
        end)
        
        -- Clean up old variable after 5 seconds
        C_Timer.After(5, function()
            XPChronicleDB = nil
        end)
        
        return true
    end
    return false
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function Database:Initialize()
    -- Attempt migration first
    migrateFromXPChronicle()
    
    -- Create database if it doesn't exist
    if not XPBarEnhancedDB then
        XPBarEnhancedDB = {}
    end
    
    -- Merge defaults if Utils available
    local Utils = Addon.Utils
    local defaults = Addon.defaults
    if Utils and Utils.MergeDefaults and defaults then
        Utils.MergeDefaults(XPBarEnhancedDB, defaults)
    end
    
    -- Set addon database reference
    Addon.db = XPBarEnhancedDB
    Addon.db.sessionData = Addon.db.sessionData or {}
    
    -- Set player key
    local playerName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    Addon.playerKey = string.format("%s-%s", playerName, realmName)
end

-------------------------------------------------------------------
-- DATABASE ACCESS
-------------------------------------------------------------------

function Database:GetDB()
    return Addon.db or {}
end

function Database:GetSessionData()
    local db = self:GetDB()
    db.sessionData = db.sessionData or {}
    return db.sessionData
end

function Database:GetPlayerKey()
    -- Generate playerKey on-demand if not yet initialized
    if not Addon.playerKey then
        local playerName = UnitName("player") or "Unknown"
        local realmName = GetRealmName() or "Unknown"
        Addon.playerKey = string.format("%s-%s", playerName, realmName)
    end
    return Addon.playerKey
end

-------------------------------------------------------------------
-- XP GAIN STATE
-------------------------------------------------------------------

function Database:IsXPGainDisabled()
    -- Safe call to IsXPUserDisabled (may not exist in all versions)
    local disabled = false
    if IsXPUserDisabled then
        disabled = IsXPUserDisabled()
    end
    Addon.state.xpGainDisabled = disabled
    return disabled
end

function Database:SetXPGainDisabled(disabled)
    Addon.state.xpGainDisabled = disabled
end

-------------------------------------------------------------------
-- BACKWARD COMPATIBILITY
-------------------------------------------------------------------

-- Maintain old namespace structure for backward compatibility
Addon.App = Addon.App or {}
Addon.App.Core = Addon.App.Core or {}
Addon.App.Core.SavedVariables = Database

return Database
