--[[
    BlizzardBarControl.lua
    
    Manages visibility of Blizzard's default XP bar.
    
    Usage:
        BlizzardBarControl:Hide()  -- Hide Blizzard XP bar
        BlizzardBarControl:Show()  -- Show Blizzard XP bar
        
    Notes:
        - Uses StatusTrackingBarManager API (retail WoW)
        - Gracefully handles missing API (returns false)
        - Used by XPBarController to implement bar style modes
]]

local Addon = XPBarEnhanced

-- Initialize UI namespace
Addon.UI = Addon.UI or {}

local BlizzardBarControl = {}

--[[
    Check if Blizzard's StatusTrackingBarManager is available
    
    @return boolean - true if API is available
]]
function BlizzardBarControl:IsAvailable()
    return StatusTrackingBarManager ~= nil and
           StatusTrackingBarManager.MainStatusTrackingBarContainer ~= nil
end

--[[
    Get the Blizzard XP bar frame
    
    @return frame|nil - The XP bar frame, or nil if not found
]]
function BlizzardBarControl:GetXPBarFrame()
    if not self:IsAvailable() then
        return nil
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Search for XP bar (barType == 0)
    if container.bars then
        for barIndex, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then
                return bar
            end
        end
    end
    
    -- Fallback: Try StatusTrackingBar1 (often the first bar is XP)
    if _G.StatusTrackingBar1 and _G.StatusTrackingBar1.StatusBar then
        if _G.StatusTrackingBar1.StatusBar.barType == 0 then
            return _G.StatusTrackingBar1
        end
    end
    
    -- Final fallback: Return the container itself for positioning
    return container
end

--[[
    Hide Blizzard's XP bar
    
    Used when:
        - Legacy mode (always hidden - we replace it)
        - Flat mode with hideBlizzardBar = true
    
    @return boolean - true if successful, false if API unavailable
]]
function BlizzardBarControl:Hide()
    if not self:IsAvailable() then
        return false
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Hide the XP bar specifically
    if container.bars then
        for _, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then  -- 0 = XP bar
                bar:Hide()
                return true
            end
        end
    end
    
    -- Fallback: try hiding the entire container
    if container then
        container:Hide()
        return true
    end
    
    return false
end

--[[
    Show Blizzard's XP bar
    
    Used when:
        - None mode (always shown - we hide our bars)
        - Flat mode with hideBlizzardBar = false (default)
    
    @return boolean - true if successful, false if API unavailable
]]
function BlizzardBarControl:Show()
    if not self:IsAvailable() then
        return false
    end
    
    local container = StatusTrackingBarManager.MainStatusTrackingBarContainer
    
    -- Show the XP bar specifically
    if container.bars then
        for _, bar in pairs(container.bars) do
            if bar.StatusBar and bar.StatusBar.barType == 0 then  -- 0 = XP bar
                bar:Show()
                return true
            end
        end
    end
    
    -- Fallback: try showing the entire container
    if container then
        container:Show()
        return true
    end
    
    return false
end

-- Export to addon namespace
Addon.UI.BlizzardBarControl = BlizzardBarControl

return BlizzardBarControl
