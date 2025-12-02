-- XP Bar Enhanced -  Animation Manager
-- Core animation driver for  bar styles

local AddonName, Addon = ...
local AnimationUtils = Addon.AnimationUtils

-----------------------------------
-- Animation Manager (Singleton)
-----------------------------------
local AnimationManager = {
	registeredBars = {}, -- Array of bars currently animating
	driver = nil -- Frame with OnUpdate
}

--- Initialize the animation driver frame
function AnimationManager:Initialize()
	if self.driver then
		return -- Already initialized
	end

	-- Create global animation driver frame
	self.driver = CreateFrame("Frame")
	self.driver:SetScript(
		"OnUpdate",
		function(frame, elapsed)
			self:OnUpdate(elapsed)
		end
	)

	-- Start paused (no bars to animate)
	self.driver:Hide()
end

--- Register a bar for animation
-- @param bar table: Bar instance with animation state
function AnimationManager:Register(bar)
	-- Check if already registered
	for _, registeredBar in ipairs(self.registeredBars) do
		if registeredBar == bar then
			return -- Already registered
		end
	end

	-- Add to registered bars
	table.insert(self.registeredBars, bar)

	-- Start driver if not running
	if not self.driver:IsShown() then
		self.driver:Show()
	end
end

--- Unregister a bar from animation
-- @param bar table: Bar instance to unregister
function AnimationManager:Unregister(bar)
	for i, registeredBar in ipairs(self.registeredBars) do
		if registeredBar == bar then
			table.remove(self.registeredBars, i)
			break
		end
	end

	-- Pause driver if no bars left
	if #self.registeredBars == 0 then
		self.driver:Hide()
	end
end

--- Start animation to target ratio
-- Handles retargeting, level-up detection, and animation initiation
-- @param bar table: Bar instance with animation state
-- @param targetRatio number: Target ratio (0.0-1.0)
-- @param xpContext table: XP context { xpBefore, xpAfter, xpMax, xpGained, restedXP, isResting, hasRestedXP, level, timestamp }
-- @param config table: Animation config { enableAnimations, flashOnGain }
function AnimationManager:AnimateTo(bar, targetRatio, xpContext, config)
	local now = GetTime()

	-- CRITICAL: Preserve incoming xpContext for flash decision BEFORE any aggregation
	-- This ensures flash only triggers on actual XP gain events, not periodic refresh (xpGained=0)
	local incomingXpContext = xpContext

	-- Ensure animation state exists
	if not bar.animation then
		bar.animation = {
			isAnimating = false,
			startRatio = 0,
			targetRatio = 0,
			startTime = 0,
			duration = 0,
			isFlashing = false,
			flashStartTime = 0,
			flashDuration = 0,
			eventContext = nil -- Single immutable context (144 bytes)
		}
	end

	local anim = bar.animation

	-- Small epsilon for floating point ratio comparisons
	local EPSILON = 1e-6

	-- Defensive: compute a reliable startRatio to compare against target
	local currentVisual = nil
	if anim.startRatio ~= nil then
		currentVisual = anim.startRatio
	elseif bar.GetCurrentRatio then
		currentVisual = bar:GetCurrentRatio() or 0
	else
		currentVisual = 0
	end

	-- Deduplicate no-op AnimateTo calls: if we're already animating to the same
	-- targetRatio (within EPSILON), ignore the request to avoid duplicate
	-- registrations and duplicate StartAnimation delegations.
	if anim.isAnimating and math.abs((anim.targetRatio or 0) - targetRatio) <= EPSILON then
		return
	end

	-- If not animating and the current visual position already equals the
	-- requested target (within EPSILON), treat as a no-op (instant set)
	if (not anim.isAnimating) and math.abs((currentVisual or 0) - targetRatio) <= EPSILON then
		if bar.SetCurrentRatio then
			bar:SetCurrentRatio(targetRatio)
		end

		return
	end

	local now = GetTime()

	-- Detect level-up
	if AnimationUtils.DetectLevelUp(xpContext) then
		-- Cancel current animation
		if anim.isAnimating then
			self:Unregister(bar)
			anim.isAnimating = false
		end

		-- Check if two-phase animation is enabled
		local twoPhaseEnabled = config.twoPhaseOnLevelUp
		-- Default to true if not explicitly set
		if twoPhaseEnabled == nil then
			twoPhaseEnabled = true
		end

		if twoPhaseEnabled then
			-- TWO-PHASE ANIMATION:
			-- Phase 1: Animate from current position to 100%
			-- Phase 2: Reset to 0 and animate to new XP (queued)

			-- Calculate current visual position for phase 1 start
			local currentVisual = bar:GetCurrentRatio() or 0

			-- Store phase 2 target for after phase 1 completes
			local currentXP = xpContext.currentXP or xpContext.xpAfter or 0
			local newXPRatio = currentXP / xpContext.xpMax

			-- Queue phase 2 animation data
			anim.pendingSecondPhase = {
				targetRatio = newXPRatio,
				context = xpContext
			}

			-- Mark this as Phase 1 of level-up (hides overlays during animation)
			anim.isLevelUpPhase1 = true

			-- Set up phase 1: animate to 100%
			anim.startRatio = currentVisual
			anim.targetRatio = 1.0
			anim.eventContext = xpContext
			targetRatio = 1.0 -- Override for phase 1
		else
			-- INSTANT RESET (original behavior):
			-- Reset bar to 0 immediately, then animate to new XP
			local resetIterationData = {
				currentRatio = 0,
				targetRatio = 0,
				startRatio = 0,
				progress = 1.0,
				easedProgress = 1.0,
				startTime = now,
				currentTime = now,
				elapsedTime = 0,
				duration = 0,
				flashData = nil,
				isFlashing = false,
				questOverlayAlpha = nil,
				questOverlayCompleteInitialAlpha = nil,
				questOverlayIncompleteInitialAlpha = nil,
				config = config
			}

			if bar.ApplyAnimationStep then
				bar:ApplyAnimationStep(resetIterationData, xpContext)
			end

			-- Now animate to new XP position
			local currentXP = xpContext.currentXP or xpContext.xpAfter or 0
			targetRatio = currentXP / xpContext.xpMax
			anim.startRatio = 0
			anim.eventContext = xpContext
		end
	elseif anim.isAnimating then
		-- Retargeting: new XP gain during active animation
		-- With immutable context, use incoming context (no aggregation)
		-- The most recent context reflects current state
		anim.eventContext = incomingXpContext

		-- Calculate current visual position for smooth retargeting
		local elapsed = now - anim.startTime
		local progress = math.min(elapsed / anim.duration, 1.0)
		if progress < 1.0 then
			-- Use eased progress to get current visual position
			local easedProgress = AnimationUtils.EaseOutQuad(progress, 0, 1, 1)
			anim.startRatio = anim.startRatio + (anim.targetRatio - anim.startRatio) * easedProgress
		else
			-- Animation complete, use target as start
			anim.startRatio = anim.targetRatio
		end

		-- Update target ratio
		anim.targetRatio = targetRatio
	else
		-- Fresh animation start
		anim.startRatio = bar:GetCurrentRatio() or 0
		anim.targetRatio = targetRatio
		anim.eventContext = xpContext -- Store single immutable context
	end

	-- Calculate delta for duration and animation check
	local delta = math.abs(targetRatio - anim.startRatio)

	-- Check if should animate
	local shouldAnimate, reason = AnimationUtils.ShouldAnimate(delta, config)

	if not shouldAnimate then
		-- Instant update with separated iteration data and event context
		local instantIterationData = {
			currentRatio = targetRatio,
			targetRatio = targetRatio,
			startRatio = anim.startRatio,
			progress = 1.0,
			easedProgress = 1.0,
			startTime = now,
			currentTime = now,
			elapsedTime = 0,
			duration = 0,
			flashData = nil,
			isFlashing = false,
			questOverlayAlpha = nil,
			questOverlayCompleteInitialAlpha = nil,
			questOverlayIncompleteInitialAlpha = nil,
			config = config
		}

		-- If this event gained XP and flash on gain is enabled, trigger the flash
		local instantWillFlash =
			config.flashOnGain and incomingXpContext and incomingXpContext.xpGained and incomingXpContext.xpGained > 0
		if instantWillFlash then
			local inCooldown = anim.flashCooldownUntil and now < anim.flashCooldownUntil
			if not anim.isFlashing and not inCooldown then
				anim.isFlashing = true
				anim.flashStartTime = now
				-- Total flash duration = fade in + hold + fade out (1.0 second total)
				anim.flashDuration = AnimationUtils.GetFlashTotalDuration()
				-- Store event context for flash
				anim.eventContext = xpContext
				-- Register so OnUpdate drives the flash
				self:Register(bar)
			end
		end

		if bar.ApplyAnimationStep then
			bar:ApplyAnimationStep(instantIterationData, xpContext)
		end

		-- Update bar's current ratio
		if bar.SetCurrentRatio then
			bar:SetCurrentRatio(targetRatio)
		end

		return
	end

	-- Calculate animation duration (based on ratio delta only, no speed multiplier)
	local duration = AnimationUtils.CalculateDuration(delta)

	-- Determine if flash should be shown
	-- CRITICAL: Use incomingXpContext (preserved at function start) to check if THIS event gained XP
	-- This prevents periodic refresh (xpGained=0) from triggering flash due to accumulated total
	local willFlash = config.flashOnGain and incomingXpContext.xpGained and incomingXpContext.xpGained > 0

	-- Setup animation state
	anim.isAnimating = true
	anim.startTime = now
	anim.duration = duration
	anim.targetRatio = targetRatio

	-- Setup flash effect if enabled and XP was gained
	if willFlash then
		-- Only start flash if not already flashing (prevent restart/flicker on retargeting)
		-- Also check cooldown to prevent double flash on rapid XP events
		local inCooldown = anim.flashCooldownUntil and now < anim.flashCooldownUntil
		if not anim.isFlashing and not inCooldown then
			anim.isFlashing = true
			anim.flashStartTime = now
			-- Total flash duration = fade in + hold + fade out (1.0 second total)
			anim.flashDuration = AnimationUtils.GetFlashTotalDuration()

			-- Capture initial quest overlay alphas to restore after flash (only if not already captured)
			if not anim.questOverlayCompleteInitialAlpha and not anim.questOverlayIncompleteInitialAlpha then
				if bar.StatusBar then
					anim.questOverlayCompleteInitialAlpha =
						bar.StatusBar.QuestOverlayComplete and bar.StatusBar.QuestOverlayComplete:GetAlpha() or 1.0
					anim.questOverlayIncompleteInitialAlpha =
						bar.StatusBar.QuestOverlayIncomplete and bar.StatusBar.QuestOverlayIncomplete:GetAlpha() or 1.0
				elseif bar.QuestOverlayComplete or bar.QuestOverlayIncomplete then
					-- Flat  style
					anim.questOverlayCompleteInitialAlpha = bar.QuestOverlayComplete and bar.QuestOverlayComplete:GetAlpha() or 1.0
					anim.questOverlayIncompleteInitialAlpha =
						bar.QuestOverlayIncomplete and bar.QuestOverlayIncomplete:GetAlpha() or 1.0
				end
			end
		end
	end

	-- Register with driver
	self:Register(bar)
end

--- OnUpdate callback for animation driver
-- @param elapsed number: Time since last frame (unused, we use GetTime())
function AnimationManager:OnUpdate(elapsed)
	local now = GetTime()
	local barsToRemove = {}

	-- Update each registered bar
	for i, bar in ipairs(self.registeredBars) do
		if not bar.animation or (not bar.animation.isAnimating and not bar.animation.isFlashing) then
			-- Bar finished animation and flash, mark for removal
			table.insert(barsToRemove, bar)
		else
			-- Update bar animation (will update bar position and/or flash)
			self:UpdateBarAnimation(bar, now)
		end
	end

	-- Remove bars that completed
	for _, bar in ipairs(barsToRemove) do
		self:Unregister(bar)
	end
end

--- Update single bar animation
-- @param bar table: Bar instance with animation state
-- @param now number: Current time (GetTime())
function AnimationManager:UpdateBarAnimation(bar, now)
	local anim = bar.animation

	-- Get animation config (bar should provide this)
	local config
	if bar.GetAnimationConfig then
		config = bar:GetAnimationConfig()
	else
		config = {enableAnimations = true, flashOnGain = true}
	end

	-- Check if flash complete BEFORE building iteration data
	if anim.isFlashing then
		local flashElapsed = now - anim.flashStartTime
		if flashElapsed >= anim.flashDuration then
			anim.isFlashing = false
			-- Set cooldown to prevent immediate restart (prevents double flash on rapid XP events)
			anim.flashCooldownUntil = now + 0.1 -- 100ms cooldown after flash completes

			-- Restore quest overlay alphas to initial values
			if bar.StatusBar then
				if bar.StatusBar.QuestOverlayComplete and anim.questOverlayCompleteInitialAlpha then
					bar.StatusBar.QuestOverlayComplete:SetAlpha(anim.questOverlayCompleteInitialAlpha)
				end
				if bar.StatusBar.QuestOverlayIncomplete and anim.questOverlayIncompleteInitialAlpha then
					bar.StatusBar.QuestOverlayIncomplete:SetAlpha(anim.questOverlayIncompleteInitialAlpha)
				end
			elseif bar.QuestOverlayComplete or bar.QuestOverlayIncomplete then
				-- Flat  style
				if bar.QuestOverlayComplete and anim.questOverlayCompleteInitialAlpha then
					bar.QuestOverlayComplete:SetAlpha(anim.questOverlayCompleteInitialAlpha)
				end
				if bar.QuestOverlayIncomplete and anim.questOverlayIncompleteInitialAlpha then
					bar.QuestOverlayIncomplete:SetAlpha(anim.questOverlayIncompleteInitialAlpha)
				end
			end

			-- Clear initial alpha storage
			anim.questOverlayCompleteInitialAlpha = nil
			anim.questOverlayIncompleteInitialAlpha = nil
		end
	end

	-- Calculate iteration data per frame (progress, elapsed, easing, flash)
	local elapsedTime = now - anim.startTime
	local progress = math.min(elapsedTime / anim.duration, 1.0)

	-- Apply easing to get current ratio
	local easedProgress = progress
	if progress < 1.0 then
		easedProgress = AnimationUtils.EaseOutQuad(progress, 0, 1, 1)
	end
	local currentRatio = anim.startRatio + (anim.targetRatio - anim.startRatio) * easedProgress

	-- Calculate flash state
	local flashData = nil
	if anim.isFlashing then
		local flashElapsed = now - anim.flashStartTime
		local flashDuration = anim.flashDuration
		local constants = AnimationUtils.GetConstants()
		local fadeInDuration = constants.GAIN_FLASH_FADE_IN_DURATION
		local holdDuration = constants.GAIN_FLASH_HOLD_DURATION
		local fadeOutDuration = constants.GAIN_FLASH_FADE_OUT_DURATION
		local maxAlpha = constants.GAIN_FLASH_MAX_ALPHA

		-- Calculate flash alpha with three phases: fade in, hold, fade out
		local flashAlpha = 0
		local phase = "none"

		if flashElapsed < fadeInDuration then
			flashAlpha = (flashElapsed / fadeInDuration) * maxAlpha
			phase = "fade_in"
		elseif flashElapsed < fadeInDuration + holdDuration then
			flashAlpha = maxAlpha
			phase = "hold"
		elseif flashElapsed < fadeInDuration + holdDuration + fadeOutDuration then
			local fadeOutProgress = (flashElapsed - fadeInDuration - holdDuration) / fadeOutDuration
			flashAlpha = maxAlpha * (1 - fadeOutProgress)
			phase = "fade_out"
		end

		flashData = {
			active = flashElapsed < flashDuration,
			currentAlpha = flashAlpha,
			startTime = anim.flashStartTime,
			duration = flashDuration,
			elapsed = flashElapsed,
			phase = phase,
			fadeInDuration = fadeInDuration,
			holdDuration = holdDuration,
			fadeOutDuration = fadeOutDuration
		}
	end

	-- Calculate quest overlay alpha reduction during flash
	local questOverlayAlpha = nil
	if anim.isFlashing and (anim.questOverlayCompleteInitialAlpha or anim.questOverlayIncompleteInitialAlpha) then
		local flashElapsed = now - anim.flashStartTime
		local flashDuration = anim.flashDuration
		local MIN_ALPHA_MULTIPLIER = 0.3
		local fadeProgress = math.min(flashElapsed / flashDuration, 1.0)
		local reductionFactor = MIN_ALPHA_MULTIPLIER + (1.0 - MIN_ALPHA_MULTIPLIER) * fadeProgress
		questOverlayAlpha = reductionFactor
	end

	-- Build iteration data (calculated per frame, zero allocation)
	local iterationData = {
		-- Core interpolated values
		currentRatio = currentRatio,
		targetRatio = anim.targetRatio,
		startRatio = anim.startRatio,
		progress = progress,
		easedProgress = easedProgress,
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
		-- Level-up phase 1 flag (hides overlays during fill-to-100% animation)
		isLevelUpPhase1 = anim.isLevelUpPhase1 or false,
		-- Configuration
		config = config
	}

	-- Use stored event context (single immutable context, no aggregation)
	local eventContext = anim.eventContext

	-- Apply animation step with separated context and iteration data
	if bar.ApplyAnimationStep then
		bar:ApplyAnimationStep(iterationData, eventContext)
	end

	-- Update bar's current ratio tracking
	if bar.SetCurrentRatio then
		bar:SetCurrentRatio(currentRatio)
	end

	-- Check if animation complete
	if progress >= 1.0 then
		anim.isAnimating = false
		-- DON'T clear isFlashing here - let flash complete independently
		-- DON'T clear eventContext yet - flash still needs it

		-- Send final cleanup step with iteration data + event context
		local cleanupIterationData = {
			currentRatio = anim.targetRatio,
			targetRatio = anim.targetRatio,
			startRatio = anim.startRatio,
			progress = 1.0,
			easedProgress = 1.0,
			startTime = anim.startTime,
			currentTime = now,
			elapsedTime = elapsedTime,
			duration = anim.duration,
			flashData = flashData,
			isFlashing = anim.isFlashing,
			questOverlayAlpha = questOverlayAlpha,
			questOverlayCompleteInitialAlpha = anim.questOverlayCompleteInitialAlpha,
			questOverlayIncompleteInitialAlpha = anim.questOverlayIncompleteInitialAlpha,
			config = config
		}

		if bar.ApplyAnimationStep then
			bar:ApplyAnimationStep(cleanupIterationData, eventContext)
		end

		-- Check if there's a pending second phase (from two-phase level-up animation)
		if anim.pendingSecondPhase then
			local phase2 = anim.pendingSecondPhase
			anim.pendingSecondPhase = nil -- Clear the pending state
			anim.isLevelUpPhase1 = false -- Clear Phase 1 flag

			-- Reset bar to 0 immediately
			if bar.SetCurrentRatio then
				bar:SetCurrentRatio(0)
			end

			-- Apply reset visually
			local resetIterationData = {
				currentRatio = 0,
				targetRatio = 0,
				startRatio = anim.targetRatio,
				progress = 1.0,
				easedProgress = 1.0,
				startTime = now,
				currentTime = now,
				elapsedTime = 0,
				duration = 0,
				flashData = nil,
				isFlashing = false,
				questOverlayAlpha = nil,
				questOverlayCompleteInitialAlpha = nil,
				questOverlayIncompleteInitialAlpha = nil,
				config = config
			}

			if bar.ApplyAnimationStep then
				bar:ApplyAnimationStep(resetIterationData, phase2.context)
			end

			-- Start phase 2: animate from 0 to new XP
			anim.isAnimating = true
			anim.startRatio = 0
			anim.targetRatio = phase2.targetRatio
			anim.startTime = now
			anim.eventContext = phase2.context

			-- Calculate duration for phase 2
			local delta = math.abs(phase2.targetRatio - 0)
			anim.duration = AnimationUtils.CalculateDuration(delta)

			-- Register bar to continue animation
			self:Register(bar)
		else
			-- Call completion callback if bar provides one
			if bar.OnAnimationComplete then
				bar:OnAnimationComplete(eventContext)
			end
		end
	end

	-- Clear context only when animation and flash are complete
	if not anim.isAnimating and not anim.isFlashing then
		anim.eventContext = nil
	end
end

-----------------------------------
-- Initialize on load
-----------------------------------
AnimationManager:Initialize()

-----------------------------------
-- Export
-----------------------------------
Addon.AnimationManager = AnimationManager
