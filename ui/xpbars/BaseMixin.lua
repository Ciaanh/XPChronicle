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

	-- Update value (expect a ratio between 0 and 1)
	if self.StatusBar then
		self.StatusBar:SetValue(ratio)
	end

	-- Update color based on rested state
	local colorKey = context.isRested and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Update rested overlay position/size/visibility
---@param context table Context with restedXP, currentXP, xpMax
---@param overlayName string|nil Overlay name (default: "RestedOverlay")
function BaseMixin:UpdateRestedOverlay(context, overlayName)
	overlayName = overlayName or "RestedOverlay"
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

	-- Calculate visibility and positioning
	local restedXP = context.restedXP or 0
	local currentXP = context.currentXP or 0
	local maxXP = context.xpMax or 1
	local completeQuestXP = context.completeQuestXP or 0
	local remainingXP = math.max(0, maxXP - currentXP)
	local isFullyRested = context.isFullyRested or false

	-- Calculate offset after completed quest XP (matching current implementation)
	local questOffset = math.min(completeQuestXP, remainingXP)
	local barWidth = self.__xpbar_config.style and self.__xpbar_config.style.width or 565
	local offsetPixels = math.floor((questOffset / maxXP) * barWidth)

	-- Calculate remaining space after offset
	local remainingAfterQuest = remainingXP - questOffset

	-- Only show if:
	-- 1. Has rested XP
	-- 2. Not fully rested
	-- 3. Rested XP + completed quest doesn't exceed remaining XP
	local restedXPClamped = math.min(restedXP, remainingAfterQuest)
	local visible = (restedXP > 0) and not isFullyRested and (restedXPClamped > 0)

	overlay:SetShown(visible)

	if visible then
		-- Calculate rested overlay width
		local restedRatio = restedXPClamped / maxXP
		local restedPixels = math.floor(restedRatio * barWidth)

		-- Ensure we don't exceed bar width
		if offsetPixels + restedPixels <= barWidth + 1 then
			overlay:ClearAllPoints()
			overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
			overlay:SetWidth(math.max(1, restedPixels))
		else
			-- Clamp to remaining space
			local remainingWidth = math.max(0, barWidth - offsetPixels)
			if remainingWidth > 1 then
				overlay:ClearAllPoints()
				overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
				overlay:SetWidth(remainingWidth)
			else
				overlay:Hide()
			end
		end
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
	local completeXP = context.completeQuestXP or 0
	local db = Addon.db or {}
	local showComplete =  db.showCompleteQuestOverlay ~= false

	local visible = false
	if showComplete and (completeXP and completeXP > 0) then
		local currentXP = context.currentXP or 0
		local maxXP = context.xpMax or 1
		local remainingXP = math.max(0, maxXP - currentXP)

		-- Default behavior: show complete quest overlay unless disabled in either per-frame config or global settings
		local questXPClamped = math.min(completeXP, remainingXP)
		local ratio = questXPClamped / maxXP

		-- Position after current XP
		local barWidth = self.StatusBar:GetWidth()

		local currentRatio = currentXP / maxXP
		local currentPixels = math.floor(currentRatio * barWidth)
		local questPixels = math.floor(ratio * barWidth)

		overlay:SetPoint("BOTTOMLEFT", currentPixels, 0)
		overlay:SetWidth(math.max(1, questPixels))
		visible = true
	else
		visible = false
	end

	overlay:SetShown(visible)
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

	-- Check config: per-frame override first, otherwise fall back to global Addon.db
	local config = self.__xpbar_config or {}
	local db = Addon and Addon.db or {}
	-- Default behavior: hide incomplete quest overlay unless enabled in either per-frame config or global settings
	local showIncomplete
	if config.showIncompleteQuestOverlay ~= nil then
		showIncomplete = config.showIncompleteQuestOverlay == true
	else
		showIncomplete = (db.showIncompleteQuestOverlay == true)
	end

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
		local restedOverlay = self.RestedOverlay or self.RestedLevel or self.ExhaustionLevelFillBar
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
-- ABSTRACT VISUAL METHODS (DEFAULT IMPLEMENTATIONS)
-- XML Contract: Styles must provide XML with required elements:
--   - StatusBar (required)
--   - XPText, PercentText, LevelText (required for text display)
--   - RestedOverlay, QuestOverlay*, ExhaustionTick, GainFlash (required for full feature parity)
-- Styles can disable specific overlays via config if not needed.
-- Override only for custom behavior (e.g., circular layout).
-------------------------------------------------------------------

--- Validate XML contract and initialize element state.
--- BaseMixin does NOT create UI elements - it validates the XML contract.
--- Styles must override if they need to create elements programmatically.
function BaseMixin:BuildVisuals()
	-- Require StatusBar (XML contract)
	if not self.StatusBar then
		if Addon and Addon.Logger then
			Addon.Logger:Error("BuildVisuals: StatusBar missing from XML for " .. (self:GetName() or "<unnamed>"))
		end
		return
	end

	-- Alias overlays that are expected as children of StatusBar.
	-- Do NOT create UI elements here; XML must provide them.
	self.RestedOverlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
	self.QuestOverlayComplete = self.QuestOverlayComplete or (self.StatusBar and self.StatusBar.QuestOverlayComplete)
	self.QuestOverlayIncomplete = self.QuestOverlayIncomplete or (self.StatusBar and self.StatusBar.QuestOverlayIncomplete)
	self.ExhaustionTick = self.ExhaustionTick or (self.StatusBar and self.StatusBar.ExhaustionTick)
	self.GainFlash = self.GainFlash or (self.StatusBar and self.StatusBar.GainFlash)

	-- Alias overlay frame text children (if style uses a TextContainer)
	if not self.XPText and self.TextContainer and self.TextContainer.XPText then
		self.XPText = self.TextContainer.XPText
	end
	if not self.PercentText and self.TextContainer and self.TextContainer.PercentText then
		self.PercentText = self.TextContainer.PercentText
	end
	if not self.LevelText and self.TextContainer and self.TextContainer.LevelText then
		self.LevelText = self.TextContainer.LevelText
	end

	-- Log missing optional overlays (development-time visibility)
	if Addon and Addon.Logger then
		if not self.RestedOverlay then
			Addon.Logger:Debug("BuildVisuals: RestedOverlay missing (expected as StatusBar child)")
		end
		if not self.QuestOverlayComplete then
			Addon.Logger:Debug("BuildVisuals: QuestOverlayComplete missing (expected as StatusBar child)")
		end
		if not self.QuestOverlayIncomplete then
			Addon.Logger:Debug("BuildVisuals: QuestOverlayIncomplete missing (expected as StatusBar child)")
		end
		if not self.ExhaustionTick then
			Addon.Logger:Debug("BuildVisuals: ExhaustionTick missing (expected as StatusBar child)")
		end
		if not self.GainFlash then
			Addon.Logger:Debug("BuildVisuals: GainFlash missing (expected as StatusBar child)")
		end
		-- Texts
		if not self.XPText then
			Addon.Logger:Debug("BuildVisuals: XPText missing (expected in TextContainer)")
		end
		if not self.PercentText then
			Addon.Logger:Debug("BuildVisuals: PercentText missing (expected in TextContainer)")
		end
		if not self.LevelText then
			Addon.Logger:Debug("BuildVisuals: LevelText missing (expected in TextContainer)")
		end
	end

	-- Apply text visibility from config
	self:UpdateTextVisibility()
end

--- Update text element visibility based on config
function BaseMixin:UpdateTextVisibility()
	local db = Addon.db or {}

	-- On-bar text elements
	if self.LevelText then
		self.LevelText:SetShown(db.showLevelText == true)
	end
	if self.XPText then
		self.XPText:SetShown(db.showXPText == true)
	end
	if self.PercentText then
		self.PercentText:SetShown(db.showPercentage == true)
	end

	-- Below-bar text elements (matches existing implementation)
	if self.RateText then
		-- Rate text (XP/hour + time to level): show if either showXPPerHourText or showTimeToLevelText is enabled
		local showRate = (db.showXPPerHourText == true) or (db.showTimeToLevelText == true)
		self.RateText:SetShown(showRate)
	end
	if self.SessionText then
		-- Session text: show if either showLevelTimeText or showSessionTimeText is enabled
		local showSession = (db.showLevelTimeText == true) or (db.showSessionTimeText == true)
		self.SessionText:SetShown(showSession)
	end
	if self.QuestSummaryText then
		-- Master toggle: show when not explicitly disabled (defaults to true)
		self.QuestSummaryText:SetShown(db.showQuestXP ~= false)
	end
end

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

--- Default implementation: update StatusBar values/colors.
-- Styles may override to provide custom bar rendering (e.g. circular).
---@param context table Immutable context (required)
function BaseMixin:UpdateBars(context)
	if not context then
		error("UpdateBars requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local ratio = (context.currentXP and maxv > 0) and (context.currentXP / maxv) or 0

	-- Prefer style-specific updater when provided. Some styles override
	-- UpdateCurrentXPBar to handle complex rendering (circular, animated, etc.).
	if self.UpdateCurrentXPBar then
		self:UpdateCurrentXPBar(context)
		return
	end

	if self.StatusBar then
		if self.StatusBar.SetValue then
			self.StatusBar:SetValue(ratio)
		end
	end
end

--- Default implementation: update text elements.
-- Styles may override to change formatting or visibility.
---@param context table Immutable context (required)
function BaseMixin:UpdateTexts(context)
	if not context then
		error("UpdateTexts requires an explicit immutable context")
	end

	-- Require the central formatter; fail explicitly if missing
	if not XPBarTextFormatter then
		error("UpdateTexts requires XPBarTextFormatter to be loaded")
	end

	-- XP on-bar: handled by dedicated methods
	self:UpdateXPText(context)
	self:UpdatePercentText(context)
	self:UpdateLevelText(context)

	-- Below-bar texts (delegated to existing methods which also use the formatter)
	self:UpdateRateText(context)
	self:UpdateSessionText(context)
	self:UpdateQuestSummaryText(context)
end

--- Update rate text (XP/hour + time to level)
function BaseMixin:UpdateRateText(context)
	if not self.RateText or not self.RateText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local db = Addon.db or {}
	local abbreviate = db.abbreviateNumbers ~= false
	local showXPPerHour = db.showXPPerHourText == true
	local showTimeToLevel = db.showTimeToLevelText == true

	-- Prefer context values when provided
	local xpPerHour = context and context.xpPerHour or nil
	local timeToLevel = context and context.timeToLevel or nil

	-- Fallback to session service
	if xpPerHour == nil and Addon.Session and Addon.Session.GetXPPerHour then
		xpPerHour = Addon.Session:GetXPPerHour()
	end
	if timeToLevel == nil and Addon.Session and Addon.Session.GetTimeToLevel then
		timeToLevel = Addon.Session:GetTimeToLevel()
	end

	-- Build text based on what's enabled
	local parts = {}

	if showXPPerHour then
		local ratePart = XPBarTextFormatter:GetXPRateText(xpPerHour or 0, abbreviate)
		if ratePart and ratePart ~= "" and ratePart ~= "Calculating..." then
			table.insert(parts, ratePart)
		end
	end

	if showTimeToLevel then
		if timeToLevel and timeToLevel > 0 then
			local timePart = XPBarTextFormatter:GetTimeToLevelText(timeToLevel)
			if timePart and timePart ~= "" and timePart ~= "N/A" then
				table.insert(parts, "Leveling in: " .. timePart)
			end
		end
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.RateText:SetText(text)
end

--- Dedicated on-bar text updaters
function BaseMixin:UpdateLevelText(context)
	if not self.LevelText or not self.LevelText:IsShown() then
		return
	end
	if not context then
		error("UpdateLevelText requires an explicit immutable context")
	end

	if XPBarTextFormatter then
		local level = context.level or UnitLevel("player")
		local levelText = XPBarTextFormatter:GetLevelText(level)
		self.LevelText:SetText(levelText)
	else
		error("UpdateLevelText requires XPBarTextFormatter to be loaded")
	end
end

function BaseMixin:UpdateXPText(context)
	if not self.XPText or not self.XPText:IsShown() then
		return
	end
	if not context then
		error("UpdateXPText requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local current = context.currentXP or 0

	if XPBarTextFormatter then
		local db = Addon.db or {}
		local abbreviate = db.abbreviateNumbers ~= false
		local showRemaining = db.showRemainingXP == true
		local text = XPBarTextFormatter:GetXPText(current, maxv, abbreviate, showRemaining)
		self.XPText:SetText(text)
	else
		error("UpdateXPText requires XPBarTextFormatter to be loaded")
	end
end

function BaseMixin:UpdatePercentText(context)
	if not self.PercentText or not self.PercentText:IsShown() then
		return
	end
	if not context then
		error("UpdatePercentText requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local current = context.currentXP or 0

	if XPBarTextFormatter then
		local db = Addon.db or {}
		local decimals = db.percentDecimals or 1
		local showQuestPercent = db.showQuestPercent == true

		local questXP = 0
		if showQuestPercent and Addon.XPBar then
			local totalXP, completeXP, incompleteXP = Addon.XPBar:GetQuestXP()
			local showComplete = db.showCompleteQuestOverlay ~= false
			local showIncomplete = db.showIncompleteQuestOverlay == true
			if showComplete then
				questXP = questXP + (completeXP or 0)
			end
			if showIncomplete then
				questXP = questXP + (incompleteXP or 0)
			end
		end

		local text = XPBarTextFormatter:GetPercentText(current, maxv, decimals, showQuestPercent, questXP)
		self.PercentText:SetText(text)
	else
		error("UpdatePercentText requires XPBarTextFormatter to be loaded")
	end
end

--- Update session text (session time + level time)
function BaseMixin:UpdateSessionText(context)
	if not self.SessionText or not self.SessionText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local Addon = XPBarEnhanced
	local db = Addon.db or {}
	local sessionSeconds = 0
	local levelSeconds = 0

	-- Check which times to show based on individual settings
	local showSessionTime = db.showSessionTimeText == true
	local showLevelTime = db.showLevelTimeText == true

	-- Prefer context values if present
	if context then
		if showSessionTime and context.sessionSeconds then
			sessionSeconds = context.sessionSeconds
		end
		if showLevelTime and context.levelSeconds then
			levelSeconds = context.levelSeconds
		end
	end

	-- Fallback to Session module when context doesn't provide values
	if (sessionSeconds == 0 or levelSeconds == 0) and Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			if showSessionTime and session.sessionStart and sessionSeconds == 0 then
				sessionSeconds = time() - session.sessionStart
			end
			if showLevelTime and levelSeconds == 0 then
				if session.realLevelTime and session.realLevelTime > 0 then
					levelSeconds = session.realLevelTime
					if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
						local elapsed = time() - session.lastTimePlayedRequest
						levelSeconds = levelSeconds + elapsed
					end
				end
			end
		end
	end

	-- Build text based on what's enabled
	local parts = {}

	if showSessionTime then
		if sessionSeconds > 0 then
			local sessionPart = XPBarTextFormatter:GetSessionTimeText(sessionSeconds, "Session")
			if sessionPart ~= "" then
				table.insert(parts, sessionPart)
			end
		end
	end

	if showLevelTime then
		if levelSeconds > 0 then
			local levelPart = XPBarTextFormatter:GetLevelTimeText(levelSeconds, "This Level")
			if levelPart ~= "" then
				table.insert(parts, levelPart)
			end
		end
	end

	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.SessionText:SetText(text)
end

--- Update quest summary text (quests + rested)
function BaseMixin:UpdateQuestSummaryText(context)
	if not self.QuestSummaryText or not self.QuestSummaryText:IsShown() then
		return
	end
	if not XPBarTextFormatter then
		return
	end
	if not context then
		error("UpdateQuestSummaryText requires an explicit immutable context")
	end

	local Addon = XPBarEnhanced
	local totalQuestXP = 0
	local completeQuestXP = 0
	local incompleteQuestXP = 0

	if context.totalQuestXP or context.completeQuestXP or context.incompleteQuestXP then
		totalQuestXP = context.totalQuestXP or 0
		completeQuestXP = context.completeQuestXP or 0
		incompleteQuestXP = context.incompleteQuestXP or 0
	elseif Addon.XPBar then
		totalQuestXP, completeQuestXP, incompleteQuestXP = Addon.XPBar:GetQuestXP()
	end

	local db = Addon.db or {}
	local decimals = db.percentDecimals or 1

	local maxXP = context.xpMax or 1
	local restedXP = context.restedXP or 0

	local text =
		XPBarTextFormatter:GetQuestSummaryText(completeQuestXP, incompleteQuestXP, totalQuestXP, maxXP, restedXP, decimals)
	self.QuestSummaryText:SetText(text)
end

--- Default overlay aggregation; calls specific overlay updaters.
-- Styles can override UpdateRestedOverlay, UpdateQuestCompleteOverlay, etc.
---@param context table|nil
function BaseMixin:UpdateOverlays(context)
	-- require explicit context; fallback builds minimal snapshot from current state
	local ctx = context
	if not ctx then
		if Addon and Addon.Logger then
			Addon.Logger:Warn("UpdateOverlays called without context; building fallback context")
		end
		ctx = {
			currentXP = (self:GetValue() or 0) * (self:GetMax() or 1),
			xpMax = self:GetMax() or 1,
			restedXP = 0,
			completeQuestXP = 0,
			incompleteQuestXP = 0,
			xpGained = 0,
			isRested = false
		}
	end

	-- Call overlay update hooks (they handle missing overlays internally)
	if self.UpdateRestedOverlay then
		self:UpdateRestedOverlay(ctx)
	end
	if self.UpdateQuestCompleteOverlay then
		self:UpdateQuestCompleteOverlay(ctx)
	end
	if self.UpdateQuestIncompleteOverlay then
		self:UpdateQuestIncompleteOverlay(ctx)
	end
	if self.UpdateExhaustionTick then
		self:UpdateExhaustionTick(ctx)
	end
end

--- Apply basic style configuration (size, basic bar texture/color)
---@param styleConfig table
function BaseMixin:ApplyStyle(styleConfig)
	if not styleConfig then
		return
	end

	-- Apply size to main frame and StatusBar if provided
	if styleConfig.width and styleConfig.height then
		self:SetSize(styleConfig.width, styleConfig.height)
		if self.StatusBar then
			-- Keep StatusBar anchored as in XML; only size the container frame if desired
			self.StatusBar:SetSize(styleConfig.width, styleConfig.height)
		end
	end


	-- Apply a statusbar texture if provided
	if styleConfig.barTexture and self.StatusBar and self.StatusBar.SetStatusBarTexture then
		self.StatusBar:SetStatusBarTexture(styleConfig.barTexture)
	end

	-- Other style params are left for the style mixin to handle (borders, corner radius, fonts)
	if Addon and Addon.Logger then
		Addon.Logger:Debug("ApplyStyle applied basic style for " .. (self:GetName() or "<unnamed>"))
	end
end

-------------------------------------------------------------------
-- ABSTRACT VISUAL METHODS (END)
-------------------------------------------------------------------

return BaseMixin
