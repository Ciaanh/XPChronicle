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
function BaseMixin:FullUpdate()
	-- Prevent re-entrant calls
	if self._isUpdating then
		return
	end
	self._isUpdating = true

	-- Build fresh context and update all visuals
	local context = XPBarContextBuilder.BuildXPChangeContext("FULL_UPDATE")
	
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

	-- Initialize behavior mixins (if present)
	if self.InitializeAnimationState then
		self:InitializeAnimationState()
	end
	if self.InitializePosition then
		self:InitializePosition()
	end

	-- Register common events
	self:RegisterCommonEvents()

	-- Call BuildVisuals if style provides it
	if self.BuildVisuals then
		self:BuildVisuals()
	else
		if Addon.Logger then
			Addon.Logger:Warn("XPBarMixinBase_v2:OnLoad - BuildVisuals() not implemented by style")
		end
	end

	-- Apply style config if provided
	if self.ApplyStyle and self.__xpbar_config.style then
		self:ApplyStyle(self.__xpbar_config.style)
	end

	-- Initial refresh
	self:Refresh()
end

--- OnShow - Called when bar becomes visible
function BaseMixin:OnShow()
	-- Refresh state when shown
	self:Refresh()
end

--- OnHide - Called when bar becomes hidden
function BaseMixin:OnHide()
	-- Cleanup if needed (behavior mixins may override)
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
	if self.PlayXPGainAnimation and context and context.xpGained > 0 then
		self:PlayXPGainAnimation(context)
	end
	if self.FlashXPGain and context and context.xpGained > 0 then
		self:FlashXPGain(context)
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
	if self.PlayLevelUpAnimation then
		self:PlayLevelUpAnimation(context)
	end
	if self.FlashLevelUp then
		self:FlashLevelUp(context)
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
