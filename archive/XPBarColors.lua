-- XP Bar Enhanced - XP Bar Color Service
-- Centralized color management using user-configured colors

local Addon = XPBarEnhanced

-----------------------------------
-- Color Service
-----------------------------------


XPC_XPBarColors = {}

-- Static color key table for code reference
Color = {
    XpBar = "xpBar",
    XpBarRested = "xpBarRested",
    QuestComplete = "questComplete",
    QuestIncomplete = "questIncomplete",
    Rested = "rested",
}

-- Centralized static color table (final fallback)
-- Note: xpBar and rested colors only apply to Flat bar (Legacy uses fixed Blizzard atlases)
local STATIC_COLORS = {
    xpBar =            { r = 0.34, g = 0.39, b = 1.0, a = 1.0 },  -- Purple/Blue (unrested)
    xpBarRested =      { r = 0.34, g = 0.39, b = 1.0, a = 1.0 },  -- Purple/Blue (unrested)
    rested =           { r = 0.07, g = 0.58, b = 0.95, a = 0.5 }, -- Light Blue (rested overlay)
    questComplete =    { r = 1.0,  g = 0.65, b = 0.0, a = 0.85 }, -- Bright Gold/Orange (rewards ready)
    questIncomplete =  { r = 0.5,  g = 1.0,  b = 0.2, a = 0.85 }, -- Bright Lime Green (progress)
}

-----------------------------------
-- Helper Functions
-----------------------------------

-- Convert RGB (0-1) to hex color code
function XPC_XPBarColors:RGBToHex(r, g, b, a)
    a = a or 1.0
    local ra = math.floor(a * 255)
    local rr = math.floor(r * 255)
    local rg = math.floor(g * 255)
    local rb = math.floor(b * 255)
    return string.format("|c%02X%02X%02X%02X", ra, rr, rg, rb)
end

-----------------------------------
-- User Color Functions
-----------------------------------

-- Get color from user's saved settings or defaults
-- Returns RGB color table { r, g, b, a }
-- colorKey: "xpBar", "questComplete", "questIncomplete", or "rested"

function XPC_XPBarColors:GetUserColor(colorKey)
    -- Try to get from saved settings
    if Addon and Addon.db and Addon.db.colors and Addon.db.colors[colorKey] then
        return Addon.db.colors[colorKey]
    end

    -- Try to get from defaults
    if Addon and Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[colorKey] then
        return Addon.defaults.colors[colorKey]
    end

    -- Fallback to static color table
    if STATIC_COLORS[colorKey] then
        return STATIC_COLORS[colorKey]
    end

    -- Fallback to white
    return {r = 1, g = 1, b = 1, a = 1}
end


-- Get user's color as RGB values for tooltips (AddDoubleLine/AddLine)
-- colorKey: use Color.<Name> (e.g., Color.XpBar)
-- Returns: r, g, b (values 0-1)
function XPC_XPBarColors:GetUserTooltipColor(colorKey)
    local color = self:GetUserColor(colorKey)
    return color.r, color.g, color.b
end


-- Get text color from user's saved bar color settings
-- colorKey: use Color.<Name> (e.g., Color.XpBar)
function XPC_XPBarColors:GetUserTextColor(colorKey)
    local color = self:GetUserColor(colorKey)
    return self:RGBToHex(color.r, color.g, color.b, color.a)
end


-- Format text with user's customized color
-- colorKey: use Color.<Name> (e.g., Color.XpBar)
function XPC_XPBarColors:ColorTextWithUserColor(text, colorKey)
    local colorCode = self:GetUserTextColor(colorKey)
    return colorCode .. text .. "|r"
end

-----------------------------------
-- Usage Examples
-----------------------------------
--[[

Available color keys (use Color.<Name>):
    Color.XpBar             -- Main XP bar
    Color.QuestComplete     -- Complete quest overlay
    Color.QuestIncomplete   -- Incomplete quest overlay
    Color.Rested            -- Rested XP overlay

Tooltips (uses user's configured bar colors):
    local r, g, b = XPC_XPBarColors:GetUserTooltipColor(Color.XpBar)
    tooltip:AddDoubleLine("Quest XP:", value, 0.8, 0.8, 0.8, r, g, b)

Text overlays (uses user's configured bar colors):
    local colorCode = XPC_XPBarColors:GetUserTextColor(Color.XpBar)
    local text = colorCode .. "5.2%" .. "|r"

Or using helper:
    local text = XPC_XPBarColors:ColorTextWithUserColor("5.2%", Color.XpBar)
]]
 --
