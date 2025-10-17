-- XP Bar Enhanced XP Bar View
local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Views = Addon.UI.Views or {}

local View = Addon.UI.Views.XPBar or {}
Addon.UI.Views.XPBar = View
Addon.XPBar = View

local _G = _G
local Utils = Addon.Utils or {}
local FrameUtils = Addon.UI.Components and Addon.UI.Components.FrameUtils
local PositionStoreMixin = Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
local DraggableFrameMixin = Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin
local QuestXPService = Addon.App and Addon.App.Services and Addon.App.Services.QuestXPService

local frame
local tooltipFonts
local function noop() end

local colorKeys = {
    "xpBar",
    "questComplete",
    "questIncomplete",
    "rested",
}

local function clamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function View:InvalidateQuestCache()
    if QuestXPService and QuestXPService.InvalidateCache then
        QuestXPService:InvalidateCache()
    end
end

local function appendFontFlag(baseFlags, addFlag)
    if not addFlag or addFlag == "" then
        return baseFlags or ""
    end

    if not baseFlags or baseFlags == "" then
        return addFlag
    end

    if string.find(baseFlags, addFlag, 1, true) then
        return baseFlags
    end

    return baseFlags .. " " .. addFlag
end

local function ensureTooltipFonts()
    if tooltipFonts then
        return tooltipFonts
    end

    local baseFontObject = GameTooltipText or GameTooltipTextSmall or GameFontHighlightSmall or GameFontHighlight or GameFontNormal
    local fontFile, fontSize, fontFlags = nil, nil, nil

    if baseFontObject and baseFontObject.GetFont then
        fontFile, fontSize, fontFlags = baseFontObject:GetFont()
    end

    if not fontFile then
        fontFile = "Fonts\\FRIZQT__.TTF"
        fontSize = 12
        fontFlags = ""
    end

    local normal = CreateFont("XPBarEnhancedTooltipFontNormal")
    normal:SetFont(fontFile, fontSize or 12, fontFlags or "")

    local bold = CreateFont("XPBarEnhancedTooltipFontBold")
    bold:SetFont(fontFile, fontSize or 12, appendFontFlag(fontFlags or "", "OUTLINE"))

    tooltipFonts = {
        normal = normal,
        bold = bold,
    }

    return tooltipFonts
end

local function setTooltipLineFont(tooltip, lineIndex, fontObject)
    if not tooltip or not lineIndex or lineIndex <= 0 then
        return
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return
    end

    local fonts = ensureTooltipFonts()
    local fontToApply = fontObject or (fonts and fonts.normal)

    local left = _G[tooltipName .. "TextLeft" .. lineIndex]
    if left and fontToApply then
        left:SetFontObject(fontToApply)
    end

    local right = _G[tooltipName .. "TextRight" .. lineIndex]
    if right and fontToApply then
        right:SetFontObject(fontToApply)
    end
end

local function addTooltipDoubleLine(tooltip, label, value, lr, lg, lb, rr, rg, rb, focusKey, activeFocus)
    if not tooltip then return end

    tooltip:AddDoubleLine(label, value, lr, lg, lb, rr, rg, rb)
    local lineIndex = tooltip:NumLines()
    local fonts = ensureTooltipFonts()
    local fontObject = fonts and fonts.normal or nil

    if focusKey and activeFocus and focusKey == activeFocus and fonts then
        fontObject = fonts.bold
    end

    setTooltipLineFont(tooltip, lineIndex, fontObject)
end

local function addTooltipLine(tooltip, text, r, g, b, focusKey, activeFocus)
    if not tooltip then return end

    tooltip:AddLine(text, r, g, b)
    local lineIndex = tooltip:NumLines()
    local fonts = ensureTooltipFonts()
    local fontObject = fonts and fonts.normal or nil

    if focusKey and activeFocus and focusKey == activeFocus and fonts then
        fontObject = fonts.bold
    end

    setTooltipLineFont(tooltip, lineIndex, fontObject)
end

-- Blizzard XP bar visibility control
local function applyDefaultXPBarVisibility()
    if not StatusTrackingBarManager then
        return
    end

    -- Determine if Blizzard bar should be hidden based on bar style
    local shouldHide = false
    
    if Addon.db then
        local style = Addon.db.barStyle or "legacy"
        
        if style == "none" then
            -- None mode: ALWAYS show Blizzard bar
            shouldHide = false
        elseif style == "legacy" then
            -- Legacy mode: ALWAYS hide Blizzard bar
            shouldHide = true
        elseif style == "flat" then
            -- Flat mode: Respect hideBlizzardBar setting
            shouldHide = Addon.db.hideBlizzardBar or false
        end
    end

    if shouldHide then
        if StatusTrackingBarManager.Show ~= noop then
            Addon.state.originalXPBarShow = Addon.state.originalXPBarShow or StatusTrackingBarManager.Show
            StatusTrackingBarManager.Show = noop
        end
        StatusTrackingBarManager:Hide()
        Addon.state.defaultXPBarHidden = true
    else
        -- Restore original Show method if we replaced it
        if Addon.state.originalXPBarShow then
            StatusTrackingBarManager.Show = Addon.state.originalXPBarShow
            Addon.state.originalXPBarShow = nil
        end
        -- Always show the bar when it shouldn't be hidden
        StatusTrackingBarManager:Show()
        Addon.state.defaultXPBarHidden = false
    end
end

function View:ApplyDefaultXPBarVisibility()
    applyDefaultXPBarVisibility()
end

function View:Initialize(controller)
    if controller then
        self.controller = controller
    end

    if Addon.state.xpGainDisabled == nil and Addon.App and Addon.App.Core and Addon.App.Core.SavedVariables then
        Addon.state.xpGainDisabled = Addon.App.Core.SavedVariables:IsXPGainDisabled()
    end

    if frame and frame:IsObjectType("Frame") then
        applyDefaultXPBarVisibility()
        return
    end

    -- Old XPBarEnhancedBar frame removed - now using XPC_FlatXPBar and XPC_LegacyXPBar
    
    -- Store container references for controller
    self.legacyContainer = _G.XPC_LegacyXPBar
    self.flatContainer = _G.XPC_FlatXPBar
    
    -- Initialize colors on both bars (SavedVariables are now loaded)
    local legacyBar = _G.XPC_LegacyXPBar and _G.XPC_LegacyXPBar.Bar
    if legacyBar and legacyBar.InitializeColors then
        legacyBar:InitializeColors()
    end
    
    local flatBar = _G.XPC_FlatXPBar and _G.XPC_FlatXPBar.Bar
    if flatBar and flatBar.InitializeColors then
        flatBar:InitializeColors()
    end

    applyDefaultXPBarVisibility()
end

function View:OnEnteringWorld()
    applyDefaultXPBarVisibility()
    self:Update()
end

function View:GetQuestXP(forceRefresh)
    if self.controller and self.controller.GetQuestXP then
        return self.controller:GetQuestXP(forceRefresh)
    end

    if QuestXPService and QuestXPService.GetQuestXP then
        return QuestXPService:GetQuestXP(forceRefresh)
    end

    return 0, 0, 0
end

function View:HandleFrameEvent(event, ...)
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_COMPLETE" then
        self:InvalidateQuestCache()
    end

    self:Update()
end

local function showFrameTooltip(self)
    View.tooltipFocus = "current"
    View:ShowTooltip()
end

local function hideFrameTooltip()
    View.tooltipFocus = nil
    GameTooltip:Hide()
end

function View:IsPlayerAtMaxLevel()
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or UnitLevel("player")
    local expansionMax = GetMaxLevelForExpansionLevel and GetMaxLevelForExpansionLevel(GetExpansionLevel()) or maxLevel
    return UnitLevel("player") >= math.min(maxLevel, expansionMax)
end

function View:Update()
    -- Delegate to new bar architecture (self-contained bars)
    -- IMPORTANT: Only update bars that are currently shown!
    local flatBar = _G.XPC_FlatXPBar
    if flatBar and flatBar:IsShown() and flatBar.Bar then
        -- Recalculate and reapply bar layout (includes overlays and text)
        if flatBar.Bar.UpdateTextVisibility then
            flatBar.Bar:UpdateTextVisibility()
        end
        if flatBar.Bar.UpdateBarOverlayColors then
            flatBar.Bar:UpdateBarOverlayColors()
        end
        if flatBar.Bar.UpdateAllText then
            flatBar.Bar:UpdateAllText()
        end
    end
    
    local legacyBar = _G.XPC_LegacyXPBar
    if legacyBar and legacyBar:IsShown() and legacyBar.Bar then
        -- Recalculate and reapply bar layout (includes overlays and text)
        if legacyBar.Bar.UpdateTextVisibility then
            legacyBar.Bar:UpdateTextVisibility()
        end
        if legacyBar.Bar.UpdateBarOverlayColors then
            legacyBar.Bar:UpdateBarOverlayColors()
        end
        if legacyBar.Bar.UpdateAllText then
            legacyBar.Bar:UpdateAllText()
        end
    end
end

function View:ShowTooltip()
    if not frame then return end

    local focus = self.tooltipFocus or "current"
    self.tooltipFocus = focus
    local fonts = ensureTooltipFonts()

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()

    GameTooltip:AddLine("Experience", 1, 1, 1)
    setTooltipLineFont(GameTooltip, GameTooltip:NumLines(), fonts and fonts.bold)

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0
    local questTotal, questComplete, questIncomplete = self:GetQuestXP()
    local questXP = questTotal

    do
        local r, g, b = XPC_XPBarColors:GetUserTooltipColor("questIncomplete")
        addTooltipDoubleLine(GameTooltip, "Current:", string.format("%s / %s", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP)), r, g, b, 1, 1, 1, "current", focus)
        addTooltipDoubleLine(GameTooltip, "Remaining:", BreakUpLargeNumbers(maxXP - currentXP), r, g, b, 1, 1, 1, "remaining", focus)
    end

    if restedXP > 0 then
        addTooltipDoubleLine(GameTooltip, "Rested:", BreakUpLargeNumbers(restedXP), 0, 0.39, 0.88, 0, 0.8, 1, "rested", focus)
    end

    if questXP > 0 and Addon.db.showQuestXP ~= false then
        local questPercent = (questXP / maxXP) * 100
        addTooltipDoubleLine(GameTooltip, "Quest XP:", string.format("%s (%.1f%%)", BreakUpLargeNumbers(questXP), questPercent), 0.78, 0.2, 0.75, 1, 0.8, 1, "quest", focus)
        if questComplete > 0 and questIncomplete > 0 then
            local completePercent = (questComplete / maxXP) * 100
            local incompletePercent = (questIncomplete / maxXP) * 100
            addTooltipDoubleLine(GameTooltip, " ├─ Complete:", string.format("%s (%.1f%%)", BreakUpLargeNumbers(questComplete), completePercent), 0.95, 0.65, 0.2, 1, 0.8, 1, "questComplete", focus)
            addTooltipDoubleLine(GameTooltip, " └─ Incomplete:", string.format("%s (%.1f%%)", BreakUpLargeNumbers(questIncomplete), incompletePercent), 0.95, 0.75, 0.9, 1, 0.8, 1, "questIncomplete", focus)
        end
    end

    addTooltipLine(GameTooltip, "Shift + Drag to move", 0.7, 0.7, 0.7, nil, focus)
    addTooltipLine(GameTooltip, "Alt + Click to open options", 0.7, 0.7, 0.7, nil, focus)
    addTooltipLine(GameTooltip, "Ctrl + Click to toggle stats", 0.7, 0.7, 0.7, nil, focus)

    GameTooltip:Show()
end

return View
