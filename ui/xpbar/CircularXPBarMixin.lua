-- CircularXPBarMixin.lua
-- Circular progress ring that fills clockwise from top (12 o'clock position)

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

---@class CircularXPBarMixin : XPBarMixinBase
CircularXPBarMixin = CreateFromMixins(XPBarMixinBase)

-- Constants
local RING_SEGMENTS = 60        -- Number of segments for smooth arc
local RING_THICKNESS = 0.15     -- Ring thickness as percentage of radius (0-1)
local GLOW_DURATION = 0.5       -- Duration of glow pulse on XP gain
local ARC_SMOOTH_DURATION = 0.3 -- Duration of arc fill animation

---@param self Frame
function CircularXPBarMixin:OnLoad()
    -- Ensure addon is loaded
    if not XPBarEnhanced then
        print("CircularXPBar ERROR: XPBarEnhanced not loaded!")
        return
    end
    
    -- Call base initialization
    if not self.InitializeState then
        print("CircularXPBar ERROR: InitializeState missing!")
        return
    end
    self:InitializeState()
    
    -- Circular bar specific setup
    self.orientation = "CIRCULAR"
    self.segments = {}
    self.restedSegments = {}
    self.lastProgress = 0
    self.targetProgress = 0
    self.isAnimating = false
    
    -- Create ring segments
    self:CreateRingSegments()
    
    -- Setup center content
    self:SetupCenterContent()
    
    -- Register common events
    if self.RegisterCommonEvents then
        self:RegisterCommonEvents()
    end
end

function CircularXPBarMixin:OnEvent(event, ...)
    -- Use base handler
    self:HandleEvent(event, ...)
end

function CircularXPBarMixin:OnMouseUp(button)
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

function CircularXPBarMixin:CreateRingSegments()
    local radius = math.min(self:GetWidth(), self:GetHeight()) / 2
    local innerRadius = radius * (1 - RING_THICKNESS)
    local centerX, centerY = self:GetWidth() / 2, self:GetHeight() / 2
    
    -- Create XP segments
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(4, radius - innerRadius)
        segment:Hide()
        self.segments[i] = segment
    end
    
    -- Create rested segments (slightly transparent, on top)
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK", nil, 1)
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(4, radius - innerRadius)
        segment:SetBlendMode("ADD")
        segment:SetAlpha(0.3)
        segment:Hide()
        self.restedSegments[i] = segment
    end
    
    -- Create background ring
    if not self.BackgroundRing then
        self.BackgroundRing = self:CreateTexture(nil, "BACKGROUND")
        self.BackgroundRing:SetAllPoints()
        self.BackgroundRing:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.BackgroundRing:SetColorTexture(0, 0, 0, 0.3)
    end
    
    -- Position segments in circle
    self:PositionSegments()
end

function CircularXPBarMixin:PositionSegments()
    local radius = math.min(self:GetWidth(), self:GetHeight()) / 2
    local innerRadius = radius * (1 - RING_THICKNESS)
    local centerX, centerY = self:GetWidth() / 2, self:GetHeight() / 2
    local avgRadius = (radius + innerRadius) / 2
    
    for i = 1, RING_SEGMENTS do
        -- Angle in radians (start from top, go clockwise)
        -- 0 degrees = top (12 o'clock) = -90 degrees in standard coordinates
        local angle = ((i - 1) / RING_SEGMENTS) * (2 * math.pi) - (math.pi / 2)
        
        -- Calculate position
        local x = centerX + math.cos(angle) * avgRadius
        local y = centerY + math.sin(angle) * avgRadius
        
        -- Position XP segment
        local segment = self.segments[i]
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
        
        -- Rotate segment to point toward center
        -- Note: WoW doesn't support rotation on textures directly
        -- We'll use SetTexCoord to simulate rotation effect
        local rotation = angle + math.pi / 2
        self:RotateTexture(segment, rotation)
        
        -- Position rested segment
        local restedSegment = self.restedSegments[i]
        restedSegment:ClearAllPoints()
        restedSegment:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
        self:RotateTexture(restedSegment, rotation)
    end
end

function CircularXPBarMixin:RotateTexture(texture, rotation)
    -- Simplified rotation using SetTexCoord
    -- This is a basic implementation; full rotation requires more complex math
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    
    -- For now, just use default texcoords
    -- Full rotation implementation would calculate UL, LL, UR, LR corners
    texture:SetTexCoord(0, 1, 0, 1)
end

function CircularXPBarMixin:SetupCenterContent()
    -- Create center background
    if not self.CenterBG then
        self.CenterBG = self:CreateTexture(nil, "BACKGROUND", nil, 1)
        self.CenterBG:SetSize(self:GetWidth() * 0.5, self:GetHeight() * 0.5)
        self.CenterBG:SetPoint("CENTER")
        self.CenterBG:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.CenterBG:SetColorTexture(0, 0, 0, 0.7)
    end
    
    -- Level text (large, center-top)
    if not self.LevelText then
        self.LevelText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    end
    self.LevelText:SetPoint("CENTER", 0, 15)
    self.LevelText:SetJustifyH("CENTER")
    
    -- Percentage text (center)
    if not self.PercentText then
        self.PercentText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    end
    self.PercentText:SetPoint("CENTER", 0, -5)
    self.PercentText:SetJustifyH("CENTER")
    
    -- XP per hour text (small, center-bottom)
    if not self.XPPerHourText then
        self.XPPerHourText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    self.XPPerHourText:SetPoint("CENTER", 0, -25)
    self.XPPerHourText:SetJustifyH("CENTER")
end

function CircularXPBarMixin:UpdateBarFill(currentXP, maxXP)
    if not currentXP or not maxXP or maxXP == 0 then
        return
    end
    
    local progress = currentXP / maxXP
    
    -- Animate arc fill if progress increased
    if progress > self.lastProgress and not self.isAnimating then
        self.targetProgress = progress
        self:AnimateArcFill()
    else
        -- Direct update
        self:SetArcProgress(progress)
        self.lastProgress = progress
    end
    
    -- Update rested arc
    self:UpdateRestedArc(currentXP, maxXP)
end

function CircularXPBarMixin:AnimateArcFill()
    if self.isAnimating then return end
    
    self.isAnimating = true
    local startProgress = self.lastProgress
    local targetProgress = self.targetProgress
    local startTime = GetTime()
    
    self:SetScript("OnUpdate", function(frame, elapsed)
        local elapsedTime = GetTime() - startTime
        local animProgress = math.min(elapsedTime / ARC_SMOOTH_DURATION, 1)
        
        -- Ease out
        local easedProgress = 1 - (1 - animProgress) * (1 - animProgress)
        local currentProgress = startProgress + (targetProgress - startProgress) * easedProgress
        
        frame:SetArcProgress(currentProgress)
        
        if animProgress >= 1 then
            frame:SetScript("OnUpdate", nil)
            frame.lastProgress = targetProgress
            frame.isAnimating = false
            frame:PlayGlowPulse()
        end
    end)
end

function CircularXPBarMixin:SetArcProgress(progress)
    -- Calculate how many segments to show
    local segmentsToShow = math.floor(progress * RING_SEGMENTS + 0.5)
    
    -- Get XP bar color
    local color = Addon.Colors:Get("xpBar")
    
    -- Update segment visibility
    for i = 1, RING_SEGMENTS do
        if i <= segmentsToShow then
            self.segments[i]:SetColorTexture(color.r, color.g, color.b, color.a or 1)
            self.segments[i]:Show()
        else
            self.segments[i]:Hide()
        end
    end
end

function CircularXPBarMixin:UpdateRestedArc(currentXP, maxXP)
    local restedXP = GetXPExhaustion() or 0
    
    if restedXP > 0 then
        local currentProgress = currentXP / maxXP
        local restedProgress = math.min((currentXP + restedXP) / maxXP, 1)
        
        local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
        local restedSegment = math.floor(restedProgress * RING_SEGMENTS)
        
        -- Get rested color
        local color = Addon.Colors:Get("xpBarRested")
        
        -- Show rested segments
        for i = 1, RING_SEGMENTS do
            if i > currentSegment and i <= restedSegment then
                self.restedSegments[i]:SetColorTexture(color.r, color.g, color.b, 1)
                self.restedSegments[i]:Show()
            else
                self.restedSegments[i]:Hide()
            end
        end
    else
        -- Hide all rested segments
        for i = 1, RING_SEGMENTS do
            self.restedSegments[i]:Hide()
        end
    end
end

function CircularXPBarMixin:PlayGlowPulse()
    -- Pulse the ring brightness briefly
    local originalAlpha = {}
    for i = 1, RING_SEGMENTS do
        if self.segments[i]:IsShown() then
            originalAlpha[i] = self.segments[i]:GetAlpha()
        end
    end
    
    -- Glow up
    C_Timer.After(0, function()
        for i = 1, RING_SEGMENTS do
            if self.segments[i]:IsShown() then
                self.segments[i]:SetAlpha(1)
            end
        end
    end)
    
    -- Fade back
    C_Timer.After(GLOW_DURATION / 2, function()
        for i = 1, RING_SEGMENTS do
            if self.segments[i]:IsShown() and originalAlpha[i] then
                self.segments[i]:SetAlpha(originalAlpha[i])
            end
        end
    end)
end

function CircularXPBarMixin:UpdateAllText()
    -- Level
    local level = UnitLevel("player")
    self.LevelText:SetText(level)
    
    -- Percentage
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

function CircularXPBarMixin:UpdateTextVisibility()
    -- Show/hide based on settings
    local db = Addon.db
    if not db then return end
    
    self.LevelText:SetShown(db.showLevel ~= false)
    self.PercentText:SetShown(db.showPercent ~= false)
    self.XPPerHourText:SetShown(db.showXPRate ~= false)
end

function CircularXPBarMixin:ApplyBarColor()
    -- Reapply colors to all visible segments
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        local progress = currentXP / maxXP
        self:SetArcProgress(progress)
        self:UpdateRestedArc(currentXP, maxXP)
    end
end

function CircularXPBarMixin:ApplyLayout(layout)
    -- For circular bar, we just need to ensure visibility
    -- The actual rendering is done in UpdateBarFill
    if not layout.visible then
        self:Hide()
        return
    end
    
    -- Quest overlays not implemented yet for circular bar
    -- Just update the main ring and rested arc
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        self:UpdateBarFill(currentXP, maxXP)
    end
end

function CircularXPBarMixin:UpdateStatusBarValue(ratio)
    -- Override base implementation since we don't use a StatusBar widget
    -- Instead, update our custom circular display
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        -- Direct update without animation (used during initialization)
        self:SetArcProgress(ratio)
        self.lastProgress = ratio
        self.targetProgress = ratio
        self:UpdateRestedArc(currentXP, maxXP)
    end
end

function CircularXPBarMixin:FullUpdate()
    -- Override base to prevent hiding UIParent (since we have no container)
    if not self.state then
        print("CircularXPBar ERROR: state not initialized!")
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
        print("CircularXPBar ERROR: UpdateBarDisplay missing!")
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

function CircularXPBarMixin:UpdateBarDisplay()
    -- Override base to prevent hiding UIParent
    if not self.IsPlayerAtMaxLevel or not self.CalculateBarState or not self.CalculateBarLayout then
        print("CircularXPBar ERROR: Missing required methods!")
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

function CircularXPBarMixin:OnShow()
    self:FullUpdate()
end

function CircularXPBarMixin:Initialize()
    -- Initialize progress
    self.lastProgress = UnitXP("player") / UnitXPMax("player")
    self.targetProgress = self.lastProgress
    
    -- Initial update
    self:FullUpdate()
end

-- Export
Addon.CircularXPBarMixin = CircularXPBarMixin
