-- XP Bar Enhanced - Tooltip Mixin (v2)
-- Behavior mixin for tooltip management and GameTooltip integration

-------------------------------------------------------------------
-- GLOBAL TOOLTIP MIXIN
-------------------------------------------------------------------

---@class XPBarTooltipMixin
XPBarTooltipMixin = {}

local TooltipMixin = XPBarTooltipMixin

-------------------------------------------------------------------
-- TOOLTIP HANDLERS
-------------------------------------------------------------------

--- OnEnter - Show tooltip on mouse enter
function TooltipMixin:OnEnter()
	local config = self.__xpbar_config or {}
	local tooltipConfig = config.tooltip or {}
	
	if tooltipConfig.enabled == false then
		return
	end
	
	-- Get tooltip content
	local content = self:GetTooltipContent()
	if not content then
		return
	end
	
	-- Show GameTooltip
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	
	-- Add title
	if content.title then
		GameTooltip:SetText(content.title, 1, 1, 1)
	end
	
	-- Add lines
	if content.lines then
		for _, line in ipairs(content.lines) do
			if type(line) == "string" then
				GameTooltip:AddLine(line, nil, nil, nil, true) -- Wrap text
			elseif type(line) == "table" then
				GameTooltip:AddDoubleLine(line.left or "", line.right or "", 
					line.leftR or 1, line.leftG or 1, line.leftB or 1,
					line.rightR or 1, line.rightG or 1, line.rightB or 1)
			end
		end
	end
	
	GameTooltip:Show()
end

--- OnLeave - Hide tooltip on mouse leave
function TooltipMixin:OnLeave()
	GameTooltip:Hide()
end

-------------------------------------------------------------------
-- TOOLTIP CONTENT PROVIDER
-------------------------------------------------------------------

--- Get tooltip content (can be overridden by styles or config)
---@return table|nil content Tooltip content structure
function TooltipMixin:GetTooltipContent()
	local config = self.__xpbar_config or {}
	local tooltipConfig = config.tooltip or {}
	
	-- Use custom provider if specified
	if tooltipConfig.provider and type(tooltipConfig.provider) == "function" then
		return tooltipConfig.provider(self)
	end
	
	-- Default tooltip content
	return self:BuildDefaultTooltipContent()
end

--- Build default tooltip content
---@return table content Default tooltip structure
function TooltipMixin:BuildDefaultTooltipContent()
	local currentXP = UnitXP("player") or 0
	local maxXP = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isRested = IsResting()
	
	-- Calculate percentages
	local xpPercent = 0
	if maxXP > 0 then
		xpPercent = (currentXP / maxXP) * 100
	end
	
	local remainingXP = maxXP - currentXP
	
	-- Build content
	local content = {
		title = string.format("Level %d", level),
		lines = {}
	}
	
	-- Current XP
	table.insert(content.lines, {
		left = "Current XP:",
		right = string.format("%s / %s (%.1f%%)", 
			BreakUpLargeNumbers(currentXP), 
			BreakUpLargeNumbers(maxXP), 
			xpPercent),
		leftR = 0.7, leftG = 0.7, leftB = 0.7,
		rightR = 1, rightG = 1, rightB = 1
	})
	
	-- Remaining XP
	table.insert(content.lines, {
		left = "Remaining:",
		right = BreakUpLargeNumbers(remainingXP),
		leftR = 0.7, leftG = 0.7, leftB = 0.7,
		rightR = 1, rightG = 0.8, rightB = 0
	})
	
	-- Rested XP
	if restedXP > 0 then
		local restedPercent = 0
		if maxXP > 0 then
			restedPercent = (restedXP / maxXP) * 100
		end
		
		table.insert(content.lines, {
			left = "Rested XP:",
			right = string.format("%s (%.1f%%)", 
				BreakUpLargeNumbers(restedXP), 
				restedPercent),
			leftR = 0, leftG = 0.7, leftB = 1,
			rightR = 0, rightG = 0.8, rightB = 1
		})
	end
	
	-- Resting status
	if isRested then
		table.insert(content.lines, " ") -- Blank line
		table.insert(content.lines, {
			left = "Status:",
			right = "Resting",
			leftR = 0.7, leftG = 0.7, leftB = 0.7,
			rightR = 0, rightG = 1, rightB = 0
		})
	end
	
	-- Session stats (if available from ContextBuilder)
	if XPBarContextBuilder and XPBarContextBuilder._sessionXP and XPBarContextBuilder._sessionXP > 0 then
		local sessionXP = XPBarContextBuilder._sessionXP
		local sessionStart = XPBarContextBuilder._sessionStart or time()
		local sessionDuration = time() - sessionStart
		local xpPerHour = XPBarContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, 0, currentXP)
		
		if sessionDuration > 60 then -- Only show if session > 1 minute
			table.insert(content.lines, " ") -- Blank line
			table.insert(content.lines, {
				left = "Session XP:",
				right = BreakUpLargeNumbers(sessionXP),
				leftR = 0.7, leftG = 0.7, leftB = 0.7,
				rightR = 0.5, rightG = 1, rightB = 0.5
			})
			
			if xpPerHour > 0 then
				table.insert(content.lines, {
					left = "XP/Hour:",
					right = BreakUpLargeNumbers(xpPerHour),
					leftR = 0.7, leftG = 0.7, leftB = 0.7,
					rightR = 0.5, rightG = 1, rightB = 0.5
				})
				
				local timeToLevel = XPBarContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour)
				if timeToLevel > 0 then
					local hours = math.floor(timeToLevel / 3600)
					local minutes = math.floor((timeToLevel % 3600) / 60)
					table.insert(content.lines, {
						left = "Time to Level:",
						right = string.format("%dh %dm", hours, minutes),
						leftR = 0.7, leftG = 0.7, leftB = 0.7,
						rightR = 1, rightG = 0.8, rightB = 0
					})
				end
			end
		end
	end
	
	return content
end

return TooltipMixin
