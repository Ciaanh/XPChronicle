-- XP Bar Enhanced - XP Bar Mixin Base (Shared Logic)
-- Contains common functionality used by both Legacy and Flat XP bar implementations

local Addon = XPBarEnhanced

-- Note: Color constants and XPC_XPBarColors compatibility layer
-- are now provided by core/Colors.lua

-----------------------------------
-- Shared Constants
-----------------------------------
local CONTAINER_WIDTH = 571
local CONTAINER_HEIGHT = 17
local BAR_WIDTH = 565 -- Container - 6
local BAR_HEIGHT = 11 -- Container - 6

-----------------------------------
-- Animation Constants (from Blizzard reference)
-----------------------------------
local ANIMATION_CONSTANTS = {
	GAIN_FLASH_HALF_PERIOD_SECONDS = 0.25,
	GAIN_FLASH_MAX_ALPHA = 0.5,
	PAUSE_SECONDS = 0.5,
	DEFAULT_ANIMATION_SPEED = 1.0,
	MIN_ANIMATION_DURATION = 0.3,
	MAX_ANIMATION_DURATION = 2.0,
}

-----------------------------------
-- Base Mixin (Shared Logic)
-----------------------------------
XPC_XPBarMixinBase = {}

-- Initialize shared state
function XPC_XPBarMixinBase:InitializeState()
	self.state = {
		currentXP = 0,
		maxXP = 1,
		restedXP = 0,
		level = 1,
		maxLevel = 80
	}

	-- Initialize quest offset for rested positioning
	self.questOffsetForRested = 0

	-- Initialize animation state
	self:InitializeAnimationState()

	-- Initialize text system
	self:InitializeTextSystem()
	
	-- Initialize quest overlay system
	self:InitializeQuestOverlays()
end

-- Initialize animation state
function XPC_XPBarMixinBase:InitializeAnimationState()
	self.animationState = {
		-- Bar fill animation
		currentValue = 0,
		targetValue = 0,
		animating = false,
		animationStartTime = 0,
		animationDuration = 0,
		pauseUntil = 0,
		
		-- Flash effect
		flashingXPGain = false,
		flashStartTime = 0,
		flashDuration = 0,
		isRestedGain = false,
		
		-- Previous XP for gain detection
		previousXP = 0,
	}
end

-- Initialize text overlay system
function XPC_XPBarMixinBase:InitializeTextSystem()
	-- Set text visibility based on SavedVariables
	-- This will be called during OnLoad, so we need to defer slightly
	-- to ensure Addon.db is loaded
	C_Timer.After(
		0.1,
		function()
			if self and self.UpdateTextVisibility then
				self:UpdateTextVisibility()
				-- Force an update of all text
				self:UpdateAllText()

				-- Request time played data if time text is enabled
				local db = Addon.db or {}
				if db.showLevelTimeText or db.showSessionTimeText then
					if Addon.Session and Addon.Session.RequestTimePlayed then
						Addon.Session:RequestTimePlayed()
					end
				end
				
				-- Note: Periodic updates are now handled by XPBarController:StartPeriodicUpdates()
				-- This ensures only one timer for the entire addon instead of per-bar timers
			end
		end
	)
end

-- Register common events
function XPC_XPBarMixinBase:RegisterCommonEvents()
	self:RegisterEvent("PLAYER_XP_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("UPDATE_EXHAUSTION")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")
	
	-- Quest events for overlays
	self:RegisterQuestEvents()
end

-- Common event handler
function XPC_XPBarMixinBase:HandleEvent(event, ...)
	if event == "PLAYER_XP_UPDATE" then
		self:UpdateXP()
		-- Update text that depends on XP
		self:UpdateXPText()
		self:UpdatePercentText()
	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = ...
		self:OnLevelUp(newLevel)
	elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		-- New architecture: UpdateBarDisplay handles rested positioning
		self:UpdateBarDisplay()
		-- Update quest summary (includes rested info)
		self:UpdateQuestSummaryText()
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:FullUpdate()
	elseif event == "TIME_PLAYED_MSG" then
		-- Update session text when we receive time played data
		self:UpdateSessionText()
	elseif event == "QUEST_ACCEPTED" or
	       event == "QUEST_REMOVED" or
	       event == "QUEST_TURNED_IN" or
	       event == "QUEST_LOG_UPDATE" or
	       event == "UNIT_QUEST_LOG_CHANGED" then
		-- NEW ARCHITECTURE: Update entire bar when quest state changes
		self:UpdateBarDisplay()
	end
end

-- Full update of all XP values
function XPC_XPBarMixinBase:FullUpdate()
	local level = UnitLevel("player")

	-- Check if max level
	if level >= self.state.maxLevel then
		self:GetParent():Hide()
		return
	end

	-- NEW ARCHITECTURE: Use unified update method
	self:UpdateBarDisplay()

	-- Update visuals (rested state texture changes for Legacy bar)
	if self.UpdateVisuals then
		self:UpdateVisuals()
	end

	-- Set bar to current position instantly (no animation on load/reload)
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local targetRatio = (maxXP > 0) and (currentXP / maxXP) or 0
	self.animationState.currentValue = targetRatio
	self.animationState.targetValue = targetRatio
	self.animationState.previousXP = currentXP
	self:UpdateStatusBarValue(targetRatio)

	-- Update text visibility and content
	self:UpdateTextVisibility()
	self:UpdateAllText()
end

-- Update XP values
function XPC_XPBarMixinBase:UpdateXP()
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local previousXP = self.animationState.previousXP

	self.state.currentXP = currentXP
	self.state.maxXP = maxXP

	-- Detect XP gain for flash effect
	if currentXP > previousXP and previousXP > 0 then
		local isRested = self:IsRested()
		self:TriggerXPGainFlash(isRested)
	end

	self.animationState.previousXP = currentXP

	-- Animate to new value
	local targetRatio = (maxXP > 0) and (currentXP / maxXP) or 0
	self:AnimateToValue(targetRatio, false)
end

-- Check if player is rested
function XPC_XPBarMixinBase:IsRested()
	local restedXP = GetXPExhaustion() or 0
	return restedXP > 0
end

-- Update status bar with current XP (now just sets min/max, animation handles value)
function XPC_XPBarMixinBase:UpdateStatusBar()
	if not self.StatusBar then
		return
	end

	local maxXP = self.state.maxXP

	-- Update min/max
	self.StatusBar:SetMinMaxValues(0, 1) -- Work in ratios for smooth animation
end

-- Update status bar value directly (called by animation system)
function XPC_XPBarMixinBase:UpdateStatusBarValue(ratio)
	if not self.StatusBar then
		return
	end

	-- Ensure ratio is a valid finite number between 0 and 1
	if type(ratio) ~= "number" or ratio ~= ratio then -- NaN check
		ratio = 0
	elseif ratio == math.huge or ratio == -math.huge then -- Infinity check
		ratio = 0
	else
		ratio = math.max(0, math.min(1, ratio)) -- Clamp to [0, 1]
	end

	self.StatusBar:SetValue(ratio)
end

-- Calculate rested XP dimensions (with quest overlay offset support)
function XPC_XPBarMixinBase:CalculateRestedDimensions()
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local restedXP = GetXPExhaustion() or 0

	if restedXP <= 0 or maxXP <= 0 then
		return nil
	end

	-- Account for quest overlays offset
	local questOffset = self.questOffsetForRested or 0
	
	-- Calculate rested position: current XP + quest overlays + rested XP
	local totalWithQuestsAndRested = currentXP + questOffset + restedXP
	local restedRatio = math.min(totalWithQuestsAndRested / maxXP, 1.0)
	local restedWidth = restedRatio * BAR_WIDTH
	
	-- Calculate the actual rested width (not including current XP or quest offset)
	local currentPlusQuestRatio = math.min((currentXP + questOffset) / maxXP, 1.0)
	local currentPlusQuestWidth = currentPlusQuestRatio * BAR_WIDTH
	local actualRestedWidth = math.max(0, restedWidth - currentPlusQuestWidth)

	return {
		restedXP = restedXP,
		restedRatio = restedRatio,  -- Total ratio including current XP + quests + rested
		restedWidth = actualRestedWidth,  -- Width of rested overlay only
		restedFullWidth = restedWidth,  -- Full width including offset (for tick positioning)
		questOffset = questOffset,  -- Store offset for positioning
		isFullyRested = restedWidth >= BAR_WIDTH,
		showTick = restedRatio >= 0.01 and restedRatio <= 0.99
	}
end

-- Get rested state
function XPC_XPBarMixinBase:GetRestedState()
	local exhaustionStateID = GetRestState()
	-- exhaustionStateID == 1 is Rested, == 2 is Normal
	local isRested = exhaustionStateID == 1

	return {
		exhaustionStateID = exhaustionStateID,
		isRested = isRested
	}
end

-- Level up handler
function XPC_XPBarMixinBase:OnLevelUp(newLevel)
	self.state.level = newLevel

	-- Cancel any ongoing animations
	self.animationState.animating = false
	self.animationState.flashingXPGain = false
	self:SetScript("OnUpdate", nil)
	
	-- Hide flash
	if self.SetFlashAlpha then
		self:SetFlashAlpha(0)
	end

	-- Check if max level
	if newLevel >= self.state.maxLevel then
		self:GetParent():Hide()
		return
	end
	
	-- Invalidate quest XP cache - quest rewards change with level
	if Addon.XPBar and Addon.XPBar.InvalidateQuestCache then
		Addon.XPBar:InvalidateQuestCache()
	end

	-- Play level-up celebration if enabled
	local db = Addon.db or {}
	if db.levelUpCelebration then
		self:PlayLevelUpCelebration(newLevel)
	else
		-- Just do normal update if celebration disabled
		self:FullUpdate()
	end

	-- Update level text immediately
	self:UpdateLevelText()
	
	-- Update all text including quest-related displays
	self:UpdateAllText()
end

-----------------------------------
-- Level-Up Celebration Animation
-----------------------------------

function XPC_XPBarMixinBase:PlayLevelUpCelebration(newLevel)
	local db = Addon.db or {}
	
	-- Celebration configuration
	local speedMultiplier = 1.0
	if db.celebrationSpeed == "fast" then
		speedMultiplier = 0.7
	elseif db.celebrationSpeed == "slow" then
		speedMultiplier = 1.5
	end
	
	-- Trigger gold flash
	self:TriggerLevelUpFlash(speedMultiplier)
	
	-- Schedule full bar update after flash
	C_Timer.After(1.0 * speedMultiplier, function()
		if self and self.FullUpdate then
			self:FullUpdate()
		end
	end)
end

function XPC_XPBarMixinBase:TriggerLevelUpFlash(speedMultiplier)
	speedMultiplier = speedMultiplier or 1.0
	
	if not self.SetFlashAlpha then
		return
	end
	
	-- Gold color for level-up flash (different from XP gain)
	self.animationState.flashingXPGain = true
	self.animationState.flashStartTime = GetTime()
	self.animationState.flashDuration = 1.0 * speedMultiplier
	self.animationState.isLevelUpFlash = true  -- Mark as level-up flash
	
	-- Start flash animation
	if not self:GetScript("OnUpdate") then
		self:SetScript("OnUpdate", self.OnAnimationUpdate)
	end
end

-----------------------------------
-- Animation System
-----------------------------------

-- Get animation configuration
function XPC_XPBarMixinBase:GetAnimationConfig()
	local db = Addon.db or {}
	
	-- Validate animationSpeed is a number (fix for corrupted SavedVariables)
	local speed = db.animationSpeed
	if type(speed) ~= "number" then
		speed = ANIMATION_CONSTANTS.DEFAULT_ANIMATION_SPEED
	end
	
	return {
		enabled = db.enableAnimations ~= false, -- Default to enabled
		speed = speed,
		easing = db.animationEasing or "easeOut",
		flashOnGain = db.flashOnGain ~= false, -- Default to enabled
		pauseOnHover = db.pauseOnHover ~= false, -- Default to enabled
	}
end

-- Main animation update (OnUpdate handler)
function XPC_XPBarMixinBase:OnAnimationUpdate(elapsed)
	local now = GetTime()
	
	-- Check if paused
	if self.animationState.pauseUntil > now then
		return
	end
	
	-- Update flash effect
	if self.animationState.flashingXPGain then
		self:UpdateFlashEffect(now, elapsed)
	end
	
	-- Update bar fill animation
	if self.animationState.animating then
		self:UpdateBarAnimation(now, elapsed)
	end
	
	-- Stop OnUpdate if nothing is animating
	if not self.animationState.animating and not self.animationState.flashingXPGain then
		self:SetScript("OnUpdate", nil)
	end
end

-- Start animation to target value
function XPC_XPBarMixinBase:AnimateToValue(targetValue, immediate)
	local config = self:GetAnimationConfig()
	
	if immediate or not config.enabled then
		-- Skip animation, set instantly
		self.animationState.currentValue = targetValue
		self.animationState.targetValue = targetValue
		self.animationState.animating = false
		self:UpdateStatusBarValue(targetValue)
		return
	end
	
	local currentValue = self.animationState.currentValue
	local delta = math.abs(targetValue - currentValue)
	
	if delta < 0.001 then
		-- Already at target (within tolerance)
		return
	end
	
	-- Calculate animation duration based on delta
	local duration = self:CalculateAnimationDuration(delta)
	
	-- If already animating, recalculate duration from current position
	if self.animationState.animating then
		duration = self:CalculateAnimationDuration(targetValue - currentValue)
	end
	
	self.animationState.targetValue = targetValue
	self.animationState.animating = true
	self.animationState.animationStartTime = GetTime()
	self.animationState.animationDuration = duration
	
	-- Start OnUpdate if not already running
	self:SetScript("OnUpdate", self.OnAnimationUpdate)
end

-- Calculate animation duration based on change magnitude
function XPC_XPBarMixinBase:CalculateAnimationDuration(delta)
	local config = self:GetAnimationConfig()
	local constants = ANIMATION_CONSTANTS
	
	local absDelta = math.abs(delta)
	local duration = constants.MIN_ANIMATION_DURATION
	
	if absDelta > 0.1 then
		-- Large change (> 10% of bar)
		duration = constants.MAX_ANIMATION_DURATION
	elseif absDelta > 0.01 then
		-- Medium change (1-10% of bar) - scale duration
		local t = (absDelta - 0.01) / 0.09
		duration = constants.MIN_ANIMATION_DURATION + 
		           (constants.MAX_ANIMATION_DURATION - constants.MIN_ANIMATION_DURATION) * t
	end
	
	-- Apply speed multiplier from config
	duration = duration / config.speed
	
	return duration
end

-- Update bar fill animation
function XPC_XPBarMixinBase:UpdateBarAnimation(now, elapsed)
	local state = self.animationState
	local elapsed_since_start = now - state.animationStartTime
	
	if elapsed_since_start >= state.animationDuration then
		-- Animation complete
		state.currentValue = state.targetValue
		state.animating = false
		self:UpdateStatusBarValue(state.currentValue)
		return
	end
	
	-- Calculate progress (0 to 1)
	local progress = elapsed_since_start / state.animationDuration
	
	-- Apply easing
	progress = self:ApplyEasing(progress)
	
	-- Interpolate current value
	-- Note: We need to handle the case where animation started from a previous value
	local startValue = state.currentValue
	if elapsed_since_start < 0.016 then -- First frame (~60 FPS)
		-- Capture the starting value on first frame
		state.animationStartValue = state.currentValue
	end
	
	startValue = state.animationStartValue or state.currentValue
	local targetValue = state.targetValue
	state.currentValue = startValue + (targetValue - startValue) * progress
	
	self:UpdateStatusBarValue(state.currentValue)
end

-- Apply easing function to animation progress
function XPC_XPBarMixinBase:ApplyEasing(t)
	local config = self:GetAnimationConfig()
	
	if config.easing == "linear" then
		return t
	elseif config.easing == "easeOut" then
		-- Ease out quad: 1 - (1 - t)^2
		return 1 - math.pow(1 - t, 2)
	elseif config.easing == "easeInOut" then
		-- Ease in-out: smooth acceleration and deceleration
		if t < 0.5 then
			return 2 * t * t
		else
			return 1 - math.pow(-2 * t + 2, 2) / 2
		end
	end
	
	return t -- fallback to linear
end

-- Trigger flash effect on XP gain
function XPC_XPBarMixinBase:TriggerXPGainFlash(isRested)
	local config = self:GetAnimationConfig()
	
	if not config.flashOnGain then
		return
	end
	
	local constants = ANIMATION_CONSTANTS
	
	self.animationState.flashingXPGain = true
	self.animationState.flashStartTime = GetTime()
	self.animationState.flashDuration = constants.GAIN_FLASH_HALF_PERIOD_SECONDS * 2
	self.animationState.isRestedGain = isRested
	
	-- Start OnUpdate if not already running
	self:SetScript("OnUpdate", self.OnAnimationUpdate)
end

-- Update flash effect
function XPC_XPBarMixinBase:UpdateFlashEffect(now, elapsed)
	local state = self.animationState
	local constants = ANIMATION_CONSTANTS
	local elapsed_since_start = now - state.flashStartTime
	
	if elapsed_since_start >= state.flashDuration then
		-- Flash complete
		state.flashingXPGain = false
		if self.SetFlashAlpha then
			self:SetFlashAlpha(0)
		end
		return
	end
	
	-- Calculate flash alpha (triangle wave: fade in, then fade out)
	local halfPeriod = constants.GAIN_FLASH_HALF_PERIOD_SECONDS
	local alpha
	
	if elapsed_since_start < halfPeriod then
		-- Fade in
		alpha = (elapsed_since_start / halfPeriod) * constants.GAIN_FLASH_MAX_ALPHA
	else
		-- Fade out
		local fadeProgress = (elapsed_since_start - halfPeriod) / halfPeriod
		alpha = (1 - fadeProgress) * constants.GAIN_FLASH_MAX_ALPHA
	end
	
	if self.SetFlashAlpha then
		self:SetFlashAlpha(alpha)
	end
end

-- Pause animation on mouseover
function XPC_XPBarMixinBase:PauseAnimation()
	local config = self:GetAnimationConfig()
	if config.pauseOnHover then
		local constants = ANIMATION_CONSTANTS
		self.animationState.pauseUntil = GetTime() + constants.PAUSE_SECONDS
	end
end

-- Resume animation (pause expires automatically)
function XPC_XPBarMixinBase:ResumeAnimation()
	-- Pause will expire naturally based on pauseUntil timestamp
end

-- Abstract method for bar-specific flash implementation
function XPC_XPBarMixinBase:SetFlashAlpha(alpha)
	-- Override in bar-specific mixins
end

-- Public API for external control
function XPC_XPBarMixinBase:Show()
	if self:GetParent() then
		self:GetParent():Show()
	end
	self:FullUpdate()
end

function XPC_XPBarMixinBase:Hide()
	if self:GetParent() then
		self:GetParent():Hide()
	end
end

function XPC_XPBarMixinBase:Toggle()
	local container = self:GetParent()
	if container then
		if container:IsShown() then
			container:Hide()
		else
			container:Show()
			self:FullUpdate()
		end
	end
end

-----------------------------------
-- Text Overlay System
-----------------------------------

function XPC_XPBarMixinBase:UpdateTextVisibility()
	-- Ensure text elements are wired (safety check for timing issues)
	local parent = self:GetParent()
	if parent and parent.WireTextElements then
		parent:WireTextElements()
	end
	
	-- Get configuration from SavedVariables (or defaults)
	local db = Addon.db or {}

	-- On-bar text elements
	if self.LevelText then
		-- Level text: no existing option, default to false
		self.LevelText:SetShown(db.showLevelText == true)
	end
	if self.XPText then
		-- XP text: no existing option, default to false
		self.XPText:SetShown(db.showXPText == true)
	end
	if self.PercentText then
		-- Percent text: maps to existing showPercentage option
		self.PercentText:SetShown(db.showPercentage == true)
	end

	-- Below-bar text elements (each controlled by its own option)
	if self.RateText then
		-- Rate text (XP/hour + time to level): show if either showXPPerHourText or showTimeToLevelText is enabled
		local showRate = (db.showXPPerHourText == true) or (db.showTimeToLevelText == true)
		self.RateText:SetShown(showRate)
	end
	if self.SessionText then
		-- Session text: show if either showLevelTimeText or showSessionTimeText is enabled
		local showSession = (db.showLevelTimeText == true) or (db.showSessionTimeText == true)
		self.SessionText:SetShown(showSession)
	end
	if self.QuestSummaryText then
		-- Quest summary text: controlled by showQuestXP option
		self.QuestSummaryText:SetShown(db.showQuestXP == true)
	end
end

function XPC_XPBarMixinBase:UpdateAllText()
	if not XPC_XPBarTextFormatter then
		return
	end

	self:UpdateLevelText()
	self:UpdateXPText()
	self:UpdatePercentText()
	self:UpdateRateText()
	self:UpdateSessionText()
	self:UpdateQuestSummaryText()
end

function XPC_XPBarMixinBase:UpdateLevelText()
	if not self.LevelText or not self.LevelText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local level = self.state.level or UnitLevel("player")
	local text = XPC_XPBarTextFormatter:GetLevelText(level)
	self.LevelText:SetText(text)
end

function XPC_XPBarMixinBase:UpdateXPText()
	if not self.XPText or not self.XPText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local abbreviate = db.abbreviateNumbers ~= false -- Default true
	local showRemaining = db.showRemainingXP == true -- Default false

	local text = XPC_XPBarTextFormatter:GetXPText(self.state.currentXP, self.state.maxXP, abbreviate, showRemaining)
	self.XPText:SetText(text)
end

function XPC_XPBarMixinBase:UpdatePercentText()
	if not self.PercentText then
		return
	end
	if not self.PercentText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local decimals = db.percentDecimals or 1
	local showQuestPercent = db.showQuestPercent == true

	-- Get quest XP from service based on overlay settings
	local questXP = 0
	if showQuestPercent and Addon.XPBar then
		-- GetQuestXP() returns: totalQuestXP, completeQuestXP, incompleteQuestXP
		local totalXP, completeXP, incompleteXP = Addon.XPBar:GetQuestXP()
		
		-- Respect overlay settings to determine which quest XP to include
		local showComplete = db.showCompleteQuestOverlay ~= false -- Default true
		local showIncomplete = db.showIncompleteQuestOverlay == true -- Default false
		
		questXP = 0
		if showComplete then
			questXP = questXP + (completeXP or 0)
		end
		if showIncomplete then
			questXP = questXP + (incompleteXP or 0)
		end
	end

	local text =
		XPC_XPBarTextFormatter:GetPercentText(self.state.currentXP, self.state.maxXP, decimals, showQuestPercent, questXP)

	self.PercentText:SetText(text)
end

function XPC_XPBarMixinBase:UpdateRateText()
	if not self.RateText or not self.RateText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local abbreviate = db.abbreviateNumbers ~= false
	
	-- Check which rate stats to show based on individual settings
	local showXPPerHour = db.showXPPerHourText == true
	local showTimeToLevel = db.showTimeToLevelText == true

	-- Get XP rate and time to level from session service
	local xpPerHour = 0
	local timeToLevel = 0
	local hasSessionData = false
	local hasLevelData = false

	if Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			local sessionTime = time() - (session.sessionStart or time())
			local gainedXP = session.gainedXP or 0

			-- Priority 1: Use session data if we have meaningful time (at least 10 seconds)
			if sessionTime >= 10 and gainedXP > 0 then
				hasSessionData = true
				xpPerHour = math.floor((gainedXP / sessionTime) * 3600)

				-- Calculate time to level
				local remainingXP = self.state.maxXP - self.state.currentXP
				if xpPerHour > 0 and remainingXP > 0 then
					timeToLevel = math.floor((remainingXP / xpPerHour) * 3600)
				end
			-- Priority 2: Fallback to current level data if available
			elseif session.realLevelTime and session.realLevelTime > 0 then
				local levelTime = session.realLevelTime
				-- Add elapsed time since last TIME_PLAYED_MSG for real-time updates
				if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
					local elapsed = time() - session.lastTimePlayedRequest
					levelTime = levelTime + elapsed
				end
				
				-- Calculate XP/hour based on current level progress
				local currentXP = self.state.currentXP
				if levelTime > 0 and currentXP > 0 then
					hasLevelData = true
					xpPerHour = math.floor((currentXP / levelTime) * 3600)
					
					-- Calculate time to level based on current level rate
					local remainingXP = self.state.maxXP - currentXP
					if xpPerHour > 0 and remainingXP > 0 then
						timeToLevel = math.floor((remainingXP / xpPerHour) * 3600)
					end
				end
			end
		end
	end

	-- Build text based on what's enabled
	local parts = {}
	
	if showXPPerHour then
		if hasSessionData or hasLevelData then
			local ratePart = XPC_XPBarTextFormatter:GetXPRateText(xpPerHour, abbreviate)
			if ratePart and ratePart ~= "" and ratePart ~= "Calculating..." then
				table.insert(parts, ratePart)
			end
		end
		-- Don't show anything if we have no data yet
	end
	
	if showTimeToLevel then
		if (hasSessionData or hasLevelData) and timeToLevel > 0 then
			local timePart = XPC_XPBarTextFormatter:GetTimeToLevelText(timeToLevel)
			if timePart and timePart ~= "" and timePart ~= "N/A" then
				table.insert(parts, "Leveling in: " .. timePart)
			end
		end
		-- Don't show anything if we have no data yet
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.RateText:SetText(text)
end

function XPC_XPBarMixinBase:UpdateSessionText()
	if not self.SessionText or not self.SessionText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local sessionSeconds = 0
	local levelSeconds = 0

	-- Check which times to show based on individual settings
	local showSessionTime = db.showSessionTimeText == true
	local showLevelTime = db.showLevelTimeText == true

	if Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			-- Use session time if enabled
			if showSessionTime and session.sessionStart then
				sessionSeconds = time() - session.sessionStart
			end

			-- Use realLevelTime from TIME_PLAYED_MSG if available (accurate server-side time)
			-- Fall back to showing 0 if not available
			if showLevelTime then
				if session.realLevelTime and session.realLevelTime > 0 then
					-- Add elapsed time since last TIME_PLAYED_MSG for real-time updates
					levelSeconds = session.realLevelTime
					if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
						local elapsed = time() - session.lastTimePlayedRequest
						levelSeconds = levelSeconds + elapsed
					end
				end
			end
		end
	end

	-- Build text based on what's enabled
	local parts = {}

	if showSessionTime then
		if sessionSeconds > 0 then
			local sessionPart = XPC_XPBarTextFormatter:GetSessionTimeText(sessionSeconds, "Session")
			if sessionPart ~= "" then
				table.insert(parts, sessionPart)
			end
		end
		-- Don't show anything if session is 0s (just started)
	end

	if showLevelTime then
		if levelSeconds > 0 then
			local levelPart = XPC_XPBarTextFormatter:GetLevelTimeText(levelSeconds, "This Level")
			if levelPart ~= "" then
				table.insert(parts, levelPart)
			end
		end
		-- Don't show anything if we don't have level time data yet
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.SessionText:SetText(text)
end

function XPC_XPBarMixinBase:UpdateQuestSummaryText()
	if not self.QuestSummaryText or not self.QuestSummaryText:IsShown() then
		return
	end
	if not XPC_XPBarTextFormatter then
		return
	end

	local totalQuestXP = 0
	local completeQuestXP = 0
	local incompleteQuestXP = 0

	if Addon.XPBar then
		totalQuestXP, completeQuestXP, incompleteQuestXP = Addon.XPBar:GetQuestXP()
	end

	local db = Addon.db or {}
	local decimals = db.percentDecimals or 1

	local text =
		XPC_XPBarTextFormatter:GetQuestSummaryText(
		completeQuestXP,
		incompleteQuestXP,
		totalQuestXP,
		self.state.maxXP,
		self.state.restedXP,
		decimals
	)
	self.QuestSummaryText:SetText(text)
end

-- Tooltip handlers
function XPC_XPBarMixinBase:OnEnter()
	-- Pause animation on mouseover
	self:PauseAnimation()
	
	if XPC_XPBarTooltip then
		XPC_XPBarTooltip:Show(self, "ANCHOR_TOP")
	end
end

function XPC_XPBarMixinBase:OnLeave()
	-- Resume animation (pause will expire automatically)
	self:ResumeAnimation()
	
	if XPC_XPBarTooltip then
		XPC_XPBarTooltip:Hide()
	end
end

-----------------------------------
-- Quest Overlay System
-----------------------------------

-- Initialize quest overlay state
function XPC_XPBarMixinBase:InitializeQuestOverlays()
	self.questState = {
		completeQuestXP = 0,
		incompleteQuestXP = 0,
		totalQuestXP = 0,
		completeCount = 0,
		incompleteCount = 0,
	}
end

-----------------------------------
-- Event Handlers (Called directly by controller)
-----------------------------------

-- Handle XP_CHANGED event
function XPC_XPBarMixinBase:OnXPChangedEvent(data)
	-- Update state
	self.state.currentXP = data.currentXP
	self.state.maxXP = data.maxXP
	self.state.level = data.level
	
	-- Update UI
	self:UpdateXP()
	self:UpdateRestedOverlay()
	self:UpdateAllText()
end

-- Handle XP_GAINED event
function XPC_XPBarMixinBase:OnXPGainedEvent(data)
	-- Trigger XP gain flash if enabled
	if not Addon.db or Addon.db.flashOnXPGain ~= false then
		self:TriggerXPGainFlash(data.isRested)
	end
end

-- Handle LEVEL_UP event
function XPC_XPBarMixinBase:OnLevelUpEvent(data)
	-- Update level
	self.state.level = data.newLevel
	
	-- Trigger celebration if enabled
	if Addon.db and Addon.db.levelUpCelebration ~= false then
		self:TriggerLevelUpCelebration()
	end
	
	-- Update UI
	self:UpdateAllText()
end

-- Handle RESTED_CHANGED event
function XPC_XPBarMixinBase:OnRestedChangedEvent(data)
	-- Update rested XP
	self.state.restedXP = data.restedXP or 0
	
	-- Update rested overlay
	self:UpdateRestedOverlay()
end

-- Handle QUEST_XP_UPDATED event
function XPC_XPBarMixinBase:OnQuestXPUpdatedEvent(data)
	-- Update quest overlays
	self:UpdateQuestOverlays()
end

-- Handle TEXT_SETTINGS_CHANGED event
function XPC_XPBarMixinBase:OnTextSettingsChangedEvent(data)
	-- Update text visibility and fonts
	self:UpdateTextVisibility()
	self:ApplyTextSettings()
	self:UpdateAllText()
end

-- Handle COLORS_CHANGED event
function XPC_XPBarMixinBase:OnColorsChangedEvent(data)
	-- Update all bar colors
	self:UpdateBarOverlayColors()
	self:UpdateAllText()
end

-- Register quest events
function XPC_XPBarMixinBase:RegisterQuestEvents()
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("QUEST_REMOVED")
	self:RegisterEvent("QUEST_TURNED_IN")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end

-- Get quest overlay configuration
function XPC_XPBarMixinBase:GetQuestOverlayConfig()
	local db = Addon.db or {}
	
	-- Get configuration from SavedVariables
	-- showQuestXP is the master toggle for all quest-related features (overlays + text)
	return {
		enabled = db.showQuestXP ~= false,  -- Default: true (master toggle)
		showComplete = db.showCompleteQuestOverlay ~= false,  -- Default: true
		showIncomplete = db.showIncompleteQuestOverlay == true,  -- Default: false
	}
end

-- Update quest overlays with improved positioning logic
function XPC_XPBarMixinBase:UpdateQuestOverlays()
	local config = self:GetQuestOverlayConfig()
	
	if not config.enabled then
		self:HideQuestOverlays()
		return
	end
	
	-- Get quest XP from service
	if not Addon.XPBar then
		self:HideQuestOverlays()
		return
	end
	
	local totalQuestXP, completeQuestXP, incompleteQuestXP = Addon.XPBar:GetQuestXP()
	local completeCount, incompleteCount = Addon.XPBar:GetQuestCounts()
	
	-- Update state
	self.questState.completeQuestXP = completeQuestXP
	self.questState.incompleteQuestXP = incompleteQuestXP
	self.questState.totalQuestXP = totalQuestXP
	self.questState.completeCount = completeCount
	self.questState.incompleteCount = incompleteCount
	
	-- Calculate overlay widths and positions
	local currentXP = self.state.currentXP
	local maxXP = self.state.maxXP
	
	if maxXP <= 0 then
		self:HideQuestOverlays()
		return
	end
	
	-- Calculate how much XP space is remaining on the bar (prevent negative)
	local remainingXP = math.max(0, maxXP - currentXP)
	
	-- Complete quest overlay: starts at currentXP, extends by completeQuestXP
	-- BUT clamped to not exceed bar width
	local completeXPToShow = math.min(completeQuestXP, remainingXP)
	local completePercent = completeXPToShow / maxXP
	local completeOffset = 0  -- No offset, starts at current XP position
	
	-- Incomplete quest overlay: starts after complete quests
	-- BUT also clamped to not exceed bar width
	local spaceAfterComplete = math.max(0, remainingXP - completeXPToShow)
	local incompleteXPToShow = math.min(incompleteQuestXP, spaceAfterComplete)
	local incompletePercent = incompleteXPToShow / maxXP
	local incompleteOffset = completeXPToShow  -- Offset by ACTUAL complete quest shown (not total)
	
	-- Update overlay visuals with positioning (only show if there's something to display)
	local showComplete = config.showComplete and completeQuestXP > 0 and completeXPToShow > 0 and completePercent > 0 and remainingXP > 0
	-- DISABLED: Incomplete quest overlay temporarily disabled for debugging
	local showIncomplete = false -- config.showIncomplete and incompleteQuestXP > 0 and incompleteXPToShow > 0 and incompletePercent > 0 and spaceAfterComplete > 0
	
	self:SetCompleteQuestOverlay(completePercent, completeOffset, showComplete)
	self:SetIncompleteQuestOverlay(incompletePercent, incompleteOffset, showIncomplete)
	
	-- Update rested overlay to account for quest overlays
	self:UpdateRestedWithQuestOffset()
end

-- Abstract methods (implemented by Legacy/Flat mixins)
function XPC_XPBarMixinBase:SetCompleteQuestOverlay(percent, offset, show)
	-- Override in Legacy/Flat mixins
end

function XPC_XPBarMixinBase:SetIncompleteQuestOverlay(percent, offset, show)
	-- Override in Legacy/Flat mixins
end

function XPC_XPBarMixinBase:HideQuestOverlays()
	self:SetCompleteQuestOverlay(0, 0, false)
	self:SetIncompleteQuestOverlay(0, 0, false)
end

-- Update rested overlay position to account for quest overlays
function XPC_XPBarMixinBase:UpdateRestedWithQuestOffset()
	-- Get quest offset for rested positioning
	-- IMPORTANT: Use the CLAMPED values, not the raw quest XP
	local config = self:GetQuestOverlayConfig()
	local questOffset = 0
	
	if config.enabled then
		local currentXP = self.state.currentXP
		local maxXP = self.state.maxXP
		local remainingXP = math.max(0, maxXP - currentXP)
		
		if config.showComplete then
			-- Use clamped complete quest XP (what's actually shown)
			local completeXPToShow = math.min(self.questState.completeQuestXP or 0, remainingXP)
			questOffset = questOffset + completeXPToShow
			remainingXP = math.max(0, remainingXP - completeXPToShow)
		end
		
		if config.showIncomplete then
			-- Use clamped incomplete quest XP (what's actually shown)
			local incompleteXPToShow = math.min(self.questState.incompleteQuestXP or 0, remainingXP)
			questOffset = questOffset + incompleteXPToShow
		end
	end
	
	-- Store offset for use in rested calculation
	self.questOffsetForRested = questOffset
	
	-- Update rested overlay with new offset
	self:UpdateRested()
end


-----------------------------------
-- New Architecture: State → Layout → Rendering
-----------------------------------

-- Layer 1: Calculate bar state (pure data, no UI)
function XPC_XPBarMixinBase:CalculateBarState()
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local restedXP = GetXPExhaustion() or 0
	local level = UnitLevel("player")
	
	-- Get quest XP from service
	local config = self:GetQuestOverlayConfig()
	local completeQuestXP = 0
	local incompleteQuestXP = 0
	
	if config.enabled and Addon.XPBar then
		local total, complete, incomplete = Addon.XPBar:GetQuestXP()
		completeQuestXP = config.showComplete and complete or 0
		incompleteQuestXP = config.showIncomplete and incomplete or 0
	end
	
	-- Return pure state (no pixels, no percentages yet)
	return {
		currentXP = currentXP,
		maxXP = maxXP,
		restedXP = restedXP,
		level = level,
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
	}
end

-- Layer 2: Calculate layout (percentages and pixels, still generic)
function XPC_XPBarMixinBase:CalculateBarLayout(state)
	local maxXP = state.maxXP
	
	if maxXP <= 0 then
		return { visible = false }
	end
	
	-- Calculate segments in order: current → quest complete → quest incomplete → rested
	local remainingXP = math.max(0, maxXP - state.currentXP)
	
	-- Current XP (the filled portion)
	local currentRatio = state.currentXP / maxXP
	
	-- Complete quest overlay (starts after current XP)
	local completeXPClamped = math.min(state.completeQuestXP, remainingXP)
	local completeRatio = completeXPClamped / maxXP
	
	-- Incomplete quest overlay (starts after complete quests)
	remainingXP = math.max(0, remainingXP - completeXPClamped)
	local incompleteXPClamped = math.min(state.incompleteQuestXP, remainingXP)
	local incompleteRatio = incompleteXPClamped / maxXP
	local incompleteOffsetXP = completeXPClamped
	
	-- Rested overlay (starts after quests)
	remainingXP = math.max(0, remainingXP - incompleteXPClamped)
	local restedXPClamped = math.min(state.restedXP, remainingXP)
	local restedRatio = restedXPClamped / maxXP
	local restedOffsetXP = completeXPClamped + incompleteXPClamped
	
	-- Calculate total for fully rested check
	local totalWithAllOverlays = state.currentXP + completeXPClamped + incompleteXPClamped + restedXPClamped
	local isFullyRested = totalWithAllOverlays >= maxXP
	
	-- Calculate pixel values
	local currentPixels = math.floor(currentRatio * BAR_WIDTH)
	
	-- Build layout structure
	return {
		visible = true,
		current = {
			ratio = currentRatio,
			pixels = currentPixels,
		},
		questComplete = {
			visible = completeXPClamped > 0,
			ratio = completeRatio,
			pixels = math.max(1, math.floor(completeRatio * BAR_WIDTH)),
			offsetXP = state.currentXP,
			offsetPixels = currentPixels,
		},
		questIncomplete = {
			visible = incompleteXPClamped > 0,
			ratio = incompleteRatio,
			pixels = math.max(1, math.floor(incompleteRatio * BAR_WIDTH)),
			offsetXP = state.currentXP + incompleteOffsetXP,
			offsetPixels = currentPixels + math.floor((incompleteOffsetXP / maxXP) * BAR_WIDTH),
		},
		rested = {
			visible = restedXPClamped > 0,
			ratio = restedRatio,
			pixels = math.max(1, math.floor(restedRatio * BAR_WIDTH)),
			offsetXP = state.currentXP + restedOffsetXP,
			offsetPixels = currentPixels + math.floor((restedOffsetXP / maxXP) * BAR_WIDTH),
			isFullyRested = isFullyRested,
			showTick = restedRatio >= 0.01 and restedRatio <= 0.99,
		},
	}
end

-- Unified update method (replaces fragmented updates)
function XPC_XPBarMixinBase:UpdateBarDisplay()
	-- Check container visibility (max level setting)
	local container = self:GetParent()
	if container then
		local atMaxLevel = self:IsPlayerAtMaxLevel()
		local showAtMax = Addon.db.showBarAtMaxLevel ~= false
		
		-- Only HIDE if at max level and user doesn't want to see it
		-- Never SHOW - that's the controller's job via SetBarStyle()
		if atMaxLevel and not showAtMax then
			container:Hide()
			return
		end
	end
	
	-- Calculate what to show (state)
	local state = self:CalculateBarState()
	
	-- Store state for other uses (text overlays, etc.)
	self.state.currentXP = state.currentXP
	self.state.maxXP = state.maxXP
	self.state.restedXP = state.restedXP
	self.state.level = state.level
	self.state.isRested = (state.restedXP and state.restedXP > 0) or false
	
	-- Calculate how to layout (percentages and pixels)
	local layout = self:CalculateBarLayout(state)
	
	-- Apply to UI (bar-specific implementation)
	self:ApplyLayout(layout)
end

-----------------------------------
-- Utility Functions
-----------------------------------
XPC_XPBarMixinBase.GetBarDimensions = function()
	return BAR_WIDTH, BAR_HEIGHT
end

XPC_XPBarMixinBase.GetContainerDimensions = function()
	return CONTAINER_WIDTH, CONTAINER_HEIGHT
end

function XPC_XPBarMixinBase:IsPlayerAtMaxLevel()
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or UnitLevel("player")
	local expansionMax = GetMaxLevelForExpansionLevel and GetMaxLevelForExpansionLevel(GetExpansionLevel()) or maxLevel
	return UnitLevel("player") >= math.min(maxLevel, expansionMax)
end
