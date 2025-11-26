-- XP Bar Enhanced - Context Builder ()
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

	-- If there's no saved DB, return an empty config table so callers
	-- treat the context as the source of truth and don't assume defaults.
	if not db then
		return {}
	end

	local cfg = {}

	-- Only include keys that are explicitly present in the saved DB.
	-- This prevents silently applying defaults and keeps the context
	-- faithful to the user's saved configuration.
	local function setIfPresent(key)
		if db[key] ~= nil then
			cfg[key] = db[key]
		end
	end

	-- Display flags
	setIfPresent("showXPText")
	setIfPresent("showLevelText")
	setIfPresent("showPercentage")
	setIfPresent("showQuestXP")
	setIfPresent("showCompleteQuestOverlay")
	setIfPresent("showIncompleteQuestOverlay")
	setIfPresent("showRestedOverlay")
	setIfPresent("showExhaustionTick")
	setIfPresent("showSessionTimeText")
	setIfPresent("showLevelTimeText")
	setIfPresent("showXPPerHourText")
	setIfPresent("showTimeToLevelText")
	setIfPresent("showRemainingXP")
	setIfPresent("showQuestPercent")

	-- Configuration values
	if db.percentDecimals ~= nil then
		cfg.percentDecimals = db.percentDecimals
	end
	setIfPresent("abbreviateNumbers")
	setIfPresent("flashOnGain")

	return cfg
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

	-- Prefer the new central QuestXPService if present; otherwise use XPBar shim
	if XPBarEnhanced and XPBarEnhanced.QuestXPService and XPBarEnhanced.QuestXPService.GetQuestXP then
		local total, complete, incomplete = XPBarEnhanced.QuestXPService:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	else
		completeQuestXP = 0
		incompleteQuestXP = 0
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
		isFullyRested = coreState.isFullyRested
		-- Note: display/config flags are applied below only when
		-- present in the saved DB. Do not inject defaults here; the
		-- context must reflect only actual saved configuration values.
	}

	if extras and type(extras) == "table" then
		for k, v in pairs(extras) do
			ctx[k] = v
		end
	end

	-- Merge in any saved configuration keys (only present keys are included)
	local staticCfg = BuildDBConfig()
	if staticCfg and type(staticCfg) == "table" then
		for k, v in pairs(staticCfg) do
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

--- Build a complete context for any XP-related event
--- Ensures all context keys are present to avoid missing data across listeners
--- @param event string Event name (e.g., "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "TOOLTIP", "UPDATE_EXHAUSTION", "QUEST_LOG_UPDATE")
--- @param ... any Event arguments (e.g., newLevel for PLAYER_LEVEL_UP)
--- @return table context Immutable context object with a Get() accessor
function ContextBuilder.BuildContext(event, ...)
	local args = {...}
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	-- Compute XP change for consistent results
	local xpGained, lastXP = ContextBuilder.ComputeXPGained(coreState.currentXP, coreState.xpMax)
	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)

	-- Default union-of-all-fields event context (pre-populated)
	local eventContext = {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = tostring(event or "UNKNOWN"),
		-- XP tracking
		xpBefore = lastXP or 0,
		xpAfter = coreState.currentXP,
		xpGained = xpGained or 0,
		remainingXP = coreState.xpMax - coreState.currentXP,
		-- Session
		sessionStart = sessionStart or time(),
		sessionXP = sessionXP or 0,
		sessionDuration = sessionDuration or 0,
		sessionSeconds = sessionDuration or 0,
		xpPerHour = xpPerHour or 0,
		-- Derived timing
		timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour),
		-- Level fields (some events won't use these)
		oldLevel = coreState.level - 1,
		newLevel = coreState.level,
		-- Behavior flags (defaults)
		hasGainedXP = (xpGained and xpGained > 0) or false,
		hasLeveledUp = false,
		shouldAnimate = (xpGained and xpGained > 0) or false,
		shouldFlash = (xpGained and xpGained > 0) or false,
		restedChanged = false,
		questsChanged = false
	}

	-- Apply special handling per event to preserve previous semantics
	if event == "PLAYER_XP_UPDATE" then
		eventContext.source = "PLAYER_XP_UPDATE"
		-- xpBefore/after were already set above
		-- default flags (gain/animate/flash) remain
		eventContext.hasLeveledUp = false
	elseif event == "PLAYER_LEVEL_UP" then
		eventContext.source = "PLAYER_LEVEL_UP"
		local newLevel = args[1] or coreState.level
		eventContext.newLevel = newLevel
		eventContext.oldLevel = (newLevel or coreState.level) - 1

		-- Keep xpBefore as 0 per previous behaviour (level-up resets xp)
		eventContext.xpBefore = 0
		eventContext.xpAfter = coreState.currentXP
		-- Level-up always animates
		eventContext.hasLeveledUp = true
		eventContext.shouldAnimate = true
		eventContext.hasGainedXP = (coreState.currentXP and coreState.currentXP > 0) or false
		eventContext.shouldFlash = eventContext.hasGainedXP
		-- Reset last XP to avoid incorrect gains next snapshot
		ContextBuilder._lastXP = coreState.currentXP
		ContextBuilder._lastMaxXP = coreState.xpMax
	elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		eventContext.source = "RESTED_UPDATE"
		-- Rest changes do not affect XP numbers
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
		eventContext.restedChanged = true
	elseif event == "QUEST_LOG_UPDATE" then
		eventContext.source = "QUEST_UPDATE"
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
		eventContext.questsChanged = true
	elseif event == "TOOLTIP" then
		eventContext.source = "TOOLTIP_CONTEXT"
		-- Tooltip is read-only, just present the computed values
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
	else
		-- For other events not explicitly handled, keep a conservative default:
		eventContext.source = eventContext.source or "UNKNOWN"
	end

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
