local Addon = XPBarEnhanced

local Logger = {}

local function safeFormat(fmt, ...)
    if type(fmt) ~= "string" then
        return tostring(fmt)
    end
    local ok, res = pcall(string.format, fmt, ...)
    if ok then return res end
    return fmt
end

---Debug message helper
function Logger:Debug(message, ...)
    print("[XPBarEnhanced DEBUG] " .. safeFormat(message, ...))
end

---Informational message helper
function Logger:Info(message, ...)
    print("[XPBarEnhanced] " .. safeFormat(message, ...))
end

---Warn message helper
function Logger:Warn(message, ...)
    print("[XPBarEnhanced WARNING] " .. safeFormat(message, ...))
end

---Log an error and raise it via error()
function Logger:Error(message, ...)
    local errorMessage = safeFormat(message, ...)
    print("[XPBarEnhanced ERROR] " .. errorMessage)
    error(errorMessage)
end

Addon.Logger = Logger
