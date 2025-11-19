-- XP Bar Enhanced - Config.lua
-- Centralized configuration management and defaults

local Addon = XPBarEnhanced
Addon.Config = Addon.Config or {}

local Config = Addon.Config
local L = Addon.L or {}
-- Local alias for optional tooltip module (may be defined in the UI layer)
local XPBarTooltip = _G and _G.XPBarTooltip
-------------------------------------------------------------------
-- DEFAULTS
-------------------------------------------------------------------

local defaults = {
    -- Bar Style Selection
    barStyle = "classic", -- "none", "classic", "flat", "vertical", "circular"
    hideBlizzardBar = true,
    barLocked = false,
    -- Text Display Settings
    showPercentage = true,
    showQuestXP = true,
    showQuestPercent = true,
    showXPPerHourText = true,
    showLevelTimeText = true,
    showSessionTimeText = true,
    showTimeToLevelText = true,
    abbreviateNumbers = true,
    showRemainingXP = true,
    showBarAtMaxLevel = true,
    showLevelText = true,
    showXPText = true,
    -- Quest overlay settings
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    -- Animation Settings
    enableAnimations = true,
    animationSpeed = 1.0,
    animationEasing = "easeOut",
    flashOnGain = true,
    pauseOnHover = true,
    -- (no test overrides by default)

    -- Level-Up Celebration Settings
    levelUpCelebration = true,
    celebrationSparkles = false,
    celebrationSound = true,
    celebrationSpeed = "normal",
    -- Auto-Hide at Max Level
    maxLevelBehavior = "always_show",
    -- Fade In/Out Effects
    fadeWhenInactive = false,
    fadeDelay = 5.0,
    idleOpacity = 0.0,
    fadeInSpeed = 0.3,
    fadeOutSpeed = 0.5,
    -- Font Customization
    textFontFace = "Fonts\\FRIZQT__.TTF",
    textFontSize = 12,
    textFontOutline = "NONE",
    textFontShadow = false,
    -- Color Settings
    colors = {
        xpBar = {r = 0.58, g = 0.0, b = 0.55, a = 1},
        xpBarRested = {r = 0.0, g = 0.44, b = 1.0, a = 1},
        rested = {r = 0.07, g = 0.58, b = 0.95, a = 0.5},
        questComplete = {r = 1.0, g = 0.65, b = 0.0, a = 0.85},
        questIncomplete = {r = 0.5, g = 1.0, b = 0.2, a = 0.85}
    },
    -- Bar Position
    barPosition = {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    },
    -- Per-style saved positions (migrated from single barPosition when needed)
    barPositions = {
        classic = {
            point = "BOTTOM",
            relativeTo = "UIParent",
            relativePoint = "BOTTOM",
            x = 0,
            y = 12
        },
        flat = {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            x = 0,
            y = 0
        },
        circular = {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            x = 0,
            y = 0
        }
    }
}

-- Backward compatibility
defaults.xpBarColor = defaults.colors.xpBar

-- Export defaults
Addon.defaults = defaults

-- Export option metadata for UI (assigned after optionDetails is defined)

-------------------------------------------------------------------
-- OPTIONS METADATA
-------------------------------------------------------------------

local optionDetails = {
    barStyle = {
        key = "barStyle",
        type = "dropdown",
        label = Addon.L["OPT_BAR_STYLE"],
        description = Addon.L["OPT_BAR_STYLE_DESC"],
        options = {
            {value = "none", label = Addon.L["OPT_BAR_STYLE_NONE"]},
            {value = "classic", label = Addon.L["OPT_BAR_STYLE_CLASSIC"]},
            {value = "flat", label = Addon.L["OPT_BAR_STYLE_FLAT"]},
            {value = "vertical", label = Addon.L["OPT_BAR_STYLE_VERTICAL"]},
            {value = "circular", label = Addon.L["OPT_BAR_STYLE_CIRCULAR"]}
        },
        commandKeys = {"style", "mode", "barstyle"}
    },
    hideBlizzardBar = {
        key = "hideBlizzardBar",
        label = Addon.L["OPT_HIDE_BLIZZARD_BAR"],
        description = Addon.L["OPT_HIDE_BLIZZARD_BAR_DESC"],
        commandKeys = {"hideblizzard", "blizzardbar"}
    },
    barLocked = {
        key = "barLocked",
        label = Addon.L["OPT_BAR_LOCKED"],
        description = Addon.L["OPT_BAR_LOCKED_DESC"],
        commandKeys = {"lock", "locked"}
    },
    showQuestXP = {
        key = "showQuestXP",
        label = Addon.L["OPT_QUEST_XP"],
        description = Addon.L["OPT_QUEST_XP_DESC"],
        commandKeys = {"questxp", "quest"}
    },
    showCompleteQuestOverlay = {
        key = "showCompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_COMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_COMPLETE_OVERLAY_DESC"],
        commandKeys = {"completeoverlay"}
    },
    showIncompleteQuestOverlay = {
        key = "showIncompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY_DESC"],
        commandKeys = {"incompleteoverlay"}
    },
    showPercentage = {
        key = "showPercentage",
        label = Addon.L["OPT_PERCENTAGE"],
        description = Addon.L["OPT_PERCENTAGE_DESC"],
        commandKeys = {"percentage"}
    },
    showQuestPercent = {
        key = "showQuestPercent",
        label = Addon.L["OPT_QUEST_PERCENT"],
        description = Addon.L["OPT_QUEST_PERCENT_DESC"],
        commandKeys = {"questpercent", "questpct"}
    },
    showLevelText = {
        key = "showLevelText",
        label = Addon.L["OPT_LEVEL_TEXT"],
        description = Addon.L["OPT_LEVEL_TEXT_DESC"],
        commandKeys = {"leveltext"}
    },
    showXPText = {
        key = "showXPText",
        label = Addon.L["OPT_XP_TEXT"],
        description = Addon.L["OPT_XP_TEXT_DESC"],
        commandKeys = {"xptext"}
    },
    showRemainingXP = {
        key = "showRemainingXP",
        label = Addon.L["OPT_REMAINING_XP"],
        description = Addon.L["OPT_REMAINING_XP_DESC"],
        commandKeys = {"remaining"}
    },
    showXPPerHourText = {
        key = "showXPPerHourText",
        label = Addon.L["OPT_XP_HOUR"],
        description = Addon.L["OPT_XP_HOUR_DESC"],
        commandKeys = {"xphour"}
    },
    showLevelTimeText = {
        key = "showLevelTimeText",
        label = Addon.L["OPT_LEVEL_TIME"],
        description = Addon.L["OPT_LEVEL_TIME_DESC"],
        commandKeys = {"leveltime"}
    },
    showSessionTimeText = {
        key = "showSessionTimeText",
        label = Addon.L["OPT_SESSION_TIME"],
        description = Addon.L["OPT_SESSION_TIME_DESC"],
        commandKeys = {"sessiontime"}
    },
    showTimeToLevelText = {
        key = "showTimeToLevelText",
        label = Addon.L["OPT_TIME_TO_LEVEL"],
        description = Addon.L["OPT_TIME_TO_LEVEL_DESC"],
        commandKeys = {"timetolevel", "ttl"}
    },
    showBarAtMaxLevel = {
        key = "showBarAtMaxLevel",
        label = Addon.L["OPT_SHOW_AT_MAX"],
        description = Addon.L["OPT_SHOW_AT_MAX_DESC"],
        commandKeys = {"showmax"}
    },
    abbreviateNumbers = {
        key = "abbreviateNumbers",
        label = Addon.L["OPT_ABBREVIATE_NUMBERS"],
        description = Addon.L["OPT_ABBREVIATE_NUMBERS_DESC"],
        commandKeys = {"abbreviate"}
    },
    enableAnimations = {
        key = "enableAnimations",
        label = Addon.L["OPT_ENABLE_ANIMATIONS"],
        description = Addon.L["OPT_ENABLE_ANIMATIONS_DESC"],
        commandKeys = {"animations", "animate"}
    },
    animationEasing = {
        key = "animationEasing",
        type = "dropdown",
        label = Addon.L["OPT_ANIMATION_EASING"],
        description = Addon.L["OPT_ANIMATION_EASING_DESC"],
        options = {
            {value = "linear", label = Addon.L["OPT_EASING_LINEAR"]},
            {value = "easeIn", label = Addon.L["OPT_EASING_EASE_IN"]},
            {value = "easeOut", label = Addon.L["OPT_EASING_EASE_OUT"]},
            {value = "easeInOut", label = Addon.L["OPT_EASING_EASE_IN_OUT"]}
        },
        commandKeys = {"easing"}
    },
    flashOnGain = {
        key = "flashOnGain",
        label = Addon.L["OPT_FLASH_ON_GAIN"],
        description = Addon.L["OPT_FLASH_ON_GAIN_DESC"],
        commandKeys = {"flash"}
    },
    pauseOnHover = {
        key = "pauseOnHover",
        label = Addon.L["OPT_PAUSE_ON_HOVER"],
        description = Addon.L["OPT_PAUSE_ON_HOVER_DESC"],
        commandKeys = {"pause", "pausehover"}
    }
}

local optionOrder = {
    "barStyle",
    "hideBlizzardBar",
    "barLocked",
    "showQuestXP",
    "showCompleteQuestOverlay",
    "showIncompleteQuestOverlay",
    "showPercentage",
    "showQuestPercent",
    "showLevelText",
    "showXPText",
    "showRemainingXP",
    "showXPPerHourText",
    "showLevelTimeText",
    "showSessionTimeText",
    "showTimeToLevelText",
    "abbreviateNumbers",
    "showBarAtMaxLevel",
    "enableAnimations",
    "animationEasing",
    "flashOnGain",
    "pauseOnHover"
}

local colorOptionsList = {
    {
        key = "xpBar",
        command = "xpbar",
        aliases = {"bar"},
        label = Addon.L["COLOR_XP_BAR"],
        description = Addon.L["COLOR_XP_BAR_DESC"],
        preview = "statusbar"
    },
    {
        key = "xpBarRested",
        command = "xpBarRested",
        aliases = {"barrested", "restedbar"},
        label = Addon.L["COLOR_XP_BAR_RESTED"],
        description = Addon.L["COLOR_XP_BAR_RESTED_DESC"],
        preview = "statusbar"
    },
    {
        key = "questComplete",
        command = "questcomplete",
        aliases = {"complete"},
        label = Addon.L["COLOR_QUEST_COMPLETE"],
        description = Addon.L["COLOR_QUEST_COMPLETE_DESC"],
        preview = "texture"
    },
    {
        key = "questIncomplete",
        command = "questincomplete",
        aliases = {"incomplete"},
        label = Addon.L["COLOR_QUEST_INCOMPLETE"],
        description = Addon.L["COLOR_QUEST_INCOMPLETE_DESC"],
        preview = "texture"
    },
    {
        key = "rested",
        command = "rested",
        aliases = {"rest"},
        label = Addon.L["COLOR_RESTED"],
        description = Addon.L["COLOR_RESTED_DESC"],
        preview = "texture"
    }
}

-- Build lookup maps
local colorOptionMap = {}
local colorOptionByKey = {}
for index, info in ipairs(colorOptionsList) do
    info.order = index
    colorOptionByKey[info.key] = info
    colorOptionMap[info.command] = info
    if info.aliases then
        for _, alias in ipairs(info.aliases) do
            colorOptionMap[alias] = info
        end
    end
end

-- Export metadata
Config.optionDetails = optionDetails
Config.optionOrder = optionOrder
Config.colorOptionsList = colorOptionsList
Config.colorOptionMap = colorOptionMap
Config.colorOptionByKey = colorOptionByKey

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
    return optionDetails[key]
end

---Get the effective option value (falls back to defaults)
function Config:GetOptionValue(key)
    local value = Addon.db and Addon.db[key]
    if value == nil then
        value = defaults[key]
    end
    return value
end

function Config:SetOptionKey(key, value, silent)
    local detail = optionDetails[key]

    -- For dropdowns and other non-boolean options, preserve the actual value
    local newValue
    if detail and detail.type == "dropdown" then
        newValue = value
    else
        newValue = value and true or false
    end

    local oldValue = Addon.db[key]
    Addon.db[key] = newValue

    self:ApplyOptionSideEffects(key)

    if not silent then
        local label = detail and detail.label or key
        local Utils = Addon.Utils
        if Utils and Utils.Print then
            if newValue then
                Utils.Print(string.format(L["MSG_OPTION_ENABLED"] or "%s enabled", label))
            else
                Utils.Print(string.format(L["MSG_OPTION_DISABLED"] or "%s disabled", label))
            end
        end

        local optionsView = Addon.UI.Views and Addon.UI.Views.Options
        if optionsView and optionsView.Refresh then
            optionsView:Refresh()
        end
    end
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

    local xpbarView = Addon.UI.Views and Addon.UI.Views.XPBar
    if xpbarView and xpbarView.GetColor then
        local xpBarColor = xpbarView:GetColor(key)
        if xpBarColor then
            return xpBarColor
        end
    end

    if Addon.db and Addon.db.colors and Addon.db.colors[key] then
        return Addon.db.colors[key]
    end

    if defaults.colors and defaults.colors[key] then
        return defaults.colors[key]
    end

    return nil
end

function Config:GetDefaultColor(key)
    return defaults.colors and defaults.colors[key]
end

function Config:GetColorHex(key)
    return colorToHex(self:GetColor(key))
end

function Config:SetColor(key, hex, silent)
    if not key then
        return false, Addon.L["ERR_UNKNOWN_COLOR_TARGET"]
    end

    local r, g, b, a, normalized = parseHexColor(hex)
    if not r then
        return false, Addon.L["ERR_INVALID_COLOR"]
    end

    -- Update color in database
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

    -- -- Update color on visible XP bars (Classic bar uses static colors)
    -- local flatBar = _G.FlatXPBar and _G.FlatXPBar.Bar
    -- if flatBar and flatBar.UpdateBarOverlayColors then
    --     flatBar:UpdateBarOverlayColors()
    -- end

    -- Refresh tooltip (resolve at runtime to avoid load-order capture issues)
    local tt = _G and _G.XPBarTooltip
    if tt and tt.Refresh then
        tt:Refresh()
    end

    if not silent then
        local Utils = Addon.Utils
        local info = self:GetColorOptionByKey(key)
        if Utils and Utils.Print then
            if info then
                Utils.Print(string.format(L["MSG_COLOR_SET"] or "%s set to %s", info.label, normalized))
            else
                Utils.Print(string.format(L["MSG_COLOR_SET"] or "%s set to %s", key, normalized))
            end
        end
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.UpdateColorControls then
        optionsView:UpdateColorControls()
    end

    -- Force visual refresh of flat and classic bars if present
    local flatBar = _G and _G.FlatBar
    if flatBar and flatBar.Refresh then
        flatBar:Refresh()
    end

    return true, normalized
end

function Config:ResetColor(key, silent)
    local default = defaults.colors and defaults.colors[key]
    if not default then
        return false, Addon.L["ERR_NO_DEFAULT_COLOR"]
    end

    local hex = colorToHex(default)
    local success, normalized = self:SetColor(key, hex, true)
    if not success then
        return false, normalized
    end

    if not silent then
        local Utils = Addon.Utils
        local info = self:GetColorOptionByKey(key)
        if Utils and Utils.Print then
            if info then
                Utils.Print(string.format(L["MSG_COLOR_RESET"] or "%s reset to default", info.label))
            else
                Utils.Print(string.format(L["MSG_COLOR_RESET"] or "%s reset to default", key))
            end
        end
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.UpdateColorControls then
        optionsView:UpdateColorControls()
    end

    return true, normalized
end

function Config:GetColorOption(target)
    if not target then
        return nil
    end
    return colorOptionMap[string.lower(target)]
end

function Config:GetColorOptionByKey(key)
    return colorOptionByKey[key]
end

function Config:GetColorOptionList()
    return colorOptionsList
end

-------------------------------------------------------------------
-- SIDE EFFECTS
-------------------------------------------------------------------

function Config:ApplyOptionSideEffects(key)
    -- Bar visual options that require refresh
    local barVisualOptions = {
        "showQuestXP",
        "showPercentage",
        "showQuestPercent",
        "showBarAtMaxLevel",
        "showCompleteQuestOverlay",
        "showIncompleteQuestOverlay",
        "abbreviateNumbers",
        "showRemainingXP",
        "showLevelText",
        "showXPText",
        "showXPPerHourText",
        "showLevelTimeText",
        "showSessionTimeText",
        "showTimeToLevelText"
    }

    local needsBarRefresh = false
    for _, optionKey in ipairs(barVisualOptions) do
        if key == optionKey then
            needsBarRefresh = true
            break
        end
    end

    if needsBarRefresh then
        -- Update XP bar controller (use new path)
        local xpbar = Addon.XPBar
        if xpbar and xpbar.Update then
            xpbar:Update()
        end

        -- Force visual refresh of flat bar
        local _G_alias = _G
        local flatBar = _G_alias.FlatXPBar
        if flatBar and flatBar:IsShown() and flatBar.Bar then
            if flatBar.Bar.UpdateBarOverlayColors then
                flatBar.Bar:UpdateBarOverlayColors()
            end
            if flatBar.Bar.UpdateTextVisibility then
                flatBar.Bar:UpdateTextVisibility()
            end
            if flatBar.Bar.UpdateAllText then
                flatBar.Bar:UpdateAllText()
            end
        end

        -- Force visual refresh of classic bar
        local _G_alias2 = _G
        local classicBar = _G_alias2.ClassicXPBar
        if classicBar and classicBar:IsShown() and classicBar.Bar then
            if classicBar.Bar.UpdateBarOverlayColors then
                classicBar.Bar:UpdateBarOverlayColors()
            end
            if classicBar.Bar.UpdateTextVisibility then
                classicBar.Bar:UpdateTextVisibility()
            end
            if classicBar.Bar.UpdateAllText then
                classicBar.Bar:UpdateAllText()
            end
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
        local xpbar = Addon.XPBar
        if xpbar and xpbar.SetBarStyle then
            local newStyle = Addon.db.barStyle
            xpbar:SetBarStyle(newStyle, true) -- skipSave=true to avoid circular save
        end
    end

    -- Blizzard bar visibility changed
    if key == "hideBlizzardBar" then
        if Addon.UI.Views and Addon.UI.Views.XPBar and Addon.UI.Views.XPBar.Initialize then
            Addon.UI.Views.XPBar:Initialize(Addon.Features and Addon.Features.xpbar)
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

function Config:OpenOptions()
    local options = Addon.Options
    if options and options.Open then
        options:Open()
    end
end

function Config:Reset()
    local Utils = Addon.Utils

    -- Clone defaults
    local copy = {}
    for key, value in pairs(defaults) do
        copy[key] = Utils and Utils.Clone and Utils.Clone(value) or value
    end

    -- Apply to database
    for key, value in pairs(copy) do
        Addon.db[key] = value
    end

    -- Use XPBarController's ResetToDefaults
    local xpBarController = Addon.Features and Addon.Features.xpbar
    if xpBarController and xpBarController.ResetToDefaults then
        xpBarController:ResetToDefaults()
    end

    -- Apply changes
    if Addon.UI.Views and Addon.UI.Views.XPBar then
        if Addon.UI.Views.XPBar.ApplySavedPosition then
            Addon.UI.Views.XPBar:ApplySavedPosition()
        end
        if Addon.UI.Views.XPBar.ApplyAllColors then
            Addon.UI.Views.XPBar:ApplyAllColors()
        elseif Addon.UI.Views.XPBar.ApplyBarColor then
            Addon.UI.Views.XPBar:ApplyBarColor()
        end
        if Addon.UI.Views.XPBar.Update then
            Addon.UI.Views.XPBar:Update()
        end
    end

    local stats = Addon.Stats
    if stats and stats.Update then
        stats:Update()
    end

    if Addon.Session and Addon.Session.ClearTimePlayedRequest then
        Addon.Session:ClearTimePlayedRequest()
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.Refresh then
        optionsView:Refresh()
    end

    if Utils and Utils.Print then
        Utils.Print(Addon.L["MSG_SETTINGS_RESET"])
    end
end

function Config:ResetStats()
    local Utils = Addon.Utils
    local playerKey = Addon.playerKey
    if not playerKey then
        local name = UnitName("player")
        local realm = GetRealmName()
        playerKey = string.format("%s-%s", name or "Player", realm or "Realm")
        Addon.playerKey = playerKey
    end

    Addon.db.levelData = Addon.db.levelData or {}
    local currentLevel = UnitLevel("player")
    Addon.db.levelData[playerKey] = {
        [currentLevel] = {
            levelStart = time(),
            xpAtStart = UnitXP("player")
        }
    }

    Addon.db.sessionData = {
        sessionStart = time(),
        sessionXP = 0,
        gainedXP = 0,
        lastXP = UnitXP("player"),
        maxXP = UnitXPMax("player"),
        realTotalTime = 0,
        realLevelTime = 0,
        lastTimePlayedRequest = 0,
        lastUpdate = time()
    }

    if Addon.Session and Addon.Session.ClearTimePlayedRequest then
        Addon.Session:ClearTimePlayedRequest()
    end

    Addon.state.requestingTimePlayed = false
    Addon.state.snapshot = nil

    local stats = Addon.Stats
    if stats and stats.Update then
        stats:Update()
    end

    local xpbar = Addon.XPBar
    if xpbar and xpbar.Update then
        xpbar:Update()
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.Refresh then
        optionsView:Refresh()
    end

    if Utils and Utils.Print then
        Utils.Print(Addon.L["MSG_SETTINGS_RESET"])
    end
end

-- Backward compatibility
Addon.App = Addon.App or {}
Addon.App.Config = Addon.App.Config or {}
Addon.App.Config.Config = Config
Addon.App.Core = Addon.App.Core or {}
Addon.App.Core.Defaults = {defaults = defaults}

return Config
