-- XP Bar Enhanced - Minimap Button
-- Provides a minimap button for quick access to stats and options
-- Based on LibDBIcon-1.0 positioning logic

local Addon = XPBarEnhanced
Addon.MinimapButton = Addon.MinimapButton or {}

---@class MinimapButton
local MinimapButton = Addon.MinimapButton

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local BUTTON_NAME = "XPBarEnhancedMinimapButton"
local ICON_TEXTURE = 4675649 -- Default addon icon (from TOC IconTexture)
local BUTTON_RADIUS = 5 -- Extra radius beyond minimap edge (like LibDBIcon)

-------------------------------------------------------------------
-- INTERNAL STATE
-------------------------------------------------------------------

local button = nil
local isDragging = false

-------------------------------------------------------------------
-- POSITION MANAGEMENT
-------------------------------------------------------------------

--- Get saved minimap position angle
---@return number angle Position angle in degrees (0-360)
local function GetSavedPosition()
    local db = Addon.db
    if db and db.minimapButtonPosition then
        return db.minimapButtonPosition
    end
    return 225 -- Default: bottom-left of minimap
end

--- Save minimap position angle
---@param angle number Position angle in degrees
local function SavePosition(angle)
    if Addon.db then
        Addon.db.minimapButtonPosition = angle
    end
end

--- Update button position on minimap based on angle
--- Matches LibDBIcon positioning for round minimap
---@param position number|nil Position angle in degrees (0-360)
local function UpdatePosition(position)
    if not button then
        return
    end

    local angle = math.rad(position or 225)
    local x, y = math.cos(angle), math.sin(angle)

    local w = (Minimap:GetWidth() / 2) + BUTTON_RADIUS
    local h = (Minimap:GetHeight() / 2) + BUTTON_RADIUS

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
end

--- Calculate angle from minimap center to cursor (matches LibDBIcon)
---@return number angle Angle in degrees (0-360)
local function GetCursorAngle()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()

    px, py = px / scale, py / scale

    return math.deg(math.atan2(py - my, px - mx)) % 360
end

-------------------------------------------------------------------
-- TOOLTIP
-------------------------------------------------------------------

local function ShowTooltip()
    if not button then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:ClearLines()

    -- Title
    GameTooltip:AddLine("XP Bar Enhanced", 1, 0.82, 0)

    -- Quick stats if available
    local session = Addon.Session and Addon.Session:GetCurrent()
    if session then
        local gainedXP = session.gainedXP or 0
        local TimeCalc = Addon.TimeCalculations
        local duration = TimeCalc and TimeCalc.SessionDuration(session.sessionStart) or 0

        if gainedXP > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Session XP:", tostring(gainedXP), 0.8, 0.8, 0.8, 1, 1, 1)

            if duration > 0 then
                local durationStr = TimeCalc and TimeCalc.FormatSmart(duration) or (duration .. "s")
                GameTooltip:AddDoubleLine("Session Time:", durationStr, 0.8, 0.8, 0.8, 1, 1, 1)
            end
        end
    end

    -- Instructions
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ff00Left-Click:|r Open Stats", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00ff00Right-Click:|r Open Options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00ff00Shift-Click:|r Reset Session", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00ff00Drag:|r Move Button", 0.8, 0.8, 0.8)

    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-------------------------------------------------------------------
-- CLICK HANDLERS
-------------------------------------------------------------------

local function OnClick(self, mouseButton)
    if isDragging then
        return
    end

    if mouseButton == "LeftButton" then
        if IsShiftKeyDown() then
            -- Reset session
            if Addon.Session and Addon.Session.ResetSession then
                Addon.Session:ResetSession()
                print("|cff00ff00XP Bar Enhanced:|r Session reset.")
            elseif Addon.Session then
                local session = Addon.Session:GetCurrent()
                if session then
                    session.gainedXP = 0
                    session.sessionStart = time()
                    print("|cff00ff00XP Bar Enhanced:|r Session reset.")
                end
            end
        else
            -- Open stats window
            if Addon.Stats and Addon.Stats.Toggle then
                Addon.Stats:Toggle()
            elseif _G.XPBarEnhancedStatsFrame then
                local frame = _G.XPBarEnhancedStatsFrame
                if frame:IsShown() then
                    frame:Hide()
                else
                    frame:Show()
                end
            else
                print("|cff00ff00XP Bar Enhanced:|r Use /xpbe stats to open stats window.")
            end
        end
    elseif mouseButton == "RightButton" then
        -- Open options
        if Addon.Options and Addon.Options.Open then
            Addon.Options:Open()
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("XP Bar Enhanced")
        else
            print("|cff00ff00XP Bar Enhanced:|r Use /xpbe to open options.")
        end
    end

    HideTooltip()
end

-------------------------------------------------------------------
-- DRAG HANDLING (based on LibDBIcon)
-------------------------------------------------------------------

local function OnDragUpdate(self)
    local pos = GetCursorAngle()
    SavePosition(pos)
    UpdatePosition(pos)
end

local function OnDragStart(self)
    isDragging = true
    self:LockHighlight()
    self.isMouseDown = true
    self:SetScript("OnUpdate", OnDragUpdate)
    GameTooltip:Hide()
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    self.isMouseDown = false
    self:UnlockHighlight()
    isDragging = false
end

local function OnMouseDown(self)
    self.isMouseDown = true
end

local function OnMouseUp(self)
    self.isMouseDown = false
end

-------------------------------------------------------------------
-- BUTTON CREATION (based on LibDBIcon for retail)
-------------------------------------------------------------------

--- Create the minimap button
function MinimapButton:Create()
    if button then
        return button
    end

    -- Create button frame (matches LibDBIcon structure)
    button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:SetSize(31, 31)

    -- Highlight texture
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    -- Border/overlay texture (OVERLAY layer, positioned at TOPLEFT)
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(50, 50)
    overlay:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT")

    -- Background texture
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
    background:SetPoint("CENTER", button, "CENTER")

    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(ICON_TEXTURE)
    icon:SetPoint("CENTER", button, "CENTER")
    button.icon = icon

    -- Register for interactions
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")

    -- Set up scripts
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)
    button:SetScript("OnMouseDown", OnMouseDown)
    button:SetScript("OnMouseUp", OnMouseUp)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)

    -- Initial positioning
    local pos = GetSavedPosition()
    UpdatePosition(pos)

    return button
end

--- Show the minimap button
function MinimapButton:Show()
    if not button then
        self:Create()
    end
    if button then
        button:Show()
    end
end

--- Hide the minimap button
function MinimapButton:Hide()
    if button then
        button:Hide()
    end
end

--- Toggle minimap button visibility
function MinimapButton:Toggle()
    if button and button:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if button is visible
---@return boolean isShown
function MinimapButton:IsShown()
    return button ~= nil and button:IsShown() == true
end

--- Update button position (public method for hooks)
function MinimapButton:UpdatePosition()
    if button then
        local angle = GetSavedPosition()
        UpdatePosition(angle)
    end
end

--- Initialize the minimap button (call after DB is ready)
function MinimapButton:Initialize()
    -- Check if minimap button should be shown
    local db = Addon.db
    local showButton = true

    if db and db.showMinimapButton ~= nil then
        showButton = db.showMinimapButton
    end

    if showButton then
        self:Create()
        self:Show()
    end
end

--- Set button visibility preference
---@param show boolean Whether to show the button
function MinimapButton:SetEnabled(show)
    if Addon.db then
        Addon.db.showMinimapButton = show
    end

    if show then
        self:Show()
    else
        self:Hide()
    end
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

return MinimapButton
