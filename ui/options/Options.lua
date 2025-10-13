---@diagnostic disable: undefined-global
-- XP Chronicle Options Panel
local XPC = XPChronicle
XPC.Options = {}
local Options = XPC.Options
local Config = XPC.Config
local function GetOptionsController()
    return XPC.App and XPC.App.Features and XPC.App.Features.options
end

XPC.UI = XPC.UI or {}
XPC.UI.Views = XPC.UI.Views or {}
XPC.UI.Views.Options = Options
XPC.Options = Options

local _G = _G
local Settings = rawget(_G, "Settings")
local InterfaceOptions_AddCategory = rawget(_G, "InterfaceOptions_AddCategory")
local InterfaceOptionsFrame_OpenToCategory = rawget(_G, "InterfaceOptionsFrame_OpenToCategory")
local InterfaceOptionsFramePanelTemplate = rawget(_G, "InterfaceOptionsFramePanelTemplate")
local PlaySound = rawget(_G, "PlaySound")
local SOUNDKIT = rawget(_G, "SOUNDKIT")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local OpacitySliderFrame = rawget(_G, "OpacitySliderFrame")

local PANEL_NAME = "XP Chronicle"

XPChronicleOptionsMixin = {}

local function clamp01(value)
    if not value then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function rgbToHex(r, g, b, a)
    local function comp(v)
        return math.floor(clamp01(v) * 255 + 0.5)
    end

    return string.format("%02X%02X%02X%02X", comp(r), comp(g), comp(b), comp(a ~= nil and a or 1))
end

local function PlayCheckboxSound(checked)
    if PlaySound then
        local kit =
            SOUNDKIT and
            (checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if kit then
            PlaySound(kit)
        end
    end
end

local function CollectChildrenByConfigKey(container)
    if not container then
        return {}
    end

    local framesByKey = {}
    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        local key = child and child.configKey
        if key then
            framesByKey[key] = child
        end
    end

    return framesByKey
end

local function SetupCheckbox(self, checkbox, key, detail)
    if not checkbox or not detail then
        return
    end

    -- Ensure Text element exists and is properly initialized
    if not checkbox.Text then
        -- Create the text element if it doesn't exist
        checkbox.Text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    end

    if checkbox.Text and checkbox.Text.SetText then
        checkbox.Text:SetText(detail.label)
    end

    checkbox.tooltipText = detail.label
    checkbox.tooltipRequirement = detail.description

    checkbox:SetScript(
        "OnClick",
        function(btn)
            PlayCheckboxSound(btn:GetChecked())
            Config:SetOptionKey(key, btn:GetChecked(), true)
            local controller = GetOptionsController()
            if controller and controller.OnOptionChanged then
                controller:OnOptionChanged(key)
            else
                self:Refresh()
            end
        end
    )

    self.controls[key] = checkbox
end

-- Setup proper dropdown control (real dropdown menu with WowStyle1DropdownTemplate)
local function SetupProperDropdown(self, row, key, detail)
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

    -- Setup dropdown menu (only once)
    if not dropdown.initialized then
        -- Set default text (WowStyle1DropdownTemplate pattern)
        if initialText and dropdown.SetDefaultText then
            dropdown:SetDefaultText(initialText)
        end

        dropdown:SetupMenu(
            function(dropdown, rootDescription)
                if not detail.options then
                    return
                end

                for _, option in ipairs(detail.options) do
                    rootDescription:CreateButton(
                        option.label,
                        function()
                            Config:SetOptionKey(key, option.value, true)

                            -- Trigger controller update
                            local controller = GetOptionsController()
                            if controller and controller.OnOptionChanged then
                                controller:OnOptionChanged(key)
                            end

                            -- The dropdown button text is automatically updated by Blizzard's menu system
                            -- when the button is clicked. We don't need to manually set it.
                        end
                    )
                end
            end
        )

        dropdown.initialized = true
    else
        -- If already initialized, update the default text
        if initialText and dropdown.SetDefaultText then
            dropdown:SetDefaultText(initialText)
        end
    end

    -- Store reference for Refresh
    self.dropdowns = self.dropdowns or {}
    self.dropdowns[key] = dropdown
end

-- Setup proper slider control (MinimalSliderWithSteppersTemplate)
local function SetupProperSlider(self, row, key, detail)
    if not row or not row.Slider or not detail then
        return
    end

    local slider = row.Slider
    local label = row.Label

    -- Set label text
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Configure slider (only initialize once)
    if not slider.initialized then
        local minValue = detail.min or 0
        local maxValue = detail.max or 100
        local stepSize = detail.step or 1

        -- Calculate number of steps (TRP3 approach)
        local numSteps = math.floor((maxValue - minValue) / stepSize)

        -- Initialize slider with formatter
        slider:Init(
            minValue, -- Start with min, will be set correctly in Refresh
            minValue,
            maxValue,
            numSteps, -- Number of steps, not step size!
            {
                [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
                    return string.format("%.1f", value)
                end
            }
        )

        -- Handle value changes (register callback only once)
        slider:RegisterCallback(
            MinimalSliderWithSteppersMixin.Event.OnValueChanged,
            function(_, value)
                -- Ignore if we're programmatically setting the value
                if slider.settingValue then
                    return
                end

                Config:SetOptionKey(key, value, true)

                -- Trigger controller update
                local controller = GetOptionsController()
                if controller and controller.OnOptionChanged then
                    controller:OnOptionChanged(key)
                end
            end
        )

        slider.initialized = true
    end

    -- Set current value
    local currentValue = Config:GetOptionValue(key)
    if type(currentValue) == "number" then
        slider.settingValue = true
        slider:SetValue(currentValue)
        slider.settingValue = false
    end

    self.sliders = self.sliders or {}
    self.sliders[key] = slider
end

-- Setup checkbox in two-column layout
local function SetupTwoColumnCheckbox(self, row, key, detail)
    if not row or not row.Checkbox or not detail then
        return
    end

    local checkbox = row.Checkbox
    local label = row.Label

    -- Set label text (LEFT column)
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Hide the checkbox's own text to avoid duplication
    if checkbox.Text then
        checkbox.Text:SetText("")
        checkbox.Text:Hide()
    end

    -- Set tooltips
    checkbox.tooltipText = detail.label
    checkbox.tooltipRequirement = detail.description

    -- Set click handler
    checkbox:SetScript(
        "OnClick",
        function(btn)
            PlayCheckboxSound(btn:GetChecked())
            Config:SetOptionKey(key, btn:GetChecked(), true)
            local controller = GetOptionsController()
            if controller and controller.OnOptionChanged then
                controller:OnOptionChanged(key)
            else
                self:Refresh()
            end
        end
    )

    self.controls[key] = checkbox
end

local function SetupDropdown(self, dropdown, key, detail)
    if not dropdown or not detail then
        return
    end

    -- Create label if it doesn't exist
    if not dropdown.Label then
        dropdown.Label = dropdown:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropdown.Label:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    end
    dropdown.Label:SetText(detail.label)

    -- Create description if it doesn't exist
    if not dropdown.Description then
        dropdown.Description = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        dropdown.Description:SetPoint("TOPLEFT", dropdown.Label, "BOTTOMLEFT", 0, -4)
        dropdown.Description:SetWidth(420)
    end
    dropdown.Description:SetText(detail.description)

    -- Create button if it doesn't exist
    local button = dropdown.Button
    if not button then
        button = CreateFrame("Button", nil, dropdown, "UIPanelButtonTemplate")
        dropdown.Button = button
        button:SetPoint("TOPLEFT", dropdown.Description, "BOTTOMLEFT", 0, -8)
        button:SetSize(200, 22)
    end

    -- Store options and key
    button.options = detail.options
    button.key = key
    button.tooltipText = detail.label
    button.tooltipRequirement = detail.description

    -- Get current value and set button text
    local currentValue = Config:GetOptionValue(key)
    for i, opt in ipairs(button.options) do
        if opt.value == currentValue then
            button:SetText(opt.label)
            break
        end
    end

    -- Setup click handler to cycle through options
    button:SetScript(
        "OnClick",
        function(btn)
            local currentValue = Config:GetOptionValue(key)
            local currentIndex = 1

            -- Find current option index
            for i, opt in ipairs(btn.options) do
                if opt.value == currentValue then
                    currentIndex = i
                    break
                end
            end

            -- Cycle to next option
            local nextIndex = (currentIndex % #btn.options) + 1
            local nextValue = btn.options[nextIndex].value
            local nextLabel = btn.options[nextIndex].label

            Config:SetOptionKey(key, nextValue, true)
            btn:SetText(nextLabel)

            -- Trigger controller update
            local controller = GetOptionsController()
            if controller and controller.OnOptionChanged then
                controller:OnOptionChanged(key)
            else
                self:Refresh()
            end
        end
    )

    self.dropdowns = self.dropdowns or {}
    self.dropdowns[key] = dropdown
end

local function SetupSlider(self, sliderFrame, key, detail)
    if not sliderFrame or not detail then
        return
    end

    -- Create slider if it doesn't exist
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

    -- Setup min/max/step
    slider:SetMinMaxValues(detail.min or 0, detail.max or 100)
    slider:SetValueStep(detail.step or 1)

    -- Create label if it doesn't exist
    if not sliderFrame.Label then
        sliderFrame.Label = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sliderFrame.Label:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 0, 0)
    end
    sliderFrame.Label:SetText(detail.label)

    -- Create description if it doesn't exist
    if not sliderFrame.Description then
        sliderFrame.Description = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sliderFrame.Description:SetPoint("TOPLEFT", sliderFrame.Label, "BOTTOMLEFT", 0, -4)
        sliderFrame.Description:SetWidth(420)
    end
    sliderFrame.Description:SetText(detail.description)

    -- Create value text if it doesn't exist
    if not sliderFrame.ValueText then
        sliderFrame.ValueText = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sliderFrame.ValueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    end

    -- Set initial value and update text
    local currentValue = Config:GetOptionValue(key)

    -- Validate that the value is a number
    if type(currentValue) ~= "number" then
        currentValue = detail.min or 1.0
    end

    slider:SetValue(currentValue)
    sliderFrame.ValueText:SetText(string.format("%.1f", currentValue))

    -- Setup value change handler
    slider:SetScript(
        "OnValueChanged",
        function(s, value)
            sliderFrame.ValueText:SetText(string.format("%.1f", value))
            Config:SetOptionKey(key, value, true)

            -- Trigger controller update
            local controller = GetOptionsController()
            if controller and controller.OnOptionChanged then
                controller:OnOptionChanged(key)
            else
                self:Refresh()
            end
        end
    )

    -- Store tooltip info
    sliderFrame.tooltipText = detail.label
    sliderFrame.tooltipRequirement = detail.description

    self.controls[key] = sliderFrame
end

local function SetupRadioGroup(self, radioGroup, key, detail)
    if not radioGroup or not detail or not detail.options then
        return
    end

    -- Setup labels
    if radioGroup.Label then
        radioGroup.Label:SetText(detail.label)
    end
    if radioGroup.Description then
        radioGroup.Description:SetText(detail.description)
    end

    -- Create radio buttons dynamically
    local buttons = {}
    local yOffset = -38 -- Start below description

    for i, option in ipairs(detail.options) do
        local button = CreateFrame("CheckButton", nil, radioGroup, "XPChronicleRadioButtonTemplate")
        button:SetPoint("TOPLEFT", radioGroup, "TOPLEFT", 4, yOffset)
        button.Text:SetText(option.label)
        button.value = option.value
        button.group = buttons
        button.key = key

        -- Radio button click handler
        button:SetScript(
            "OnClick",
            function(btn)
                -- Uncheck all buttons in group
                for _, otherBtn in ipairs(btn.group) do
                    otherBtn:SetChecked(false)
                end

                -- Check this button
                btn:SetChecked(true)

                -- Update config
                Config:SetOptionKey(key, btn.value, true)

                -- Trigger controller update
                local controller = GetOptionsController()
                if controller and controller.OnOptionChanged then
                    controller:OnOptionChanged(key)
                else
                    self:Refresh()
                end
            end
        )

        buttons[i] = button
        yOffset = yOffset - 26 -- Space between radio buttons
    end

    -- Store buttons for updates
    radioGroup.buttons = buttons

    self.radioGroups = self.radioGroups or {}
    self.radioGroups[key] = radioGroup
end

local function SetupSwatchVisuals(swatch)
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

local function SetupPreviewFrames(row, previewType)
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

local function SetupColorRow(self, row, info)
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
    SetupSwatchVisuals(swatch)

    local preview, previewBackground, effectivePreviewType = SetupPreviewFrames(row, info.preview or "texture")

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
        swatch:SetScript(
            "OnClick",
            function()
                if IsShiftKeyDown and IsShiftKeyDown() then
                    Config:ResetColor(info.key, true)
                    local controller = GetOptionsController()
                    if controller and controller.OnColorReset then
                        controller:OnColorReset(info.key)
                    else
                        self:UpdateColorControls()
                    end
                    return
                end

                self:OpenColorPicker(info.key)
            end
        )

        swatch:SetScript(
            "OnEnter",
            function(widget)
                GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
                GameTooltip:AddLine(info.label .. " Color", 1, 1, 1)
                if info.description and info.description ~= "" then
                    GameTooltip:AddLine(info.description, 0.8, 0.8, 0.8, true)
                end
                GameTooltip:AddLine("Shift-Click to restore the default color.", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end
        )

        swatch:SetScript(
            "OnLeave",
            function()
                GameTooltip:Hide()
            end
        )

        -- Check if color picker is available
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

function XPChronicleOptionsMixin:OnLoad()
    Options.frame = self
    self.controls = {}
    self.colorControls = {}
    self.radioGroups = {}

    -- ContentFrame is now a child of ScrollBox in XML
    -- Access it through ScrollBox
    self.ContentFrame = self.ScrollBox.ContentFrame
    local scrollChild = self.ContentFrame

    -- SIMPLIFIED SCROLLBOX SETUP:
    -- Use the modern ScrollBox API with ContentFrame as the scroll target
    local view = CreateScrollBoxListLinearView()
    view:SetPanExtent(100) -- Mousewheel scroll amount

    -- Get the full height for the extent calculator
    local contentHeight = scrollChild:GetHeight()

    view:SetElementExtentCalculator(
        function(dataIndex, elementData)
            return contentHeight
        end
    )

    -- Simple factory that references our existing ContentFrame
    view:SetElementFactory(
        function(factory, elementData)
            factory(
                "Frame",
                function(frame, elementData)
                    if not frame.initialized then
                        -- Just set the frame to match ContentFrame's size
                        frame:SetSize(scrollChild:GetSize())
                        -- Make ContentFrame visible within this frame
                        scrollChild:ClearAllPoints()
                        scrollChild:SetAllPoints(frame)
                        frame.initialized = true
                    end
                end
            )
        end
    )

    -- Create data provider with one element
    local dataProvider = CreateDataProvider()
    dataProvider:Insert({id = "content"})

    -- Initialize ScrollBox and ScrollBar
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    self.ScrollBox:SetDataProvider(dataProvider)
    self.ScrollBox:SetScrollPercentage(0, ScrollBoxConstants.NoScrollInterpolation)

    if scrollChild.TitleText then
        scrollChild.TitleText:SetText(PANEL_NAME)
        if scrollChild.TitleText.SetJustifyH then
            scrollChild.TitleText:SetJustifyH("LEFT")
        end
    end

    if scrollChild.SubtitleText then
        scrollChild.SubtitleText:SetText(
            "Configure the custom experience bar, quest overlays, and leveling statistics."
        )
        if scrollChild.SubtitleText.SetJustifyH then
            scrollChild.SubtitleText:SetJustifyH("LEFT")
        end
        if scrollChild.SubtitleText.SetWordWrap then
            scrollChild.SubtitleText:SetWordWrap(true)
        end
        if scrollChild.SubtitleText.SetNonSpaceWrap then
            scrollChild.SubtitleText:SetNonSpaceWrap(true)
        end
    end

    -- Set subsection header text (localized)
    local container = scrollChild.OptionsContainer
    if container then
        if container.TextOnBarHeader and container.TextOnBarHeader.Title then
            container.TextOnBarHeader.Title:SetText(L and L("OPT_TEXT_ON_BAR") or "Text ON the Bar")
        end

        if container.TextBelowBarHeader and container.TextBelowBarHeader.Title then
            container.TextBelowBarHeader.Title:SetText(L and L("OPT_TEXT_BELOW_BAR") or "Text BELOW the Bar")
        end
        if container.TextLeftLabelHeader and container.TextLeftLabelHeader.Text then
            container.TextLeftLabelHeader.Text:SetText(L and L("OPT_TEXT_LEFT") or "Left")
        end
        if container.TextMiddleLabelHeader and container.TextMiddleLabelHeader.Text then
            container.TextMiddleLabelHeader.Text:SetText(L and L("OPT_TEXT_MIDDLE") or "Middle")
        end
        if container.TextRightLabelHeader and container.TextRightLabelHeader.Text then
            container.TextRightLabelHeader.Text:SetText(L and L("OPT_TEXT_RIGHT") or "Right")
        end
    end

    if scrollChild.ResetSettingsButton and scrollChild.ResetSettingsButton.SetText then
        scrollChild.ResetSettingsButton:SetText("Reset Settings")
    end
    if scrollChild.ResetStatsButton and scrollChild.ResetStatsButton.SetText then
        scrollChild.ResetStatsButton:SetText("Reset Statistics")
    end

    if scrollChild.ResetSettingsButton then
        scrollChild.ResetSettingsButton:SetScript(
            "OnClick",
            function()
                self:OnResetSettingsClicked()
            end
        )
    end

    if scrollChild.ResetStatsButton then
        scrollChild.ResetStatsButton:SetScript(
            "OnClick",
            function()
                self:OnResetStatsClicked()
            end
        )
    end

    if scrollChild.ResetBarPositionButton then
        scrollChild.ResetBarPositionButton:SetText(L and L("OPT_RESET_BAR_POSITION") or "Reset Bar Position")
        scrollChild.ResetBarPositionButton:SetScript(
            "OnClick",
            function()
                self:OnResetBarPositionClicked()
            end
        )
    end

    -- Set section header titles
    if scrollChild.OptionsContainer then
        local container = scrollChild.OptionsContainer

        -- Bar Settings section
        if container.BarSettingsHeader and container.BarSettingsHeader.Title then
            container.BarSettingsHeader.Title:SetText("Bar Settings")
        end

        -- Quest Features section
        if container.QuestFeaturesHeader and container.QuestFeaturesHeader.Title then
            container.QuestFeaturesHeader.Title:SetText("Quest Features")
        end

        -- Text Display section
        if container.TextDisplayHeader and container.TextDisplayHeader.Title then
            container.TextDisplayHeader.Title:SetText("Text Display")
        end

        -- Colors section
        if container.ColorsHeader and container.ColorsHeader.Title then
            container.ColorsHeader.Title:SetText("Colors")
        end
    end

    self:BuildOptionCheckboxes()
    self:BuildColorControls()
    self:Refresh()
    self:RegisterCategory()
end

function XPChronicleOptionsMixin:OnPanelShow()
    self:Refresh()
end

function XPChronicleOptionsMixin:BuildOptionCheckboxes()
    if not self.ContentFrame or not self.ContentFrame.OptionsContainer then
        return
    end

    if next(self.controls) then
        return
    end

    local container = self.ContentFrame.OptionsContainer
    local childFrames = CollectChildrenByConfigKey(container)

    for _, key in ipairs(Config.optionOrder or {}) do
        local detail = Config.optionDetails and Config.optionDetails[key]
        local frame = childFrames[key]

        if detail and frame then
            -- Route based on template type (detect two-column templates)
            -- Check for Slider and Dropdown FIRST (before Checkbox) to avoid misdetection
            if frame.Slider then
                -- Two-column slider template (XPC_ConfigSliderTemplate)
                SetupProperSlider(self, frame, key, detail)
            elseif frame.Dropdown then
                -- Two-column dropdown template (XPC_ConfigDropdownTemplate)
                SetupProperDropdown(self, frame, key, detail)
            elseif frame.Checkbox and frame.Label then
                -- Two-column checkbox template (XPC_ConfigCheckboxTemplate)
                SetupTwoColumnCheckbox(self, frame, key, detail)
            elseif detail.type == "slider" then
                -- Old-style slider (dynamically created)
                SetupSlider(self, frame, key, detail)
            elseif detail.type == "dropdown" and detail.options and #detail.options > 2 then
                -- Old-style cycling button dropdown
                SetupDropdown(self, frame, key, detail)
            elseif detail.type == "dropdown" then
                -- Old-style radio group
                SetupRadioGroup(self, frame, key, detail)
            else
                -- Default to checkbox
                SetupCheckbox(self, frame, key, detail)
            end
        end
    end
end

function XPChronicleOptionsMixin:BuildColorControls()
    if not self.ContentFrame or not self.ContentFrame.OptionsContainer then
        return
    end

    if next(self.colorControls) then
        return -- Already built
    end

    local container = self.ContentFrame.OptionsContainer

    -- Collect all color picker rows from OptionsContainer (they're now direct children like other settings)
    local rowsByKey = CollectChildrenByConfigKey(container)

    if not Config.colorOptionsList then
        return
    end

    -- Setup each color row
    for _, info in ipairs(Config.colorOptionsList) do
        local row = rowsByKey[info.key]
        if row then
            local controls = SetupColorRow(self, row, info)
            if controls then
                self.colorControls[info.key] = controls
            end
        end
    end

    self:UpdateColorControls()
end

function XPChronicleOptionsMixin:UpdateContentHeight(bottomAnchor)
    local contentFrame = self.ContentFrame
    if not contentFrame then
        return
    end

    local top = contentFrame:GetTop()
    local bottom = bottomAnchor and bottomAnchor.valueText and bottomAnchor.valueText:GetBottom()

    if not bottom and self.ResetSettingsButton and self.ResetSettingsButton.GetBottom then
        bottom = self.ResetSettingsButton:GetBottom()
    end

    if top and bottom then
        local height = (top - bottom) + 80
        if height > contentFrame:GetHeight() then
            contentFrame:SetHeight(height)
        end
    end
end

function XPChronicleOptionsMixin:RegisterCategory()
    if self._registeredCategory then
        return
    end

    self.name = PANEL_NAME

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local settingsCategory = Settings.RegisterCanvasLayoutCategory(self, PANEL_NAME)
        settingsCategory.ID = settingsCategory.ID or PANEL_NAME
        Settings.RegisterAddOnCategory(settingsCategory)
        self._registeredCategory = settingsCategory
        Options.category = settingsCategory
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(self)
        self._registeredCategory = self
        Options.category = self
    end
end

function XPChronicleOptionsMixin:OnResetSettingsClicked()
    Config:Reset()
    self:Refresh()
end

function XPChronicleOptionsMixin:OnResetStatsClicked()
    Config:ResetStats()
    self:Refresh()
end

function XPChronicleOptionsMixin:OnResetBarPositionClicked()
    local Addon = XPChronicle
    local xpBarController = Addon.App and Addon.App.Features and Addon.App.Features.xpbar
    if xpBarController and xpBarController.ResetFlatBarPosition then
        xpBarController:ResetFlatBarPosition()
        -- Show confirmation message
        local L = function(key)
            return Addon.L and Addon.L(key) or key
        end
        print("|cFF00FF00" .. L("ADDON_NAME") .. ":|r Bar position reset to default.")
    end
end

function XPChronicleOptionsMixin:UpdateColorControls()
    if not Config or not Config.colorOptionsList then
        return
    end

    for _, info in ipairs(Config.colorOptionsList) do
        local controls = self.colorControls[info.key]
        if controls then
            local color = Config:GetColor(info.key) or Config:GetDefaultColor(info.key) or {}
            local r = clamp01(color.r or color[1] or 1)
            local g = clamp01(color.g or color[2] or 1)
            local b = clamp01(color.b or color[3] or 1)
            local a = clamp01(color.a or color[4] or 1)

            if controls.swatchTexture then
                controls.swatchTexture:SetColorTexture(r, g, b, 1)
            end

            if controls.previewType == "statusbar" and controls.preview and controls.preview.SetStatusBarColor then
                controls.preview:SetStatusBarColor(r, g, b, a)
                if controls.previewBackground and controls.previewBackground.SetColorTexture then
                    controls.previewBackground:SetColorTexture(r, g, b, clamp01(a * 0.25) + 0.05)
                end
            elseif controls.previewType == "texture" and controls.preview and controls.preview.SetColorTexture then
                controls.preview:SetColorTexture(r, g, b, a)
            end

            if controls.valueText then
                local hex = Config:GetColorHex(info.key) or "FFFFFFFF"
                local alphaPercent = math.floor(a * 100 + 0.5)
                controls.valueText:SetText(
                    string.format("Current: #%s (Alpha %d%%)", string.sub(hex, 1, 6), alphaPercent)
                )
            end

            if controls.swatch then
                if ColorPickerFrame or rawget(_G, "OpenColorPicker") then
                    controls.swatch:Enable()
                    controls.swatch:SetAlpha(1)
                else
                    controls.swatch:Disable()
                    controls.swatch:SetAlpha(0.5)
                end
            end
        end
    end
end

function XPChronicleOptionsMixin:OpenColorPicker(colorKey)
    -- Check for modern ColorPicker API first
    local hasColorPicker = ColorPickerFrame or rawget(_G, "OpenColorPicker")

    if not hasColorPicker then
        print("|cFFFF5555XP Chronicle:|r Color picker is not available.")
        return
    end

    local info = Config:GetColorOptionByKey(colorKey)
    if not info then
        return
    end

    local color = Config:GetColor(colorKey) or Config:GetDefaultColor(colorKey) or {}
    local r = clamp01(color.r or color[1] or 1)
    local g = clamp01(color.g or color[2] or 1)
    local b = clamp01(color.b or color[3] or 1)
    local a = clamp01(color.a or color[4] or 1)
    local previousHex = Config:GetColorHex(colorKey)

    -- Called continuously as the user changes color/opacity
    local function applyColor(restore, ...)
        local pr, pg, pb, opacity

        if type(restore) == "table" then
            pr = clamp01(restore.r or restore[1] or r)
            pg = clamp01(restore.g or restore[2] or g)
            pb = clamp01(restore.b or restore[3] or b)
            local restoreAlpha = restore.a or restore[4]
            if restoreAlpha ~= nil then
                opacity = clamp01(restoreAlpha)
            end
        end

        if not pr then
            pr, pg, pb = ColorPickerFrame:GetColorRGB()
        end

        if opacity == nil then
            -- Use GetColorAlpha() to get the current alpha value from the slider
            if ColorPickerFrame.GetColorAlpha then
                opacity = ColorPickerFrame:GetColorAlpha()
            elseif
                ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and
                    ColorPickerFrame.Content.ColorPicker.GetColorAlpha
             then
                opacity = ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
            end

            -- Fallback to the static opacity field if GetColorAlpha doesn't exist
            if opacity == nil then
                opacity = ColorPickerFrame.opacity
            end

            -- Final fallback to OpacitySliderFrame for older versions
            if (opacity == nil) and OpacitySliderFrame and OpacitySliderFrame:IsShown() then
                opacity = OpacitySliderFrame:GetValue()
            end
        end

        opacity = clamp01(opacity or 1)
        local hex = rgbToHex(pr, pg, pb, opacity)

        -- Save the new color
        Config:SetColor(colorKey, hex, true)

        -- Update UI
        local controller = GetOptionsController()
        if controller and controller.OnColorChanged then
            controller:OnColorChanged(colorKey, hex)
        else
            self:UpdateColorControls()
        end
    end

    -- Called when user clicks Cancel - restore original color
    local function cancelColor(restore)
        -- Restore to the original color
        Config:SetColor(colorKey, previousHex, true)

        -- Update UI
        local controller = GetOptionsController()
        if controller and controller.OnColorCancel then
            controller:OnColorCancel(colorKey, previousHex)
        else
            self:UpdateColorControls()
        end
    end

    if ColorPickerFrame and ColorPickerFrame.SetColorRGB then
        ColorPickerFrame.func = applyColor
        ColorPickerFrame.opacityFunc = applyColor
        ColorPickerFrame.cancelFunc = cancelColor

        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = a
        ColorPickerFrame.previousValues = {r = r, g = g, b = b, a = a}
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    elseif ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(
            {
                swatchFunc = applyColor,
                opacityFunc = applyColor,
                cancelFunc = cancelColor,
                hasOpacity = true,
                opacity = a,
                r = r,
                g = g,
                b = b,
                previousValues = {r = r, g = g, b = b, a = a}
            }
        )
    else
        local OpenColorPicker = rawget(_G, "OpenColorPicker")
        if OpenColorPicker then
            OpenColorPicker(
                {
                    swatchFunc = applyColor,
                    opacityFunc = applyColor,
                    cancelFunc = cancelColor,
                    hasOpacity = true,
                    opacity = a,
                    r = r,
                    g = g,
                    b = b,
                    previousValues = {r = r, g = g, b = b, a = a}
                }
            )
        end
    end
end

function XPChronicleOptionsMixin:Refresh()
    if not self.controls then
        return
    end

    -- Get current barStyle value for conditional visibility
    local barStyle = Config:GetOptionValue("barStyle")
    local isFlatMode = (barStyle == "flat")

    -- Refresh checkboxes
    for key, checkbox in pairs(self.controls) do
        if checkbox and checkbox.SetChecked then
            local value = Config:GetOptionValue(key)
            checkbox:SetChecked(value and true or false)

            -- Conditional visibility: only show flat-mode options when in flat mode
            if key == "hideBlizzardBar" or key == "barLocked" then
                -- Get the parent row frame (Row_hideBlizzardBar or Row_barLocked)
                local rowKey = "Row_" .. key
                local rowFrame =
                    self.ContentFrame and self.ContentFrame.OptionsContainer and
                    self.ContentFrame.OptionsContainer[rowKey]

                if isFlatMode then
                    checkbox:Show()
                    if rowFrame then
                        rowFrame:Show()
                    end
                else
                    checkbox:Hide()
                    if rowFrame then
                        rowFrame:Hide()
                    end
                end
            end
        elseif checkbox and checkbox.Slider then
            -- It's a slider control
            local value = Config:GetOptionValue(key)

            -- Validate that value is a number
            if type(value) ~= "number" then
                -- Fall back to default value from metadata
                local detail = Config.optionDetails and Config.optionDetails[key]
                if detail then
                    value = detail.min or 0
                else
                    value = 1.0 -- Fallback default
                end
            end

            if checkbox.Slider.SetValue then
                checkbox.Slider:SetValue(value)
                if checkbox.ValueText then
                    checkbox.ValueText:SetText(string.format("%.1f", value))
                end
            end
        end
    end

    -- Refresh dropdowns
    if self.dropdowns then
        for key, dropdown in pairs(self.dropdowns) do
            local value = Config:GetOptionValue(key)
            local detail = Config.optionDetails and Config.optionDetails[key]

            if detail and detail.options then
                -- Find the label for current value
                local labelText = nil
                for _, opt in ipairs(detail.options) do
                    if opt.value == value then
                        labelText = opt.label
                        break
                    end
                end

                if labelText then
                    -- WowStyle1DropdownTemplate: Use SetDefaultText to update displayed text
                    if dropdown.SetDefaultText then
                        dropdown:SetDefaultText(labelText)
                    elseif dropdown.Button then
                        -- Old-style cycling button dropdown (legacy)
                        dropdown.Button:SetText(labelText)
                    end
                end
            end
        end
    end

    -- Refresh proper sliders (MinimalSliderWithSteppersTemplate)
    if self.sliders then
        for key, slider in pairs(self.sliders) do
            local value = Config:GetOptionValue(key)

            -- Validate that value is a number
            if type(value) ~= "number" then
                local detail = Config.optionDetails and Config.optionDetails[key]
                if detail then
                    value = detail.min or 0
                else
                    value = 1.0
                end
            end

            if slider and slider.SetValue then
                -- Prevent callback from firing when we programmatically set value
                slider.settingValue = true
                slider:SetValue(value)
                slider.settingValue = false
            end
        end
    end

    -- Refresh radio groups
    if self.radioGroups then
        for key, radioGroup in pairs(self.radioGroups) do
            if radioGroup and radioGroup.buttons then
                local value = Config:GetOptionValue(key)

                -- Update radio button checked states
                for _, button in ipairs(radioGroup.buttons) do
                    button:SetChecked(button.value == value)
                end
            end
        end
    end

    self:UpdateColorControls()
end

function Options:Initialize(controller)
    if controller then
        self.controller = controller
    end

    if not self.frame then
        local panel = rawget(_G, "XPChronicleOptionsPanel")
        if panel then
            self.frame = panel
        end
    end

    local panel = self.frame
    if panel and not panel.controls then
        if panel.OnLoad then
            panel:OnLoad()
        end
    end

    return panel
end

function Options:Refresh()
    local panel = self:Initialize(self.controller)
    if panel and panel.Refresh then
        panel:Refresh()
    end
end

function Options:UpdateColorControls()
    local panel = self:Initialize(self.controller)
    if panel and panel.UpdateColorControls then
        panel:UpdateColorControls()
    end
end

function Options:OpenColorPicker(colorKey)
    local panel = self:Initialize(self.controller)
    if panel and panel.OpenColorPicker then
        panel:OpenColorPicker(colorKey)
    end
end

function Options:Open()
    local panel = self:Initialize(self.controller)
    if not panel then
        return
    end

    self:Refresh()

    local category = self.category
    if Settings and Settings.OpenToCategory and category then
        local id = category.GetID and category:GetID() or category.ID or category
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

return Options
