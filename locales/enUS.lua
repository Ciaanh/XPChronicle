local ADDON_NAME = "XPBarEnhanced"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)

if not L then
    return
end

-- ============================================================================
-- ADDON GENERAL
-- ============================================================================
L["ADDON_NAME"] = "XP Bar Enhanced"
L["ADDON_LOADED"] = "Loaded!"

-- ============================================================================
-- TOOLTIPS
-- ============================================================================
L["TT_EXPERIENCE"] = "Experience"
L["TT_CURRENT"] = "Current"
L["TT_REMAINING"] = "Remaining"
L["TT_AMOUNT"] = "Amount"
L["TT_TO_LEVEL"] = "%s to level %d"
L["TT_RESTED"] = "Rested"
L["TT_RESTED_XP"] = "Rested XP"
L["TT_QUEST_XP"] = "Quest XP"
L["TT_STATUS"] = "Status"
L["TT_FULLY_RESTED"] = "Fully Rested"
L["TT_RESTED"] = "Rested"
L["TT_RESTED_TO_LEVEL"] = "Rested (to level)"
L["TT_RESTED_LOW_WARNING"] = "Almost out of rest! Visit an inn or city to rest."
L["TT_NORMAL"] = "Normal"
L["TT_QUEST_XP_AVAILABLE"] = "Quest XP Available"
L["TT_COMPLETE"] = "Complete"
L["TT_INCOMPLETE"] = "Incomplete"
L["TT_TOTAL"] = "Total"
L["TT_QUESTS"] = "%d quests"
L["TT_QUEST"] = "%d quest"
L["TT_SESSION"] = "Session"
L["TT_GAINED"] = "Gained"
L["TT_TIME"] = "Time"
L["TT_XP_PER_HOUR"] = "XP/Hour"
L["TT_TIME_TO_LEVEL"] = "Time to level"
L["TT_CALCULATING"] = "Calculating..."
L["TT_OVER_99_HOURS"] = "99+ hours"
L["TT_SESSION_XP_GAINED"] = "Session XP Gained"
L["TT_SESSION_TIME"] = "Session Time"
L["TT_SESSION_STATS"] = "Session Stats"
L["TT_LEVEL_TIME"] = "Level Time"
L["TT_QUEST_XP_COMPLETE"] = "Completed Quest XP"
L["TT_QUEST_XP_INCOMPLETE"] = "Quest XP (Incomplete)"

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================
-- Current options in OptionsMetadata
L["OPT_QUEST_XP"] = "Quest XP display"
L["OPT_QUEST_XP_DESC"] = "Display quest XP overlays and tooltip breakdown."
L["OPT_SHOW_COMPLETE_OVERLAY"] = "Show completed quest overlay"
L["OPT_SHOW_COMPLETE_OVERLAY_DESC"] = "Display the orange overlay showing XP from completed quests ready to turn in."
L["OPT_SHOW_INCOMPLETE_OVERLAY"] = "Show incomplete quest overlay"
L["OPT_SHOW_INCOMPLETE_OVERLAY_DESC"] =
    "Display the yellow semi-transparent overlay showing XP from incomplete quests (doesn't reduce bar width)."
L["OPT_PERCENTAGE"] = "Show percentage"
L["OPT_PERCENTAGE_DESC"] = "Display current percentage progress as text overlaid on the XP bar itself."
L["OPT_QUEST_PERCENT"] = "Include quest XP in percentage"
L["OPT_QUEST_PERCENT_DESC"] =
    "Show percentage with quest XP included. Example: '75% (80%)' where 80% includes completed quest XP ready to turn in. Requires 'Show percentage ON the bar' to be enabled."
L["OPT_LEVEL_TEXT"] = "Show level"
L["OPT_LEVEL_TEXT_DESC"] = "Display your current level number as text overlaid on the left side of the XP bar."
L["OPT_XP_TEXT"] = "Show XP amounts"
L["OPT_XP_TEXT_DESC"] = "Display current/max XP numbers as text overlaid on the XP bar itself (e.g., '1250/5000')."
L["OPT_REMAINING_XP"] = "Show remaining XP"
L["OPT_REMAINING_XP_DESC"] = "Display how much XP is needed to level as text beneath the XP bar."
L["OPT_XP_HOUR"] = "Show XP/hour"
L["OPT_XP_HOUR_DESC"] = "Display experience gained per hour as text beneath the XP bar."
L["OPT_LEVEL_TIME"] = "Show level time"
L["OPT_LEVEL_TIME_DESC"] = "Display time spent on current level as text beneath the XP bar."
L["OPT_SESSION_TIME"] = "Show session time"
L["OPT_SESSION_TIME_DESC"] = "Display time played this session as text beneath the XP bar."
L["OPT_TIME_TO_LEVEL"] = "Show time to next level"
L["OPT_TIME_TO_LEVEL_DESC"] =
    "Display estimated time remaining to reach next level (based on current XP/hour rate) as text beneath the XP bar."
L["OPT_ABBREVIATE_NUMBERS"] = "Abbreviate numbers"
L["OPT_ABBREVIATE_NUMBERS_DESC"] = "Use abbreviated number format (K, M, B) instead of full numbers in all displays."
L["OPT_SHOW_AT_MAX"] = "Show bar at max level"
L["OPT_SHOW_AT_MAX_DESC"] = "Keep the custom XP bar visible even at maximum level."
L["OPT_HIDE_DEFAULT"] = "Hide default XP bar"
L["OPT_HIDE_DEFAULT_DESC"] = "Hide Blizzard's default experience bar when the addon loads."

-- Subsection headers
L["OPT_TEXT_ON_BAR"] = "Text ON the Bar"
L["OPT_TEXT_BELOW_BAR"] = "Text BELOW the Bar"

-- Options
L["OPT_BAR_STYLE"] = "Bar Style"
L["OPT_BAR_STYLE_DESC"] =
    "Choose which XP bar to display: None (Blizzard only), Legacy (Blizzard-style replacement), or Flat (Draggable custom bar)."
L["OPT_BAR_STYLE_NONE"] = "None (Blizzard only)"
L["OPT_BAR_STYLE_LEGACY"] = "Legacy (Blizzard-style)"
L["OPT_BAR_STYLE_FLAT"] = "Flat (Custom draggable)"
L["OPT_HIDE_BLIZZARD_BAR"] = "Hide Blizzard bar in Flat mode"
L["OPT_HIDE_BLIZZARD_BAR_DESC"] = "When using Flat bar style, also hide the Blizzard XP bar. Uncheck to see both bars."
L["OPT_BAR_LOCKED"] = "Lock bar position"
L["OPT_BAR_LOCKED_DESC"] = "Prevent the Flat bar from being moved with Shift+Drag. Applies only to Flat bar style."
L["OPT_RESET_BAR_POSITION"] = "Reset Bar Position"
L["OPT_RESET_BAR_POSITION_DESC"] = "Reset the Flat bar to its default position at the bottom center of the screen."
L["OPT_RESET_SETTINGS"] = "Reset Settings"
L["OPT_RESET_STATS"] = "Reset Statistics"

-- Text Display Section Headers
L["OPT_TEXT_ON_BAR"] = "Text ON the Bar"
L["OPT_TEXT_BELOW_BAR"] = "Text BELOW the Bar"
L["OPT_TEXT_LEFT"] = "Left"
L["OPT_TEXT_MIDDLE"] = "Middle"
L["OPT_TEXT_RIGHT"] = "Right"

-- Animation options
L["OPT_ENABLE_ANIMATIONS"] = "Enable animations"
L["OPT_ENABLE_ANIMATIONS_DESC"] = "Enable smooth fill animations when XP changes."
L["OPT_ANIMATION_EASING"] = "Animation easing"
L["OPT_ANIMATION_EASING_DESC"] = "The animation curve style (easeOut recommended for natural feel)."
L["OPT_EASING_LINEAR"] = "Linear"
L["OPT_EASING_EASE_IN"] = "Ease In"
L["OPT_EASING_EASE_OUT"] = "Ease Out"
L["OPT_EASING_EASE_IN_OUT"] = "Ease In/Out"
L["OPT_FLASH_ON_GAIN"] = "Flash on XP gain"
L["OPT_FLASH_ON_GAIN_DESC"] = "Briefly flash the bar when XP is gained."
L["OPT_PAUSE_ON_HOVER"] = "Pause animation on hover"
L["OPT_PAUSE_ON_HOVER_DESC"] = "Pause the fill animation when hovering over the bar."

-- Color options
L["COLOR_XP_BAR"] = "XP Bar Fill"
L["COLOR_XP_BAR_DESC"] = "Primary color of the experience bar."
L["COLOR_XP_BAR_RESTED"] = "XP Bar Fill (Rested)"
L["COLOR_XP_BAR_RESTED_DESC"] = "Color of the experience bar when you are rested."
L["COLOR_QUEST_COMPLETE"] = "Completed Quest Overlay"
L["COLOR_QUEST_COMPLETE_DESC"] = "Color of XP earned from completed quests."
L["COLOR_QUEST_INCOMPLETE"] = "Incomplete Quest Overlay"
L["COLOR_QUEST_INCOMPLETE_DESC"] = "Color of XP from quests still in progress."
L["COLOR_RESTED"] = "Rested XP Overlay"
L["COLOR_RESTED_DESC"] = "Color of the rested XP segment of the bar."

-- ============================================================================
-- MESSAGES
-- ============================================================================
L["MSG_OPTION_ENABLED"] = "%s enabled"
L["MSG_OPTION_DISABLED"] = "%s disabled"
L["MSG_COLOR_SET"] = "%s color set to #%s"
L["MSG_COLOR_RESET"] = "%s color reset to default"
L["MSG_UNKNOWN_COMMAND"] = "Unknown command:"
L["MSG_STATS_UNAVAILABLE"] = "Stats feature is unavailable."
L["MSG_OPTIONS_UNAVAILABLE"] = "Options panel is unavailable."
L["MSG_RESET_UNAVAILABLE"] = "Unable to reset settings."
L["MSG_RESET_STATS_UNAVAILABLE"] = "Unable to reset statistics."
L["MSG_SETTINGS_RESET"] = "Settings reset to defaults"

-- ============================================================================
-- ERRORS
-- ============================================================================
L["ERR_UNKNOWN_COLOR_TARGET"] = "Unknown color target."
L["ERR_INVALID_COLOR"] = "Invalid color. Use a hex value such as 4C63FF or 4C63FFFF."
L["ERR_NO_DEFAULT_COLOR"] = "No default color available."
L["ERR_INIT_FAILED"] = "Initialization failed: missing core modules."
L["ERR_EVENT_HANDLER_FAILED"] = "Event %s handler failed: %s"
