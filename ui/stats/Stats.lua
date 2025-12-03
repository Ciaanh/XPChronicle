-- XP Bar Enhanced - Stats Module
-- Consolidated from: StatsController.lua + StatsView.lua
-- Manages the stats window displaying level and session statistics

local Addon = XPBarEnhanced
local L = Addon.L or {}

local Stats = {}

--------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------

local SessionService = Addon and Addon.Session
local TimeCalc = Addon and Addon.TimeCalculations
local XPCalc = Addon and Addon.XPCalculations

--------------------------------------------------------------------------------
-- Local caches & helpers
--------------------------------------------------------------------------------

local _G = _G
local UIParent = _G.UIParent
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local time = time
local date = date
local tostring = tostring
local type = type
local math_max = math.max
local math_floor = math.floor
local string_format = string.format

local Utils = Addon and Addon.Utils or {}
Utils.ShortNumber = Utils.ShortNumber or function(v) return tostring(v) end
Utils.FormatDuration = Utils.FormatDuration or function(v) return tostring(v) end

local function SetTextSafe(el, value)
    if el and el.SetText then
        el:SetText(value)
    end
end

--------------------------------------------------------------------------------
-- Frame Mixin (for XML-defined frame)
--------------------------------------------------------------------------------

local StatsFrameMixin = {}
-- Register the mixin under a namespaced table and expose the global
-- alias only for XML mixin resolution.
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Mixins.StatsFrameMixin = StatsFrameMixin
_G.XPBarEnhancedStatsMixin = StatsFrameMixin

local modifierChecks = {
    SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
    CTRL  = function() return IsControlKeyDown and IsControlKeyDown() end,
    ALT   = function() return IsAltKeyDown and IsAltKeyDown() end
}

local function isModifierRequirementMet(requirement)
    if not requirement then return true end

    if type(requirement) == "table" then
        for _, modifier in ipairs(requirement) do
            local check = modifierChecks[string.upper(modifier)]
            if not (check and check()) then
                return false
            end
        end
        return true
    end

    local check = modifierChecks[string.upper(requirement)]
    return check and check()
end

-- Begin: position storage + drag functions embedded into StatsFrameMixin
function StatsFrameMixin:InitPositionStorage(getter, setter, defaultsProvider)
    self._positionStoreGetter = getter
    self._positionStoreSetter = setter
    self._positionStoreDefaultsProvider = defaultsProvider
end

function StatsFrameMixin:GetOrCreatePositionStore()
    if not self.__posStore then
        local getter = self._positionStoreGetter
        if getter then
            self.__posStore = getter() or {}
        else
            self.__posStore = {}
        end
    end
    return self.__posStore
end

function StatsFrameMixin:GetPositionDefaults()
    if self._positionStoreDefaultsProvider then
        return self._positionStoreDefaultsProvider(self)
    end
    -- canonical default
    return {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0, left = 0, top = 0}
end

function StatsFrameMixin:ApplyStoredPosition()
    local stored = self:GetOrCreatePositionStore() or {}
    local defaults = self:GetPositionDefaults() or {}

    -- Backwards compatibility: left/top
    if stored.left ~= nil and stored.top ~= nil then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", stored.left, stored.top)
        return
    end

    local point = stored.point or defaults.point or "CENTER"
    local relativeName = stored.relativeTo or defaults.relativeTo or "UIParent"
    local relativePoint = stored.relativePoint or defaults.relativePoint or point
    local x = stored.x or defaults.x or 0
    local y = stored.y or defaults.y or 0

    local relative = _G[relativeName]
    if not relative or type(relative) ~= "table" then
        relative = UIParent
    end

    self:ClearAllPoints()
    self:SetPoint(point, relative, relativePoint, x, y)
end

function StatsFrameMixin:SaveStoredPosition()
    local store = self:GetOrCreatePositionStore()
    if not store then return end

    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    local left = self.GetLeft and self:GetLeft() or nil
    local top  = self.GetTop and self:GetTop() or nil

    if not point then
        if left == nil or top == nil then return end
    end

    local defaults = self:GetPositionDefaults() or {}
    local toSave = {}

    if left ~= nil and top ~= nil then
        toSave.left = left
        toSave.top = top
    end
    if point then
        toSave.point = point
        toSave.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
        toSave.relativePoint = relativePoint
        toSave.x = x
        toSave.y = y
    end

    -- Clear storage when matching defaults
    if toSave.left ~= nil and toSave.left == defaults.left and toSave.top == defaults.top then
        if self._positionStoreSetter then self._positionStoreSetter(nil) end
        self.__posStore = nil
        return
    end
    if toSave.point and defaults.point and toSave.point == defaults.point and toSave.x == defaults.x and toSave.y == defaults.y then
        if self._positionStoreSetter then self._positionStoreSetter(nil) end
        self.__posStore = nil
        return
    end

    if self._positionStoreSetter then
        self._positionStoreSetter(toSave)
    end
    self.__posStore = toSave
end

function StatsFrameMixin:EnableDrag(options)
    options = options or {}
    local originalStart = options.onDragStart
    local originalStop = options.onDragStop

    options.onDragStart = function(frame, ...)
        if frame.SaveStoredPosition then
            frame._xpcWasDragging = true
        end
        if originalStart then
            originalStart(frame, ...)
        end
    end

    options.onDragStop = function(frame, ...)
        if originalStop then
            originalStop(frame, ...)
        end
        if frame._xpcWasDragging then
            frame._xpcWasDragging = nil
            frame:SaveStoredPosition()
        end
    end

    local button = options and options.button or "LeftButton"

    self:SetMovable(true)
    self:EnableMouse(true)

    if type(button) == "table" then
        self:RegisterForDrag(unpack(button))
    else
        self:RegisterForDrag(button)
    end

    self:SetScript("OnDragStart", function(self)
        if options.requireModifier and not isModifierRequirementMet(options.requireModifier) then
            self:StopMovingOrSizing()
            if options.onModifierFail then options.onModifierFail(self) end
            return
        end

        self.isDragging = true
        if options.onDragStart then options.onDragStart(self) end
        self:StartMoving()
    end)

    self:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end

        self:StopMovingOrSizing()
        self.isDragging = nil
        if options.onDragStop then options.onDragStop(self) end
    end)

    -- Mark frame as draggable and store options for hints/tooltip usage
    self.isDraggable = true
    if options and options.requireModifier then
        self._xpbeDragModifier = options.requireModifier
    end
    self._xpbeDragButton = (options and options.button) or "LeftButton"
end
-- End: embedded position + drag behavior

function StatsFrameMixin:OnLoad()
    local statsFrame = self
    Stats:SetFrame(statsFrame)

    statsFrame:SetClampedToScreen(true)

    -- Initialize local position storage + drag behavior
    statsFrame:InitPositionStorage(
        function()
            return Addon.db and Addon.db.statsPosition
        end,
        function(pos)
            if Addon.db then Addon.db.statsPosition = pos end
        end,
        function()
            return {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = 0,
                y = 0
            }
        end
    )

    -- Apply stored position and enable dragging
    statsFrame:ApplyStoredPosition()
    statsFrame:EnableDrag({button = "LeftButton"})

    -- Setup close button
    if statsFrame.CloseButton then
        statsFrame.CloseButton:SetScript("OnClick", function(btn)
            btn:GetParent():Hide()
        end)
    end

    -- Initial update
    Stats:Update()
end

function StatsFrameMixin:OnShow()
    Stats:Update()
end

function StatsFrameMixin:OnHide()
    -- Could add event unsubscribing here if needed
end

function StatsFrameMixin:OnUpdate(elapsed)
    -- Reserved for potential future use (animations, etc.)
end

--------------------------------------------------------------------------------
-- Core Stats Module
--------------------------------------------------------------------------------

---Set the Stats frame instance used by the module
function Stats:SetFrame(newFrame)
    frame = newFrame
    self.frame = newFrame
end

---Return the currently registered Stats frame (or nil)
function Stats:GetFrame()
    if frame then
        return frame
    end

    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing then
        self:SetFrame(existing)
        return existing
    end
end

function Stats:Initialize()
    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing and existing.OnLoad then
        existing:OnLoad()
    end
    if existing then
        self:SetFrame(existing)
        self:Update()
    end
    -- Register events regardless, keeping in sync with game
    self:RegisterEventHandlers()
end

function Stats:RegisterEventHandlers()
    if self.eventFrame then return end

    local f
    if CreateFrame then
        f = CreateFrame("Frame")
    else
        -- Test/stub environment: create safe stub
        f = {}
        f.RegisterEvent = function(_) end
        f.UnregisterAllEvents = function(_) end
        f.SetScript = function(_, _, _) end
    end

    -- Register events we care about
    if f.RegisterEvent then
        local events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED" }
        for _, ev in ipairs(events) do
            f:RegisterEvent(ev)
        end
    end

    -- OnEvent handler dispatches to Stats methods
    if f.SetScript then
        f:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_XP_UPDATE" then
                self:OnXPUpdate(...)
            elseif event == "PLAYER_LEVEL_UP" then
                self:OnLevelUp(...)
            elseif event == "TIME_PLAYED_MSG" then
                self:OnTimePlayed(...)
            elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
                self:OnQuestXPUpdated(...)
            end
        end)
    end

    self.eventFrame = f
end

function Stats:ShutdownEventHandlers()
    if not self.eventFrame then return end
    if self.eventFrame.UnregisterAllEvents then self.eventFrame:UnregisterAllEvents() end
    if self.eventFrame.SetScript then self.eventFrame:SetScript("OnEvent", nil) end
    self.eventFrame = nil
end

function Stats:Toggle()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    if statsFrame:IsShown() then
        statsFrame:Hide()
    else
        self:Update()
        statsFrame:Show()
    end
end

function Stats:Update()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    -- Update Left Page (Current Level Stats)
    self:UpdateLevelStats(statsFrame)

    -- Update Right Page (Session Stats)
    self:UpdateSessionStats(statsFrame)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function Stats:OnXPUpdate() self:Update() end
function Stats:OnLevelUp() self:Update() end
function Stats:OnXPChanged() self:UpdateLevelStats(self.frame) end
function Stats:OnSessionUpdated() self:UpdateSessionStats(self.frame) end
function Stats:OnQuestXPUpdated() self:UpdateLevelStats(self.frame) end
function Stats:OnTimePlayed(totalTime, levelTime) self:Update() end

--------------------------------------------------------------------------------
-- Update Methods
--------------------------------------------------------------------------------

-- Update left page with current level statistics
function Stats:UpdateLevelStats(statsFrame)
    if not (statsFrame and statsFrame.LeftPage) then return end

    local leftPage = statsFrame.LeftPage
    local content = leftPage.Content
    if not content then return end

    -- Get current player stats
    local level = UnitLevel("player")
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local remainingXP = math_max(0, (maxXP - currentXP))
    local restedXP = GetXPExhaustion() or 0

    -- Calculate progress percentage
    local percent = (currentXP / math_max(maxXP, 1)) * 100

    -- Get session data for level time tracking
    local session = SessionService and SessionService.GetCurrent and SessionService:GetCurrent()

    local levelTime = session and session.realLevelTime or 0

    -- Calculate XP rate for THIS LEVEL (not just current session)
    local levelXPRate = 0 -- XP per second for this level
    if levelTime > 0 and currentXP > 0 then
        levelXPRate = (currentXP / levelTime)
    end

    -- Calculate time to next level based on current level's XP rate
    local timeToLevel = nil
    if levelXPRate > 0 and remainingXP > 0 then
        timeToLevel = remainingXP / levelXPRate -- in seconds
    end

    -- Update current level and XP values using safe setters
    SetTextSafe(content.levelValue, tostring(level))
    SetTextSafe(content.CurrentXPValue, Utils.ShortNumber(currentXP))
    SetTextSafe(content.MaxXPValue, Utils.ShortNumber(maxXP))
    SetTextSafe(content.ProgressValue, string_format("%.1f%%", percent))
    SetTextSafe(content.RemainingXPValue, Utils.ShortNumber(remainingXP))

    if content.RestedXPValue then
        if restedXP > 0 then
            SetTextSafe(content.RestedXPValue, Utils.ShortNumber(restedXP))
        else
            SetTextSafe(content.RestedXPValue, L["TT_NONE"])
        end
    end

    -- Update quest XP
    if content.QuestXPValue then
        local totalQuestXP, completeQuestXP, incompleteQuestXP = self:GetQuestXP()

        if totalQuestXP and totalQuestXP > 0 then
            local questPercent = (totalQuestXP / math_max(maxXP, 1)) * 100
            SetTextSafe(content.QuestXPValue, string_format("%s (%.1f%%)", Utils.ShortNumber(totalQuestXP), questPercent))
        else
            SetTextSafe(content.QuestXPValue, L["TT_NONE"])
        end
    end

    -- Update time on this level
    if content.LevelTimeValue then
        if levelTime > 0 then
            SetTextSafe(content.LevelTimeValue, Utils.FormatDuration(levelTime))
        else
            SetTextSafe(content.LevelTimeValue, L["TT_NA"])
        end
    end

    -- Update time to next level
    if content.TimeToLevelValue then
        if timeToLevel and timeToLevel > 0 then
            SetTextSafe(content.TimeToLevelValue, Utils.FormatDuration(timeToLevel))
        else
            SetTextSafe(content.TimeToLevelValue, L["TT_NA"])
        end
    end
end

-- Update right page with session statistics
function Stats:UpdateSessionStats(statsFrame)
    if not (statsFrame and statsFrame.RightPage) then return end

    local rightPage = statsFrame.RightPage
    local content = rightPage.Content
    if not content then return end

    -- Get session data
    local session = SessionService and SessionService.GetCurrent and SessionService:GetCurrent()
    if not session then
        session = { sessionStart = time(), gainedXP = 0, realLevelTime = 0 }
    end

    -- Calculate session duration using TimeCalculations
    local sessionElapsed = TimeCalc and TimeCalc.SessionDuration(session.sessionStart) or (time() - (session.sessionStart or time()))
    local sessionXP = session.gainedXP or 0

    -- Calculate XP per hour using TimeCalculations
    local xpPerHour = TimeCalc and TimeCalc.CalculateXPPerHour(session.sessionStart, sessionXP) or 0

    -- Levels gained this session (tracked via PLAYER_LEVEL_UP)
    local levelsGained = session.levelsGained or 0

    -- Update session duration & start
    SetTextSafe(content.SessionDurationValue, Utils.FormatDuration(sessionElapsed))
    SetTextSafe(content.SessionStartValue, date("%H:%M", session.sessionStart or time()))
    SetTextSafe(content.SessionXPValue, Utils.ShortNumber(sessionXP))
    SetTextSafe(content.LevelsGainedValue, tostring(levelsGained))

    if content.XPPerHourValue then
        if xpPerHour > 0 then
            SetTextSafe(content.XPPerHourValue, Utils.ShortNumber(xpPerHour))
        else
            SetTextSafe(content.XPPerHourValue, L["TT_CALCULATING"])
        end
    end

    SetTextSafe(content.TotalSessionXPValue, Utils.ShortNumber(sessionXP))
end

--------------------------------------------------------------------------------
-- Quest XP Integration
--------------------------------------------------------------------------------

---Return quest XP totals (total, complete, incomplete)
function Stats:GetQuestXP(forceRefresh)
    if Addon and Addon.QuestXP and Addon.QuestXP.GetQuestXP then
        return Addon.QuestXP:GetQuestXP(forceRefresh)
    end
    return 0, 0, 0
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

XPBarEnhanced.Stats = Stats
