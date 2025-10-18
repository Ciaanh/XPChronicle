-- VerticalXPBarMixin.lua
-- Vertical XP bar where new XP "falls down" from the top with gravity animation

---@diagnostic disable: undefined-global, undefined-field, assign-type-mismatch

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

VerticalXPBarMixin = CreateFromMixins(XPBarMixinBase)

---@class VerticalXPBarView : Frame
---@field LevelText FontString
---@field OverlayFrame Frame
---@field XPText FontString
---@field PercentText FontString
---@field RateText FontString
---@field SessionText FontString
---@field QuestSummaryText FontString

---@class VerticalXPBarContainerMixin : Frame
---@field Bar VerticalXPBarView
---@field InitPositionStorage fun(self, getter, setter, defaultsProvider)
---@field EnableDrag fun(self, options)
---@field EnableMouse fun(self, enable)
---@field SetMovable fun(self, movable)
VerticalXPBarContainerMixin = {}

function VerticalXPBarContainerMixin:OnLoad()
    -- Stay hidden until controller shows based on barStyle
    self:Hide()

    -- Ensure Bar child is sized to container
    if self.Bar and self.Bar.SetSize then
        self.Bar:SetSize(self:GetWidth(), self:GetHeight())
    end

    -- Wire text elements (if view provided overlay frames)
    if self.WireTextElements then
        self:WireTextElements()
    end

    -- Setup dragging & position storage (reuse flat bar mixins if available)
    self:SetFrameStrata("LOW")
    self:SetMovable(true)
    self:SetUserPlaced(false)
    self:SetClampedToScreen(true)
    self:EnableMouse(true)

    local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
    local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
    if PositionStoreMixin and DraggableFrameMixin then
        Mixin(self, PositionStoreMixin, DraggableFrameMixin)
        self:InitPositionStorage(
            -- getter
            function()
                if not Addon.db then return nil end
                if Addon.db.barPositions and Addon.db.barPositions.vertical then
                    return Addon.db.barPositions.vertical
                end
                -- fallback for older single-position setting
                return Addon.db.barPosition
            end,
            -- setter
            function(pos)
                if not Addon.db then return end
                Addon.db.barPositions = Addon.db.barPositions or {}
                Addon.db.barPositions.vertical = pos
            end,
            -- defaults provider
            function()
                if Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.vertical then
                    return Addon.defaults.barPositions.vertical
                end
                return Addon.defaults and Addon.defaults.barPosition
            end
        )
        self:EnableDrag({ button = "LeftButton", requireModifier = "SHIFT" })
    else
        -- Retry after login if mixins aren't available yet
        C_Timer.After(1, function()
            if self.RetryDraggingSetup then
                self:RetryDraggingSetup()
            end
        end)
    end
end

function VerticalXPBarContainerMixin:WireTextElements()
    if not self.Bar then return end
    -- If the bar has an OverlayFrame (from XML) wire its fontstrings
    if self.Bar.OverlayFrame then
        self.Bar.LevelText = self.Bar.OverlayFrame.LevelText
        self.Bar.XPText = self.Bar.OverlayFrame.XPText
        self.Bar.PercentText = self.Bar.OverlayFrame.PercentText
    end
end

function VerticalXPBarContainerMixin:OnShow()
    -- Ensure child view gets its text wired (no FullUpdate here)
    self:WireTextElements()
end

function VerticalXPBarContainerMixin:RetryDraggingSetup()
    local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
    local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
    if PositionStoreMixin and DraggableFrameMixin and not self.InitPositionStorage then
        Mixin(self, PositionStoreMixin, DraggableFrameMixin)
        self:InitPositionStorage(
            function()
                if not Addon.db then return nil end
                if Addon.db.barPositions and Addon.db.barPositions.vertical then
                    return Addon.db.barPositions.vertical
                end
                return Addon.db.barPosition
            end,
            function(pos)
                if not Addon.db then return end
                Addon.db.barPositions = Addon.db.barPositions or {}
                Addon.db.barPositions.vertical = pos
            end,
            function()
                if Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.vertical then
                    return Addon.defaults.barPositions.vertical
                end
                return Addon.defaults and Addon.defaults.barPosition
            end
        )
        self:EnableDrag({ button = "LeftButton", requireModifier = "SHIFT" })
    end
end

function VerticalXPBarContainerMixin:SetLocked(locked)
    if locked then
        self:SetMovable(false)
        self.isDraggable = false
    else
        self:SetMovable(true)
        if self.EnableDrag then
            self:EnableDrag({ button = "LeftButton", requireModifier = "SHIFT" })
            self.isDraggable = true
        end
    end
end

---@class VerticalXPBarMixin : XPBarMixinBase
---@field Bar Frame
---@field FilledTexture Texture
---@field RestedOverlay Texture
VerticalXPBarMixin = CreateFromMixins(XPBarMixinBase)
-- Constants
local FALL_DURATION = 0.4  -- Duration of falling animation in seconds
local BOUNCE_HEIGHT = 5    -- Pixels to bounce up on impact
local BOUNCE_DURATION = 0.1 -- Duration of bounce animations
local PARTICLE_COUNT = 8   -- Number of particles on impact

-- Animation easing function (quadratic out - deceleration)
local function EaseOut(progress)
    return 1 - (1 - progress) * (1 - progress)
end

---@param self Frame
function VerticalXPBarMixin:OnLoad()
    -- Ensure addon is loaded
    if not XPBarEnhanced then
        print("VerticalXPBar ERROR: XPBarEnhanced not loaded!")
        return
    end
    
    -- Call base initialization
    if not self.InitializeState then
        print("VerticalXPBar ERROR: InitializeState missing!")
        return
    end
    self:InitializeState()
    
    -- Vertical bar specific setup
    self.orientation = "VERTICAL"
    self.fillDirection = "BOTTOM_TO_TOP"
    
    -- Animation state
    self.isFalling = false
    self.lastXP = 0
    
    -- Create particle pool for impact effects
    self.particlePool = {}
    for i = 1, PARTICLE_COUNT do
        local particle = self:CreateTexture(nil, "OVERLAY")
        particle:SetSize(4, 4)
        particle:SetTexture("Interface\\Buttons\\WHITE8X8")
        particle:SetBlendMode("ADD")
        particle:Hide()
        table.insert(self.particlePool, particle)
    end
    
    -- Setup textures
    self:SetupTextures()
    
    -- Register common events
    if self.RegisterCommonEvents then
        self:RegisterCommonEvents()
    end
end

function VerticalXPBarMixin:OnEvent(event, ...)
    -- Use base handler
    self:HandleEvent(event, ...)
end

function VerticalXPBarMixin:OnMouseUp(button)
    -- Stop dragging if active
    local container = self:GetParent()
    if container and container.isDragging then
        container:StopMovingOrSizing()
        container.isDragging = nil
        if container.SaveStoredPosition then
            container:SaveStoredPosition()
        end
        return
    end

    -- Handle clicks (Alt+Click for options, Ctrl+Click for stats)
    if IsAltKeyDown() then
        if Addon.Options and Addon.Options.Open then
            Addon.Options:Open()
        end
        return
    elseif IsControlKeyDown() then
        if Addon.Stats then
            if Addon.Stats.Toggle then
                Addon.Stats:Toggle()
            elseif Addon.Stats.ToggleWindow then
                Addon.Stats:ToggleWindow()
            end
        end
        return
    end
end

function VerticalXPBarMixin:OnMouseDown(button)
    -- Forward shift+drag to parent container
    local container = self:GetParent()
    if container and IsShiftKeyDown() and button == "LeftButton" then
        if container:IsMovable() and container.isDragging == nil then
            container:StartMoving()
            container.isDragging = true
        end
        return
    end
end

function VerticalXPBarMixin:SetupTextures()
    -- Background (full height)
    if not self.Background then
        self.Background = self:CreateTexture(nil, "BACKGROUND")
    end
    self.Background:SetAllPoints()
    self.Background:SetColorTexture(0, 0, 0, 0.5)
    
    -- Filled texture (current XP - grows from bottom)
    if not self.FilledTexture then
        self.FilledTexture = self:CreateTexture(nil, "ARTWORK")
    end
    self.FilledTexture:SetPoint("BOTTOMLEFT")
    self.FilledTexture:SetPoint("BOTTOMRIGHT")
    self.FilledTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    
    -- Falling texture (animated new XP)
    if not self.FallingTexture then
        self.FallingTexture = self:CreateTexture(nil, "ARTWORK", nil, 1)
    end
    self.FallingTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.FallingTexture:Hide()
    
    -- Rested overlay (on top of filled)
    if not self.RestedOverlay then
        self.RestedOverlay = self:CreateTexture(nil, "ARTWORK", nil, 2)
    end
    self.RestedOverlay:SetPoint("BOTTOMLEFT")
    self.RestedOverlay:SetPoint("BOTTOMRIGHT")
    self.RestedOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.RestedOverlay:SetBlendMode("ADD")
    self.RestedOverlay:SetAlpha(0.3)
    
    -- Border
    if not self.Border then
        self.Border = self:CreateTexture(nil, "OVERLAY")
    end
    self.Border:SetAllPoints()
    self.Border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    self.Border:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- Text elements
    self:SetupTextElements()
end

function VerticalXPBarMixin:SetupTextElements()
    -- Level text (top)
    if not self.LevelText then
        self.LevelText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    self.LevelText:SetPoint("TOP", 0, -10)
    self.LevelText:SetJustifyH("CENTER")
    
    -- Percentage text (center)
    if not self.PercentText then
        self.PercentText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    end
    self.PercentText:SetPoint("CENTER", 0, 0)
    self.PercentText:SetJustifyH("CENTER")
    
    -- XP/hour text (bottom)
    if not self.XPPerHourText then
        self.XPPerHourText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    self.XPPerHourText:SetPoint("BOTTOM", 0, 10)
    self.XPPerHourText:SetJustifyH("CENTER")
end

function VerticalXPBarMixin:UpdateBarFill(currentXP, maxXP)
    if not currentXP or not maxXP or maxXP == 0 then
        return
    end
    
    local barHeight = self:GetHeight()
    local percentage = currentXP / maxXP
    
    -- Check if we gained XP (animate falling)
    if currentXP > self.lastXP and not self.isFalling then
        self:AnimateFallingXP(self.lastXP, currentXP, maxXP)
    else
        -- Direct update (no animation)
        local fillHeight = barHeight * percentage
        self.FilledTexture:SetHeight(fillHeight)
        
        -- Apply color
        local color = Addon.Colors:Get("xpBar")
        self.FilledTexture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    end
    
    self.lastXP = currentXP
    
    -- Update rested overlay
    self:UpdateRestedOverlay(currentXP, maxXP)
end

function VerticalXPBarMixin:AnimateFallingXP(oldValue, newValue, maxValue)
    if self.isFalling then return end
    
    self.isFalling = true
    local barHeight = self:GetHeight()
    local gainedXP = newValue - oldValue
    local segmentHeight = (gainedXP / maxValue) * barHeight
    
    -- Position falling segment at top
    self.FallingTexture:SetWidth(self:GetWidth())
    self.FallingTexture:SetHeight(segmentHeight)
    self.FallingTexture:ClearAllPoints()
    self.FallingTexture:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    
    -- Set color (brighter version of XP bar color)
    local color = Addon.Colors:Get("xpBar")
    self.FallingTexture:SetColorTexture(
        math.min(color.r * 1.3, 1),
        math.min(color.g * 1.3, 1),
        math.min(color.b * 1.3, 1),
        1
    )
    self.FallingTexture:Show()
    
    -- Calculate target position (top of current fill)
    local currentFillHeight = (oldValue / maxValue) * barHeight
    local targetY = -(barHeight - currentFillHeight - segmentHeight)
    
    -- Animate fall
    local startTime = GetTime()
    local startY = 0
    
    self:SetScript("OnUpdate", function(frame, elapsed)
        local elapsedTime = GetTime() - startTime
        local progress = math.min(elapsedTime / FALL_DURATION, 1)
        
        -- Apply easing
        local easedProgress = EaseOut(progress)
        local currentY = startY + (targetY - startY) * easedProgress
        
        -- Update position
        frame.FallingTexture:ClearAllPoints()
        frame.FallingTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, currentY)
        
        -- Check if fall complete
        if progress >= 1 then
            frame:SetScript("OnUpdate", nil)
            frame:OnFallComplete(oldValue, newValue, maxValue)
        end
    end)
end

function VerticalXPBarMixin:OnFallComplete(oldValue, newValue, maxValue)
    -- Hide falling texture
    self.FallingTexture:Hide()
    
    -- Update main fill to new value
    local barHeight = self:GetHeight()
    local percentage = newValue / maxValue
    local fillHeight = barHeight * percentage
    self.FilledTexture:SetHeight(fillHeight)
    
    -- Apply color
    local color = Addon.Colors:Get("xpBar")
    self.FilledTexture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    
    -- Play impact effects
    self:PlayImpactEffect()
    
    -- Bounce animation
    self:PlayBounceAnimation()
    
    self.isFalling = false
end

function VerticalXPBarMixin:PlayImpactEffect()
    -- Scatter particles from impact point
    local barHeight = self:GetHeight()
    local fillHeight = self.FilledTexture:GetHeight()
    local impactY = barHeight - fillHeight
    
    for i, particle in ipairs(self.particlePool) do
        -- Random direction
        local angle = (math.pi * 2) * (i / PARTICLE_COUNT)
        local speed = 50 + math.random() * 30
        local dx = math.cos(angle) * speed
        local dy = math.sin(angle) * speed
        
        -- Position at impact point
        particle:ClearAllPoints()
        particle:SetPoint("CENTER", self, "BOTTOM", 0, fillHeight)
        
        -- Color
        local color = Addon.Colors:Get("xpBar")
        particle:SetVertexColor(color.r, color.g, color.b, 1)
        particle:Show()
        
        -- Animate
        local startTime = GetTime()
        local startX, startY = 0, fillHeight
        
        C_Timer.NewTicker(0.016, function(ticker)
            local elapsed = GetTime() - startTime
            if elapsed > 0.5 then
                particle:Hide()
                ticker:Cancel()
                return
            end
            
            local x = startX + dx * elapsed
            local y = startY + dy * elapsed - (200 * elapsed * elapsed) -- Gravity
            local alpha = 1 - (elapsed / 0.5)
            
            particle:ClearAllPoints()
            particle:SetPoint("CENTER", self, "BOTTOM", x, y)
            particle:SetAlpha(alpha)
        end)
    end
end

function VerticalXPBarMixin:PlayBounceAnimation()
    -- Quick bounce up and settle down
    local originalHeight = self.FilledTexture:GetHeight()
    
    -- Bounce up
    C_Timer.After(0, function()
        self.FilledTexture:SetHeight(originalHeight + BOUNCE_HEIGHT)
    end)
    
    -- Settle back
    C_Timer.After(BOUNCE_DURATION, function()
        self.FilledTexture:SetHeight(originalHeight)
    end)
end

function VerticalXPBarMixin:UpdateRestedOverlay(currentXP, maxXP)
    local restedXP = GetXPExhaustion() or 0
    
    if restedXP > 0 then
        local barHeight = self:GetHeight()
        local currentPercent = currentXP / maxXP
        local restedPercent = math.min((currentXP + restedXP) / maxXP, 1)
        
        local currentHeight = barHeight * currentPercent
        local restedHeight = barHeight * restedPercent
        
        self.RestedOverlay:SetHeight(restedHeight)
        
        -- Apply rested color
        local color = Addon.Colors:Get("xpBarRested")
        self.RestedOverlay:SetColorTexture(color.r, color.g, color.b, 0.3)
        self.RestedOverlay:Show()
    else
        self.RestedOverlay:Hide()
    end
end

function VerticalXPBarMixin:UpdateAllText()
    -- Adjust text for vertical layout
    local level = UnitLevel("player")
    if self.LevelText then
        self.LevelText:SetText(tostring(level))
    end
    
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local percent = (currentXP / maxXP) * 100
    self.PercentText:SetText(string.format("%.1f%%", percent))
    
    -- XP per hour
    if Addon.Session then
        local stats = Addon.Session:GetStats()
        if stats and stats.xpPerHour > 0 then
            self.XPPerHourText:SetText(Addon.Utils.ShortNumber(stats.xpPerHour) .. "/hr")
        else
            self.XPPerHourText:SetText("")
        end
    end
end

function VerticalXPBarMixin:UpdateTextVisibility()
    -- Show/hide based on settings
    local db = Addon.db
    if not db then return end
    
    self.LevelText:SetShown(db.showLevel ~= false)
    self.PercentText:SetShown(db.showPercent ~= false)
    self.XPPerHourText:SetShown(db.showXPRate ~= false)
end

function VerticalXPBarMixin:ApplyBarColor()
    -- Update colors from config
    if self.FilledTexture:IsShown() then
        local color = Addon.Colors:Get("xpBar")
        self.FilledTexture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    end
    
    if self.RestedOverlay:IsShown() then
        local color = Addon.Colors:Get("xpBarRested")
        self.RestedOverlay:SetColorTexture(color.r, color.g, color.b, 0.3)
    end
end

function VerticalXPBarMixin:ApplyLayout(layout)
    -- For vertical bar, we just need to ensure visibility
    -- The actual rendering is done in UpdateBarFill
    if not layout.visible then
        return
    end
    
    local parent = self:GetParent()
    -- Only show the container for the active view; avoid revealing inactive views
    local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
    if activeView == self and parent then
        parent:Show()
    end

    -- Quest overlays not implemented yet for vertical bar
    -- Just update the main bar and rested overlay
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        self:UpdateBarFill(currentXP, maxXP)
    end
end

function VerticalXPBarMixin:UpdateStatusBarValue(ratio)
    -- Override base implementation since we don't use a StatusBar widget
    -- Instead, update our custom vertical display
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        -- Direct update without animation (used during initialization)
        local barHeight = self:GetHeight()
        local fillHeight = barHeight * ratio
        
        if self.FilledTexture then
            self.FilledTexture:SetHeight(fillHeight)
            
            -- Apply color
            local color = Addon.Colors:Get("xpBar")
            self.FilledTexture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        end
        
        self.lastXP = currentXP
        self:UpdateRestedOverlay(currentXP, maxXP)
    end
end

function VerticalXPBarMixin:FullUpdate()
    -- Prevent re-entrant updates for the vertical bar
    if self._isUpdating then
        return
    end
    self._isUpdating = true

    -- Override base to prevent hiding UIParent (since we have no container)
    if not self.state then
        print("VerticalXPBar ERROR: state not initialized!")
        self._isUpdating = nil
        return
    end

    self.state.maxLevel = self:GetEffectiveMaxLevel()

    -- Respect max-level visibility preference for standalone bars
    if self:IsPlayerAtMaxLevel() and (Addon.db and Addon.db.showBarAtMaxLevel == false) then
        self:Hide()
        self._isUpdating = nil
        return
    end

    local parent = self:GetParent()
    -- Only show the container for the active view
    local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
    if activeView == self and parent then
        parent:Show()
    end

    -- Call base update logic
    if not self.UpdateBarDisplay then
        print("VerticalXPBar ERROR: UpdateBarDisplay missing!")
        return
    end
    self:UpdateBarDisplay()

    -- Update visuals if method exists
    if self.UpdateVisuals then
        self:UpdateVisuals()
    end

    -- Set bar to current position instantly (no animation on load/reload)
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local targetRatio = (maxXP > 0) and (currentXP / maxXP) or 0
    self.animationState.currentValue = targetRatio
    self.animationState.targetValue = targetRatio
    self.animationState.previousXP = currentXP
    self:UpdateStatusBarValue(targetRatio)

    -- Update text visibility and content
    self:UpdateTextVisibility()
    self:UpdateAllText()
    self._isUpdating = nil
end

function VerticalXPBarMixin:UpdateBarDisplay()
    -- Override base to prevent hiding UIParent
    if not self.IsPlayerAtMaxLevel or not self.CalculateBarState or not self.CalculateBarLayout then
        print("VerticalXPBar ERROR: Missing required methods!")
        return
    end

    self.state.maxLevel = self:GetEffectiveMaxLevel()
    
    -- Check if at max level and should hide
    local atMaxLevel = self:IsPlayerAtMaxLevel()
    local showAtMax = Addon.db and Addon.db.showBarAtMaxLevel ~= false
    
    if atMaxLevel and not showAtMax then
        self:Hide()  -- Hide SELF, not parent
        self._isUpdating = nil
        return
    end

    local parent = self:GetParent()
    -- Only show the container for the active view
    local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
    if activeView == self and parent then
        parent:Show()
    end
    
    -- Calculate what to show (state)
    local state = self:CalculateBarState()
    
    -- Store state
    self.state.currentXP = state.currentXP
    self.state.maxXP = state.maxXP
    self.state.restedXP = state.restedXP
    self.state.level = state.level
    self.state.isRested = (state.restedXP and state.restedXP > 0) or false
    
    -- Calculate layout
    local layout = self:CalculateBarLayout(state)
    
    -- Apply to UI
    self:ApplyLayout(layout)
end

function VerticalXPBarMixin:OnShow()
    if not self._isUpdating then
        self:FullUpdate()
    end
end

function VerticalXPBarMixin:Initialize()
    -- Initialize last XP value
    self.lastXP = UnitXP("player")
    
    -- Initial update
    self:FullUpdate()
end

-- Export
Addon.VerticalXPBarMixin = VerticalXPBarMixin
