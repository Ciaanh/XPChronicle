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
local EventNames = Addon.EventNames

-------------------------------------------------------------------
-- PUBLIC API SURFACE
-------------------------------------------------------------------

--- Refresh bar state from game data ( unified pattern)
function BaseMixin:Refresh()
	-- Check if ContextBuilder exists
	if not XPBarContextBuilder then
		error("XPBarContextBuilder not loaded")
	end

	local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
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

	-- Update text visibility in case options changed
	self:UpdateTextVisibility(context)

	self._isUpdating = nil
end

-------------------------------------------------------------------
-- LIFECYCLE METHODS
-------------------------------------------------------------------

--- OnLoad - Initialize bar state and register events
function BaseMixin:OnLoad()
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

	-- Register for broadcast updates via EventBus (preferred) or via shim fallback
	-- Uses a named subscription id so we can unregister later if needed
	local observerId = self:GetName() or ("_bar_" .. tostring(self))
	if Addon.EventBus and Addon.EventBus.Register then
		-- Handler invoked by EventBus subscriptions
		local handler = function(ctx)
			if self and self.FullUpdate then
				pcall(
					function()
						self:FullUpdate(ctx)
					end
				)
			end
		end

		-- Register the two EventBus topics now (NOT inside handler)
		Addon.EventBus:Register(EventNames.XPBAR_BROADCAST_UPDATE, observerId, handler)

		-- Subscribe to CONFIG_UPDATED (EventNames.CONFIG_UPDATED) to react to fine-grained key changes
		local configId = observerId .. ":config"
		local configHandler = function(payload)
			-- Basic default: full update on config change
			if self and self.FullUpdate then
				pcall(
					function()
						local ctx =
							XPBarContextBuilder and XPBarContextBuilder.BuildContext and XPBarContextBuilder.BuildContext("BROADCAST_UPDATE") or
							nil
						self:FullUpdate(ctx)
					end
				)
			end
		end
		Addon.EventBus:Register(EventNames.CONFIG_UPDATED, configId, configHandler)

		self.__observer_id = observerId
		self.__config_observer_id = configId
	end

	-- Initial refresh

	if not self.Refresh then
		error("Refresh method missing")
	end

	self:Refresh()
end

--- OnShow - Called when bar becomes visible
function BaseMixin:OnShow()
	-- Refresh state when shown
	self:Refresh()

	-- Register subscription if not already registered
	-- This handles cases where bar is created but not via OnLoad
	if not self.__observer_id then
		local observerId = self:GetName() or ("_bar_" .. tostring(self))
		if Addon.EventBus and Addon.EventBus.Register then
			local handler = function(ctx)
				if self and self.FullUpdate then
					pcall(
						function()
							self:FullUpdate(ctx)
						end
					)
				end
			end
			Addon.EventBus:Register(EventNames.XPBAR_BROADCAST_UPDATE, observerId, handler)
			local configId = observerId .. ":config"
			local configHandler = function(payload)
				if self and self.FullUpdate then
					pcall(
						function()
							local ctx =
								XPBarContextBuilder and XPBarContextBuilder.BuildContext and
								XPBarContextBuilder.BuildContext("BROADCAST_UPDATE") or
								nil
							self:FullUpdate(ctx)
						end
					)
				end
			end
			Addon.EventBus:Register(EventNames.CONFIG_UPDATED, configId, configHandler)
			self.__observer_id = observerId
			self.__config_observer_id = configId
		end
	end

	-- Start periodic text refresh ticker (updates session/level time and rate text)
	if not self._textRefreshTicker then
		self._textRefreshTicker =
			C_Timer.NewTicker(
			2.5,
			function()
				if self and self:IsShown() then
					local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
					-- Update session text with fresh time values (computes from Session service)
					-- Don't pass context so it always fetches fresh time
					if self.UpdateSessionText then
						self:UpdateSessionText(context)
					end
					-- Update rate text (XP/hour and time to level) with fresh calculations
					if self.UpdateRateText then
						self:UpdateRateText(context)
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
	-- Unregister any EventBus subscriptions created in OnLoad/OnShow
	if self.__observer_id and Addon.EventBus and Addon.EventBus.Unregister then
		Addon.EventBus:Unregister(EventNames.XPBAR_BROADCAST_UPDATE, self.__observer_id)
		self.__observer_id = nil
	end
	if self.__config_observer_id and Addon.EventBus and Addon.EventBus.Unregister then
		Addon.EventBus:Unregister(EventNames.CONFIG_UPDATED, self.__config_observer_id)
		self.__config_observer_id = nil
	end
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

	-- PLAYER_LEVEL_UP is now optional - we detect level-up via xpMax change in PLAYER_XP_UPDATE
	-- But we still process it for any level-up specific UI (flash effect, etc.)

	local context = XPBarContextBuilder.BuildContext(event, ...)

	if context then
		self:TriggerBarRefresh(context)
	end
end

-------------------------------------------------------------------
-- TRIGGER METHODS (Orchestrate Actions - NOT overridable)
-------------------------------------------------------------------

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

function BaseMixin:CalculateTargetRatio(context)
	if not context then
		error("BaseMixin:CalculateTargetRatio called with nil context")
	end

	local targetRatio = 0
	if context and context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end
	return targetRatio
end

--- Single entry point for all bar updates (NEW unified pattern)
--- Orchestrates animation vs immediate render based on context
---@param context table Immutable context from ContextBuilder with event flags
function BaseMixin:TriggerBarRefresh(context)
	-- Explicit context required
	if not context then
		error("TriggerBarRefresh requires an explicit immutable context")
	end

	-- Validate required methods
	if not self.RenderBar then
		error("Style must implement RenderBar(context) method")
	end

	local ev = context and context.event

	-- determine if this update should force render
	local forceRender = false
	if ev == "FULL_UPDATE" or ev == "BROADCAST_UPDATE" or ev == "MANUAL_REFRESH" or ev == "OPTIONS_CHANGED" then
		forceRender = true
	end

	-- Short-circuit: ignore pure no-change PLAYER_XP_UPDATE (avoid snapping / redundant renders)
	if ev == "PLAYER_XP_UPDATE" and not forceRender and not context.hasGainedXP and not context.hasLeveledUp then
		-- Update only overlays and text; do not call RenderBar or affect animation state
		if context.restedChanged and self.UpdateRestedBar then
			self:UpdateRestedBar(context)
		end
		if context.questsChanged and self.UpdateQuestCompleteBar then
			self:UpdateQuestCompleteBar(context)
		end
		if context.questsChanged and self.UpdateQuestIncompleteBar then
			self:UpdateQuestIncompleteBar(context)
		end
		if context.restedChanged and self.UpdateExhaustionTick then
			self:UpdateExhaustionTick(context)
		end

		if self.UpdateTextVisibility then
			self:UpdateTextVisibility(context)
		end
		if self.UpdateSessionText then
			self:UpdateSessionText(context)
		end
		if self.UpdateRateText then
			self:UpdateRateText(context)
		end
		if self.UpdateXPText then
			self:UpdateXPText(context)
		end
		if self.UpdatePercentText then
			self:UpdatePercentText(context)
		end
		if self.UpdateLevelText then
			self:UpdateLevelText(context)
		end

		return
	end

	-- ORCHESTRATION: Decide between animation vs immediate render
	if context.shouldAnimate and self.StartAnimation then
		-- Animated update path
		local targetRatio = self:CalculateTargetRatio(context)

		-- Build config from context (populated via BuildDBConfig in ContextBuilder)
		-- Context is the source of truth for all settings
		local config = {
			enableAnimations = context.enableAnimations,
			flashOnGain = context.flashOnGain,
			twoPhaseOnLevelUp = context.twoPhaseOnLevelUp
		}

		-- Apply defaults only if not explicitly set in context
		if config.enableAnimations == nil then
			config.enableAnimations = true
		end
		if config.flashOnGain == nil then
			config.flashOnGain = true
		end
		if config.twoPhaseOnLevelUp == nil then
			config.twoPhaseOnLevelUp = true
		end

		-- Before starting animation, update overlays (if present)
		-- This mirrors the non-animated RenderBar flow
		-- and avoids stale visuals during animation.
		if self.UpdateRestedBar then
			self:UpdateRestedBar(context)
		end
		if self.UpdateQuestCompleteBar then
			self:UpdateQuestCompleteBar(context)
		end
		if self.UpdateQuestIncompleteBar then
			self:UpdateQuestIncompleteBar(context)
		end
		if self.UpdateExhaustionTick then
			self:UpdateExhaustionTick(context)
		end

		-- Start animation - AnimationManager will call AnimateBarPosition on each tick
		self:StartAnimation(targetRatio, context, config)
	else
		-- Immediate render path
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
