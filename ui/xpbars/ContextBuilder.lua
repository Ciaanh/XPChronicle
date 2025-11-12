-- XP Bar Enhanced - Context Builder (v2)
-- Standalone utility module for building immutable context objects
-- Integrates session calculation methods (duplicated from core/Session.lua)
-- NO DEPENDENCIES on existing Session, Database, or other core modules

-------------------------------------------------------------------
-- STATIC CONFIGURATION (SHARED)
-------------------------------------------------------------------

--- Build fresh static configuration from database
--- Called each time a context is built to ensure latest settings
--- @return table staticConfig Fresh configuration with current settings
local function BuildDBConfig()
	local AddonGlobal = _G["XPBarEnhanced"]
	local db = AddonGlobal and AddonGlobal.db

	-- Helper to get boolean from db with default fallback
	local function getBool(key, default)
		local dbValue = db and db[key]
		if dbValue ~= nil then
			if default == true then
				return dbValue ~= false
			else
				return dbValue == true
			end
		else
			return default == true
		end
	end

	return {
		-- Display flags (13 fields)
		showXPText = getBool("showXPText", true),
		showLevelText = getBool("showLevelText", true),
		showPercentage = getBool("showPercentage", true),
		showQuestXP = getBool("showQuestXP", true),
		showCompleteQuestOverlay = getBool("showCompleteQuestOverlay", true),
		showIncompleteQuestOverlay = getBool("showIncompleteQuestOverlay", false),
		showRestedOverlay = getBool("showRestedOverlay", true),
		showExhaustionTick = getBool("showExhaustionTick", true),
		showSessionTimeText = getBool("showSessionTimeText", true),
		showLevelTimeText = getBool("showLevelTimeText", true),
		showXPPerHourText = getBool("showXPPerHourText", true),
		showTimeToLevelText = getBool("showTimeToLevelText", true),
		showRemainingXP = getBool("showRemainingXP", false),
		showQuestPercent = getBool("showQuestPercent", false),
		-- Configuration values (3 fields)
		percentDecimals = (db and db.percentDecimals) or 1,
		abbreviateNumbers = getBool("abbreviateNumbers", true),
		flashOnGain = getBool("flashOnGain", true)
	}
end

-------------------------------------------------------------------
-- GLOBAL CONTEXT BUILDER
-------------------------------------------------------------------

---@class XPBarContextBuilder
XPBarContextBuilder = {}

local ContextBuilder = XPBarContextBuilder

-------------------------------------------------------------------
-- INTERNAL HELPERS (factorised common computations)
-------------------------------------------------------------------

-- Retrieve core player XP/rested/level state
function ContextBuilder.GetCoreState()
	local currentXP = UnitXP("player") or 0
	local xpMax = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isResting = IsResting() -- Player is in a resting area (inn/city)
	local hasRestedXP = restedXP > 0 -- Player has rested XP bonus available
	local isFullyRested = restedXP >= (1.5 * xpMax)
	return {
		currentXP = currentXP,
		xpMax = xpMax,
		level = level,
		restedXP = restedXP,
		isResting = isResting,
		hasRestedXP = hasRestedXP,
		isFullyRested = isFullyRested
	}
end

-- Retrieve quest XP breakdown (best-effort)
function ContextBuilder.GetQuestXP()
	local completeQuestXP = 0
	local incompleteQuestXP = 0

	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	end

	return completeQuestXP, incompleteQuestXP
end

-------------------------------------------------------------------
-- CONTEXT MANIPULATION HELPERS
-------------------------------------------------------------------

--- Extend an existing context with additional fields
--- Creates a new context table by copying base and adding new fields
--- @param baseContext table The base context to extend
--- @param additions table Table of key-value pairs to add
--- @return table extendedContext New context with all fields
function ContextBuilder.ExtendContext(baseContext, additions)
	local extended = {}

	-- Copy all fields from base context
	if baseContext then
		for k, v in pairs(baseContext) do
			extended[k] = v
		end
	end

	-- Add/override with new fields
	if additions then
		for k, v in pairs(additions) do
			extended[k] = v
		end
	end

	return extended
end

--- Make a context table immutable using metatable protection
--- Make a context immutable and provide a Get() function for safe access
--- Uses a simple flattened structure with all values copied in
--- This avoids complex metatable chains that don't work reliably in WoW
--- @param eventData table Event-specific data
--- @param coreData table Core player state data
--- @return table immutableContext Context with Get() function
function ContextBuilder.MakeImmutable(eventData, coreData)
	-- Flatten all data into a single table (copy values, don't reference)
	local flatContext = BuildDBConfig()

	-- Copy core data (medium priority - overrides static)
	if coreData then
		for k, v in pairs(coreData) do
			flatContext[k] = v
		end
	end

	-- Copy event data (highest priority - overrides everything)
	if eventData then
		for k, v in pairs(eventData) do
			flatContext[k] = v
		end
	end

	-- Create immutable wrapper with Get() function
	local wrapper = {
		-- Public Get function for safe access
		Get = function(self, key, default)
			local value = flatContext[key]
			if value ~= nil then
				return value
			end
			return default
		end,
		-- Expose values directly for backward compatibility (but discourage modification)
		_data = flatContext
	}

	-- Use metatable only for direct field access (no complex chain)
	setmetatable(
		wrapper,
		{
			__index = function(t, k)
				-- Allow direct access for backward compatibility
				-- but prefer using Get() function
				return flatContext[k]
			end,
			__newindex = function(t, k, v)
				error(string.format("Attempt to modify immutable context field '%s'", tostring(k)), 2)
			end,
			__metatable = false
		}
	)

	return wrapper
end

-- Compute XP gained since last snapshot (handles level-up wrap-around)
function ContextBuilder.ComputeXPGained(currentXP, xpMax)
	local lastXP = ContextBuilder._lastXP or currentXP
	local lastMax = ContextBuilder._lastMaxXP or xpMax
	local xpGained = currentXP - lastXP
	if xpGained < 0 then
		-- Level-up occurred, XP wrapped around
		xpGained = lastMax - lastXP + currentXP
	end
	if xpGained < 0 then
		xpGained = 0
	end
	-- update last values for next computation
	ContextBuilder._lastXP = currentXP
	ContextBuilder._lastMaxXP = xpMax
	return xpGained, lastXP
end

-- Update session tracking with a gain and return session snapshot
function ContextBuilder.UpdateSessionWithGain(xpGained)
	-- ARCHITECTURE NOTE: sessionStart and sessionXP should persist across reloads
	-- Use Session service's sessionStart and gainedXP from saved variables
	local AddonGlobal = _G["XPBarEnhanced"]
	local sessionStart = time() -- Fallback if Session not available
	local sessionXP = 0 -- Fallback

	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session and session.sessionStart then
			sessionStart = session.sessionStart
		end
		-- Use Session service's persistent gainedXP instead of transient local counter
		if session and session.gainedXP then
			sessionXP = session.gainedXP
		end
	end

	local sessionDuration = time() - sessionStart

	-- Get realLevelTime from Session service for fallback calculation
	local realLevelTime = 0
	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session and session.realLevelTime then
			realLevelTime = session.realLevelTime
			-- Add elapsed time since last TIME_PLAYED_MSG for real-time accuracy
			if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
				local elapsed = time() - session.lastTimePlayedRequest
				realLevelTime = realLevelTime + elapsed
			end
		end
	end

	local currentXP = UnitXP("player") or 0
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)

	return sessionStart, sessionXP, sessionDuration, xpPerHour
end

-- Helper to build base context table
function ContextBuilder.BuildBaseContext(event, source, coreState, extras)
	-- Use explicit global reference to avoid nil issues
	local AddonGlobal = _G["XPBarEnhanced"]
	local db = AddonGlobal and AddonGlobal.db

	-- Helper to get boolean from db with default fallback
	local function getBool(key, default)
		local dbValue = db and db[key]

		if dbValue ~= nil then
			-- For defaults that are true: show unless explicitly disabled
			if default == true then
				-- For defaults that are false: hide unless explicitly enabled
				return dbValue ~= false
			else
				return dbValue == true
			end
		else
			return default == true
		end
	end

	local ctx = {
		event = event,
		timestamp = time(),
		source = source,
		currentXP = coreState.currentXP,
		xpMax = coreState.xpMax,
		remainingXP = coreState.xpMax - coreState.currentXP,
		level = coreState.level,
		restedXP = coreState.restedXP,
		isResting = coreState.isResting,
		hasRestedXP = coreState.hasRestedXP,
		isFullyRested = coreState.isFullyRested,
		-- Centralized display flags using ConfigHelper for consistency
		showXPText = getBool("showXPText", true),
		showLevelText = getBool("showLevelText", true),
		showPercentage = getBool("showPercentage", true),
		showQuestXP = getBool("showQuestXP", true),
		showCompleteQuestOverlay = getBool("showCompleteQuestOverlay", true),
		showIncompleteQuestOverlay = getBool("showIncompleteQuestOverlay", false),
		showRestedOverlay = getBool("showRestedOverlay", true),
		showExhaustionTick = getBool("showExhaustionTick", true),
		showSessionTimeText = getBool("showSessionTimeText", true),
		showLevelTimeText = getBool("showLevelTimeText", true),
		showXPPerHourText = getBool("showXPPerHourText", true),
		showTimeToLevelText = getBool("showTimeToLevelText", true),
		-- Configuration values
		percentDecimals = (db and db.percentDecimals) or 1,
		abbreviateNumbers = getBool("abbreviateNumbers", true),
		showRemainingXP = getBool("showRemainingXP", false),
		showQuestPercent = getBool("showQuestPercent", false)
	}

	if extras and type(extras) == "table" then
		for k, v in pairs(extras) do
			ctx[k] = v
		end
	end

	return ctx
end

--- Build minimal core context with only dynamic game state
--- Does NOT include display flags (use XPBarStaticConfig instead)
--- @param coreState table Core XP state from GetCoreState()
--- @return table coreContext Minimal context with 12 dynamic fields
function ContextBuilder.BuildCoreContext(coreState)
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	-- Get session data from Session service
	local AddonGlobal = _G["XPBarEnhanced"]
	local sessionStart = time()
	local sessionXP = 0
	local levelSeconds = 0

	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session then
			if session.sessionStart then
				sessionStart = session.sessionStart
			end
			if session.gainedXP then
				sessionXP = session.gainedXP
			end
			if session.realLevelTime and session.realLevelTime > 0 then
				levelSeconds = session.realLevelTime
				-- Add elapsed time since last TIME_PLAYED_MSG for real-time accuracy
				if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
					local elapsed = time() - session.lastTimePlayedRequest
					levelSeconds = levelSeconds + elapsed
				end
			end
		end
	end

	-- Core context with only 12 dynamic fields
	return {
		-- Core XP state (7 fields)
		currentXP = coreState.currentXP,
		xpMax = coreState.xpMax,
		level = coreState.level,
		restedXP = coreState.restedXP,
		isResting = coreState.isResting,
		hasRestedXP = coreState.hasRestedXP,
		isFullyRested = coreState.isFullyRested,
		-- Quest XP (2 fields)
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Session data (3 fields)
		sessionStart = sessionStart,
		sessionXP = sessionXP,
		levelSeconds = levelSeconds
	}
end

-------------------------------------------------------------------
-- CONTEXT BUILDING FUNCTIONS
-------------------------------------------------------------------

--- Build context for XP change events
--- Returns immutable context with all XP-related state
--- Uses inheritance: core context + event data + static config reference
---@param event string Event name (e.g., "PLAYER_XP_UPDATE")
---@param ... any Event arguments
---@return table context Immutable context object
function ContextBuilder.BuildXPChangeContext(event, ...)
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Calculate XP change
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(coreState.currentXP, coreState.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)

	-- Event-specific context (only 6 new fields)
	local eventContext = {
		-- Event metadata (3 fields)
		event = event,
		timestamp = time(),
		source = "PLAYER_XP_UPDATE",
		-- XP change tracking (3 fields)
		xpBefore = lastXP,
		xpAfter = coreState.currentXP,
		xpGained = xpGained,
		-- Derived values
		remainingXP = coreState.xpMax - coreState.currentXP,
		sessionDuration = sessionDuration,
		sessionSeconds = sessionDuration,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour),
		-- Event behavior flags
		hasGainedXP = (xpGained and xpGained > 0),
		hasLeveledUp = false,
		shouldAnimate = (xpGained and xpGained > 0),
		shouldFlash = (xpGained and xpGained > 0),
		restedChanged = false,
		questsChanged = false
	}

	-- Create immutable context with flattened structure
	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

--- Build context for level-up events
---@param event string Event name (e.g., "PLAYER_LEVEL_UP")
---@param newLevel number New player level
---@return table context Immutable context object
function ContextBuilder.BuildLevelUpContext(event, newLevel)
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Override level in core context to show the NEW level
	coreContext.level = newLevel or coreState.level

	-- Get session stats from Session service (before reset)
	local AddonGlobal = _G["XPBarEnhanced"]
	local sessionStart = time()
	local sessionXP = 0
	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session then
			if session.sessionStart then
				sessionStart = session.sessionStart
			end
			if session.gainedXP then
				sessionXP = session.gainedXP
			end
		end
	end

	local sessionDuration = time() - sessionStart
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, 0, 0)
	local timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour)

	-- Reset XP tracking for new level (Session service handles its own reset)
	ContextBuilder._lastXP = coreState.currentXP
	ContextBuilder._lastMaxXP = coreState.xpMax

	-- Event-specific context (only 5 new fields)
	local eventContext = {
		-- Event metadata (3 fields)
		event = event,
		timestamp = time(),
		source = "PLAYER_LEVEL_UP",
		-- Level-up semantics
		oldLevel = (newLevel or coreState.level) - 1,
		newLevel = newLevel or coreState.level,
		remainingXP = coreState.xpMax - coreState.currentXP,
		-- Session stats (preserved from before reset)
		sessionDuration = sessionDuration,
		sessionSeconds = sessionDuration,
		xpPerHour = xpPerHour,
		timeToLevel = timeToLevel,
		-- Event behavior flags
		-- Level-up DOES gain XP: from 0 to currentXP at new level (wraparound XP)
		hasGainedXP = (coreState.currentXP and coreState.currentXP > 0),
		hasLeveledUp = true,
		shouldAnimate = true,
		shouldFlash = (coreState.currentXP and coreState.currentXP > 0),
		restedChanged = false,
		questsChanged = false
	}

	-- Create immutable context with flattened structure
	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

--- Build context for rested state change
---@param event string Event name (e.g., "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING")
---@return table context Immutable context object
function ContextBuilder.BuildRestedContext(event, ...)
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Event-specific context (only 4 new fields)
	local eventContext = {
		-- Event metadata (3 fields)
		event = event,
		timestamp = time(),
		source = "RESTED_UPDATE",
		-- Derived values
		remainingXP = coreState.xpMax - coreState.currentXP,
		-- Event behavior flags
		hasGainedXP = false,
		hasLeveledUp = false,
		shouldAnimate = false, -- No bar animation for rested change
		shouldFlash = false,
		restedChanged = true,
		questsChanged = false
	}

	-- Create immutable context with flattened structure
	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

--- Build context for quest overlay updates
---@param event string Event name (e.g., "QUEST_LOG_UPDATE")
---@return table context Immutable context object
function ContextBuilder.BuildQuestContext(event, ...)
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Event-specific context (only 4 new fields)
	local eventContext = {
		-- Event metadata (3 fields)
		event = event,
		timestamp = time(),
		source = "QUEST_UPDATE",
		-- Derived values
		remainingXP = coreState.xpMax - coreState.currentXP,
		-- Event behavior flags
		hasGainedXP = false,
		hasLeveledUp = false,
		shouldAnimate = false, -- No bar animation for quest overlay change
		shouldFlash = false,
		restedChanged = false,
		questsChanged = true
	}

	-- Create immutable context with flattened structure
	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

--- Build context for tooltip display
---@return table context Immutable context object
function ContextBuilder.BuildTooltipContext()
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Calculate current session stats for tooltip display
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(coreState.currentXP, coreState.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)

	-- Event-specific context (only 6 new fields)
	local eventContext = {
		-- Event metadata (3 fields)
		event = "TOOLTIP",
		timestamp = time(),
		source = "TOOLTIP_CONTEXT",
		-- Derived values
		remainingXP = coreState.xpMax - coreState.currentXP,
		sessionDuration = sessionDuration,
		sessionSeconds = sessionDuration,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour)
	}

	-- Create immutable context with flattened structure
	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

-------------------------------------------------------------------
-- SESSION CALCULATION METHODS
-------------------------------------------------------------------

--- Calculate XP gain rate (XP per hour)
--- Duplicated from Session:GetXPPerHour() - independent implementation
---@param sessionStart number Session start timestamp
---@param sessionXP number Total XP gained in session
---@param realLevelTime number|nil Real played time at current level (optional)
---@param currentXP number|nil Current XP amount (optional, for fallback calculation)
---@return number xpPerHour XP per hour rate
function ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
	local duration = time() - (sessionStart or time())
	local gainedXP = sessionXP or 0

	-- Prefer session-derived rate when session is meaningful (at least 10 seconds)
	if duration >= 10 and gainedXP > 0 then
		return math.floor((gainedXP / duration) * 3600)
	end

	-- Fallback: estimate from realLevelTime if available
	if realLevelTime and realLevelTime > 0 and currentXP and currentXP > 0 then
		return math.floor((currentXP / realLevelTime) * 3600)
	end

	return 0
end

--- Calculate estimated time to next level
--- Duplicated from Session:GetTimeToLevel() - independent implementation
---@param currentXP number Current XP amount
---@param maxXP number Max XP for current level
---@param xpPerHour number XP gain rate (per hour)
---@return number seconds Estimated seconds to level up
function ContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour)
	if not maxXP or maxXP <= 0 then
		return 0
	end

	local remainingXP = (maxXP or 0) - (currentXP or 0)
	if xpPerHour > 0 and remainingXP > 0 then
		return math.floor((remainingXP / xpPerHour) * 3600)
	end

	return 0
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

--- Initialize context builder state
--- Called on addon load to set up XP tracking
function ContextBuilder.Initialize()
	-- No longer tracking sessionXP locally - use Session service's persistent gainedXP
	ContextBuilder._lastXP = UnitXP("player") or 0
	ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
end

--- Reset XP tracking (e.g., on login or manual reset)
--- Note: Session service handles its own session reset
function ContextBuilder.ResetSession()
	-- No longer tracking sessionXP locally - use Session service's persistent gainedXP
	ContextBuilder._lastXP = UnitXP("player") or 0
	ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
end

-- Auto-initialize on load
ContextBuilder.Initialize()

return ContextBuilder
