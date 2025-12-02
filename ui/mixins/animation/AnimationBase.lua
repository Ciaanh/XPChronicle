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
function AnimationBase:StartAnimation(targetRatio, context, config)
    -- Check if animations are disabled
    if config and config.enableAnimations == false then
        self:RenderBar(context)
        return
    end

    if not Addon.AnimationManager then
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
            self:ApplyAnimationStep(instantIterationData, context)
        end
        self._currentRatio = targetRatio
        return
    end

    -- Delegate to AnimationManager
    Addon.AnimationManager:AnimateTo(self, targetRatio, context, config)

    -- Update text
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
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
	self:AnimateBarPosition(iterationData, eventContext) -- Update bar fill
	self:AnimateBarEffect(iterationData, eventContext) -- Update visual effects (flash, etc)
end

--- Update bar position (ABSTRACT - must be implemented by style)
-- Updates the bar fill based on currentRatio
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function AnimationBase:AnimateBarPosition(iterationData, eventContext)
	-- Prefer style-specific UpdateGainedBar if provided (handles overlay layout, colors, and text updates)
	if self.UpdateGainedBar and iterationData and iterationData.currentRatio then
		-- UpdateGainedBar takes currentRatio and immutable context
		self:UpdateGainedBar(iterationData.currentRatio, eventContext)
		return
	else
		error("UpdateGainedBar must be implemented in style mixin")
	end
end

--- Update visual effects (ABSTRACT - must be implemented by style)
-- Updates flash overlay and other visual effects
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function AnimationBase:AnimateBarEffect(iterationData, eventContext)
	local flashData = iterationData and iterationData.flashData
	-- attempt to find GainFlash on StatusBar first, fallback to frame GainFlash
	local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
	if not gainFlash then
		return
	end
	if flashData and flashData.active and flashData.currentAlpha and flashData.currentAlpha > 0 then
		local XPBarColors = _G.XPBarColors
		local hasRestedXP = eventContext and eventContext.hasRestedXP
		local colorKey = hasRestedXP and Color.Rested or Color.XpBar
		local color = XPBarColors and XPBarColors.GetUserColor and XPBarColors:GetUserColor(colorKey)
		if color then
			gainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
		else
			gainFlash:SetColorTexture(1, 1, 1, flashData.currentAlpha)
		end
		gainFlash:Show()
	else
		gainFlash:Hide()
	end

	if iterationData and iterationData.questOverlayAlpha then
		if self.StatusBar then
			local complete = self.StatusBar.QuestOverlayComplete
			local incomplete = self.StatusBar.QuestOverlayIncomplete
			if complete and iterationData.questOverlayCompleteInitialAlpha then
				local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
				complete:SetAlpha(newAlpha)
			end
			if incomplete and iterationData.questOverlayIncompleteInitialAlpha then
				local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
				incomplete:SetAlpha(newAlpha)
			end
		else
			-- frame-level overlays
			if self.QuestOverlayComplete and iterationData.questOverlayCompleteInitialAlpha then
				local newAlpha = iterationData.questOverlayCompleteInitialAlpha * iterationData.questOverlayAlpha
				self.QuestOverlayComplete:SetAlpha(newAlpha)
			end
			if self.QuestOverlayIncomplete and iterationData.questOverlayIncompleteInitialAlpha then
				local newAlpha = iterationData.questOverlayIncompleteInitialAlpha * iterationData.questOverlayAlpha
				self.QuestOverlayIncomplete:SetAlpha(newAlpha)
			end
		end
	end
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
