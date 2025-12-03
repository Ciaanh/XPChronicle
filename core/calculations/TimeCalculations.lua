-- XP Bar Enhanced - Time Calculations
-- Shared time/rate calculation helpers used by ContextBuilder, Session, and Stats

local Addon = XPBarEnhanced
Addon.TimeCalculations = Addon.TimeCalculations or {}

---@class TimeCalculations
local TimeCalc = Addon.TimeCalculations

-------------------------------------------------------------------
-- XP RATE CALCULATIONS
-------------------------------------------------------------------

--- Calculate XP per hour based on session data
---@param sessionStart number Session start timestamp (from time())
---@param sessionXP number Total XP gained in session
---@param realLevelTime number|nil Real level time from TIME_PLAYED_MSG (optional)
---@param currentXP number|nil Current XP for level-time based calculation (optional)
---@return number xpPerHour XP gained per hour
function TimeCalc.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
    local now = time()
    local elapsed = now - (sessionStart or now)

    -- Minimum elapsed time to avoid division issues (30 seconds)
    if elapsed < 30 then
        return 0
    end

    -- If we have real level time from TIME_PLAYED_MSG and current XP, use that for accuracy
    if realLevelTime and realLevelTime > 0 and currentXP and currentXP > 0 then
        -- XP per hour based on actual time at this level
        return (currentXP / realLevelTime) * 3600
    end

    -- Fall back to session-based calculation
    if sessionXP and sessionXP > 0 then
        return (sessionXP / elapsed) * 3600
    end

    return 0
end

--- Calculate time to level at current XP rate
---@param remainingXP number XP needed to level up
---@param xpPerHour number Current XP gain rate per hour
---@return number|nil secondsToLevel Estimated seconds to level, or nil if cannot estimate
function TimeCalc.CalculateTimeToLevel(remainingXP, xpPerHour)
    if not remainingXP or remainingXP <= 0 then
        return 0
    end
    if not xpPerHour or xpPerHour <= 0 then
        return nil -- Cannot estimate
    end

    -- Convert XP/hour to seconds
    return (remainingXP / xpPerHour) * 3600
end

--- Calculate time to level using XP and time values directly
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@param xpPerHour number Current XP gain rate per hour
---@return number|nil secondsToLevel Estimated seconds to level
function TimeCalc.TimeToLevelFromXP(currentXP, xpMax, xpPerHour)
    local remaining = (xpMax or 0) - (currentXP or 0)
    return TimeCalc.CalculateTimeToLevel(remaining, xpPerHour)
end

-------------------------------------------------------------------
-- DURATION FORMATTING
-------------------------------------------------------------------

--- Format seconds into human-readable duration
---@param seconds number Duration in seconds
---@param compact boolean|nil Use compact format (1h 30m) vs verbose (1 hour 30 minutes)
---@return string formatted Formatted duration string
function TimeCalc.FormatDuration(seconds, compact)
    if not seconds or seconds < 0 then
        return compact and "0s" or "0 seconds"
    end

    seconds = math.floor(seconds)

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if compact then
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm %ds", minutes, secs)
        else
            return string.format("%ds", secs)
        end
    else
        local parts = {}
        if days > 0 then
            table.insert(parts, days .. (days == 1 and " day" or " days"))
        end
        if hours > 0 then
            table.insert(parts, hours .. (hours == 1 and " hour" or " hours"))
        end
        if minutes > 0 then
            table.insert(parts, minutes .. (minutes == 1 and " minute" or " minutes"))
        end
        if #parts == 0 or (secs > 0 and seconds < 60) then
            table.insert(parts, secs .. (secs == 1 and " second" or " seconds"))
        end
        return table.concat(parts, " ")
    end
end

--- Format duration as HH:MM:SS
---@param seconds number Duration in seconds
---@return string formatted Time in HH:MM:SS format
function TimeCalc.FormatHMS(seconds)
    if not seconds or seconds < 0 then
        return "00:00:00"
    end

    seconds = math.floor(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

--- Format duration with smart abbreviation based on magnitude
---@param seconds number Duration in seconds
---@return string formatted Smart-formatted duration
function TimeCalc.FormatSmart(seconds)
    if not seconds or seconds < 0 then
        return "0s"
    end

    seconds = math.floor(seconds)

    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        if s > 0 then
            return string.format("%dm %ds", m, s)
        else
            return string.format("%dm", m)
        end
    elseif seconds < 86400 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        if m > 0 then
            return string.format("%dh %dm", h, m)
        else
            return string.format("%dh", h)
        end
    else
        local d = math.floor(seconds / 86400)
        local h = math.floor((seconds % 86400) / 3600)
        if h > 0 then
            return string.format("%dd %dh", d, h)
        else
            return string.format("%dd", d)
        end
    end
end

-------------------------------------------------------------------
-- SESSION HELPERS
-------------------------------------------------------------------

--- Calculate session duration from start time
---@param sessionStart number Session start timestamp
---@return number duration Session duration in seconds
function TimeCalc.SessionDuration(sessionStart)
    if not sessionStart then
        return 0
    end
    return math.max(0, time() - sessionStart)
end

--- Calculate adjusted level time (realLevelTime + elapsed since last update)
---@param realLevelTime number Level time from TIME_PLAYED_MSG
---@param lastTimePlayedRequest number Timestamp of last TIME_PLAYED_MSG
---@return number adjustedTime Real-time adjusted level time
function TimeCalc.AdjustedLevelTime(realLevelTime, lastTimePlayedRequest)
    if not realLevelTime or realLevelTime <= 0 then
        return 0
    end

    local elapsed = 0
    if lastTimePlayedRequest and lastTimePlayedRequest > 0 then
        elapsed = math.max(0, time() - lastTimePlayedRequest)
    end

    return realLevelTime + elapsed
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

return TimeCalc
