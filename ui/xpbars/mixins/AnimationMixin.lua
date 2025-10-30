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
	
	-- Normalize valueSmoothing (accept boolean true/false or a numeric duration)
	local function GetSmoothDuration(self)
		local animCfg = nil
		if self then
			animCfg = (self.__xpbar_config and self.__xpbar_config.animation) or (self.config and self.config.animation) or {}
		end
		local vs = animCfg and animCfg.valueSmoothing
		-- Legacy config used boolean; true -> default duration, false -> disabled
		if type(vs) == "boolean" then
			vs = vs and 0.25 or 0
		elseif type(vs) ~= "number" then
			-- When nil or other types, use default
			vs = 0.25
		end
		-- Ensure numeric and non-negative
		if vs <= 0 then
			-- treat non-positive as disabled (instant)
			vs = 0
		end
		return vs
	end

	local smoothDuration = GetSmoothDuration(self)
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

-- Replace old SmoothValueTransition with context-first implementation
function XPBarAnimationMixin:SmoothValueTransition(context, duration)
    if not context then
        error("SmoothValueTransition requires an explicit immutable context")
    end

    -- derive max and target ratio from context (explicit)
    local maxv = context.xpMax or 1
    local targetRatio = (context.currentXP or 0) / (maxv > 0 and maxv or 1)

    -- derive start ratio from context (prefer explicit previous/current delta)
    local startXP = nil
    if context.previousXP ~= nil then
        startXP = context.previousXP
    elseif context.currentXP and context.xpGained then
        startXP = context.currentXP - context.xpGained
    end
    startXP = startXP or 0
    local startRatio = startXP / (maxv > 0 and maxv or 1)

    -- Normalize smoothing duration from config (boolean or number)
    local animCfg = (self.__xpbar_config and self.__xpbar_config.animation) or {}
    local vs = animCfg.valueSmoothing
    if type(vs) == "boolean" then
        vs = vs and 0.25 or 0
    elseif type(vs) ~= "number" then
        vs = 0.25
    end
    local smoothDuration = duration or vs

    -- If smoothing is disabled or zero duration, set instantly
    if not smoothDuration or smoothDuration <= 0 then
        if self.StatusBar and self.StatusBar.SetValue then
            self.StatusBar:SetValue(targetRatio)
        end
        return
    end

    -- Setup animation state
    self.__animation = {
        targetValue = targetRatio,
        startValue = startRatio,
        startTime = GetTime(),
        duration = smoothDuration
    }

    -- Ensure we have an OnUpdate ticker to drive the smooth animation
    if not self.__animationTicker then
        self.__animationTicker = self:CreateAnimationTicker()
    end
end

-- Helper to create/update ticker (non-intrusive; existing code may reuse this)
function XPBarAnimationMixin:CreateAnimationTicker()
    -- create a frame OnUpdate handler attached to this frame (non-leaking)
    local owner = self
    local frame = owner.__animationTickerFrame
    if not frame then
        frame = CreateFrame("Frame", nil, owner)
        owner.__animationTickerFrame = frame
    end

    frame:SetScript("OnUpdate", function(_, elapsed)
        local anim = owner.__animation
        if not anim then
            frame:SetScript("OnUpdate", nil)
            owner.__animationTicker = nil
            return
        end

        local now = GetTime()
        local t = (now - anim.startTime) / (anim.duration > 0 and anim.duration or 1)
        if t >= 1 then
            -- end animation
            if owner.StatusBar and owner.StatusBar.SetValue then
                owner.StatusBar:SetValue(anim.targetValue)
            end
            owner.__animation = nil
            frame:SetScript("OnUpdate", nil)
            owner.__animationTicker = nil
            return
        end

        -- smoothstep / linear interpolation (use simple ease-out)
        local progress = t
        -- linear interpolation
        local value = anim.startValue + (anim.targetValue - anim.startValue) * progress
        if owner.StatusBar and owner.StatusBar.SetValue then
            owner.StatusBar:SetValue(value)
        end
    end)

    return frame
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
    -- require explicit context
    if not context then
        error("PlayXPGainAnimation requires an explicit immutable context")
    end

    -- Only animate when xpGained present and positive
    if not context.xpGained or context.xpGained <= 0 then
        return
    end

    -- Use config duration if provided by animation settings, else nil to use normalized default
    local cfg = (self.__xpbar_config and self.__xpbar_config.animation) or {}
    local duration = cfg and cfg.valueSmoothingDuration -- optional numeric override

    -- Start smooth transition using explicit context
    self:SmoothValueTransition(context, duration)

    -- existing gain/flash behavior (keep original flash handling if present)
    if self.PlayGainFlash and cfg and cfg.xpGainFlash then
        -- keep original flash trigger logic here if necessary
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
