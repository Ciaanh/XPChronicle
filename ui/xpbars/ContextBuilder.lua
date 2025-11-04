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
	local isRested = IsResting()
	local isFullyRested = restedXP >= (1.5 * xpMax)
	return {
		currentXP = currentXP,
		xpMax = xpMax,
		level = level,
		restedXP = restedXP,
		isRested = isRested,
		isFullyRested = isFullyRested
	}
end

-- Retrieve quest XP breakdown (best-effort)
function ContextBuilder.GetQuestXP()
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	local completeCount = 0
	local incompleteCount = 0

	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	-- counts not exposed by current service; keep zero defaults
	end

	return completeQuestXP, incompleteQuestXP, completeCount, incompleteCount
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
	ContextBuilder._sessionStart = ContextBuilder._sessionStart or time()
	ContextBuilder._sessionXP = ContextBuilder._sessionXP or 0
	ContextBuilder._sessionXP = ContextBuilder._sessionXP + (xpGained or 0)

	local sessionStart = ContextBuilder._sessionStart
	local sessionXP = ContextBuilder._sessionXP
	local sessionDuration = time() - sessionStart
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, 0, ContextBuilder._lastXP or 0)

	return sessionStart, sessionXP, sessionDuration, xpPerHour
end

-- Helper to build base context table
function ContextBuilder.BuildBaseContext(event, source, coreState, extras)
	-- Helper to resolve boolean config with precedence: per-frame config -> global Addon.db -> default
	local function cfgBool(db, key, default)
		if db and db[key] ~= nil then
			return db[key] == true
		end
		return default == true
	end

	local db = Addon and Addon.db or {}

	local ctx = {
		event = event,
		timestamp = time(),
		source = source,
		currentXP = coreState.currentXP,
		xpMax = coreState.xpMax,
		remainingXP = coreState.xpMax - coreState.currentXP,
		level = coreState.level,
		restedXP = coreState.restedXP,
		isRested = coreState.isRested,
		isFullyRested = coreState.isFullyRested,
		-- Centralized display flags (per-frame config overrides global settings)
		showXPText = cfgBool(db, "showXPText", true),
		showLevelText = cfgBool(db, "showLevelText", true),
		showPercentage = cfgBool(db, "showPercentage", true),
		showQuestXP = cfgBool(db, "showQuestXP", true),
		showCompleteQuestOverlay = cfgBool(db, "showCompleteQuestOverlay", true),
		showIncompleteQuestOverlay = cfgBool(db, "showIncompleteQuestOverlay", true),
		showRestedOverlay = cfgBool(db, "showRestedOverlay", true),
		showExhaustionTick = cfgBool(db, "showExhaustionTick", true),
		showSessionTimeText = cfgBool(db, "showSessionTimeText", true),
		showLevelTimeText = cfgBool(db, "showLevelTimeText", true),
		showXPPerHourText = cfgBool(db, "showXPPerHourText", true),
		showTimeToLevelText = cfgBool(db, "showTimeToLevelText", true)
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

	local completeQuestXP, incompleteQuestXP, completeCount, incompleteCount = ContextBuilder.GetQuestXP()

	local extras = {
		-- XP change tracking
		xpBefore = lastXP,
		xpAfter = core.currentXP,
		xpGained = xpGained,
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		completeCount = completeCount,
		incompleteCount = incompleteCount,
		-- Session stats
		sessionXP = sessionXP,
		sessionDuration = sessionDuration,
		sessionStart = sessionStart,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(core.currentXP, core.xpMax, xpPerHour)
	}

	local ctx = ContextBuilder.BuildBaseContext(event, "PLAYER_XP_UPDATE", core, extras)
	return ctx
end

--- Build context for level-up events
---@param event string Event name (e.g., "PLAYER_LEVEL_UP")
---@param newLevel number New player level
---@return table context Immutable context object
function ContextBuilder.BuildLevelUpContext(event, newLevel)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	-- Reset session tracking for new level
	ContextBuilder._lastXP = core.currentXP
	ContextBuilder._lastMaxXP = core.xpMax
	ContextBuilder._sessionStart = ContextBuilder._sessionStart or time()
	ContextBuilder._sessionXP = 0

	local extras = {
		oldLevel = (newLevel or core.level) - 1,
		newLevel = newLevel or core.level,
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP
	}

	local ctx = ContextBuilder.BuildBaseContext(event, "PLAYER_LEVEL_UP", core, extras)
	return ctx
end

--- Build context for rested state change
---@param event string Event name (e.g., "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING")
---@return table context Immutable context object
function ContextBuilder.BuildRestedContext(event, ...)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	local extras = {
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP
	}

	local ctx = ContextBuilder.BuildBaseContext(event, "RESTED_UPDATE", core, extras)
	return ctx
end

--- Build context for quest overlay updates
---@param event string Event name (e.g., "QUEST_LOG_UPDATE")
---@return table context Immutable context object
function ContextBuilder.BuildQuestContext(event, ...)
	local core = ContextBuilder.GetCoreState()
	local completeQuestXP, incompleteQuestXP, completeCount, incompleteCount = ContextBuilder.GetQuestXP()

	local extras = {
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		completeCount = completeCount,
		incompleteCount = incompleteCount
	}

	local ctx = ContextBuilder.BuildBaseContext(event, "QUEST_UPDATE", core, extras)
	return ctx
end

function ContextBuilder.BuildTooltipContext()
	local core = ContextBuilder.GetCoreState()
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(core.currentXP, core.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)
	local completeQuestXP, incompleteQuestXP, completeCount, incompleteCount = ContextBuilder.GetQuestXP()

	local extras = {
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		completeCount = completeCount,
		incompleteCount = incompleteCount,
		-- Session stats
		sessionXP = sessionXP,
		sessionStart = sessionStart,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(core.currentXP, core.xpMax, xpPerHour)
	}

	local ctx = ContextBuilder.BuildBaseContext(event, "TOOLTIP_CONTEXT", core, extras)
	return ctx
end

-------------------------------------------------------------------
-- SESSION CALCULATION METHODS (duplicated from core/Session.lua)
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

--- Build session stats snapshot
--- Duplicated from Session:GetStats() - independent implementation
---@param sessionStart number Session start timestamp
---@param sessionXP number Total XP gained in session
---@param realLevelTime number|nil Real played time at current level (optional)
---@param realTotalTime number|nil Real total played time (optional)
---@return table stats Session statistics
function ContextBuilder.BuildSessionStats(sessionStart, sessionXP, realLevelTime, realTotalTime)
	local duration = time() - (sessionStart or time())

	-- Calculate XP per hour
	local xpPerHour = 0
	if duration > 0 then
		xpPerHour = ((sessionXP or 0) / (duration / 3600))
	end

	return {
		duration = duration,
		xpGained = sessionXP or 0,
		xpPerHour = xpPerHour,
		startTime = sessionStart or time(),
		realTotalTime = realTotalTime or 0,
		realLevelTime = realLevelTime or 0
	}
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

--- Initialize context builder state
--- Called on addon load to set up session tracking
function ContextBuilder.Initialize()
	ContextBuilder._sessionStart = time()
	ContextBuilder._sessionXP = 0
	ContextBuilder._lastXP = UnitXP("player") or 0
	ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
end

--- Reset session tracking (e.g., on login or manual reset)
function ContextBuilder.ResetSession()
	ContextBuilder._sessionStart = time()
	ContextBuilder._sessionXP = 0
	ContextBuilder._lastXP = UnitXP("player") or 0
	ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
end

-- Auto-initialize on load
ContextBuilder.Initialize()

return ContextBuilder
