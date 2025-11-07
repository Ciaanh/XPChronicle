-- XP Bar Enhanced - Base Mixin v2
-- Core functionality: event orchestration, Trigger/Action methods, overlay actions
-- Uses ContextBuilder for immutable contexts (no Session dependency)

-------------------------------------------------------------------
-- GLOBAL BASE MIXIN
-------------------------------------------------------------------

---@class XPBarMixinBase_v2
XPBarMixinBase_v2 = {}

local BaseMixin = XPBarMixinBase_v2

-- Reference to addon for Logger access
local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- PUBLIC API SURFACE
-------------------------------------------------------------------

--- Refresh bar state from game data
function BaseMixin:Refresh()
	local context = XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")
	self:TriggerXPChanged(context)
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
		context = XPBarContextBuilder.BuildXPChangeContext("FULL_UPDATE")
	end
	
	-- Update all visual elements (bars, overlays, text)
	if self.UpdateVisuals then
		self:UpdateVisuals(context)
	end
	
	-- Update text visibility in case options changed
	if self.UpdateTextVisibility then
		self:UpdateTextVisibility(context)
	end

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

	-- Register as observer for broadcast updates (color changes, etc.)
	-- This ensures multiple V2 bars receive updates simultaneously
	local Addon = XPBarEnhanced
	if Addon.XPBar and Addon.XPBar.RegisterObserver then
		-- Use frame name or generate unique ID
		local observerId = self:GetName() or ("v2_bar_" .. tostring(self))
		self.__observer_id = Addon.XPBar:RegisterObserver(self, observerId)
	end

	-- Initial refresh
	self:Refresh()
end

--- OnShow - Called when bar becomes visible
function BaseMixin:OnShow()
	-- Refresh state when shown
	self:Refresh()
	
	-- Register as observer if not already registered
	-- This handles cases where bar is created but not via OnLoad
	if not self.__observer_id then
		local Addon = XPBarEnhanced
		if Addon.XPBar and Addon.XPBar.RegisterObserver then
			local observerId = self:GetName() or ("v2_bar_" .. tostring(self))
			self.__observer_id = Addon.XPBar:RegisterObserver(self, observerId)
		end
	end
	
	-- Start periodic text refresh ticker (updates session/level time and rate text)
	if not self._textRefreshTicker then
		self._textRefreshTicker = C_Timer.NewTicker(2.5, function()
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
		end)
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

--- Event dispatcher - calls ContextBuilder and Trigger methods
---@param event string Event name
---@param ... any Event arguments
function BaseMixin:OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUI = ...
		local context = XPBarContextBuilder.BuildXPChangeContext(event, ...)
		self:TriggerXPChanged(context)
	elseif event == "PLAYER_XP_UPDATE" then
		local context = XPBarContextBuilder.BuildXPChangeContext(event, ...)
		self:TriggerXPChanged(context)
	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = ...
		local context = XPBarContextBuilder.BuildLevelUpContext(event, newLevel)
		self:TriggerLevelUp(context)
	elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		local context = XPBarContextBuilder.BuildRestedContext(event, ...)
		self:TriggerRestedChanged(context)
	elseif
		event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or
			event == "UNIT_QUEST_LOG_CHANGED" or
			event == "QUEST_WATCH_UPDATE"
	 then
		local context = XPBarContextBuilder.BuildQuestContext(event, ...)
		self:TriggerQuestChanged(context)
	elseif event == "TIME_PLAYED_MSG" then
		-- Store time played data for session calculations
		local totalTime, levelTime = ...
	-- ContextBuilder will use this indirectly through UnitXP calculations
	end
end

-------------------------------------------------------------------
-- TRIGGER METHODS (Orchestrate Actions - NOT overridable)
-------------------------------------------------------------------

--- Trigger XP change response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerXPChanged(context)
	-- explicit context required for all downstream updates
	if self.UpdateCurrentXPBar then
		self:UpdateCurrentXPBar(context)
	end
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
	if self.UpdateVisuals then
		self:UpdateVisuals(context)
	end
end

--- Trigger level-up response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerLevelUp(context)
	if self.UpdateCurrentXPBar then
		self:UpdateCurrentXPBar(context)
	end
	if self.UpdateRestedOverlay then
		self:UpdateRestedOverlay(context)
	end
	if self.UpdateVisuals then
		self:UpdateVisuals(context)
	end
end

--- Trigger rested state change response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerRestedChanged(context)
	if self.UpdateRestedOverlay then
		self:UpdateRestedOverlay(context)
	end
	if self.UpdateExhaustionTick then
		self:UpdateExhaustionTick(context)
	end
	if self.UpdateVisuals then
		self:UpdateVisuals(context)
	end
end

--- Trigger quest overlay update response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerQuestChanged(context)
	if self.UpdateQuestCompleteOverlay then
		self:UpdateQuestCompleteOverlay(context)
	end
	if self.UpdateQuestIncompleteOverlay then
		self:UpdateQuestIncompleteOverlay(context)
	end
	if self.UpdateVisuals then
		self:UpdateVisuals(context)
	end
end

-------------------------------------------------------------------
-- ACTION METHODS
-- Now provided by XPBarVisualsMixin and XPBarTextMixin (injected in OnLoad)
-- Styles can still override these methods - injection only fills missing methods
-------------------------------------------------------------------

-- UpdateCurrentXPBar, UpdateRestedOverlay, UpdateQuestCompleteOverlay,
-- UpdateQuestIncompleteOverlay, UpdateExhaustionTick, UpdateFlashOverlay,
-- UpdateOverlays, UpdateBars, BuildVisuals, ApplyStyle
-- → Provided by XPBarVisualsMixin

-- UpdateTextVisibility, UpdateTexts, UpdateXPText, UpdatePercentText,
-- UpdateLevelText, UpdateRateText, UpdateSessionText, UpdateQuestSummaryText
-- → Provided by XPBarTextMixin

-------------------------------------------------------------------
-- VISUAL ORCHESTRATION (delegates to mixin methods)
-------------------------------------------------------------------

--- Update visuals (delegates to granular overridable methods).
-- Styles may override UpdateBars, UpdateTexts, or UpdateOverlays individually.
---@param context table|nil Immutable context (recommended)
function BaseMixin:UpdateVisuals(context)
	-- require explicit context
	if not context then
		error("UpdateVisuals requires an explicit immutable context")
	end

	-- Update bar values and appearance
	if self.UpdateBars then
		self:UpdateBars(context)
	end

	-- Update overlay visuals
	if self.UpdateOverlays then
		self:UpdateOverlays(context)
	end

	-- Update text elements
	if self.UpdateTexts then
		self:UpdateTexts(context)
	end
end

-------------------------------------------------------------------
-- ABSTRACT VISUAL METHODS (END) - now in mixins
-------------------------------------------------------------------

return BaseMixin
