-- XP Bar Enhanced - Stats Module
-- Consolidated from: StatsController.lua + StatsView.lua
-- Manages the stats window displaying level and session statistics

local Addon = XPBarEnhanced

local Stats = {}

--------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------

local FrameUtils = Addon.UI.Components and Addon.UI.Components.FrameUtils
local PositionStoreMixin = Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
local DraggableFrameMixin = Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
local SessionService = Addon.Session

--------------------------------------------------------------------------------
-- Local State
--------------------------------------------------------------------------------

local frame

--------------------------------------------------------------------------------
-- Frame Mixin (for XML-defined frame)
--------------------------------------------------------------------------------

local StatsFrameMixin = {}
-- Register the mixin under a namespaced table and expose the global
-- alias only for XML mixin resolution.
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Mixins.StatsFrameMixin = StatsFrameMixin
_G.XPBarEnhancedStatsMixin = StatsFrameMixin

function StatsFrameMixin:OnLoad()
    local statsFrame = self
    Stats:SetFrame(statsFrame)

    statsFrame:SetClampedToScreen(true)

    -- Initialize draggable frame functionality
    if PositionStoreMixin and DraggableFrameMixin then
        Mixin(statsFrame, PositionStoreMixin, DraggableFrameMixin)
        statsFrame:InitPositionStorage(
            function()
                return Addon.db and Addon.db.statsPosition
            end,
            function(pos)
                if Addon.db then
                    Addon.db.statsPosition = pos
                end
            end,
            function()
                return {
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = 0,
                    y = 0,
                }
            end
        )
        statsFrame:EnableDrag({ button = "LeftButton" })
    elseif FrameUtils and FrameUtils.EnableDrag then
        FrameUtils.EnableDrag(statsFrame, { button = "LeftButton" })
    end

    -- Setup close button
    if statsFrame.CloseButton then
        statsFrame.CloseButton:SetScript("OnClick", function(btn)
            btn:GetParent():Hide()
        end)
    end

    -- Initial update
    Stats:Update()
end

function StatsFrameMixin:OnShow()
    -- Immediate update when shown
    Stats:Update()
end

function StatsFrameMixin:OnHide()
    -- Could add event unsubscribing here if needed
end

function StatsFrameMixin:OnUpdate(elapsed)
    -- Reserved for potential future use (animations, etc.)
end

--------------------------------------------------------------------------------
-- Core Stats Module
--------------------------------------------------------------------------------

---Set the Stats frame instance used by the module
function Stats:SetFrame(newFrame)
    frame = newFrame
    self.frame = newFrame
end

---Return the currently registered Stats frame (or nil)
function Stats:GetFrame()
    if frame then
        return frame
    end

    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing then
        self:SetFrame(existing)
        return existing
    end
end

function Stats:Initialize()
    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing and existing.OnLoad then
        existing:OnLoad()
        self:SetFrame(existing)
        -- Register for game events to keep stats up-to-date
        self:RegisterEventHandlers()
    elseif existing then
        self:SetFrame(existing)
        self:Update()
        -- Register for game events even if OnLoad wasn't called
        self:RegisterEventHandlers()
    end
end

function Stats:RegisterEventHandlers()
    if self.eventFrame then return end

    local f = CreateFrame and CreateFrame('Frame') or {}
    -- Provide safe no-op implementations when running in test/stubbed env
    f.RegisterEvent = f.RegisterEvent or function(_, _) end
    f.UnregisterAllEvents = f.UnregisterAllEvents or function(_) end
    f.SetScript = f.SetScript or function(_, _, _) end

    -- Register events we care about
    if f.RegisterEvent then
        f:RegisterEvent('PLAYER_XP_UPDATE')
        f:RegisterEvent('PLAYER_LEVEL_UP')
        f:RegisterEvent('TIME_PLAYED_MSG')
        f:RegisterEvent('QUEST_LOG_UPDATE')
        f:RegisterEvent('UNIT_QUEST_LOG_CHANGED')
    end

    -- OnEvent handler dispatches to Stats methods
    if f.SetScript then
        f:SetScript('OnEvent', function(_, event, ...)
            if event == 'PLAYER_XP_UPDATE' then
                self:OnXPUpdate(...)
            elseif event == 'PLAYER_LEVEL_UP' then
                self:OnLevelUp(...)
            elseif event == 'TIME_PLAYED_MSG' then
                self:OnTimePlayed(...)
            elseif event == 'QUEST_LOG_UPDATE' or event == 'UNIT_QUEST_LOG_CHANGED' then
                self:OnQuestXPUpdated(...)
            end
        end)
    end

    self.eventFrame = f
end

function Stats:ShutdownEventHandlers()
    if not self.eventFrame then return end
    pcall(function()
        if self.eventFrame.UnregisterAllEvents then
            self.eventFrame:UnregisterAllEvents()
        end
        if self.eventFrame.SetScript then
            self.eventFrame:SetScript('OnEvent', nil)
        end
    end)
    self.eventFrame = nil
end

function Stats:Toggle()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    if statsFrame:IsShown() then
        statsFrame:Hide()
    else
        self:Update()
        statsFrame:Show()
    end
end

function Stats:Update()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    -- Update Left Page (Current Level Stats)
    self:UpdateLevelStats(statsFrame)
    
    -- Update Right Page (Session Stats)
    self:UpdateSessionStats(statsFrame)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function Stats:OnXPUpdate()
    self:Update()
end

function Stats:OnLevelUp()
    self:Update()
end

function Stats:OnXPChanged()
    self:UpdateLevelStats(self.frame)
end

function Stats:OnSessionUpdated()
    self:UpdateSessionStats(self.frame)
end

function Stats:OnQuestXPUpdated()
    self:UpdateLevelStats(self.frame)
end

function Stats:OnTimePlayed(totalTime, levelTime)
    self:Update()
end

--------------------------------------------------------------------------------
-- Update Methods
--------------------------------------------------------------------------------

-- Update left page with current level statistics
function Stats:UpdateLevelStats(statsFrame)
    if not (statsFrame and statsFrame.LeftPage) then return end
    
    local leftPage = statsFrame.LeftPage
    local content = leftPage.Content
    if not content then return end
    
    -- Get current player stats
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local remainingXP = math.max(0, maxXP - currentXP)
    local restedXP = GetXPExhaustion() or 0
    
    -- Calculate progress percentage
    local percent = (currentXP / math.max(maxXP, 1)) * 100
    
    -- Get session data for level time tracking
    local session = SessionService and SessionService:GetCurrent()
    
    -- Get time on this level (from session service)
    local levelTime = 0
    if session and session.realLevelTime then
        levelTime = session.realLevelTime
    end
    
    -- Calculate XP rate for THIS LEVEL (not just current session)
    -- This uses the XP gained during this level divided by time spent on this level
    local levelXPRate = 0  -- XP per second for this level
    if levelTime > 0 and currentXP > 0 then
        levelXPRate = currentXP / levelTime  -- XP per second
    end
    
    -- Calculate time to next level based on current level's XP rate
    local timeToLevel = nil
    if levelXPRate > 0 and remainingXP > 0 then
        timeToLevel = remainingXP / levelXPRate  -- in seconds
    end
    
    -- Update current level
    if content.CurrentLevelValue then
        content.CurrentLevelValue:SetText(tostring(currentLevel))
    end
    
    -- Update current XP
    if content.CurrentXPValue then
        content.CurrentXPValue:SetText(Addon.Utils.ShortNumber(currentXP))
    end
    
    -- Update max XP
    if content.MaxXPValue then
        content.MaxXPValue:SetText(Addon.Utils.ShortNumber(maxXP))
    end
    
    -- Update progress
    if content.ProgressValue then
        content.ProgressValue:SetText(string.format("%.1f%%", percent))
    end
    
    -- Update remaining XP
    if content.RemainingXPValue then
        content.RemainingXPValue:SetText(Addon.Utils.ShortNumber(remainingXP))
    end
    
    -- Update rested XP
    if content.RestedXPValue then
        if restedXP > 0 then
            content.RestedXPValue:SetText(Addon.Utils.ShortNumber(restedXP))
        else
            content.RestedXPValue:SetText("None")
        end
    end
    
    -- Update quest XP
    if content.QuestXPValue then
        local totalQuestXP, completeQuestXP, incompleteQuestXP = self:GetQuestXP()
        
        if totalQuestXP > 0 then
            local questPercent = (totalQuestXP / math.max(maxXP, 1)) * 100
            content.QuestXPValue:SetText(string.format("%s (%.1f%%)", 
                Addon.Utils.ShortNumber(totalQuestXP), questPercent))
        else
            content.QuestXPValue:SetText("None")
        end
    end
    
    -- Update time on this level
    if content.LevelTimeValue then
        if levelTime > 0 then
            content.LevelTimeValue:SetText(Addon.Utils.FormatDuration(levelTime))
        else
            content.LevelTimeValue:SetText("N/A")
        end
    end
    
    -- Update time to next level
    if content.TimeToLevelValue then
        if timeToLevel and timeToLevel > 0 then
            content.TimeToLevelValue:SetText(Addon.Utils.FormatDuration(timeToLevel))
        else
            content.TimeToLevelValue:SetText("N/A")
        end
    end
end

-- Update right page with session statistics
function Stats:UpdateSessionStats(statsFrame)
    if not (statsFrame and statsFrame.RightPage) then return end
    
    local rightPage = statsFrame.RightPage
    local content = rightPage.Content
    if not content then return end
    
    -- Get session data
    local session = SessionService and SessionService:GetCurrent()
    if not session then
        session = {
            sessionStart = time(),
            gainedXP = 0,
            realLevelTime = 0
        }
    end
    
    -- Calculate session duration
    local sessionElapsed = time() - (session.sessionStart or time())
    local sessionXP = session.gainedXP or 0
    
    -- Calculate XP per hour
    local xpPerHour = 0
    if sessionElapsed > 0 and sessionXP > 0 then
        xpPerHour = math.floor((sessionXP / sessionElapsed) * 3600)
    end
    
    -- Calculate levels gained this session
    local levelsGained = 0
    if SessionService and SessionService.GetSession then
        -- TODO: Track levels gained in session
        levelsGained = 0
    end
    
    -- Update session duration
    if content.SessionDurationValue then
        content.SessionDurationValue:SetText(Addon.Utils.FormatDuration(sessionElapsed))
    end
    
    -- Update session start time
    if content.SessionStartValue then
        local startTime = date("%H:%M", session.sessionStart or time())
        content.SessionStartValue:SetText(startTime)
    end
    
    -- Update XP gained
    if content.SessionXPValue then
        content.SessionXPValue:SetText(Addon.Utils.ShortNumber(sessionXP))
    end
    
    -- Update levels gained
    if content.LevelsGainedValue then
        content.LevelsGainedValue:SetText(tostring(levelsGained))
    end
    
    -- Update XP per hour
    if content.XPPerHourValue then
        if xpPerHour > 0 then
            content.XPPerHourValue:SetText(Addon.Utils.ShortNumber(xpPerHour))
        else
            content.XPPerHourValue:SetText("Calculating...")
        end
    end
    
    -- Update total session XP (same as gained)
    if content.TotalSessionXPValue then
        content.TotalSessionXPValue:SetText(Addon.Utils.ShortNumber(sessionXP))
    end
end

--------------------------------------------------------------------------------
-- Quest XP Integration
--------------------------------------------------------------------------------

---Return quest XP totals (total, complete, incomplete)
function Stats:GetQuestXP(forceRefresh)
    -- Try new consolidated path first
    if Addon.XPBar and Addon.XPBar.GetQuestXP then
        return Addon.XPBar:GetQuestXP(forceRefresh)
    end
    
    return 0, 0, 0
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

XPBarEnhanced.Stats = Stats

-- Compatibility: Expose via old paths
Addon.UI = Addon.UI or {}
Addon.UI.Views = Addon.UI.Views or {}
Addon.UI.Views.Stats = Stats

-- Compatibility: Old Features.stats path
-- Register Stats module
Addon.Stats = Stats

return Stats
