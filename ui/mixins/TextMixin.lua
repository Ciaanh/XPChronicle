-- XPBarEnhanced - XPBarTextMixin
-- Responsibilities: text content formatting, text visibility/presentation

---@class XPBarTextMixin
XPBarTextMixin = {}

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- TEXT VISIBILITY METHODS
-------------------------------------------------------------------

--- Update text element visibility based on config
function XPBarTextMixin:UpdateTextVisibility(context)
	-- On-bar text elements: prefer explicit context flags when provided, default to true if not set
	if self.LevelText then
		local show = Addon.ConfigHelper.GetShowLevelText(context)
		self.LevelText:SetShown(show)
	end
	if self.XPText then
		local show = Addon.ConfigHelper.GetShowXPText(context)
		self.XPText:SetShown(show)
	end
	if self.PercentText then
		local show = Addon.ConfigHelper.GetShowPercentage(context)
		self.PercentText:SetShown(show)
	end

	-- Below-bar text elements: default to true if not explicitly set to false
	if self.RateText then
		local showXPPerHour = Addon.ConfigHelper.GetShowXPPerHourText(context)
		local showTimeToLevel = Addon.ConfigHelper.GetShowTimeToLevelText(context)
		local showRate = showXPPerHour or showTimeToLevel
		self.RateText:SetShown(showRate)
	end
	if self.SessionText then
		local showLevelTime = Addon.ConfigHelper.GetShowLevelTimeText(context)
		local showSessionTime = Addon.ConfigHelper.GetShowSessionTimeText(context)
		local showSession = showLevelTime or showSessionTime
		self.SessionText:SetShown(showSession)
	end
	if self.QuestSummaryText then
		local showQuest = Addon.ConfigHelper.GetShowQuestXP(context)
		self.QuestSummaryText:SetShown(showQuest)
	end
end

-------------------------------------------------------------------
-- TEXT CONTENT UPDATE METHODS
-------------------------------------------------------------------

--- Default implementation: update text elements.
-- Styles may override to change formatting or visibility.
---@param context table Immutable context (required)
function XPBarTextMixin:UpdateTexts(context)
	if not context then
		error("UpdateTexts requires an explicit immutable context")
	end

	-- Require the central formatter; fail explicitly if missing
	if not XPBarTextFormatter then
		error("UpdateTexts requires XPBarTextFormatter to be loaded")
	end

	-- Update visibility first (in case config changed)
	self:UpdateTextVisibility(context)

	-- XP on-bar: handled by dedicated methods
	self:UpdateXPText(context)
	self:UpdatePercentText(context)
	self:UpdateLevelText(context)

	-- Below-bar texts (delegated to existing methods which also use the formatter)
	self:UpdateRateText(context)
	self:UpdateSessionText(context)
	self:UpdateQuestSummaryText(context)
end

--- Dedicated on-bar text updaters
function XPBarTextMixin:UpdateLevelText(context)
	if not self.LevelText then
		return
	end
	if context and context.showLevelText == false then
		self.LevelText:Hide()
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

function XPBarTextMixin:UpdateXPText(context)
	if not self.XPText then
		return
	end
	if context and context.showXPText == false then
		self.XPText:Hide()
		return
	end
	if not context then
		error("UpdateXPText requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local current = context.currentXP or 0

	if XPBarTextFormatter then
		local abbreviate = Addon.ConfigHelper.GetAbbreviateNumbers(context)
		local showRemaining = Addon.ConfigHelper.GetShowRemainingXP(context)
		local text = XPBarTextFormatter:GetXPText(current, maxv, abbreviate, showRemaining)
		self.XPText:SetText(text)
	else
		error("UpdateXPText requires XPBarTextFormatter to be loaded")
	end
end

function XPBarTextMixin:UpdatePercentText(context)
	if not self.PercentText then
		return
	end
	if context and context.showPercentage == false then
		self.PercentText:Hide()
		return
	end
	if not context then
		error("UpdatePercentText requires an explicit immutable context")
	end

	local maxv = context.xpMax or 1
	local current = context.currentXP or 0

	if XPBarTextFormatter then
		local decimals = context.percentDecimals or 1
		local showQuestPercent = Addon.ConfigHelper.GetShowQuestPercent(context)

		local questXP = 0
		if showQuestPercent and Addon.XPBar then
			local totalXP, completeXP, incompleteXP = Addon.XPBar:GetQuestXP()
			local showComplete = Addon.ConfigHelper.GetShowCompleteQuestOverlay(context)
			local showIncomplete = Addon.ConfigHelper.GetShowIncompleteQuestOverlay(context)
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

--- Update rate text (XP/hour + time to level)
function XPBarTextMixin:UpdateRateText(context)
	if not self.RateText then
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local abbreviate = context and context.abbreviateNumbers ~= false or true
	-- Prefer context-level toggles when present, default to true if not explicitly disabled
	local showXPPerHour = Addon.ConfigHelper.GetShowXPPerHourText(context)
	local showTimeToLevel = Addon.ConfigHelper.GetShowTimeToLevelText(context)

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

	-- Set text content (may be empty initially)
	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.RateText:SetText(text)
	
	-- Don't hide the element here - visibility is controlled by UpdateTextVisibility
	-- This allows the element to show placeholder space even when empty
end

--- Update session text (session time + level time)
function XPBarTextMixin:UpdateSessionText(context)
	if not self.SessionText then
		return
	end
	if context and context.showSessionTimeText == false and context.showLevelTimeText == false then
		self.SessionText:Hide()
		return
	end
	if not XPBarTextFormatter then
		return
	end

	local Addon = XPBarEnhanced
	local sessionSeconds = 0
	local levelSeconds = 0

	-- Check which times to show based on individual settings; prefer context flags when present, default to true
	local showSessionTime = Addon.ConfigHelper.GetShowSessionTimeText(context)
	local showLevelTime = Addon.ConfigHelper.GetShowLevelTimeText(context)

	-- ALWAYS compute time fresh from Session service for real-time updates
	-- Do NOT use stale context values
	if Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			-- Session time: current time minus session start
			if showSessionTime and session.sessionStart then
				sessionSeconds = time() - session.sessionStart
			end
			-- Level time: realLevelTime from TIME_PLAYED_MSG plus elapsed time since last request
			if showLevelTime then
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

	-- Set text content (may be empty initially)
	local text = #parts > 0 and table.concat(parts, " - ") or ""
	self.SessionText:SetText(text)
	
	-- Don't hide the element here - visibility is controlled by UpdateTextVisibility
	-- This allows the element to show placeholder space even when empty
end

--- Update quest summary text (quests + rested)
function XPBarTextMixin:UpdateQuestSummaryText(context)
	if not self.QuestSummaryText then
		return
	end
	if context and context.showQuestXP == false then
		self.QuestSummaryText:Hide()
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

	local decimals = context.percentDecimals or 1

	local maxXP = context.xpMax or 1
	local restedXP = context.restedXP or 0

	local text =
		XPBarTextFormatter:GetQuestSummaryText(completeQuestXP, incompleteQuestXP, totalQuestXP, maxXP, restedXP, decimals)
	self.QuestSummaryText:SetText(text)
end

return XPBarTextMixin
