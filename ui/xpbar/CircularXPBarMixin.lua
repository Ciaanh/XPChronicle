-- CircularXPBarMixin.lua
-- Circular progress ring that fills clockwise from top (12 o'clock position)

local Addon = XPBarEnhanced

-- OverlayFrame (if present) is wired into the Bar by the container
-- Bar field declared in core/Types.lua
local CircularXPBarContainerMixin = {}

function CircularXPBarContainerMixin:OnLoad()
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

    -- Retry wiring shortly after load (cancelable)
    if self._initTimer1 then
        pcall(function() self._initTimer1:Cancel() end)
        self._initTimer1 = nil
    end
    self._initTimer1 = C_Timer.NewTimer(0.1, function()
        if not self or not self:IsShown() or not self.WireTextElements then
            self._initTimer1 = nil
            return
        end
        self:WireTextElements()
        self._initTimer1 = nil
    end)

    -- Setup dragging & position storage
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
            function()
                if not Addon.db then return nil end
                if Addon.db.barPositions and Addon.db.barPositions.circular then
                    return Addon.db.barPositions.circular
                end
                return Addon.db.barPosition
            end,
            function(pos)
                if not Addon.db then return end
                Addon.db.barPositions = Addon.db.barPositions or {}
                Addon.db.barPositions.circular = pos
            end,
            function()
                if Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.circular then
                    return Addon.defaults.barPositions.circular
                end
                return Addon.defaults and Addon.defaults.barPosition
            end
        )
        self:EnableDrag({ button = "LeftButton", requireModifier = "SHIFT" })
    else
        if self._dragRetryTimer then
            pcall(function() self._dragRetryTimer:Cancel() end)
            self._dragRetryTimer = nil
        end
        self._dragRetryTimer = C_Timer.NewTimer(1, function()
            if not self or not self:IsShown() then
                self._dragRetryTimer = nil
                return
            end
            if self.RetryDraggingSetup then
                self:RetryDraggingSetup()
            end
            self._dragRetryTimer = nil
        end)
    end
end

function CircularXPBarContainerMixin:WireTextElements()
    if not self.Bar then return end
    if self.Bar.OverlayFrame then
        self.Bar.LevelText = self.Bar.OverlayFrame.LevelText
        self.Bar.XPText = self.Bar.OverlayFrame.XPText
        self.Bar.PercentText = self.Bar.OverlayFrame.PercentText
    end
end

function CircularXPBarContainerMixin:OnShow()
    self:WireTextElements()
end

function CircularXPBarContainerMixin:OnHide()
    if self._initTimer1 then
        pcall(function() self._initTimer1:Cancel() end)
        self._initTimer1 = nil
    end
    if self._dragRetryTimer then
        pcall(function() self._dragRetryTimer:Cancel() end)
        self._dragRetryTimer = nil
    end
end

function CircularXPBarContainerMixin:RetryDraggingSetup()
    local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
    local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
    if PositionStoreMixin and DraggableFrameMixin and not self.InitPositionStorage then
        Mixin(self, PositionStoreMixin, DraggableFrameMixin)
        self:InitPositionStorage(
            function()
                if not Addon.db then return nil end
                if Addon.db.barPositions and Addon.db.barPositions.circular then
                    return Addon.db.barPositions.circular
                end
                return Addon.db.barPosition
            end,
            function(pos)
                if not Addon.db then return end
                Addon.db.barPositions = Addon.db.barPositions or {}
                Addon.db.barPositions.circular = pos
            end,
            function()
                if Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.circular then
                    return Addon.defaults.barPositions.circular
                end
                return Addon.defaults and Addon.defaults.barPosition
            end
        )
        self:EnableDrag({ button = "LeftButton", requireModifier = "SHIFT" })
    end
end

function CircularXPBarContainerMixin:SetLocked(locked)
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

local CircularXPBarMixin = CreateFromMixins(XPBarMixinBase)

-- Constants
local RING_SEGMENTS = 60        -- Number of segments for smooth arc
local RING_THICKNESS = 0.15     -- Ring thickness as percentage of radius (0-1)
-- Sublevels used when creating ring textures. Quest overlays should render above rested segments.
local RING_REST_SUBLEVEL = 1
local RING_QUEST_SUBLEVEL = 3
local GLOW_DURATION = 0.5       -- Duration of glow pulse on XP gain
local ARC_SMOOTH_DURATION = 0.3 -- Duration of arc fill animation

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
    -- Identify style for debugging
    self._barStyle = "Circular"
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

function CircularXPBarMixin:OnMouseDown(button)
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
    
    -- Create rested segments (slightly transparent, below quest overlays)
    for i = 1, RING_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK", nil, RING_REST_SUBLEVEL)
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(4, radius - innerRadius)
        segment:SetBlendMode("ADD")
        segment:SetAlpha(0.3)
        segment:Hide()
        self.restedSegments[i] = segment
    end

    -- Create quest overlay segments (complete & incomplete) - render above rested segments
    self.questCompleteSegments = {}
    self.questIncompleteSegments = {}
    for i = 1, RING_SEGMENTS do
        -- Use a higher sub-level so quest overlays always draw above rested overlay
    local qc = self:CreateTexture(nil, "ARTWORK", nil, RING_QUEST_SUBLEVEL)
        qc:SetTexture("Interface\\Buttons\\WHITE8X8")
        qc:SetSize(4, radius - innerRadius)
        qc:Hide()
        self.questCompleteSegments[i] = qc

        local qi = self:CreateTexture(nil, "ARTWORK", nil, RING_QUEST_SUBLEVEL)
        qi:SetTexture("Interface\\Buttons\\WHITE8X8")
        qi:SetSize(4, radius - innerRadius)
        qi:Hide()
        self.questIncompleteSegments[i] = qi
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
    -- local profiler = Addon.Profiler
    -- if profiler and profiler._enabled then profiler:Start("Circular.PositionSegments") end
    local radius = math.min(self:GetWidth(), self:GetHeight()) / 2
    local innerRadius = radius * (1 - RING_THICKNESS)
    local centerX, centerY = self:GetWidth() / 2, self:GetHeight() / 2
    local avgRadius = (radius + innerRadius) / 2
    
    -- Localize heavy math functions for the inner loop
    local math_cos = math.cos
    local math_sin = math.sin
    local math_pi = math.pi
    for i = 1, RING_SEGMENTS do
        -- Angle in radians (start from top, go clockwise)
        -- 0 degrees = top (12 o'clock) = -90 degrees in standard coordinates
        local angle = ((i - 1) / RING_SEGMENTS) * (2 * math_pi) - (math_pi / 2)

        -- Calculate position
        local x = centerX + math_cos(angle) * avgRadius
        local y = centerY + math_sin(angle) * avgRadius
        
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

            -- Position quest overlay segments
            local qc = self.questCompleteSegments[i]
            qc:ClearAllPoints()
            qc:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
            self:RotateTexture(qc, rotation)

            local qi = self.questIncompleteSegments[i]
            qi:ClearAllPoints()
            qi:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
            self:RotateTexture(qi, rotation)
    end
    -- if profiler and profiler._enabled then profiler:Stop("Circular.PositionSegments") end
end

function CircularXPBarMixin:RotateTexture(texture, rotation)
    if not texture then
        return
    end

    -- Use the modern SetRotation API (available in retail WoW)
    -- This is the recommended method from Blizzard for rotating textures
    -- See refs/BlizzardInterfaceCode/docs/TEXTURE_ROTATION.md for details
    if texture.SetRotation then
        texture:SetRotation(rotation)
    else
        -- Fallback for older clients: use SetTexCoord for 90° rotations only
        -- For arbitrary angles, we'll skip rotation on legacy clients
        local degrees = math.deg(rotation)
        local normalized = (degrees % 360 + 360) % 360
        
        if normalized < 45 or normalized >= 315 then
            -- 0 degrees
            texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        elseif normalized >= 45 and normalized < 135 then
            -- 90 degrees
            texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
        elseif normalized >= 135 and normalized < 225 then
            -- 180 degrees
            texture:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0)
        elseif normalized >= 225 and normalized < 315 then
            -- 270 degrees
            texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        end
    end
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
    -- Prefer the global animation task registry for smooth centralized updates.
    -- This follows the guidance in `refs/BlizzardInterfaceCode` for animation timing
    -- and uses patterns from `refs/Animated addons` as implementation examples.
    local xpbar = Addon.XPBar
    local getTime = GetTime
    local math_min = math.min
    local startTime = getTime()

    -- Use a frame OnUpdate to animate the arc fill (frame-driven)
    local fallbackStart = getTime()
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    self:SetScript("OnUpdate", function(frame, elapsed)
        local elapsedTime = getTime() - fallbackStart
        local animProgress = math.min(elapsedTime / ARC_SMOOTH_DURATION, 1)
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

function CircularXPBarMixin:OnHide()
    -- Cancel any running per-frame arc animation
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    self.isAnimating = false

    -- Call base cleanup to cancel timers and unsubscribe events
    if XPBarMixinBase and XPBarMixinBase.OnHide then
        XPBarMixinBase.OnHide(self)
    end
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
        
        -- Show rested segments between current progress and rested progress. Quest
        -- segments are drawn on a higher sublevel so they will be visible above
        -- these rested segments without additional masking logic.
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
    
    -- Glow up (cancelable)
    if self._glowUpTimer then
        pcall(function() self._glowUpTimer:Cancel() end)
        self._glowUpTimer = nil
    end
    self._glowUpTimer = C_Timer.NewTimer(0, function()
        if not self or not self:IsShown() then
            self._glowUpTimer = nil
            return
        end
        for i = 1, RING_SEGMENTS do
            if self.segments[i]:IsShown() then
                self.segments[i]:SetAlpha(1)
            end
        end
        self._glowUpTimer = nil
    end)

    -- Fade back (cancelable)
    if self._glowDownTimer then
        pcall(function() self._glowDownTimer:Cancel() end)
        self._glowDownTimer = nil
    end
    self._glowDownTimer = C_Timer.NewTimer(GLOW_DURATION / 2, function()
        if not self or not self:IsShown() then
            self._glowDownTimer = nil
            return
        end
        for i = 1, RING_SEGMENTS do
            if self.segments[i]:IsShown() and originalAlpha[i] then
                self.segments[i]:SetAlpha(originalAlpha[i])
            end
        end
        self._glowDownTimer = nil
    end)
end

function CircularXPBarMixin:UpdateAllText()
    -- Level
    local level = UnitLevel("player")
        if self.LevelText then
            self.LevelText:SetText(tostring(level))
        end
    
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
    
    -- Use canonical config keys from Config.lua
    self.LevelText:SetShown(db.showLevelText == true)
    self.PercentText:SetShown(db.showPercentage == true)
    self.XPPerHourText:SetShown(db.showXPPerHourText == true)
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
        return
    end
    
    local parent = self:GetParent()
    -- Only show the container for the active view; avoid revealing inactive views
    local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
    if activeView == self and parent then
        parent:Show()
    end

    -- Quest overlays not implemented yet for circular bar
    -- Just update the main ring and rested arc
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    
    if maxXP > 0 then
        self:UpdateBarFill(currentXP, maxXP)
    end

        -- Call UpdateQuestArc to render complete/incomplete segments
        self:UpdateQuestArc(layout)
end

-- Set display value (override for circular rendering)
-- Blizzard pattern: Bar-specific rendering implementation
function CircularXPBarMixin:SetDisplayValue(ratio)
	-- Update circular arc directly (doesn't use StatusBar widget)
	self:SetArcProgress(ratio)
	self.lastProgress = ratio
	self.targetProgress = ratio
	
	-- Update rested overlay (needs actual XP values)
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	if maxXP > 0 then
		self:UpdateRestedArc(currentXP, maxXP)
	end
	
	-- Update quest overlay
	local layout = self._lastLayout or self:CalculateBarLayout(self:CalculateBarState())
	self:UpdateQuestArc(layout)
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
    -- Delegate quest overlay rendering to helper. Use cached layout when available
    local layout = self._lastLayout or self:CalculateBarLayout(self:CalculateBarState())
    self:UpdateQuestArc(layout)
end

-- Pure helper: compute which segment indices should be used for complete and incomplete quest overlays
-- Returns two arrays: completeIndices, incompleteIndices
function CircularXPBarMixin:ComputeQuestSegmentRanges(layout)
    if not layout or not layout.visible then
        return {}, {}
    end
    local currentProgress = layout.current and layout.current.ratio or 0
    local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
    -- Compute counts and ensure visibility for tiny values: if layout marks an overlay as visible
    -- but rounding produces 0 segments, force at least 1 segment so it is visible on the ring.
    local completeCount = 0
    if layout.questComplete and layout.questComplete.visible and (layout.questComplete.ratio or 0) > 0 then
        completeCount = math.max(1, math.floor(layout.questComplete.ratio * RING_SEGMENTS + 0.5))
    end
    local incompleteCount = 0
    if layout.questIncomplete and layout.questIncomplete.visible and (layout.questIncomplete.ratio or 0) > 0 then
        incompleteCount = math.max(1, math.floor(layout.questIncomplete.ratio * RING_SEGMENTS + 0.5))
    end

    -- Clamp to total available segments to avoid overflow
    if completeCount + incompleteCount > RING_SEGMENTS then
        if completeCount >= RING_SEGMENTS then
            completeCount = RING_SEGMENTS
            incompleteCount = 0
        else
            incompleteCount = RING_SEGMENTS - completeCount
        end
    end

    local completeIndices = {}
    local incompleteIndices = {}
    local start = currentSegment + 1
    for j = 0, completeCount - 1 do
        local idx = ((start + j - 1) % RING_SEGMENTS) + 1
        completeIndices[#completeIndices + 1] = idx
    end
    local start2 = start + completeCount
    for j = 0, incompleteCount - 1 do
        local idx = ((start2 + j - 1) % RING_SEGMENTS) + 1
        incompleteIndices[#incompleteIndices + 1] = idx
    end
    return completeIndices, incompleteIndices
end

-- Pure helper: compute which segment indices correspond to the rested overlay
-- Returns array of indices (could overlap with quest indices). This is a pure
-- function and useful for unit tests and layout validation.
function CircularXPBarMixin:ComputeRestSegmentRanges(layout)
    if not layout or not layout.visible or not layout.current or not layout.rested then
        return {}
    end
    local currentProgress = layout.current and layout.current.ratio or 0
    local restedProgress = math.min((currentProgress + (layout.rested and layout.rested.ratio or 0)), 1)
    local currentSegment = math.floor(currentProgress * RING_SEGMENTS)
    local restedSegment = math.floor(restedProgress * RING_SEGMENTS)

    local restIndices = {}
    for j = currentSegment + 1, currentSegment + (restedSegment - currentSegment) do
        if (restedSegment - currentSegment) <= 0 then break end
        local idx = ((j - 1) % RING_SEGMENTS) + 1
        restIndices[#restIndices + 1] = idx
    end
    return restIndices
end

function CircularXPBarMixin:GetRingSublevels()
    return { rest = RING_REST_SUBLEVEL, quest = RING_QUEST_SUBLEVEL }
end

function CircularXPBarMixin:UpdateQuestArc(layout)
    -- If caller didn't provide a layout (e.g. animation-only update), fall back to cached layout
    local effectiveLayout = layout or self._lastLayout
    -- Hide everything if layout is not visible
    if not effectiveLayout or not effectiveLayout.visible then
        for i = 1, RING_SEGMENTS do
            if self.questCompleteSegments and self.questCompleteSegments[i] then self.questCompleteSegments[i]:Hide() end
            if self.questIncompleteSegments and self.questIncompleteSegments[i] then self.questIncompleteSegments[i]:Hide() end
        end
        return
    end

    -- Compute indices for overlays
    local completeIndices, incompleteIndices = self:ComputeQuestSegmentRanges(effectiveLayout)

    -- Hide all first
    for i = 1, RING_SEGMENTS do
        if self.questCompleteSegments[i] then self.questCompleteSegments[i]:Hide() end
        if self.questIncompleteSegments[i] then self.questIncompleteSegments[i]:Hide() end
    end

    -- Show complete segments
    local qcColor = Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.QuestComplete) or { r = 1, g = 0.59, b = 0 }
    for _, idx in ipairs(completeIndices) do
        local seg = self.questCompleteSegments[idx]
        if seg then
            seg:SetColorTexture(qcColor.r, qcColor.g, qcColor.b, 1)
            seg:Show()
        end
    end

    -- Show incomplete segments
    local qiColor = Addon.Colors and Addon.Colors:Get(Addon.Colors.Key.QuestIncomplete) or { r = 1, g = 1, b = 0 }
    for _, idx in ipairs(incompleteIndices) do
        local seg = self.questIncompleteSegments[idx]
        if seg then
            seg:SetColorTexture(qiColor.r, qiColor.g, qiColor.b, 1)
            seg:Show()
        end
    end
end

function CircularXPBarMixin:FullUpdate()
    -- Prevent re-entrant updates for the circular bar
    if self._isUpdating then
        return
    end
    self._isUpdating = true

    -- Override base to prevent hiding UIParent (since we have no container)
    if not self.state then
        print("CircularXPBar ERROR: state not initialized!")
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
    self._currentRatio = targetRatio
    self.animation.previousXP = currentXP
    self:UpdateStatusBarValue(targetRatio)

    -- Update text visibility and content
    self:UpdateTextVisibility()
    self:UpdateAllText()
    self._isUpdating = nil
end

function CircularXPBarMixin:UpdateBarDisplay()
    -- Override base to prevent hiding UIParent
    if not self.IsPlayerAtMaxLevel or not self.CalculateBarState or not self.CalculateBarLayout then
        print("CircularXPBar ERROR: Missing required methods!")
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

function CircularXPBarMixin:OnShow()
    -- Ensure events are registered when shown
    if not self._eventsRegistered and self.RegisterCommonEvents then
        self:RegisterCommonEvents()
    end

    if not self._isUpdating then
        self:FullUpdate()
    end
end

function CircularXPBarMixin:Initialize()
    -- Initialize progress
    self.lastProgress = UnitXP("player") / UnitXPMax("player")
    self.targetProgress = self.lastProgress
    
    -- Initial update
    self:FullUpdate()
end

-- Export
-- Export mixins into the Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.CircularXPBarContainerMixin = CircularXPBarContainerMixin
Addon.Mixins.CircularXPBarMixin = CircularXPBarMixin
-- Legacy compatibility
_G.CircularXPBarContainerMixin = CircularXPBarContainerMixin
_G.CircularXPBarMixin = CircularXPBarMixin
