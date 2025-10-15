-- XP Bar Enhanced Stats View - Book-Style Two-Page Layout
-- Left Page: Current Level Stats
-- Right Page: Current Session Stats
local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Views = Addon.UI.Views or {}

local View = Addon.UI.Views.Stats or {}
Addon.UI.Views.Stats = View
Addon.Stats = View

local Utils = Addon.Utils or {}
local FrameUtils = Addon.UI.Components and Addon.UI.Components.FrameUtils
local PositionStoreMixin = Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
local DraggableFrameMixin = Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
local SessionService = Addon.App and Addon.App.Services and Addon.App.Services.SessionService

local frame

local StatsFrameMixin = {}
XPBarEnhancedStatsMixin = StatsFrameMixin

function View:SetFrame(newFrame)
    frame = newFrame
    self.frame = newFrame
end

function StatsFrameMixin:OnLoad()
    local statsFrame = self
    View:SetFrame(statsFrame)

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
    View:Update()
end

function StatsFrameMixin:OnShow()
    -- Subscribe to events (event-driven updates)
    View:SubscribeToEvents()
    
    -- Immediate update when shown
    View:Update()
end

function StatsFrameMixin:OnHide()
    -- Unsubscribe from events to prevent memory leaks
    View:UnsubscribeFromEvents()
end

function StatsFrameMixin:OnUpdate(elapsed)
    -- NOTE: Auto-refresh timer removed in Phase 3!
    -- Stats now update automatically via event subscriptions
    -- This method kept for potential future use (animations, etc.)
end

function View:Initialize(controller)
    if controller then
        self.controller = controller
    end

    if frame and frame:IsShown() then
        return
    end

    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing and existing.OnLoad then
        existing:OnLoad()
        self:SetFrame(existing)
    elseif existing then
        self:SetFrame(existing)
        self:Update()
    end
end

function View:GetFrame()
    if frame then
        return frame
    end

    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing then
        self:SetFrame(existing)
        return existing
    end
end

function View:Toggle()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    if statsFrame:IsShown() then
        statsFrame:Hide()
    else
        self:Update()
        statsFrame:Show()
    end
end

-----------------------------------
-- Event Subscription (Phase 3: Event-Driven Architecture)
-----------------------------------

-- Subscribe to EventBus events
function View:SubscribeToEvents()
    local EventBus = XPC_EventBus
    local EventTypes = XPC_EventTypes
    
    if not EventBus or not EventTypes then
        return
    end
    
    -- Store unsubscribe functions for cleanup
    self.eventUnsubscribers = self.eventUnsubscribers or {}
    
    -- XP Changed - Update level stats
    table.insert(self.eventUnsubscribers, EventBus:Subscribe(
        EventTypes.XP_CHANGED,
        "StatsView",
        function(data)
            self:UpdateLevelStats(frame)
        end
    ))
    
    -- Session Updated - Update session stats
    table.insert(self.eventUnsubscribers, EventBus:Subscribe(
        EventTypes.SESSION_UPDATED,
        "StatsView",
        function(data)
            self:UpdateSessionStats(frame)
        end
    ))
    
    -- Quest XP Updated - Update quest XP in level stats
    table.insert(self.eventUnsubscribers, EventBus:Subscribe(
        EventTypes.QUEST_XP_UPDATED,
        "StatsView",
        function(data)
            self:UpdateLevelStats(frame)
        end
    ))
    
    -- Level Up - Update both pages
    table.insert(self.eventUnsubscribers, EventBus:Subscribe(
        EventTypes.LEVEL_UP,
        "StatsView",
        function(data)
            self:Update()
        end
    ))
end

-- Unsubscribe from all events
function View:UnsubscribeFromEvents()
    if not self.eventUnsubscribers then
        return
    end
    
    for _, unsubscribe in ipairs(self.eventUnsubscribers) do
        unsubscribe()
    end
    
    self.eventUnsubscribers = {}
end

-----------------------------------
-- Update Methods
-----------------------------------

function View:Update()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    -- Update Left Page (Current Level Stats)
    self:UpdateLevelStats(statsFrame)
    
    -- Update Right Page (Session Stats)
    self:UpdateSessionStats(statsFrame)
end

-- Update left page with current level statistics
function View:UpdateLevelStats(statsFrame)
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
    local session = SessionService and SessionService:GetSession()
    
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
        content.CurrentXPValue:SetText(Utils.ShortNumber(currentXP))
    end
    
    -- Update max XP
    if content.MaxXPValue then
        content.MaxXPValue:SetText(Utils.ShortNumber(maxXP))
    end
    
    -- Update progress
    if content.ProgressValue then
        content.ProgressValue:SetText(string.format("%.1f%%", percent))
    end
    
    -- Update remaining XP
    if content.RemainingXPValue then
        content.RemainingXPValue:SetText(Utils.ShortNumber(remainingXP))
    end
    
    -- Update rested XP
    if content.RestedXPValue then
        if restedXP > 0 then
            content.RestedXPValue:SetText(Utils.ShortNumber(restedXP))
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
                Utils.ShortNumber(totalQuestXP), questPercent))
        else
            content.QuestXPValue:SetText("None")
        end
    end
    
    -- Update time on this level
    if content.LevelTimeValue then
        if levelTime > 0 then
            content.LevelTimeValue:SetText(Utils.FormatDuration(levelTime))
        else
            content.LevelTimeValue:SetText("N/A")
        end
    end
    
    -- Update time to next level
    if content.TimeToLevelValue then
        if timeToLevel and timeToLevel > 0 then
            content.TimeToLevelValue:SetText(Utils.FormatDuration(timeToLevel))
        else
            content.TimeToLevelValue:SetText("N/A")
        end
    end
end

-- Update right page with session statistics
function View:UpdateSessionStats(statsFrame)
    if not (statsFrame and statsFrame.RightPage) then return end
    
    local rightPage = statsFrame.RightPage
    local content = rightPage.Content
    if not content then return end
    
    -- Get session data
    local session = SessionService and SessionService:GetSession()
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
        content.SessionDurationValue:SetText(Utils.FormatDuration(sessionElapsed))
    end
    
    -- Update session start time
    if content.SessionStartValue then
        local startTime = date("%H:%M", session.sessionStart or time())
        content.SessionStartValue:SetText(startTime)
    end
    
    -- Update XP gained
    if content.SessionXPValue then
        content.SessionXPValue:SetText(Utils.ShortNumber(sessionXP))
    end
    
    -- Update levels gained
    if content.LevelsGainedValue then
        content.LevelsGainedValue:SetText(tostring(levelsGained))
    end
    
    -- Update XP per hour
    if content.XPPerHourValue then
        if xpPerHour > 0 then
            content.XPPerHourValue:SetText(Utils.ShortNumber(xpPerHour))
        else
            content.XPPerHourValue:SetText("Calculating...")
        end
    end
    
    -- Update total session XP (same as gained)
    if content.TotalSessionXPValue then
        content.TotalSessionXPValue:SetText(Utils.ShortNumber(sessionXP))
    end
end

function View:GetQuestXP(forceRefresh)
    local controller = self.controller
    if controller and controller.GetQuestXP then
        return controller:GetQuestXP(forceRefresh)
    end

    if Addon.App and Addon.App.Features and Addon.App.Features.xpbar and Addon.App.Features.xpbar.GetQuestXP then
        return Addon.App.Features.xpbar:GetQuestXP(forceRefresh)
    end

    if QuestXPService and QuestXPService.GetQuestXP then
        return QuestXPService:GetQuestXP(forceRefresh)
    end

    return 0, 0, 0
end

function View:OnTimePlayed()
    self:Update()
end

return View
