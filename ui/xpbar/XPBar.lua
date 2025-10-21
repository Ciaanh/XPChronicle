-- XP Bar Enhanced - XPBar Core Module
-- Coordinates XP bar display logic and delegates to view implementations

local Addon = XPBarEnhanced

local XPBar = {}
local L = Addon.L or {}
local Compatibility = Addon.Compatibility or {}

--------------------------------------------------------------------------------
-- Quest XP Tracking (from QuestXPService.lua)
--------------------------------------------------------------------------------

local questCache = {
    data = nil,
    timestamp = 0,
    TTL = 0.5,  -- Cache duration in seconds
}

---Check whether all objectives for a quest are complete

local function areObjectivesComplete(questID)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return false
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if not objectives or #objectives == 0 then
        return false
    end

    for _, objective in ipairs(objectives) do
        if not objective.finished then
            return false
        end
    end

    return true
end

---Determine if a quest is ready for turn in using available info and compatibility fallbacks
local function isQuestReadyForTurnIn(questID, info)
    if info then
        if info.isComplete or info.isAutoComplete then
            return true
        end

        if info.isOnQuest == false then
            return false
        end
    end

    -- Use compatibility wrappers where available (prefer Addon.Compatibility if populated)
    local comp = Addon.Compatibility or Compatibility
    if comp and comp.IsQuestComplete and comp:IsQuestComplete(questID) then
        return true
    end
    if comp and comp.ReadyForTurnIn and comp:ReadyForTurnIn(questID) then
        return true
    end

    if areObjectivesComplete(questID) then
        return true
    end

    return false
end

function XPBar:InvalidateQuestCache()
    questCache.data = nil
    questCache.timestamp = 0
end

---Collects quest XP totals from the player's quest log.
---Returns three values: totalQuestXP, completeQuestXP, incompleteQuestXP
function XPBar:GetQuestXP(forceRefresh)
    -- Use Compatibility wrappers to support multiple client APIs
    local comp = Addon.Compatibility or Compatibility
    if not comp or not comp.GetNumQuestLogEntries then
        return 0, 0, 0
    end

    -- Use cache if valid
    if not forceRefresh and questCache.data then
        local now = GetTime()
        if (now - questCache.timestamp) < questCache.TTL then
            return questCache.data.totalQuestXP, 
                   questCache.data.completeQuestXP, 
                   questCache.data.incompleteQuestXP
        end
    end

    local numEntries = comp:GetNumQuestLogEntries()
    if not numEntries or numEntries <= 0 then
        questCache.data = {
            totalQuestXP = 0,
            completeQuestXP = 0,
            incompleteQuestXP = 0,
        }
        questCache.timestamp = GetTime()
        return 0, 0, 0
    end

    local totalQuestXP = 0
    local completeQuestXP = 0
    local incompleteQuestXP = 0
    local completeQuestCount = 0
    local incompleteQuestCount = 0
    local countedQuests = {}

    for i = 1, numEntries do
        local info = comp:GetQuestInfo(i)
        
        if info and not info.isHeader and not info.isHidden then
            -- Use questID when available, otherwise fall back to a stable index-based key
            local key = info.questID or ("idx:" .. tostring(i))
            if not countedQuests[key] then
                countedQuests[key] = true

                -- Compatibility:GetQuestRewardXP now accepts (index, questID) to be resilient
                local xp = comp:GetQuestRewardXP(i, info.questID) or 0

                if xp > 0 then
                    if isQuestReadyForTurnIn(info.questID, info) then
                        completeQuestXP = completeQuestXP + xp
                        completeQuestCount = completeQuestCount + 1
                    else
                        incompleteQuestXP = incompleteQuestXP + xp
                        incompleteQuestCount = incompleteQuestCount + 1
                    end

                    totalQuestXP = totalQuestXP + xp
                end
            end
        end
    end

    -- Cache the results
    questCache.data = {
        totalQuestXP = totalQuestXP,
        completeQuestXP = completeQuestXP,
        incompleteQuestXP = incompleteQuestXP,
        completeQuestCount = completeQuestCount,
        incompleteQuestCount = incompleteQuestCount,
    }
    questCache.timestamp = GetTime()

    return totalQuestXP, completeQuestXP, incompleteQuestXP
end

---Return two numbers: completeQuestCount, incompleteQuestCount
function XPBar:GetQuestCounts()
    -- Ensure cache is fresh
    self:GetQuestXP()
    
    if questCache.data then
        return questCache.data.completeQuestCount or 0, 
               questCache.data.incompleteQuestCount or 0
    end
    
    return 0, 0
end

--------------------------------------------------------------------------------
-- Blizzard Bar Control (from BlizzardBarControl.lua)
--------------------------------------------------------------------------------

function XPBar:IsBlizzardBarAvailable()
    return StatusTrackingBarManager ~= nil and
           StatusTrackingBarManager.MainStatusTrackingBarContainer ~= nil
end

function XPBar:GetBlizzardXPBarFrame()
    if not self:IsBlizzardBarAvailable() then
        return nil
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Search for XP bar (barType == 0)
    if container.bars then
        for _, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then
                return bar
            end
        end
    end
    
    -- Fallback: Try StatusTrackingBar1
    if _G.StatusTrackingBar1 and _G.StatusTrackingBar1.StatusBar then
        if _G.StatusTrackingBar1.StatusBar.barType == 0 then
            return _G.StatusTrackingBar1
        end
    end
    
    return container
end

function XPBar:HideBlizzardBar()
    if not self:IsBlizzardBarAvailable() then
        return false
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Hide the XP bar specifically
    if container.bars then
        for _, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then
                bar:Hide()
                return true
            end
        end
    end
    
    -- Fallback: hide the container
    if container then
        container:Hide()
        return true
    end
    
    return false
end

function XPBar:ShowBlizzardBar()
    if not self:IsBlizzardBarAvailable() then
        return false
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Show the XP bar specifically
    if container.bars then
        for _, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then
                bar:Show()
                StatusTrackingBarManager:UpdateBarsShown()
                return true
            end
        end
    end
    
    -- Fallback: show the container
    if container then
        container:Show()
        StatusTrackingBarManager:UpdateBarsShown()
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Color Utilities (from XPBarColors.lua)
--------------------------------------------------------------------------------

---Convert color components to a WoW color escape hex string
function XPBar:RGBToHex(r, g, b, a)
    a = a or 1.0
    local ra = math.floor(a * 255)
    local rr = math.floor(r * 255)
    local rg = math.floor(g * 255)
    local rb = math.floor(b * 255)
    return string.format("|c%02X%02X%02X%02X", ra, rr, rg, rb)
end

-- Delegate to Colors module
---Return a color table for the given key
function XPBar:GetColor(colorKey)
    return Addon.Colors:Get(colorKey)
end

function XPBar:GetTooltipColor(colorKey)
    local color = self:GetColor(colorKey)
    return color.r, color.g, color.b
end

function XPBar:GetTextColor(colorKey)
    local color = self:GetColor(colorKey)
    return self:RGBToHex(color.r, color.g, color.b, color.a)
end

---Wrap text in a colored escape sequence
function XPBar:ColorText(text, colorKey)
    local colorCode = self:GetTextColor(colorKey)
    return colorCode .. text .. "|r"
end

--------------------------------------------------------------------------------
-- Text Formatting (from XPBarTextFormatter.lua)
--------------------------------------------------------------------------------

function XPBar:AbbreviateNumber(num, decimals)
    if not num then return "0" end
    decimals = decimals or 1
    
    if num < 1000 then
        return tostring(math.floor(num))
    elseif num < 1000000 then
        return string.format("%." .. decimals .. "fK", num / 1000)
    elseif num < 1000000000 then
        return string.format("%.2fM", num / 1000000)
    else
        return string.format("%.2fB", num / 1000000000)
    end
end

function XPBar:FormatNumber(num, abbreviate)
    if not num then return "0" end
    
    if abbreviate then
        return self:AbbreviateNumber(num)
    elseif BreakUpLargeNumbers then
        return BreakUpLargeNumbers(num)
    else
        return tostring(math.floor(num))
    end
end

function XPBar:FormatTime(seconds, short)
    if not seconds or seconds <= 0 then
        return short and "0s" or "0 seconds"
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if short then
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm", minutes)
        else
            return string.format("%ds", secs)
        end
    else
        local parts = {}
        if days > 0 then
            table.insert(parts, days == 1 and "1 day" or string.format("%d days", days))
        end
        if hours > 0 then
            table.insert(parts, hours == 1 and "1 hour" or string.format("%d hours", hours))
        end
        if minutes > 0 and days == 0 then
            table.insert(parts, minutes == 1 and "1 minute" or string.format("%d minutes", minutes))
        end
        if secs > 0 and hours == 0 and days == 0 then
            table.insert(parts, secs == 1 and "1 second" or string.format("%d seconds", secs))
        end
        return #parts > 0 and table.concat(parts, " ") or "0 seconds"
    end
end

function XPBar:FormatPercent(value, maxValue, decimals)
    if not value or not maxValue or maxValue == 0 then
        return "0%"
    end
    decimals = decimals or 1
    local percent = (value / maxValue) * 100
    return string.format("%." .. decimals .. "f%%", percent)
end

-- Text Builder Methods

function XPBar:GetLevelText(level)
    if not level then
        level = UnitLevel("player")
    end
    return string.format("Level %d", level)
end

function XPBar:GetXPText(currentXP, maxXP, abbreviate, showRemaining)
    if not currentXP or not maxXP then
        return ""
    end
    
    local current = self:FormatNumber(currentXP, abbreviate)
    local max = self:FormatNumber(maxXP, abbreviate)
    
    if showRemaining then
        local remaining = self:FormatNumber(maxXP - currentXP, abbreviate)
        return string.format("%s / %s (%s)", current, max, remaining)
    else
        return string.format("%s / %s", current, max)
    end
end

function XPBar:GetPercentText(currentXP, maxXP, decimals, showQuestPercent, questXP)
    if not currentXP or not maxXP then
        return "0%"
    end
    
    local percent = self:FormatPercent(currentXP, maxXP, decimals)
    
    if showQuestPercent and questXP and questXP > 0 then
        local withQuest = currentXP + questXP
        local questPercent = self:FormatPercent(withQuest, maxXP, decimals)
        return string.format("%s (%s)", percent, questPercent)
    else
        return percent
    end
end

function XPBar:GetXPRateText(xpPerHour, abbreviate)
    if not xpPerHour or xpPerHour <= 0 then
        return "Calculating..."
    end
    
    local rate = self:FormatNumber(xpPerHour, abbreviate)
    return string.format("%s XP/Hour", rate)
end

function XPBar:GetTimeToLevelText(secondsToLevel, prefix)
    if not secondsToLevel or secondsToLevel <= 0 then
        return "N/A"
    end
    
    -- Cap at 99+ hours for display
    if secondsToLevel > 356400 then -- 99 hours
        return "99+ hours"
    end
    
    local timeStr = self:FormatTime(secondsToLevel, true)
    
    if prefix then
        return string.format("%s: %s", prefix, timeStr)
    else
        return timeStr
    end
end

function XPBar:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, decimals)
    -- Prefer centralized overlay helper when available
    if Addon.OverlayHelper and type(Addon.OverlayHelper.GetQuestSummaryText) == "function" then
        return Addon.OverlayHelper:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, { decimals = decimals })
    end

    -- Fallback: simple summary
    if not maxXP or maxXP <= 0 then
        return ""
    end
    decimals = decimals or 1
    local parts = {}
    if completeXP and completeXP > 0 then
        table.insert(parts, string.format("Completed: %s", self:FormatNumber(completeXP, true)))
    end
    if restedXP and restedXP > 0 then
        table.insert(parts, string.format("Rested: %s", self:FormatNumber(restedXP, true)))
    end
    return #parts > 0 and table.concat(parts, " - ") or ""
end

function XPBar:GetSessionTimeText(sessionSeconds, prefix)
    if not sessionSeconds then
        return ""
    end
    
    local timeStr = self:FormatTime(sessionSeconds, true)
    
    if prefix then
        return string.format("%s: %s", prefix, timeStr)
    else
        return timeStr
    end
end

function XPBar:GetLevelTimeText(levelSeconds, prefix)
    if not levelSeconds then
        return ""
    end
    
    local timeStr = self:FormatTime(levelSeconds, true)
    
    if prefix then
        return string.format("%s: %s", prefix, timeStr)
    else
        return timeStr
    end
end

function XPBar:GetCombinedRateText(xpPerHour, timeToLevel, abbreviate)
    local ratePart = self:GetXPRateText(xpPerHour, abbreviate)
    local timePart = self:GetTimeToLevelText(timeToLevel)
    
    if ratePart == "Calculating..." and timePart == "N/A" then
        return "Calculating..."
    elseif ratePart == "Calculating..." then
        return "Leveling in: " .. timePart
    elseif timePart == "N/A" then
        return ratePart
    else
        local rate = xpPerHour
        local rateStr
        if rate > 10000 then
            rateStr = string.format("%.1fK", rate / 1000)
        else
            rateStr = self:FormatNumber(rate, false)
        end
        return string.format("Leveling in: %s (%s XP/Hour)", timePart, rateStr)
    end
end

function XPBar:GetCombinedSessionText(sessionSeconds, levelSeconds)
    local sessionPart = self:GetSessionTimeText(sessionSeconds, "Session")
    local levelPart = self:GetLevelTimeText(levelSeconds, "This Level")
    
    local parts = {}
    
    if sessionPart ~= "" then
        table.insert(parts, sessionPart)
    end
    
    if levelPart ~= "" then
        table.insert(parts, levelPart)
    end
    
    if #parts == 0 then
        return ""
    end
    
    return table.concat(parts, " - ")
end

function XPBar:GetSessionXPText(sessionXP, abbreviate)
    if not sessionXP or sessionXP <= 0 then
        return ""
    end

    local xp = self:FormatNumber(sessionXP, abbreviate)
    return string.format("Session: %s XP", xp)
end

function XPBar:GetRestedStatusText(restedXP, maxXP)
    if not restedXP or restedXP <= 0 or not maxXP or maxXP <= 0 then
        return "Not Rested"
    end

    local restedPercent = self:FormatPercent(restedXP, maxXP, 0)
    return string.format("Rested: %s", restedPercent)
end

function XPBar:GetQuestXPText(completeXP, incompleteXP, abbreviate)
    if not completeXP and not incompleteXP then
        return ""
    end

    local parts = {}
    if completeXP and completeXP > 0 then
        table.insert(parts, string.format("Complete: %s", self:FormatNumber(completeXP, abbreviate)))
    end

    if incompleteXP and incompleteXP > 0 then
        table.insert(parts, string.format("Incomplete: %s", self:FormatNumber(incompleteXP, abbreviate)))
    end

    if #parts == 0 then
        return ""
    end

    return "Quest XP: " .. table.concat(parts, " / ")
end

function XPBar:GetHintText(frame)
    local AddonL = Addon.L or {}
    local baseHint = AddonL["TT_HINT_CONFIG"] or "Right-click to configure XP Bar"

    -- Show drag hint if the bar's container is draggable and movable
    local container = frame and frame.GetParent and frame:GetParent()
    if container and container.isDraggable and container.IsMovable and container:IsMovable() then
        local modifier = container._xpbeDragModifier or "SHIFT"
        local modifierName = modifier
        -- Localize common modifier names
        if type(modifierName) == "string" then
            if modifierName:upper() == "SHIFT" then
                modifierName = AddonL["KEY_SHIFT"] or "Shift"
            elseif modifierName:upper() == "CTRL" then
                modifierName = AddonL["KEY_CTRL"] or "Ctrl"
            elseif modifierName:upper() == "ALT" then
                modifierName = AddonL["KEY_ALT"] or "Alt"
            end
        end
        local dragFmt = AddonL["TT_HINT_DRAG"] or "Hold %s and drag to move the bar"
        return string.format("%s | %s", baseHint, string.format(dragFmt, modifierName))
    end

    return baseHint
end

--------------------------------------------------------------------------------
-- Tooltip (from XPBarTooltip.lua - core logic, views can extend)
--------------------------------------------------------------------------------

local currentTooltipOwner = nil

function XPBar:ShowTooltip(frame)
    currentTooltipOwner = frame
    
    GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM", 0, -10)
    
    -- XP Section
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local percentXP = math.floor((currentXP / maxXP) * 100)
    local remainingXP = maxXP - currentXP
    
    GameTooltip_SetTitle(GameTooltip, L["TT_EXPERIENCE"] or "Experience")
    
    GameTooltip:AddDoubleLine(
        (L["TT_CURRENT"] or "Current") .. ":",
        string.format("%s / %s", self:FormatNumber(currentXP, false), self:FormatNumber(maxXP, false)),
        0.7, 0.7, 0.7,
        1.0, 1.0, 1.0
    )
    
    GameTooltip:AddDoubleLine(
        (L["TT_REMAINING"] or "Remaining") .. ":",
        self:FormatNumber(remainingXP, false),
        0.7, 0.7, 0.7,
        1.0, 1.0, 1.0
    )
    
    -- Rested Section
    local restedXP = GetXPExhaustion() or 0
    if restedXP > 0 then
        GameTooltip:AddLine(" ")
        local restedPercent = (restedXP / maxXP) * 100
        local restedR, restedG, restedB = self:GetTooltipColor(self.ColorKey.Rested)
        
        GameTooltip:AddDoubleLine(
            L["TT_RESTED"] or "Rested",
            string.format("%s (%.0f%%)", self:FormatNumber(restedXP, false), restedPercent),
            restedR, restedG, restedB,
            restedR, restedG, restedB
        )
    end
    
    -- Quest Section
    local db = Addon.db or {}
    if db.showQuestXP ~= false then
        local showComplete = db.showCompleteQuestOverlay ~= false
        local showIncomplete = db.showIncompleteQuestOverlay == true
        
        local totalQuestXP, completeQuestXP, incompleteQuestXP = self:GetQuestXP()
        local completeQuestCount, incompleteQuestCount = self:GetQuestCounts()
        
        local hasCompleteToShow = showComplete and completeQuestXP and completeQuestXP > 0
        local hasIncompleteToShow = showIncomplete and incompleteQuestXP and incompleteQuestXP > 0
        
        if hasCompleteToShow or hasIncompleteToShow then
            GameTooltip:AddLine(" ")
            
            if hasCompleteToShow then
                local questPercent = (completeQuestXP / maxXP) * 100
                local completeR, completeG, completeB = self:GetTooltipColor(self.ColorKey.QuestComplete)
                
                GameTooltip:AddDoubleLine(
                    L["TT_QUESTS_COMPLETE"] or "Quests Complete",
                    string.format("%d (%s, %.1f%%)", completeQuestCount, 
                                  self:FormatNumber(completeQuestXP, false), questPercent),
                    completeR, completeG, completeB,
                    completeR, completeG, completeB
                )
            end
            
            if hasIncompleteToShow then
                local questPercent = (incompleteQuestXP / maxXP) * 100
                local incompleteR, incompleteG, incompleteB = self:GetTooltipColor(self.ColorKey.QuestIncomplete)
                
                GameTooltip:AddDoubleLine(
                    L["TT_QUESTS_INCOMPLETE"] or "Quests Incomplete",
                    string.format("%d (%s, %.1f%%)", incompleteQuestCount, 
                                  self:FormatNumber(incompleteQuestXP, false), questPercent),
                    incompleteR, incompleteG, incompleteB,
                    incompleteR, incompleteG, incompleteB
                )
            end
        end
    end
    
    -- Session Stats Section
    if Addon.Session then
        local session = Addon.Session:GetCurrent()
        if session and session.gainedXP and session.gainedXP > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TT_SESSION"] or "Session", 0.4, 0.78, 1.0)
            
            local sessionTime = time() - (session.sessionStart or time())
            if sessionTime > 0 then
                local xpPerHour = math.floor((session.gainedXP / sessionTime) * 3600)
                GameTooltip:AddDoubleLine(
                    (L["TT_XP_HOUR"] or "XP/Hour") .. ":",
                    self:FormatNumber(xpPerHour, false),
                    0.7, 0.7, 0.7,
                    1.0, 1.0, 1.0
                )
                
                if xpPerHour > 0 then
                    local timeToLevel = math.floor((remainingXP / xpPerHour) * 3600)
                    GameTooltip:AddDoubleLine(
                        (L["TT_TIME_TO_LEVEL"] or "Time to Level") .. ":",
                        self:FormatTime(timeToLevel, false),
                        0.7, 0.7, 0.7,
                        1.0, 1.0, 1.0
                    )
                end
            end
        end
    end
    
    GameTooltip:Show()
end

function XPBar:HideTooltip()
    currentTooltipOwner = nil
    GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- View Management (coordinates Legacy/Flat/Future views)
--------------------------------------------------------------------------------

XPBar.currentView = nil
XPBar.currentViewType = nil
XPBar.periodicUpdateTimer = nil

function XPBar:GetView()
    -- Legacy compatibility: old code expected Addon.UI.Views.XPBar
    -- Now we just return self since XPBar module is the coordinator
    return self
end

function XPBar:GetActiveView()
    return self.currentView
end

function XPBar:GetLegacyContainer()
    return _G.LegacyXPBar
end

function XPBar:GetFlatContainer()
    return _G.FlatXPBar
end

function XPBar:GetVerticalContainer()
    return _G.VerticalXPBar
end

function XPBar:GetCircularContainer()
    return _G.CircularXPBar
end

function XPBar:GetTestContainer()
    return _G.TestXPBar
end

function XPBar:GetLegacyView()
    local container = self:GetLegacyContainer()
    return container and container.Bar
end

function XPBar:GetFlatView()
    local container = self:GetFlatContainer()
    return container and container.Bar
end

function XPBar:GetVerticalView()
    local container = self:GetVerticalContainer()
    return container and container.Bar
end

function XPBar:GetCircularView()
    local container = self:GetCircularContainer()
    return container and container.Bar
end

function XPBar:GetTestView()
    local container = self:GetTestContainer()
    return container and container.Bar
end

function XPBar:SetBarStyle(style, skipSave)
    -- Validate style
    local validStyles = { "none", "legacy", "flat", "vertical", "circular" }
    local isValid = false
    for _, validStyle in ipairs(validStyles) do
        if style == validStyle then
            isValid = true
            break
        end
    end
    
    if not isValid then
        print("XPBar: Invalid style: " .. tostring(style))
        return
    end
    
    -- Define all containers and their view getters
    local containers = {
        legacy = { container = self:GetLegacyContainer(), viewGetter = function() return self:GetLegacyView() end },
        flat = { container = self:GetFlatContainer(), viewGetter = function() return self:GetFlatView() end },
        vertical = { container = self:GetVerticalContainer(), viewGetter = function() return self:GetVerticalView() end },
        circular = { container = self:GetCircularContainer(), viewGetter = function() return self:GetCircularView() end },
    }
    
    -- Hide all our bars
    for _, data in pairs(containers) do
        if data.container then
            data.container:Hide()
        end
    end
    
    -- Apply style-specific behavior
    if style == "none" then
        self.currentView = nil
        self.currentViewType = nil
        self:ShowBlizzardBar()
    else
        -- Hide Blizzard bar for custom styles
        self:HideBlizzardBar()
        
        -- Show and activate the selected bar
        local barData = containers[style]
        if barData and barData.container then
            barData.container:Show()
            self.currentView = barData.viewGetter()
            self.currentViewType = style
            
            -- Manually trigger the bar's OnShow to ensure FullUpdate is called
            if self.currentView and self.currentView.OnShow then
                self.currentView:OnShow()
            end
        end
    end
    
    -- Save preference
    if not skipSave then
        Addon.db.barStyle = style
    end
end

--------------------------------------------------------------------------------
-- Periodic Updates
--------------------------------------------------------------------------------

function XPBar:StartPeriodicUpdates()
    if self.periodicUpdateTimer then
        self.periodicUpdateTimer:Cancel()
        self.periodicUpdateTimer = nil
    end
    
    self.periodicUpdateTimer = C_Timer.NewTicker(5, function()
        if not self.currentView then return end
        
        -- Update time-sensitive text displays
        if self.currentView.UpdateRateText then
            self.currentView:UpdateRateText()
        end
        if self.currentView.UpdateSessionText then
            self.currentView:UpdateSessionText()
        end
    end)
end

--------------------------------------------------------------------------------
-- NOTE: Earlier versions used per-frame OnUpdate handlers for animations. The
-- centralized animation registry was removed per user request to restore the
-- original, frame-driven animation behavior.

function XPBar:StopPeriodicUpdates()
    if self.periodicUpdateTimer then
        self.periodicUpdateTimer:Cancel()
        self.periodicUpdateTimer = nil
    end
end

--------------------------------------------------------------------------------
-- Core Bar Management
--------------------------------------------------------------------------------

function XPBar:Initialize()
    -- Register quest events
    self:RegisterQuestEvents()
    
    -- Load saved bar style and show the appropriate bar
    local style = Addon.db and Addon.db.barStyle or "legacy"
    self:SetBarStyle(style, true)
    
    -- Initial update
    self:Update()
    
    -- Start periodic updates for time-based displays
    self:StartPeriodicUpdates()
end

function XPBar:Update()
    if self.currentView and self.currentView.FullUpdate then
        self.currentView:FullUpdate()
    end
end

function XPBar:RegisterQuestEvents()
    -- Avoid creating multiple frames
    if self.questEventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("QUEST_REMOVED")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    frame:RegisterEvent("QUEST_WATCH_UPDATE")

    frame:SetScript("OnEvent", function(_, event, ...)
        -- Filter unit events to player only via OnQuestEvent
        self:OnQuestEvent(event, ...)
    end)

    self.questEventFrame = frame
end

function XPBar:ShutdownQuestEventHandling()
    if self.questEventFrame then
        self.questEventFrame:UnregisterAllEvents()
        self.questEventFrame:SetScript("OnEvent", nil)
        self.questEventFrame = nil
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function XPBar:OnXPUpdate()
    self:Update()
end

function XPBar:OnLevelUp(newLevel)
    self:InvalidateQuestCache()
    self:Update()
end

function XPBar:OnQuestEvent(event, ...)
    self:InvalidateQuestCache()
    
    -- Delayed update to ensure quest log is updated (cancelable)
    if self._questUpdateTimer then
        pcall(function() self._questUpdateTimer:Cancel() end)
        self._questUpdateTimer = nil
    end
    self._questUpdateTimer = C_Timer.NewTimer(0.5, function()
        if not self or not self.Update then
            self._questUpdateTimer = nil
            return
        end
        self:Update()
        self._questUpdateTimer = nil
    end)
end

function XPBar:OnEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin or isReloadingUI then
        self:InvalidateQuestCache()
        self:Update()
    end
end

function XPBar:Shutdown()
    -- Cancel any pending quest update timer
    if self._questUpdateTimer then
        pcall(function() self._questUpdateTimer:Cancel() end)
        self._questUpdateTimer = nil
    end

    -- Stop periodic updates
    self:StopPeriodicUpdates()

    -- (No global animation registry in this build; per-view handlers are frame-driven.)

    -- Clear active view reference
    self.currentView = nil
    self.currentViewType = nil
    
    -- Shutdown quest event handling
    if self.ShutdownQuestEventHandling then
        self:ShutdownQuestEventHandling()
    end
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

XPBarEnhanced.XPBar = XPBar

--------------------------------------------------------------------------------
-- Compatibility: Expose as global XPBarTextFormatter for view mixins
--------------------------------------------------------------------------------

XPBarTextFormatter = {
    AbbreviateNumber = function(_, ...) return XPBar:AbbreviateNumber(...) end,
    FormatNumber = function(_, ...) return XPBar:FormatNumber(...) end,
    FormatTime = function(_, ...) return XPBar:FormatTime(...) end,
    FormatPercent = function(_, ...) return XPBar:FormatPercent(...) end,
    GetLevelText = function(_, ...) return XPBar:GetLevelText(...) end,
    GetXPText = function(_, ...) return XPBar:GetXPText(...) end,
    GetPercentText = function(_, ...) return XPBar:GetPercentText(...) end,
    GetXPRateText = function(_, ...) return XPBar:GetXPRateText(...) end,
    GetTimeToLevelText = function(_, ...) return XPBar:GetTimeToLevelText(...) end,
    GetQuestSummaryText = function(_, ...) return XPBar:GetQuestSummaryText(...) end,
    GetSessionTimeText = function(_, ...) return XPBar:GetSessionTimeText(...) end,
    GetLevelTimeText = function(_, ...) return XPBar:GetLevelTimeText(...) end,
    GetCombinedRateText = function(_, ...) return XPBar:GetCombinedRateText(...) end,
    GetCombinedSessionText = function(_, ...) return XPBar:GetCombinedSessionText(...) end,
    GetSessionXPText = function(_, ...) return XPBar:GetSessionXPText(...) end,
    GetRestedStatusText = function(_, ...) return XPBar:GetRestedStatusText(...) end,
    GetQuestXPText = function(_, ...) return XPBar:GetQuestXPText(...) end,
    GetHintText = function(_, ...) return XPBar:GetHintText(...) end,
}

--------------------------------------------------------------------------------
-- Compatibility: Expose Quest XP Service for view mixins
--------------------------------------------------------------------------------

return XPBar
