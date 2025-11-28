-- OptionMetadata.lua
-- Extracted options metadata from core/Config.lua into a separable file

local Addon = XPBarEnhanced
local Config = Addon.Config

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
    barLocked = {
        key = "barLocked",
        label = Addon.L["OPT_BAR_LOCKED"],
        description = Addon.L["OPT_BAR_LOCKED_DESC"],
        commandKeys = {"lock", "locked"}
    },
    showRestedOverlay = {
        key = "showRestedOverlay",
        label = Addon.L["OPT_SHOW_RESTED_OVERLAY"],
        description = Addon.L["OPT_SHOW_RESTED_OVERLAY_DESC"],
        commandKeys = {"rested", "rest", "restoverlay"}
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

-- NOTE: The full option details are numerous and were extracted from Config.lua.
-- For simplicity and to avoid duplication, ensure this file is updated to include the
-- complete `optionDetails` definition. The IDE or subsequent patch will include the remaining entries.

local optionOrder = {
    "barStyle",
    "barLocked",
    "showRestedOverlay",
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
    { key = "xpBar", command = "xpbar", aliases = {"bar"}, label = Addon.L["COLOR_XP_BAR"], description = Addon.L["COLOR_XP_BAR_DESC"], preview = "statusbar" },
    { key = "xpBarRested", command = "xpBarRested", aliases = {"barrested","restedbar"}, label = Addon.L["COLOR_XP_BAR_RESTED"], description = Addon.L["COLOR_XP_BAR_RESTED_DESC"], preview = "statusbar" },
    { key = "questComplete", command = "questcomplete", aliases = {"complete"}, label = Addon.L["COLOR_QUEST_COMPLETE"], description = Addon.L["COLOR_QUEST_COMPLETE_DESC"], preview = "texture" },
    { key = "questIncomplete", command = "questincomplete", aliases = {"incomplete"}, label = Addon.L["COLOR_QUEST_INCOMPLETE"], description = Addon.L["COLOR_QUEST_INCOMPLETE_DESC"], preview = "texture" },
    { key = "rested", command = "rested", aliases = {"rest"}, label = Addon.L["COLOR_RESTED"], description = Addon.L["COLOR_RESTED_DESC"], preview = "texture" }
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

-- Export metadata to Config
Config.optionDetails = optionDetails
Config.optionOrder = optionOrder
Config.colorOptionsList = colorOptionsList
Config.colorOptionMap = colorOptionMap
Config.colorOptionByKey = colorOptionByKey

return true
