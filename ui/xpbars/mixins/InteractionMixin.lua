-- XP Bar Enhanced - Interaction Mixin (v2)
-- Behavior mixin for mouse handling and click interactions (non-tooltip)

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
	
	-- Default: no action on mouse down
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
	
	-- Default click action: toggle stats view (if available)
	if button == "LeftButton" then
		self:OnLeftClick()
	elseif button == "RightButton" then
		self:OnRightClick()
	end
end

--- OnLeftClick - Handle left mouse click
function InteractionMixin:OnLeftClick()
	-- Default: toggle stats frame if available
	local addon = XPBarEnhanced
	if addon and addon.UI and addon.UI.Views and addon.UI.Views.Stats then
		local statsView = addon.UI.Views.Stats
		if statsView.Toggle then
			statsView:Toggle()
		end
	end
end

--- OnRightClick - Handle right mouse click
function InteractionMixin:OnRightClick()
	-- Default: open options if available
	local addon = XPBarEnhanced
	if addon and addon.OpenOptions then
		addon:OpenOptions()
	elseif Settings and Settings.OpenToCategory then
		Settings.OpenToCategory("XP Bar Enhanced")
	end
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
