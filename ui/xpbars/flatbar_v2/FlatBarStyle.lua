-- XP Bar Enhanced - FlatBar Style v2
-- Minimal style file: XML owns visual creation via contract.
-- Only provides config and registration. No overrides needed for standard flat layout.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase_v2 then
	error(
		"FlatBarStyle: v2 core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
	)
end

-------------------------------------------------------------------
-- Debug Message Collection
-------------------------------------------------------------------
local debugMessages = {}
local MAX_DEBUG_MESSAGES = 30

local function AddDebugMessage(message)
	table.insert(debugMessages, string.format("[%.3f] %s", GetTime(), message))
	if #debugMessages > MAX_DEBUG_MESSAGES then
		table.remove(debugMessages, 1)
	end
end

-- Command to dump debug messages to error frame
SLASH_FLATBARDEBUG1 = "/flatbardebug"
SlashCmdList["FLATBARDEBUG"] = function()
	if #debugMessages == 0 then
		UIErrorsFrame:AddMessage("No FlatBar debug messages collected.", 1.0, 1.0, 0.0, 1.0)
		error("No FlatBar debug messages collected.")
		return
	end
	
	-- Dump all messages to error frame
	UIErrorsFrame:AddMessage("=== FlatBar Debug Messages ===", 1.0, 1.0, 0.0, 1.0)
	for _, msg in ipairs(debugMessages) do
		UIErrorsFrame:AddMessage(msg, 1.0, 1.0, 1.0, 1.0)
		error(msg)
	end
	UIErrorsFrame:AddMessage(string.format("=== Total: %d messages ===", #debugMessages), 1.0, 1.0, 0.0, 1.0)
	--error(string.format("=== Total: %d messages ===", #debugMessages))
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Minimal style template: don't duplicate aliasing; rely on BaseMixin
local FlatBarStyleTemplate = {}

-------------------------------------------------------------------
-- V2 ANIMATION IMPLEMENTATION (StatusBar-based)
-------------------------------------------------------------------


--- Update bar position - smooth fill animation
-- @param stepContext table: Step context with currentRatio
-- Note: Rested overlay animates automatically because it's positioned BEHIND the StatusBar
--       with width = currentXP + restedXP (set once at animation start). As the StatusBar
--       fill animates from old to new currentXP, it progressively reveals/covers the rested
--       overlay beneath it, creating smooth animation without any per-frame updates.
function FlatBarStyleTemplate:AnimateBarPosition(stepContext)
	if self.StatusBar then
		self.StatusBar:SetValue(stepContext.currentRatio)
	end
end

--- Update visual effects - flash overlay animation
-- @param stepContext table: Step context with flashData
function FlatBarStyleTemplate:AnimateBarEffect(stepContext)
	if not self.GainFlash then
		return
	end
	
	-- Ensure blend mode is set (matches V1 behavior)
	if not self._flashBlendModeSet then
		self.GainFlash:SetBlendMode("ADD")
		self._flashBlendModeSet = true
	end

	local flashData = stepContext.flashData
	if flashData and flashData.active and flashData.currentAlpha > 0 then
		-- Get user-defined color based on rested state (matches V1 behavior)
		-- Use Rested color if player had rested XP available (meaning the gain consumed rested bonus)
		local XPBarColors = _G.XPBarColors
		local hasRestedXP = stepContext.xpContext and stepContext.xpContext.hasRestedXP
		local colorKey = hasRestedXP and Color.Rested or Color.XpBar
		local color = XPBarColors:GetUserColor(colorKey)
		
		-- Debug: Log flash color selection (include bar identity)
		-- Only log every 5th frame to reduce spam
		if not self._flashLogCounter then
			self._flashLogCounter = 0
		end
		self._flashLogCounter = self._flashLogCounter + 1
		if self._flashLogCounter >= 5 then
			local restedXP = (stepContext.xpContext and stepContext.xpContext.restedXP) or 0
			AddDebugMessage(string.format("Flash[%s]: hasRestedXP=%s, restedXP=%d, alpha=%.3f",
				tostring(self:GetName() or "unnamed"), 
				hasRestedXP and "true" or "false",
				restedXP,
				flashData.currentAlpha))
			self._flashLogCounter = 0
		end
		
		-- Show flash with user color and animated alpha (fades to 0)
		self.GainFlash:SetColorTexture(color.r, color.g, color.b, flashData.currentAlpha)
		self.GainFlash:Show()
	else
		-- Hide flash when not active, complete, or alpha is 0
		if self.GainFlash:IsShown() then
			AddDebugMessage(string.format("Flash[%s]: HIDING - active=%s, alpha=%.3f",
				tostring(self:GetName() or "unnamed"), 
				flashData and tostring(flashData.active) or "nil", 
				flashData and flashData.currentAlpha or 0))
		end
		self.GainFlash:Hide()
		self._flashLogCounter = nil -- Reset counter when hiding
	end
end

--- Get animation configuration from database
-- @return table: Animation config { enableAnimations, flashOnGain }
function FlatBarStyleTemplate:GetAnimationConfig()
	-- First check for frame-specific config
	local frameConfig = self.__xpbar_config
	if frameConfig and frameConfig.animation then
		local anim = frameConfig.animation
		return {
			enableAnimations = anim.enableAnimations ~= false, -- Default true
			flashOnGain = anim.flashOnGain ~= false -- Default true
		}
	end
	
	-- Fall back to global database
	local Addon = XPBarEnhanced
	local db = Addon and Addon.Database and Addon.Database:GetDB()

	if db then
		return {
			enableAnimations = db.enableAnimations ~= false, -- Default true
			flashOnGain = db.flashOnGain ~= false -- Default true
		}
	end

	-- Fallback default config
	return {
		enableAnimations = true,
		flashOnGain = true
	}
end

-------------------------------------------------------------------
-- OVERRIDE: Bar Update with V2 Animation
-------------------------------------------------------------------

--- Update bar with animation (overrides VisualsMixin)
-- @param context table: Immutable XP context
function FlatBarStyleTemplate:UpdateCurrentXPBar(context)
	if not context then
		error("UpdateCurrentXPBar requires an explicit immutable context")
	end
	
	-- Calculate target ratio
	local targetRatio = 0
	if context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end
	
	-- Initialize current ratio if not set (first update)
	if not self._currentRatio or self._currentRatio == 0 then
		-- Get current StatusBar value as starting point
		if self.StatusBar then
			local currentValue = self.StatusBar:GetValue()
			if currentValue and currentValue > 0 then
				if self.SetCurrentRatio then
					self:SetCurrentRatio(currentValue)
				end
			end
		end
	end
	
	-- Build XP context for animation system
	local xpContext = {
		xpBefore = context.xpBefore or context.previousXP or 0,
		xpAfter = context.xpAfter or context.currentXP or 0,
		xpMax = context.xpMax or 1,
		xpGained = context.xpGained or 0,
		restedXP = context.restedXP or 0,
		isResting = context.isResting or false,
		hasRestedXP = context.hasRestedXP or false,
		level = context.level or 1,
		timestamp = GetTime()
	}
	
	-- Debug logging
	local barName = self:GetName() or tostring(self)
	AddDebugMessage(string.format("FlatBar[%s] UpdateCurrentXPBar - targetRatio: %.3f, xpGained: %d, hasRestedXP: %s, restedXP: %d", 
		barName, targetRatio, xpContext.xpGained, xpContext.hasRestedXP and "true" or "false", xpContext.restedXP))
	
	-- Get animation config
	local config = self:GetAnimationConfig()
	
	-- Debug animation config with source info
	local configSource = "default"
	if self.__xpbar_config and self.__xpbar_config.animation then
		configSource = "frame"
	elseif XPBarEnhanced and XPBarEnhanced.Database then
		configSource = "global"
	end
	AddDebugMessage(string.format("FlatBar[%s] Animation config - source: %s, enabled: %s, flash: %s", 
		barName, configSource, tostring(config.enableAnimations), tostring(config.flashOnGain)))
	
	-- Debug: Check what animation methods are available
	AddDebugMessage(string.format("Methods available: StartAnimation=%s, InitializeAnimation=%s, CleanupAnimation=%s",
		tostring(self.StartAnimation ~= nil), 
		tostring(self.InitializeAnimation ~= nil),
		tostring(self.CleanupAnimation ~= nil)))
	
	-- Start animation (delegates to AnimationManager via AnimationBase)
	if self.StartAnimation then
		self:StartAnimation(targetRatio, xpContext, config)
	else
		-- Fallback: instant update if animation system not available
		AddDebugMessage("StartAnimation not available, using instant update")
		if self.StatusBar then
			self.StatusBar:SetValue(targetRatio)
		end
		-- Update tracked ratio
		if self.SetCurrentRatio then
			self:SetCurrentRatio(targetRatio)
		end
	end
	
	-- Update bar colors (non-animated visuals)
	if self.UpdateBarColors then
		self:UpdateBarColors(context)
	end
end-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
	interaction = {enabled = true},
	tooltip = {enabled = true},
	position = {mode = "DRAGGABLE", positionKey = "FlatBar_v2"},
	style = {width = 565, height = 30, showQuestOverlays = true}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase_v2, FlatBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("flat", FlatBarXPBarMixin)

-------------------------------------------------------------------
-- PROGRAMMATIC HELPER
-------------------------------------------------------------------

--- Create FlatBar frame programmatically.
function XPBarEnhanced_CreateFlatBarFrame()
	local styleKey = "flat"

	local frame = XPBarStyleBuilder:CreateFrameForStyle(styleKey, DefaultConfig, "FlatBarTemplate_v2")
	frame:Show()

	_G.FlatBar_v2 = frame -- Global reference

	return frame
end
