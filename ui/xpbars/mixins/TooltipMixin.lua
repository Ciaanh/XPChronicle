-- XP Bar Enhanced - Tooltip Mixin (v2)
-- Behavior mixin for tooltip management and GameTooltip integration
-- Restored feature parity with legacy XPBarTooltip: config checks, anchors, sections, colors, refresh/owner tracking

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
	return BreakUpLargeNumbers(tonumber(n) or 0)
end

function TooltipMixin:FormatTime(seconds)
	-- keep existing behavior
	if not seconds or seconds <= 0 then
		return L["TT_CALCULATING"] or "Calculating..."
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours >= 99 then
		return L["TT_OVER_99_HOURS"] or ">99h"
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
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

function TooltipMixin:RefreshTooltip() -- re-shows tooltip for owner when configuration or colors change
	local owner = TooltipMixin.currentTooltipOwner
	if owner and owner == self then
		-- re-open for same owner
		self:Hide()
		-- small deferred reopen if available, but simple immediate call
		self:OnEnter()
	end
end

-------------------------------------------------------------------
-- SECTION BUILDERS (compatibility with legacy behavior)
-------------------------------------------------------------------

-- Add XP / percent lines to content.lines
function TooltipMixin:AddXPSection(content, ctx, cfg)
	local currentXP = tonumber(ctx.currentXP) or 0
	local maxXP = tonumber(ctx.xpMax) or 1
	local xpPercent = 0
	if maxXP > 0 then
		xpPercent = (currentXP / maxXP) * 100
	end

	-- left uses muted label color; right should reflect the bar's primary color (or rested color when appropriate)
	local leftR, leftG, leftB = 0.7, 0.7, 0.7
	local rightR, rightG, rightB = 1, 1, 1
	if XPBarColors and Color and XPBarColors.GetUserColor then
		local hasRestedXP = ctx and (ctx.hasRestedXP or (ctx.restedXP and ctx.restedXP > 0))
		local key = hasRestedXP and Color.XpBarRested or Color.XpBar
		local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(key) or nil
		if c then
			rightR, rightG, rightB = c.r or rightR, c.g or rightG, c.b or rightB
		end
	end

	table.insert(
		content.lines,
		{
			left = L["TT_CURRENT"] or "Current:",
			right = string.format(
				L["TT_CURRENT_FMT"] or "%s / %s (%.1f%%)",
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
			left = L["TT_REMAINING"] or "Remaining:",
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
function TooltipMixin:AddRestedSection(content, ctx, cfg)
	local restedXP = tonumber(ctx.restedXP) or 0
	if restedXP <= 0 then
		return
	end

	local maxXP = tonumber(ctx.xpMax) or 1
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
			left = L["TT_RESTED"] or "Rested:",
			right = string.format(L["TT_RESTED_FMT"] or "%s (%.1f%%)", self:FormatNumber(restedXP), restedPercent),
			leftR = leftR,
			leftG = leftG,
			leftB = leftB,
			rightR = rightR,
			rightG = rightG,
			rightB = rightB
		}
	)
end

-- Quest section: totals for complete/incomplete and optionally per-quest lines
function TooltipMixin:AddQuestSection(content, ctx, cfg)
	-- If global or bar config disables quest tooltip, skip
	local global = GetGlobalDB()
	if (cfg and cfg.showQuestXP == false) or (global.showQuestXP == false) then
		return
	end

	-- attempt to use QuestXPService if available; otherwise use context fields
	local totalComplete = ctx.questCompleteXP or 0
	local totalIncomplete = ctx.questIncompleteXP or 0
	local completeCount = ctx.questCompleteCount or 0
	local incompleteCount = ctx.questIncompleteCount or 0
	local perQuest = ctx.quests -- optional list of {title, xp, isComplete}

	if QuestXPService and type(QuestXPService.GetRecentQuests) == "function" and (not perQuest) then
		-- try to fetch a current snapshot if service exists (call directly when available)
		local q = QuestXPService:GetRecentQuests()
		if q then
			perQuest = q
		end
	end

	-- If there is no quest data to show, skip
	if totalComplete == 0 and totalIncomplete == 0 and (not perQuest or #perQuest == 0) then
		return
	end

	-- header / spacing
	table.insert(content.lines, " ")

	local leftR, leftG, leftB = 0.7, 0.7, 0.7

	if totalComplete and totalComplete > 0 then
		local cR, cG, cB = 0, 1, 0
		if XPBarColors and Color and XPBarColors.GetUserColor then
			local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestComplete) or nil
			if c then
				cR, cG, cB = c.r or cR, c.g or cG, c.b or cB
			end
		end
		table.insert(
			content.lines,
			{
				left = L["TT_QUESTS_COMPLETE"] or "Quest XP (Complete):",
				right = self:FormatNumber(totalComplete) .. (completeCount and (" (" .. tostring(completeCount) .. ")") or ""),
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
		table.insert(
			content.lines,
			{
				left = L["TT_QUESTS_INCOMPLETE"] or "Quest XP (Incomplete):",
				right = self:FormatNumber(totalIncomplete) .. (incompleteCount and (" (" .. tostring(incompleteCount) .. ")") or ""),
				leftR = leftR,
				leftG = leftG,
				leftB = leftB,
				rightR = cR,
				rightG = cG,
				rightB = cB
			}
		)
	end

	-- optionally list per-quest breakdown if requested by config
	local showPerQuest = (cfg and cfg.showQuestList) or GetGlobalDB().showQuestList
	if perQuest and showPerQuest then
		for _, q in ipairs(perQuest) do
			if q and (q.xp and q.title) then
				local rightText = self:FormatNumber(q.xp)
				if cfg and cfg.showQuestPercent then
					local maxXP = ctx.xpMax or 1
					if maxXP > 0 then
						local pct = (q.xp / maxXP) * 100
						rightText = string.format("%s (%.1f%%)", rightText, pct)
					end
				end
				local leftColorR, leftColorG, leftColorB = 0.7, 0.7, 0.7
				local rightColorR, rightColorG, rightColorB = 1, 1, 1
				if q.isComplete then
					if XPBarColors and Color and XPBarColors.GetUserColor then
						local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestComplete) or nil
						if c then
							rightColorR, rightColorG, rightColorB = c.r or rightColorR, c.g or rightColorG, c.b or rightColorB
						end
					else
						rightColorR, rightColorG, rightColorB = 0, 1, 0
					end
				else
					if XPBarColors and Color and XPBarColors.GetUserColor then
						local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestIncomplete) or nil
						if c then
							rightColorR, rightColorG, rightColorB = c.r or rightColorR, c.g or rightColorG, c.b or rightColorB
						end
					else
						rightColorR, rightColorG, rightColorB = 1, 1, 0
					end
				end
				table.insert(
					content.lines,
					{
						left = q.title,
						right = rightText,
						leftR = leftColorR,
						leftG = leftColorG,
						leftB = leftColorB,
						rightR = rightColorR,
						rightG = rightColorG,
						rightB = rightColorB
					}
				)
			end
		end
	end
end

-- Session section: multiple rules/thresholds like legacy implementation
function TooltipMixin:AddSessionSection(content, ctx, cfg)
	local sessionXP = ctx.sessionXP or 0
	local sessionStart = ctx.sessionStart or nil

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
	-- legacy thresholds: at least 30s and at least 100 xp to show (preserve parity)
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
			left = L["TT_SESSION_XP"] or "Session XP:",
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
	local xpPerHour = ctx.xpPerHour
	if (not xpPerHour) and sessionStart and sessionXP then
		if XPBarContextBuilder and type(XPBarContextBuilder.CalculateXPPerHour) == "function" then
			-- Call directly; rely on existence checks rather than pcall
			local val = XPBarContextBuilder:CalculateXPPerHour(sessionStart, sessionXP, 0, ctx.currentXP or 0)
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
				left = L["TT_XP_PER_HOUR"] or "XP/Hour:",
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
		local timeToLevel = ctx.timeToLevel
		if (not timeToLevel) and xpPerHour and xpPerHour > 0 then
			local currentXP = tonumber(ctx.currentXP) or 0
			local maxXP = tonumber(ctx.xpMax) or 1
			local remaining = maxXP - currentXP
			if remaining > 0 then
				timeToLevel = math.floor((remaining / xpPerHour) * 3600)
			end
		end
		if timeToLevel and timeToLevel > 0 then
			table.insert(
				content.lines,
				{
					left = L["TT_TIME_TO_LEVEL"] or "Time to Level:",
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

-- final hints section (legacy displayed help/hints)
function TooltipMixin:AddHintSection(content, ctx, cfg)
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

--- Get hint text for V2 bars
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
		table.insert(hints, L["TT_HINT_DRAG"] or "Shift+Drag to move")
	end

	-- Alt+Click to open options
	table.insert(hints, L["TT_HINT_ALT_OPTIONS"] or "Alt+Click for options")

	-- Ctrl+Click to toggle stats
	table.insert(hints, L["TT_HINT_CTRL_STATS"] or "Ctrl+Click to toggle stats")

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

	-- Build the context (try centralized builder, fall back to services/context on self)
	local ctx = nil
	-- Prefer a centralized context builder exposed via self:GetContext (call directly if available)
	if type(self.GetContext) == "function" then
		ctx = self:GetContext()
	else
		-- gracefully fallback: try to build simple context from self fields or services
		ctx = ctx or {}
		ctx.currentXP = (self and self.currentXP) or ctx.currentXP or 0
		ctx.xpMax = (self and self.xpMax) or ctx.xpMax or 1
		ctx.level = (self and self.level) or ctx.level or 1
		-- attempt to populate session/quest from services if available
		if SessionService and type(SessionService.GetSession) == "function" then
			local s = SessionService:GetSession()
			if s then
				ctx.sessionXP = ctx.sessionXP or s.gainedXP
				ctx.sessionStart = ctx.sessionStart or s.startTime
			end
		end
		if QuestXPService and type(QuestXPService.GetQuestTotals) == "function" then
			local q = QuestXPService:GetQuestTotals()
			if q then
				ctx.questCompleteXP = ctx.questCompleteXP or q.completeXP
				ctx.questIncompleteXP = ctx.questIncompleteXP or q.incompleteXP
				ctx.questCompleteCount = ctx.questCompleteCount or q.completeCount
				ctx.questIncompleteCount = ctx.questIncompleteCount or q.incompleteCount
				ctx.quests = ctx.quests or q.quests
			end
		end
	end

	-- If there's an explicit per-bar toggle to disable tooltip content, return
	if tooltipConfig.enabled == false then
		return
	end

	-- Build content using unified API that preserves section parity
	local content = {title = string.format(L["TT_LEVEL_FMT"] or "Level %d", tonumber(ctx.level) or 1), lines = {}}

	-- XP / remaining
	self:AddXPSection(content, ctx, tooltipConfig)

	-- Rested
	self:AddRestedSection(content, ctx, tooltipConfig)

	-- Resting status
	if ctx.isResting then
		table.insert(content.lines, " ")
		table.insert(
			content.lines,
			{
				left = L["TT_STATUS"] or "Status:",
				right = L["TT_RESTING"] or "Resting",
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
	self:AddQuestSection(content, ctx, tooltipConfig)

	-- Session stats
	self:AddSessionSection(content, ctx, tooltipConfig)

	-- Hints
	self:AddHintSection(content, ctx, tooltipConfig)

	-- If no content lines and user opted not to show an empty tooltip, return
	if not content.lines or #content.lines == 0 then
		return
	end

	-- Set owner using best anchor (legacy used smart anchoring)
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
	local ctx = nil
	if type(self.GetContext) == "function" then
		ctx = self:GetContext()
	end
	if ctx and type(ctx) == "table" then
		-- build content like legacy did (use helper builders)
		local content = {title = string.format(L["TT_LEVEL_FMT"] or "Level %d", tonumber(c.level) or 1), lines = {}}
		self:AddXPSection(content, c, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddRestedSection(content, c, self.__xpbar_config and self.__xpbar_config.tooltip)
		if c.isResting then
			table.insert(content.lines, " ")
			table.insert(
				content.lines,
				{
					left = L["TT_STATUS"] or "Status:",
					right = L["TT_RESTING"] or "Resting",
					leftR = 0.7,
					leftG = 0.7,
					leftB = 0.7,
					rightR = 0,
					rightG = 1,
					rightB = 0
				}
			)
		end
		self:AddQuestSection(content, c, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddSessionSection(content, c, self.__xpbar_config and self.__xpbar_config.tooltip)
		self:AddHintSection(content, c, self.__xpbar_config and self.__xpbar_config.tooltip)
		return content
	end

	-- fallback: nil to let OnEnter attempt its own fallback
	return nil
end

--- Retrieve a centralized context for this bar using XPBarContextBuilder when available.
--- Returns a table with fields used for tooltip construction, or nil.
function TooltipMixin:GetContext()
	-- Prefer centralized context builder if available
	if XPBarContextBuilder and XPBarContextBuilder.BuildTooltipContext then
		return XPBarContextBuilder:BuildTooltipContext()
	end

	-- if builder missing, do not error here — return nil to allow fallbacks
	return nil
end

return TooltipMixin
