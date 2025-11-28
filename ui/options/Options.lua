---@diagnostic disable: undefined-global
-- XP Bar Enhanced Options Panel
local Addon = XPBarEnhanced

Addon.Options = {}
local Options = Addon.Options
local Config = Addon.Config
local EventNames = Addon.EventNames

-- Helper function to resolve locale keys from Config
local function ResolveLocale(key)
    return Addon.L and Addon.L[key] or key
end

-- Expose via multiple namespaces for compatibility
Addon.UI = Addon.UI or {}
Addon.App = Addon.App or {}
-- Addon.App.Features = Addon.App.Features or {}
-- Addon.App.Features.options = Options

local _G = _G
local Settings = rawget(_G, "Settings")
local InterfaceOptions_AddCategory = rawget(_G, "InterfaceOptions_AddCategory")
local InterfaceOptionsFrame_OpenToCategory = rawget(_G, "InterfaceOptionsFrame_OpenToCategory")
-- local PlaySound = rawget(_G, "PlaySound")
-- local SOUNDKIT = rawget(_G, "SOUNDKIT")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local OpacitySliderFrame = rawget(_G, "OpacitySliderFrame")

local PANEL_NAME = "XP Bar Enhanced"

local XPBarEnhancedOptionsMixin = {}

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

-- Play checkbox sound handled by ControlHelpers

---Collects immediate children of a container indexed by their `configKey` field
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

-- ControlHelpers is used for centralized option control setup
local ControlHelpers = Addon.UI.ControlHelpers

-- Setup proper dropdown control (real dropdown menu with WowStyle1DropdownTemplate)
-- Note: `SetupProperDropdown` implemented in ControlHelpers

-- Setup proper slider control (MinimalSliderWithSteppersTemplate)

-- Note: `SetupDropdown` implemented in ControlHelpers

-- Note: SetupProperSlider, SetupTwoColumnCheckbox, SetupSlider and other helpers
-- are implemented in `Addon.UI.ControlHelpers` and are called directly in build methods.

-- Note: `SetupRadioGroup` implemented in ControlHelpers

-- Note: `SetupSwatchVisuals` implemented in ControlHelpers

-- Note: `SetupPreviewFrames` implemented in ControlHelpers

-- Note: `SetupColorRow` implemented in ControlHelpers

function XPBarEnhancedOptionsMixin:OnLoad()
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
            container.TextOnBarHeader.Title:SetText(ResolveLocale("OPT_TEXT_ON_BAR"))
        end

        if container.TextBelowBarHeader and container.TextBelowBarHeader.Title then
            container.TextBelowBarHeader.Title:SetText(ResolveLocale("OPT_TEXT_BELOW_BAR"))
        end
        if container.TextLeftLabelHeader and container.TextLeftLabelHeader.Text then
            container.TextLeftLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_LEFT"))
        end
        if container.TextMiddleLabelHeader and container.TextMiddleLabelHeader.Text then
            container.TextMiddleLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_MIDDLE"))
        end
        if container.TextRightLabelHeader and container.TextRightLabelHeader.Text then
            container.TextRightLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_RIGHT"))
        end
    end

    if scrollChild.ResetSettingsButton and scrollChild.ResetSettingsButton.SetText then
        scrollChild.ResetSettingsButton:SetText(ResolveLocale("OPT_RESET_SETTINGS"))
    end
    if scrollChild.ResetStatsButton and scrollChild.ResetStatsButton.SetText then
        scrollChild.ResetStatsButton:SetText(ResolveLocale("OPT_RESET_STATS"))
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
        scrollChild.ResetBarPositionButton:SetText(ResolveLocale("OPT_RESET_BAR_POSITION"))
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
            container.BarSettingsHeader.Title:SetText(ResolveLocale("OPT_HEADER_BAR_SETTINGS"))
        end

        -- Quest Features section
        if container.OverlayFeaturesHeader and container.OverlayFeaturesHeader.Title then
            container.OverlayFeaturesHeader.Title:SetText(ResolveLocale("OPT_HEADER_DISPLAY_FEATURES"))
        end

        -- Quest Features section
        if container.QuestFeaturesHeader and container.QuestFeaturesHeader.Title then
            container.QuestFeaturesHeader.Title:SetText(ResolveLocale("OPT_HEADER_QUEST_FEATURES"))
        end

        -- Text Display section
        if container.TextDisplayHeader and container.TextDisplayHeader.Title then
            container.TextDisplayHeader.Title:SetText(ResolveLocale("OPT_HEADER_TEXT_DISPLAY"))
        end

        -- Colors section
        if container.ColorsHeader and container.ColorsHeader.Title then
            container.ColorsHeader.Title:SetText(ResolveLocale("OPT_HEADER_COLORS"))
        end
    end

    self:BuildOptionCheckboxes()
    self:BuildColorControls()
    self:Refresh()
    self:RegisterCategory()

    local observerId = self:GetName() or ("_bar_" .. tostring(self))
    local colorHandler = function(payload)
        if self and self.UpdateColorControls then
            self:UpdateColorControls()
        end
    end
    Addon.EventBus:Register(EventNames.COLORS_UPDATED, observerId, colorHandler)
end

function XPBarEnhancedOptionsMixin:OnPanelShow()
    self:Refresh()
end

function XPBarEnhancedOptionsMixin:BuildOptionCheckboxes()
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
                -- Two-column slider template (ConfigSliderTemplate)
                ControlHelpers.SetupProperSlider(self, frame, key, detail)
            elseif frame.Dropdown then
                -- Two-column dropdown template (ConfigDropdownTemplate)
                ControlHelpers.SetupProperDropdown(self, frame, key, detail)
            elseif frame.Checkbox and frame.Label then
                -- Two-column checkbox template (ConfigCheckboxTemplate)
                ControlHelpers.SetupTwoColumnCheckbox(self, frame, key, detail)
            elseif detail.type == "slider" then
                -- Old-style slider (dynamically created)
                ControlHelpers.SetupSlider(self, frame, key, detail)
            elseif detail.type == "dropdown" and detail.options and #detail.options > 2 then
                -- Old-style cycling button dropdown
                ControlHelpers.SetupDropdown(self, frame, key, detail)
            elseif detail.type == "dropdown" then
                -- Old-style radio group
                ControlHelpers.SetupRadioGroup(self, frame, key, detail)
            else
                -- Default to checkbox
                ControlHelpers.SetupCheckbox(self, frame, key, detail)
            end
        end
    end
end

function XPBarEnhancedOptionsMixin:BuildColorControls()
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
            local controls = ControlHelpers.SetupColorRow(self, row, info)
            if controls then
                self.colorControls[info.key] = controls
            end
        end
    end

    self:UpdateColorControls()
end

function XPBarEnhancedOptionsMixin:UpdateContentHeight(bottomAnchor)
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

function XPBarEnhancedOptionsMixin:RegisterCategory()
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

function XPBarEnhancedOptionsMixin:OnResetSettingsClicked()
    Config:Reset()
    self:Refresh()

    -- Refresh bars immediately to apply new colors and settings

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function XPBarEnhancedOptionsMixin:OnResetStatsClicked()
    Config:ResetStats()
    self:Refresh()
end

function XPBarEnhancedOptionsMixin:OnResetBarPositionClicked()
    -- Prefer BarManager wrapper or direct view call for reset position; fallback to old shim
    if Addon.BarManager and Addon.BarManager.ResetBarPosition then
        Addon.BarManager:ResetBarPosition()
    end
end

function XPBarEnhancedOptionsMixin:UpdateColorControls()
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

function XPBarEnhancedOptionsMixin:OpenColorPicker(colorKey)
    -- Check for modern ColorPicker API first
    local hasColorPicker = ColorPickerFrame or rawget(_G, "OpenColorPicker")

    if not hasColorPicker then
        print("|cFFFF5555XP Bar Enhanced:|r Color picker is not available.")
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
                opacity = ColorPickerFrame.Content.ColorPicker
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
        local controller = Options
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
        local controller = Options
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

function XPBarEnhancedOptionsMixin:Refresh()
    if not self.controls then
        return
    end

    -- Get current barStyle value for conditional visibility
    local barStyle = Config:GetOptionValue("barStyle")
    local isNoneMode = (barStyle == "none")

    -- Refresh checkboxes
    for key, checkbox in pairs(self.controls) do
        if checkbox and checkbox.SetChecked then
            local value = Config:GetOptionValue(key)
            checkbox:SetChecked(value and true or false)

            -- Conditional visibility: only show flat-mode options when in flat mode
            if key == "barLocked" then
                -- Get the parent row frame (Row_barLocked)
                local rowKey = "Row_" .. key
                local rowFrame =
                    self.ContentFrame and self.ContentFrame.OptionsContainer and
                    self.ContentFrame.OptionsContainer[rowKey]

                if isNoneMode then
                    checkbox:Hide()
                    if rowFrame then
                        rowFrame:Hide()
                    end
                else
                    checkbox:Show()
                    if rowFrame then
                        rowFrame:Show()
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
                        -- Old-style cycling button dropdown (classic)
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
        local panel = rawget(_G, "XPBarEnhancedOptionsPanel")
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

-- Controller Methods

function Options:OnOptionChanged(key)
    -- Handle specific option changes
    if key == "barStyle" then
        local value = Addon.db and Addon.db.barStyle or "classic"
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(value)
        end
    elseif key == "hideBlizzardBar" then
        -- Update Blizzard bar visibility (handled by Config side effects)
        -- No additional action needed here
    elseif key == "barLocked" then
    elseif
        key == "enableAnimations" or key == "animationSpeed" or key == "animationEasing" or key == "flashOnGain" or
            key == "pauseOnHover"
     then
        if Addon.BarManager and Addon.BarManager.UpdateAnimationSettings then
            Addon.BarManager:UpdateAnimationSettings()
        end
    elseif
        key == "showQuestXP" or key == "showQuestPercent" or key == "questOverlaysEnabled" or
            key == "showCompleteQuestOverlay" or
            key == "showIncompleteQuestOverlay"
     then
    end

    -- General refresh
    self:Refresh()

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED)
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function Options:OnColorReset()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function Options:OnColorChanged()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function Options:OnColorCancel()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

-- Register as a feature for compatibility
-- Export the mixin into a namespaced table for internal use and also
-- expose the global name required by XML mixin attributes.
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Mixins.XPBarEnhancedOptionsMixin = XPBarEnhancedOptionsMixin
_G.XPBarEnhancedOptionsMixin = XPBarEnhancedOptionsMixin

return Options
