---@class EventBus
---Event Bus - Central event routing system for decoupled component communication
local XPC_EventBus = {}

-- Event subscriptions: { [eventType] = { [subscriberId] = callback } }
local subscriptions = {}

-- Event queue for batching
local eventQueue = {}
local isProcessing = false

---Register a callback for an event type
---@param eventType string The event to listen for (e.g., "XP_CHANGED")
---@param subscriberId string Unique ID for the subscriber (e.g., "XPBarMixin")
---@param callback function Function to call when event fires: callback(eventData)
---@return function unsubscribe Function to call to unsubscribe from the event
function XPC_EventBus:Subscribe(eventType, subscriberId, callback)
    if not subscriptions[eventType] then
        subscriptions[eventType] = {}
    end
    
    subscriptions[eventType][subscriberId] = callback
    
    -- Return unsubscribe function
    return function()
        self:Unsubscribe(eventType, subscriberId)
    end
end

---Unregister a callback
---@param eventType string
---@param subscriberId string
function XPC_EventBus:Unsubscribe(eventType, subscriberId)
    if subscriptions[eventType] then
        subscriptions[eventType][subscriberId] = nil
    end
end

---Publish an event to all subscribers (queued for next frame)
---@param eventType string The event type (e.g., "XP_CHANGED")
---@param eventData table Data payload for the event
function XPC_EventBus:Publish(eventType, eventData)
    -- Add to queue
    table.insert(eventQueue, {
        type = eventType,
        data = eventData or {},
        timestamp = GetTime(),
    })
    
    -- Process queue on next frame
    if not isProcessing then
        C_Timer.After(0, function()
            self:ProcessQueue()
        end)
    end
end

---Publish an event immediately (skip queue)
---@param eventType string
---@param eventData table
function XPC_EventBus:PublishImmediate(eventType, eventData)
    self:DispatchEvent(eventType, eventData or {})
end

---Process all queued events
function XPC_EventBus:ProcessQueue()
    isProcessing = true
    
    -- Process all queued events
    while #eventQueue > 0 do
        local event = table.remove(eventQueue, 1)
        self:DispatchEvent(event.type, event.data)
    end
    
    isProcessing = false
end

---Dispatch an event to all subscribers
---@param eventType string
---@param eventData table
function XPC_EventBus:DispatchEvent(eventType, eventData)
    local subscribers = subscriptions[eventType]
    if not subscribers then return end
    
    -- Call all subscriber callbacks
    for subscriberId, callback in pairs(subscribers) do
        local success, err = pcall(callback, eventData)
        if not success then
            print("XPChronicle Event Error [" .. eventType .. " -> " .. subscriberId .. "]: " .. tostring(err))
        end
    end
end

---Clear all subscriptions (for testing/cleanup)
function XPC_EventBus:ClearAll()
    subscriptions = {}
    eventQueue = {}
end

---Get subscription count for debugging
---@param eventType string
---@return number
function XPC_EventBus:GetSubscriberCount(eventType)
    local subscribers = subscriptions[eventType]
    if not subscribers then return 0 end
    
    local count = 0
    for _ in pairs(subscribers) do
        count = count + 1
    end
    return count
end

---Get all event types with subscriptions (for debugging)
---@return table
function XPC_EventBus:GetAllEventTypes()
    local eventTypes = {}
    for eventType, _ in pairs(subscriptions) do
        table.insert(eventTypes, eventType)
    end
    return eventTypes
end

-- Register with addon namespace
XPChronicle = XPChronicle or {}
XPChronicle.App = XPChronicle.App or {}
XPChronicle.App.Core = XPChronicle.App.Core or {}
XPChronicle.App.Core.EventBus = XPC_EventBus
