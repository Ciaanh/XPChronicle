-- XP Bar Enhanced - V2 Animation Base Mixin
-- Common animation behavior for V2 bar styles

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
		contexts = {} -- For context aggregation during retargeting
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
	if not Addon.AnimationManager then
		-- Fallback to instant update if manager not available
		if self.ApplyAnimationStep then
			local now = GetTime()
			local instantContext = {
				currentRatio = targetRatio,
				targetRatio = targetRatio,
				startRatio = self._currentRatio or 0,
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
			self:ApplyAnimationStep(instantContext)
		end
		self._currentRatio = targetRatio
		return
	end
	
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
		self.animation.contexts = {}
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
	-- Default config, override in bar mixin
	return {
		enableAnimations = true,
		flashOnGain = true
	}
end

--- Animation step callback
-- Called every frame during animation with interpolated values
-- @param stepContext table: Step context with currentRatio, targetRatio, progress, timing, flash data, config, xpContext
function AnimationBase:ApplyAnimationStep(stepContext)
	  self:AnimateBarPosition(stepContext) -- Update bar fill
	  self:AnimateBarEffect(stepContext)   -- Update visual effects (flash, etc)
end

--- Update bar position (ABSTRACT - must be implemented by style)
-- Updates the bar fill based on currentRatio
-- @param stepContext table: Step context with currentRatio and other data
function AnimationBase:AnimateBarPosition(stepContext)
	-- This is an abstract method that must be implemented by the style mixin
	-- Example for StatusBar-based styles (Flat, Legacy):
	--   self.StatusBar:SetValue(stepContext.currentRatio)
	error("AnimateBarPosition must be implemented by style mixin")
end

--- Update visual effects (ABSTRACT - must be implemented by style)
-- Updates flash overlay and other visual effects
-- @param stepContext table: Step context with flashData and other data
function AnimationBase:AnimateBarEffect(stepContext)
	-- This is an abstract method that must be implemented by the style mixin
	-- Example for StatusBar-based styles (Flat, Legacy):
	--   if stepContext.flashData and stepContext.flashData.active then
	--     local color = stepContext.flashData.color
	--     self.GainFlash:SetColorTexture(color.r, color.g, color.b, stepContext.flashData.currentAlpha)
	--     self.GainFlash:Show()
	--   else
	--     self.GainFlash:Hide()
	--   end
	error("AnimateBarEffect must be implemented by style mixin")
end

--- Animation completion callback (optional hook)
-- Called when animation completes naturally (not when canceled)
-- @param xpContext table: Final XP context
function AnimationBase:OnAnimationComplete(xpContext)
	-- Optional hook for style-specific completion logic
	-- Override in style mixin if needed
end

-----------------------------------
-- Export
-----------------------------------
-- Export as global for composition in StyleBuilder (consistent with other mixins)
XPBarAnimationMixin = AnimationBase
Addon.AnimationBase = AnimationBase -- Keep for backward compatibility

