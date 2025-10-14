local Addon = XPChronicle
Addon.Utils = Addon.Utils or {}
Addon.App.Core = Addon.App.Core or {}

local Utils = Addon.Utils

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

function Utils.Clone(value)
    return cloneTable(value)
end

function Utils.MergeDefaults(target, source)
    mergeDefaults(target, source)
end

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

function Utils.FormatDuration(seconds)
    if not seconds or seconds <= 0 then
        return "--"
    end

    local minutes = math.floor(seconds / 60)
    if minutes < 1 then
        return "<1m"
    end

    local days = math.floor(minutes / 1440)
    minutes = minutes % 1440
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    local parts = {}
    if days > 0 then
        table.insert(parts, string.format("%dd", days))
    end
    if hours > 0 then
        table.insert(parts, string.format("%dh", hours))
    end
    if minutes > 0 then
        table.insert(parts, string.format("%dm", minutes))
    end

    return table.concat(parts, " ")
end

function Utils.FormatTime(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return "--"
    end

    seconds = math.floor(seconds + 0.5)

    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%dm %ds", mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, mins)
    end
end

function Utils.Print(message, ...)
    if not message then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    print("|cFF00FF00XP Chronicle:|r " .. message)
end

Addon.App.Core.Utils = {
    CloneTable = cloneTable,
    MergeDefaults = mergeDefaults,
}
