-- XP Bar Enhanced - Base Mixin
-- Core functionality: event orchestration, Trigger/Action methods, overlay actions
-- Uses ContextBuilder for immutable contexts (no Session dependency)

-------------------------------------------------------------------
-- GLOBAL BASE MIXIN
-------------------------------------------------------------------

---@class XPBarMixinBase
XPBarMixinBase = {}

local BaseMixin = XPBarMixinBase

-- Reference to addon for Logger access
local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- PUBLIC API SURFACE
-------------------------------------------------------------------

--- Refresh bar state from game data ( unified pattern)
function BaseMixin:Refresh()
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "Refresh called")
	end

	-- Check if ContextBuilder exists
	if not XPBarContextBuilder then
		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "ERROR: XPBarContextBuilder not found")
		end
		error("XPBarContextBuilder not loaded")
	end

	local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")

	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "Refresh context built:", context ~= nil)
	end

	self:TriggerBarRefresh(context)
end

--- Full update - Called by XPBar controller for option/color changes
--- This provides V1 compatibility for live refresh features
--- @param context table Optional pre-built context (if provided by broadcaster)
function BaseMixin:FullUpdate(context)
	-- Prevent re-entrant calls
	if self._isUpdating then
		return
	end
	self._isUpdating = true

	-- Use provided context or build fresh one
	if not context then
		context = XPBarContextBuilder.BuildContext("FULL_UPDATE")
	end

	-- Use unified render pattern
	self:TriggerBarRefresh(context)

	self._isUpdating = nil
end

-------------------------------------------------------------------
-- LIFECYCLE METHODS
-------------------------------------------------------------------

--- OnLoad - Initialize bar state and register events
function BaseMixin:OnLoad()
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "OnLoad called")
	end
	-- Initialize internal config
	self.__xpbar_config = self.__xpbar_config or {}

	-- Initialize animation system (from AnimationBase mixin)
	if self.InitializeAnimation then
		self:InitializeAnimation()
	end

	-- Initialize position behavior (if present)
	if self.InitializePosition then
		self:InitializePosition()
	end

	-- Register common events
	self:RegisterCommonEvents()

	-- Call BuildVisuals if style provides it
	if self.BuildVisuals then
		self:BuildVisuals()
	end

	-- Apply style config if provided
	if self.ApplyStyle and self.__xpbar_config.style then
		self:ApplyStyle(self.__xpbar_config.style)
	end

	-- Register as observer for broadcast updates (color changes, etc.)
	-- This ensures multiple  bars receive updates simultaneously
	local Addon = XPBarEnhanced
	if Addon.XPBar and Addon.XPBar.RegisterObserver then
		-- Use frame name or generate unique ID
		local observerId = self:GetName() or ("_bar_" .. tostring(self))
		self.__observer_id = Addon.XPBar:RegisterObserver(self, observerId)
	end

	-- Initial refresh
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "OnLoad calling initial Refresh")
	end
	if not self.Refresh then
		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "ERROR: Refresh method not found on frame")
		end
		error("Refresh method missing")
	end
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "OnLoad about to call self:Refresh()")
	end
	self:Refresh()
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "OnLoad Refresh completed")
	end
end

--- OnShow - Called when bar becomes visible
function BaseMixin:OnShow()
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "OnShow called")
	end
	-- Refresh state when shown
	self:Refresh()

	-- Register as observer if not already registered
	-- This handles cases where bar is created but not via OnLoad
	if not self.__observer_id then
		local Addon = XPBarEnhanced
		if Addon.XPBar and Addon.XPBar.RegisterObserver then
			local observerId = self:GetName() or ("_bar_" .. tostring(self))
			self.__observer_id = Addon.XPBar:RegisterObserver(self, observerId)
		end
	end

	-- Start periodic text refresh ticker (updates session/level time and rate text)
	if not self._textRefreshTicker then
		self._textRefreshTicker =
			C_Timer.NewTicker(
			2.5,
			function()
				if self and self:IsShown() then
					-- Update session text with fresh time values (computes from Session service)
					-- Don't pass context so it always fetches fresh time
					if self.UpdateSessionText then
						self:UpdateSessionText(nil)
					end
					-- Update rate text (XP/hour and time to level) with fresh calculations
					if self.UpdateRateText then
						self:UpdateRateText(nil)
					end
				end
			end
		)
	end
end

--- OnHide - Called when bar becomes hidden
function BaseMixin:OnHide()
	-- Cancel periodic text refresh ticker
	if self._textRefreshTicker then
		self._textRefreshTicker:Cancel()
		self._textRefreshTicker = nil
	end

	-- Cleanup animation state (from AnimationBase mixin)
	if self.CleanupAnimation then
		self:CleanupAnimation()
	end

	-- Note: Don't unregister observer here - we want to receive updates
	-- even when hidden (e.g., color changes should update all bars)
end

-------------------------------------------------------------------
-- EVENT REGISTRATION
-------------------------------------------------------------------

--- Register common XP events
function BaseMixin:RegisterCommonEvents()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_XP_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("UPDATE_EXHAUSTION")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")
end

--- Register quest-related events (called by behavior mixin or style)
function BaseMixin:RegisterQuestEvents()
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("QUEST_REMOVED")
	self:RegisterEvent("QUEST_TURNED_IN")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	self:RegisterEvent("QUEST_WATCH_UPDATE")
end

function BaseMixin:UnsubscribeFromEvents()
	-- Unregister common events
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("PLAYER_XP_UPDATE")
	self:UnregisterEvent("PLAYER_LEVEL_UP")
	self:UnregisterEvent("UPDATE_EXHAUSTION")
	self:UnregisterEvent("PLAYER_UPDATE_RESTING")
	self:UnregisterEvent("TIME_PLAYED_MSG")

	-- If mixin registered quest events, unregister them too
	self:UnregisterEvent("QUEST_ACCEPTED")
	self:UnregisterEvent("QUEST_REMOVED")
	self:UnregisterEvent("QUEST_TURNED_IN")
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	self:UnregisterEvent("UNIT_QUEST_LOG_CHANGED")
	self:UnregisterEvent("QUEST_WATCH_UPDATE")
end

-------------------------------------------------------------------
-- EVENT ORCHESTRATION (Trigger/Action Pattern)
-------------------------------------------------------------------

--- Event dispatcher - calls ContextBuilder and TriggerBarRefresh ( unified pattern)
---@param event string Event name
---@param ... any Event arguments
function BaseMixin:OnEvent(event, ...)
	if event == "TIME_PLAYED_MSG" then
		return
	end

	local context
	if event == "PLAYER_LEVEL_UP" then
		local newLevel = ...
		context = XPBarContextBuilder.BuildContext(event, newLevel)
	else
		context = XPBarContextBuilder.BuildContext(event, ...)
	end

	-- "PLAYER_ENTERING_WORLD"
	-- "PLAYER_XP_UPDATE"
	-- "PLAYER_LEVEL_UP"
	-- "UPDATE_EXHAUSTION"
	-- "PLAYER_UPDATE_RESTING"
	-- "QUEST_ACCEPTED"
	-- "QUEST_REMOVED"
	-- "QUEST_TURNED_IN"
	-- "QUEST_LOG_UPDATE"
	-- "UNIT_QUEST_LOG_CHANGED"
	-- "QUEST_WATCH_UPDATE"
	-- "TIME_PLAYED_MSG"

	if context then
		self:TriggerBarRefresh(context)
	end
end

-------------------------------------------------------------------
-- TRIGGER METHODS (Orchestrate Actions - NOT overridable)
-------------------------------------------------------------------

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN (Phase 3: Refactor)
-------------------------------------------------------------------

--- Single entry point for all bar updates (NEW unified pattern)
--- Orchestrates animation vs immediate render based on context
---@param context table Immutable context from ContextBuilder with event flags
function BaseMixin:TriggerBarRefresh(context)
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "TriggerBarRefresh called")
	end

	-- Explicit context required
	if not context then
		error("TriggerBarRefresh requires an explicit immutable context")
	end

	-- Validate required methods
	if not self.RenderBar then
		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "ERROR: RenderBar method not found on frame", self:GetName() or "unknown")
		end
		error("Style must implement RenderBar(context) method")
	end

	local frameName = self:GetName() or "unnamed"
	if XPBarDebugLog then
		XPBarDebugLog:Log("BaseMixin", "Frame:", frameName, "shouldAnimate:", tostring(context.shouldAnimate))
	end

	-- ORCHESTRATION: Decide between animation vs immediate render
	if context.shouldAnimate and self.StartAnimation then
		-- Animated update path
		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "Starting animation for", frameName)
		end

		-- Calculate target ratio for animation (use xpMax, not maxXP)
		local targetRatio = 0
		if context.currentXP and context.xpMax and context.xpMax > 0 then
			targetRatio = context.currentXP / context.xpMax
		end

		if XPBarDebugLog then
			XPBarDebugLog:Log(
				"BaseMixin",
				"Animation targetRatio:",
				targetRatio,
				"currentXP:",
				context.currentXP,
				"xpMax:",
				context.xpMax
			)
		end

		-- Get animation config from nested structure
		local fullConfig = self.__xpbar_config or {}
		local animConfig = fullConfig.animation or {}

		-- Build flat config object for AnimationManager
		local config = {
			enableAnimations = animConfig.enableAnimations,
			flashOnGain = animConfig.flashOnGain
		}

		-- Apply defaults only if not explicitly set
		if config.enableAnimations == nil then
			config.enableAnimations = true
		end
		if config.flashOnGain == nil then
			config.flashOnGain = true
		end

		if XPBarDebugLog then
			XPBarDebugLog:Log(
				"BaseMixin",
				"Animation config for",
				frameName,
				"enableAnimations:",
				config.enableAnimations,
				"flashOnGain:",
				config.flashOnGain,
				"from nested:",
				animConfig.flashOnGain
			)
		end

		-- Before starting animation, update overlays (if present) so any cached
		-- overlay data (used by styles like CircularBar) are up-to-date for
		-- the animation path. This mirrors the non-animated RenderBar flow
		-- and avoids stale visuals during animation.
		if self.UpdateRestedOverlay then
			self:UpdateRestedOverlay(context)
		end
		if self.UpdateQuestCompleteOverlay then
			self:UpdateQuestCompleteOverlay(context)
		end
		if self.UpdateQuestIncompleteOverlay then
			self:UpdateQuestIncompleteOverlay(context)
		end
		if self.UpdateExhaustionTick then
			self:UpdateExhaustionTick(context)
		end

		-- Start animation - AnimationManager will call AnimateBarPosition on each tick
		self:StartAnimation(targetRatio, context, config)

		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "Animation started for", frameName)
		end
	else
		-- Immediate render path
		if XPBarDebugLog then
			local reason = not context.shouldAnimate and "shouldAnimate=false" or "no StartAnimation method"
			XPBarDebugLog:Log("BaseMixin", "Immediate render for", frameName, "reason:", reason)
		end

		-- Call style-specific render method directly
		-- If an animation is currently running, we still allow immediate render
		-- when this is an explicit full update or broadcast (e.g., options change)
		local forceRender = false
		-- Prefer context.event as the event marker (we use event names when building contexts)
		if context and context.event then
			local ev = context.event
			if ev == "FULL_UPDATE" or ev == "BROADCAST_UPDATE" or ev == "MANUAL_REFRESH" then
				forceRender = true
			end
		end

		if self.animation and self.animation.isAnimating and forceRender then
			-- If the style provides a cleanup hook, call it to stop animations
			if self.CleanupAnimation then
				self:CleanupAnimation()
			end
			-- Ensure animation flag cleared
			if self.animation then
				self.animation.isAnimating = false
			end
		end

		if not (self.animation and self.animation.isAnimating) then
			self:RenderBar(context)
		else
			if XPBarDebugLog then
				XPBarDebugLog:Log(
					"BaseMixin",
					"Skipping immediate RenderBar for",
					frameName,
					"animation.isAnimating:",
					self.animation and self.animation.isAnimating or "nil"
				)
			end
		end

		if XPBarDebugLog then
			XPBarDebugLog:Log("BaseMixin", "RenderBar completed for", frameName)
		end
	end
end

-------------------------------------------------------------------
-- ACTION METHODS
-- Visual methods provided by XPBarTextMixin (injected in OnLoad)
-- Styles can override these methods - injection only fills missing methods
-------------------------------------------------------------------

-- UpdateTextVisibility, UpdateTexts, UpdateXPText, UpdatePercentText,
-- UpdateLevelText, UpdateRateText, UpdateSessionText, UpdateQuestSummaryText
-- → Provided by XPBarTextMixin

-------------------------------------------------------------------
-- ABSTRACT VISUAL METHODS (END) - now in mixins
-------------------------------------------------------------------

return BaseMixin
