-- XP Bar Enhanced - Utils.lua
-- General utility functions

---@class Utils
---@field Clone fun(value: any): any Deep clone a value
---@field MergeDefaults fun(target: table, source: table) Merge defaults without overwriting
---@field ShortNumber fun(value: number): string Format number as short string (1.2K, 3.4M)
---@field FormatDuration fun(seconds: number): string Format duration as compact string
---@field FormatTime fun(seconds: number): string Format time in user-friendly format

local Addon = XPBarEnhanced
Addon.Utils = Addon.Utils or {}

local Utils = Addon.Utils

---Deep clone a table recursively
---@param value any Value to clone
---@return any cloned Cloned value
local function cloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, innerValue in pairs(value) do
        copy[key] = cloneTable(innerValue)
    end
    return copy
end

---Merge source defaults into target without overwriting existing values
---@param target table Target table to merge into
---@param source table Source table with defaults
local function mergeDefaults(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = cloneTable(value)
        elseif type(value) == "table" then
            target[key] = target[key] or {}
            mergeDefaults(target[key], value)
        end
    end
end

---Deep clone a value (tables are cloned recursively)
---@param value any Value to clone
---@return any cloned Deep copy of value
function Utils.Clone(value)
    return cloneTable(value)
end

---Merge defaults from `source` into `target` without overwriting explicit values
---@param target table Target table to merge into
---@param source table Source table with defaults
function Utils.MergeDefaults(target, source)
    mergeDefaults(target, source)
end

---Return a human-friendly short representation of a number (e.g. 1.2K, 3.4M)
---@param value number The number to format
---@return string formatted Short format string
function Utils.ShortNumber(value)
    if not value or value <= 0 then
        return "0"
    end

    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    end

    return BreakUpLargeNumbers(math.floor(value + 0.5))
end

---Format a duration in seconds into compact days/hours/minutes string
---Uses centralized TimeCalculations module
---@param seconds number Duration in seconds
---@return string formatted Compact duration string (e.g. "1d 2h 30m")
function Utils.FormatDuration(seconds)
    local TimeCalc = Addon.TimeCalculations
    return TimeCalc.FormatSmart(seconds)
end

---Format seconds into a user-friendly time string (e.g. "1h 2m")
---Uses centralized TimeCalculations module
---@param seconds number Duration in seconds
---@return string formatted User-friendly time string
function Utils.FormatTime(seconds)
    local TimeCalc = Addon.TimeCalculations
    return TimeCalc.FormatHMS(seconds)
end
