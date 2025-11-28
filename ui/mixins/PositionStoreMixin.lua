local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

local PositionStoreMixin = {}
Addon.UI.Mixins.PositionStoreMixin = PositionStoreMixin

-- Initialize accessor callbacks to store/retrieve position data
function PositionStoreMixin:InitPositionStorage(getter, setter, defaultsProvider)
    self._positionStoreGetter = getter
    self._positionStoreSetter = setter
    self._positionStoreDefaultsProvider = defaultsProvider
end

function PositionStoreMixin:GetOrCreatePositionStore()
    if not self.__posStore then
        local getter = self._positionStoreGetter
        if getter then
            self.__posStore = getter() or {}
        else
            self.__posStore = {}
        end
    end
    return self.__posStore
end

function PositionStoreMixin:GetPositionDefaults()
    if self._positionStoreDefaultsProvider then
        return self._positionStoreDefaultsProvider(self)
    end
    -- Provide canonical general default that works for both formats
    return {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0, left = 0, top = 0}
end

function PositionStoreMixin:ApplyStoredPosition()
    local stored = self:GetOrCreatePositionStore() or {}
    local defaults = self:GetPositionDefaults() or {}

    -- Backwards compatibility: support legacy left/top stored positions
    if stored.left ~= nil and stored.top ~= nil then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", stored.left, stored.top)
        return
    end

    -- Preferred generic position format (point/relativeTo/relativePoint/x/y)
    local point = stored.point or defaults.point or "CENTER"
    local relativeName = stored.relativeTo or defaults.relativeTo or "UIParent"
    local relativePoint = stored.relativePoint or defaults.relativePoint or point
    local x = stored.x or defaults.x or 0
    local y = stored.y or defaults.y or 0

    local relative = _G[relativeName]
    if not relative or type(relative) ~= "table" then
        relative = UIParent
    end

    self:ClearAllPoints()
    self:SetPoint(point, relative, relativePoint, x, y)
end

function PositionStoreMixin:SaveStoredPosition()
    local store = self:GetOrCreatePositionStore()
    if not store then
        return
    end

    -- Try to capture anchor points in both canonical formats so both code paths can read it.
    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    local left = self.GetLeft and self:GetLeft() or nil
    local top = self.GetTop and self:GetTop() or nil

    if not point then
        -- No point available; fallback to left/top if present
        if left == nil or top == nil then
            return
        end
    end

    local defaults = self:GetPositionDefaults() or {}

    -- Normalize store values
    local toSave = {}
    if left ~= nil and top ~= nil then
        toSave.left = left
        toSave.top = top
    end
    if point then
        toSave.point = point
        toSave.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
        toSave.relativePoint = relativePoint
        toSave.x = x
        toSave.y = y
    end

    -- If all values equal to defaults, clear storage
    if toSave.left ~= nil and toSave.left == defaults.left and toSave.top == defaults.top then
        if self._positionStoreSetter then
            self._positionStoreSetter(nil)
        end
        self.__posStore = nil
        return
    end
    if toSave.point and defaults.point and toSave.point == defaults.point and toSave.x == defaults.x and toSave.y == defaults.y then
        if self._positionStoreSetter then
            self._positionStoreSetter(nil)
        end
        self.__posStore = nil
        return
    end

    if self._positionStoreSetter then
        self._positionStoreSetter(toSave)
    end
    self.__posStore = toSave
end

Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.PositionStoreMixin = PositionStoreMixin
_G.PositionStoreMixin = PositionStoreMixin

return PositionStoreMixin
