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
	local db = Addon.db or {}

	-- On-bar text elements: prefer explicit context flags when provided, default to true if not set
	if self.LevelText then
		local show = (context and context.showLevelText ~= nil) and context.showLevelText or (db.showLevelText ~= false)
		self.LevelText:SetShown(show)
	end
	if self.XPText then
		local show = (context and context.showXPText ~= nil) and context.showXPText or (db.showXPText ~= false)
		self.XPText:SetShown(show)
	end
	if self.PercentText then
		local show = (context and context.showPercentage ~= nil) and context.showPercentage or (db.showPercentage ~= false)
		self.PercentText:SetShown(show)
	end

	-- Below-bar text elements: default to true if not explicitly set to false
	if self.RateText then
		local showXPPerHour = (context and context.showXPPerHourText ~= nil) and context.showXPPerHourText or (db.showXPPerHourText ~= false)
		local showTimeToLevel = (context and context.showTimeToLevelText ~= nil) and context.showTimeToLevelText or (db.showTimeToLevelText ~= false)
		local showRate = showXPPerHour or showTimeToLevel
		self.RateText:SetShown(showRate)
	end
	if self.SessionText then
		local showLevelTime = (context and context.showLevelTimeText ~= nil) and context.showLevelTimeText or (db.showLevelTimeText ~= false)
		local showSessionTime = (context and context.showSessionTimeText ~= nil) and context.showSessionTimeText or (db.showSessionTimeText ~= false)
		local showSession = showLevelTime or showSessionTime
		self.SessionText:SetShown(showSession)
	end
	if self.QuestSummaryText then
		local showQuest = (context and context.showQuestXP ~= nil) and context.showQuestXP or (db.showQuestXP ~= false)
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
		local db = Addon.db or {}
		local abbreviate = (context and context.abbreviateNumbers ~= nil) and context.abbreviateNumbers or (db.abbreviateNumbers ~= false)
		local showRemaining = (context and context.showRemainingXP ~= nil) and context.showRemainingXP or (db.showRemainingXP == true)
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
		local db = Addon.db or {}
		local decimals = (context and context.percentDecimals) or db.percentDecimals or 1
		local showQuestPercent = (context and context.showQuestXP ~= nil) and context.showQuestXP or (db.showQuestPercent == true)

		local questXP = 0
		if showQuestPercent and Addon.XPBar then
			local totalXP, completeXP, incompleteXP = Addon.XPBar:GetQuestXP()
			local showComplete = (context and context.showCompleteQuestOverlay ~= nil) and context.showCompleteQuestOverlay or (db.showCompleteQuestOverlay ~= false)
			local showIncomplete = (context and context.showIncompleteQuestOverlay ~= nil) and context.showIncompleteQuestOverlay or (db.showIncompleteQuestOverlay == true)
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

	local db = Addon.db or {}
	local abbreviate = db.abbreviateNumbers ~= false
	-- Prefer context-level toggles when present, default to true if not explicitly disabled
	local showXPPerHour = (context and context.showXPPerHourText ~= nil) and context.showXPPerHourText or (db.showXPPerHourText ~= false)
	local showTimeToLevel = (context and context.showTimeToLevelText ~= nil) and context.showTimeToLevelText or (db.showTimeToLevelText ~= false)

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
	local db = Addon.db or {}
	local sessionSeconds = 0
	local levelSeconds = 0

	-- Check which times to show based on individual settings; prefer context flags when present, default to true
	local showSessionTime = (context and context.showSessionTimeText ~= nil) and context.showSessionTimeText or (db.showSessionTimeText ~= false)
	local showLevelTime = (context and context.showLevelTimeText ~= nil) and context.showLevelTimeText or (db.showLevelTimeText ~= false)

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

	local db = Addon.db or {}
	local decimals = db.percentDecimals or 1

	local maxXP = context.xpMax or 1
	local restedXP = context.restedXP or 0

	local text =
		XPBarTextFormatter:GetQuestSummaryText(completeQuestXP, incompleteQuestXP, totalQuestXP, maxXP, restedXP, decimals)
	self.QuestSummaryText:SetText(text)
end

return XPBarTextMixin
