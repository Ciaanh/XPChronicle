local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}

local PositionStoreMixin = {}

local function resolveDefaults(defaults)
    if type(defaults) == "function" then
        return defaults()
    end
    return defaults
end

function PositionStoreMixin:InitPositionStorage(getter, setter, defaultsProvider)
    self._xpcPositionGetter = getter
    self._xpcPositionSetter = setter
    self._xpcPositionDefaults = defaultsProvider
end

function PositionStoreMixin:GetOrCreatePositionStore()
    if not self._xpcPositionGetter then
        return nil
    end

    local store = self._xpcPositionGetter()
    if not store and self._xpcPositionSetter then
        store = {}
        self._xpcPositionSetter(store)
    end

    return store
end

function PositionStoreMixin:GetPositionDefaults()
    return resolveDefaults(self._xpcPositionDefaults) or {}
end

function PositionStoreMixin:ApplyStoredPosition()
    local store = self:GetOrCreatePositionStore() or {}
    local defaults = self:GetPositionDefaults()

    local point = store.point or defaults.point or "CENTER"
    local relativeName = store.relativeTo or defaults.relativeTo or "UIParent"
    local relativePoint = store.relativePoint or defaults.relativePoint or point
    local x = store.x or defaults.x or 0
    local y = store.y or defaults.y or 0

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

    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    store.point = point
    store.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
    store.relativePoint = relativePoint
    store.x = x
    store.y = y

    if type(self.OnStoredPositionSaved) == "function" then
        self:OnStoredPositionSaved(store)
    end
end

-- Export mixin to Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.PositionStoreMixin = PositionStoreMixin
_G.PositionStoreMixin = PositionStoreMixin
