local Addon = XPChronicle
Addon.Config = Addon.Config or {}
Addon.App = Addon.App or {}
Addon.App.Config = Addon.App.Config or {}

local Config = Addon.Config
local Utils = Addon.Utils or {}
local metadata = Addon.App.Config.OptionsMetadata or {}
local SessionService = Addon.App.Services and Addon.App.Services.SessionService
local QuestXPService = Addon.App.Services and Addon.App.Services.QuestXPService
local TimePlayedService = Addon.App.Services and Addon.App.Services.TimePlayedService
local L = function(key, ...) return Addon.L and Addon.L(key, ...) or key end

local defaults = Addon.defaults or {}
local optionDetails = metadata.optionDetails or {}
local optionOrder = metadata.optionOrder or {}
local colorOptionsList = metadata.colorOptionsList or {}

local optionMap = {}
for key, detail in pairs(optionDetails) do
    if not detail.key then
        detail.key = key
    end
    if detail.commandKeys then
        for _, alias in ipairs(detail.commandKeys) do
            optionMap[alias] = detail
        end
    else
        optionMap[key] = detail
    end
end

local optionCommandNames = {}
for _, key in ipairs(optionOrder) do
    local detail = optionDetails[key]
    if detail then
        local alias = detail.commandKeys and detail.commandKeys[1] or key
        table.insert(optionCommandNames, alias)
    end
end

Config.optionListString = table.concat(optionCommandNames, ", ")
Config.optionDetails = optionDetails
Config.optionOrder = optionOrder

local colorOptionMap = {}
local colorOptionByKey = {}
local colorCommandNames = {}

for index, info in ipairs(colorOptionsList) do
    info.order = index
    colorOptionByKey[info.key] = info
    colorOptionMap[info.command] = info
    table.insert(colorCommandNames, info.command)

    if info.aliases then
        for _, alias in ipairs(info.aliases) do
            colorOptionMap[alias] = info
        end
    end
end

Config.colorOptionsList = colorOptionsList
Config.colorOptionMap = colorOptionMap
Config.colorOptionByKey = colorOptionByKey
Config.colorCommandNames = colorCommandNames
Config.colorCommandListString = table.concat(colorCommandNames, ", ")

function Config:GetOptionDetail(key)
    return optionDetails[key]
end

function Config:GetOptionValue(key)
    local value = Addon.db[key]
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
        newValue = value  -- Keep the actual string value
    else
        newValue = value and true or false  -- Boolean for checkboxes
    end
    
    Addon.db[key] = newValue

    self:ApplyOptionSideEffects(key)

    if not silent then
        local label = detail and detail.label or key
        if newValue then
            Utils.Print(L("MSG_OPTION_ENABLED", label))
        else
            Utils.Print(L("MSG_OPTION_DISABLED", label))
        end
        local optionsView = Addon.UI.Views and Addon.UI.Views.Options
        if optionsView and optionsView.Refresh then
            optionsView:Refresh()
        end
    end
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
    if not key then
        return nil
    end

    if defaults.colors and defaults.colors[key] then
        return defaults.colors[key]
    end

    return nil
end

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

function Config:GetColorHex(key)
    local color = self:GetColor(key)
    if not color then
        return "FFFFFFFF"
    end
    return colorToHex(color)
end

function Config:SetColor(key, hex, silent)
    if not key then
        return false, L("ERR_UNKNOWN_COLOR_TARGET")
    end

    local r, g, b, a, normalized = parseHexColor(hex)
    if not r then
        return false, L("ERR_INVALID_COLOR")
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

    -- Update color on visible XP bars
    -- Note: Legacy bar uses STATIC colors only (fixed Blizzard look - not customizable)
    -- Only Flat bar responds to color picker changes
    local flatBar = _G.XPC_FlatXPBar and _G.XPC_FlatXPBar.Bar
    
    if flatBar and flatBar.UpdateBarOverlayColors then
        flatBar:UpdateBarOverlayColors()
    end

    -- Refresh tooltip colors if tooltip is currently showing
    if XPC_XPBarTooltip and XPC_XPBarTooltip.Refresh then
        XPC_XPBarTooltip:Refresh()
    end

    if not silent then
        local info = self:GetColorOptionByKey(key)
        if info then
            Utils.Print(L("MSG_COLOR_SET", info.label, normalized))
        else
            Utils.Print(L("MSG_COLOR_SET", key, normalized))
        end
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.UpdateColorControls then
        optionsView:UpdateColorControls()
    end

    return true, normalized
end

function Config:ResetColor(key, silent)
    local default = defaults.colors and defaults.colors[key]
    if not default then
        return false, L("ERR_NO_DEFAULT_COLOR")
    end

    local hex = colorToHex(default)
    local success, normalized = self:SetColor(key, hex, true)
    if not success then
        return false, normalized
    end

    if not silent then
        local info = self:GetColorOptionByKey(key)
        if info then
            Utils.Print(L("MSG_COLOR_RESET", info.label))
        else
            Utils.Print(L("MSG_COLOR_RESET", key))
        end
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.UpdateColorControls then
        optionsView:UpdateColorControls()
    end

    return true, normalized
end

function Config:GetColorOptionList()
    return colorOptionsList
end

function Config:ApplyOptionSideEffects(key)
    -- All text display and visual options that affect XP bar
    local barVisualOptions = {
        "showQuestXP", "showPercentage", "showQuestPercent",
        "showBarAtMaxLevel", "showCompleteQuestOverlay", "showIncompleteQuestOverlay",
        "abbreviateNumbers", "showRemainingXP",
        "showLevelText", "showXPText", "showXPPerHourText",
        "showLevelTimeText", "showSessionTimeText", "showTimeToLevelText"
    }
    
    local needsBarRefresh = false
    for _, optionKey in ipairs(barVisualOptions) do
        if key == optionKey then
            needsBarRefresh = true
            break
        end
    end
    
    if needsBarRefresh then
        -- Update XP bar controller - this updates bar display and text
        local xpbar = Addon.App.Features and Addon.App.Features.xpbar
        if xpbar and xpbar.Update then
            xpbar:Update()
        elseif Addon.UI.Views and Addon.UI.Views.XPBar and Addon.UI.Views.XPBar.Update then
            Addon.UI.Views.XPBar:Update()
        end
        
        -- Force visual refresh of flat bar (recalculate state + layout + apply overlays + update text)
        local flatBar = _G.XPC_FlatXPBar
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
        
        -- Force visual refresh of legacy bar (recalculate state + layout + apply overlays + update text)
        local legacyBar = _G.XPC_LegacyXPBar
        if legacyBar and legacyBar:IsShown() and legacyBar.Bar then
            if legacyBar.Bar.UpdateBarOverlayColors then
                legacyBar.Bar:UpdateBarOverlayColors()
            end
            if legacyBar.Bar.UpdateTextVisibility then
                legacyBar.Bar:UpdateTextVisibility()
            end
            if legacyBar.Bar.UpdateAllText then
                legacyBar.Bar:UpdateAllText()
            end
        end
    end

    if key == "showLevelTimeText" or key == "showSessionTimeText" then
        local session = Addon.db.sessionData
        if session and (session.lastTimePlayedRequest or 0) == 0 and (Addon.db.showLevelTimeText or Addon.db.showSessionTimeText) then
            if TimePlayedService and TimePlayedService.RequestTimePlayed then
                TimePlayedService:RequestTimePlayed()
            end
        end
    end

    -- Options that affect stats display
    local statsOptions = {
        "showXPPerHourText", "showLevelTimeText", "showSessionTimeText",
        "showQuestXP", "abbreviateNumbers",
        "showPercentage", "showRemainingXP"
    }
    
    local needsStatsRefresh = false
    for _, optionKey in ipairs(statsOptions) do
        if key == optionKey then
            needsStatsRefresh = true
            break
        end
    end
    
    if needsStatsRefresh then
        local stats = Addon.App.Features and Addon.App.Features.stats
        if stats and stats.Update then
            stats:Update()
        elseif Addon.UI.Views and Addon.UI.Views.Stats and Addon.UI.Views.Stats.Update then
            Addon.UI.Views.Stats:Update()
        end
    end

    if key == "hideBlizzardBar" then
        if Addon.UI.Views and Addon.UI.Views.XPBar and Addon.UI.Views.XPBar.Initialize then
            Addon.UI.Views.XPBar:Initialize(Addon.App.Features and Addon.App.Features.xpbar)
        end
    end
end

function Config:ShowHelp()
    print("|cFF00FF00" .. L("ADDON_NAME") .. " Commands:|r")
    print("  |cFFFFD700/xpc|r or |cFFFFD700/xpc help|r - Show this help")
    print("  |cFFFFD700/xpc stats|r - Toggle stats window")
    print("    (Ctrl + Click the XP bar for quick access)")
    print("    (Alt + Click the XP bar to open options)")
    print("  |cFFFFD700/xpc options|r - Open the in-game options panel")
    print("     Customize colors and features from the options panel.")
    print("  |cFFFFD700/xpc reset|r - Reset all settings to defaults")
    print("  |cFFFFD700/xpc resetstats|r - Clear all tracked statistics")
    print("  |cFFFFD700/xpc style <none|legacy|flat>|r - Change bar style")
end

function Config:OpenOptions()
    local optionsFeature = Addon.App.Features and Addon.App.Features.options
    if optionsFeature and optionsFeature.Open then
        optionsFeature:Open()
        return
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.Open then
        optionsView:Open()
    else
        print("|cFFFFD700" .. L("ADDON_NAME") .. ":|r " .. L("MSG_OPTIONS_UNAVAILABLE"))
    end
end

local function cloneDefaults()
    local copy = {}
    for key, value in pairs(defaults) do
        copy[key] = Utils.Clone(value)
    end
    return copy
end

function Config:Reset()
    local copy = cloneDefaults()
    for key, value in pairs(copy) do
        Addon.db[key] = value
    end

    -- Use XPBarController's ResetToDefaults instead
    local xpBarController = Addon.App.Features and Addon.App.Features.xpbar
    if xpBarController and xpBarController.ResetToDefaults then
        xpBarController:ResetToDefaults()
    end

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

    local stats = Addon.App.Features and Addon.App.Features.stats
    if stats and stats.Update then
        stats:Update()
    elseif Addon.UI.Views and Addon.UI.Views.Stats and Addon.UI.Views.Stats.Update then
        Addon.UI.Views.Stats:Update()
    end

    if TimePlayedService and TimePlayedService.ClearRequest then
        TimePlayedService:ClearRequest()
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.Refresh then
        optionsView:Refresh()
    end

    Utils.Print(L("MSG_SETTINGS_RESET"))
end

function Config:ResetStats()
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
            xpAtStart = UnitXP("player"),
        },
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
        lastUpdate = time(),
    }

    if TimePlayedService and TimePlayedService.ClearRequest then
        TimePlayedService:ClearRequest()
    end

    Addon.state.requestingTimePlayed = false
    Addon.state.snapshot = nil

    local stats = Addon.App.Features and Addon.App.Features.stats
    if stats and stats.Update then
        stats:Update()
    elseif Addon.UI.Views and Addon.UI.Views.Stats and Addon.UI.Views.Stats.Update then
        Addon.UI.Views.Stats:Update()
    end

    local xpbar = Addon.App.Features and Addon.App.Features.xpbar
    if xpbar and xpbar.Update then
        xpbar:Update()
    elseif Addon.UI.Views and Addon.UI.Views.XPBar and Addon.UI.Views.XPBar.Update then
        Addon.UI.Views.XPBar:Update()
    end

    local optionsView = Addon.UI.Views and Addon.UI.Views.Options
    if optionsView and optionsView.Refresh then
        optionsView:Refresh()
    end

    Utils.Print(L("MSG_SETTINGS_RESET"))
end

Addon.App.Config.Config = Config
return Config
