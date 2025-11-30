-- XP Bar Enhanced - Interaction Mixin ()
-- Behavior mixin for mouse handling and click interactions (non-tooltip)

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- GLOBAL INTERACTION MIXIN
-------------------------------------------------------------------

---@class XPBarInteractionMixin
XPBarInteractionMixin = {}

local InteractionMixin = XPBarInteractionMixin

-------------------------------------------------------------------
-- MOUSE HANDLERS
-------------------------------------------------------------------

--- OnMouseDown - Handle mouse button press
---@param button string Button name ("LeftButton", "RightButton", etc.)
function InteractionMixin:OnMouseDown(button)
	local config = self.__xpbar_config or {}
	local interactionConfig = config.interaction or {}

	if interactionConfig.enabled == false then
		return
	end

	-- Handle Shift + Left click for dragging (if in DRAGGABLE mode)
	if button == "LeftButton" and IsShiftKeyDown() then
		if self.GetPositionMode then
			local positionMode = self:GetPositionMode()
			local locked = Addon.db and Addon.db.barLocked or false
			if positionMode == "DRAGGABLE" and self:IsMovable() and not locked then
				self:StartMoving()
				self.__isDragging = true
				return
			end
		end
	end

	-- Styles can override this method for custom behavior
end

--- OnMouseUp - Handle mouse button release
---@param button string Button name
function InteractionMixin:OnMouseUp(button)
	local config = self.__xpbar_config or {}
	local interactionConfig = config.interaction or {}

	if interactionConfig.enabled == false then
		return
	end

	-- Stop dragging if active (and don't process any click actions)
	if self.__isDragging then
		self:StopMovingOrSizing()
		self.__isDragging = nil
		if self.SavePosition then
			self:SavePosition()
		end
		return
	end

	-- If Shift is still held down, don't process clicks (user was trying to drag)
	if IsShiftKeyDown() then
		return
	end

	-- Alt + Click: Open options
	if IsAltKeyDown() then
		self:OnAltClick(button)
		return
	end

	-- Ctrl + Click: Toggle stats
	if IsControlKeyDown() then
		self:OnCtrlClick(button)
		return
	end

	-- Regular click (no modifiers)
	if button == "LeftButton" then
		self:OnLeftClick()
	end
end

--- OnAltClick - Handle Alt + Click (open options)
function InteractionMixin:OnAltClick(button)
	if Addon and Addon.Options and Addon.Options.Open then
		Addon.Options:Open()
	elseif Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(Addon.OptionsCategory)
	end
end

--- OnCtrlClick - Handle Ctrl + Click (toggle stats)
function InteractionMixin:OnCtrlClick(button)
	if Addon and Addon.Stats and Addon.Stats.Toggle then
		Addon.Stats:Toggle()
	end
end

--- OnLeftClick - Handle left mouse click
function InteractionMixin:OnLeftClick()
	-- Styles can override this method for custom behavior
end

--- OnRightClick - Handle right mouse click
function InteractionMixin:OnRightClick()
	-- Right-click intentionally disabled to match classic interaction parity.
	-- Keep this method present so styles can override if they really need it,
	-- but do nothing by default to avoid unexpected context menu behavior.
end

-------------------------------------------------------------------
-- KEYBOARD HANDLERS (Optional)
-------------------------------------------------------------------

--- OnKeyDown - Handle keyboard input (optional)
---@param key string Key name
function InteractionMixin:OnKeyDown(key)
	local config = self.__xpbar_config or {}
	local interactionConfig = config.interaction or {}

	if interactionConfig.enabled == false then
		return
	end

	-- Default: no keyboard handling
	-- Styles can override for accessibility features
end

return InteractionMixin
