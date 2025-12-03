-- XP Bar Enhanced - Event Bus
-- Central event bus with a simple register/emit/unregister API

---@class XPBarContext
---@field event string The event that triggered this context
---@field timestamp number Unix timestamp when context was built
---@field source? string Source identifier for the event
---@field currentXP number Current player XP
---@field xpMax number Maximum XP for current level
---@field remainingXP? number XP remaining to next level
---@field level number Current player level
---@field restedXP number Amount of rested XP available
---@field isResting boolean Whether player is in a resting area
---@field hasRestedXP boolean Whether player has any rested XP
---@field isFullyRested boolean Whether player has max rested XP
---@field completeQuestXP? number XP from completed quests ready to turn in
---@field incompleteQuestXP? number XP from incomplete quests
---@field sessionStart? number Session start timestamp
---@field sessionXP? number Total XP gained this session
---@field levelSeconds? number Time played at current level
---@field xpGained? number XP gained in this event
---@field didLevelUp? boolean Whether player leveled up
---@field Get fun(self: XPBarContext, key: string, default?: any): any Safe getter with default value

---@alias EventHandler fun(context: XPBarContext): nil

---@class EventBus
---@field listeners table<string, table<string, EventHandler>> Registered event handlers keyed by event name and subscription id
local Addon = XPBarEnhanced
Addon.EventBus = Addon.EventBus or {}
local EventBus = Addon.EventBus

EventBus.listeners = EventBus.listeners or {}

---Register a handler for an event
---@param eventName string The event name to listen for
---@param idOrHandler string|EventHandler Subscription ID (string) or handler function
---@param handler? EventHandler Handler function (required if idOrHandler is a string)
---@return string id The subscription ID for later unregistration
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

---Unregister a handler by id or function for an event
---@param eventName string The event name to unregister from
---@param idOrHandler string|EventHandler The subscription ID or handler function to remove
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

---Emit an event to all listeners
---@param eventName string The event name to emit
---@return XPBarContext context The context object passed to all handlers
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
                ("EventBus: listener [%s] for %s failed: %s"):format(tostring(id), tostring(eventName), tostring(err))
            )
        end
    end

    return context
end

return EventBus
