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
-- CONTEXT BUILDING FUNCTIONS
-------------------------------------------------------------------

--- Build context for XP change events
--- Returns immutable context with all XP-related state
---@param event string Event name (e.g., "PLAYER_XP_UPDATE")
---@param ... any Event arguments
---@return table context Immutable context object
function ContextBuilder.BuildXPChangeContext(event, ...)
	local currentXP = UnitXP("player") or 0
	local maxXP = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isRested = IsResting()
	local isFullyRested = restedXP >= (1.5 * maxXP)
	
	-- Calculate XP gain (handles level-up wrap-around)
	local lastXP = ContextBuilder._lastXP or currentXP
	local xpGained = currentXP - lastXP
	if xpGained < 0 then
		-- Level-up occurred, XP wrapped around
		xpGained = (ContextBuilder._lastMaxXP or maxXP) - lastXP + currentXP
	end
	if xpGained < 0 then
		xpGained = 0
	end
	
	-- Store current values for next calculation
	ContextBuilder._lastXP = currentXP
	ContextBuilder._lastMaxXP = maxXP
	
	-- Get quest XP values (if quest service available)
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	local completeCount = 0
	local incompleteCount = 0
	
	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
		-- Note: counts not available from current service, default to 0
	end
	
	-- Calculate session stats
	local sessionStart = ContextBuilder._sessionStart or time()
	local sessionXP = ContextBuilder._sessionXP or 0
	sessionXP = sessionXP + xpGained
	ContextBuilder._sessionXP = sessionXP
	
	local sessionDuration = time() - sessionStart
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, 0, currentXP)
	
	-- Build immutable context
	return {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = "PLAYER_XP_UPDATE",
		
		-- Core XP values
		currentXP = currentXP,
		xpMax = maxXP,
		level = level,
		
		-- XP change tracking
		xpBefore = lastXP,
		xpAfter = currentXP,
		xpGained = xpGained,
		
		-- Rested state
		restedXP = restedXP,
		isRested = isRested,
		isFullyRested = isFullyRested,
		
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		completeCount = completeCount,
		incompleteCount = incompleteCount,
		
		-- Session stats
		sessionXP = sessionXP,
		sessionDuration = sessionDuration,
		xpPerHour = xpPerHour,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour),
	}
end

--- Build context for level-up events
---@param event string Event name (e.g., "PLAYER_LEVEL_UP")
---@param newLevel number New player level
---@return table context Immutable context object
function ContextBuilder.BuildLevelUpContext(event, newLevel)
	local oldLevel = (newLevel or UnitLevel("player")) - 1
	local currentXP = UnitXP("player") or 0
	local maxXP = UnitXPMax("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isRested = IsResting()
	local isFullyRested = restedXP >= (1.5 * maxXP)
	
	-- Get quest XP values
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	
	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	end
	
	-- Reset session tracking for new level
	ContextBuilder._lastXP = currentXP
	ContextBuilder._lastMaxXP = maxXP
	
	return {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = "PLAYER_LEVEL_UP",
		
		-- Level change
		oldLevel = oldLevel,
		newLevel = newLevel or UnitLevel("player"),
		
		-- Current state
		currentXP = currentXP,
		xpMax = maxXP,
		level = newLevel or UnitLevel("player"),
		
		-- Rested state
		restedXP = restedXP,
		isRested = isRested,
		isFullyRested = isFullyRested,
		
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
	}
end

--- Build context for rested state change
---@param event string Event name (e.g., "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING")
---@return table context Immutable context object
function ContextBuilder.BuildRestedContext(event, ...)
	local currentXP = UnitXP("player") or 0
	local maxXP = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isRested = IsResting()
	local isFullyRested = restedXP >= (1.5 * maxXP)
	
	-- Get quest XP values
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	
	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	end
	
	return {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = "RESTED_UPDATE",
		
		-- Core values
		currentXP = currentXP,
		xpMax = maxXP,
		level = level,
		
		-- Rested state
		restedXP = restedXP,
		isRested = isRested,
		isFullyRested = isFullyRested,
		
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
	}
end

--- Build context for quest overlay updates
---@param event string Event name (e.g., "QUEST_LOG_UPDATE")
---@return table context Immutable context object
function ContextBuilder.BuildQuestContext(event, ...)
	local currentXP = UnitXP("player") or 0
	local maxXP = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	
	-- Get quest XP values
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	local completeCount = 0
	local incompleteCount = 0
	
	if XPBarEnhanced and XPBarEnhanced.XPBar then
		local total, complete, incomplete = XPBarEnhanced.XPBar:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	end
	
	return {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = "QUEST_UPDATE",
		
		-- Core values
		currentXP = currentXP,
		xpMax = maxXP,
		level = level,
		
		-- Quest XP
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		completeCount = completeCount,
		incompleteCount = incompleteCount,
	}
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
		realLevelTime = realLevelTime or 0,
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
