local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Services = Addon.App.Services or {}

local SavedVariables = Addon.App.Core and Addon.App.Core.SavedVariables
local Utils = Addon.Utils or {}
local EventBus = XPC_EventBus
local EventTypes = XPC_EventTypes

local SessionService = {}

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

function SessionService:GetSession()
    if not SavedVariables then
        return nil
    end

    local session = SavedVariables:GetSessionData()
    ensureSessionDefaults(session)
    
    return session
end

function SessionService:Initialize()
    self:GetSession()
end

function SessionService:OnEnteringWorld(isInitialLogin, isReload)
    local session = self:GetSession()
    if not session then
        return
    end

    if isInitialLogin then
        session.sessionStart = time()
        session.gainedXP = 0
        
        -- Publish SESSION_STARTED event
        if EventBus and EventTypes then
            EventBus:Publish(EventTypes.SESSION_STARTED, {
                startTime = session.sessionStart,
            })
        end
    end

    if isInitialLogin or isReload then
        session.lastXP = UnitXP("player")
        session.maxXP = UnitXPMax("player")
    end

    if Addon.db.showLevelTimeText or Addon.db.showSessionTimeText then
        local TimeService = Addon.App.Services.TimePlayedService
        if TimeService and TimeService.RequestTimePlayed then
            TimeService:RequestTimePlayed()
        end
    end
end

function SessionService:OnXPUpdate()
    local session = self:GetSession()
    if not session then 
        return 
    end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local lastXP = session.lastXP or currentXP
    local gained = currentXP - lastXP

    if gained < 0 then
        gained = (session.maxXP or maxXP) - lastXP + currentXP
    end

    if gained < 0 then
        gained = 0
    end

    session.gainedXP = (session.gainedXP or 0) + gained
    session.sessionXP = session.gainedXP
    session.lastXP = currentXP
    session.maxXP = maxXP
    session.lastUpdate = time()
    
    -- Publish SESSION_UPDATED event
    self:PublishSessionUpdate()
end

function SessionService:OnLevelUp(newLevel)
    local session = self:GetSession()
    if not session then
        return
    end
    
    session.realLevelTime = 0
    
    -- Update current level state
    session.lastXP = UnitXP("player")
    session.maxXP = UnitXPMax("player")
end

function SessionService:OnTimePlayed(totalTime, levelTime)
    local session = self:GetSession()
    if not session then
        return
    end

    session.realTotalTime = totalTime or session.realTotalTime or 0
    session.realLevelTime = levelTime or session.realLevelTime or 0
    session.lastTimePlayedRequest = time()
    Addon.state.requestingTimePlayed = false
end

function SessionService:RefreshSessionTimes()
    local session = self:GetSession()
    if not session then return end

    session.lastUpdate = time()
end

function SessionService:PublishSessionUpdate()
    if not EventBus or not EventTypes then
        return
    end
    
    local session = self:GetSession()
    if not session then
        return
    end
    
    -- Calculate session duration
    local duration = time() - (session.sessionStart or time())
    
    -- Calculate XP per hour
    local xpPerHour = 0
    if duration > 0 then
        xpPerHour = (session.gainedXP or 0) / (duration / 3600)
    end
    
    EventBus:Publish(EventTypes.SESSION_UPDATED, {
        duration = duration,
        xpGained = session.gainedXP or 0,
        levelsGained = 0,  -- TODO: Track levels gained in session
        xpPerHour = xpPerHour,
        startTime = session.sessionStart or time(),
    })
end

Addon.App.Services.SessionService = SessionService
