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

function UI.CreateOverlayTexture(parent, layer, subLevel, color, texturePath)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)

    if type(texturePath) == "table" then
        if texturePath.atlas then
            local ok = tex:SetAtlas(texturePath.atlas, texturePath.useAtlasSize ~= false)
            if not ok then
                tex:SetTexture(texturePath.texture or DEFAULT_STATUSBAR_TEXTURE)
            end
        elseif texturePath.texture then
            tex:SetTexture(texturePath.texture)
        else
            tex:SetTexture(DEFAULT_STATUSBAR_TEXTURE)
        end
    elseif type(texturePath) == "string" and texturePath ~= "" then
        tex:SetTexture(texturePath)
    else
        tex:SetTexture(DEFAULT_STATUSBAR_TEXTURE)
    end

    if color and color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        tex:SetVertexColor(r, g, b)
        tex:SetAlpha(a or 1)
    elseif color and type(color) == "table" then
        local r = color[1] or color.r or 1
        local g = color[2] or color.g or 1
        local b = color[3] or color.b or 1
        local a = color[4] or color.a or 1
        tex:SetVertexColor(r, g, b)
        tex:SetAlpha(a)
    else
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(1)
    end

    tex:SetPoint("TOP", parent, "TOP", 0, 0)
    tex:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
    tex:Hide()
    return tex
end

function UI.CreateText(parent, template, point, offsetX, offsetY, justifyH, fontSize, fontFlags, layer, color)
    local text = parent:CreateFontString(nil, layer or "OVERLAY", template)
    text:SetPoint(point, parent, point, offsetX or 0, offsetY or 0)

    if justifyH then
        text:SetJustifyH(justifyH)
    end

    local reference = _G[template]
    if reference and reference.GetFont then
        local font, size, flags = reference:GetFont()
        if font then
            text:SetFont(font, fontSize or size, fontFlags or flags)
        end
    elseif fontSize then
        local font = text:GetFont()
        text:SetFont(font, fontSize, fontFlags)
    end

    if color then
        text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    return text
end

function UI.CreateInfoLine(parent, anchor, offsetY, color, justifyH, template)
    local infoTemplate = template or "GameFontNormalSmall"
    local line = parent:CreateFontString(nil, "OVERLAY", infoTemplate)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -2)
    line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offsetY or -2)
    line:SetJustifyH(justifyH or "LEFT")

    if color then
        line:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    return line
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
