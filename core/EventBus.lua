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
function EventBus:Emit(eventName)
    -- Build a fresh immutable context
    local context = nil
    if XPBarContextBuilder and XPBarContextBuilder.BuildContext then
        -- use eventName to let the builder set a reason; fall back to generic
        local reason = eventName or "BROADCAST_UPDATE"
        context = XPBarContextBuilder.BuildContext(reason)
    end

    if context == nil then
        error("EventBus:Emit requires a valid context")
    end

    -- Dispatch to listeners (use defensive pcall so a failing listener won't break others)
    local listenersForEvent = self.listeners and self.listeners[eventName]
    if not listenersForEvent then
        return context
    end

    for id, handler in pairs(listenersForEvent) do
        local ok, err = pcall(handler, context)
        if not ok then
            -- Keep a small error log but avoid throwing here

                print(
                    ("EventBus: listener [%s] for %s failed: %s"):format(
                        tostring(id),
                        tostring(eventName),
                        tostring(err)
                    )
                )
        end
    end

    return context
end

return EventBus
