-- XP Bar Enhanced - Session.lua
-- Simplified session tracking (Phase 2)
-- Consolidates: SessionService.lua + TimePlayedService.lua

local Addon = XPBarEnhanced
Addon.Session = Addon.Session or {}

local Session = Addon.Session
local timePlayedTicker

-------------------------------------------------------------------
-- SESSION HELPERS
-------------------------------------------------------------------

local function ensureSessionDefaults(session)
    session.sessionStart = session.sessionStart or time()
    session.sessionXP = session.sessionXP or 0
    session.gainedXP = session.gainedXP or 0
    session.lastXP = session.lastXP or UnitXP("player")
    session.maxXP = session.maxXP or UnitXPMax("player")
    session.realTotalTime = session.realTotalTime or 0
    session.realLevelTime = session.realLevelTime or 0
    session.lastTimePlayedRequest = session.lastTimePlayedRequest or 0
    session.lastUpdate = session.lastUpdate or time()
end

-------------------------------------------------------------------
-- SESSION MANAGEMENT
-------------------------------------------------------------------

function Session:GetCurrent()
    local Database = Addon.Database
    if not Database then
        return nil
    end
    
    local session = Database:GetSessionData()
    ensureSessionDefaults(session)
    
    return session
end

function Session:Initialize()
    self:GetCurrent()
end

function Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self:GetCurrent()
    if not session then
        return
    end
    
    if isInitialLogin then
        session.sessionStart = time()
        session.gainedXP = 0
    end
    
    if isInitialLogin or isReloadingUI then
        session.lastXP = UnitXP("player")
        session.maxXP = UnitXPMax("player")
    end
    
    -- Request time played if time text options are enabled
    if Addon.db.showLevelTimeText or Addon.db.showSessionTimeText then
        self:RequestTimePlayed()
    end
end

function Session:OnXPUpdate()
    local session = self:GetCurrent()
    if not session then
        return
    end
    
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local lastXP = session.lastXP or currentXP
    local gained = currentXP - lastXP
    
    -- Handle level-up case (XP resets to 0)
    if gained < 0 then
        gained = (session.maxXP or maxXP) - lastXP + currentXP
    end
    
    -- Ensure non-negative gain
    if gained < 0 then
        gained = 0
    end
    
    -- Update session
    session.gainedXP = (session.gainedXP or 0) + gained
    session.sessionXP = session.gainedXP
    session.lastXP = currentXP
    session.maxXP = maxXP
    session.lastUpdate = time()
    
    -- Notify StatsView
    self:NotifySessionUpdated()
end

function Session:OnLevelUp(newLevel)
    local session = self:GetCurrent()
    if not session then
        return
    end
    
    -- Reset level time
    session.realLevelTime = 0
    
    -- Update current level state
    session.lastXP = UnitXP("player")
    session.maxXP = UnitXPMax("player")
end

function Session:OnTimePlayed(totalTime, levelTime)
    local session = self:GetCurrent()
    if not session then
        return
    end
    
    session.realTotalTime = totalTime or session.realTotalTime or 0
    session.realLevelTime = levelTime or session.realLevelTime or 0
    session.lastTimePlayedRequest = time()
    Addon.state.requestingTimePlayed = false
    
    -- Clear the ticker
    self:ClearTimePlayedRequest()
end

function Session:RefreshSessionTimes()
    local session = self:GetCurrent()
    if not session then return end
    
    session.lastUpdate = time()
end

-------------------------------------------------------------------
-- TIME PLAYED MANAGEMENT
-------------------------------------------------------------------

function Session:ClearTimePlayedRequest()
    if timePlayedTicker then
        timePlayedTicker:Cancel()
        timePlayedTicker = nil
    end
    Addon.state.requestingTimePlayed = false
end

function Session:RequestTimePlayed()
    if Addon.state.requestingTimePlayed then
        return
    end
    
    self:ClearTimePlayedRequest()
    Addon.state.requestingTimePlayed = true
    
    -- Use timer to avoid instant spam
    if C_Timer and C_Timer.NewTimer then
        timePlayedTicker = C_Timer.NewTimer(0.5, function()
            RequestTimePlayed()
        end)
    else
        RequestTimePlayed()
    end
end

-------------------------------------------------------------------
-- SESSION STATS (for backward compatibility)
-------------------------------------------------------------------

function Session:GetStats()
    local session = self:GetCurrent()
    if not session then
        return {
            duration = 0,
            xpGained = 0,
            xpPerHour = 0,
            startTime = time(),
        }
    end
    
    -- Calculate session duration
    local duration = time() - (session.sessionStart or time())
    
    -- Calculate XP per hour
    local xpPerHour = 0
    if duration > 0 then
        xpPerHour = (session.gainedXP or 0) / (duration / 3600)
    end
    
    return {
        duration = duration,
        xpGained = session.gainedXP or 0,
        xpPerHour = xpPerHour,
        startTime = session.sessionStart or time(),
        realTotalTime = session.realTotalTime or 0,
        realLevelTime = session.realLevelTime or 0,
    }
end

-------------------------------------------------------------------
-- VIEW NOTIFICATION (replaces EventBus)
-------------------------------------------------------------------

function Session:NotifySessionUpdated()
    -- Notify StatsView directly
    local statsView = Addon.UI and Addon.UI.Views and Addon.UI.Views.Stats
    if statsView and statsView.OnSessionUpdated then
        statsView:OnSessionUpdated()
    end
end

-------------------------------------------------------------------
-- BACKWARD COMPATIBILITY
-------------------------------------------------------------------

return Session
