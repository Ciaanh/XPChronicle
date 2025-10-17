local Addon = XPBarEnhanced
Addon.App = Addon.App or {}
Addon.App.Features = Addon.App.Features or {}

local controller = {}

function controller:GetView()
    return Addon.UI.Views and Addon.UI.Views.Stats
end

function controller:Initialize()
    local view = self:GetView()
    if view and view.Initialize then
        view:Initialize(self)
    end
end

function controller:Toggle()
    local view = self:GetView()
    if view and view.Toggle then
        view:Toggle()
    end
end

function controller:Update()
    local view = self:GetView()
    if view and view.Update then
        view:Update()
    end
end

function controller:OnXPUpdate()
    self:Update()
end

function controller:OnLevelUp()
    self:Update()
end

function controller:OnTimePlayed(totalTime, levelTime)
    local view = self:GetView()
    if view and view.OnTimePlayed then
        view:OnTimePlayed(totalTime, levelTime)
    end
end

Addon:RegisterFeature("stats", controller)
Addon.App.Features.stats = controller
return controller
