-- XP Bar Enhanced - Position Mixin (v2)
-- Behavior mixin for positioning: STATIC (anchored to Blizzard bar) or DRAGGABLE (user-movable with persistence)

-------------------------------------------------------------------
-- GLOBAL POSITION MIXIN
-------------------------------------------------------------------

---@class XPBarPositionMixin
XPBarPositionMixin = {}

local PositionMixin = XPBarPositionMixin

-------------------------------------------------------------------
-- POSITION MODES
-------------------------------------------------------------------

local POSITION_MODE = {
	STATIC = "STATIC",       -- Anchored to Blizzard MainMenuExpBar
	DRAGGABLE = "DRAGGABLE", -- User-movable with saved position
}

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

--- Initialize position state (called by OnLoad)
function PositionMixin:InitializePosition()
	local config = self.__xpbar_config or {}
	local positionConfig = config.position or {}
	
	-- Determine mode (default: STATIC)
	local mode = positionConfig.mode or POSITION_MODE.STATIC
	self.__position_mode = mode
	self.__position_key = positionConfig.positionKey or "XPBar_v2_Default"
	
	-- Apply position based on mode
	if mode == POSITION_MODE.STATIC then
		self:ApplyStaticPosition()
	elseif mode == POSITION_MODE.DRAGGABLE then
		self:EnableDragging(true)
		self:RestorePosition()
	end
end

-------------------------------------------------------------------
-- STATIC POSITIONING
-------------------------------------------------------------------

--- Apply static position (anchored to Blizzard bar)
function PositionMixin:ApplyStaticPosition()
	-- Anchor to MainStatusTrackingBarContainer if available
	local container = _G.MainStatusTrackingBarContainer
	if container then
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
		self:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
		return
	end
	
	-- Fallback: anchor to MainMenuExpBar if available
	local expBar = _G.MainMenuExpBar
	if expBar then
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", expBar, "TOPLEFT", 0, 0)
		self:SetPoint("TOPRIGHT", expBar, "TOPRIGHT", 0, 0)
		return
	end
	
	-- Last resort: anchor to bottom of screen
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
end

-------------------------------------------------------------------
-- DRAGGABLE POSITIONING
-------------------------------------------------------------------

--- Enable or disable dragging
---@param enabled boolean True to enable dragging
function PositionMixin:EnableDragging(enabled)
	if enabled then
		self:SetMovable(true)
		self:EnableMouse(true)
		self:RegisterForDrag("LeftButton")
		self:SetScript("OnDragStart", function(frame)
			frame:StartMoving()
		end)
		self:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing()
			frame:SavePosition()
		end)
	else
		self:SetMovable(false)
		self:RegisterForDrag()
		self:SetScript("OnDragStart", nil)
		self:SetScript("OnDragStop", nil)
	end
end

--- Save current position to SavedVariables
function PositionMixin:SavePosition()
	-- Ensure XPChronicleDB exists
	if not XPChronicleDB then
		XPChronicleDB = {}
	end
	if not XPChronicleDB.barPositions then
		XPChronicleDB.barPositions = {}
	end
	
	-- Get first anchor point
	local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
	if not point then
		return
	end
	
	-- Save position
	XPChronicleDB.barPositions[self.__position_key] = {
		point = point,
		relativeTo = "UIParent", -- Always save relative to UIParent for consistency
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
end

--- Restore saved position from SavedVariables
function PositionMixin:RestorePosition()
	-- Check if saved position exists
	if not XPChronicleDB or not XPChronicleDB.barPositions then
		-- No saved positions, use default
		self:SetDefaultDraggablePosition()
		return
	end
	
	local savedPos = XPChronicleDB.barPositions[self.__position_key]
	if not savedPos or not savedPos.point then
		-- No saved position for this key, use default
		self:SetDefaultDraggablePosition()
		return
	end
	
	-- Restore saved position
	self:ClearAllPoints()
	self:SetPoint(
		savedPos.point,
		UIParent,
		savedPos.relativePoint or "TOPLEFT",
		savedPos.x or 0,
		savedPos.y or 0
	)
end

--- Set default position for draggable bars
function PositionMixin:SetDefaultDraggablePosition()
	-- Default: bottom center of screen (above action bars)
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
end

--- Clear saved position
function PositionMixin:ClearSavedPosition()
	if XPChronicleDB and XPChronicleDB.barPositions then
		XPChronicleDB.barPositions[self.__position_key] = nil
	end
end

-------------------------------------------------------------------
-- HELPER METHODS
-------------------------------------------------------------------

--- Get position key for this bar
---@return string key Position key for SavedVariables
function PositionMixin:GetPositionKey()
	return self.__position_key or "XPBar_v2_Default"
end

--- Get position mode
---@return string mode "STATIC" or "DRAGGABLE"
function PositionMixin:GetPositionMode()
	return self.__position_mode or POSITION_MODE.STATIC
end

--- Reset position to default
function PositionMixin:ResetPosition()
	if self.__position_mode == POSITION_MODE.STATIC then
		self:ApplyStaticPosition()
	else
		self:ClearSavedPosition()
		self:SetDefaultDraggablePosition()
	end
end

return PositionMixin
