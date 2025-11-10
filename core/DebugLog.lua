-- XP Bar Enhanced - Debug Logging System
-- Captures detailed initialization workflow for debugging

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced or {}
XPBarEnhanced = Addon

-----------------------------------
-- Debug Log Storage
-----------------------------------
local DebugLog = {
    logs = {},
    enabled = true,
    maxLogs = 500
}

Addon.DebugLog = DebugLog

--- Add a log entry
-- @param category string: Log category (e.g., "CircularBar", "BaseMixin", "Animation")
-- @param message string: Log message
-- @param data table: Optional additional data
function DebugLog:Add(category, message, data)
    if not self.enabled then
        return
    end
    
    local entry = {
        timestamp = GetTime(),
        category = category,
        message = message,
        data = data,
        stackTrace = debugstack(3, 2, 2) -- 2 levels of stack, starting from caller
    }
    
    table.insert(self.logs, entry)
    
    -- Trim old logs if exceeding max
    if #self.logs > self.maxLogs then
        table.remove(self.logs, 1)
    end
    
    -- Also print to chat for immediate visibility
    print(string.format("[%s] %s", category, message))
end

--- Clear all logs
function DebugLog:Clear()
    self.logs = {}
    print("Debug logs cleared")
end

--- Dump all logs
function DebugLog:Dump()
    if #self.logs == 0 then
        print("No debug logs to dump")
        return
    end
    local output = {}
    table.insert(output, "========================================")
    table.insert(output, string.format("DEBUG LOG DUMP (%d entries)", #self.logs))
    table.insert(output, "========================================")

    for i, entry in ipairs(self.logs) do
        table.insert(output, string.format("[%d] T+%.3fs [%s] %s", 
            i, 
            entry.timestamp, 
            entry.category, 
            entry.message))

        if entry.data then
            for key, value in pairs(entry.data) do
                table.insert(output, string.format("    %s = %s", key, tostring(value)))
            end
        end

        if entry.stackTrace and entry.stackTrace ~= "" then
            table.insert(output, string.format("    Stack: %s", entry.stackTrace))
        end
    end

    table.insert(output, "========================================")
    table.insert(output, "END DEBUG LOG")
    table.insert(output, "========================================")

    local fullOutput = table.concat(output, "\n")
    -- Raise an error so the full log appears in the error frame for easy copy/paste
    error(fullOutput)
end

--- Dump logs to UIParent error frame (expandable)
function DebugLog:DumpToError()
    if #self.logs == 0 then
        print("No debug logs to dump")
        return
    end
    
    local output = {}
    table.insert(output, "========================================")
    table.insert(output, string.format("DEBUG LOG DUMP (%d entries)", #self.logs))
    table.insert(output, "========================================")
    
    for i, entry in ipairs(self.logs) do
        table.insert(output, string.format("[%d] T+%.3fs [%s] %s", 
            i, 
            entry.timestamp, 
            entry.category, 
            entry.message))
        
        if entry.data then
            for key, value in pairs(entry.data) do
                table.insert(output, string.format("    %s = %s", key, tostring(value)))
            end
        end
        
        if entry.stackTrace and entry.stackTrace ~= "" then
            table.insert(output, string.format("    Stack: %s", entry.stackTrace))
        end
    end
    
    table.insert(output, "========================================")
    
    -- Trigger error to show in UI
    local fullOutput = table.concat(output, "\n")
    
    -- Use UIErrorsFrame to show in yellow text (more visible)
    UIErrorsFrame:AddMessage(string.format("Debug log dumped (%d entries) - check chat", #self.logs), 1.0, 1.0, 0.0, 1.0)
    
    -- Print to chat as well
    for _, line in ipairs(output) do
        print(line)
    end
end

--- Enable/disable debug logging
function DebugLog:SetEnabled(enabled)
    self.enabled = enabled
    print(string.format("Debug logging %s", enabled and "enabled" or "disabled"))
end

-----------------------------------
-- Slash Commands
-----------------------------------

SLASH_XPBARDEBUG1 = "/xpdebug"
SlashCmdList["XPBARDEBUG"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "dump" or msg == "" then
        -- Use Dump() which aggregates logs into a single string and raises an error
        -- so the full output appears in the UI error frame for easy copy/paste
        DebugLog:Dump()
    elseif msg == "clear" then
        DebugLog:Clear()
    elseif msg == "on" then
        DebugLog:SetEnabled(true)
    elseif msg == "off" then
        DebugLog:SetEnabled(false)
    else
        print("XP Bar Debug Commands:")
        print("  /xpdebug dump  - Dump all logs to chat")
        print("  /xpdebug clear - Clear all logs")
        print("  /xpdebug on    - Enable debug logging")
        print("  /xpdebug off   - Disable debug logging")
    end
end

print("XPBarEnhanced: Debug logging system loaded. Use /xpdebug dump to view logs.")
