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
    Addon.UI = Addon.UI or {}
    Addon.UI.Views = Addon.UI.Views or {}

    local db = Addon.db or {}
    local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    local style = db.barStyle or defaultStyle

    self:SetStyle(style)

    -- Ensure lock state is applied at startup
    if Addon.db == nil then
        Addon.db = {}
    end
    if Addon.db.locked == nil then
        Addon.db.locked = false
    end
    self:UpdateLockedState()

    -- Hide Blizzard default whenever a custom style is active
    self:ApplyDefaultXPBarVisibility()
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
    Addon.UI.Views = Addon.UI.Views or {}
    self.barFrames = self.barFrames or {}

    local previousStyle = self.currentStyle
    if not nextStyle or type(nextStyle) ~= "string" then
        nextStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    end

    if previousStyle == nextStyle then
        return
    end

    local previousFrame = self.barFrames[previousStyle]
    if previousFrame and previousFrame.Hide then
        print("Hiding current frame for style: " .. tostring(previousStyle) .. " -> " .. tostring(nextStyle))
        previousFrame:Hide()
    end

    local nextFrame = self.barFrames[nextStyle]

    if not nextFrame and StyleBuilder and StyleBuilder.CreateFrameForStyle then
        local templateName = StyleTemplateNameMap[nextStyle]
        local mixin = StyleBuilder:GetStyleMixin(nextStyle)
        if not mixin then
            error("BarManager:SetStyle: Unknown style key: " .. tostring(nextStyle))
        end

        frame = StyleBuilder:CreateFrameForStyle(nextStyle, mixin.__xpbar_config or {}, templateName)
        self.barFrames[nextStyle] = frame
        Addon.UI.Views[nextStyle] = frame
    else
        if nextFrame and nextFrame.Show then
            nextFrame:Show()
        end
    end

    self.currentStyle = nextStyle

    -- Apply the lock setting to the new view and to all cached views
    self:UpdateLockedState()

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

-- Update locked state on the current view (e.g., lock/unlock drag on flat style)
function BarManager:UpdateLockedState()
    self.barFrames = self.barFrames or {}

    -- If a given frame implements UpdateLockedState, call it to ensure it applies lock/unlock
    for key, frame in pairs(self.barFrames) do
        if frame and frame.UpdateLockedState then
            pcall(
                function()
                    frame:UpdateLockedState()
                end
            )
        else
            -- Fallback: if the frame supports SetDraggable/SetMovable or a SetLocked helper, try those
            if frame and frame.SetLocked then
                pcall(
                    function()
                        frame:SetLocked(Addon.db and Addon.db.locked or false)
                    end
                )
            end
            if frame and frame.SetMovable and frame.SetUserPlaced then
                pcall(
                    function()
                        local locked = Addon.db and Addon.db.locked or false
                        frame:SetMovable(not locked)
                    end
                )
            end
        end
    end

    -- Broadcast update so styles that are not currently cached can react
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
        return true
    end

    return true
end

-- Public helper to toggle or set the locked state across all styles
function BarManager:SetLocked(locked)
    if Addon.db == nil then
        Addon.db = {}
    end
    Addon.db.locked = (locked == true)
    self:UpdateLockedState()
    return Addon.db.locked
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
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        pcall(
            function()
                Addon.QuestXPService:InvalidateQuestCache()
            end
        )
        return true
    end
    return false
end

function BarManager:OnLevelUp()
    -- Invalidate quest XP cache and notify listeners
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        pcall(
            function()
                Addon.QuestXPService:InvalidateQuestCache()
            end
        )
    end

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
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
