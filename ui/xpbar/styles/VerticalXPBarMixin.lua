-- VerticalXPBarMixin.lua
-- Vertical XP bar where new XP "falls down" from the top with gravity animation

local Addon = XPBarEnhanced

local VerticalXPBarMixin = CreateFromMixins(XPBarMixinBase)

-- Bar field declared in core/Types.lua
local VerticalXPBarContainerMixin = CreateFromMixins(DraggableFrameMixin, PositionStoreMixin)

function VerticalXPBarContainerMixin:OnLoad()
    -- Keep container hidden until controller shows it explicitly
    self:Hide()

    -- Ensure Bar child matches container size
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

    self:InitPositionStorage(
        function()
            if not Addon.db then
                return nil
            end
            if Addon.db.barPositions and Addon.db.barPositions.vertical then
                return Addon.db.barPositions.vertical
            end
            -- fallback for older single-position setting
            return Addon.db.barPosition
        end,
        function(pos)
            if not Addon.db then
                return
            end
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
    self:EnableDrag({button = "LeftButton", requireModifier = "SHIFT"})
end

function VerticalXPBarContainerMixin:WireTextElements()
    if not self.Bar then
        return
    end
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

function VerticalXPBarContainerMixin:OnHide()
    if self._dragRetryTimer then
        self._dragRetryTimer:Cancel()
        self._dragRetryTimer = nil
    end
end

function VerticalXPBarContainerMixin:RetryDraggingSetup()
    local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
    local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
    if PositionStoreMixin and DraggableFrameMixin and not self.InitPositionStorage then
        Mixin(self, PositionStoreMixin, DraggableFrameMixin)
        self:InitPositionStorage(
            function()
                if not Addon.db then
                    return nil
                end
                if Addon.db.barPositions and Addon.db.barPositions.vertical then
                    return Addon.db.barPositions.vertical
                end
                return Addon.db.barPosition
            end,
            function(pos)
                if not Addon.db then
                    return
                end
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
        self:EnableDrag({button = "LeftButton", requireModifier = "SHIFT"})
    end
end

function VerticalXPBarContainerMixin:SetLocked(locked)
    if locked then
        self:SetMovable(false)
        self.isDraggable = false
    else
        self:SetMovable(true)
        if self.EnableDrag then
            self:EnableDrag({button = "LeftButton", requireModifier = "SHIFT"})
            self.isDraggable = true
        end
    end
end

-- VerticalXPBarMixin is implemented below; type annotations omitted to avoid analyzer conflicts
-- instance fields: FilledTexture, RestedOverlay (created at runtime)
-- VerticalXPBarMixin already defined above as a local; avoid duplicate assignment
-- Constants
local FALL_DURATION = 0.4 -- Duration of falling animation in seconds
local BOUNCE_HEIGHT = 5 -- Pixels to bounce up on impact
local BOUNCE_DURATION = 0.1 -- Duration of bounce animations
local PARTICLE_COUNT = 8 -- Number of particles on impact

-- Sublevels for draw ordering (vertical bar specific)
local VERTICAL_SUBLEVEL_FILL = 0
local VERTICAL_SUBLEVEL_REST = 1
local VERTICAL_SUBLEVEL_QUEST = 3
local VERTICAL_SUBLEVEL_FALLING = 4

-- Animation easing function (quadratic out - deceleration)
local function EaseOut(progress)
    return 1 - (1 - progress) * (1 - progress)
end

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
    -- Identify style for debugging
    self._barStyle = "Vertical"
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

-- Set display value (override for vertical StatusBar rendering)
-- Blizzard pattern: Bar-specific rendering implementation
function VerticalXPBarMixin:SetDisplayValue(ratio)
    if not self.StatusBar then
        return
    end

    -- Delegate to base UpdateStatusBarValue (already expects ratio)
    self:UpdateStatusBarValue(ratio)
end

function VerticalXPBarMixin:OnEvent(event, ...)
    -- Use base handler
    self:HandleEvent(event, ...)
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
        self.FallingTexture = self:CreateTexture(nil, "ARTWORK", nil, VERTICAL_SUBLEVEL_FALLING)
    end
    self.FallingTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.FallingTexture:Hide()

    -- Rested overlay (behind quest overlays)
    if not self.RestedOverlay then
        self.RestedOverlay = self:CreateTexture(nil, "ARTWORK", nil, VERTICAL_SUBLEVEL_REST)
    end
    self.RestedOverlay:ClearAllPoints()
    self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    self.RestedOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.RestedOverlay:SetBlendMode("ADD")
    self.RestedOverlay:SetAlpha(0.3)

    -- Quest overlays: complete and incomplete (vertical orientation uses heights)
    -- Quest overlays must render above rested overlay
    if not self.QuestOverlayComplete then
        self.QuestOverlayComplete = self:CreateTexture(nil, "ARTWORK", nil, VERTICAL_SUBLEVEL_QUEST)
    end
    self.QuestOverlayComplete:ClearAllPoints()
    self.QuestOverlayComplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    self.QuestOverlayComplete:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    self.QuestOverlayComplete:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.QuestOverlayComplete:Hide()

    if not self.QuestOverlayIncomplete then
        self.QuestOverlayIncomplete = self:CreateTexture(nil, "ARTWORK", nil, VERTICAL_SUBLEVEL_QUEST)
    end
    self.QuestOverlayIncomplete:ClearAllPoints()
    self.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    self.QuestOverlayIncomplete:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    self.QuestOverlayIncomplete:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.QuestOverlayIncomplete:Hide()

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

---Animate a falling XP segment from oldValue to newValue
function VerticalXPBarMixin:AnimateFallingXP(oldValue, newValue, maxValue)
    if self.isFalling then
        return
    end

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

    -- Animate fall using centralized animation task registry (better cleanup and perf).
    -- Uses easing/duration choices guided by `refs/BlizzardInterfaceCode` and
    -- draws on patterns in `refs/Animated addons` for particle movement.
    local xpbar = Addon.XPBar
    local getTime = GetTime
    local math_min = math.min
    local ease = EaseOut
    local startTime = getTime()
    local startY = 0

    -- Use a per-frame OnUpdate to animate the falling segment
    -- Cancel any previous per-frame handler first
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    self:SetScript(
        "OnUpdate",
        function(frame, elapsed)
            local elapsedTime = getTime() - startTime
            local progress = math_min(elapsedTime / FALL_DURATION, 1)
            local easedProgress = ease(progress)
            local currentY = startY + (targetY - startY) * easedProgress
            frame.FallingTexture:ClearAllPoints()
            frame.FallingTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, currentY)
            if progress >= 1 then
                frame:SetScript("OnUpdate", nil)
                frame:OnFallComplete(oldValue, newValue, maxValue)
            end
        end
    )
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
    -- local profiler = Addon.Profiler
    -- if profiler and profiler._enabled then profiler:Start("Vertical.PlayImpactEffect") end
    local barHeight = self:GetHeight()
    local fillHeight = self.FilledTexture:GetHeight()
    local impactY = barHeight - fillHeight

    -- Localize math functions for inner loop
    local pi2 = math.pi * 2
    local math_cos = math.cos
    local math_sin = math.sin
    local math_random = math.random

    for i, particle in ipairs(self.particlePool) do
        -- Random direction
        local angle = pi2 * (i / PARTICLE_COUNT)
        local speed = 50 + math_random() * 30
        local dx = math_cos(angle) * speed
        local dy = math_sin(angle) * speed

        -- Position at impact point
        particle:ClearAllPoints()
        particle:SetPoint("CENTER", self, "BOTTOM", 0, fillHeight)

        -- Color
        local color = Addon.Colors:Get("xpBar")
        particle:SetVertexColor(color.r, color.g, color.b, 1)
        particle:Show()

        -- Animate each particle using the fallback per-particle ticker
        local startTime = GetTime()
        local startX, startY = 0, fillHeight
        local ticker =
            C_Timer.NewTicker(
            0.016,
            function(t)
                local elapsed = GetTime() - startTime
                if elapsed > 0.5 then
                    particle:Hide()
                    t:Cancel()
                    return
                end
                local x = startX + dx * elapsed
                local y = startY + dy * elapsed - (200 * elapsed * elapsed)
                local alpha = 1 - (elapsed / 0.5)
                particle:ClearAllPoints()
                particle:SetPoint("CENTER", self, "BOTTOM", x, y)
                particle:SetAlpha(alpha)
            end
        )
        particle._fallbackTicker = ticker
    end
    if profiler and profiler._enabled then
        profiler:Stop("Vertical.PlayImpactEffect")
    end
end

function VerticalXPBarMixin:PlayBounceAnimation()
    -- Quick bounce up and settle down
    local originalHeight = self.FilledTexture:GetHeight()

    -- Bounce up (cancelable)
    if self._bounceUpTimer then
        self._bounceUpTimer:Cancel()
        self._bounceUpTimer = nil
    end
    self._bounceUpTimer =
        C_Timer.NewTimer(
        0,
        function()
            if not self or not self:IsShown() then
                self._bounceUpTimer = nil
                return
            end
            self.FilledTexture:SetHeight(originalHeight + BOUNCE_HEIGHT)
            self._bounceUpTimer = nil
        end
    )

    -- Settle back (cancelable)
    if self._bounceDownTimer then
        self._bounceDownTimer:Cancel()
        self._bounceDownTimer = nil
    end
    self._bounceDownTimer =
        C_Timer.NewTimer(
        BOUNCE_DURATION,
        function()
            if not self or not self:IsShown() then
                self._bounceDownTimer = nil
                return
            end
            self.FilledTexture:SetHeight(originalHeight)
            self._bounceDownTimer = nil
        end
    )
end

function VerticalXPBarMixin:UpdateRestedOverlay(currentXP, maxXP)
    -- Keep update behavior consistent with UpdateRested() and ApplyLayout:
    -- rested overlay should show only the delta after current XP and any quest overlays
    local restedXP = GetXPExhaustion() or 0
    if not maxXP or maxXP <= 0 then
        if self.RestedOverlay then
            self.RestedOverlay:Hide()
        end
        return
    end

    local questOffset = self.questOffsetForRested or 0
    local available = math.max(0, maxXP - (currentXP or 0) - (questOffset or 0))
    local toShow = math.min(restedXP, available)

    if toShow > 0 then
        local barHeight = self:GetHeight()
        local restedHeight = math.max(1, math.floor((toShow / maxXP) * barHeight))
        local offsetHeight = math.floor(((currentXP + questOffset) / maxXP) * barHeight)

        if self.RestedOverlay then
            self.RestedOverlay:ClearAllPoints()
            self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, offsetHeight)
            self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, offsetHeight)
            self.RestedOverlay:SetHeight(restedHeight)
            local color =
                Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.XpBarRested) or
                Addon.Colors and Addon.Colors:Get("xpBarRested") or
                {r = 0.3, g = 0.6, b = 1.0}
            self.RestedOverlay:SetColorTexture(color.r, color.g, color.b, 0.3)
            self.RestedOverlay:Show()
        end
    else
        if self.RestedOverlay then
            self.RestedOverlay:Hide()
        end
    end
end

-- Compatibility: base calls self:UpdateRested() after computing questOffsetForRested
function VerticalXPBarMixin:UpdateRested()
    local barHeight = self:GetHeight()
    local maxXP = self.state and self.state.maxXP or UnitXPMax("player")
    local currentXP = self.state and self.state.currentXP or UnitXP("player")
    local questOffset = self.questOffsetForRested or 0
    local restedXP = GetXPExhaustion() or (self.state and self.state.restedXP) or 0

    -- Space available after current XP and quest overlays
    local available = math.max(0, (maxXP or 0) - (currentXP or 0) - (questOffset or 0))
    local showRested = restedXP > 0 and available > 0 and maxXP > 0

    if showRested then
        local toShow = math.min(restedXP, available)
        local restedHeight = math.max(1, math.floor((toShow / maxXP) * barHeight))
        local offsetHeight = math.floor(((currentXP + questOffset) / maxXP) * barHeight)

        -- Position and size rested overlay
        if self.RestedOverlay then
            self.RestedOverlay:ClearAllPoints()
            self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, offsetHeight)
            self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, offsetHeight)
            self.RestedOverlay:SetHeight(restedHeight)
            local color = Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.XpBarRested) or {r = 0.3, g = 0.6, b = 1.0}
            self.RestedOverlay:SetColorTexture(color.r, color.g, color.b, 0.3)
            self.RestedOverlay:Show()
        end
    else
        if self.RestedOverlay then
            self.RestedOverlay:Hide()
        end
    end
end

-- Pure helper: compute overlay heights using the shared base helper
function VerticalXPBarMixin:ComputeOverlayHeights(layout, barHeight)
    barHeight = barHeight or (self and self.GetHeight and self:GetHeight()) or 100
    local dims = self:ComputeOverlayDimensions(layout, barHeight)
    return {
        completeHeight = dims.completeSize,
        completeOffset = dims.completeOffset,
        incompleteHeight = dims.incompleteSize,
        incompleteOffset = dims.incompleteOffset,
        restedHeight = dims.restedSize,
        restedOffset = dims.restedOffset
    }
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
    if not db then
        return
    end

    -- Use canonical config keys from Config.lua
    self.LevelText:SetShown(db.showLevelText == true)
    self.PercentText:SetShown(db.showPercentage == true)
    self.XPPerHourText:SetShown(db.showXPPerHourText == true)
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

    -- Render quest overlays for vertical bar using the generic layout
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local barHeight = self:GetHeight()

    if maxXP > 0 then
        -- Update main fill and falling animation
        self:UpdateBarFill(currentXP, maxXP)

        -- Quest complete overlay (stacked on top of current fill)
        if self.QuestOverlayComplete then
            local heights = self:ComputeOverlayHeights(layout, barHeight)
            if layout.questComplete and layout.questComplete.visible and heights.completeHeight > 0 then
                self.QuestOverlayComplete:ClearAllPoints()
                self.QuestOverlayComplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, heights.completeOffset)
                self.QuestOverlayComplete:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, heights.completeOffset)
                self.QuestOverlayComplete:SetHeight(heights.completeHeight)
                local color =
                    Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.QuestComplete) or {r = 1.0, g = 0.59, b = 0.0}
                self.QuestOverlayComplete:SetColorTexture(color.r, color.g, color.b, 0.85)
                self.QuestOverlayComplete:Show()
            else
                self.QuestOverlayComplete:Hide()
            end
        end

        -- Quest incomplete overlay (follows complete overlay)
        if self.QuestOverlayIncomplete then
            local heights = self:ComputeOverlayHeights(layout, barHeight)
            if layout.questIncomplete and layout.questIncomplete.visible and heights.incompleteHeight > 0 then
                self.QuestOverlayIncomplete:ClearAllPoints()
                self.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, heights.incompleteOffset)
                self.QuestOverlayIncomplete:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, heights.incompleteOffset)
                self.QuestOverlayIncomplete:SetHeight(heights.incompleteHeight)
                local color =
                    Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.QuestIncomplete) or {r = 1.0, g = 1.0, b = 0.0}
                self.QuestOverlayIncomplete:SetColorTexture(color.r, color.g, color.b, 0.85)
                self.QuestOverlayIncomplete:Show()
            else
                self.QuestOverlayIncomplete:Hide()
            end
        end

        -- Update rested overlay afterwards so it renders above current fill but behind quest overlays
        -- Use the same ComputeOverlayHeights helper so rest positioning matches quest overlays
        local heights = self:ComputeOverlayHeights(layout, barHeight)
        if self.RestedOverlay then
            if heights.restedHeight and heights.restedHeight > 0 then
                self.RestedOverlay:ClearAllPoints()
                self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, heights.restedOffset)
                self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, heights.restedOffset)
                self.RestedOverlay:SetHeight(heights.restedHeight)
                local color =
                    Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.XpBarRested) or {r = 0.3, g = 0.6, b = 1.0}
                self.RestedOverlay:SetColorTexture(color.r, color.g, color.b, 0.3)
                self.RestedOverlay:Show()
            else
                self.RestedOverlay:Hide()
            end
        end
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
    self._currentRatio = targetRatio
    self.animation.previousXP = currentXP
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
        self:Hide() -- Hide SELF, not parent
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
    -- Register events when this view is shown
    if not self._eventsRegistered and self.RegisterCommonEvents then
        self:RegisterCommonEvents()
    end

    if not self._isUpdating then
        self:FullUpdate()
    end
end

function VerticalXPBarMixin:OnHide()
    -- Cancel any pending drag retry timer
    if self._dragRetryTimer then
        self._dragRetryTimer:Cancel()
        self._dragRetryTimer = nil
    end

    -- Cancel bounce timers
    if self._bounceUpTimer then
        self._bounceUpTimer:Cancel()
        self._bounceUpTimer = nil
    end
    if self._bounceDownTimer then
        self._bounceDownTimer:Cancel()
        self._bounceDownTimer = nil
    end

    -- Cancel any per-frame falling handler
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    if self.FallingTexture then
        self.FallingTexture:Hide()
    end
    self.isFalling = false

    -- Cancel per-particle fallback tickers and clear per-particle OnUpdate handlers
    if self.particlePool then
        for _, particle in ipairs(self.particlePool) do
            if particle._fallbackTicker then
                particle._fallbackTicker:Cancel()
                particle._fallbackTicker = nil
            end
            if type(particle.GetScript) == "function" and particle:GetScript("OnUpdate") then
                particle:SetScript("OnUpdate", nil)
            end
            particle:Hide()
        end
    end
    -- Call base OnHide to perform standard cleanup (timers, event unsubscription)
    if XPBarMixinBase and XPBarMixinBase.OnHide then
        XPBarMixinBase.OnHide(self)
    end
end

function VerticalXPBarMixin:Initialize()
    -- Initialize last XP value
    self.lastXP = UnitXP("player")

    -- Initial update
    self:FullUpdate()
end

-- Export
-- Export mixins into the Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.VerticalXPBarContainerMixin = VerticalXPBarContainerMixin
Addon.Mixins.VerticalXPBarMixin = VerticalXPBarMixin
-- Legacy compatibility
_G.VerticalXPBarContainerMixin = VerticalXPBarContainerMixin
_G.VerticalXPBarMixin = VerticalXPBarMixin
