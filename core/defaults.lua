-- defaults.lua
-- Extracted default configuration values for XPBarEnhanced

local Addon = XPBarEnhanced

local defaults = {
    -- Bar Style Selection
    barStyle = "classic",
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
    showBarAtMaxLevel = false,
    showLevelText = true,
    showXPText = true,
    -- Overlays settings
    wRestedOverlay = true,
    -- Quest overlay settings
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    -- Animation Settings
    enableAnimations = true,
    animationSpeed = 1.0,
    animationEasing = "easeOut",
    flashOnGain = true,
    pauseOnHover = true,
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
        classic = {point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 12},
        flat = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0},
        circular = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0}
    }
}

-- Backward compatibility
defaults.xpBarColor = defaults.colors.xpBar

Addon.defaults = defaults

return defaults
