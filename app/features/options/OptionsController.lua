local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Features = Addon.App.Features or {}

local controller = {}

local function getView()
    return Addon.UI and Addon.UI.Views and Addon.UI.Views.Options
end

local function ensureView(self)
    local view = getView()
    if not view then
        return nil
    end

    if view.Initialize then
        view:Initialize(self)
    end

    return view
end

function controller:Initialize()
    ensureView(self)
end

function controller:Refresh()
    local view = ensureView(self)
    if view and view.Refresh then
        view:Refresh()
    end
end

function controller:UpdateColorControls()
    local view = ensureView(self)
    if view and view.UpdateColorControls then
        view:UpdateColorControls()
    end
end

function controller:OpenColorPicker(colorKey)
    local view = ensureView(self)
    if view and view.OpenColorPicker then
        view:OpenColorPicker(colorKey)
    end
end

function controller:Open()
    local view = ensureView(self)
    if view and view.Open then
        view:Open()
    end
end

function controller:OnOptionChanged(key)
    -- Handle specific option changes
    if key == "barStyle" then
        -- Update bar style via XPBarController
        local xpBarController = Addon.App.Features and Addon.App.Features.xpbar
        if xpBarController and xpBarController.SetBarStyle then
            local value = Addon.db and Addon.db.barStyle or "legacy"
            xpBarController:SetBarStyle(value, true) -- skipSave=true since it's already saved
        end
        
        -- Refresh UI to update dropdown text and visibility
        self:Refresh()
        
    elseif key == "hideBlizzardBar" then
        -- Update Blizzard bar visibility
        local BlizzardBarControl = Addon.UI and Addon.UI.BlizzardBarControl
        if BlizzardBarControl then
            local shouldHide = Addon.db and Addon.db.hideBlizzardBar
            if shouldHide then
                BlizzardBarControl:Hide()
            else
                BlizzardBarControl:Show()
            end
        end
    elseif key == "barLocked" then
        -- Update Flat bar lock state via XPBarController
        local xpBarController = Addon.App.Features and Addon.App.Features.xpbar
        if xpBarController and xpBarController.UpdateLockedState then
            xpBarController:UpdateLockedState()
        end
    elseif key == "enableAnimations" or key == "animationSpeed" or key == "animationEasing" 
        or key == "flashOnGain" or key == "pauseOnHover" then
        -- Update animation settings via XPBarController
        local xpBarController = Addon.App.Features and Addon.App.Features.xpbar
        if xpBarController and xpBarController.UpdateAnimationSettings then
            xpBarController:UpdateAnimationSettings()
        end
    elseif key == "showQuestXP" or key == "showQuestPercent" or key == "questOverlaysEnabled"
        or key == "showCompleteQuestOverlay" or key == "showIncompleteQuestOverlay" then
        -- Update quest-related display (overlays and text)
        local xpBarController = Addon.App.Features and Addon.App.Features.xpbar
        if xpBarController then
            if xpBarController.UpdateQuestOverlays then
                xpBarController:UpdateQuestOverlays()
            end
            if xpBarController.UpdateTextDisplay then
                xpBarController:UpdateTextDisplay()
            end
        end
    end
    
    -- General refresh
    self:Refresh()
    if Addon.XPBar and Addon.XPBar.Update then
        Addon.XPBar:Update()
    end
end

function controller:OnColorReset()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.XPBar and Addon.XPBar.Update then
        Addon.XPBar:Update()
    end
end

function controller:OnColorChanged()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.XPBar and Addon.XPBar.Update then
        Addon.XPBar:Update()
    end
end

function controller:OnColorCancel()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.XPBar and Addon.XPBar.Update then
        Addon.XPBar:Update()
    end
end

Addon:RegisterFeature("options", controller)
Addon.App.Features.options = controller

return controller
