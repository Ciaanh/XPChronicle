-- XP Bar Enhanced - V2 Animation Manager
-- Core animation driver for V2 bar styles

local AddonName, Addon = ...
local AnimationUtils = Addon.AnimationUtils

-----------------------------------
-- Debug Message Collection
-----------------------------------
local debugMessages = {}
local MAX_DEBUG_MESSAGES = 50
local debugFlashTiming = false -- Flag to enable detailed flash timing debug
local flashTimingLogs = {} -- Array to collect flash timing logs
local MAX_FLASH_LOGS = 100

-- Flash tracking logs (for debugging double flash issue)
local flashTrackLogs = {}
local MAX_FLASH_TRACK_LOGS = 100
local flashTrackEnabled = false

local function AddDebugMessage(message)
	table.insert(debugMessages, string.format("[%.3f] %s", GetTime(), message))
	if #debugMessages > MAX_DEBUG_MESSAGES then
		table.remove(debugMessages, 1)
	end
end

local function AddFlashTrackLog(message)
	if not flashTrackEnabled then
		return
	end
	table.insert(flashTrackLogs, string.format("[%.3f] %s", GetTime(), message))
	if #flashTrackLogs > MAX_FLASH_TRACK_LOGS then
		table.remove(flashTrackLogs, 1)
	end
end

local function AddFlashTimingLog(message)
	table.insert(flashTimingLogs, string.format("[%.3f] %s", GetTime(), message))
	if #flashTimingLogs > MAX_FLASH_LOGS then
		table.remove(flashTimingLogs, 1)
	end
end

-- Command to dump debug messages to error frame
SLASH_ANIMDEBUG1 = "/animdebug"
SlashCmdList["ANIMDEBUG"] = function()
	if #debugMessages == 0 then
		UIErrorsFrame:AddMessage("No animation debug messages collected.", 1.0, 1.0, 0.0, 1.0)
		error("No animation debug messages collected.")
        return
	end
	
	-- Dump all messages to error frame
	UIErrorsFrame:AddMessage("=== Animation Debug Messages ===", 1.0, 1.0, 0.0, 1.0)
	for _, msg in ipairs(debugMessages) do
		UIErrorsFrame:AddMessage(msg, 1.0, 1.0, 1.0, 1.0)
        error(msg)
	end
	UIErrorsFrame:AddMessage(string.format("=== Total: %d messages ===", #debugMessages), 1.0, 1.0, 0.0, 1.0)
end

-- Command to toggle flash tracking debug
SLASH_FLASHTRACK1 = "/flashtrack"
SlashCmdList["FLASHTRACK"] = function()
	flashTrackEnabled = not flashTrackEnabled
	if flashTrackEnabled then
		flashTrackLogs = {} -- Clear logs when enabling
	end
	local status = flashTrackEnabled and "ENABLED" or "DISABLED"
	print(string.format("|cff00ff00[Flash Track]|r Flash tracking: %s (Use /flashtracklogs to dump)", status))
end

-- Command to dump flash tracking logs
SLASH_FLASHTRACKLOGS1 = "/flashtracklogs"
SlashCmdList["FLASHTRACKLOGS"] = function()
	if #flashTrackLogs == 0 then
		UIErrorsFrame:AddMessage("No flash tracking logs. Enable with /flashtrack", 1.0, 1.0, 0.0, 1.0)
		error("No flash tracking logs. Enable with /flashtrack")
		return
	end
	
	UIErrorsFrame:AddMessage("=== Flash Tracking Logs ===", 1.0, 1.0, 0.0, 1.0)
	for _, msg in ipairs(flashTrackLogs) do
		UIErrorsFrame:AddMessage(msg, 1.0, 1.0, 1.0, 1.0)
		error(msg)
	end
	UIErrorsFrame:AddMessage(string.format("=== Total: %d logs ===", #flashTrackLogs), 1.0, 1.0, 0.0, 1.0)
end

-- Command to toggle detailed flash timing debug
SLASH_FLASHDEBUG1 = "/flashdebug"
SlashCmdList["FLASHDEBUG"] = function()
	debugFlashTiming = not debugFlashTiming
	if debugFlashTiming then
		flashTimingLogs = {} -- Clear logs when enabling
	end
	local status = debugFlashTiming and "ENABLED" or "DISABLED"
	print(string.format("|cff00ff00[V2 Flash Debug]|r Detailed flash timing: %s", status))
end

-- Command to dump V2 flash timing logs
SLASH_V2FLASHLOGS1 = "/v2flashlogs"
SlashCmdList["V2FLASHLOGS"] = function()
	if #flashTimingLogs == 0 then
		UIErrorsFrame:AddMessage("No V2 flash timing logs collected. Enable with /flashdebug", 1.0, 1.0, 0.0, 1.0)
		error("No V2 flash timing logs collected. Enable with /flashdebug")
		return
	end
	
	UIErrorsFrame:AddMessage("=== V2 Flash Timing Logs ===", 0.0, 1.0, 0.0, 1.0)
	for _, msg in ipairs(flashTimingLogs) do
		UIErrorsFrame:AddMessage(msg, 1.0, 1.0, 1.0, 1.0)
		error(msg)
	end
	UIErrorsFrame:AddMessage(string.format("=== Total: %d logs ===", #flashTimingLogs), 0.0, 1.0, 0.0, 1.0)
end

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
	self.driver:SetScript("OnUpdate", function(frame, elapsed)
		self:OnUpdate(elapsed)
	end)
	
	-- Start paused (no bars to animate)
	self.driver:Hide()
end

--- Register a bar for animation
-- @param bar table: Bar instance with animation state
function AnimationManager:Register(bar)
	-- Check if already registered
	for _, registeredBar in ipairs(self.registeredBars) do
		if registeredBar == bar then
			AddDebugMessage(string.format("Bar already registered: %s", tostring(bar:GetName() or bar)))
			return -- Already registered
		end
	end
	
	-- Add to registered bars
	table.insert(self.registeredBars, bar)
	AddDebugMessage(string.format("Registered bar: %s (total bars: %d)", tostring(bar:GetName() or bar), #self.registeredBars))
	
	-- Start driver if not running
	if not self.driver:IsShown() then
		self.driver:Show()
		AddDebugMessage("Animation driver started")
	end
end

--- Unregister a bar from animation
-- @param bar table: Bar instance to unregister
function AnimationManager:Unregister(bar)
	for i, registeredBar in ipairs(self.registeredBars) do
		if registeredBar == bar then
			table.remove(self.registeredBars, i)
			AddDebugMessage(string.format("Unregistered bar: %s (remaining bars: %d)", tostring(bar:GetName() or bar), #self.registeredBars))
			break
		end
	end
	
	-- Pause driver if no bars left
	if #self.registeredBars == 0 then
		self.driver:Hide()
		AddDebugMessage("Animation driver stopped (no bars left)")
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
	
	AddDebugMessage(string.format("AnimateTo: targetRatio=%.3f, xpGained=%d, xpBefore=%d, xpAfter=%d", 
		targetRatio, xpContext.xpGained or 0, xpContext.xpBefore or 0, xpContext.xpAfter or 0))
	
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
		anim.contexts = { xpContext }
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
		anim.contexts = { xpContext }
	end
	
	-- Calculate delta for duration and animation check
	local delta = math.abs(targetRatio - anim.startRatio)
	
	-- Check if should animate
	local shouldAnimate, reason = AnimationUtils.ShouldAnimate(delta, config)
	
	AddDebugMessage(string.format("ShouldAnimate: %s, reason=%s, delta=%.4f, startRatio=%.3f, targetRatio=%.3f", 
		tostring(shouldAnimate), reason, delta, anim.startRatio, targetRatio))
	
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
	
	AddDebugMessage(string.format("Starting animation: duration=%.2fs, flashConfig=%s, xpGained=%d, willFlash=%s", 
		duration, tostring(config.flashOnGain), incomingXpContext.xpGained or 0, tostring(willFlash)))
	
	-- Setup animation state
	anim.isAnimating = true
	anim.startTime = now
	anim.duration = duration
	anim.targetRatio = targetRatio
	
	-- Setup flash effect if enabled and XP was gained
	if willFlash then
		-- Only start flash if not already flashing (prevent restart/flicker on retargeting)
		-- Also check cooldown to prevent double flash on rapid XP events (e.g., quest turn-in + bonus)
		local inCooldown = anim.flashCooldownUntil and now < anim.flashCooldownUntil
		if not anim.isFlashing and not inCooldown then
			anim.isFlashing = true
			anim.flashStartTime = now
			anim.flashDuration = AnimationUtils.GetConstants().GAIN_FLASH_HALF_PERIOD_SECONDS * 2
			AddDebugMessage(string.format("Flash enabled for bar: duration=%.2fs", anim.flashDuration))
		elseif inCooldown then
			local cooldownRemaining = anim.flashCooldownUntil - now
			AddDebugMessage(string.format("Flash skipped: cooldown active (%.3fs remaining)", cooldownRemaining))
		else
			AddDebugMessage("Flash skipped: already flashing (aggregating XP gains)")
		end
	else
		anim.isFlashing = false
		if config.flashOnGain and (not xpContext.xpGained or xpContext.xpGained == 0) then
			AddDebugMessage("Flash disabled: xpGained is 0 (no actual XP gain)")
		elseif not config.flashOnGain then
			AddDebugMessage("Flash disabled: flashOnGain config is false")
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
			-- Bar finished both animation AND flash, mark for removal
			AddDebugMessage(string.format("Bar %s finished animating and flashing", tostring(bar:GetName() or bar)))
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
		config = { enableAnimations = true, flashOnGain = true }
	end
	
	-- Check if flash complete BEFORE building step context
	if anim.isFlashing then
		local flashElapsed = now - anim.flashStartTime
		if flashElapsed >= anim.flashDuration then
			anim.isFlashing = false
			-- Set cooldown to prevent immediate restart (prevents double flash on rapid XP events)
			anim.flashCooldownUntil = now + 0.1 -- 100ms cooldown after flash completes
			AddDebugMessage(string.format("Flash completed: elapsed=%.3fs, cooldown until %.3f", 
				flashElapsed, anim.flashCooldownUntil))
		end
	end
	
	-- Get XP context from aggregated contexts
	local xpContext = AnimationUtils.AggregateContexts(anim.contexts)
	
	-- Build step context (will include current flash state)
	local stepContext = AnimationUtils.BuildStepContext(bar, now, config, xpContext)
	
	-- Debug: Log detailed flash timing if enabled
	if debugFlashTiming and stepContext.flashData then
		local fd = stepContext.flashData
		AddFlashTimingLog(string.format("V2: elapsed=%.3fs phase=%s alpha=%.3f duration=%.2fs halfPeriod=%.2fs",
			fd.elapsed, fd.phase or "unknown", fd.currentAlpha, fd.duration, fd.halfPeriod or 0))
	end
	
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
	
	-- Clear contexts only when BOTH animation and flash are complete
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
