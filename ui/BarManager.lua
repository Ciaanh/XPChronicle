-- XP Bar Enhanced - Bar Manager (UI)
-- Responsible for creating style frames, switching styles, and hiding Blizzard's default XP bar if enabled.

local Addon = XPBarEnhanced
Addon.BarManager = Addon.BarManager or {}
local BarManager = Addon.BarManager

local StyleBuilder = XPBarStyleBuilder
local EventNames = Addon.EventNames

local StyleTemplateNameMap = {
    classic = "ClassicBarTemplate",
    flat = "FlatBarTemplate",
    vertical = "VerticalBarTemplate",
    circular = "CircularBarTemplate"
}

-- Helper: true if style key corresponds to a custom addon style (not Blizzard's bar)
function BarManager:IsCustomStyle(style)
    return style and StyleTemplateNameMap[style] ~= nil
end

function BarManager:Initialize()
    local db = Addon.db or {}
    local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    local style = db.barStyle or defaultStyle

    self:SetStyle(style)

    -- Ensure lock state is applied at startup
    if Addon.db == nil then
        Addon.db = {}
    end
    
    if Addon.db.barLocked == nil then
        Addon.db.barLocked = false
    end

    -- Hide Blizzard default whenever a custom style is active
    self:ApplyDefaultXPBarVisibility()
end

local function IsPlayerAtMaxLevel()
    local level = UnitLevel("player") or 0
    local maxLevel = GetMaxPlayerLevel() or 80
    return level >= maxLevel
end

function BarManager:ApplyDefaultXPBarVisibility()
    -- Hide Blizzard main bar components whenever we are using a custom style
    -- (classic, flat, vertical, circular)
    if self:IsCustomStyle(self.currentStyle) then
        if _G.MainMenuExpBar and _G.MainMenuExpBar.Hide then
            _G.MainMenuExpBar:Hide()
        end
        if _G.MainStatusTrackingBarContainer and _G.MainStatusTrackingBarContainer.Hide then
            _G.MainStatusTrackingBarContainer:Hide()
        end
    else
        -- Otherwise, restore Blizzard defaults
        if _G.MainMenuExpBar and _G.MainMenuExpBar.Show then
            _G.MainMenuExpBar:Show()
        end
        if _G.MainStatusTrackingBarContainer and _G.MainStatusTrackingBarContainer.Show then
            _G.MainStatusTrackingBarContainer:Show()
        end
    end
end

function BarManager:GetCurrentFrame()
    self.barFrames = self.barFrames or {}
    return self.barFrames[self.currentStyle]
end

function BarManager:SetStyle(nextStyle)
    self.barFrames = self.barFrames or {}

    local previousStyle = self.currentStyle
    if not nextStyle or type(nextStyle) ~= "string" then
        nextStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    end

    -- If player is at max level, force Blizzard bar (non-custom) regardless of selected style
    if IsPlayerAtMaxLevel() then
        nextStyle = "none"
    end

    if previousStyle == nextStyle then
        return
    end

    -- Special case: "none" (Blizzard default) should not attempt to create a custom frame
    if nextStyle == "none" then
        -- Hide any custom frames and restore Blizzard bar visibility
        for key, frame in pairs(self.barFrames) do
            if frame and frame.Hide then
                frame:SetShown(false)
            end
        end
        self.currentStyle = "none"
        self:ApplyDefaultXPBarVisibility()
        return
    end

    -- Hide any other frames except the selected style to ensure only one visible
    for key, frame in pairs(self.barFrames) do
        if key ~= nextStyle and frame and frame.Hide then
            frame:SetShown(false)
        end
    end

    local nextFrame = self.barFrames[nextStyle]

    if not nextFrame and StyleBuilder and StyleBuilder.CreateFrameForStyle then
        local templateName = StyleTemplateNameMap[nextStyle]
        local mixin = StyleBuilder:GetStyleMixin(nextStyle)
        if not mixin then
            error("BarManager:SetStyle: Unknown style key: " .. tostring(nextStyle))
        end

        local frame = StyleBuilder:CreateFrameForStyle(nextStyle, mixin.__xpbar_config or {}, templateName)
        self.barFrames[nextStyle] = frame

        if frame and frame.Show then
            frame:SetShown(true)
        end
    else
        if nextFrame and nextFrame.Show then
            nextFrame:SetShown(true)
        end
    end

    self.currentStyle = nextStyle

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end

    -- Always hide the Blizzard XP bar when we are using a custom style
    self:ApplyDefaultXPBarVisibility()
end

function BarManager:GetCurrentStyle()
    return self.currentStyle
end

function BarManager:ResetBarPosition()
    for key, value in pairs(self.barFrames) do
        if value.ClearSavedPosition and value.SetDefaultDraggablePosition then
            value:ClearSavedPosition()
            value:SetDefaultDraggablePosition()
        end
    end
end

-- Update animation settings for views (emit broadcast for views to reconfigure)
function BarManager:UpdateAnimationSettings()
    -- If an AnimationManager exists, call configured update; otherwise, broadcast for view updates
    if Addon.AnimationManager and Addon.AnimationManager.UpdateSettings then
        pcall(
            function()
                Addon.AnimationManager:UpdateSettings()
            end
        )
        return true
    end
    return false
end

-- Lifecycle wrappers (compatibility helpers / convenience)
function BarManager:OnEnteringWorld()
    -- Invalidate Quest cache and notify listeners
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        pcall(
            function()
                Addon.QuestXP:InvalidateQuestCache()
            end
        )
        return true
    end
    return false
end

function BarManager:OnLevelUp()
    -- Re-evaluate style in case player hit max level (will hide bar if at max)
    self:SetStyle(Addon.db.barStyle)
end

function BarManager:OnRestedChanged()
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function BarManager:Shutdown()
    -- Hide any frames and perform light cleanup
    self.barFrames = self.barFrames or {}
    for style, frame in pairs(self.barFrames) do
        if frame and frame.Hide then
            pcall(
                function()
                    frame:Hide()
                end
            )
        end
    end
    self.currentFrame = nil
    self.currentStyle = nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

return BarManager
