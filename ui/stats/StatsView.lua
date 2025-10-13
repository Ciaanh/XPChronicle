-- XP Chronicle Stats View
local Addon = XPChronicle
Addon.UI = Addon.UI or {}
Addon.UI.Views = Addon.UI.Views or {}

local View = Addon.UI.Views.Stats or {}
Addon.UI.Views.Stats = View
Addon.Stats = View

local Utils = Addon.Utils or {}
local FrameUtils = Addon.UI.Components and Addon.UI.Components.FrameUtils
local PositionStoreMixin = Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
local DraggableFrameMixin = Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
local QuestXPService = Addon.App and Addon.App.Services and Addon.App.Services.QuestXPService

local frame

local StatsFrameMixin = {}
XPChronicleStatsMixin = StatsFrameMixin

function View:SetFrame(newFrame)
    frame = newFrame
    self.frame = newFrame
end

function StatsFrameMixin:OnLoad()
    local statsFrame = self
    View:SetFrame(statsFrame)

    statsFrame:SetClampedToScreen(true)

    if PositionStoreMixin and DraggableFrameMixin then
        Mixin(statsFrame, PositionStoreMixin, DraggableFrameMixin)
        statsFrame:InitPositionStorage(
            function()
                return Addon.db and Addon.db.statsPosition
            end,
            function(pos)
                if Addon.db then
                    Addon.db.statsPosition = pos
                end
            end,
            function()
                return {
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = 0,
                    y = 0,
                }
            end
        )
        statsFrame:EnableDrag({ button = "LeftButton" })
    elseif FrameUtils and FrameUtils.EnableDrag then
        FrameUtils.EnableDrag(statsFrame, { button = "LeftButton" })
    end

    if statsFrame.TitleText then
        statsFrame.TitleText:SetText("XP Chronicle")
    end

    if statsFrame.ScrollFrame and statsFrame.ContentFrame then
        statsFrame.ScrollFrame:SetClipsChildren(true)
        statsFrame.ScrollFrame:SetScrollChild(statsFrame.ContentFrame)
    end

    if statsFrame.ContentFrame and statsFrame.ContentFrame.StatsText then
        local statsText = statsFrame.ContentFrame.StatsText
        if statsText.SetJustifyH then
            statsText:SetJustifyH("LEFT")
        end
        if statsText.SetJustifyV then
            statsText:SetJustifyV("TOP")
        end
    end

    if statsFrame.CloseButton then
        statsFrame.CloseButton:SetScript("OnClick", function(btn)
            btn:GetParent():Hide()
        end)
    end

    if statsFrame.RefreshButton then
        statsFrame.RefreshButton:SetText("Refresh")
        statsFrame.RefreshButton:SetScript("OnClick", function()
            View:Update()
        end)
    end

    View:Update()
end

function View:Initialize(controller)
    if controller then
        self.controller = controller
    end

    if frame and frame:IsShown() then
        return
    end

    local existing = _G["XPChronicleStatsFrame"]
    if existing and existing.OnLoad then
        existing:OnLoad()
        self:SetFrame(existing)
    elseif existing then
        self:SetFrame(existing)
        self:Update()
    end
end

function View:GetFrame()
    if frame then
        return frame
    end

    local existing = _G["XPChronicleStatsFrame"]
    if existing then
        self:SetFrame(existing)
        return existing
    end
end

function View:Toggle()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    if statsFrame:IsShown() then
        statsFrame:Hide()
    else
        self:Update()
        statsFrame:Show()
    end
end

local function collectLevelHistory()
    local levelHistory = {}
    if not (Addon.db and Addon.playerKey and Addon.db.levelData) then
        return levelHistory
    end

    local levelTable = Addon.db.levelData[Addon.playerKey]
    if not levelTable then
        return levelHistory
    end

    for level, data in pairs(levelTable) do
        table.insert(levelHistory, { level = level, data = data })
    end

    table.sort(levelHistory, function(a, b)
        return a.level < b.level
    end)

    return levelHistory
end

local function formatLevelLine(entry)
    local level = entry.level
    local data = entry.data or {}

    if data.levelEnd then
        -- Completed level
        local levelTime = Addon.App.Services.LevelHistoryService:GetLevelDuration(level)
        local timeStr = Utils.FormatTime(levelTime)
        
        -- Add XP gained if available
        local xpInfo = ""
        if data.xpAtStart and data.xpAtEnd then
            local xpGained = data.xpAtEnd - data.xpAtStart
            xpInfo = string.format(" - %s XP", Utils.FormatNumber(xpGained))
        end
        
        -- Format completion date if available
        local dateStr = ""
        if data.levelEnd then
            dateStr = string.format(" (Completed: %s)", date("%m/%d/%Y", data.levelEnd))
        end
        
        return string.format("  Level %d: %s%s%s", level, timeStr, xpInfo, dateStr)
    else
        -- In progress level
        local elapsed = 0
        if data.levelStart then
            elapsed = math.max(0, time() - data.levelStart)
        end
        
        local xpInfo = ""
        if data.xpAtStart then
            local currentXP = UnitXP("player")
            local xpGained = math.max(0, currentXP - data.xpAtStart)
            xpInfo = string.format(", %s XP gained", Utils.FormatNumber(xpGained))
        end
        
        return string.format("  Level %d: In Progress (%s elapsed%s)", level, Utils.FormatTime(elapsed), xpInfo)
    end
end

function View:Update()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    local contentFrame = statsFrame.ContentFrame
    local statsText = contentFrame and contentFrame.StatsText
    if not statsText then
        return
    end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local currentLevel = UnitLevel("player")
    local restedXP = GetXPExhaustion() or 0

    if maxXP == 0 then
        maxXP = 1
    end

    local _, questComplete, questIncomplete = self:GetQuestXP()

    local remainingXP = math.max(0, maxXP - currentXP)

    local session = Addon.App.Services.SessionService:GetSession()
    local sessionElapsed = time() - session.sessionStart
    local sessionXP = session.gainedXP
    
    local xpPerHour = 0
    if sessionElapsed > 0 and sessionXP > 0 then
        xpPerHour = (sessionXP / sessionElapsed) * 3600
    end

    local timeToLevel
    if xpPerHour > 0 then
        timeToLevel = remainingXP / xpPerHour
    end

    local lines = {}

    table.insert(lines, string.format("|cFFFFD700Level:|r %d", currentLevel))
    table.insert(lines, string.format("|cFFFFD700XP:|r %s / %s (%s remaining)", Utils.FormatNumber(currentXP), Utils.FormatNumber(maxXP), Utils.FormatNumber(remainingXP)))
    
    if restedXP > 0 then
        table.insert(lines, string.format("|cFFFFD700Rested:|r %s (%s)", Utils.FormatNumber(restedXP), XPC_XPBarTextFormatter:FormatPercent(restedXP, maxXP, 1)))
    end

    if questComplete > 0 or questIncomplete > 0 then
        table.insert(lines, "")
        table.insert(lines, "|cFFFFD700Quest XP:|r")
        if questComplete > 0 then
            table.insert(lines, string.format("  |cFFFFD700Complete:|r %s", Utils.FormatNumber(questComplete)))
        end
        if questIncomplete > 0 then
            table.insert(lines, string.format("  |cFFFFD700Incomplete:|r %s", Utils.FormatNumber(questIncomplete)))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "|cFFFFD700Session:|r")
    table.insert(lines, string.format("  |cFFFFD700Time:|r %s", Utils.FormatTime(sessionElapsed)))
    table.insert(lines, string.format("  |cFFFFD700XP Gained:|r %s", Utils.FormatNumber(sessionXP)))
    if xpPerHour > 0 then
        table.insert(lines, string.format("  |cFFFFD700XP/Hour:|r %s", Utils.FormatNumber(xpPerHour)))
    end

    table.insert(lines, "")
    table.insert(lines, "|cFFFFD700Time to Level:|r")
    if timeToLevel then
        table.insert(lines, string.format("  |cFFFFD700Current Rate:|r %s", Utils.FormatTime(timeToLevel)))
    else
        table.insert(lines, "  |cFFFFD700Current Rate:|r Calculating...")
    end
    
    local levelTime = session.realLevelTime or 0
    if levelTime > 0 then
        table.insert(lines, string.format("  |cFFFFD700This Level:|r %s", Utils.FormatTime(levelTime)))
    else
        -- Fallback to calculated level time if realLevelTime not available
        local levelData = Addon.db.levelData and Addon.playerKey and Addon.db.levelData[Addon.playerKey]
        if levelData and levelData[currentLevel] and levelData[currentLevel].levelStart then
            local calcLevelTime = math.max(0, time() - levelData[currentLevel].levelStart)
            if calcLevelTime > 0 then
                table.insert(lines, string.format("  |cFFFFD700This Level:|r %s", Utils.FormatTime(calcLevelTime)))
            end
        end
    end

    local levelHistory = collectLevelHistory()
    if #levelHistory > 0 then
        table.insert(lines, "")
        table.insert(lines, "|cFFFFD700Level History:|r")

        for _, entry in ipairs(levelHistory) do
            table.insert(lines, formatLevelLine(entry))
        end
    end

    statsText:SetText(table.concat(lines, "\n"))
end

function View:GetQuestXP(forceRefresh)
    local controller = self.controller
    if controller and controller.GetQuestXP then
        return controller:GetQuestXP(forceRefresh)
    end

    if Addon.App and Addon.App.Features and Addon.App.Features.xpbar and Addon.App.Features.xpbar.GetQuestXP then
        return Addon.App.Features.xpbar:GetQuestXP(forceRefresh)
    end

    if QuestXPService and QuestXPService.GetQuestXP then
        return QuestXPService:GetQuestXP(forceRefresh)
    end

    return 0, 0, 0
end

function View:OnTimePlayed()
    self:Update()
end

return View
