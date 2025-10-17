local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Components = Addon.UI.Components or {}

local UI = {}
Addon.UI.Components.FrameUtils = UI

local _G = _G

local DEFAULT_STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local modifierChecks = {
    SHIFT = function()
        return IsShiftKeyDown and IsShiftKeyDown()
    end,
    CTRL = function()
        return IsControlKeyDown and IsControlKeyDown()
    end,
    ALT = function()
        return IsAltKeyDown and IsAltKeyDown()
    end,
}

local function isModifierRequirementMet(requirement)
    if not requirement then
        return true
    end

    if type(requirement) == "table" then
        for _, modifier in ipairs(requirement) do
            local check = modifierChecks[string.upper(modifier)]
            if not (check and check()) then
                return false
            end
        end
        return true
    end

    local check = modifierChecks[string.upper(requirement)]
    return check and check()
end

function UI.EnableDrag(frame, options)
    options = options or {}
    local button = options.button or "LeftButton"

    frame:SetMovable(true)
    frame:EnableMouse(true)

    if type(button) == "table" then
        frame:RegisterForDrag(unpack(button))
    else
        frame:RegisterForDrag(button)
    end

    frame:SetScript("OnDragStart", function(self)
        if options.requireModifier and not isModifierRequirementMet(options.requireModifier) then
            self:StopMovingOrSizing()
            if options.onModifierFail then
                options.onModifierFail(self)
            end
            return
        end

        self.isDragging = true
        if options.onDragStart then
            options.onDragStart(self)
        end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        if not self.isDragging then
            return
        end

        self:StopMovingOrSizing()
        self.isDragging = nil
        if options.onDragStop then
            options.onDragStop(self)
        end
    end)
end

return UI
