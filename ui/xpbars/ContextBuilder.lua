-- XP Bar Enhanced - Context Builder (v2)
-- Standalone utility module for building immutable context objects
-- Integrates session calculation methods (duplicated from core/Session.lua)
-- NO DEPENDENCIES on existing Session, Database, or other core modules

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
--- Prevents accidental modifications to context after creation
--- @param context table The context to make immutable
--- @return table immutableContext Protected context
function ContextBuilder.MakeImmutable(context)
	return setmetatable({}, {
		__index = context,
		__newindex = function(t, k, v)
			error(string.format("Attempt to modify immutable context field '%s'", tostring(k)), 2)
		end,
		__metatable = false -- Prevent metatable access
	})
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
				return dbValue ~= false
			-- For defaults that are false: hide unless explicitly enabled  
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

-------------------------------------------------------------------
-- CONTEXT BUILDING FUNCTIONS
-------------------------------------------------------------------

--- Build context for XP change events
--- Returns immutable context with all XP-related state
---@param event string Event name (e.g., "PLAYER_XP_UPDATE")
---@param ... any Event arguments
---@return table context Immutable context object
function ContextBuilder.BuildXPChangeContext(event, ...)
	local core = ContextBuilder.GetCoreState()
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(core.currentXP, core.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()
	
	-- Get real level time from Session service (not just session duration)
	local levelSeconds = 0
	local AddonGlobal = _G["XPBarEnhanced"]
	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session and session.realLevelTime and session.realLevelTime > 0 then
			levelSeconds = session.realLevelTime
			-- Add elapsed time since last TIME_PLAYED_MSG for real-time accuracy
			if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
				local elapsed = time() - session.lastTimePlayedRequest
				levelSeconds = levelSeconds + elapsed
			end
		end
	end

	local baseContext = ContextBuilder.BuildBaseContext(event, "PLAYER_XP_UPDATE", core, nil)
	
	-- Extend with XP change specific data
	local ctx = ContextBuilder.ExtendContext(baseContext, {
		-- XP change tracking
		xpBefore = lastXP,
		xpAfter = core.currentXP,
		xpGained = xpGained,
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Session stats
		sessionXP = sessionXP,
		sessionDuration = sessionDuration,
		sessionSeconds = sessionDuration,
		levelSeconds = levelSeconds, -- Real level time from Session service
		sessionStart = sessionStart,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(core.currentXP, core.xpMax, xpPerHour),
		-- Event behavior flags (Phase 1: Refactor)
		hasGainedXP = (xpGained and xpGained > 0),
		hasLeveledUp = false,
		shouldAnimate = (xpGained and xpGained > 0),
		shouldFlash = (xpGained and xpGained > 0),
		restedChanged = false,
		questsChanged = false
	})
	
	return ContextBuilder.MakeImmutable(ctx)
end

--- Build context for level-up events
---@param event string Event name (e.g., "PLAYER_LEVEL_UP")
---@param newLevel number New player level
---@return table context Immutable context object
function ContextBuilder.BuildLevelUpContext(event, newLevel)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	-- Use Session service's sessionStart from saved variables
	local AddonGlobal = _G["XPBarEnhanced"]
	local sessionStart = time() -- Fallback
	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session and session.sessionStart then
			sessionStart = session.sessionStart
		end
	end

	-- Calculate current session stats (use Session service's gainedXP)
	local AddonGlobal = _G["XPBarEnhanced"]
	local sessionXP = 0
	if AddonGlobal and AddonGlobal.Session then
		local session = AddonGlobal.Session:GetCurrent()
		if session and session.gainedXP then
			sessionXP = session.gainedXP
		end
	end
	
	local sessionDuration = time() - sessionStart
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, 0, 0)
	local timeToLevel = ContextBuilder.CalculateTimeToLevel(core.currentXP, core.xpMax, xpPerHour)

	-- Reset XP tracking for new level (Session service handles its own reset)
	ContextBuilder._lastXP = core.currentXP
	ContextBuilder._lastMaxXP = core.xpMax

	local baseContext = ContextBuilder.BuildBaseContext(event, "PLAYER_LEVEL_UP", core, nil)
	
	-- Extend with level-up specific data
	local ctx = ContextBuilder.ExtendContext(baseContext, {
		oldLevel = (newLevel or core.level) - 1,
		newLevel = newLevel or core.level,
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Session stats (from before reset)
		sessionXP = sessionXP,
		sessionDuration = sessionDuration,
		sessionStart = sessionStart,
		xpPerHour = xpPerHour,
		timeToLevel = timeToLevel,
		sessionSeconds = sessionDuration,
		levelSeconds = 0, -- Reset for new level
		-- Event behavior flags (Phase 1: Refactor)
		-- Level-up DOES gain XP: from 0 to currentXP at new level (wraparound XP)
		hasGainedXP = (core.currentXP and core.currentXP > 0),
		hasLeveledUp = true,
		shouldAnimate = true,
		shouldFlash = (core.currentXP and core.currentXP > 0), -- Flash only if we have XP at new level
		restedChanged = false,
		questsChanged = false
	})
	
	return ContextBuilder.MakeImmutable(ctx)
end

--- Build context for rested state change
---@param event string Event name (e.g., "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING")
---@return table context Immutable context object
function ContextBuilder.BuildRestedContext(event, ...)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	local baseContext = ContextBuilder.BuildBaseContext(event, "RESTED_UPDATE", core, nil)
	
	-- Extend with quest XP data
	local ctx = ContextBuilder.ExtendContext(baseContext, {
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Event behavior flags (Phase 1: Refactor)
		hasGainedXP = false,
		hasLeveledUp = false,
		shouldAnimate = false, -- No bar animation for rested change
		shouldFlash = false,
		restedChanged = true,
		questsChanged = false
	})
	
	return ContextBuilder.MakeImmutable(ctx)
end

--- Build context for quest overlay updates
---@param event string Event name (e.g., "QUEST_LOG_UPDATE")
---@return table context Immutable context object
function ContextBuilder.BuildQuestContext(event, ...)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	local baseContext = ContextBuilder.BuildBaseContext(event, "QUEST_UPDATE", core, nil)
	
	-- Extend with quest XP data
	local ctx = ContextBuilder.ExtendContext(baseContext, {
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Event behavior flags (Phase 1: Refactor)
		hasGainedXP = false,
		hasLeveledUp = false,
		shouldAnimate = false, -- No bar animation for quest overlay change
		shouldFlash = false,
		restedChanged = false,
		questsChanged = true
	})
	
	return ContextBuilder.MakeImmutable(ctx)
end

--- Build context for tooltip display
---@return table context Immutable context object
function ContextBuilder.BuildTooltipContext()
	local core = ContextBuilder.GetCoreState()
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(core.currentXP, core.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	local baseContext = ContextBuilder.BuildBaseContext("TOOLTIP", "TOOLTIP_CONTEXT", core, nil)
	
	-- Extend with tooltip-specific data
	local ctx = ContextBuilder.ExtendContext(baseContext, {
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		-- Session stats
		sessionXP = sessionXP,
		sessionStart = sessionStart,
		sessionDuration = sessionDuration,
		sessionSeconds = sessionDuration,
		levelSeconds = sessionDuration, -- For tooltip, assume level time = session time
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(core.currentXP, core.xpMax, xpPerHour)
	})
	
	return ContextBuilder.MakeImmutable(ctx)
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
