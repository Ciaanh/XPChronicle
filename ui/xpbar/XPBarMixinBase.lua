-- XP Bar Enhanced - XP Bar Mixin Base (Shared Logic)
-- Contains common functionality used by both Legacy and Flat XP bar implementations

local Addon = XPBarEnhanced

-----------------------------------
-- Shared Constants
-----------------------------------
local CONTAINER_WIDTH = 571
local CONTAINER_HEIGHT = 17
local BAR_WIDTH = 565 -- Container - 6
local BAR_HEIGHT = 11 -- Container - 6

-----------------------------------
-- Animation Constants (Simplified Unified System)
-----------------------------------
local ANIMATION_CONSTANTS = {
	-- Flash effect
	GAIN_FLASH_HALF_PERIOD_SECONDS = 0.25,
	GAIN_FLASH_MAX_ALPHA = 0.5,
	PAUSE_SECONDS = 0.5,
	-- Speed configuration
	DEFAULT_ANIMATION_SPEED = 1.0,
	-- Duration bounds (backup values - faster, more responsive feel)
	MIN_ANIMATION_DURATION = 0.3, -- Was 0.5 (backup proven value)
	MAX_ANIMATION_DURATION = 2.0, -- Was 3.0 (backup proven value)
	-- Diff thresholds
	ANIMATION_THRESHOLD = 0.001, -- Minimum change to animate (0.1%)
	INSTANT_THRESHOLD = 0.95, -- Changes >95% are instant
	-- Enforced minimum for visibility
	ENFORCED_MIN_DURATION = 0.25 -- Clearly visible at 60 FPS (15 frames)
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
		maxLevel = 1
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

-- Initialize animation state (Simplified Unified System)
function XPBarMixinBase:InitializeAnimationState()
	-- Single animation state container (no scattered member variables)
	self.animation = {
		-- Bar fill animation
		isAnimating = false,
		startRatio = 0,
		targetRatio = 0,
		startTime = 0,
		duration = 0,
		pauseUntil = 0,
		-- Flash effect
		flashingXPGain = false,
		flashStartTime = 0,
		flashDuration = 0,
		isRestedGain = false,
		-- Previous XP for gain detection
		previousXP = 0,
		-- Optional metadata for style-specific effects
		metadata = nil
	}

	-- Track current displayed ratio (for retargeting)
	self._currentRatio = 0

	-- Initialize a global previous-XP snapshot to avoid race conditions
	-- when PLAYER_XP_UPDATE is dispatched to multiple view frames.
	if Addon and Addon._lastKnownXP == nil then
		Addon._lastKnownXP = UnitXP("player") or 0
	end

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
				self:SetScript(
					"OnUpdate",
					function(frame, elapsed)
						-- Iterate copy to avoid modification during iteration
						for b, _ in pairs(frame.bars) do
							-- Safely call the animation update for each bar
							XPBarMixinBase.OnAnimationUpdate(b, elapsed)
						end
					end
				)
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

-- Return a human-readable style name for logging
function XPBarMixinBase:GetBarStyleName()
	-- Prefer explicit override set by concrete mixins
	if self._barStyle and type(self._barStyle) == "string" then
		return self._barStyle
	end
	-- Common fallbacks based on flags used by mixins
	if self.isFlatBar then
		return "Flat"
	end
	if self.orientation == "VERTICAL" then
		return "Vertical"
	end
	if self.orientation == "CIRCULAR" then
		return "Circular"
	end
	-- As a last resort, use the frame name if available
	if type(self.GetName) == "function" then
		local name = self:GetName()
		if name and name ~= "" then
			return tostring(name)
		end
	end
	return "Unknown"
end

-- Initialize text overlay system
function XPBarMixinBase:InitializeTextSystem()
	-- Defer a small amount so SavedVariables and other modules are available.
	if self._textInitTimer then
		self._textInitTimer:Cancel()
		self._textInitTimer = nil
	end

	self._textInitTimer =
		C_Timer.NewTimer(
		0.1,
		function()
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
		end
	)
end

-- Register common events
function XPBarMixinBase:RegisterCommonEvents()
	-- Avoid re-registering events
	if self._eventsRegistered then
		return
	end

	-- NOTE: PLAYER_XP_UPDATE is now handled centrally by XPBar controller
	-- Individual views no longer register for this event
	-- self:RegisterEvent("PLAYER_XP_UPDATE")  -- REMOVED

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
	self:UnregisterEvent("PLAYER_XP_UPDATE")
	self:UnregisterEvent("PLAYER_LEVEL_UP")
	self:UnregisterEvent("UPDATE_EXHAUSTION")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("PLAYER_UPDATE_RESTING")
	self:UnregisterEvent("TIME_PLAYED_MSG")

	-- If mixin registered quest events, unregister them too
	self:UnregisterEvent("QUEST_ACCEPTED")
	self:UnregisterEvent("QUEST_REMOVED")
	self:UnregisterEvent("QUEST_TURNED_IN")
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	self:UnregisterEvent("UNIT_QUEST_LOG_CHANGED")

	self._eventsRegistered = false
end

-- Common event handler
function XPBarMixinBase:HandleEvent(event, ...)
	if event == "PLAYER_XP_UPDATE" then
		-- Prefer centralized handling via the XPBar controller so that the
		-- immutable context pattern remains the single source of truth.
		if Addon and Addon.XPBar and Addon.XPBar.HandleXPUpdate then
			Addon.XPBar:HandleXPUpdate()
		end
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
	elseif
		event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or
			event == "UNIT_QUEST_LOG_CHANGED"
	 then
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

	-- Initialize previousXP for animation to avoid first-gain jump from 0
	if self.animation then
		if not self.animation.isAnimating then
			self.animation.previousXP = self.state.currentXP or self.animation.previousXP or 0
		end
		-- Ensure global snapshot exists to avoid race conditions
		if Addon and Addon._lastKnownXP == nil then
			Addon._lastKnownXP = self.state.currentXP or 0
		end
	end

	-- Set bar to current position instantly (no animation on load/reload)
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local targetRatio = (maxXP > 0) and (currentXP / maxXP) or 0
	self._currentRatio = targetRatio
	self.animation.previousXP = currentXP
	self:UpdateStatusBarValue(targetRatio)

	-- Update text visibility and content
	self:UpdateTextVisibility()
	self:UpdateAllText()

	-- Finished update
	self._isUpdating = nil
end

-- Animate XP Change with Immutable Context
-- Called by XPBar controller with an immutable context object.
-- This method handles aggregation for rapid XP gains.
function XPBarMixinBase:AnimateXPChange(context)
	-- Context is immutable - never modify it directly
	-- Update state for this view
	self.state.currentXP = context.xpAfter
	self.state.maxXP = context.xpMax

	-- Check if we're currently animating (retargeting scenario)
	if self.animation.isAnimating and self.animation.context then
		-- Aggregate: compute combined gain, keep original xpBefore
		local combinedContext = {
			xpBefore = self.animation.context.xpBefore, -- Keep original start
			xpAfter = context.xpAfter, -- New target
			xpMax = context.xpMax,
			xpGained = context.xpAfter - self.animation.context.xpBefore, -- Total gain
			level = context.level,
			prevLevel = self.animation.context.prevLevel or context.prevLevel,
			isLevelUp = context.isLevelUp or self.animation.context.isLevelUp,
			isRested = context.isRested,
			timestamp = context.timestamp,
			source = "aggregated"
		}
		self.animation.context = combinedContext
	else
		-- First context or no current animation
		self.animation.context = context
	end

	-- Compute ratios from immutable context
	local startRatio = self.animation.context.xpBefore / self.animation.context.xpMax
	local targetRatio = self.animation.context.xpAfter / self.animation.context.xpMax

	-- Trigger flash for XP gain (if not already flashing)
	-- Set flags for fully-rested handling: views can hide the rested overlay
	-- and treat gained XP visually as rested when appropriate.
	self.state.isFullyRested = self.animation.context.isFullyRested or false
	self.animation.isFullyRestedGain = self.animation.context.isFullyRested or false

	if self.animation.context.xpGained > 0 and not self.animation.flashingXPGain then
		-- Pass the 'isRested' argument for regular rested flash coloring. If
		-- this gain qualifies as fully-rested, the view will use the fully-
		-- rested visual path (isFullyRestedGain) during animation.
		self:TriggerXPGainFlash(self.animation.context.isRested)
	end

	-- Pass context directly to AnimateToRatio (no metadata conversion)
	self:AnimateToRatio(targetRatio, self.animation.context)
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
-- Get current displayed value (Simplified Unified System)
function XPBarMixinBase:GetCurrentDisplayValue()
	return self._currentRatio or 0
end

-- Accessor for animation state (for debugging)
function XPBarMixinBase:GetAnimationState()
	if not self.animation then
		self:InitializeAnimationState()
	end
	return self.animation
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
		restedRatio = restedRatio, -- Total ratio including current XP + quests + rested
		restedWidth = actualRestedWidth, -- Width of rested overlay only
		restedFullWidth = restedWidth, -- Full width including offset (for tick positioning)
		questOffset = questOffset, -- Store offset for positioning
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
	self.animation.isAnimating = false
	self.animation.flashingXPGain = false
	if Addon._AnimationDriver then
		Addon._AnimationDriver:RemoveBar(self)
	end

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
		self._celebrationTimer:Cancel()
		self._celebrationTimer = nil
	end
	self._celebrationTimer =
		C_Timer.NewTimer(
		1.0 * speedMultiplier,
		function()
			if not self or not self:IsShown() or not self.FullUpdate then
				self._celebrationTimer = nil
				return
			end
			self:FullUpdate()
			self._celebrationTimer = nil
		end
	)
end

-- Cancel and cleanup any pending timers attached to this mixin instance
function XPBarMixinBase:CleanupTimers()
	if self._textInitTimer then
		self._textInitTimer:Cancel()
		self._textInitTimer = nil
	end

	if self._celebrationTimer then
		self._celebrationTimer:Cancel()
		self._celebrationTimer = nil
	end

	if self._updateDelayTimer then
		self._updateDelayTimer:Cancel()
		self._updateDelayTimer = nil
	end

	if self._animationTicker then
		self._animationTicker:Cancel()
		self._animationTicker = nil
	end

	if self._dragRetryTimer then
		self._dragRetryTimer:Cancel()
		self._dragRetryTimer = nil
	end

	if self._positionRestoreTimer then
		self._positionRestoreTimer:Cancel()
		self._positionRestoreTimer = nil
	end

	if self._fullUpdateTimer then
		self._fullUpdateTimer:Cancel()
		self._fullUpdateTimer = nil
	end

	if self._glowUpTimer then
		self._glowUpTimer:Cancel()
		self._glowUpTimer = nil
	end

	if self._glowDownTimer then
		self._glowDownTimer:Cancel()
		self._glowDownTimer = nil
	end

	if self._bounceUpTimer then
		self._bounceUpTimer:Cancel()
		self._bounceUpTimer = nil
	end

	if self._bounceDownTimer then
		self._bounceDownTimer:Cancel()
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
	self.animation.flashingXPGain = true
	self.animation.flashStartTime = GetTime()
	self.animation.flashDuration = 1.0 * speedMultiplier
	self.animation.isLevelUpFlash = true -- Mark as level-up flash

	-- Register with global driver
	if Addon._AnimationDriver then
		Addon._AnimationDriver:AddBar(self)
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
		pauseOnHover = db.pauseOnHover ~= false -- Default to enabled
		-- Debug testing hooks (none by default)
	}
end

-- Main animation update (OnUpdate handler)
-- Main animation update (OnUpdate handler)
-- Frame-driven animation update (Simplified Unified System)
-- Called by global driver every frame for registered bars
function XPBarMixinBase:OnAnimationUpdate(elapsed)
	local now = GetTime()

	-- DEBUG: Print every 60 frames
	self._debugUpdateCount = (self._debugUpdateCount or 0) + 1
	if self._debugUpdateCount % 60 == 0 then
		print(
			string.format(
				"[XPBar Update] frame=%d, animating=%s, flashing=%s",
				self._debugUpdateCount,
				tostring(self.animation.isAnimating),
				tostring(self.animation.flashingXPGain)
			)
		)
	end

	-- Check if paused
	if self.animation.pauseUntil > now then
		return
	end

	-- Update flash effect
	if self.animation.flashingXPGain then
		self:UpdateFlashEffect(now, elapsed)
	end

	-- Update bar fill animation
	if self.animation.isAnimating then
		local elapsed_since_start = now - self.animation.startTime

		if elapsed_since_start >= self.animation.duration then
			-- DON'T unregister yet if flash is still running
			-- (OnAnimationUpdate will handle unregister when both complete)
			-- Animation complete
			self.animation.isAnimating = false
			self._currentRatio = self.animation.targetRatio

			-- Update display to final target
			self:SetDisplayValue(self.animation.targetRatio)

			-- Call completion hook (context will be cleared in OnAnimationComplete)
			local completionData = self.animation.context or self.animation.metadata
			self:OnAnimationComplete(completionData)
		else
			-- Calculate progress with easing
			local progress = math.min(elapsed_since_start / self.animation.duration, 1.0)
			progress = self:ApplyEasing(progress)

			-- Pure Lua interpolation (deterministic, client-independent)
			local currentRatio = self.animation.startRatio + (self.animation.targetRatio - self.animation.startRatio) * progress

			-- Update display (delegates to style-specific rendering)
			self:SetDisplayValue(currentRatio)
			self._currentRatio = currentRatio
		end
	end

	-- Unregister if nothing is animating
	if not self.animation.isAnimating and not self.animation.flashingXPGain then
		if Addon._AnimationDriver then
			Addon._AnimationDriver:RemoveBar(self)
		end
	end
end

-- Start animation to target ratio
-- Main entry point for all bar animations
function XPBarMixinBase:AnimateToRatio(targetRatio, metadata)
	local config = self:GetAnimationConfig()

	-- Use context if available (new path), fall back to metadata (legacy path)
	local context = self.animation.context or metadata
	local currentRatio = self._currentRatio or 0

	-- Compute logical start ratio from context (authoritative source)
	local logicalStartRatio = currentRatio
	if context and context.xpBefore and context.xpMax and context.xpMax > 0 then
		logicalStartRatio = math.min(context.xpBefore / context.xpMax, 1.0)
	end

	-- If retargeting (animation already in progress), use interpolated visual position
	local visualStartRatio = logicalStartRatio
	if self.animation.isAnimating then
		local elapsed = GetTime() - self.animation.startTime
		local progress = math.min(elapsed / self.animation.duration, 1.0)
		progress = self:ApplyEasing(progress)
		visualStartRatio = self.animation.startRatio + (self.animation.targetRatio - self.animation.startRatio) * progress
	elseif logicalStartRatio ~= currentRatio then
		visualStartRatio = logicalStartRatio
	end

	-- Rule: Check if should animate
	local shouldAnimate, reason = self:ShouldAnimateChange(visualStartRatio, targetRatio, config)
	if not shouldAnimate then
		-- Instant update
		self:SetDisplayValue(targetRatio)
		self._currentRatio = targetRatio
		self:OnAnimationComplete(context)
		-- Clear context on completion
		self.animation.context = nil
		return
	end

	-- Calculate duration from visual delta (smooth retargeting)
	local delta = math.abs(targetRatio - visualStartRatio)
	local duration = self:CalculateAnimationDuration(delta, config)

	-- Setup animation state
	self.animation.isAnimating = true
	self.animation.startRatio = visualStartRatio
	self.animation.targetRatio = targetRatio
	self.animation.startTime = GetTime()
	self.animation.duration = duration
	-- Store context reference (already set by AnimateXPChange or converted from metadata)
	if not self.animation.context then
		self.animation.context = metadata -- Legacy fallback
	end

	-- Backward compatibility: Keep metadata field for any legacy code
	self.animation.metadata = metadata or context

	-- Register with global driver (frame-driven interpolation)
	if Addon._AnimationDriver then
		Addon._AnimationDriver:AddBar(self)
	end
end

-- Check if change should be animated (explicit diff rules)
function XPBarMixinBase:ShouldAnimateChange(currentRatio, newRatio, config)
	local constants = ANIMATION_CONSTANTS
	local delta = math.abs(newRatio - currentRatio)

	-- Rule: User disabled animations
	if not config.enabled then
		return false, "user_disabled"
	end

	-- Rule: Tiny changes are instant (avoid micro-animations)
	if delta < constants.ANIMATION_THRESHOLD then
		return false, "delta_too_small"
	end

	-- Rule: Huge changes are instant (level-up, addon reload)
	-- REMOVED: This was causing normal XP gains to appear instant
	-- The backup version doesn't have this check and works correctly
	-- if delta > constants.INSTANT_THRESHOLD then
	-- 	return false, "delta_too_large"
	-- end

	-- Rule: Inactive view = instant (avoid duplicate animations)
	if Addon and Addon.XPBar and Addon.XPBar.GetActiveView then
		if Addon.XPBar:GetActiveView() ~= self then
			return false, "inactive_view"
		end
	end

	-- Otherwise, animate
	return true, "normal"
end

-- Legacy compatibility wrapper (old code calls AnimateToValue)
function XPBarMixinBase:AnimateToValue(targetValue, immediate)
	-- Convert to ratio-based call
	if immediate then
		self:SetDisplayValue(targetValue)
		self._currentRatio = targetValue
		return
	end

	-- Create metadata for compatibility
	local metadata = {
		source = "legacy_AnimateToValue"
	}

	self:AnimateToRatio(targetValue, metadata)
end

-- Simplified duration calculation (explicit formula)
function XPBarMixinBase:CalculateAnimationDuration(delta, config)
	local constants = ANIMATION_CONSTANTS

	-- Linear scaling: 0.001 delta = MIN, 1.0 delta = MAX
	local duration =
		constants.MIN_ANIMATION_DURATION + (delta * (constants.MAX_ANIMATION_DURATION - constants.MIN_ANIMATION_DURATION))

	-- Apply user preference multiplier (from settings)
	local speedPref = config.speed or 1.0 -- 0.5 = half speed, 2.0 = double speed
	duration = duration / speedPref

	-- Clamp to bounds
	return math.max(constants.ENFORCED_MIN_DURATION, math.min(constants.MAX_ANIMATION_DURATION, duration))
end

-- Animation completion hook
function XPBarMixinBase:OnAnimationComplete(contextOrMetadata)
	-- Clear context when animation completes
	self.animation.context = nil

	-- Hook for style-specific effects (e.g., Vertical bar falling animation)
	if self.OnBarAnimationComplete then
		self:OnBarAnimationComplete(contextOrMetadata)
	end
end

-- Get current displayed ratio (for debugging/testing)
function XPBarMixinBase:GetCurrentRatio()
	return self._currentRatio or 0
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

	self.animation.flashingXPGain = true
	self.animation.flashStartTime = GetTime()
	self.animation.flashDuration = constants.GAIN_FLASH_HALF_PERIOD_SECONDS * 2
	self.animation.isRestedGain = isRested

	-- Register with the global animation driver so flash ticks are driven
	if Addon and Addon._AnimationDriver then
		Addon._AnimationDriver:AddBar(self)
	else
		print("[XPBar] ERROR: No driver available!")
	end
end

-- Update flash effect
---Update the alpha used for flash effects. Override in bar-specific mixins.
function XPBarMixinBase:SetFlashAlpha(alpha)
	-- Default flash implementation for mixins that don't provide one.
	-- If the mixin's XML has already created a GainFlash texture, use it.
	local anchor = (self.StatusBar and self.StatusBar) or self
	if not self.GainFlash then
		-- Create a simple full-area overlay texture for flash effects
		local tex = anchor:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints(anchor)
		tex:SetBlendMode("ADD")
		tex:Hide()
		-- Match typical overlay sublevel used by XML templates
		tex:SetDrawLayer("OVERLAY", 3)
		self.GainFlash = tex
	end

	if alpha and alpha > 0 then
		-- Level-up flash (gold color)
		if self.animation and self.animation.isLevelUpFlash then
			self.GainFlash:SetColorTexture(1.0, 0.84, 0.0, alpha)
		else
			-- Use rested color for rested gains when available
			local isRested = self.animation and self.animation.isRestedGain
			local r, g, b, a = 1, 1, 1, alpha
			if isRested and XPBarColors and XPBarColors.GetUserColor then
				local c = XPBarColors:GetUserColor(Color.Rested)
				if c then
					r, g, b = c.r, c.g, c.b
				end
			elseif XPBarColors and XPBarColors.GetUserColor then
				local c = XPBarColors:GetUserColor(Color.XpBar)
				if c then
					r, g, b = c.r, c.g, c.b
				end
			end
			self.GainFlash:SetColorTexture(r, g, b, a)
		end
		self.GainFlash:Show()
	else
		if self.GainFlash then
			self.GainFlash:Hide()
		end
	end
end

function XPBarMixinBase:UpdateFlashEffect(now, elapsed)
	local state = self.animation
	local constants = ANIMATION_CONSTANTS
	local elapsed_since_start = now - state.flashStartTime

	if elapsed_since_start >= state.flashDuration then
		-- Flash complete
		state.flashingXPGain = false
		if self.SetFlashAlpha then
			self:SetFlashAlpha(0)
		end
		-- DON'T unregister here - let OnAnimationUpdate handle it
		-- (Unregistering here would stop the driver if bar animation is still running)
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
		-- Use unified animation state container
		self.animation.pauseUntil = GetTime() + constants.PAUSE_SECONDS
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
			self._fullUpdateTimer:Cancel()
			self._fullUpdateTimer = nil
		end
		self._fullUpdateTimer =
			C_Timer.NewTimer(
			0,
			function()
				self._fullUpdateScheduled = nil
				if not self or not self.FullUpdate then
					self._fullUpdateTimer = nil
					return
				end
				self:FullUpdate()
				self._fullUpdateTimer = nil
			end
		)
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
	local showXPPerHour = db.showXPPerHourText == true
	local showTimeToLevel = db.showTimeToLevelText == true

	-- Get XP rate and time to level from session service
	local xpPerHour = 0
	local timeToLevel = 0

	if Addon.Session and Addon.Session.GetXPPerHour then
		xpPerHour = Addon.Session:GetXPPerHour()
	end

	if Addon.Session and Addon.Session.GetTimeToLevel then
		timeToLevel = Addon.Session:GetTimeToLevel()
	end

	-- Build text based on what's enabled
	local parts = {}

	if showXPPerHour then
		local ratePart = XPBarTextFormatter:GetXPRateText(xpPerHour, abbreviate)
		if ratePart and ratePart ~= "" and ratePart ~= "Calculating..." then
			table.insert(parts, ratePart)
		end
	-- Don't show anything if we have no data yet
	end

	if showTimeToLevel then
		if timeToLevel > 0 then
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
			tooltip:SetText(
				string.format("XP: %s / %s (%d%%)", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP), percent),
				1,
				1,
				1
			)
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
		incompleteCount = 0
	}
end

-----------------------------------
-- Quest Event Registration & Configuration
-----------------------------------

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
		enabled = db.showQuestXP ~= false, -- Default: true (master toggle)
		showComplete = db.showCompleteQuestOverlay ~= false, -- Default: true
		showIncomplete = db.showIncompleteQuestOverlay == true -- Default: false
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
		incompleteQuestXP = incompleteQuestXP
	}
end

-- Layer 2: Calculate layout (percentages and pixels, still generic)
function XPBarMixinBase:CalculateBarLayout(state)
	local maxXP = state.maxXP

	if maxXP <= 0 then
		return {visible = false}
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

	-- Fully rested: restedXP >= 1.5 * maxXP
	local isFullyRested = state.restedXP >= (1.5 * maxXP)

	-- Bar color: rested if restedXP > 0, else normal
	-- Rested overlay: show only if restedXP < remainingXP

	-- Calculate pixel values
	local currentPixels = math.floor(currentRatio * BAR_WIDTH)

	-- Build layout structure
	-- Quest overlay visibility must respect config settings
	local config = self:GetQuestOverlayConfig()

	return {
		visible = true,
		current = {
			ratio = currentRatio,
			pixels = currentPixels
		},
		questComplete = (function()
			local visible = config.showComplete and completeXPClamped > 0 and completeRatio >= 0.01 -- show only when >= 1%
			return {
				visible = visible,
				ratio = completeRatio,
				pixels = visible and math.max(1, math.floor(completeRatio * BAR_WIDTH)) or 0,
				offsetXP = state.currentXP,
				offsetPixels = currentPixels
			}
		end)(),
		questIncomplete = (function()
			local visible = config.showIncomplete and incompleteXPClamped > 0 and incompleteRatio >= 0.01 -- show only when >= 1%
			return {
				visible = visible,
				ratio = incompleteRatio,
				pixels = visible and math.max(1, math.floor(incompleteRatio * BAR_WIDTH)) or 0,
				offsetXP = state.currentXP + incompleteOffsetXP,
				offsetPixels = currentPixels + math.floor((incompleteOffsetXP / maxXP) * BAR_WIDTH)
			}
		end)(),
		rested = {
			visible = (state.restedXP > 0) and (state.restedXP < remainingXP),
			ratio = restedRatio,
			pixels = math.max(1, math.floor(restedRatio * BAR_WIDTH)),
			offsetXP = state.currentXP + restedOffsetXP,
			offsetPixels = currentPixels + math.floor((restedOffsetXP / maxXP) * BAR_WIDTH),
			isFullyRested = isFullyRested,
			showTick = restedRatio >= 0.01 and restedRatio <= 0.99
		}
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

	-- Store layout-derived state
	self.state.isFullyRested = layout.rested and layout.rested.isFullyRested or false

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
			completeSize = 0,
			completeOffset = 0,
			incompleteSize = 0,
			incompleteOffset = 0,
			restedSize = 0,
			restedOffset = 0
		}
	end

	local completeSize = layout.questComplete and math.max(1, math.floor(layout.questComplete.ratio * barSize)) or 0
	local completeOffset = layout.questComplete and math.floor((layout.questComplete.offsetXP / maxXP) * barSize) or 0
	local incompleteSize = layout.questIncomplete and math.max(1, math.floor(layout.questIncomplete.ratio * barSize)) or 0
	local incompleteOffset =
		layout.questIncomplete and math.floor((layout.questIncomplete.offsetXP / maxXP) * barSize) or 0
	local restedSize = layout.rested and math.max(0, math.floor(layout.rested.ratio * barSize)) or 0
	local restedOffset = layout.rested and math.floor((layout.rested.offsetXP / maxXP) * barSize) or 0

	return {
		completeSize = completeSize,
		completeOffset = completeOffset,
		incompleteSize = incompleteSize,
		incompleteOffset = incompleteOffset,
		restedSize = restedSize,
		restedOffset = restedOffset
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
