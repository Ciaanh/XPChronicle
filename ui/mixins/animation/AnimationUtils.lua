-- XP Bar Enhanced -  Animation Utilities
-- Helper functions for  animation system (copied from V1, independent implementation)

local AddonName, Addon = ...

-----------------------------------
-- Animation Constants
-----------------------------------
local ANIMATION_CONSTANTS = {
	-- Duration bounds
	MIN_ANIMATION_DURATION = 0.3, -- Minimum animation time (seconds)
	MAX_ANIMATION_DURATION = 2.0, -- Maximum animation time (seconds)
	ENFORCED_MIN_DURATION = 0.25, -- Clearly visible at 60 FPS (15 frames)
	-- Flash effect (matches V1 glow pattern)
	GAIN_FLASH_FADE_IN_DURATION = 0.2, -- Fade in time (200ms)
	GAIN_FLASH_FADE_OUT_DURATION = 0.3, -- Fade out time (300ms)
	GAIN_FLASH_HOLD_DURATION = 0.5, -- Hold at max alpha (500ms)
	GAIN_FLASH_MAX_ALPHA = 0.6, -- Maximum flash opacity (60%)
	-- Thresholds
	ANIMATION_THRESHOLD = 0.001 -- Minimum change to animate (0.1%)
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
	local duration =
		constants.MIN_ANIMATION_DURATION + (delta * (constants.MAX_ANIMATION_DURATION - constants.MIN_ANIMATION_DURATION))

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
--- Detect level-up from XP context
-- Level-up occurs when xpAfter < xpBefore (XP resets on level)
-- @param context table: XP context { xpBefore, xpAfter, xpMax, level }
-- @return boolean: true if level-up detected
function AnimationUtils.DetectLevelUp(context)
	-- Prefer explicit flag from context builder when available
	if not context then
		return false
	end

	local hasLeveledUp
	-- Support both direct field access and Get() accessor on immutable contexts
	if type(context.Get) == "function" then
		hasLeveledUp = context:Get("hasLeveledUp")
	else
		hasLeveledUp = context.hasLeveledUp
	end

	if hasLeveledUp then
		return true
	end

	-- Fallback: compare xpAfter/xpBefore safely
	local xpAfter = (type(context.Get) == "function") and context:Get("xpAfter") or context.xpAfter
	local xpBefore = (type(context.Get) == "function") and context:Get("xpBefore") or context.xpBefore

	if not xpAfter or not xpBefore then
		return false
	end

	return xpAfter < xpBefore
end

--- Get total flash duration (fade in + hold + fade out)
-- @return number: Total flash duration in seconds
function AnimationUtils.GetFlashTotalDuration()
	return ANIMATION_CONSTANTS.GAIN_FLASH_FADE_IN_DURATION + ANIMATION_CONSTANTS.GAIN_FLASH_HOLD_DURATION +
		ANIMATION_CONSTANTS.GAIN_FLASH_FADE_OUT_DURATION
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
