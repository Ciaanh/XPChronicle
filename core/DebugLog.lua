-- XP Bar Enhanced - Debug Log Buffer
-- Captures debug logs for troubleshooting and dumps via chat command

-------------------------------------------------------------------
-- DEBUG LOG BUFFER
-------------------------------------------------------------------

local DebugLog = {}
local Addon = XPBarEnhanced

-- Configuration
local MAX_LOG_ENTRIES = 500  -- Maximum log entries to keep in memory
local LOG_ENABLED = true     -- Master switch for debug logging

-- Log buffer (circular buffer)
local logBuffer = {}
local logIndex = 1
local logCount = 0

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

--- Add a log entry to the buffer
-- @param category string: Log category (e.g., "BaseMixin", "CircularBar", "Animation")
-- @param message string: Log message
-- @param ... any: Additional values to log
function DebugLog:Log(category, message, ...)
    if not LOG_ENABLED then
        return
    end

    local timestamp = GetTime()
    local args = {...}
    local argsStr = ""
    
    -- Convert additional arguments to string
    if #args > 0 then
        local parts = {}
        for i, v in ipairs(args) do
            if type(v) == "table" then
                table.insert(parts, "{table}")
            elseif type(v) == "boolean" then
                table.insert(parts, tostring(v))
            elseif v == nil then
                table.insert(parts, "nil")
            else
                table.insert(parts, tostring(v))
            end
        end
        argsStr = " " .. table.concat(parts, ", ")
    end
    
    -- Create log entry
    local entry = string.format("[%.3f] [%s] %s%s", timestamp, category, message, argsStr)
    
    -- Add to circular buffer
    logBuffer[logIndex] = entry
    logIndex = (logIndex % MAX_LOG_ENTRIES) + 1
    logCount = math.min(logCount + 1, MAX_LOG_ENTRIES)
    
    -- Also print to console for immediate visibility
    print(entry)
end

--- Get all log entries in chronological order
-- @return table: Array of log entry strings
function DebugLog:GetLogs()
    local logs = {}
    
    if logCount < MAX_LOG_ENTRIES then
        -- Buffer not full yet, read from start
        for i = 1, logCount do
            table.insert(logs, logBuffer[i])
        end
    else
        -- Buffer full, read from current index (oldest entry) to end
        for i = logIndex, MAX_LOG_ENTRIES do
            table.insert(logs, logBuffer[i])
        end
        -- Then read from start to current index - 1
        for i = 1, logIndex - 1 do
            table.insert(logs, logBuffer[i])
        end
    end
    
    return logs
end

--- Clear all log entries
function DebugLog:Clear()
    logBuffer = {}
    logIndex = 1
    logCount = 0
    print("Debug log buffer cleared")
end

--- Dump all logs to chat or raise as error
-- @param asError boolean: If true, raise a Lua error with the dump string (useful for copy-paste)
function DebugLog:Dump(asError)
    local logs = self:GetLogs()

    if #logs == 0 then
        print("Debug log buffer is empty")
        return
    end

    if asError then
        -- Concatenate logs into a single string and raise as error for easy copy-paste
        local MAX_ERROR_CHARS = 65536 -- 64KB cap to avoid huge errors
        local parts = {}
        for i, entry in ipairs(logs) do
            table.insert(parts, entry)
        end
        local dumpStr = table.concat(parts, "\n")
        if #dumpStr > MAX_ERROR_CHARS then
            dumpStr = string.sub(dumpStr, 1, MAX_ERROR_CHARS) .. "\n... (truncated)"
        end
        error(dumpStr)
    else
        print(string.format("=== Debug Log Dump (%d entries) ===", #logs))
        for i, entry in ipairs(logs) do
            print(entry)
        end
        print("=== End Debug Log ===")
    end
end

--- Get recent logs (last N entries)
-- @param count number: Number of recent entries to retrieve (default 20)
-- @return table: Array of log entry strings
function DebugLog:GetRecent(count)
    count = count or 20
    local logs = self:GetLogs()
    local startIdx = math.max(1, #logs - count + 1)
    local recent = {}
    
    for i = startIdx, #logs do
        table.insert(recent, logs[i])
    end
    
    return recent
end

--- Dump recent logs to chat or raise as error
-- @param count number: Number of recent entries to dump (default 20)
-- @param asError boolean: If true, raise a Lua error with the recent logs
function DebugLog:DumpRecent(count, asError)
    count = count or 20
    local recent = self:GetRecent(count)
    
    if #recent == 0 then
        print("Debug log buffer is empty")
        return
    end

    if asError then
        local MAX_ERROR_CHARS = 65536
        local dumpStr = table.concat(recent, "\n")
        if #dumpStr > MAX_ERROR_CHARS then
            dumpStr = string.sub(dumpStr, 1, MAX_ERROR_CHARS) .. "\n... (truncated)"
        end
        error(dumpStr)
    else
        print(string.format("=== Recent Debug Logs (last %d of %d entries) ===", #recent, logCount))
        for i, entry in ipairs(recent) do
            print(entry)
        end
        print("=== End Recent Logs ===")
    end
end

--- Enable debug logging
function DebugLog:Enable()
    LOG_ENABLED = true
    print("Debug logging enabled")
end

--- Disable debug logging
function DebugLog:Disable()
    LOG_ENABLED = false
    print("Debug logging disabled")
end

--- Check if debug logging is enabled
-- @return boolean: True if logging is enabled
function DebugLog:IsEnabled()
    return LOG_ENABLED
end

--- Get buffer stats
-- @return table: Stats { count, capacity, enabled }
function DebugLog:GetStats()
    return {
        count = logCount,
        capacity = MAX_LOG_ENTRIES,
        enabled = LOG_ENABLED,
        memoryUsage = string.format("~%.1f KB", (logCount * 100) / 1024) -- Rough estimate
    }
end

-------------------------------------------------------------------
-- CHAT COMMANDS
-------------------------------------------------------------------

local function RegisterChatCommands()
    -- Register slash commands
    SLASH_XPBARDEBUG1 = "/xpbdebug"
    SLASH_XPBARDEBUG2 = "/xpbd"
    
    SlashCmdList["XPBARDEBUG"] = function(msg)
        local cmd, arg = strsplit(" ", msg, 2)
        cmd = tostring(cmd or "")
        arg = tostring(arg or "")

        -- Support exclamation suffix (e.g., dump!) and 'error' arg (e.g., dump error)
        local cmdExclaim = false
        if string.sub(cmd, -1) == "!" then
            cmdExclaim = true
            cmd = string.sub(cmd, 1, -2)
        end

        cmd = string.lower(cmd)
        arg = string.lower(arg)

        local asError = false
        if cmdExclaim or arg == "error" or arg == "dump" and string.find(msg, "!$") then
            asError = true
        end

        if cmd == "dump" then
            DebugLog:Dump(asError)
        elseif cmd == "recent" then
            local count = tonumber(arg) or 20
            DebugLog:DumpRecent(count, asError)
        elseif cmd == "clear" then
            DebugLog:Clear()
        elseif cmd == "enable" then
            DebugLog:Enable()
        elseif cmd == "disable" then
            DebugLog:Disable()
        elseif cmd == "stats" then
            local stats = DebugLog:GetStats()
            print("=== Debug Log Stats ===")
            print(string.format("Entries: %d / %d", stats.count, stats.capacity))
            print(string.format("Memory: %s", stats.memoryUsage))
            print(string.format("Enabled: %s", stats.enabled and "Yes" or "No"))
        elseif cmd == "help" or cmd == "" then
            print("=== XPBar Debug Commands ===")
            print("/xpbdebug dump - Dump all logs")
            print("/xpbdebug recent [N] - Dump last N logs (default 20)")
            print("/xpbdebug clear - Clear log buffer")
            print("/xpbdebug enable - Enable debug logging")
            print("/xpbdebug disable - Disable debug logging")
            print("/xpbdebug stats - Show buffer statistics")
        else
            print("Unknown command. Use /xpbdebug help for usage.")
        end
    end
    
    print("XPBar Debug commands registered: /xpbdebug or /xpbd")
end

-- Register commands on addon load
if Addon then
    Addon.DebugLog = DebugLog
    
    -- Register commands after PLAYER_LOGIN
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            RegisterChatCommands()
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

XPBarDebugLog = DebugLog
return DebugLog
