-- XP Bar Enhanced -  Animation Base Mixin
-- Common animation behavior for  bar styles

local AddonName, Addon = ...

-----------------------------------
-- Animation Base Mixin
-----------------------------------
local AnimationBase = {}

--- Initialize animation system for this bar
-- Called during bar initialization (OnLoad or Initialize)
function AnimationBase:InitializeAnimation()
	-- Initialize animation state
	self.animation = {
		isAnimating = false,
		startRatio = 0,
		targetRatio = 0,
		startTime = 0,
		duration = 0,
		isFlashing = false,
		flashStartTime = 0,
		flashDuration = 0,
		eventContext = nil -- Single immutable event context (144 bytes)
	}
	
	-- Track current displayed ratio (for retargeting)
	self._currentRatio = 0
end

--- Start animation to target ratio
-- Delegates to AnimationManager for actual animation logic
-- @param targetRatio number: Target ratio (0.0-1.0)
-- @param xpContext table: XP context { xpBefore, xpAfter, xpMax, xpGained, restedXP, isResting, hasRestedXP, level, timestamp }
-- @param config table: Animation config { enableAnimations, flashOnGain }
function AnimationBase:StartAnimation(targetRatio, xpContext, config)
	if XPBarDebugLog then XPBarDebugLog:Log("AnimationBase", "StartAnimation called for", self:GetName() or "unknown", "targetRatio:", targetRatio, "enableAnimations:", config and config.enableAnimations or "nil") end
	if not Addon.AnimationManager then
		if XPBarDebugLog then XPBarDebugLog:Log("AnimationBase", "StartAnimation fallback (no manager)") end
		-- Fallback to instant update if manager not available
		if self.ApplyAnimationStep then
			local now = GetTime()
			local instantIterationData = {
				currentRatio = targetRatio,
				targetRatio = targetRatio,
				startRatio = self._currentRatio or 0,
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
			self:ApplyAnimationStep(instantIterationData, xpContext)
		end
		self._currentRatio = targetRatio
		return
	end
	
	if XPBarDebugLog then XPBarDebugLog:Log("AnimationBase", "StartAnimation delegating to AnimationManager") end
	-- Delegate to AnimationManager
	Addon.AnimationManager:AnimateTo(self, targetRatio, xpContext, config)
end

--- Cleanup animation state
-- Called when bar is hidden or style changes
function AnimationBase:CleanupAnimation()
	if Addon.AnimationManager then
		Addon.AnimationManager:Unregister(self)
	end
	
	if self.animation then
		self.animation.isAnimating = false
		self.animation.isFlashing = false
		self.animation.eventContext = nil
	end
end

--- Get current displayed ratio
-- Used for retargeting and debugging
-- @return number: Current ratio (0.0-1.0)
function AnimationBase:GetCurrentRatio()
	return self._currentRatio or 0
end

--- Set current displayed ratio
-- Called by AnimationManager during animation updates
-- @param ratio number: New current ratio (0.0-1.0)
function AnimationBase:SetCurrentRatio(ratio)
	self._currentRatio = ratio
end

--- Get animation configuration from database
-- Override in bar mixin if needed, or provide default config
-- @return table: { enableAnimations = bool, flashOnGain = bool }
function AnimationBase:GetAnimationConfig()
    -- First check for frame-specific config
    local frameConfig = self.__xpbar_config
    if frameConfig and frameConfig.animation then
        local anim = frameConfig.animation
        return {
            enableAnimations = anim.enableAnimations ~= false,
            flashOnGain = anim.flashOnGain ~= false
        }
    end

    -- Fall back to global database
    local Addon = XPBarEnhanced
    local db = Addon and Addon.Database and Addon.Database:GetDB()

    if db then
        return {
            enableAnimations = db.enableAnimations ~= false,
            flashOnGain = db.flashOnGain ~= false
        }
    end

    -- Fallback default config
    return {
        enableAnimations = true,
        flashOnGain = true
    }
end

--- Animation step callback
-- Called every frame during animation with separated iteration data and event context
-- @param iterationData table: Per-frame iteration data (currentRatio, progress, easedProgress, flashData, timing, config)
-- @param eventContext table: Immutable event context (XP state, session data, display flags - 144 bytes)
function AnimationBase:ApplyAnimationStep(iterationData, eventContext)
	if XPBarDebugLog then XPBarDebugLog:Log("AnimationBase", "ApplyAnimationStep called for", self:GetName() or "unknown") end
	  self:AnimateBarPosition(iterationData, eventContext) -- Update bar fill
	  self:AnimateBarEffect(iterationData, eventContext)   -- Update visual effects (flash, etc)
end

--- Update bar position (ABSTRACT - must be implemented by style)
-- Updates the bar fill based on currentRatio
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function AnimationBase:AnimateBarPosition(iterationData, eventContext)
	-- This is an abstract method that must be implemented by the style mixin
	-- Example for StatusBar-based styles (Flat, Classic):
	--   self.StatusBar:SetValue(iterationData.currentRatio)
	error("AnimateBarPosition must be implemented by style mixin")
end

--- Update visual effects (ABSTRACT - must be implemented by style)
-- Updates flash overlay and other visual effects
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function AnimationBase:AnimateBarEffect(iterationData, eventContext)
	-- This is an abstract method that must be implemented by the style mixin
	-- Example for StatusBar-based styles (Flat, Classic):
	--   if iterationData.flashData and iterationData.flashData.active then
	--     self.GainFlash:SetColorTexture(1, 1, 1, iterationData.flashData.currentAlpha)
	--     self.GainFlash:Show()
	--   else
	--     self.GainFlash:Hide()
	--   end
	error("AnimateBarEffect must be implemented by style mixin")
end

--- Animation completion callback (optional hook)
-- Called when animation completes naturally (not when canceled)
-- @param eventContext table: Final immutable event context
function AnimationBase:OnAnimationComplete(eventContext)
	-- Optional hook for style-specific completion logic
	-- Override in style mixin if needed
end

-----------------------------------
-- Export
-----------------------------------
-- Export as global for composition in StyleBuilder (consistent with other mixins)
XPBarAnimationMixin = AnimationBase
Addon.AnimationBase = AnimationBase -- Keep for backward compatibility

