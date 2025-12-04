-- ControlHelpers.lua
-- Centralized helpers for checkbox and slider control setup in Options UI

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.ControlHelpers = Addon.UI.ControlHelpers or {}

local ControlHelpers = {}
local Config = Addon.Config

-- Play sound helper from Options.lua
local PlaySound = rawget(_G, "PlaySound")
local SOUNDKIT = rawget(_G, "SOUNDKIT")
local function PlayCheckboxSound(checked)
    if PlaySound then
        local kit = SOUNDKIT and (checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if kit then
            PlaySound(kit)
        end
    end
end

-- Shared checkbox click handler
local function CheckboxOnClick(selfFrame, checkbox, key)
    PlayCheckboxSound(checkbox:GetChecked())
    Config:SetOptionKey(key, checkbox:GetChecked(), true)
    -- Get fresh reference to Options module (avoids stale upvalue issue)
    local controller = Addon.Options
    if controller and controller.OnOptionChanged then
        controller:OnOptionChanged(key)
    else
        -- Fallback: attempt to call Refresh on the container where checkbox lives
        if selfFrame and selfFrame.Refresh then
            selfFrame:Refresh()
        end
    end
end

-- Shared slider value change handler
local function SliderOnValueChanged(selfFrame, slider, key, value)
    if slider.settingValue then
        return
    end
    Config:SetOptionKey(key, value, true)
    -- Get fresh reference to Options module (avoids stale upvalue issue)
    local controller = Addon.Options
    if controller and controller.OnOptionChanged then
        controller:OnOptionChanged(key)
    else
        if selfFrame and selfFrame.Refresh then
            selfFrame:Refresh()
        end
    end
end

-- Initialize a checkbox contained inside a row container (two-column layout)
function ControlHelpers.SetupTwoColumnCheckbox(selfFrame, row, key, detail)
    if not row or not row.Checkbox or not detail then
        return
    end
    local checkbox = row.Checkbox
    local label = row.Label

    -- Set label on the LEFT column
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Hide the checkbox's own built-in text to avoid duplication
    if checkbox.Text then
        checkbox.Text:SetText("")
        checkbox.Text:Hide()
    end

    -- Set tooltips
    checkbox.tooltipText = detail.label
    checkbox.tooltipRequirement = detail.description

    -- Register click
    checkbox:SetScript("OnClick", function(btn) CheckboxOnClick(selfFrame, btn, key) end)

    -- Alias for refresh
    selfFrame.controls = selfFrame.controls or {}
    selfFrame.controls[key] = checkbox
end

-- Initialize a standalone checkbox where the checkbox provides its own text
function ControlHelpers.SetupCheckbox(selfFrame, checkbox, key, detail)
    if not checkbox or not detail then
        return
    end

    -- Ensure Text element
    if not checkbox.Text then
        checkbox.Text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    end
    if checkbox.Text and checkbox.Text.SetText then
        checkbox.Text:SetText(detail.label)
    end

    checkbox.tooltipText = detail.label
    checkbox.tooltipRequirement = detail.description

    checkbox:SetScript("OnClick", function(btn) CheckboxOnClick(selfFrame, btn, key) end)

    selfFrame.controls = selfFrame.controls or {}
    selfFrame.controls[key] = checkbox
end

-- Initialize a two-column slider (ConfigSliderTemplate)
function ControlHelpers.SetupProperSlider(selfFrame, row, key, detail)
    if not row or not row.Slider or not detail then
        return
    end

    local slider = row.Slider
    local label = row.Label

    -- Set label text
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Set current value now (useful as initial value for Init)
    local currentValue = Config:GetOptionValue(key)
    if type(currentValue) ~= "number" then
        currentValue = detail.min or 0
    end

    -- Setup slider only once (Init API may exist on custom slider mixin)
    if not slider.initialized then
        local minValue = detail.min or 0
        local maxValue = detail.max or 100
        local stepSize = detail.step or 1
        -- steps is the number of intervals: (max-min)/stepSize
        -- Blizzard calculates: actualStep = (max-min)/steps
        -- So for 20 to 100 with stepSize=5: steps = 80/5 = 16
        local steps = math.floor((maxValue - minValue) / stepSize)
        local formatStr = detail.format or "%.1f"
        -- MinimalSliderWithSteppersMixin.Init signature: Init(value, minValue, maxValue, steps, formatters)
        if slider.Init then
            slider:Init(currentValue, minValue, maxValue, steps, {
                [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
                    return string.format(formatStr, value)
                end
            })

            slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                SliderOnValueChanged(selfFrame, slider, key, value)
            end)
        else
            -- Fallback to simple Slider API
            slider:SetMinMaxValues(minValue, maxValue)
            slider:SetValueStep(stepSize)
            slider:SetScript("OnValueChanged", function(_, value)
                SliderOnValueChanged(selfFrame, slider, key, value)
            end)
        end

        slider.initialized = true
        slider.format = formatStr
    end

    -- Set current value while preserving programmatic flag
    -- currentValue was already computed above
    slider.settingValue = true
    if slider.SetValue then
        slider:SetValue(currentValue)
    end
    slider.settingValue = false

    selfFrame.sliders = selfFrame.sliders or {}
    selfFrame.sliders[key] = slider
end

-- Initialize legacy slider structure
function ControlHelpers.SetupSlider(selfFrame, sliderFrame, key, detail)
    if not sliderFrame or not detail then
        return
    end

    local slider = sliderFrame.Slider
    if not slider then
        slider = CreateFrame("Slider", nil, sliderFrame, "OptionsSliderTemplate")
        sliderFrame.Slider = slider
        slider:SetPoint("TOPLEFT", 16, -32)
        slider:SetPoint("TOPRIGHT", -16, -32)
        slider:SetHeight(17)
        slider:SetOrientation("HORIZONTAL")
        slider:SetObeyStepOnDrag(true)
    end

    slider:SetMinMaxValues(detail.min or 0, detail.max or 100)
    slider:SetValueStep(detail.step or 1)

    if not sliderFrame.Label then
        sliderFrame.Label = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sliderFrame.Label:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 0, 0)
    end
    sliderFrame.Label:SetText(detail.label)

    if not sliderFrame.Description then
        sliderFrame.Description = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sliderFrame.Description:SetPoint("TOPLEFT", sliderFrame.Label, "BOTTOMLEFT", 0, -4)
        sliderFrame.Description:SetWidth(420)
    end
    sliderFrame.Description:SetText(detail.description)

    if not sliderFrame.ValueText then
        sliderFrame.ValueText = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sliderFrame.ValueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    end

    local currentValue = Config:GetOptionValue(key)
    if type(currentValue) ~= "number" then
        currentValue = detail.min or 1.0
    end

    slider.settingValue = true
    slider:SetValue(currentValue)
    slider.settingValue = false
    local formatStr = detail.format or "%.1f"
    slider.format = formatStr
    sliderFrame.ValueText:SetText(string.format(formatStr, currentValue))

    slider:SetScript("OnValueChanged", function(s, value)
        sliderFrame.ValueText:SetText(string.format(slider.format or "%.1f", value))
        SliderOnValueChanged(selfFrame, s, key, value)
    end)

    sliderFrame.tooltipText = detail.label
    sliderFrame.tooltipRequirement = detail.description

    selfFrame.controls = selfFrame.controls or {}
    selfFrame.controls[key] = sliderFrame
end

-- Two-column dropdown setup (WowStyle1DropdownTemplate)
function ControlHelpers.SetupProperDropdown(selfFrame, row, key, detail)
    if not row or not row.Dropdown or not detail then
        return
    end

    local dropdown = row.Dropdown
    local label = row.Label

    -- Set label text
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Get current value for initial text
    local currentValue = Config:GetOptionValue(key)
    local initialText = nil
    if currentValue and detail.options then
        for _, option in ipairs(detail.options) do
            if option.value == currentValue then
                initialText = option.label
                break
            end
        end
    end

    if not dropdown.initialized then
        if initialText and dropdown.SetDefaultText then
            dropdown:SetDefaultText(initialText)
        end

        dropdown:SetupMenu(
            function(dropdown, rootDescription)
                if not detail.options then
                    return
                end
                for _, option in ipairs(detail.options) do
                    rootDescription:CreateButton(option.label, function()
                        Config:SetOptionKey(key, option.value, true)
                        local controller = Addon.Options
                        if controller and controller.OnOptionChanged then
                            controller:OnOptionChanged(key)
                        end
                    end)
                end
            end
        )

        dropdown.initialized = true
    else
        if initialText and dropdown.SetDefaultText then
            dropdown:SetDefaultText(initialText)
        end
    end

    selfFrame.dropdowns = selfFrame.dropdowns or {}
    selfFrame.dropdowns[key] = dropdown
end

-- Legacy dropdown (button-based cycler)
function ControlHelpers.SetupDropdown(selfFrame, dropdown, key, detail)
    if not dropdown or not detail then
        return
    end

    if not dropdown.Label then
        dropdown.Label = dropdown:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropdown.Label:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    end
    dropdown.Label:SetText(detail.label)

    if not dropdown.Description then
        dropdown.Description = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        dropdown.Description:SetPoint("TOPLEFT", dropdown.Label, "BOTTOMLEFT", 0, -4)
        dropdown.Description:SetWidth(420)
    end
    dropdown.Description:SetText(detail.description)

    local button = dropdown.Button
    if not button then
        button = CreateFrame("Button", nil, dropdown, "UIPanelButtonTemplate")
        dropdown.Button = button
        button:SetPoint("TOPLEFT", dropdown.Description, "BOTTOMLEFT", 0, -8)
        button:SetSize(200, 22)
    end

    button.options = detail.options
    button.key = key
    button.tooltipText = detail.label
    button.tooltipRequirement = detail.description

    local currentValue = Config:GetOptionValue(key)

    local function IsPlayerAtMaxLevel()
        local level = UnitLevel("player") or 0
        local maxLevel = GetMaxPlayerLevel() or 80
        return level >= maxLevel
    end

    for i, opt in ipairs(button.options) do
        if opt.value == currentValue then
            button:SetText(opt.label)
            break
        end
    end

    -- If player is at max level and this dropdown controls the bar style, disable it
    if key == "barStyle" and IsPlayerAtMaxLevel() then
        button:Disable()
        button:SetText(Addon.L and "Blizzard Bar (Max Level)" or "Blizzard Bar (Max Level)")
        if button.SetTooltip then
            button:SetTooltip("Disabled at max level: Blizzard experience bar enforced")
        end
    end

    button:SetScript("OnClick", function(btn)
        if key == "barStyle" and IsPlayerAtMaxLevel() then
            -- no-op at max level; player is forced to Blizzard bar
            return
        end
        local currentValue = Config:GetOptionValue(key)
        local currentIndex = 1
        for i, opt in ipairs(btn.options) do
            if opt.value == currentValue then
                currentIndex = i
                break
            end
        end
        local nextIndex = (currentIndex % #btn.options) + 1
        local nextValue = btn.options[nextIndex].value
        local nextLabel = btn.options[nextIndex].label
        Config:SetOptionKey(key, nextValue, true)
        btn:SetText(nextLabel)
        local controller = Addon.Options
        if controller and controller.OnOptionChanged then
            controller:OnOptionChanged(key)
        else
            selfFrame:Refresh()
        end
    end)

    selfFrame.dropdowns = selfFrame.dropdowns or {}
    selfFrame.dropdowns[key] = dropdown
end

-- Radio group helper
function ControlHelpers.SetupRadioGroup(selfFrame, radioGroup, key, detail)
    if not radioGroup or not detail or not detail.options then
        return
    end
    if radioGroup.Label then
        radioGroup.Label:SetText(detail.label)
    end
    if radioGroup.Description then
        radioGroup.Description:SetText(detail.description)
    end

    local buttons = {}
    local yOffset = -38
    for i, option in ipairs(detail.options) do
        local button = CreateFrame("CheckButton", nil, radioGroup, "XPBarEnhancedRadioButtonTemplate")
        button:SetPoint("TOPLEFT", radioGroup, "TOPLEFT", 4, yOffset)
        button.Text:SetText(option.label)
        button.value = option.value
        button.group = buttons
        button.key = key
        button:SetScript("OnClick", function(btn)
            for _, otherBtn in ipairs(btn.group) do
                otherBtn:SetChecked(false)
            end
            btn:SetChecked(true)
            Config:SetOptionKey(key, btn.value, true)
            local controller = Addon.Options
            if controller and controller.OnOptionChanged then
                controller:OnOptionChanged(key)
            else
                selfFrame:Refresh()
            end
        end)
        buttons[i] = button
        yOffset = yOffset - 26
    end
    radioGroup.buttons = buttons
    selfFrame.radioGroups = selfFrame.radioGroups or {}
    selfFrame.radioGroups[key] = radioGroup
end

-- Visual helper for color swatches
function ControlHelpers.SetupSwatchVisuals(swatch)
    if not swatch then
        return
    end
    if swatch.Background then
        swatch.Background:ClearAllPoints()
        swatch.Background:SetAllPoints()
        swatch.Background:SetColorTexture(0, 0, 0, 1)
    end
    if swatch.Texture then
        swatch.Texture:ClearAllPoints()
        swatch.Texture:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
        swatch.Texture:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
        swatch.Texture:SetColorTexture(1, 1, 1, 1)
    end
    if swatch.Highlight then
        swatch.Highlight:ClearAllPoints()
        swatch.Highlight:SetAllPoints()
        swatch.Highlight:SetColorTexture(1, 1, 1, 0.2)
    end
end

-- Preview setup (statusbar vs texture previews)
function ControlHelpers.SetupPreviewFrames(row, previewType)
    local statusPreview = row.StatusPreview
    local textureFrame = row.TexturePreview
    local texturePreview = textureFrame and textureFrame.Texture
    if statusPreview then
        statusPreview:Hide()
        statusPreview:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusPreview:SetMinMaxValues(0, 1)
        statusPreview:SetValue(1)
        if statusPreview.BackgroundTexture then
            statusPreview.BackgroundTexture:ClearAllPoints()
            statusPreview.BackgroundTexture:SetAllPoints()
        end
    end
    if textureFrame and texturePreview then
        textureFrame:Hide()
        texturePreview:ClearAllPoints()
        texturePreview:SetAllPoints()
        texturePreview:SetColorTexture(1, 1, 1, 1)
    end
    if previewType == "statusbar" and statusPreview then
        statusPreview:Show()
        return statusPreview, statusPreview.BackgroundTexture, "statusbar"
    elseif previewType == "texture" and textureFrame and texturePreview then
        textureFrame:Show()
        return texturePreview, nil, "texture"
    end
    if textureFrame and texturePreview then
        textureFrame:Show()
        return texturePreview, nil, "texture"
    end
    return nil, nil, previewType
end

-- Color row setup (color picker + swatch + preview)
function ControlHelpers.SetupColorRow(selfFrame, row, info)
    if not row or not info then
        return nil
    end
    if row.Label then
        row.Label:SetText(info.label)
        if row.Label.SetJustifyH then
            row.Label:SetJustifyH("LEFT")
        end
    end
    if row.Description then
        row.Description:SetText(info.description or "")
        if row.Description.SetJustifyH then
            row.Description:SetJustifyH("LEFT")
        end
        if row.Description.SetWordWrap then
            row.Description:SetWordWrap(true)
        end
        if row.Description.SetNonSpaceWrap then
            row.Description:SetNonSpaceWrap(true)
        end
    end
    if row.ValueText then
        if row.ValueText.SetJustifyH then
            row.ValueText:SetJustifyH("LEFT")
        end
        if row.ValueText.SetWordWrap then
            row.ValueText:SetWordWrap(false)
        end
    end

    local swatch = row.Swatch
    ControlHelpers.SetupSwatchVisuals(swatch)
    local preview, previewBackground, effectivePreviewType = ControlHelpers.SetupPreviewFrames(row, info.preview or "texture")
    local controls = {
        info = info,
        row = row,
        swatch = swatch,
        swatchTexture = swatch and swatch.Texture or nil,
        previewType = effectivePreviewType or info.preview or "texture",
        preview = preview,
        previewBackground = previewBackground,
        valueText = row.ValueText
    }
    if swatch then
        swatch:SetScript("OnClick", function()
            if IsShiftKeyDown and IsShiftKeyDown() then
                Config:ResetColor(info.key, true)
                local controller = Addon.Options
                if controller and controller.OnColorReset then
                    controller:OnColorReset(info.key)
                else
                    selfFrame:UpdateColorControls()
                end
                return
            end
            selfFrame:OpenColorPicker(info.key)
        end)

        swatch:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:AddLine(info.label .. " Color", 1, 1, 1)
            if info.description and info.description ~= "" then
                GameTooltip:AddLine(info.description, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:AddLine("Shift-Click to restore the default color.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local hasColorPicker = ColorPickerFrame or rawget(_G, "OpenColorPicker")
        if not hasColorPicker then
            swatch:Disable()
            swatch:SetAlpha(0.5)
        else
            swatch:Enable()
            swatch:SetAlpha(1)
        end
    end
    return controls
end

Addon.UI.ControlHelpers = ControlHelpers
return ControlHelpers
