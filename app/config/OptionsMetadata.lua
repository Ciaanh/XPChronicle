local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Config = Addon.App.Config or {}

local metadata = {}
local L = function(key, ...) return Addon.L and Addon.L(key, ...) or key end

metadata.optionDetails = {
    barStyle = {
        key = "barStyle",
        type = "dropdown",
        label = L("OPT_BAR_STYLE"),
        description = L("OPT_BAR_STYLE_DESC"),
        options = {
            { value = "none", label = L("OPT_BAR_STYLE_NONE") },
            { value = "legacy", label = L("OPT_BAR_STYLE_LEGACY") },
            { value = "flat", label = L("OPT_BAR_STYLE_FLAT") },
        },
        commandKeys = { "style", "mode", "barstyle" },
    },
    hideBlizzardBar = {
        key = "hideBlizzardBar",
        label = L("OPT_HIDE_BLIZZARD_BAR"),
        description = L("OPT_HIDE_BLIZZARD_BAR_DESC"),
        commandKeys = { "hideblizzard", "blizzardbar" },
    },
    barLocked = {
        key = "barLocked",
        label = L("OPT_BAR_LOCKED"),
        description = L("OPT_BAR_LOCKED_DESC"),
        commandKeys = { "lock", "locked" },
    },
    showQuestXP = {
        key = "showQuestXP",
        label = L("OPT_QUEST_XP"),
        description = L("OPT_QUEST_XP_DESC"),
        commandKeys = { "questxp", "quest" },
    },
    showCompleteQuestOverlay = {
        key = "showCompleteQuestOverlay",
        label = L("OPT_SHOW_COMPLETE_OVERLAY"),
        description = L("OPT_SHOW_COMPLETE_OVERLAY_DESC"),
        commandKeys = { "completeoverlay" },
    },
    showIncompleteQuestOverlay = {
        key = "showIncompleteQuestOverlay",
        label = L("OPT_SHOW_INCOMPLETE_OVERLAY"),
        description = L("OPT_SHOW_INCOMPLETE_OVERLAY_DESC"),
        commandKeys = { "incompleteoverlay" },
    },
    showPercentage = {
        key = "showPercentage",
        label = L("OPT_PERCENTAGE"),
        description = L("OPT_PERCENTAGE_DESC"),
        commandKeys = { "percentage" },
    },
    showQuestPercent = {
        key = "showQuestPercent",
        label = L("OPT_QUEST_PERCENT"),
        description = L("OPT_QUEST_PERCENT_DESC"),
        commandKeys = { "questpercent", "questpct" },
    },
    showLevelText = {
        key = "showLevelText",
        label = L("OPT_LEVEL_TEXT"),
        description = L("OPT_LEVEL_TEXT_DESC"),
        commandKeys = { "leveltext" },
    },
    showXPText = {
        key = "showXPText",
        label = L("OPT_XP_TEXT"),
        description = L("OPT_XP_TEXT_DESC"),
        commandKeys = { "xptext" },
    },
    showRemainingXP = {
        key = "showRemainingXP",
        label = L("OPT_REMAINING_XP"),
        description = L("OPT_REMAINING_XP_DESC"),
        commandKeys = { "remaining" },
    },
    showXPPerHourText = {
        key = "showXPPerHourText",
        label = L("OPT_XP_HOUR"),
        description = L("OPT_XP_HOUR_DESC"),
        commandKeys = { "xphour" },
    },
    showLevelTimeText = {
        key = "showLevelTimeText",
        label = L("OPT_LEVEL_TIME"),
        description = L("OPT_LEVEL_TIME_DESC"),
        commandKeys = { "leveltime" },
    },
    showSessionTimeText = {
        key = "showSessionTimeText",
        label = L("OPT_SESSION_TIME"),
        description = L("OPT_SESSION_TIME_DESC"),
        commandKeys = { "sessiontime" },
    },
    showTimeToLevelText = {
        key = "showTimeToLevelText",
        label = L("OPT_TIME_TO_LEVEL"),
        description = L("OPT_TIME_TO_LEVEL_DESC"),
        commandKeys = { "timetolevel", "ttl" },
    },
    showBarAtMaxLevel = {
        key = "showBarAtMaxLevel",
        label = L("OPT_SHOW_AT_MAX"),
        description = L("OPT_SHOW_AT_MAX_DESC"),
        commandKeys = { "showmax" },
    },
    abbreviateNumbers = {
        key = "abbreviateNumbers",
        label = L("OPT_ABBREVIATE_NUMBERS"),
        description = L("OPT_ABBREVIATE_NUMBERS_DESC"),
        commandKeys = { "abbreviate" },
    },
    enableAnimations = {
        key = "enableAnimations",
        label = L("OPT_ENABLE_ANIMATIONS"),
        description = L("OPT_ENABLE_ANIMATIONS_DESC"),
        commandKeys = { "animations", "animate" },
    },
    animationEasing = {
        key = "animationEasing",
        type = "dropdown",
        label = L("OPT_ANIMATION_EASING"),
        description = L("OPT_ANIMATION_EASING_DESC"),
        options = {
            { value = "linear", label = L("OPT_EASING_LINEAR") },
            { value = "easeIn", label = L("OPT_EASING_EASE_IN") },
            { value = "easeOut", label = L("OPT_EASING_EASE_OUT") },
            { value = "easeInOut", label = L("OPT_EASING_EASE_IN_OUT") },
        },
        commandKeys = { "easing" },
    },
    flashOnGain = {
        key = "flashOnGain",
        label = L("OPT_FLASH_ON_GAIN"),
        description = L("OPT_FLASH_ON_GAIN_DESC"),
        commandKeys = { "flash" },
    },
    pauseOnHover = {
        key = "pauseOnHover",
        label = L("OPT_PAUSE_ON_HOVER"),
        description = L("OPT_PAUSE_ON_HOVER_DESC"),
        commandKeys = { "pause", "pausehover" },
    },
}

metadata.optionOrder = {
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
    "pauseOnHover",
}

metadata.colorOptionsList = {
    {
        key = "xpBar",
        command = "xpbar",
        aliases = { "bar" },
        label = L("COLOR_XP_BAR"),
        description = L("COLOR_XP_BAR_DESC"),
        preview = "statusbar",
    },
    {
        key = "xpBarRested",
        command = "xpBarRested",
        aliases = { "barrested", "restedbar" },
        label = L("COLOR_XP_BAR_RESTED"),
        description = L("COLOR_XP_BAR_RESTED_DESC"),
        preview = "statusbar",
    },
    {
        key = "questComplete",
        command = "questcomplete",
        aliases = { "complete" },
        label = L("COLOR_QUEST_COMPLETE"),
        description = L("COLOR_QUEST_COMPLETE_DESC"),
        preview = "texture",
    },
    {
        key = "questIncomplete",
        command = "questincomplete",
        aliases = { "incomplete" },
        label = L("COLOR_QUEST_INCOMPLETE"),
        description = L("COLOR_QUEST_INCOMPLETE_DESC"),
        preview = "texture",
    },
    {
        key = "rested",
        command = "rested",
        aliases = { "rest" },
        label = L("COLOR_RESTED"),
        description = L("COLOR_RESTED_DESC"),
        preview = "statusbar",
    },
}

Addon.App.Config.OptionsMetadata = metadata
return metadata
