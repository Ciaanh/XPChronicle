-- XP Bar Enhanced - Config.lua
-- Centralized configuration management and defaults

local Addon = XPBarEnhanced
Addon.Config = Addon.Config or {}

local Config = Addon.Config
local L = Addon.L or {}
local EventNames = Addon.EventNames

-------------------------------------------------------------------
-- Defaults are extracted to `core/config/defaults.lua` and assigned to `Addon.defaults`.
-------------------------------------------------------------------

-- Export option metadata for UI (still assigned elsewhere)

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

---Initialize configuration state and migrate any classic settings
function Config:Initialize()
    -- Configuration is now managed by Database module
    -- Migrate single barPosition to per-style barPositions if needed
    if Addon and Addon.db then
        if not Addon.db.barPositions then
            -- If user has an existing single position, copy it to all styles as a sensible default
            if Addon.db.barPosition then
                Addon.db.barPositions = {
                    classic = Addon.db.barPosition,
                    flat = Addon.db.barPosition,
                    vertical = Addon.db.barPosition,
                    circular = Addon.db.barPosition
                }
            else
                -- Ensure table exists so code can write per-style entries
                Addon.db.barPositions = {}
            end
        end
    end
end

-------------------------------------------------------------------
-- OPTIONS API
-------------------------------------------------------------------

---Get option metadata for a given option key
function Config:GetOptionDetail(key)
    return self.optionDetails and self.optionDetails[key]
end

---Get the effective option value (falls back to defaults)
function Config:GetOptionValue(key)
    local value = Addon.db and Addon.db[key]
    if value == nil then
        value = Addon.defaults and Addon.defaults[key]
    end
    return value
end

function Config:SetOptionKey(key, value, silent)
    local detail = self.optionDetails and self.optionDetails[key]

    -- For dropdowns, sliders, and other non-boolean options, preserve the actual value
    local newValue
    if detail and (detail.type == "dropdown" or detail.type == "slider") then
        newValue = value
    else
        newValue = value and true or false
    end

    local oldValue = Addon.db[key]
    Addon.db[key] = newValue

    self:ApplyOptionSideEffects(key)
end

-------------------------------------------------------------------
-- COLOR API
-------------------------------------------------------------------

local function colorToHex(color)
    if not color then
        return "FFFFFFFF"
    end

    local function component(value)
        value = math.min(math.max(value or 1, 0), 1)
        return math.floor(value * 255 + 0.5)
    end

    local r = component(color.r or color[1])
    local g = component(color.g or color[2])
    local b = component(color.b or color[3])
    local a = component(color.a or color[4] or 1)

    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

local function parseHexColor(hex)
    if not hex or hex == "" then
        return nil
    end

    hex = string.upper(hex):gsub("^#", "")

    if #hex ~= 6 and #hex ~= 8 then
        return nil
    end
    if not hex:match("^[0-9A-F]+$") then
        return nil
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

    if not (r and g and b and a) then
        return nil
    end

    return r / 255, g / 255, b / 255, a / 255, hex
end

function Config:GetColor(key)
    if not key then
        return nil
    end

    if Addon.db and Addon.db.colors and Addon.db.colors[key] then
        return Addon.db.colors[key]
    end

    if Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key] then
        return Addon.defaults.colors[key]
    end

    return nil
end

function Config:GetDefaultColor(key)
    return Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key]
end

function Config:GetColorHex(key)
    return colorToHex(self:GetColor(key))
end

function Config:SetColor(key, hex, silent)
    if not key then
        return false, Addon.L and Addon.L["ERR_UNKNOWN_COLOR_TARGET"]
    end

    local r, g, b, a, normalized = parseHexColor(hex)
    if not r then
        return false, Addon.L and Addon.L["ERR_INVALID_COLOR"]
    end
    Addon.db = Addon.db or {}
    Addon.db.colors = Addon.db.colors or {}
    local colorTable = Addon.db.colors[key] or {}
    colorTable.r = r
    colorTable.g = g
    colorTable.b = b
    colorTable.a = a
    Addon.db.colors[key] = colorTable

    if key == "xpBar" then
        Addon.db.xpBarColor = colorTable
    end

    -- Emit a dedicated color update event so views can update only their color previews
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED)
    end

    return true, normalized
end

function Config:ResetColor(key, silent)
    local default = Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key]
    if not default then
        return false, Addon.L and Addon.L["ERR_NO_DEFAULT_COLOR"]
    end

    local hex = colorToHex(default)
    local success, normalized = self:SetColor(key, hex, true)
    if not success then
        return false, normalized
    end

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED)
    end

    return true, normalized
end

function Config:GetColorOption(target)
    if not target then
        return nil
    end
    return self.colorOptionMap and self.colorOptionMap[string.lower(target)]
end

function Config:GetColorOptionByKey(key)
    return self.colorOptionByKey and self.colorOptionByKey[key]
end

function Config:GetColorOptionList()
    return colorOptionsList
end

-------------------------------------------------------------------
-- SIDE EFFECTS
-------------------------------------------------------------------

function Config:ApplyOptionSideEffects(key)
    -- Emit a config-level event for fine-grained subscribers; also leave broadcast for compatibility
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED)
    end
    -- Bar visual options that require refresh
    local barVisualOptions = {
        "showQuestXP",
        "showPercentage",
        "showQuestPercent",

        "showCompleteQuestOverlay",
        "showIncompleteQuestOverlay",
        "abbreviateNumbers",
        "showRemainingXP",
        "showLevelText",
        "showXPText",
        "showXPPerHourText",
        "showLevelTimeText",
        "showSessionTimeText",
        "showTimeToLevelText",
        "showRestedOverlay"
    }

    local needsBarRefresh = false
    for _, optionKey in ipairs(barVisualOptions) do
        if key == optionKey then
            needsBarRefresh = true
            break
        end
    end

    if needsBarRefresh then
        -- Update XP bar controller (use new EventBus first)
        if Addon.EventBus and Addon.EventBus.Emit then
            Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
        end
    end

    -- Request time played if time text options enabled
    if key == "showLevelTimeText" or key == "showSessionTimeText" then
        local session = Addon.db.sessionData
        if
            session and (session.lastTimePlayedRequest or 0) == 0 and
                (Addon.db.showLevelTimeText or Addon.db.showSessionTimeText)
         then
            if Addon.Session and Addon.Session.RequestTimePlayed then
                Addon.Session:RequestTimePlayed()
            end
        end
    end

    -- Stats options that require refresh
    local statsOptions = {
        "showXPPerHourText",
        "showLevelTimeText",
        "showSessionTimeText",
        "showQuestXP",
        "abbreviateNumbers",
        "showPercentage",
        "showRemainingXP"
    }

    local needsStatsRefresh = false
    for _, optionKey in ipairs(statsOptions) do
        if key == optionKey then
            needsStatsRefresh = true
            break
        end
    end

    if needsStatsRefresh then
        local stats = Addon.Stats
        if stats and stats.Update then
            stats:Update()
        end
    end

    -- Bar style changed
    if key == "barStyle" then
        local newStyle = Addon.db.barStyle
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(newStyle)
        end
    end
end

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------

function Config:ShowHelp()
    print("|cFF00FF00" .. Addon.L["ADDON_NAME"] .. " Commands:|r")
    print("  |cFFFFD700/xpbe|r or |cFFFFD700/xpbe help|r - Show this help")
    print("  |cFFFFD700/xpbe stats|r - Toggle stats window")
    print("    (Ctrl + Click the XP bar for quick access)")
    print("    (Alt + Click the XP bar to open options)")
    print("  |cFFFFD700/xpbe options|r - Open the in-game options panel")
    print("     Customize colors and features from the options panel.")
    print("  |cFFFFD700/xpbe reset|r - Reset all settings to defaults")
    print("  |cFFFFD700/xpbe resetstats|r - Clear all tracked statistics")
    print("  |cFFFFD700/xpbe style <none|classic|flat>|r - Change bar style")
end

function Config:Reset()
    -- Wipe saved-variables and reinitialize database
    XPBarEnhancedDB = {}
    if Addon.Database and Addon.Database.Initialize then
        Addon.Database:Initialize()
    end
    -- Emit config change so UI updates
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED)
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function Config:ResetStats()
    if Addon and Addon.db then
        Addon.db.sessionData = {}
        Addon.db.stats = {}
    end
    if Addon.ContextBuilder and Addon.ContextBuilder.ResetSession then
        Addon.ContextBuilder.ResetSession()
    end
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end
    local stats = Addon.Stats
    if stats and stats.Update then
        stats:Update()
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED)
    end
end

Addon.Config = Config
return Config
