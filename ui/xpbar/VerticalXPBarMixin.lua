-- VerticalXPBarMixin.lua
-- Vertical XP bar where new XP "falls down" from the top with gravity animation

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

---@class VerticalXPBarMixin : XPBarMixinBase
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
    -- Handle clicks (Alt+Click for options, Ctrl+Click for stats)
    if IsAltKeyDown() then
        if Addon.Options and Addon.Options.Open then
            Addon.Options:Open()
        end
    elseif IsControlKeyDown() then
        if Addon.Stats and Addon.Stats.ToggleWindow then
            Addon.Stats:ToggleWindow()
        end
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
    self.LevelText:SetText(level)
    
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
        self:Hide()
        return
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
    -- Override base to prevent hiding UIParent (since we have no container)
    if not self.state then
        print("VerticalXPBar ERROR: state not initialized!")
        return
    end
    
    local level = UnitLevel("player")

    -- Check if max level - hide SELF, not parent
    if level >= self.state.maxLevel then
        self:Hide()
        return
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
end

function VerticalXPBarMixin:UpdateBarDisplay()
    -- Override base to prevent hiding UIParent
    if not self.IsPlayerAtMaxLevel or not self.CalculateBarState or not self.CalculateBarLayout then
        print("VerticalXPBar ERROR: Missing required methods!")
        return
    end
    
    -- Check if at max level and should hide
    local atMaxLevel = self:IsPlayerAtMaxLevel()
    local showAtMax = Addon.db and Addon.db.showBarAtMaxLevel ~= false
    
    if atMaxLevel and not showAtMax then
        self:Hide()  -- Hide SELF, not parent
        return
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
    self:FullUpdate()
end

function VerticalXPBarMixin:Initialize()
    -- Initialize last XP value
    self.lastXP = UnitXP("player")
    
    -- Initial update
    self:FullUpdate()
end

-- Export
Addon.VerticalXPBarMixin = VerticalXPBarMixin
