---@class EventTypes
---Event Type Definitions - All event types used in XP Chronicle
local XPC_EventTypes = {
    -- XP Events
    XP_CHANGED = "XPC_XP_CHANGED",           -- XP amount changed (gain or loss)
    XP_GAINED = "XPC_XP_GAINED",             -- XP was gained (subset of XP_CHANGED)
    LEVEL_UP = "XPC_LEVEL_UP",               -- Player leveled up
    RESTED_CHANGED = "XPC_RESTED_CHANGED",   -- Rested status changed
    MAX_XP_CHANGED = "XPC_MAX_XP_CHANGED",   -- Max XP for level changed
    
    -- Session Events
    SESSION_STARTED = "XPC_SESSION_STARTED", -- New session started
    SESSION_UPDATED = "XPC_SESSION_UPDATED", -- Session stats updated
    SESSION_ENDED = "XPC_SESSION_ENDED",     -- Session ended (logout)
    
    -- UI Events
    BAR_STYLE_CHANGED = "XPC_BAR_STYLE_CHANGED", -- User changed bar style
    COLORS_CHANGED = "XPC_COLORS_CHANGED",       -- User changed color settings
    TEXT_SETTINGS_CHANGED = "XPC_TEXT_SETTINGS_CHANGED", -- Font/text changed
    
    -- Config Events
    CONFIG_CHANGED = "XPC_CONFIG_CHANGED",   -- Any config setting changed
    
    -- Quest Events
    QUEST_XP_UPDATED = "XPC_QUEST_XP_UPDATED", -- Quest XP data updated
}

---Event payload schemas (for documentation and validation)
---These describe the structure of eventData for each event type
local EventSchemas = {
    XP_CHANGED = {
        currentXP = "number",      -- Current XP amount
        maxXP = "number",          -- XP required for next level
        previousXP = "number",     -- XP before change
        delta = "number",          -- Amount changed (+/-)
        isRested = "boolean",      -- Is player rested
        level = "number",          -- Current level
    },
    
    XP_GAINED = {
        amount = "number",         -- XP gained
        currentXP = "number",      -- New current XP
        maxXP = "number",          -- Max XP
        isRested = "boolean",      -- Was rested bonus applied
        restedBonus = "number",    -- Amount of rested bonus
        source = "string",         -- Source: "quest", "kill", "gather", etc. [optional]
    },
    
    LEVEL_UP = {
        newLevel = "number",       -- Level reached
        previousLevel = "number",  -- Level before
        timestamp = "number",      -- Time of level-up
        totalTimePlayed = "number", -- Total time played [optional]
    },
    
    RESTED_CHANGED = {
        isRested = "boolean",      -- New rested state
        restedXP = "number",       -- Amount of rested XP
        wasRested = "boolean",     -- Previous state
    },
    
    MAX_XP_CHANGED = {
        newMaxXP = "number",       -- New max XP value
        previousMaxXP = "number",  -- Previous max XP value
        level = "number",          -- Current level
    },
    
    SESSION_STARTED = {
        startTime = "number",      -- Session start timestamp
        level = "number",          -- Starting level
        currentXP = "number",      -- Starting XP
    },
    
    SESSION_UPDATED = {
        duration = "number",       -- Session duration (seconds)
        xpGained = "number",       -- XP gained this session
        levelsGained = "number",   -- Levels gained
        xpPerHour = "number",      -- XP per hour rate
        startTime = "number",      -- Session start timestamp
    },
    
    SESSION_ENDED = {
        duration = "number",       -- Total session duration
        xpGained = "number",       -- Total XP gained
        levelsGained = "number",   -- Total levels gained
        endTime = "number",        -- Session end timestamp
    },
    
    BAR_STYLE_CHANGED = {
        newStyle = "string",       -- Style ID (e.g., "animated")
        previousStyle = "string",  -- Previous style ID
    },
    
    COLORS_CHANGED = {
        setting = "string",        -- Which color setting changed
        value = "table",           -- New color {r, g, b, a}
    },
    
    TEXT_SETTINGS_CHANGED = {
        setting = "string",        -- Which text setting changed
        value = "any",             -- New value
    },
    
    CONFIG_CHANGED = {
        key = "string",            -- Config key that changed
        value = "any",             -- New value
        previousValue = "any",     -- Old value
    },
    
    QUEST_XP_UPDATED = {
        totalQuestXP = "number",   -- Total quest XP available
        completeQuests = "number", -- XP from complete quests
        incompleteQuests = "number", -- XP from incomplete quests
        questCount = "number",     -- Number of quests tracked
    },
}

-- Register with addon namespace
XPChronicle = XPChronicle or {}
XPChronicle.App = XPChronicle.App or {}
XPChronicle.App.Core = XPChronicle.App.Core or {}
XPChronicle.App.Core.EventTypes = XPC_EventTypes
XPChronicle.App.Core.EventSchemas = EventSchemas
