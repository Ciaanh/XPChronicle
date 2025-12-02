-- XP Bar Enhanced - Tooltip Mixin ()
-- Behavior mixin for tooltip management and GameTooltip integration
-- Restored feature parity with classic XPBarTooltip: config checks, anchors, sections, colors, refresh/owner tracking

-------------------------------------------------------------------
-- GLOBAL TOOLTIP MIXIN
-------------------------------------------------------------------

---@class XPBarTooltipMixin
XPBarTooltipMixin = {}

local TooltipMixin = XPBarTooltipMixin
local XPBarColors = _G.XPBarColors

-- track the current tooltip owner so Refresh can re-open it when needed
TooltipMixin.currentTooltipOwner = nil

-------------------------------------------------------------------
-- UTIL / DEPENDENCY HELPERS
-------------------------------------------------------------------

local Addon = XPBarEnhanced
local L = Addon and Addon.L or {}

local function GetGlobalDB()
	if Addon and Addon.db and Addon.db.profile then
		return Addon.db.profile
	end
	return {}
end

function TooltipMixin:FormatNumber(n)
	if not n then
		return "0"
	end
	if Addon and Addon.TextFormatter and Addon.TextFormatter.FormatNumber then
		return Addon.TextFormatter:FormatNumber(tonumber(n) or 0, false)
	end
	return BreakUpLargeNumbers(tonumber(n) or 0)
end

-- Add a compact formatter for k/M style abbreviations
function TooltipMixin:FormatAbbrevNumber(n)
	if not n then
		return "0"
	end
	if Addon and Addon.TextFormatter and Addon.TextFormatter.AbbreviateNumber then
		return Addon.TextFormatter:AbbreviateNumber(tonumber(n) or 0)
	end
	local num = tonumber(n) or 0
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fk", num / 1000)
	else
		return tostring(num)
	end
end

function TooltipMixin:FormatTime(seconds)
	-- Prefer canonical formatter when available for consistent output
	if not seconds or seconds <= 0 then
		return L["TT_CALCULATING"]
	end
	local hours = math.floor(seconds / 3600)
	if hours >= 99 then
		return L["TT_OVER_99_HOURS"]
	end
	if Addon and Addon.TextFormatter and Addon.TextFormatter.FormatTime then
		-- Use short format (true) to keep tooltip compact
		return Addon.TextFormatter:FormatTime(seconds, true)
	else
		local minutes = math.floor((seconds % 3600) / 60)
		if hours > 0 then
			return string.format("%dh %dm", hours, minutes)
		else
			return string.format("%dm", minutes)
		end
	end
end

-- attempt to get user tooltip column colors; left = muted label, right = primary xp color
local function GetTooltipColors()
	local leftR, leftG, leftB = 0.7, 0.7, 0.7
	local rightR, rightG, rightB = 1, 1, 1
	if XPBarColors and Color and XPBarColors.GetUserColor then
		local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.XpBar) or nil
		if c then
			rightR, rightG, rightB = c.r or rightR, c.g or rightG, c.b or rightB
		end
	end
	return leftR, leftG, leftB, rightR, rightG, rightB
end

-------------------------------------------------------------------
-- ANCHOR / OWNER / LIFECYCLE
-------------------------------------------------------------------

-- Determine a reasonable anchor similar to the previous implementation
function TooltipMixin:GetBestAnchor()
	-- If this bar has a frame center, use top/bottom anchor decision
	local owner = self
	local parent = owner.GetCenter and owner or UIParent
	local x, y = parent:GetCenter()
	if not x or not y then
		return "ANCHOR_TOP"
	end

	local screenWidth = UIParent:GetRight() or GetScreenWidth()
	local screenHeight = UIParent:GetTop() or GetScreenHeight()

	-- if bar is in top half, anchor below; else above
	if y > (screenHeight / 2) then
		return "ANCHOR_BOTTOM"
	else
		return "ANCHOR_TOP"
	end
end

function TooltipMixin:Show() -- public helper that mirrors old API
	TooltipMixin.currentTooltipOwner = self
	self:OnEnter()
end

function TooltipMixin:Hide() -- public helper
	if TooltipMixin.currentTooltipOwner == self then
		TooltipMixin.currentTooltipOwner = nil
	end
	GameTooltip:Hide()
end

-------------------------------------------------------------------
-- SECTION BUILDERS (compatibility with classic behavior)
-------------------------------------------------------------------

-- Add XP / percent lines to content.lines
function TooltipMixin:AddXPSection(content, context, cfg)
	local currentXP = tonumber(context.currentXP) or 0
	local maxXP = tonumber(context.xpMax) or 1
	local xpPercent = 0
	if maxXP > 0 then
		xpPercent = (currentXP / maxXP) * 100
	end

	-- left uses muted label color; right should reflect the bar's primary color (or rested color when appropriate)
	local leftR, leftG, leftB = 0.7, 0.7, 0.7
	local rightR, rightG, rightB = 1, 1, 1
	if XPBarColors and Color and XPBarColors.GetUserColor then
		local hasRestedXP = context and (context.hasRestedXP or (context.restedXP and context.restedXP > 0))
		local key = hasRestedXP and Color.XpBarRested or Color.XpBar
		local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(key) or nil
		if c then
			rightR, rightG, rightB = c.r or rightR, c.g or rightG, c.b or rightB
		end
	end

	table.insert(
		content.lines,
		{
			left = (L["TT_CURRENT"]) .. ":",
			right = string.format(
				L["TT_CURRENT_FMT"],
				self:FormatNumber(currentXP),
				self:FormatNumber(maxXP),
				xpPercent
			),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			rightR = rightR,
			rightG = rightG,
			rightB = rightB
		}
	)

	local remainingXP = maxXP - currentXP
	table.insert(
		content.lines,
		{
			left = (L["TT_REMAINING"]) .. ":",
			right = self:FormatNumber(remainingXP),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			rightR = 1,
			rightG = 0.8,
			rightB = 0
		}
	)
end

-- Rested
function TooltipMixin:AddRestedSection(content, context, cfg)
	local restedXP = tonumber(context.restedXP) or 0
	if restedXP <= 0 then
		return
	end

	local maxXP = tonumber(context.xpMax) or 1
	local restedPercent = 0
	if maxXP > 0 then
		restedPercent = (restedXP / maxXP) * 100
	end

	-- Rested color should reflect the rested overlay color
	local leftR, leftG, leftB = 0.7, 0.7, 0.7
	local rightR, rightG, rightB = 0, 0.8, 1
	if XPBarColors and Color and XPBarColors.GetUserColor then
		local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.Rested) or nil
		if c then
			rightR, rightG, rightB = c.r or rightR, c.g or rightG, c.b or rightB
		end
	end

	table.insert(
		content.lines,
		{
			left = (L["TT_RESTED"]) .. ":",
			right = string.format(L["TT_RESTED_FMT"], self:FormatNumber(restedXP), restedPercent),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			rightR = rightR,
			rightG = rightG,
			rightB = rightB
		}
	)
end

-- Quest section: totals for complete/incomplete (context-only, no counts, no per-quest listing)
function TooltipMixin:AddQuestSection(content, context, cfg)
	-- If global or bar config disables quest tooltip, skip
	local global = GetGlobalDB()
	if (cfg and cfg.showQuestXP == false) or (global.showQuestXP == false) then
		return
	end

	-- Use only immutable context properties required by the spec
	local totalComplete = tonumber(context.completeQuestXP) or 0
	local totalIncomplete = tonumber(context.incompleteQuestXP) or 0

	-- If there is no quest data to show, skip
	if totalComplete == 0 and totalIncomplete == 0 then
		return
	end

	-- header / spacing
	table.insert(content.lines, " ")

	local leftR, leftG, leftB = 0.7, 0.7, 0.7
	local xpMax = tonumber(context.xpMax) or 0

	-- Determine user preference for abbreviated numbers using the context-first helper
	local useAbbrev =
		(Addon and Addon.ConfigHelper and Addon.ConfigHelper.GetAbbreviateNumbers and
		Addon.ConfigHelper.GetAbbreviateNumbers(context)) or
		false

	-- Prepare best available abbreviation formatter from workspace helpers
	local abbrevFn
	if Addon and Addon.Utils and Addon.Utils.ShortNumber then
		abbrevFn = Addon.Utils.ShortNumber
	elseif Addon and Addon.TextFormatter and Addon.TextFormatter.AbbreviateNumber then
		abbrevFn = function(v)
			return Addon.TextFormatter:AbbreviateNumber(v)
		end
	else
		abbrevFn = function(v)
			return BreakUpLargeNumbers(tonumber(v) or 0)
		end
	end

	if totalComplete and totalComplete > 0 then
		local cR, cG, cB = 0, 1, 0
		if XPBarColors and Color and XPBarColors.GetUserColor then
			local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestComplete) or nil
			if c then
				cR, cG, cB = c.r or cR, c.g or cG, c.b or cB
			end
		end

		local amountText
		if useAbbrev then
			amountText = abbrevFn(totalComplete)
		else
			amountText = self:FormatNumber(totalComplete)
		end

		if xpMax and xpMax > 0 then
			local pct = (totalComplete / xpMax) * 100
			amountText = string.format("%s (%.1f%%)", amountText, pct)
		end

		table.insert(
			content.lines,
			{
				left = L["TT_QUEST_XP_COMPLETE"],
				right = amountText,
				leftR = leftR,
				leftG = leftG,
				leftB = leftB,
				rightR = cR,
				rightG = cG,
				rightB = cB
			}
		)
	end

	if totalIncomplete and totalIncomplete > 0 then
		local cR, cG, cB = 1, 0.8, 0
		if XPBarColors and Color and XPBarColors.GetUserColor then
			local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestIncomplete) or nil
			if c then
				cR, cG, cB = c.r or cR, c.g or cG, c.b or cB
			end
		end

		local amountText
		if useAbbrev then
			amountText = abbrevFn(totalIncomplete)
		else
			amountText = self:FormatNumber(totalIncomplete)
		end

		if xpMax and xpMax > 0 then
			local pct = (totalIncomplete / xpMax) * 100
			amountText = string.format("%s (%.1f%%)", amountText, pct)
		end

		table.insert(
			content.lines,
			{
				left = L["TT_QUEST_XP_INCOMPLETE"],
				right = amountText,
				leftR = leftR,
				leftG = leftG,
				leftB = leftB,
				rightR = cR,
				rightG = cG,
				rightB = cB
			}
		)
	end
end

-- Session section: multiple rules/thresholds like classic implementation
function TooltipMixin:AddSessionSection(content, context, cfg)
	local sessionXP = context.sessionXP or 0
	local sessionStart = context.sessionStart or nil

	-- check explicit per-bar or global enable/disable
	local global = GetGlobalDB()
	if (cfg and cfg.showSession == false) or (global.showSession == false) then
		return
	end

	if not sessionXP or sessionXP <= 0 then
		return
	end

	local sessionDuration = nil
	if sessionStart then
		sessionDuration = time() - sessionStart
	end
	-- classic thresholds: at least 30s and at least 100 xp to show (preserve parity)
	local minDuration = (cfg and cfg.sessionMinDuration) or global.sessionMinDuration or 30
	local minXP = (cfg and cfg.sessionMinXP) or global.sessionMinXP or 100

	-- if duration nil (unknown) allow showing; otherwise require minDuration
	if sessionDuration and sessionDuration < minDuration then
		return
	end
	if sessionXP < minXP then
		return
	end

	-- header
	table.insert(content.lines, " ")

	local leftR, leftG, leftB, rightR, rightG, rightB = GetTooltipColors()

	table.insert(
		content.lines,
		{
			left = (L["TT_SESSION_XP"] or L["TT_SESSION"]) .. ":",
			right = self:FormatNumber(sessionXP),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			rightR = 0.5,
			rightG = 1,
			rightB = 0.5
		}
	)

	-- XP/hour: calculate either from context or via helper, fallback safe
	local xpPerHour = context.xpPerHour
	if (not xpPerHour) and sessionStart and sessionXP then
		if XPBarContextBuilder and type(XPBarContextBuilder.CalculateXPPerHour) == "function" then
			-- Call directly; rely on existence checks rather than pcall
			local val = XPBarContextBuilder:CalculateXPPerHour(sessionStart, sessionXP, 0, context.currentXP or 0)
			if tonumber(val) then
				xpPerHour = tonumber(val)
			end
		else
			-- best-effort naive calc: xp/sec * 3600
			if sessionDuration and sessionDuration > 0 then
				xpPerHour = (sessionXP / math.max(1, sessionDuration)) * 3600
			end
		end
	end

	if xpPerHour and xpPerHour > 0 then
		table.insert(
			content.lines,
			{
				left = (L["TT_XP_PER_HOUR"]) .. ":",
				right = self:FormatNumber(math.floor(xpPerHour)),
				leftR = leftR,
				leftG = leftG,
				leftB = leftB,
				rightR = 0.5,
				rightG = 1,
				rightB = 0.5
			}
		)
		-- time-to-level if available
		local timeToLevel = context.timeToLevel
		if (not timeToLevel) and xpPerHour and xpPerHour > 0 then
			local currentXP = tonumber(context.currentXP) or 0
			local maxXP = tonumber(context.xpMax) or 1
			local remaining = maxXP - currentXP
			if remaining > 0 then
				timeToLevel = math.floor((remaining / xpPerHour) * 3600)
			end
		end
		if timeToLevel and timeToLevel > 0 then
			table.insert(
				content.lines,
				{
					left = (L["TT_TIME_TO_LEVEL"]) .. ":",
					right = self:FormatTime(timeToLevel),
					leftR = leftR,
					leftG = leftG,
					leftB = leftB,
					rightR = 1,
					rightG = 0.8,
					rightB = 0
				}
			)
		end
	end
end

-- final hints section (classic displayed help/hints)
function TooltipMixin:AddHintSection(content, context, cfg)
	local global = GetGlobalDB()
	if (cfg and cfg.showHints == false) or (global.showHints == false) then
		return
	end

	-- Generate hint text based on bar capabilities
	local hintText = self:GetHintText()

	if hintText and hintText ~= "" then
		table.insert(content.lines, " ")
		table.insert(content.lines, hintText)
	end
end

--- Get hint text for  bars
-- Returns appropriate hint based on position mode and interaction config
function TooltipMixin:GetHintText()
	local L = XPBarEnhanced and XPBarEnhanced.L or {}

	-- Check position mode
	local isDraggable = false
	if self.GetPositionMode then
		local positionMode = self:GetPositionMode()
		isDraggable = (positionMode == "DRAGGABLE")
	end

	-- Build hint parts
	local hints = {}

	-- Drag hint (if draggable)
	if isDraggable then
		table.insert(hints, L["TT_HINT_DRAG"])
	end

	-- Alt+Click to open options
	table.insert(hints, L["TT_HINT_ALT_OPTIONS"])

	-- Ctrl+Click to toggle stats
	table.insert(hints, L["TT_HINT_CTRL_STATS"])

	-- Join with line breaks
	return table.concat(hints, "\n")
end

-------------------------------------------------------------------
-- TOOLTIP HANDLERS (OnEnter/OnLeave)
-------------------------------------------------------------------

--- OnEnter - Show tooltip on mouse enter
function TooltipMixin:OnEnter()
	-- Safety check: only show tooltip if mouse is actually over the frame
	-- (prevents spurious OnEnter calls during frame initialization)
	if not self:IsMouseOver() then
		return
	end

	local config = self.__xpbar_config or {}
	local tooltipConfig = config.tooltip or {}
	local global = GetGlobalDB()

	-- respect per-bar override then global toggle
	if
		tooltipConfig.enabled == false or global.showTooltip == false or
			(global.showTooltip == nil and tooltipConfig.enabled == false)
	 then
		return
	end

	-- Build the context using centralized builder
	local context = XPBarContextBuilder:BuildContext("TOOLTIP")

	-- If there's an explicit per-bar toggle to disable tooltip content, return
	if tooltipConfig.enabled == false then
		return
	end

	-- Build content using unified API that preserves section parity
	local content = {title = string.format(L["TT_LEVEL_FMT"], tonumber(context.level) or 1), lines = {}}

	-- XP / remaining
	self:AddXPSection(content, context, tooltipConfig)

	-- Rested
	self:AddRestedSection(content, context, tooltipConfig)

	-- Resting status
	if context.isResting then
		table.insert(content.lines, " ")
		table.insert(
			content.lines,
			{
				left = (L["TT_STATUS"]) .. ":",
				right = L["TT_RESTING"],
				leftR = 0.7,
				leftG = 0.7,
				leftB = 0.7,
				rightR = 0,
				rightG = 1,
				rightB = 0
			}
		)
	end

	-- Quest section
	self:AddQuestSection(content, context, tooltipConfig)

	-- Session stats
	self:AddSessionSection(content, context, tooltipConfig)

	-- Hints
	self:AddHintSection(content, context, tooltipConfig)

	-- If no content lines and user opted not to show an empty tooltip, return
	if not content.lines or #content.lines == 0 then
		return
	end

	-- Set owner using best anchor (classic used smart anchoring)
	GameTooltip:SetOwner(self, self:GetBestAnchor())

	-- Title
	if content.title then
		GameTooltip:SetText(content.title, 1, 1, 1)
	end

	-- Add lines (respect tables for double lines)
	for _, line in ipairs(content.lines) do
		if type(line) == "string" then
			GameTooltip:AddLine(line, nil, nil, nil, true)
		elseif type(line) == "table" then
			GameTooltip:AddDoubleLine(
				line.left or "",
				line.right or "",
				line.leftR or 1,
				line.leftG or 1,
				line.leftB or 1,
				line.rightR or 1,
				line.rightG or 1,
				line.rightB or 1
			)
		end
	end

	GameTooltip:Show()
	TooltipMixin.currentTooltipOwner = self
end

--- OnLeave - Hide tooltip on mouse leave
function TooltipMixin:OnLeave()
	-- hide only if owner matches (graceful)
	if TooltipMixin.currentTooltipOwner == self then
		TooltipMixin.currentTooltipOwner = nil
	end
	GameTooltip:Hide()
end

-------------------------------------------------------------------
-- TOOLTIP CONTENT PROVIDER (centralized context preference)
-------------------------------------------------------------------

--- Get tooltip content (can be overridden by styles or config)
---@return table|nil content Tooltip content structure
function TooltipMixin:GetTooltipContent()
	-- Try to obtain a centralized context first (call directly if available)
	local context = XPBarContextBuilder:BuildContext("TOOLTIP")
	if context and type(context) == "table" then
		-- build content like classic did (use helper builders)
		local content = {title = string.format(L["TT_LEVEL_FMT"], tonumber(context.level) or 1), lines = {}}
		self:AddXPSection(content, context, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddRestedSection(content, context, self.__xpbar_config and self.__xpbar_config.tooltip)
		if context.isResting then
			table.insert(content.lines, " ")
			table.insert(
				content.lines,
				{
					left = (L["TT_STATUS"]) .. ":",
					right = L["TT_RESTING"],
					leftR = 0.7,
					leftG = 0.7,
					leftB = 0.7,
					rightR = 0,
					rightG = 1,
					rightB = 0
				}
			)
		end
		self:AddQuestSection(content, context, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddSessionSection(content, context, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddHintSection(content, context, self.__xpbar_config and self.__xpbar_config.tooltip)
		return content
	end

	-- fallback: nil to let OnEnter attempt its own fallback
	return nil
end

return TooltipMixin
