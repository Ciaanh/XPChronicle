-- XP Bar Enhanced - Colors.lua
-- Centralized color management for all XP bar elements

local Addon = XPBarEnhanced
Addon.Colors = {}
local Colors = Addon.Colors

-------------------------------------------------------------------
-- Color Keys (Constants)
-------------------------------------------------------------------

Colors.Key = {
    XpBar = "xpBar",
    XpBarRested = "xpBarRested",
    Rested = "rested",
    QuestComplete = "questComplete",
    QuestIncomplete = "questIncomplete",
}

-------------------------------------------------------------------
-- Color Access
-------------------------------------------------------------------

---Get color from config or defaults
-- table with fields r,g,b,a
function Colors:Get(colorKey)
    local db = Addon.db or {}
    local colors = db.colors or (Addon.defaults and Addon.defaults.colors)
    
    if colors and colors[colorKey] then
        return colors[colorKey]
    end
    
    -- Fallback to white if color not found
    return { r = 1, g = 1, b = 1, a = 1 }
end

---Set color in configuration
function Colors:Set(colorKey, color)
    if not Addon.db then
        return
    end
    
    if not Addon.db.colors then
        Addon.db.colors = {}
    end
    
    Addon.db.colors[colorKey] = {
        r = color.r or color[1] or 1,
        g = color.g or color[2] or 1,
        b = color.b or color[3] or 1,
        a = color.a or color[4] or 1,
    }
end

---Get default color from the defaults table
function Colors:GetDefault(colorKey)
    if not Addon.defaults or not Addon.defaults.colors then
        return { r = 1, g = 1, b = 1, a = 1 }
    end
    
    return Addon.defaults.colors[colorKey] or { r = 1, g = 1, b = 1, a = 1 }
end

---Reset a color to its default value
function Colors:Reset(colorKey)
    local defaultColor = self:GetDefault(colorKey)
    self:Set(colorKey, defaultColor)
end

-- Reset all colors to defaults
function Colors:ResetAll()
    if not Addon.db then
        return
    end
    
    -- Clear colors table, will fallback to defaults
    Addon.db.colors = nil
end

-------------------------------------------------------------------
-- Compatibility Layer (for XPBarMixinBase)
-------------------------------------------------------------------

-- Global compatibility object for old XPBarMixinBase code
_G.XPBarColors = {
    GetUserColor = function(self, colorKey)
        return Addon.Colors:Get(colorKey)
    end
}

-- Global Color key constants (for XPBarMixinBase)
_G.Color = Colors.Key

return Colors
