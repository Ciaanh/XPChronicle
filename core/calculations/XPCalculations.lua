-- XP Bar Enhanced - XP Calculations
-- Shared XP calculation helpers used by ContextBuilder and Session

local Addon = XPBarEnhanced
Addon.XPCalculations = Addon.XPCalculations or {}

---@class XPCalculations
local XPCalc = Addon.XPCalculations

-------------------------------------------------------------------
-- XP GAIN COMPUTATION
-------------------------------------------------------------------

--- Compute XP gained between two snapshots, handling level-up wrap-around
---@param currentXP number Current XP amount
---@param currentMax number Current level's max XP
---@param lastXP number Previous XP snapshot
---@param lastMax number Previous level's max XP
---@return number xpGained Amount of XP gained
---@return boolean didLevelUp Whether a level-up occurred
function XPCalc.ComputeGain(currentXP, currentMax, lastXP, lastMax)
    local xpGained = 0
    local didLevelUp = false

    -- Detect level-up: xpMax changed (new level has different XP requirement)
    if lastMax and currentMax and lastMax ~= currentMax then
        didLevelUp = true
        -- Level-up occurred: XP gained = (old max - old current) + new current
        xpGained = (lastMax - lastXP) + currentXP
    elseif currentXP >= lastXP then
        -- Normal XP gain (same level)
        xpGained = currentXP - lastXP
    else
        -- Edge case: currentXP < lastXP but xpMax same (shouldn't happen normally)
        -- Could be a data reset or edge case - treat as no gain
        xpGained = 0
    end

    return xpGained, didLevelUp
end

--- Compute XP remaining to reach next level
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@return number remainingXP XP needed to level up
function XPCalc.ComputeRemaining(currentXP, xpMax)
    return math.max(0, (xpMax or 0) - (currentXP or 0))
end

--- Compute current XP as a ratio (0.0 - 1.0)
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@return number ratio Progress ratio (0.0 - 1.0)
function XPCalc.ComputeRatio(currentXP, xpMax)
    if not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(1, math.max(0, (currentXP or 0) / xpMax))
end

--- Compute XP percentage with configurable decimal places
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@param decimals number|nil Number of decimal places (default 1)
---@return number percentage XP progress as percentage
function XPCalc.ComputePercent(currentXP, xpMax, decimals)
    decimals = decimals or 1
    local ratio = XPCalc.ComputeRatio(currentXP, xpMax)
    local multiplier = 10 ^ decimals
    return math.floor(ratio * 100 * multiplier + 0.5) / multiplier
end

-------------------------------------------------------------------
-- RESTED XP CALCULATIONS
-------------------------------------------------------------------

--- Check if player is fully rested (150% of level XP)
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return boolean isFullyRested True if rested XP >= 150% of level
function XPCalc.IsFullyRested(restedXP, xpMax)
    if not restedXP or not xpMax or xpMax <= 0 then
        return false
    end
    return restedXP >= (1.5 * xpMax)
end

--- Compute rested XP as percentage of level
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return number percent Rested XP as percentage (max 150%)
function XPCalc.RestedPercent(restedXP, xpMax)
    if not restedXP or not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(150, (restedXP / xpMax) * 100)
end

--- Compute how much rested XP extends beyond current XP position
---@param currentXP number Current XP amount
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return number restedEndRatio Ratio where rested bar should end (0.0 - 1.0, capped at current level)
function XPCalc.RestedEndRatio(currentXP, restedXP, xpMax)
    if not restedXP or restedXP <= 0 or not xpMax or xpMax <= 0 then
        return 0
    end
    local restedEnd = (currentXP or 0) + restedXP
    return math.min(1, restedEnd / xpMax)
end

-------------------------------------------------------------------
-- QUEST XP CALCULATIONS
-------------------------------------------------------------------

--- Compute quest XP as ratio of level
---@param questXP number Total quest XP available
---@param xpMax number XP needed for next level
---@return number ratio Quest XP as ratio (0.0 - 1.0)
function XPCalc.QuestXPRatio(questXP, xpMax)
    if not questXP or not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(1, questXP / xpMax)
end

--- Compute where quest overlay should start and end
---@param currentXP number Current XP amount
---@param questXP number Quest XP to overlay
---@param xpMax number XP needed for next level
---@return number startRatio Start position ratio
---@return number endRatio End position ratio (capped at 1.0)
function XPCalc.QuestOverlayRange(currentXP, questXP, xpMax)
    if not xpMax or xpMax <= 0 then
        return 0, 0
    end
    local startRatio = (currentXP or 0) / xpMax
    local endRatio = math.min(1, ((currentXP or 0) + (questXP or 0)) / xpMax)
    return startRatio, endRatio
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

return XPCalc
