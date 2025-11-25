-- XP Bar Enhanced - Event Bus
-- Central event bus with a simple register/emit/unregister API

local Addon = XPBarEnhanced
Addon.EventBus = Addon.EventBus or {}
local EventBus = Addon.EventBus

EventBus.listeners = EventBus.listeners or {}

--- Register a handler for an event
-- @param eventName string
-- @param idOrHandler string|function optional id or handler
-- @param handler function optional handler if id provided
-- @return id string subscription id
function EventBus:Register(eventName, idOrHandler, handler)
    if not eventName then
        error("EventBus:Register requires an eventName")
    end
    local id
    local fn
    if type(idOrHandler) == "string" then
        id = idOrHandler
        fn = handler
    else
        fn = idOrHandler
    end
    if type(fn) ~= "function" then
        error("EventBus:Register requires a function handler")
    end
    id = id or tostring(fn)
    EventBus.listeners[eventName] = EventBus.listeners[eventName] or {}
    EventBus.listeners[eventName][id] = fn
    return id
end

--- Unregister a handler by id or function for an event
function EventBus:Unregister(eventName, idOrHandler)
    if not eventName or not EventBus.listeners[eventName] then
        return
    end
    if type(idOrHandler) == "string" then
        EventBus.listeners[eventName][idOrHandler] = nil
        return
    end
    for id, fn in pairs(EventBus.listeners[eventName]) do
        if fn == idOrHandler then
            EventBus.listeners[eventName][id] = nil
        end
    end
end

--- Emit an event to all listeners
function EventBus:Emit(eventName, payload)
    if not eventName then return end
    local listeners = EventBus.listeners[eventName]
    if not listeners then return end
    for id, fn in pairs(listeners) do
        local ok, err = pcall(fn, payload)
        if not ok and Addon.Logger and Addon.Logger.Error then
            Addon.Logger:Error("EventBus handler failed for " .. tostring(eventName) .. ": " .. tostring(err))
        end
    end
end

return EventBus
