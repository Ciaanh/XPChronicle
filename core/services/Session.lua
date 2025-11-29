-- XP Bar Enhanced - Session.lua
-- Manages player session data such as XP gained and time played

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

---Return the currently active session table, or nil if DB unavailable
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
    -- Set up event listeners to keep session state updated
    self:SetupEventFrame()
end

-- Initialize event frame for session-relevant events
function Session:SetupEventFrame()
    if self.eventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_XP_UPDATE")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("TIME_PLAYED_MSG")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("QUEST_LOG_UPDATE")

    frame:SetScript(
        "OnEvent",
        function(_, event, ...)
            if event == "PLAYER_XP_UPDATE" then
                Session:OnXPUpdate()
            elseif event == "PLAYER_LEVEL_UP" then
                local level = ...
                Session:OnLevelUp(level)
            elseif event == "TIME_PLAYED_MSG" then
                local totalTime, levelTime = ...
                Session:OnTimePlayed(totalTime, levelTime)
            elseif event == "QUEST_TURNED_IN" then
                local questID = ...
                Session:OnQuestTurnedIn(questID)
            elseif event == "QUEST_LOG_UPDATE" then
                -- keep lastXP/maxXP/current cache fresh just in case
                Session:RefreshSessionTimes()
            end
        end
    )

    self.eventFrame = frame
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

-- Ensure completed-quest cache and session XP are refreshed after a quest is turned in.
-- Delay slightly to allow the server/game to update the quest/completion state.
function Session:OnQuestTurnedIn(questID)
    if not questID then
        return
    end

    local function RefreshCompletedQuests()
        -- Touch the API to ensure it's updated
        local completed = false
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            completed = C_QuestLog.IsQuestFlaggedCompleted(questID) or false
        end

        -- If the addon maintains a database/quest cache, try to update it.
        -- Use existence checks to remain non-invasive if those APIs don't exist.
        if Addon.Database and Addon.Database.UpdateQuestCompletion then
            pcall(Addon.Database.UpdateQuestCompletion, Addon.Database, questID, completed)
        elseif Addon.Database and Addon.Database.MarkQuestCompleted then
            pcall(Addon.Database.MarkQuestCompleted, Addon.Database, questID, completed)
        end

        -- Ensure session XP baseline is up-to-date (XP gains from quest may have triggered PLAYER_XP_UPDATE
        -- before the completed flag became available).
        Session:OnXPUpdate()

        -- Touch session timestamps so UI/data consumers will refresh.
        local session = Session:GetCurrent()
        if session then
            session.lastUpdate = time()
        end
    end

    RefreshCompletedQuests()

    -- Small delay: the quest history/completed flag may not be instantly available.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, RefreshCompletedQuests)
        C_Timer.After(0.1, RefreshCompletedQuests)
    end
end

function Session:RefreshSessionTimes()
    local session = self:GetCurrent()
    if not session then
        return
    end

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
        timePlayedTicker =
            C_Timer.NewTimer(
            0.5,
            function()
                RequestTimePlayed()
            end
        )
    else
        RequestTimePlayed()
    end
end

-------------------------------------------------------------------
-- SESSION STATS (for backward compatibility)
-------------------------------------------------------------------
-- TIME TO LEVEL HELPER
-------------------------------------------------------------------

---Compute time to level based on session XP rate and remaining XP
function Session:GetTimeToLevel()
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")

    if not maxXP or maxXP <= 0 then
        return 0
    end

    -- Use centralized XP/hour calculation
    local xpPerHour = 0
    if self and self.GetXPPerHour then
        xpPerHour = self:GetXPPerHour() or 0
    end

    local remainingXP = (maxXP or 0) - (currentXP or 0)
    if xpPerHour > 0 and remainingXP > 0 then
        return math.floor((remainingXP / xpPerHour) * 3600)
    end

    return 0
end

---Return XP per hour based on session or level-time fallback
function Session:GetXPPerHour()
    local session = self:GetCurrent()
    if not session then
        return 0
    end

    local duration = time() - (session.sessionStart or time())
    local gainedXP = session.gainedXP or 0

    -- Prefer session-derived rate when session is meaningful
    if duration >= 10 and gainedXP > 0 then
        return math.floor((gainedXP / duration) * 3600)
    end

    -- Fallback: estimate from realLevelTime if available
    if session.realLevelTime and session.realLevelTime > 0 then
        local levelTime = session.realLevelTime
        if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
            local elapsed = time() - session.lastTimePlayedRequest
            levelTime = levelTime + elapsed
        end
        local currentXP = UnitXP("player") or 0
        if levelTime > 0 and currentXP > 0 then
            return math.floor((currentXP / levelTime) * 3600)
        end
    end

    return 0
end
-------------------------------------------------------------------

---Return a normalized stats table for the current session
function Session:GetStats()
    local session = self:GetCurrent()
    if not session then
        return {
            duration = 0,
            xpGained = 0,
            xpPerHour = 0,
            startTime = time()
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
        realLevelTime = session.realLevelTime or 0
    }
end

-------------------------------------------------------------------
-- BACKWARD COMPATIBILITY
-------------------------------------------------------------------

return Session
