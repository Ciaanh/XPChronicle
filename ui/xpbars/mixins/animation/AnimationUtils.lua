-- XP Bar Enhanced - V2 Animation Utilities
-- Helper functions for V2 animation system (copied from V1, independent implementation)

local AddonName, Addon = ...

-----------------------------------
-- Animation Constants
-----------------------------------
local ANIMATION_CONSTANTS = {
	-- Duration bounds
	MIN_ANIMATION_DURATION = 0.3, -- Minimum animation time (seconds)
	MAX_ANIMATION_DURATION = 2.0, -- Maximum animation time (seconds)
	ENFORCED_MIN_DURATION = 0.25, -- Clearly visible at 60 FPS (15 frames)
	
	-- Flash effect
	GAIN_FLASH_HALF_PERIOD_SECONDS = 0.25, -- Fade in time
	GAIN_FLASH_MAX_ALPHA = 0.5, -- Maximum flash opacity
	
	-- Thresholds
	ANIMATION_THRESHOLD = 0.001, -- Minimum change to animate (0.1%)
}

-----------------------------------
-- Animation Utilities
-----------------------------------
local AnimationUtils = {}

--- Calculate animation duration based on ratio delta
-- @param delta number: Absolute difference between start and target ratio (0.0-1.0)
-- @return number: Duration in seconds, clamped to min/max bounds
function AnimationUtils.CalculateDuration(delta)
	local constants = ANIMATION_CONSTANTS
	
	-- Linear scaling: 0.001 delta = MIN, 1.0 delta = MAX
	local duration = constants.MIN_ANIMATION_DURATION + 
		(delta * (constants.MAX_ANIMATION_DURATION - constants.MIN_ANIMATION_DURATION))
	
	-- Clamp to bounds
	return math.max(constants.ENFORCED_MIN_DURATION, math.min(constants.MAX_ANIMATION_DURATION, duration))
end

--- Ease-out quadratic easing function
-- @param t number: Progress value (0.0-1.0)
-- @param b number: Start value
-- @param c number: Change in value (target - start)
-- @param d number: Duration (normalized to 1.0)
-- @return number: Eased value
function AnimationUtils.EaseOutQuad(t, b, c, d)
	t = t / d
	return -c * t * (t - 2) + b
end

--- Check if a change should be animated
-- @param delta number: Absolute difference between current and target ratio
-- @param config table: Animation config { enableAnimations = bool }
-- @return boolean: true if should animate, false for instant update
-- @return string: Reason for decision ("enabled", "user_disabled", "delta_too_small")
function AnimationUtils.ShouldAnimate(delta, config)
	local constants = ANIMATION_CONSTANTS
	
	-- Rule: User disabled animations
	if not config.enableAnimations then
		return false, "user_disabled"
	end
	
	-- Rule: Tiny changes are instant (avoid micro-animations)
	if delta < constants.ANIMATION_THRESHOLD then
		return false, "delta_too_small"
	end
	
	-- Otherwise, animate
	return true, "enabled"
end

--- Build step context for ApplyAnimationStep
-- Contains all interpolated values and metadata needed for rendering
-- @param bar table: Bar instance with animation state
-- @param now number: Current time (GetTime())
-- @param config table: Animation config
-- @param xpContext table: XP context { xpBefore, xpAfter, xpMax, xpGained, restedXP, isResting, hasRestedXP, level }
-- @return table: stepContext with currentRatio, targetRatio, progress, timing, flash data, config, xpContext
function AnimationUtils.BuildStepContext(bar, now, config, xpContext)
	local anim = bar.animation

    -- no debug logs here in normal test
	
	-- Calculate progress
	local elapsedTime = now - anim.startTime
	local progress = math.min(elapsedTime / anim.duration, 1.0)
	
	-- Apply easing to get current ratio
	local easedProgress = progress
	if progress < 1.0 then
		-- Use ease-out quad for smooth deceleration
		easedProgress = AnimationUtils.EaseOutQuad(progress, 0, 1, 1)
	end
	local currentRatio = anim.startRatio + (anim.targetRatio - anim.startRatio) * easedProgress
	
	-- Calculate flash state
	local flashData = nil
	if anim.isFlashing then
		local flashElapsed = now - anim.flashStartTime
		local flashDuration = anim.flashDuration
		local flashHalfPeriod = ANIMATION_CONSTANTS.GAIN_FLASH_HALF_PERIOD_SECONDS
		
		-- Calculate flash alpha (fade in, then fade out)
		local flashAlpha = 0
		local phase = "none"
		if flashElapsed < flashHalfPeriod then
			-- Fade in
			flashAlpha = (flashElapsed / flashHalfPeriod) * ANIMATION_CONSTANTS.GAIN_FLASH_MAX_ALPHA
			phase = "fade_in"
		elseif flashElapsed < flashDuration then
			-- Fade out
			local fadeOutProgress = (flashElapsed - flashHalfPeriod) / flashHalfPeriod
			flashAlpha = ANIMATION_CONSTANTS.GAIN_FLASH_MAX_ALPHA * (1 - fadeOutProgress)
			phase = "fade_out"
		end
		
		flashData = {
			active = flashElapsed < flashDuration,
			currentAlpha = flashAlpha,
			startTime = anim.flashStartTime,
			duration = flashDuration,
			elapsed = flashElapsed,
			phase = phase, -- Added for debugging
			halfPeriod = flashHalfPeriod, -- Added for debugging
		}
	end
	
	-- Calculate quest overlay alpha reduction during flash (inverse of flash)
	-- When flash is active, reduce quest overlay alpha to make flash more visible
	local questOverlayAlpha = nil
	if anim.isFlashing and (anim.questOverlayCompleteInitialAlpha or anim.questOverlayIncompleteInitialAlpha) then
		local flashElapsed = now - anim.flashStartTime
		local flashDuration = anim.flashDuration
		
		-- Calculate reduction factor: start low (0.3), fade in to initial (1.0), then stay at initial
		-- Min alpha = 0.3 (30% of initial), fades in to initial over full duration
		local MIN_ALPHA_MULTIPLIER = 0.3
		local fadeProgress = math.min(flashElapsed / flashDuration, 1.0)
		local reductionFactor = MIN_ALPHA_MULTIPLIER + (1.0 - MIN_ALPHA_MULTIPLIER) * fadeProgress
		
		questOverlayAlpha = reductionFactor
	end
	
	-- Build step context
	local stepContext = {
		-- Core interpolated values
		currentRatio = currentRatio,
		targetRatio = anim.targetRatio,
		startRatio = anim.startRatio,
		progress = progress,
		
		-- Timing information
		startTime = anim.startTime,
		currentTime = now,
		elapsedTime = elapsedTime,
		duration = anim.duration,
		
		-- Flash data (nil if not flashing)
		flashData = flashData,
		isFlashing = anim.isFlashing,
		
		-- Quest overlay alpha multiplier (nil if not flashing)
		questOverlayAlpha = questOverlayAlpha,
		questOverlayCompleteInitialAlpha = anim.questOverlayCompleteInitialAlpha,
		questOverlayIncompleteInitialAlpha = anim.questOverlayIncompleteInitialAlpha,
		
		-- Configuration
		config = config,
		
		-- XP context (immutable)
		xpContext = xpContext
	}
	
	return stepContext
end

--- Aggregate multiple XP contexts during retargeting
-- Combines multiple XP gains into a single aggregated context
-- @param contexts table: Array of XP contexts to aggregate
-- @return table: Aggregated context with summed xpGained, preserved rested fields from latest context
function AnimationUtils.AggregateContexts(contexts)
	if #contexts == 0 then
		return nil
	end
	
	if #contexts == 1 then
		return contexts[1]
	end
	
	-- Start with first context
	local aggregated = {
		xpBefore = contexts[1].xpBefore,
		xpAfter = contexts[#contexts].xpAfter, -- Use latest xpAfter
		xpMax = contexts[#contexts].xpMax, -- Use latest max
		xpGained = 0,
		restedXP = contexts[#contexts].restedXP or 0, -- Use latest rested XP
		isResting = contexts[#contexts].isResting or false, -- Use latest resting state
		hasRestedXP = contexts[#contexts].hasRestedXP or false, -- Use latest hasRestedXP
		level = contexts[#contexts].level, -- Use latest level
		timestamp = contexts[1].timestamp -- Keep first timestamp
	}
	
	-- Sum all xpGained, preserve hasRestedXP flag if any gain had rested XP
	for _, ctx in ipairs(contexts) do
		aggregated.xpGained = aggregated.xpGained + (ctx.xpGained or 0)
		-- If any context has rested XP available, preserve that flag
		aggregated.hasRestedXP = aggregated.hasRestedXP or ctx.hasRestedXP
	end
	
	return aggregated
end

--- Detect level-up from XP context
-- Level-up occurs when xpAfter < xpBefore (XP resets on level)
-- @param context table: XP context { xpBefore, xpAfter, xpMax, level }
-- @return boolean: true if level-up detected
function AnimationUtils.DetectLevelUp(context)
	return context.xpAfter < context.xpBefore
end

--- Get animation constants
-- @return table: ANIMATION_CONSTANTS
function AnimationUtils.GetConstants()
	return ANIMATION_CONSTANTS
end

-----------------------------------
-- Export
-----------------------------------
Addon.AnimationUtils = AnimationUtils
