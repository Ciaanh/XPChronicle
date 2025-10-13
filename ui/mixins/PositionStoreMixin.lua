local Addon = XPChronicle
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

local UIComponents = Addon.UI.Components or {}
local FrameUtils = UIComponents.FrameUtils

local MixinTable = {}
Addon.UI.Mixins.PositionStoreMixin = MixinTable

local function resolveDefaults(defaults)
    if type(defaults) == "function" then
        return defaults()
    end
    return defaults
end

function MixinTable:InitPositionStorage(getter, setter, defaultsProvider)
    self._xpcPositionGetter = getter
    self._xpcPositionSetter = setter
    self._xpcPositionDefaults = defaultsProvider
end

function MixinTable:GetOrCreatePositionStore()
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

function MixinTable:GetPositionDefaults()
    return resolveDefaults(self._xpcPositionDefaults) or {}
end

function MixinTable:ApplyStoredPosition()
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

function MixinTable:SaveStoredPosition()
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

return MixinTable
