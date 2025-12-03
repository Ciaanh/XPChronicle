-- XP Bar Enhanced - Context Builder ()
-- Standalone utility module for building immutable context objects
-- Integrates session calculation methods (duplicated from core/Session.lua)
-- NO DEPENDENCIES on existing Session, Database, or other core modules

---@class CoreState
---@field currentXP number Current player XP
---@field xpMax number Maximum XP for current level
---@field level number Current player level
---@field restedXP number Amount of rested XP available
---@field isResting boolean Whether player is in a resting area
---@field hasRestedXP boolean Whether player has any rested XP
---@field isFullyRested boolean Whether player has max rested XP

-------------------------------------------------------------------
-- STATIC CONFIGURATION (SHARED)
-------------------------------------------------------------------

---Build fresh static configuration from database
---Called each time a context is built to ensure latest settings
---@return table staticConfig Fresh configuration with current settings
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

	-- Animation settings
	setIfPresent("enableAnimations")
	setIfPresent("twoPhaseOnLevelUp")

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

	-- Prefer the new central QuestXP if present; otherwise use XPBar shim
	if XPBarEnhanced and XPBarEnhanced.QuestXP and XPBarEnhanced.QuestXP.GetQuestXP then
		local total, complete, incomplete = XPBarEnhanced.QuestXP:GetQuestXP()
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
-- Uses centralized XPCalculations module
function ContextBuilder.ComputeXPGained(currentXP, xpMax)
	local lastXP = ContextBuilder._lastXP or currentXP
	local lastMax = ContextBuilder._lastMaxXP or xpMax

	-- Use centralized XPCalculations module
	local XPCalc = XPBarEnhanced.XPCalculations
	local xpGained, didLevelUp = XPCalc.ComputeGain(currentXP, xpMax, lastXP, lastMax)

	-- Store pre-level snapshot BEFORE updating (for two-phase animation)
	local preLevelXP = lastXP
	local preLevelMax = lastMax

	-- Update last values for next computation
	ContextBuilder._lastXP = currentXP
	ContextBuilder._lastMaxXP = xpMax

	return xpGained, preLevelXP, preLevelMax, didLevelUp
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

-- helper: decide if this event is worth logging in detail
local function isImportantEvent(event, xpGained, lastXP, coreState)
	if event == "PLAYER_LEVEL_UP" then
		return true
	end
	if xpGained and xpGained > 0 then
		return true
	end
	-- XP wrap-around indicates a level-up even if no PLAYER_LEVEL_UP delivered
	if lastXP and coreState and lastXP > coreState.currentXP then
		return true
	end
	-- add other critical events here if needed
	return false
end

-- Events that should NOT consume XP changes (internal addon events)
-- Only real WoW XP events should update _lastXP and trigger animation
local XP_CONSUMING_EVENTS = {
	["PLAYER_XP_UPDATE"] = true,
	["PLAYER_LEVEL_UP"] = true,
	["PLAYER_ENTERING_WORLD"] = true -- initial load should set baseline
}

function XPBarContextBuilder.BuildContext(event, ...)
	local args = {...}
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	local shouldConsumeXP = XP_CONSUMING_EVENTS[event] == true

	local xpGained, preLevelXP, preLevelMax, didLevelUp
	if shouldConsumeXP then
		xpGained, preLevelXP, preLevelMax, didLevelUp = ContextBuilder.ComputeXPGained(coreState.currentXP, coreState.xpMax)
	else
		xpGained = 0
		preLevelXP = ContextBuilder._lastXP or coreState.currentXP
		preLevelMax = ContextBuilder._lastMaxXP or coreState.xpMax
		didLevelUp = false
	end

	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)

	local hasGainedXP = (xpGained and xpGained > 0) or false

	-- Default event context
	local eventContext = {
		-- Event metadata
		event = event,
		timestamp = time(),
		source = tostring(event or "UNKNOWN"),
		-- XP tracking
		xpBefore = preLevelXP or 0,
		xpAfter = coreState.currentXP,
		xpGained = xpGained or 0,
		-- Snapshot fields for two-phase animations on level-up
		preLevelCurrentXP = preLevelXP or 0,
		preLevelXPMax = preLevelMax or coreState.xpMax or 1,
		-- Session
		sessionStart = sessionStart or time(),
		sessionXP = sessionXP or 0,
		sessionDuration = sessionDuration or 0,
		sessionSeconds = sessionDuration or 0,
		xpPerHour = xpPerHour or 0,
		-- Derived timing
		timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour or 0),
		-- Level fields
		previousLevel = didLevelUp and (coreState.level - 1) or nil,
		level = coreState.level,
		-- Behavior flags
		hasGainedXP = hasGainedXP,
		hasLeveledUp = didLevelUp,
		shouldAnimate = hasGainedXP or didLevelUp,
		shouldFlash = hasGainedXP or didLevelUp,
		restedChanged = false,
		questsChanged = false
	}

	-- Apply special handling per event to preserve previous semantics
	if event == "PLAYER_XP_UPDATE" then
		eventContext.source = "PLAYER_XP_UPDATE"
	elseif event == "PLAYER_LEVEL_UP" then
		eventContext.source = "PLAYER_LEVEL_UP"
		local level = args[1] or coreState.level
		eventContext.level = level
		eventContext.previousLevel = (level and level - 1) or (coreState.level and coreState.level - 1)

		-- IMPORTANT: On PLAYER_LEVEL_UP, the WoW API (UnitXP/UnitXPMax) hasn't updated yet.
		-- The actual new XP values come in the subsequent PLAYER_XP_UPDATE event.
		-- We mark hasLeveledUp for informational purposes but DON'T trigger animation here.
		-- The two-phase animation will be triggered by PLAYER_XP_UPDATE when it detects
		-- the xpMax change and has the actual new XP values.
		eventContext.hasLeveledUp = false  -- Let PLAYER_XP_UPDATE detect this via xpMax change
		eventContext.shouldAnimate = false -- Don't animate with stale data
		eventContext.hasGainedXP = false
		eventContext.shouldFlash = false

		-- DON'T update _lastXP/_lastMaxXP here - let PLAYER_XP_UPDATE do it with real values
	elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		eventContext.source = "RESTED_UPDATE"
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
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
	else
		eventContext.source = eventContext.source or "UNKNOWN"
	end

	-- Ensure both canonical keys exist so consumers don't fail if they expect currentXP or xpAfter
	-- Copy canonical values if needed
	local flatCoreXP = coreState.currentXP or nil
	if eventContext.xpAfter ~= nil and flatCoreXP == nil then
		-- nothing to do here since coreContext will be merged; left as safety
	else
		-- if coreState had value assign it to xpAfter if not provided (already done above)
	end

	local immutableContext = ContextBuilder.MakeImmutable(eventContext, coreContext)

	return immutableContext
end

-------------------------------------------------------------------
-- SESSION CALCULATION METHODS
-------------------------------------------------------------------

--- Calculate XP gain rate (XP per hour)
--- Uses centralized TimeCalculations module
---@param sessionStart number Session start timestamp
---@param sessionXP number Total XP gained in session
---@param realLevelTime number|nil Real played time at current level (optional)
---@param currentXP number|nil Current XP amount (optional, for fallback calculation)
---@return number xpPerHour XP per hour rate
function ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
	local TimeCalc = XPBarEnhanced.TimeCalculations
	return TimeCalc.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
end

--- Calculate estimated time to next level
--- Uses centralized TimeCalculations module
---@param currentXP number Current XP amount
---@param maxXP number Max XP for current level
---@param xpPerHour number XP gain rate (per hour)
---@return number seconds Estimated seconds to level up
function ContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour)
	local TimeCalc = XPBarEnhanced.TimeCalculations
	return TimeCalc.TimeToLevelFromXP(currentXP, maxXP, xpPerHour) or 0
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
