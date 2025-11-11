-- XP Bar Enhanced - V2 Animation Manager
-- Core animation driver for V2 bar styles

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
			contexts = {} -- For aggregation during retargeting
		}
	end

	local anim = bar.animation
	local now = GetTime()

	-- Detect level-up
	if AnimationUtils.DetectLevelUp(xpContext) then
		-- Cancel current animation
		if anim.isAnimating then
			self:Unregister(bar)
			anim.isAnimating = false
		end

		-- Reset bar to 0 immediately via instant update
		local resetContext = {
			currentRatio = 0,
			targetRatio = 0,
			startRatio = 0,
			progress = 1.0,
			startTime = now,
			currentTime = now,
			elapsedTime = 0,
			duration = 0,
			flashData = nil,
			isFlashing = false,
			config = config,
			xpContext = xpContext
		}

		if bar.ApplyAnimationStep then
			bar:ApplyAnimationStep(resetContext)
		end

		-- Now animate to new XP position
		-- Level-up resets XP, so xpAfter is the new position
		targetRatio = xpContext.xpAfter / xpContext.xpMax
		anim.startRatio = 0
		anim.contexts = {xpContext}
	elseif anim.isAnimating then
		-- Retargeting: new XP gain during active animation
		-- Aggregate contexts
		table.insert(anim.contexts, xpContext)
		local aggregatedContext = AnimationUtils.AggregateContexts(anim.contexts)
		-- Use aggregated context for bar positioning (smooth retargeting)
		-- incomingXpContext preserved at function start for flash decision
		xpContext = aggregatedContext

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
		anim.contexts = {xpContext}
	end

	-- Calculate delta for duration and animation check
	local delta = math.abs(targetRatio - anim.startRatio)

	-- Check if should animate
	local shouldAnimate, reason = AnimationUtils.ShouldAnimate(delta, config)

	if not shouldAnimate then
		-- Instant update via ApplyAnimationStep with final context
		local instantContext = {
			currentRatio = targetRatio,
			targetRatio = targetRatio,
			startRatio = anim.startRatio,
			progress = 1.0,
			startTime = now,
			currentTime = now,
			elapsedTime = 0,
			duration = 0,
			flashData = nil,
			isFlashing = false,
			config = config,
			xpContext = xpContext
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
				-- Register so OnUpdate drives the flash
				self:Register(bar)
			end
		end

		if bar.ApplyAnimationStep then
			bar:ApplyAnimationStep(instantContext)
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
					anim.questOverlayCompleteInitialAlpha = bar.StatusBar.QuestOverlayComplete and bar.StatusBar.QuestOverlayComplete:GetAlpha() or 1.0
					anim.questOverlayIncompleteInitialAlpha = bar.StatusBar.QuestOverlayIncomplete and bar.StatusBar.QuestOverlayIncomplete:GetAlpha() or 1.0
				elseif bar.QuestOverlayComplete or bar.QuestOverlayIncomplete then
					-- Flat V2 style
					anim.questOverlayCompleteInitialAlpha = bar.QuestOverlayComplete and bar.QuestOverlayComplete:GetAlpha() or 1.0
					anim.questOverlayIncompleteInitialAlpha = bar.QuestOverlayIncomplete and bar.QuestOverlayIncomplete:GetAlpha() or 1.0
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
	local elapsedTime = now - anim.startTime
	local progress = math.min(elapsedTime / anim.duration, 1.0)
	-- Get animation config (bar should provide this)
	local config
	if bar.GetAnimationConfig then
		config = bar:GetAnimationConfig()
	else
		config = {enableAnimations = true, flashOnGain = true}
	end

	-- Check if flash complete BEFORE building step context
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
				-- Flat V2 style
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
	
	-- Get XP context from aggregated contexts
	local xpContext = AnimationUtils.AggregateContexts(anim.contexts)

	-- Build step context (will include current flash state)
	local stepContext = AnimationUtils.BuildStepContext(bar, now, config, xpContext)

	-- Apply animation step (bar implements this)
	if bar.ApplyAnimationStep then
		bar:ApplyAnimationStep(stepContext)
	end

	-- Update bar's current ratio tracking
	if bar.SetCurrentRatio then
		bar:SetCurrentRatio(stepContext.currentRatio)
	end

	-- Check if animation complete
	if progress >= 1.0 then
		anim.isAnimating = false
		-- DON'T clear isFlashing here - let flash complete independently
		-- DON'T clear contexts yet - flash still needs xpContext

		-- Send final cleanup step context (flash may still be active)
		local cleanupContext = AnimationUtils.BuildStepContext(bar, now, config, xpContext)
		if bar.ApplyAnimationStep then
			bar:ApplyAnimationStep(cleanupContext)
		end

		-- Call completion callback if bar provides one
		if bar.OnAnimationComplete then
			bar:OnAnimationComplete(xpContext)
		end
	end

	-- Clear contexts only when animation and flash are complete
	if not anim.isAnimating and not anim.isFlashing then
		anim.contexts = {}
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
