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

--- Set current value (0-1 ratio)
---@param value number Value ratio (0.0 to 1.0)
function BaseMixin:SetValue(value)
	self.__xpbar_value = value or 0
	if self.StatusBar then
		self.StatusBar:SetValue(value or 0)
	end
end

--- Get current value
---@return number value Current value ratio
function BaseMixin:GetValue()
	return self.__xpbar_value or 0
end

--- Set maximum value
---@param max number Maximum value
function BaseMixin:SetMax(max)
	self.__xpbar_max = max or 1
	if self.StatusBar then
		self.StatusBar:SetMinMaxValues(0, 1) -- StatusBar always uses 0-1 ratio
	end
end

--- Get maximum value
---@return number max Maximum value
function BaseMixin:GetMax()
	return self.__xpbar_max or 1
end

--- Set bar color (for StatusBar)
---@param r number Red component
---@param g number Green component
---@param b number Blue component
---@param a number|nil Alpha component (optional)
function BaseMixin:SetColor(r, g, b, a)
	if self.StatusBar then
		self.StatusBar:SetStatusBarColor(r or 1, g or 1, b or 1, a or 1)
	end
end

--- Get current bar color
---@return number r Red component
---@return number g Green component
---@return number b Blue component
---@return number a Alpha component
function BaseMixin:GetColor()
	if self.StatusBar then
		return self.StatusBar:GetStatusBarColor()
	end
	return 1, 1, 1, 1
end

--- Refresh bar state from game data
function BaseMixin:Refresh()
	local context = XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")
	self:TriggerXPChanged(context)
end

-------------------------------------------------------------------
-- LIFECYCLE METHODS
-------------------------------------------------------------------

--- OnLoad - Initialize bar state and register events
function BaseMixin:OnLoad()
	-- Initialize internal state
	self.__xpbar_value = 0
	self.__xpbar_max = 1
	self.__xpbar_config = self.__xpbar_config or {}
	
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
		
	elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or 
	       event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or
	       event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_WATCH_UPDATE" then
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
	self:UpdateCurrentXPBar(context)
	self:UpdateRestedOverlay(context)
	self:UpdateQuestCompleteOverlay(context)
	self:UpdateQuestIncompleteOverlay(context)
	self:UpdateExhaustionTick(context)
	
	-- Optional animations
	if self.PlayXPGainAnimation and context.xpGained > 0 then
		self:PlayXPGainAnimation(context)
	end
	if self.FlashXPGain and context.xpGained > 0 then
		self:FlashXPGain(context)
	end
	
	-- Update visuals if style provides method
	if self.UpdateVisuals then
		self:UpdateVisuals()
	end
end

--- Trigger level-up response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerLevelUp(context)
	self:UpdateCurrentXPBar(context)
	self:UpdateMaxXP(context)
	self:UpdateRestedOverlay(context)
	
	-- Optional animations
	if self.PlayLevelUpAnimation then
		self:PlayLevelUpAnimation(context)
	end
	if self.FlashLevelUp then
		self:FlashLevelUp(context)
	end
	
	-- Update visuals
	if self.UpdateVisuals then
		self:UpdateVisuals()
	end
end

--- Trigger rested state change response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerRestedChanged(context)
	self:UpdateRestedOverlay(context)
	self:UpdateExhaustionTick(context)
	
	-- Update visuals
	if self.UpdateVisuals then
		self:UpdateVisuals()
	end
end

--- Trigger quest overlay update response
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerQuestChanged(context)
	self:UpdateQuestCompleteOverlay(context)
	self:UpdateQuestIncompleteOverlay(context)
	
	-- Update visuals
	if self.UpdateVisuals then
		self:UpdateVisuals()
	end
end

-------------------------------------------------------------------
-- ACTION METHODS (CAN be overridden by styles)
-------------------------------------------------------------------

--- Update current XP bar from context
---@param context table Context with currentXP, xpMax
---@param barName string|nil StatusBar name (default: "StatusBar")
function BaseMixin:UpdateCurrentXPBar(context, barName)
	barName = barName or "StatusBar"
	local bar = self[barName]
	
	if not bar then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateCurrentXPBar: bar not found - " .. barName)
		end
		return
	end
	
	-- Calculate ratio (0-1)
	local ratio = 0
	if context.xpMax and context.xpMax > 0 then
		ratio = (context.currentXP or 0) / context.xpMax
	end
	
	-- Update value
	self:SetValue(ratio)
	self:SetMax(context.xpMax or 1)
	
	-- Update color based on rested state
	local colorKey = context.isRested and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Update max XP from context
---@param context table Context with xpMax
function BaseMixin:UpdateMaxXP(context)
	self:SetMax(context.xpMax or 1)
end

--- Update rested overlay position/size/visibility
---@param context table Context with restedXP, currentXP, xpMax
---@param overlayName string|nil Overlay name (default: "RestedLevel")
function BaseMixin:UpdateRestedOverlay(context, overlayName)
	overlayName = overlayName or "RestedLevel"
	local overlay = self[overlayName]
	
	if not overlay then
		if Addon.Logger then
			Addon.Logger:Warn("UpdateRestedOverlay: overlay not found - " .. overlayName)
		end
		return
	end
	
	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.Rested)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
	
	-- Calculate visibility
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	local isFullyRested = context.isFullyRested or false
	
	local visible = (restedXP > 0) and (restedXP < remainingXP) and not isFullyRested
	overlay:SetShown(visible)
	
	if visible then
		-- Calculate position and size (linear bar positioning)
		local restedXPClamped = math.min(restedXP, remainingXP)
		local currentRatio = currentXP / maxXP
		local restedRatio = restedXPClamped / maxXP
		
		-- Assume 565px width (standard from legacy bar)
		local barWidth = 565
		local currentPixels = math.floor(currentRatio * barWidth)
		local restedPixels = math.floor(restedRatio * barWidth)
		
		overlay:SetPoint("BOTTOMLEFT", currentPixels, 0)
		overlay:SetWidth(math.max(1, restedPixels))
	end
end

--- Update completed quest overlay
---@param context table Context with completeQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayComplete")
function BaseMixin:UpdateQuestCompleteOverlay(context, overlayName)
	overlayName = overlayName or "QuestOverlayComplete"
	local overlay = self[overlayName]
	
	if not overlay then
		-- Quest overlays are optional, don't warn
		return
	end
	
	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.QuestComplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
	
	-- Calculate visibility
	local questXP = context.completeQuestXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	
	-- Check config (default: show complete quests)
	local config = self.__xpbar_config or {}
	local showComplete = config.showCompleteQuestOverlay ~= false
	
	local questXPClamped = math.min(questXP, remainingXP)
	local ratio = questXPClamped / maxXP
	local visible = showComplete and questXP > 0 and ratio >= 0.01
	
	overlay:SetShown(visible)
	
	if visible then
		-- Position after current XP
		local barWidth = 565
		local currentRatio = currentXP / maxXP
		local currentPixels = math.floor(currentRatio * barWidth)
		local questPixels = math.floor(ratio * barWidth)
		
		overlay:SetPoint("BOTTOMLEFT", currentPixels, 0)
		overlay:SetWidth(math.max(1, questPixels))
	end
end

--- Update incomplete quest overlay
---@param context table Context with incompleteQuestXP
---@param overlayName string|nil Overlay name (default: "QuestOverlayIncomplete")
function BaseMixin:UpdateQuestIncompleteOverlay(context, overlayName)
	overlayName = overlayName or "QuestOverlayIncomplete"
	local overlay = self[overlayName]
	
	if not overlay then
		-- Quest overlays are optional, don't warn
		return
	end
	
	-- Get user-defined color
	local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
	overlay:SetVertexColor(color.r, color.g, color.b, color.a)
	
	-- Calculate visibility
	local completeQuestXP = context.completeQuestXP or 0
	local incompleteQuestXP = context.incompleteQuestXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	
	-- Check config (default: hide incomplete quests)
	local config = self.__xpbar_config or {}
	local showIncomplete = config.showIncompleteQuestOverlay == true
	
	-- Account for complete quest overlay
	remainingXP = math.max(0, remainingXP - completeQuestXP)
	local questXPClamped = math.min(incompleteQuestXP, remainingXP)
	local ratio = questXPClamped / maxXP
	local visible = showIncomplete and incompleteQuestXP > 0 and ratio >= 0.01
	
	overlay:SetShown(visible)
	
	if visible then
		-- Position after current XP + complete quest overlay
		local barWidth = 565
		local currentRatio = currentXP / maxXP
		local completeRatio = completeQuestXP / maxXP
		local startPixels = math.floor((currentRatio + completeRatio) * barWidth)
		local questPixels = math.floor(ratio * barWidth)
		
		overlay:SetPoint("BOTTOMLEFT", startPixels, 0)
		overlay:SetWidth(math.max(1, questPixels))
	end
end

--- Update exhaustion tick marker position/visibility
---@param context table Context with restedXP
---@param tickName string|nil Tick name (default: "ExhaustionTick")
function BaseMixin:UpdateExhaustionTick(context, tickName)
	tickName = tickName or "ExhaustionTick"
	local tick = self[tickName]
	
	if not tick then
		-- Exhaustion tick is optional, don't warn
		return
	end
	
	-- Calculate visibility
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local remainingXP = math.max(0, maxXP - currentXP)
	
	local restedXPClamped = math.min(restedXP, remainingXP)
	local restedRatio = restedXPClamped / maxXP
	
	-- Show tick when rested ratio is between 1% and 99%
	local visible = restedXP > 0 and restedRatio >= 0.01 and restedRatio <= 0.99
	tick:SetShown(visible)
	
	if visible then
		-- Position at the end of rested overlay
		local restedOverlay = self.RestedLevel or self.ExhaustionLevelFillBar
		if restedOverlay then
			tick:SetPoint("CENTER", restedOverlay, "RIGHT", 0, 0)
		end
	end
end

--- Update flash overlay (optional)
---@param context table Context object
---@param flashName string|nil Flash overlay name (default: "GainFlash")
function BaseMixin:UpdateFlashOverlay(context, flashName)
	flashName = flashName or "GainFlash"
	local flash = self[flashName]
	
	if not flash then
		-- Flash overlay is optional, don't warn
		return
	end
	
	-- Flash update is typically handled by animation mixin
	-- This method exists for style override if needed
end

-------------------------------------------------------------------
-- ABSTRACT VISUAL METHODS (MUST be provided by style)
-------------------------------------------------------------------

-- BuildVisuals() - Create textures/fontstrings/frames
-- UpdateVisuals() - Update textures and text based on state
-- ApplyStyle(styleConfig) - Optional style parameters

return BaseMixin
