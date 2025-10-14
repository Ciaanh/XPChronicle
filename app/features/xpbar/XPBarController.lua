local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Features = Addon.App.Features or {}

local SessionService = Addon.App.Services.SessionService
local QuestXPService = Addon.App.Services.QuestXPService
local EventBus = XPC_EventBus
local EventTypes = XPC_EventTypes

local controller = {}

function controller:GetView()
    return Addon.UI.Views.XPBar
end

-- Load bar style from SavedVariables on initialization

function controller:Initialize()
    local view = self:GetView()
    if view and view.Initialize then
        view:Initialize(self)
    end

    self:RegisterQuestEvents()
    
    -- Ensure both bars are hidden initially, then show the correct one
    if view and view.legacyContainer and view.flatContainer then
        view.legacyContainer:Hide()
        view.flatContainer:Hide()
    end
    
    -- Apply saved bar style
    self:ApplyBarStyle()
    
    self:Update()
    
    -- Start centralized periodic update timer
    self:StartPeriodicUpdates()
end

-- Centralized periodic update timer - orchestrates all time-sensitive updates
function controller:StartPeriodicUpdates()
    -- Cancel any existing timer
    if self.periodicUpdateTimer then
        self.periodicUpdateTimer:Cancel()
        self.periodicUpdateTimer = nil
    end
    
    -- Update every 5 seconds for all time-sensitive displays
    self.periodicUpdateTimer = C_Timer.NewTicker(5, function()
        if not self then return end
        
        local view = self:GetView()
        if not view then return end
        
        -- Get active bar (legacy or flat)
        local activeBar = nil
        if view.legacyContainer and view.legacyContainer:IsShown() and view.legacyContainer.Bar then
            activeBar = view.legacyContainer.Bar
        elseif view.flatContainer and view.flatContainer:IsShown() and view.flatContainer.Bar then
            activeBar = view.flatContainer.Bar
        end
        
        if activeBar then
            -- Update time-sensitive text displays
            if activeBar.UpdateRateText then
                activeBar:UpdateRateText()
            end
            if activeBar.UpdateSessionText then
                activeBar:UpdateSessionText()
            end
        end
    end)
end

-- Stop the periodic update timer
function controller:StopPeriodicUpdates()
    if self.periodicUpdateTimer then
        self.periodicUpdateTimer:Cancel()
        self.periodicUpdateTimer = nil
    end
end

-- Apply bar style from saved settings
function controller:ApplyBarStyle()
    local db = Addon.db or {}
    local style = db.barStyle or "legacy"  -- Default to legacy
    self:SetBarStyle(style, true)  -- skipSave = true (already in db)
end

-- Set bar style (none/legacy/flat)
function controller:SetBarStyle(style, skipSave)
    local view = self:GetView()
    if not view then 
        error("XPBarController: View is NIL!")
        return 
    end
    
    -- Get Blizzard bar control
    local BlizzardBarControl = Addon.UI and Addon.UI.BlizzardBarControl
    if not BlizzardBarControl then
        error("XPBarController: BlizzardBarControl is NIL!")
        return
    end
    
    -- Validate style
    if style ~= "none" and style ~= "legacy" and style ~= "flat" then
        error("XPBarController: Invalid style: " .. tostring(style))
        return
    end
    
    -- Hide all OUR bars first
    if view.legacyContainer then
        view.legacyContainer:Hide()
    end
    
    if view.flatContainer then
        view.flatContainer:Hide()
    end
    
    -- Apply style-specific behavior
    if style == "none" then
        -- None: ALWAYS show Blizzard bar (ignore hideBlizzardBar setting)
        BlizzardBarControl:Show()
        
    elseif style == "legacy" then
        -- Legacy: Hide Blizzard bar ALWAYS, show Legacy bar at fixed position
        BlizzardBarControl:Hide()
        
        if view.legacyContainer then
            view.legacyContainer:Show()
        end
        
    elseif style == "flat" then
        -- Flat: Show Flat bar (draggable), Blizzard bar depends on setting
        
        if view.flatContainer then
            view.flatContainer:Show()
        end
        
        -- Blizzard bar visibility based on user preference
        local db = Addon.db or {}
        if db.hideBlizzardBar then
            BlizzardBarControl:Hide()
        else
            BlizzardBarControl:Show()
        end
        
        -- Update locked state for Flat bar
        self:UpdateLockedState()
    end
    
    -- Apply Blizzard bar visibility settings (handles .Show method restoration)
    if view.ApplyDefaultXPBarVisibility then
        view:ApplyDefaultXPBarVisibility()
    end
    
    -- Save preference (unless this is initial load)
    if not skipSave then
        local previousStyle = Addon.db.barStyle
        Addon.db.barStyle = style
        
        -- Publish BAR_STYLE_CHANGED event
        if EventBus and EventTypes then
            EventBus:Publish(EventTypes.BAR_STYLE_CHANGED, {
                newStyle = style,
                previousStyle = previousStyle,
            })
        end
    end
    
    -- Update the visible bar
    if style ~= "none" then
        self:Update()
    end
end

-- Toggle Blizzard bar visibility (only applies in Flat mode)
function controller:SetBlizzardBarVisibility(visible)
    local db = Addon.db or {}
    
    -- Only applies in Flat mode
    if db.barStyle ~= "flat" then
        return
    end
    
    -- Get Blizzard bar control
    local BlizzardBarControl = Addon.UI and Addon.UI.BlizzardBarControl
    if not BlizzardBarControl then
        return
    end
    
    -- Save setting (inverted: visible = false means hideBlizzardBar = true)
    db.hideBlizzardBar = not visible
    
    -- Apply immediately
    if visible then
        BlizzardBarControl:Show()
    else
        BlizzardBarControl:Hide()
    end
end

-- Update text display on all visible bars
function controller:UpdateTextDisplay()
    local view = self:GetView()
    if not view then return end
    
    -- Update Legacy bar if visible
    if view.legacyContainer and view.legacyContainer:IsShown() then
        local bar = view.legacyContainer.Bar
        if bar and bar.UpdateTextVisibility then
            bar:UpdateTextVisibility()
            if bar.UpdateAllText then
                bar:UpdateAllText()
            end
        end
    end
    
    -- Update Flat bar if visible
    if view.flatContainer and view.flatContainer:IsShown() then
        local bar = view.flatContainer.Bar
        if bar and bar.UpdateTextVisibility then
            bar:UpdateTextVisibility()
            if bar.UpdateAllText then
                bar:UpdateAllText()
            end
        end
    end
end

-- Update animation settings on all visible bars
function controller:UpdateAnimationSettings()
    -- Animations are read from GetAnimationConfig() which reads from db
    -- The next animation will use the new settings automatically
end

-- Update quest overlays on all visible bars
function controller:UpdateQuestOverlays()
    local view = self:GetView()
    if not view then return end
    
    -- Update Legacy bar if visible
    if view.legacyContainer and view.legacyContainer:IsShown() then
        local bar = view.legacyContainer.Bar
        if bar and bar.UpdateQuestOverlays then
            bar:UpdateQuestOverlays()
        end
    end
    
    -- Update Flat bar if visible
    if view.flatContainer and view.flatContainer:IsShown() then
        local bar = view.flatContainer.Bar
        if bar and bar.UpdateQuestOverlays then
            bar:UpdateQuestOverlays()
        end
    end
end

-- Reset all XP bar settings to defaults
function controller:ResetToDefaults()
    local db = Addon.db
    local defaults = Addon.defaults
    
    if not db or not defaults then
        return
    end
    
    -- Bar style
    db.barStyle = defaults.barStyle
    
    -- Text display
    db.showPercentage = defaults.showPercentage
    db.showQuestXP = defaults.showQuestXP
    db.showQuestPercent = defaults.showQuestPercent
    db.showXPPerHourText = defaults.showXPPerHourText
    db.showLevelTimeText = defaults.showLevelTimeText
    db.showSessionTimeText = defaults.showSessionTimeText
    db.abbreviateNumbers = defaults.abbreviateNumbers
    db.showLevelText = defaults.showLevelText
    db.showXPText = defaults.showXPText
    
    -- Animations
    db.enableAnimations = defaults.enableAnimations
    db.animationSpeed = defaults.animationSpeed
    db.animationEasing = defaults.animationEasing
    db.flashOnGain = defaults.flashOnGain
    db.pauseOnHover = defaults.pauseOnHover
    
    -- Quest overlays
    db.questOverlaysEnabled = defaults.questOverlaysEnabled
    db.showCompleteQuestOverlay = defaults.showCompleteQuestOverlay
    db.showIncompleteQuestOverlay = defaults.showIncompleteQuestOverlay
    
    -- Apply changes
    self:SetBarStyle(db.barStyle)
    self:UpdateTextDisplay()
    self:UpdateQuestOverlays()
end

-- Reset Flat Bar position to default (center)
function controller:ResetFlatBarPosition()
    local view = self:GetView()
    if not view or not view.flatContainer then
        return
    end
    
    local flatContainer = view.flatContainer
    if not flatContainer then
        return
    end
    
    -- Clear saved position
    local db = Addon.db or {}
    db.barPosition = nil
    
    -- Reset to default position from Defaults.lua
    local defaults = Addon.defaults or {}
    local defaultPos = defaults.barPosition or {}
    local point = defaultPos.point or "CENTER"
    local relativeTo = _G[defaultPos.relativeTo] or UIParent
    local relativePoint = defaultPos.relativePoint or "CENTER"
    local x = defaultPos.x or 0
    local y = defaultPos.y or 0
    
    flatContainer:ClearAllPoints()
    flatContainer:SetPoint(point, relativeTo, relativePoint, x, y)
    
    -- Save the default position
    if flatContainer.SavePosition then
        flatContainer:SavePosition()
    end
end

-- Update locked state for Flat Bar
function controller:UpdateLockedState()
    local view = self:GetView()
    if not view or not view.flatContainer then
        return
    end
    
    local flatContainer = view.flatContainer
    if not flatContainer then
        return
    end
    
    local db = Addon.db or {}
    local isLocked = db.barLocked or false
    
    -- Update draggable state on container
    if flatContainer.SetLocked then
        flatContainer:SetLocked(isLocked)
    end
end


function controller:RegisterQuestEvents()
    if self._questEventsRegistered then
        return
    end

    local questEvents = {
        "QUEST_LOG_UPDATE",
        "QUEST_TURNED_IN",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_COMPLETE",
        "QUEST_WATCH_LIST_CHANGED",  -- Changed from TRACKED_QUEST_LIST_CHANGED
    }

    for _, event in ipairs(questEvents) do
        Addon:RegisterEvent(event, function()
            self:OnQuestDataChanged()
        end)
    end

    self._questEventsRegistered = true
end

function controller:OnQuestDataChanged()
    if QuestXPService and QuestXPService.InvalidateCache then
        QuestXPService:InvalidateCache()
    end
    
    -- Publish QUEST_XP_UPDATED event
    if EventBus and EventTypes and QuestXPService then
        local totalXP, completeXP, incompleteXP = QuestXPService:GetQuestXP()
        EventBus:Publish(EventTypes.QUEST_XP_UPDATED, {
            totalQuestXP = totalXP,
            completeQuests = completeXP,
            incompleteQuests = incompleteXP,
            questCount = C_QuestLog.GetNumQuestLogEntries(),
        })
    end
    
    -- Update() removed: Subscribers handle updates via QUEST_XP_UPDATED event
end

function controller:OnEnteringWorld(isInitialLogin, isReload)
    local view = self:GetView()
    if view and view.OnEnteringWorld then
        view:OnEnteringWorld(isInitialLogin, isReload)
    end

    -- Update() removed: Events triggered on world enter will update subscribers
end

function controller:OnXPUpdate()
    -- Refresh session service first
    if SessionService and SessionService.RefreshSessionTimes then
        SessionService:RefreshSessionTimes()
    end
    
    -- Publish XP_CHANGED event
    if EventBus and EventTypes then
        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local level = UnitLevel("player")
        local restedXP = GetXPExhaustion() or 0
        local isRested = restedXP > 0
        
        -- Get previous XP (stored in view state)
        local view = self:GetView()
        local previousXP = 0
        if view and view.legacyContainer and view.legacyContainer.Bar then
            previousXP = view.legacyContainer.Bar.animationState and view.legacyContainer.Bar.animationState.previousXP or 0
        elseif view and view.flatContainer and view.flatContainer.Bar then
            previousXP = view.flatContainer.Bar.animationState and view.flatContainer.Bar.animationState.previousXP or 0
        end
        
        local delta = currentXP - previousXP
        
        EventBus:Publish(EventTypes.XP_CHANGED, {
            currentXP = currentXP,
            maxXP = maxXP,
            previousXP = previousXP,
            delta = delta,
            isRested = isRested,
            level = level,
        })
        
        -- If XP was gained, also publish XP_GAINED event
        if delta > 0 and previousXP > 0 then
            -- Calculate rested bonus (if applicable)
            local restedBonus = 0
            if isRested then
                -- Rested bonus is 200% XP, so the bonus is 100% of the base gain
                restedBonus = delta / 2  -- Approximate
            end
            
            EventBus:Publish(EventTypes.XP_GAINED, {
                amount = delta,
                currentXP = currentXP,
                maxXP = maxXP,
                isRested = isRested,
                restedBonus = restedBonus,
            })
        end
    end
    
    -- Update() removed: Subscribers handle updates via XP_CHANGED/XP_GAINED events
end

function controller:OnLevelUp()
    -- Publish LEVEL_UP event
    if EventBus and EventTypes then
        local newLevel = UnitLevel("player")
        
        EventBus:Publish(EventTypes.LEVEL_UP, {
            newLevel = newLevel,
            previousLevel = newLevel - 1,
            timestamp = time(),
        })
    end
    
    -- Update() removed: Subscribers handle updates via LEVEL_UP event
end

function controller:OnRestedChanged()
    -- Publish RESTED_CHANGED event
    if EventBus and EventTypes then
        local restedXP = GetXPExhaustion() or 0
        local isRested = restedXP > 0
        
        -- Get previous rested state (stored in view state if available)
        local view = self:GetView()
        local wasRested = false
        if view and view.legacyContainer and view.legacyContainer.Bar then
            wasRested = view.legacyContainer.Bar.state and view.legacyContainer.Bar.state.isRested or false
        elseif view and view.flatContainer and view.flatContainer.Bar then
            wasRested = view.flatContainer.Bar.state and view.flatContainer.Bar.state.isRested or false
        end
        
        EventBus:Publish(EventTypes.RESTED_CHANGED, {
            isRested = isRested,
            restedXP = restedXP,
            wasRested = wasRested,
        })
    end
    
    -- Update() removed: Subscribers handle updates via RESTED_CHANGED event
end

function controller:OnTimePlayed(totalTime, levelTime)
    local view = self:GetView()
    if view and view.OnTimePlayed then
        view:OnTimePlayed(totalTime, levelTime)
    end
end

function controller:Update()
    local view = self:GetView()
    if view and view.Update then
        view:Update()
    end
end

function controller:GetQuestXP(forceRefresh)
    if QuestXPService and QuestXPService.GetQuestXP then
        return QuestXPService:GetQuestXP(forceRefresh)
    end
    return 0, 0, 0
end

Addon:RegisterFeature("xpbar", controller)
Addon.App.Features.xpbar = controller
return controller
