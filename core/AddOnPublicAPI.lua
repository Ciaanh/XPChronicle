-- AddOnPublicAPI.lua
-- Public API surface extracted from XPBarEnhanced.lua

local Addon = XPBarEnhanced

---Register a feature module with a short name
function Addon:RegisterFeature(name, feature)
    if not name or type(feature) ~= "table" then
        return
    end
    self.Features[name] = feature
end

---Return a previously registered feature by name
function Addon:GetFeature(name)
    return self.Features[name]
end

---Return whether a feature with the provided name is registered
function Addon:HasFeature(name)
    return self.Features[name] ~= nil
end

function Addon:ClearTimePlayedTicker()
    if self.Session and self.Session.ClearTimePlayedRequest then
        self.Session:ClearTimePlayedRequest()
    end
end

function Addon:RequestTimePlayed()
    if self.Session and self.Session.RequestTimePlayed then
        self.Session:RequestTimePlayed()
    end
end

return true
