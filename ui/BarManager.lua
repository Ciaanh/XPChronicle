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

function BarManager:Initialize()
    Addon.UI = Addon.UI or {}
    Addon.UI.Views = Addon.UI.Views or {}
    Addon.UI.Views.XPBar = self

    local db = Addon.db or {}
    local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    local style = db.barStyle or defaultStyle

    self:SetStyle(style, true)

    if db.hideBlizzardBar then
        self:ApplyDefaultXPBarVisibility()
    end
end

function BarManager:ApplyDefaultXPBarVisibility()
    local db = Addon.db or {}
    if db.hideBlizzardBar and self.currentStyle == "flat" then
        if _G.MainMenuExpBar and _G.MainMenuExpBar.Hide then
            _G.MainMenuExpBar:Hide()
        end
        if _G.MainStatusTrackingBarContainer and _G.MainStatusTrackingBarContainer.Hide then
            _G.MainStatusTrackingBarContainer:Hide()
        end
    else
        if _G.MainMenuExpBar and _G.MainMenuExpBar.Show then
            _G.MainMenuExpBar:Show()
        end
        if _G.MainStatusTrackingBarContainer and _G.MainStatusTrackingBarContainer.Show then
            _G.MainStatusTrackingBarContainer:Show()
        end
    end
end

function BarManager:SetStyle(style, skipSave)
    if not style or type(style) ~= "string" then
        style = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    end
    local curStyle = self.currentStyle
    if curStyle == style then
        return
    end
    if self.currentFrame and self.currentFrame.Hide then
        pcall(
            function()
                self.currentFrame:Hide()
            end
        )
    end
    self.frames = self.frames or {}
    local frame = self.frames[style]
    if not frame then
        local templateName = StyleTemplateNameMap[style]
        if not frame and StyleBuilder and StyleBuilder.CreateFrameForStyle then
            local mixin = StyleBuilder:GetStyleMixin(style)
            if not mixin then
                style = (Addon.defaults and Addon.defaults.barStyle) or "classic"
                mixin = StyleBuilder:GetStyleMixin(style)
            end
            frame = StyleBuilder:CreateFrameForStyle(style, mixin.__xpbar_config or {}, templateName)
        end
        -- if frame and frame.OnLoad then
        --     pcall(
        --         function()
        --             frame:OnLoad()
        --         end
        --     )
        -- end
        self.frames[style] = frame
    end
    if frame and frame.Show then
        pcall(
            function()
                frame:Show()
            end
        )
    end
    Addon.UI.Views = Addon.UI.Views or {}
    Addon.UI.Views[style] = frame
    self.currentStyle = style
    self.currentFrame = frame
    if not skipSave and Addon.db then
        Addon.db.barStyle = style
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, {reason = "SET_STYLE", style = style})
    end
    if Addon.db and Addon.db.hideBlizzardBar then
        self:ApplyDefaultXPBarVisibility()
    end
end

function BarManager:GetCurrentStyle()
    return self.currentStyle
end

-- Helper: return the flat view frame if it exists
function BarManager:GetFlatView()
    -- Prioritize frames table, then Addon.UI.Views
    self.frames = self.frames or {}
    local flat = self.frames.flat or (Addon.UI and Addon.UI.Views and Addon.UI.Views.flat)
    return flat
end

-- Reset position for the flat view, clearing saved position and restoring defaults
function BarManager:ResetFlatBarPosition()
    local flat = self:GetFlatView()
    if flat then
        if flat.ResetPosition then
            pcall(
                function()
                    flat:ResetPosition()
                end
            )
            return true
        elseif flat.ClearSavedPosition and flat.SetDefaultDraggablePosition then
            pcall(
                function()
                    flat:ClearSavedPosition()
                    flat:SetDefaultDraggablePosition()
                end
            )
            return true
        end
    end
    return false
end

-- Trigger a full update (broadcast) across views
function BarManager:Update(ctx)
    ctx =
        ctx or
        (XPBarContextBuilder and XPBarContextBuilder.BuildContext and
            XPBarContextBuilder.BuildContext("BROADCAST_UPDATE"))
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
        return true
    elseif self.currentFrame and self.currentFrame.Update then
        pcall(
            function()
                self.currentFrame:Update()
            end
        )
        return true
    end
    return false
end

-- Update locked state on the current view (e.g., lock/unlock drag on flat style)
function BarManager:UpdateLockedState()
    if self.currentFrame and self.currentFrame.UpdateLockedState then
        pcall(
            function()
                self.currentFrame:UpdateLockedState()
            end
        )
        return true
    end
    -- Fallback: emit broadcast so views can react
    return self:Update()
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
    return self:Update()
end

-- Lifecycle wrappers (compatibility helpers / convenience)
function BarManager:OnEnteringWorld(isInitialLogin, isReloadingUI)
    -- Invalidate Quest cache and notify listeners
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        pcall(
            function()
                Addon.QuestXPService:InvalidateQuestCache()
            end
        )
    end
    -- Broadcast a full update so views can refresh
    self:Update()
end

function BarManager:OnLevelUp(level)
    -- Invalidate quest XP cache and notify listeners
    if Addon.QuestXPService and Addon.QuestXPService.InvalidateQuestCache then
        pcall(
            function()
                Addon.QuestXPService:InvalidateQuestCache()
            end
        )
    end
    -- Broadcast level-up update
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("PLAYER_LEVEL_UP", level) or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    else
        self:Update(ctx)
    end
end

function BarManager:OnRestedChanged()
    local ctx =
        XPBarContextBuilder and XPBarContextBuilder.BuildContext and
        XPBarContextBuilder.BuildContext("UPDATE_EXHAUSTION") or
        nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    else
        self:Update(ctx)
    end
end

function BarManager:Shutdown()
    -- Hide any frames and perform light cleanup
    self.frames = self.frames or {}
    for style, frame in pairs(self.frames) do
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
        local ctx =
            XPBarContextBuilder and XPBarContextBuilder.BuildContext and XPBarContextBuilder.BuildContext("SHUTDOWN") or
            nil
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, ctx)
    end
end

return BarManager
