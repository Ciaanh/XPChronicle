-- XP Bar Enhanced - XP Bar Mixin Base (Shared Logic)
-- Contains common functionality used by both Legacy and Flat XP bar implementations

local Addon = XPBarEnhanced

-- Note: Color constants and XPBarColors compatibility layer
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
	MIN_ANIMATION_DURATION = 0.5,
	MAX_ANIMATION_DURATION = 3.0,
}

-----------------------------------
-- Base Mixin (Shared Logic)
-----------------------------------
local XPBarMixinBase = {}

-- Local alias for optional tooltip module (may be defined elsewhere)
local XPBarTooltip = _G and _G.XPBarTooltip

-- Initialize shared state
function XPBarMixinBase:InitializeState()
	self.state = {
		currentXP = 0,
		maxXP = 1,
		restedXP = 0,
		level = 1,
		maxLevel = 1,
	}

	-- Re-entrancy guard & scheduling state
	self._isUpdating = false
	self._fullUpdateScheduled = nil

	-- Capture the current effective level cap for later comparisons
	self.state.maxLevel = self:GetEffectiveMaxLevel()

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
function XPBarMixinBase:InitializeAnimationState()
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

	-- Ensure a single global animation driver exists to tick animations.
	-- This avoids per-bar OnUpdate conflicts where other code replaces frame OnUpdate,
	-- causing our animation updates to be skipped.
	if not Addon._AnimationDriver then
		local driver = CreateFrame("Frame", "XPBarEnhanced_AnimationDriver", UIParent)
		driver.bars = {}
		function driver:AddBar(bar)
			self.bars[bar] = true
			bar._xpbar_driverRegistered = true
			-- Ensure OnUpdate is active
			if not self._isRunning then
				self:SetScript("OnUpdate", function(frame, elapsed)
					-- Iterate copy to avoid modification during iteration
					for b, _ in pairs(frame.bars) do
						-- Safely call the animation update for each bar
						pcall(XPBarMixinBase.OnAnimationUpdate, b, elapsed)
					end
				end)
				self._isRunning = true
			end
		end
		function driver:RemoveBar(bar)
			self.bars[bar] = nil
			bar._xpbar_driverRegistered = nil
			-- If no bars left, stop the OnUpdate to avoid extra work
			for _ in pairs(self.bars) do
				return
			end
			if self._isRunning then
				self:SetScript("OnUpdate", nil)
				self._isRunning = nil
			end
		end
		Addon._AnimationDriver = driver
	end
end

-- Initialize text overlay system
function XPBarMixinBase:InitializeTextSystem()
	-- Defer a small amount so SavedVariables and other modules are available.
	if self._textInitTimer then
		pcall(function() self._textInitTimer:Cancel() end)
		self._textInitTimer = nil
	end

	self._textInitTimer = C_Timer.NewTimer(0.1, function()
		if not self or not self.UpdateTextVisibility then
			self._textInitTimer = nil
			return
		end

		-- Only update if frame is shown to avoid unnecessary work for hidden views
		if not self:IsShown() then
			self._textInitTimer = nil
			return
		end

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

		-- Clear timer reference
		self._textInitTimer = nil
	end)
end

-- Register common events
function XPBarMixinBase:RegisterCommonEvents()
	-- Avoid re-registering events
	if self._eventsRegistered then
		return
	end

	self:RegisterEvent("PLAYER_XP_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("UPDATE_EXHAUSTION")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")
    
	-- Quest events for overlays
	if self.RegisterQuestEvents then
		self:RegisterQuestEvents()
	end

	self._eventsRegistered = true
end

function XPBarMixinBase:UnsubscribeFromEvents()
	-- Unregister common events
	pcall(function()
		self:UnregisterEvent("PLAYER_XP_UPDATE")
		self:UnregisterEvent("PLAYER_LEVEL_UP")
		self:UnregisterEvent("UPDATE_EXHAUSTION")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("PLAYER_UPDATE_RESTING")
		self:UnregisterEvent("TIME_PLAYED_MSG")
	end)

	-- If mixin registered quest events, unregister them too
	pcall(function()
		self:UnregisterEvent("QUEST_ACCEPTED")
		self:UnregisterEvent("QUEST_REMOVED")
		self:UnregisterEvent("QUEST_TURNED_IN")
		self:UnregisterEvent("QUEST_LOG_UPDATE")
		self:UnregisterEvent("UNIT_QUEST_LOG_CHANGED")
	end)

	self._eventsRegistered = false
end

-- Common event handler
function XPBarMixinBase:HandleEvent(event, ...)
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
		-- Only update the currently active view on entering world; other views
		-- should not perform full updates which may reveal their containers.
		local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
		if activeView == self then
			self:FullUpdate()
		end
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

function XPBarMixinBase:FullUpdate()
	-- Prevent re-entrant FullUpdate calls
	if self._isUpdating then
		return
	end
	self._isUpdating = true

	-- Refresh the cached level cap so toggling between expansions works
	self.state.maxLevel = self:GetEffectiveMaxLevel()

	-- Honor user preference for hiding the bar at max level
	if self:IsPlayerAtMaxLevel() and (Addon.db and Addon.db.showBarAtMaxLevel == false) then
		local parent = self:GetParent()
		if parent then
			parent:Hide()
		end
		self._isUpdating = nil
		return
	end

	-- Ensure the active container is visible when the bar should render
	local parent = self:GetParent()
	if parent and parent ~= UIParent then
		local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
		if activeView == self and not parent:IsShown() then
			parent:Show()
		end
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

	-- Finished update
	self._isUpdating = nil
end

-- Update XP values
function XPBarMixinBase:UpdateXP()
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
function XPBarMixinBase:IsRested()
	local restedXP = GetXPExhaustion() or 0
	return restedXP > 0
end

-- Update status bar with current XP (now just sets min/max, animation handles value)
function XPBarMixinBase:UpdateStatusBar()
	if not self.StatusBar then
		return
	end

	local maxXP = self.state.maxXP

	-- Update min/max
	self.StatusBar:SetMinMaxValues(0, 1) -- Work in ratios for smooth animation
end

-- Update status bar value directly (called by animation system)
---Update the status bar display value (expects a ratio between 0 and 1)
function XPBarMixinBase:UpdateStatusBarValue(ratio)
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

-- Set display value (unified interface for all bar types)
-- Blizzard pattern: Each bar type overrides this for bar-specific rendering
function XPBarMixinBase:SetDisplayValue(ratio)
	-- Base implementation: delegate to UpdateStatusBarValue directly
	-- Bar types that don't use StatusBar (e.g., circular) override this method
	self:UpdateStatusBarValue(ratio)
end

-- Get current value (respects continuous animation value)
-- Blizzard pattern: Returns continuousValue during animation, currentValue otherwise
function XPBarMixinBase:GetCurrentDisplayValue()
	-- During animation, return the continuous interpolated value
	if self.continuousValue then
		return self.continuousValue
	end
	
	-- Otherwise return the discrete current value
	local state = self:GetAnimationState()
	return state.currentValue or 0
end

-- Accessor for animation state (keeps callers from reaching into fields directly)
function XPBarMixinBase:GetAnimationState()
	if not self.animationState then
		self:InitializeAnimationState()
	end
	return self.animationState
end

-- Calculate rested XP dimensions (with quest overlay offset support)
function XPBarMixinBase:CalculateRestedDimensions()
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
function XPBarMixinBase:GetRestedState()
	local exhaustionStateID = GetRestState()
	-- exhaustionStateID == 1 is Rested, == 2 is Normal
	local isRested = exhaustionStateID == 1

	return {
		exhaustionStateID = exhaustionStateID,
		isRested = isRested
	}
end

-- Level up handler
function XPBarMixinBase:OnLevelUp(newLevel)
	self.state.level = newLevel
	self.state.maxLevel = self:GetEffectiveMaxLevel()

	-- Cancel any ongoing animations
	self.animationState.animating = false
	self.animationState.flashingXPGain = false
	self:SetScript("OnUpdate", nil)
	
	-- Hide flash
	if self.SetFlashAlpha then
		self:SetFlashAlpha(0)
	end

	-- Check if max level
	if self:IsPlayerAtMaxLevel() and (Addon.db and Addon.db.showBarAtMaxLevel == false) then
		local parent = self:GetParent()
		if parent then
			parent:Hide()
		end
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

function XPBarMixinBase:PlayLevelUpCelebration(newLevel)
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
	
	-- Schedule full bar update after flash (cancelable)
	if self._celebrationTimer then
		pcall(function() self._celebrationTimer:Cancel() end)
		self._celebrationTimer = nil
	end
	self._celebrationTimer = C_Timer.NewTimer(1.0 * speedMultiplier, function()
		if not self or not self:IsShown() or not self.FullUpdate then
			self._celebrationTimer = nil
			return
		end
		self:FullUpdate()
		self._celebrationTimer = nil
	end)
end

-- Cancel and cleanup any pending timers attached to this mixin instance
function XPBarMixinBase:CleanupTimers()
	if self._textInitTimer then
		pcall(function() self._textInitTimer:Cancel() end)
		self._textInitTimer = nil
	end

	if self._celebrationTimer then
		pcall(function() self._celebrationTimer:Cancel() end)
		self._celebrationTimer = nil
	end

	if self._updateDelayTimer then
		pcall(function() self._updateDelayTimer:Cancel() end)
		self._updateDelayTimer = nil
	end

	if self._animationTicker then
		pcall(function() self._animationTicker:Cancel() end)
		self._animationTicker = nil
	end

	if self._dragRetryTimer then
		pcall(function() self._dragRetryTimer:Cancel() end)
		self._dragRetryTimer = nil
	end

	if self._positionRestoreTimer then
		pcall(function() self._positionRestoreTimer:Cancel() end)
		self._positionRestoreTimer = nil
	end
    
	if self._fullUpdateTimer then
		pcall(function() self._fullUpdateTimer:Cancel() end)
		self._fullUpdateTimer = nil
	end
    
	if self._glowUpTimer then
		pcall(function() self._glowUpTimer:Cancel() end)
		self._glowUpTimer = nil
	end

	if self._glowDownTimer then
		pcall(function() self._glowDownTimer:Cancel() end)
		self._glowDownTimer = nil
	end
    
	if self._bounceUpTimer then
		pcall(function() self._bounceUpTimer:Cancel() end)
		self._bounceUpTimer = nil
	end

	if self._bounceDownTimer then
		pcall(function() self._bounceDownTimer:Cancel() end)
		self._bounceDownTimer = nil
	end

	-- ...existing code...
end

function XPBarMixinBase:OnHide()
	-- Ensure timers are canceled and events unsubscribed when hidden
	if self.CleanupTimers then
		self:CleanupTimers()
	end

	if self.UnsubscribeFromEvents then
		self:UnsubscribeFromEvents()
	end

	-- Ensure timers are canceled and events unsubscribed when hidden
	-- (Do not touch animation registry state here; animations are frame-driven in this build.)
end

function XPBarMixinBase:OnShow()
	-- Register events when the frame becomes visible
	if not self._eventsRegistered then
		self:RegisterCommonEvents()
	end

	-- Trigger a full update when shown
	if self.FullUpdate then
		self:FullUpdate()
	end
end

function XPBarMixinBase:TriggerLevelUpFlash(speedMultiplier)
	speedMultiplier = speedMultiplier or 1.0
	
	if not self.SetFlashAlpha then
		return
	end
	
	-- Gold color for level-up flash (different from XP gain)
	self.animationState.flashingXPGain = true
	self.animationState.flashStartTime = GetTime()
	self.animationState.flashDuration = 1.0 * speedMultiplier
	self.animationState.isLevelUpFlash = true  -- Mark as level-up flash
	
	-- Start flash animation (frame-driven)
	if not self:GetScript("OnUpdate") then
		self:SetScript("OnUpdate", self.OnAnimationUpdate)
	end
end

-----------------------------------
-- Animation System
-----------------------------------

-- Get animation configuration
function XPBarMixinBase:GetAnimationConfig()
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
	-- Debug testing hooks (none by default)
	}
end

-- Main animation update (OnUpdate handler)
-- Main animation update (OnUpdate handler)
function XPBarMixinBase:OnAnimationUpdate(elapsed)
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
---Animate the bar to a target ratio value
function XPBarMixinBase:AnimateToValue(targetValue, immediate)
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

	-- If this view is not the active view shown to the user, skip running
	-- a full animation. Updating hidden/inactive views can cause duplicate
	-- AnimateToValue calls across multiple view implementations (e.g.
	-- Vertical vs Circular). Prefer to set their discrete state and avoid
	-- installing hooks or drivers for hidden views.
	if Addon and Addon.XPBar and Addon.XPBar.GetActiveView and Addon.XPBar:GetActiveView() ~= self then
		self.animationState.currentValue = targetValue
		self.animationState.targetValue = targetValue
		self.animationState.animating = false
		-- Update visuals immediately for non-animated view (keeps state in sync)
		pcall(function() self:UpdateStatusBarValue(targetValue) end)
		return
	end
	
	-- If an animation is already in progress for this bar, just update
	-- the target and let the existing animation continue. Simpler path.
	if self.animationState.animating then
		self.targetValue = targetValue
		return
	end	-- Blizzard pattern: Use member variables for animation state
	-- These are NEVER modified during interpolation, ensuring fixed baseline
	self.startValue = self.continuousValue or currentValue
	self.targetValue = targetValue
	self.animationStartTime = GetTime()
	
	-- Calculate animation duration based on delta
	local duration = self:CalculateAnimationDuration(delta)
	
	-- Enforce a small minimum duration so extremely large animationSpeed values
	-- cannot collapse the animation to an instantaneous jump.
	self.animationDuration = math.max(duration, 0.15)

	-- If this is a flat StatusBar view prefer the widget's native smoothing
	-- on clients that support SetStatusBarAnimatedDuration. The full
	-- implementation below installs a temporary SetValue hook and completion
	-- timer so we can block external immediate SetValue calls while the
	-- widget performs its own smoothing.

	-- Ensure underlying StatusBar is set to the start value so overlay animation
	-- has a consistent baseline (flat bars may use native smoothing otherwise).
	if self.startValue and (self.StatusBar) then
		self:UpdateStatusBarValue(self.startValue)
	end

	-- Ensure underlying StatusBar is set to the start value so overlay animation
	-- has a consistent baseline (flat bars use native smoothing).
	if self.startValue and (self.StatusBar) then
		self:UpdateStatusBarValue(self.startValue)
	end

	-- If this is a flat StatusBar, try native smoothing API if available.
	-- If not available, fall through to ticker-based animation.
	if self.isFlatBar and self.StatusBar then
		local hasNativeSmoothing = false
		
		-- Try SetStatusBarAnimatedDuration (note: "Animated" not "Animation")
		if self.StatusBar.SetStatusBarAnimatedDuration then
			self.animationState.animating = true
			self.animationState.targetValue = targetValue
			pcall(function()
				self.StatusBar:SetStatusBarAnimatedDuration(self.animationDuration)
				self.StatusBar:SetValue(targetValue)
			end)
			hasNativeSmoothing = true
		end
		
		if hasNativeSmoothing then
			-- Set completion timer to clear animating flag
			if self._animationCompletionTimer then 
				pcall(function() self._animationCompletionTimer:Cancel() end) 
			end
			self._animationCompletionTimer = C_Timer.NewTimer(self.animationDuration, function()
				self.animationState.animating = false
				self._animationCompletionTimer = nil
			end)
			return
		end
		
		-- If native API not available, fall through to ticker animation below
		-- The ticker will work for flat bars too (calls SetDisplayValue each frame)
	end

	-- Otherwise fall back to per-bar ticker animation driven by UpdateBarAnimation
	self.animationState.animating = true
	self.animationState.targetValue = targetValue
	-- Fallback to ticker-based frame-driven animation for non-flat bars
	self._animationTicker = C_Timer.NewTicker(0.016, function()
		local now = GetTime()
		self:UpdateBarAnimation(now, 0.016)
	end)
end

-- Calculate animation duration based on change magnitude
function XPBarMixinBase:CalculateAnimationDuration(delta)
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

	-- No testing override applied here; keep configured speed
	
	return duration
end

-- Update bar fill animation
-- Blizzard pattern: Interpolate between fixed startValue and targetValue
function XPBarMixinBase:UpdateBarAnimation(now, elapsed)
	local state = self.animationState
	local elapsed_since_start = now - self.animationStartTime
	
	if elapsed_since_start >= self.animationDuration then
		-- Animation complete
		self.continuousValue = self.targetValue
		state.currentValue = self.targetValue
		state.animating = false

		-- Delegate to bar-specific rendering (mark internal)
		self._xpbar_isAnimatingSet = true
		self:SetDisplayValue(self.targetValue)
		self._xpbar_isAnimatingSet = nil

		-- If an external SetValue was attempted while animating, apply it now
		local sb = self.StatusBar
		if sb and sb._xpbar_pendingExternal ~= nil and sb._xpbar_origSetValue then
			local pending = sb._xpbar_pendingExternal
			sb._xpbar_pendingExternal = nil
			pcall(function() sb._xpbar_origSetValue(sb, pending) end)
		end

		-- Cancel per-bar ticker/completion timer if present
		if self._animationTicker then
			pcall(function() self._animationTicker:Cancel() end)
			self._animationTicker = nil
		end
		if self._animationCompletionTimer then
			pcall(function() self._animationCompletionTimer:Cancel() end)
			self._animationCompletionTimer = nil
		end

		-- Unregister this bar from the global animation driver so it stops receiving ticks
		if Addon and Addon._AnimationDriver then
			pcall(function() Addon._AnimationDriver:RemoveBar(self) end)
		end
		
		-- Clean up animation members (Blizzard pattern)
		self.startValue = nil
		self.targetValue = nil
		self.animationStartTime = nil
		self.animationDuration = nil
		
		return
	end
	
	-- Calculate progress (0 to 1)
	local progress = elapsed_since_start / self.animationDuration
	
	-- Apply easing
	progress = self:ApplyEasing(progress)
	
	-- Blizzard pattern: Interpolate from FIXED start to FIXED target
	-- startValue and targetValue are NEVER modified during animation
	self.continuousValue = self.startValue + (self.targetValue - self.startValue) * progress
	
	-- Delegate to bar-specific rendering
	-- Mark that this SetDisplayValue call originates from the animation system
	-- so UpdateStatusBarValue can ignore external direct sets while animating.
	self._xpbar_isAnimatingSet = true
	self:SetDisplayValue(self.continuousValue)
	self._xpbar_isAnimatingSet = nil
end

-- Apply easing function to animation progress
function XPBarMixinBase:ApplyEasing(t)
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
function XPBarMixinBase:TriggerXPGainFlash(isRested)
	local config = self:GetAnimationConfig()
	
	if not config.flashOnGain then
		return
	end
	
	local constants = ANIMATION_CONSTANTS
	
	self.animationState.flashingXPGain = true
	self.animationState.flashStartTime = GetTime()
	self.animationState.flashDuration = constants.GAIN_FLASH_HALF_PERIOD_SECONDS * 2
	self.animationState.isRestedGain = isRested
	
	-- Register with the global animation driver so flash ticks are driven
	if Addon and Addon._AnimationDriver then
		Addon._AnimationDriver:AddBar(self)
	end
end

-- Update flash effect
---Update the alpha used for flash effects. Override in bar-specific mixins.
function XPBarMixinBase:SetFlashAlpha(alpha)
	-- Override in bar-specific mixins
end

function XPBarMixinBase:UpdateFlashEffect(now, elapsed)
	local state = self.animationState
	local constants = ANIMATION_CONSTANTS
	local elapsed_since_start = now - state.flashStartTime
	
	if elapsed_since_start >= state.flashDuration then
		-- Flash complete
		state.flashingXPGain = false
		if self.SetFlashAlpha then
			self:SetFlashAlpha(0)
		end
		-- Unregister from driver if present
		if Addon and Addon._AnimationDriver then
			pcall(function() Addon._AnimationDriver:RemoveBar(self) end)
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
function XPBarMixinBase:PauseAnimation()
	local config = self:GetAnimationConfig()
	if config.pauseOnHover then
		local constants = ANIMATION_CONSTANTS
		self.animationState.pauseUntil = GetTime() + constants.PAUSE_SECONDS
	end
end

-- Resume animation (pause expires automatically)
function XPBarMixinBase:ResumeAnimation()
	-- Pause will expire naturally based on pauseUntil timestamp
end

-- Abstract method for bar-specific flash implementation (implemented once above)

-- Public API for external control
function XPBarMixinBase:Show()
	local parent = self:GetParent()
	if parent then
		parent:Show()
	end

	-- If a FullUpdate is currently in progress, don't re-enter it.
	if self._isUpdating then
		return
	end

	-- Debounce scheduling to avoid queuing many updates in a single frame.
	if not self._fullUpdateScheduled then
		self._fullUpdateScheduled = true

		if self._fullUpdateTimer then
			pcall(function() self._fullUpdateTimer:Cancel() end)
			self._fullUpdateTimer = nil
		end
		self._fullUpdateTimer = C_Timer.NewTimer(0, function()
			self._fullUpdateScheduled = nil
			if not self or not self.FullUpdate then
				self._fullUpdateTimer = nil
				return
			end
			self:FullUpdate()
			self._fullUpdateTimer = nil
		end)
	end
end

function XPBarMixinBase:Hide()
	if self:GetParent() then
		self:GetParent():Hide()
	end
end

function XPBarMixinBase:Toggle()
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

function XPBarMixinBase:UpdateTextVisibility()
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
		-- Master toggle: show when not explicitly disabled (defaults to true)
		self.QuestSummaryText:SetShown(db.showQuestXP ~= false)
	end
end

function XPBarMixinBase:UpdateAllText()
	if not XPBarTextFormatter then
		return
	end

	self:UpdateLevelText()
	self:UpdateXPText()
	self:UpdatePercentText()
	self:UpdateRateText()
	self:UpdateSessionText()
	self:UpdateQuestSummaryText()
end

function XPBarMixinBase:UpdateLevelText()
	if not self.LevelText or not self.LevelText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local level = self.state.level or UnitLevel("player")
	local text = XPBarTextFormatter:GetLevelText(level)
	self.LevelText:SetText(text)
end

function XPBarMixinBase:UpdateXPText()
	if not self.XPText or not self.XPText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local abbreviate = db.abbreviateNumbers ~= false -- Default true
	local showRemaining = db.showRemainingXP == true -- Default false

	local text = XPBarTextFormatter:GetXPText(self.state.currentXP, self.state.maxXP, abbreviate, showRemaining)
	self.XPText:SetText(text)
end

function XPBarMixinBase:UpdatePercentText()
	if not self.PercentText then
		return
	end
	if not self.PercentText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
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
		XPBarTextFormatter:GetPercentText(self.state.currentXP, self.state.maxXP, decimals, showQuestPercent, questXP)

	self.PercentText:SetText(text)
end

function XPBarMixinBase:UpdateRateText()
	if not self.RateText or not self.RateText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
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
			local ratePart = XPBarTextFormatter:GetXPRateText(xpPerHour, abbreviate)
			if ratePart and ratePart ~= "" and ratePart ~= "Calculating..." then
				table.insert(parts, ratePart)
			end
		end
		-- Don't show anything if we have no data yet
	end
	
	if showTimeToLevel then
		if (hasSessionData or hasLevelData) and timeToLevel > 0 then
			local timePart = XPBarTextFormatter:GetTimeToLevelText(timeToLevel)
			if timePart and timePart ~= "" and timePart ~= "N/A" then
				table.insert(parts, "Leveling in: " .. timePart)
			end
		end
		-- Don't show anything if we have no data yet
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.RateText:SetText(text)
end

function XPBarMixinBase:UpdateSessionText()
	if not self.SessionText or not self.SessionText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
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
			local sessionPart = XPBarTextFormatter:GetSessionTimeText(sessionSeconds, "Session")
			if sessionPart ~= "" then
				table.insert(parts, sessionPart)
			end
		end
		-- Don't show anything if session is 0s (just started)
	end

	if showLevelTime then
		if levelSeconds > 0 then
			local levelPart = XPBarTextFormatter:GetLevelTimeText(levelSeconds, "This Level")
			if levelPart ~= "" then
				table.insert(parts, levelPart)
			end
		end
		-- Don't show anything if we don't have level time data yet
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.SessionText:SetText(text)
end

function XPBarMixinBase:UpdateQuestSummaryText()
	if not self.QuestSummaryText or not self.QuestSummaryText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
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
		XPBarTextFormatter:GetQuestSummaryText(
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
function XPBarMixinBase:OnEnter()
	-- Pause animation on mouseover
	self:PauseAnimation()
    
	if XPBarTooltip then
		XPBarTooltip:Show(self, "ANCHOR_TOP")
	else
		-- Fallback: simple GameTooltip showing XP values
		if GameTooltip and GameTooltip.SetOwner then
			local tooltip = GameTooltip
			GameTooltip_SetDefaultAnchor(tooltip, UIParent)
			local currentXP = UnitXP("player")
			local maxXP = UnitXPMax("player")
			local percent = (maxXP > 0) and math.floor((currentXP / maxXP) * 100) or 0
			tooltip:SetText(string.format("XP: %s / %s (%d%%)", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP), percent), 1, 1, 1)
			tooltip:Show()
		end
	end
end

function XPBarMixinBase:OnLeave()
	-- Resume animation (pause will expire automatically)
	self:ResumeAnimation()
    
	if XPBarTooltip then
		XPBarTooltip:Hide()
	else
		if GameTooltip and GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end
end

-----------------------------------
-- Quest Overlay System
-----------------------------------

-- Initialize quest overlay state
function XPBarMixinBase:InitializeQuestOverlays()
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
function XPBarMixinBase:OnXPChangedEvent(data)
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
function XPBarMixinBase:OnXPGainedEvent(data)
	-- Trigger XP gain flash if enabled
	if not Addon.db or Addon.db.flashOnXPGain ~= false then
		self:TriggerXPGainFlash(data.isRested)
	end
end

-- Handle LEVEL_UP event
function XPBarMixinBase:OnLevelUpEvent(data)
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
function XPBarMixinBase:OnRestedChangedEvent(data)
	-- Update rested XP
	self.state.restedXP = data.restedXP or 0
	
	-- Update rested overlay
	self:UpdateRestedOverlay()
end

-- Handle QUEST_XP_UPDATED event
function XPBarMixinBase:OnQuestXPUpdatedEvent(data)
	-- Update quest XP state and trigger full bar display update
	-- This will recalculate layout and apply all overlays including quest overlays
	if Addon.XPBar then
		local totalQuestXP, completeQuestXP, incompleteQuestXP = Addon.XPBar:GetQuestXP()
		local completeCount, incompleteCount = Addon.XPBar:GetQuestCounts()
		
		-- Update quest state
		self.questState.completeQuestXP = completeQuestXP
		self.questState.incompleteQuestXP = incompleteQuestXP
		self.questState.totalQuestXP = totalQuestXP
		self.questState.completeCount = completeCount
		self.questState.incompleteCount = incompleteCount
	end
	
	-- Trigger full bar update (will recalculate layout and apply all overlays)
	self:UpdateBarDisplay()
end

-- Handle TEXT_SETTINGS_CHANGED event
function XPBarMixinBase:OnTextSettingsChangedEvent(data)
	-- Update text visibility and fonts
	self:UpdateTextVisibility()
	self:ApplyTextSettings()
	self:UpdateAllText()
end

-- Handle COLORS_CHANGED event
function XPBarMixinBase:OnColorsChangedEvent(data)
	-- Update all bar colors
	self:UpdateBarOverlayColors()
	self:UpdateAllText()
end

-- Register quest events
function XPBarMixinBase:RegisterQuestEvents()
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("QUEST_REMOVED")
	self:RegisterEvent("QUEST_TURNED_IN")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end

-- Get quest overlay configuration
function XPBarMixinBase:GetQuestOverlayConfig()
	local db = Addon.db or {}
	
	-- Get configuration from SavedVariables
	-- showQuestXP is the master toggle for all quest-related features (overlays + text)
	return {
		enabled = db.showQuestXP ~= false,  -- Default: true (master toggle)
		showComplete = db.showCompleteQuestOverlay ~= false,  -- Default: true
		showIncomplete = db.showIncompleteQuestOverlay == true,  -- Default: false
	}
end

-----------------------------------
-- New Architecture: State → Layout → Rendering
-----------------------------------

-- Layer 1: Calculate bar state (pure data, no UI)
function XPBarMixinBase:CalculateBarState()
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
function XPBarMixinBase:CalculateBarLayout(state)
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
function XPBarMixinBase:UpdateBarDisplay()
	-- Keep the cached max level in sync with the current game state
	self.state.maxLevel = self:GetEffectiveMaxLevel()

	-- Check container visibility (max level setting)
	local container = self:GetParent()
	--print("XPBarMixinBase:UpdateBarDisplay - container:", container)
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
	
	-- Cache and apply layout to UI (bar-specific implementation)
	self._lastLayout = layout
	self:ApplyLayout(layout)
end

-----------------------------------
-- Utility Functions
-----------------------------------
XPBarMixinBase.GetBarDimensions = function()
	return BAR_WIDTH, BAR_HEIGHT
end

XPBarMixinBase.GetContainerDimensions = function()
	return CONTAINER_WIDTH, CONTAINER_HEIGHT
end

-- Compute overlay dimensions (pixels & offsets) from layout data.
-- Generic helper used by all bar styles (Flat horizontal, Vertical, Circular).
-- For horizontal bars, use barWidth; for vertical bars, use barHeight.
function XPBarMixinBase:ComputeOverlayDimensions(layout, barSize)
	barSize = barSize or BAR_WIDTH
	local maxXP = (self and self.state and self.state.maxXP) or (layout and layout.current and 1) or 1
	if not layout or not layout.visible or maxXP <= 0 then
		return {
			completeSize = 0, completeOffset = 0,
			incompleteSize = 0, incompleteOffset = 0,
			restedSize = 0, restedOffset = 0,
		}
	end

	local completeSize = layout.questComplete and math.max(1, math.floor(layout.questComplete.ratio * barSize)) or 0
	local completeOffset = layout.questComplete and math.floor((layout.questComplete.offsetXP / maxXP) * barSize) or 0
	local incompleteSize = layout.questIncomplete and math.max(1, math.floor(layout.questIncomplete.ratio * barSize)) or 0
	local incompleteOffset = layout.questIncomplete and math.floor((layout.questIncomplete.offsetXP / maxXP) * barSize) or 0
	local restedSize = layout.rested and math.max(0, math.floor(layout.rested.ratio * barSize)) or 0
	local restedOffset = layout.rested and math.floor((layout.rested.offsetXP / maxXP) * barSize) or 0

	return {
		completeSize = completeSize, completeOffset = completeOffset,
		incompleteSize = incompleteSize, incompleteOffset = incompleteOffset,
		restedSize = restedSize, restedOffset = restedOffset,
	}
end

function XPBarMixinBase:GetEffectiveMaxLevel()
	local playerCap = GetMaxPlayerLevel and GetMaxPlayerLevel() or nil
	local expansionLevel = GetExpansionLevel and GetExpansionLevel() or nil
	local expansionCap
	if GetMaxLevelForExpansionLevel and expansionLevel ~= nil then
		expansionCap = GetMaxLevelForExpansionLevel(expansionLevel)
	end

	local fallback = playerCap or expansionCap or 80
	if playerCap and expansionCap then
		return math.min(playerCap, expansionCap)
	end

	return fallback
end

function XPBarMixinBase:IsPlayerAtMaxLevel()
	local effectiveCap = self:GetEffectiveMaxLevel()
	return UnitLevel("player") >= effectiveCap
end

-- Export mixin to Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.XPBarMixinBase = XPBarMixinBase
_G.XPBarMixinBase = XPBarMixinBase
