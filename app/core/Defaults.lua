local Addon = XPBarEnhanced
Addon.App.Core = Addon.App.Core or {}

local defaults = {
    -- Bar Style Selection
    barStyle = "legacy",  -- "none", "legacy", "flat"
    hideBlizzardBar = true,  -- Only applies when barStyle = "flat" - allows Blizzard bar to show alongside
    barLocked = false,  -- Only applies when barStyle = "flat" - prevents accidental dragging
    
    -- Text Display Settings
    showPercentage = true,
    showQuestXP = true,
    showQuestPercent = true,  -- Show quest XP in percentage text (e.g., "75% (80%)")
    showXPPerHourText = true,
    showLevelTimeText = true,
    showSessionTimeText = true,
    showTimeToLevelText = true,
    abbreviateNumbers = true,
    showRemainingXP = true,
    showBarAtMaxLevel = false,
    
    -- Individual Text Element Toggles
    showLevelText = true,  -- On-bar level text
    showXPText = true,     -- On-bar XP text
    
    -- Quest overlay settings
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    
    -- Animation Settings (flattened from nested structure for backward compatibility)
    enableAnimations = true,
    animationSpeed = 1.0,
    animationEasing = "easeOut",
    flashOnGain = true,
    pauseOnHover = true,
    
    -- Level-Up Celebration Settings
    levelUpCelebration = true,
    celebrationSparkles = false,  -- Disabled by default for performance
    celebrationSound = true,
    celebrationSpeed = "normal",  -- "fast", "normal", "slow"
    
    -- Auto-Hide at Max Level
    maxLevelBehavior = "always_show",  -- "always_show", "auto_hide", "show_on_hover", "minimal_mode"
    
    -- Fade In/Out Effects
    fadeWhenInactive = false,
    fadeDelay = 5.0,  -- seconds
    idleOpacity = 0.0,  -- 0-100, 0 = fully hidden
    fadeInSpeed = 0.3,  -- seconds
    fadeOutSpeed = 0.5,  -- seconds
    
    -- Font Customization
    textFontFace = "Fonts\\FRIZQT__.TTF",
    textFontSize = 12,
    textFontOutline = "NONE",  -- "NONE", "OUTLINE", "THICKOUTLINE"
    textFontShadow = false,
    
    -- Color Settings
    colors = {
        -- XP Bar and Rested colors (Flat bar only - Legacy uses fixed Blizzard atlases)
        xpBar = { r = 0.58, g = 0.0, b = 0.55, a = 1 },         -- Magenta/Purple (unrested)
        xpBarRested = { r = 0.0, g = 0.44, b = 1.0, a = 1 },    -- Blue (rested state)
        rested = { r = 0.07, g = 0.58, b = 0.95, a = 0.5 },     -- Light Blue (rested overlay)
        
        -- Quest overlay colors (both Flat and Legacy bars)
        questComplete = { r = 1.0, g = 0.65, b = 0.0, a = 0.85 },       -- Bright Gold/Orange - rewards ready!
        questIncomplete = { r = 0.5, g = 1.0, b = 0.2, a = 0.85 },      -- Bright Lime Green - progress in action
    },
    barPosition = {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

defaults.xpBarColor = defaults.colors.xpBar

Addon.defaults = defaults
Addon.App.Core.Defaults = {
    defaults = defaults,
}
