-- XP Bar Enhanced - Tooltip module (restored and improved from refs)

local Addon = XPBarEnhanced
local L = Addon.L or {}

local Tooltip = {}

-- Track current owner for tooltip refresh
local currentTooltipOwner = nil

-- Helpers
local function fmtNumber(n)
    if not n then return "0" end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

local function fmtTime(seconds)
    if not seconds or seconds <= 0 then return L["TT_CALCULATING"] or "Calculating..." end
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

local function xpPerHour(gainedXP, sessionSeconds)
    if not sessionSeconds or sessionSeconds <= 0 then return 0 end
    return math.floor((gainedXP / sessionSeconds) * 3600)
end

local function timeToLevel(remainingXP, xpPerHourVal)
    if not xpPerHourVal or xpPerHourVal <= 0 then return 0 end
    return math.floor((remainingXP / xpPerHourVal) * 3600)
end

-- Sections
function Tooltip:AddXPSection(tt)
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    local remaining = maxXP - currentXP
    GameTooltip_SetTitle(tt, L["TT_EXPERIENCE"] or "Experience")
    tt:AddDoubleLine(L["TT_CURRENT"] or "Current:", string.format("%s / %s", fmtNumber(currentXP), fmtNumber(maxXP)), 0.7,0.7,0.7, 1,1,1)
    tt:AddDoubleLine(L["TT_REMAINING"] or "Remaining:", fmtNumber(remaining), 0.7,0.7,0.7, 1,1,1)
end

function Tooltip:AddRestedSection(tt)
    local rested = GetXPExhaustion() or 0
    if rested <= 0 then return end
    tt:AddLine(" ")
    local maxXP = UnitXPMax("player") or 1
    local pct = (rested / maxXP) * 100
    local color = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.Rested) or { r=0.07, g=0.58, b=0.95 }
    tt:AddDoubleLine(L["TT_RESTED"] or "Rested:", string.format("%s (%.0f%%)", fmtNumber(rested), pct), color.r, color.g, color.b, color.r, color.g, color.b)
    if pct > 0 and pct < 10 then
        tt:AddLine("  " .. (L["TT_RESTED_LOW_WARNING"] or "Rested low"), 1.0,0.8,0.0, true)
    end
end

function Tooltip:AddQuestSection(tt)
    -- Use XPBar module to fetch quest XP if available
    if not Addon.XPBar then return end
    local total, complete, incomplete = Addon.XPBar:GetQuestXP()
    local completeCount, incompleteCount = Addon.XPBar:GetQuestCounts()
    local db = Addon.db or {}
    if not db.showQuestXP and db.showQuestXP ~= nil then return end
    local showComplete = db.showCompleteQuestOverlay ~= false
    local showIncomplete = db.showIncompleteQuestOverlay == true
    if not showComplete and not showIncomplete then return end

    if (showComplete and (complete or 0) > 0) or (showIncomplete and (incomplete or 0) > 0) then
        tt:AddLine(" ")
    end

    local maxXP = UnitXPMax("player") or 1
    if showComplete and complete and complete > 0 then
        local pct = (complete / maxXP) * 100
        local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestComplete) or { r=1,g=0.65,b=0 }
        local countText = (completeCount == 1) and (L["TT_QUEST"] or "quest") or string.format(L["TT_QUESTS"] or "%d quests", completeCount)
        tt:AddDoubleLine(L["TT_QUEST_XP_COMPLETE"] or "Completed quest XP:", string.format("%s (%.1f%%) - %s", fmtNumber(complete), pct, countText), c.r, c.g, c.b, c.r, c.g, c.b)
    end
    if showIncomplete and incomplete and incomplete > 0 then
        local pct = (incomplete / maxXP) * 100
        local c = (XPBarColors and XPBarColors.GetUserColor) and XPBarColors:GetUserColor(Color.QuestIncomplete) or { r=1,g=1,b=0 }
        local countText = (incompleteCount == 1) and (L["TT_QUEST"] or "quest") or string.format(L["TT_QUESTS"] or "%d quests", incompleteCount)
        tt:AddDoubleLine(L["TT_QUEST_XP_INCOMPLETE"] or "Incomplete quest XP:", string.format("%s (%.1f%%) - %s", fmtNumber(incomplete), pct, countText), c.r, c.g, c.b, c.r, c.g, c.b)
    end
end

function Tooltip:AddSessionSection(tt)
    local session = (Addon.Session and Addon.Session.GetCurrent) and Addon.Session:GetCurrent() or nil
    if not session then return end
    local gained = session.gainedXP or 0
    local start = session.sessionStart or time()
    local duration = time() - start
    if duration < 30 or gained < 100 then return end

    local db = Addon.db or {}
    local showXPPerHourBelow = db.showXPPerHourText == true
    local showTimeToLevelBelow = db.showTimeToLevelText == true
    local showLevelTimeBelow = db.showLevelTimeText == true
    local showSessionTimeBelow = db.showSessionTimeText == true

    local xpHour = xpPerHour(gained, duration)
    local remaining = (UnitXPMax("player") or 1) - (UnitXP("player") or 0)
    local ttl = timeToLevel(remaining, xpHour)

    local headerAdded = false
    if not showXPPerHourBelow and xpHour > 0 then
        tt:AddLine(" ")
        tt:AddLine(L["TT_SESSION_STATS"] or "Session stats", 1,0.82,0)
        headerAdded = true
        tt:AddDoubleLine("  " .. (L["TT_XP_PER_HOUR"] or "XP/hour"), fmtNumber(xpHour), 0.7,0.7,0.7, 1,0.82,0)
    end
    if not showTimeToLevelBelow and ttl > 0 and xpHour > 0 then
        if not headerAdded then tt:AddLine(" ") tt:AddLine(L["TT_SESSION_STATS"] or "Session stats", 1,0.82,0) end
        tt:AddDoubleLine("  " .. (L["TT_TIME_TO_LEVEL"] or "Time to level"), fmtTime(ttl), 0.7,0.7,0.7, 1,0.82,0)
        headerAdded = true
    end
    if not showSessionTimeBelow then
        if not headerAdded then tt:AddLine(" ") tt:AddLine(L["TT_SESSION_STATS"] or "Session stats", 1,0.82,0) end
        tt:AddDoubleLine("  " .. (L["TT_SESSION_TIME"] or "Session time"), fmtTime(duration), 0.7,0.7,0.7, 1,1,1)
        headerAdded = true
    end
    if not showLevelTimeBelow then
        local levelTime = session.realLevelTime or 0
        if levelTime > 0 then
            if not headerAdded then tt:AddLine(" ") tt:AddLine(L["TT_SESSION_STATS"] or "Session stats", 1,0.82,0) end
            tt:AddDoubleLine("  " .. (L["TT_LEVEL_TIME"] or "Level time"), fmtTime(levelTime), 0.7,0.7,0.7, 1,1,1)
        end
    end
end

function Tooltip:AddHintSection(tt, owner)
    tt:AddLine(" ")
    if XPBarTextFormatter and XPBarTextFormatter.GetHintText then
        tt:AddLine(XPBarTextFormatter:GetHintText(owner), 0.6,0.6,0.6, true)
    end
end

function Tooltip:GetBestAnchor(owner)
    if not owner then return "ANCHOR_TOP" end
    local screenHeight = 768
    if GetScreenHeight then
        screenHeight = GetScreenHeight()
    end
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale()
    end
    screenHeight = screenHeight * scale
    local ownerTop = owner and owner.GetTop and owner:GetTop()
    if not ownerTop then return "ANCHOR_TOP" end
    if ownerTop > (screenHeight * 0.8) then
        return "ANCHOR_BOTTOM"
    else
        return "ANCHOR_TOP"
    end
end

function Tooltip:Show(owner, anchorPoint)
    if not owner then return end
    currentTooltipOwner = owner
    local tt = GameTooltip
    if not anchorPoint then anchorPoint = self:GetBestAnchor(owner) end
    tt:SetOwner(owner, anchorPoint, 0, 0)
    self:AddXPSection(tt)
    self:AddRestedSection(tt)
    self:AddQuestSection(tt)
    self:AddSessionSection(tt)
    self:AddHintSection(tt, owner)
    tt:Show()
end

function Tooltip:Hide()
    currentTooltipOwner = nil
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

function Tooltip:Refresh()
    if currentTooltipOwner and GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == currentTooltipOwner then
        self:Show(currentTooltipOwner)
    end
end

-- Export
Addon.XPBarTooltip = Tooltip
_G.XPBarTooltip = Tooltip
return Tooltip
