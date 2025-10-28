-- XP Bar Enhanced - Animation Mixin (v2)
-- Behavior mixin for value smoothing, transitions, and flash effects

-------------------------------------------------------------------
-- GLOBAL ANIMATION MIXIN
-------------------------------------------------------------------

---@class XPBarAnimationMixin
XPBarAnimationMixin = {}

local AnimationMixin = XPBarAnimationMixin

-------------------------------------------------------------------
-- ANIMATION STATE
-------------------------------------------------------------------

--- Initialize animation state (called by OnLoad)
function AnimationMixin:InitializeAnimationState()
	self.__animation = self.__animation or {
		targetValue = 0,
		currentValue = 0,
		smoothing = 0.2, -- Default smoothing duration in seconds
		ticker = nil,
		flashTicker = nil,
	}
end

-------------------------------------------------------------------
-- VALUE SMOOTHING
-------------------------------------------------------------------

--- Smooth value transition over time
---@param targetValue number Target value (0-1 ratio)
---@param duration number|nil Smoothing duration in seconds (optional)
function AnimationMixin:SmoothValueTransition(targetValue, duration)
	if not self.__animation then
		self:InitializeAnimationState()
	end
	
	local config = self.__xpbar_config or {}
	local animConfig = config.animation or {}
	
	-- Check if smoothing is enabled
	if animConfig.enabled == false then
		-- No smoothing, instant update
		self:SetValue(targetValue)
		return
	end
	
	-- Stop existing animation
	if self.__animation.ticker then
		self.__animation.ticker:Cancel()
		self.__animation.ticker = nil
	end
	
	-- Set up smooth transition
	self.__animation.targetValue = targetValue
	self.__animation.currentValue = self:GetValue()
	
	local smoothDuration = duration or animConfig.valueSmoothing or 0.2
	local startTime = GetTime()
	local startValue = self.__animation.currentValue
	local delta = targetValue - startValue
	
	-- Create ticker for smooth animation
	self.__animation.ticker = C_Timer.NewTicker(0.016, function() -- ~60 FPS
		local elapsed = GetTime() - startTime
		local progress = math.min(1, elapsed / smoothDuration)
		
		-- Ease-out quad easing
		local easedProgress = 1 - (1 - progress) * (1 - progress)
		local newValue = startValue + (delta * easedProgress)
		
		self:SetValue(newValue)
		self.__animation.currentValue = newValue
		
		-- Stop when complete
		if progress >= 1 then
			if self.__animation.ticker then
				self.__animation.ticker:Cancel()
				self.__animation.ticker = nil
			end
		end
	end)
end

-------------------------------------------------------------------
-- FLASH EFFECTS
-------------------------------------------------------------------

--- Play XP gain flash effect (optional)
---@param context table Context from ContextBuilder
function AnimationMixin:FlashXPGain(context)
	local flashOverlay = self.GainFlash
	if not flashOverlay then
		return -- Flash overlay not present, skip
	end
	
	local config = self.__xpbar_config or {}
	local animConfig = config.animation or {}
	
	if animConfig.enabled == false then
		return -- Animations disabled
	end
	
	-- Play flash animation: fade in then fade out
	self:PlayFlashAnimation(flashOverlay, 0.3, 0.3) -- 0.3s in, 0.3s out
end

--- Play level-up flash effect (optional)
---@param context table Context from ContextBuilder
function AnimationMixin:FlashLevelUp(context)
	local flashOverlay = self.GainFlash
	if not flashOverlay then
		return -- Flash overlay not present, skip
	end
	
	local config = self.__xpbar_config or {}
	local animConfig = config.animation or {}
	
	if animConfig.enabled == false then
		return -- Animations disabled
	end
	
	-- Play longer flash for level-up
	self:PlayFlashAnimation(flashOverlay, 0.5, 0.5) -- 0.5s in, 0.5s out
end

--- Play flash animation on texture
---@param texture table Texture object
---@param fadeInDuration number Fade in duration in seconds
---@param fadeOutDuration number Fade out duration in seconds
function AnimationMixin:PlayFlashAnimation(texture, fadeInDuration, fadeOutDuration)
	if not texture then
		return
	end
	
	if not self.__animation then
		self:InitializeAnimationState()
	end
	
	-- Stop existing flash
	if self.__animation.flashTicker then
		self.__animation.flashTicker:Cancel()
		self.__animation.flashTicker = nil
	end
	
	-- Set up flash animation
	local startTime = GetTime()
	local phase = "in" -- "in" or "out"
	
	texture:Show()
	
	self.__animation.flashTicker = C_Timer.NewTicker(0.016, function()
		local elapsed = GetTime() - startTime
		
		if phase == "in" then
			local progress = math.min(1, elapsed / fadeInDuration)
			local alpha = progress
			texture:SetAlpha(alpha)
			
			if progress >= 1 then
				phase = "out"
				startTime = GetTime() -- Reset for fade out
			end
		else -- phase == "out"
			local progress = math.min(1, elapsed / fadeOutDuration)
			local alpha = 1 - progress
			texture:SetAlpha(alpha)
			
			if progress >= 1 then
				texture:Hide()
				texture:SetAlpha(0)
				if self.__animation.flashTicker then
					self.__animation.flashTicker:Cancel()
					self.__animation.flashTicker = nil
				end
			end
		end
	end)
end

-------------------------------------------------------------------
-- XP GAIN ANIMATION (Optional)
-------------------------------------------------------------------

--- Play XP gain animation (optional override point)
---@param context table Context from ContextBuilder
function AnimationMixin:PlayXPGainAnimation(context)
	-- Smooth value transition to new XP
	if context.xpMax and context.xpMax > 0 then
		local targetRatio = (context.currentXP or 0) / context.xpMax
		self:SmoothValueTransition(targetRatio)
	end
end

--- Play level-up animation (optional override point)
---@param context table Context from ContextBuilder
function AnimationMixin:PlayLevelUpAnimation(context)
	-- On level-up, reset to 0 then animate to new XP
	self:SetValue(0)
	
	if context.xpMax and context.xpMax > 0 then
		local targetRatio = (context.currentXP or 0) / context.xpMax
		C_Timer.After(0.1, function() -- Small delay before animating
			self:SmoothValueTransition(targetRatio)
		end)
	end
end

-------------------------------------------------------------------
-- CLEANUP
-------------------------------------------------------------------

--- OnHide - Cancel animations
function AnimationMixin:OnHide()
	if self.__animation then
		if self.__animation.ticker then
			self.__animation.ticker:Cancel()
			self.__animation.ticker = nil
		end
		if self.__animation.flashTicker then
			self.__animation.flashTicker:Cancel()
			self.__animation.flashTicker = nil
		end
	end
end

return AnimationMixin
