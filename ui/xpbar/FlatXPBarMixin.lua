-- XP Bar Enhanced - Flat XP Bar Mixin (Solid colors, modern style)

local Addon = XPBarEnhanced

-- Get shared dimensions
local BAR_WIDTH, BAR_HEIGHT = XPBarMixinBase.GetBarDimensions()
BAR_HEIGHT = 30 -- Override for Flat bar height

-----------------------------------
-- Container Mixin
-----------------------------------

-- InitPositionStorage signature declared centrally in core/Types.lua

local FlatXPBarContainerMixin = {}

function FlatXPBarContainerMixin:OnLoad()
	local Addon = XPBarEnhanced

	-- IMPORTANT: Stay hidden until controller shows us based on barStyle setting
	self:Hide()

	-- Container sizing
	if self.Bar then
		self.Bar:SetSize(BAR_WIDTH, BAR_HEIGHT)

		if self.Bar.StatusBar then
			self.Bar.StatusBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
		end

		-- Wire up text elements
		self:WireTextElements()
	end

	-- Enable dragging for Flat bar (Shift+drag)
	self:SetFrameStrata("LOW")
	self:SetMovable(true)
	self:SetUserPlaced(false)
	self:SetClampedToScreen(true)
	self:EnableMouse(true)

	-- Get mixins and apply them
	local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
	local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin

	if PositionStoreMixin and DraggableFrameMixin then
		Mixin(self, PositionStoreMixin, DraggableFrameMixin)
		self:InitPositionStorage(
			function()
				return Addon.db and Addon.db.barPosition
			end,
			function(pos)
				if Addon.db then
					Addon.db.barPosition = pos
				end
			end,
			function()
				return Addon.defaults and Addon.defaults.barPosition
			end
		)

		self:EnableDrag(
			{
				button = "LeftButton",
				requireModifier = "SHIFT"
			}
		)
	else
		-- Schedule a retry after PLAYER_LOGIN (cancelable)
		if self._dragRetryTimer then
			self._dragRetryTimer:Cancel()

			self._dragRetryTimer = nil
		end
		self._dragRetryTimer =
			C_Timer.NewTimer(
			1,
			function()
				if not self or not self:IsShown() then
					self._dragRetryTimer = nil
					return
				end
				if self.RetryDraggingSetup then
					self:RetryDraggingSetup()
				end
				self._dragRetryTimer = nil
			end
		)
	end
end

function FlatXPBarContainerMixin:WireTextElements()
	if not self.Bar then
		return
	end

	-- Wire up on-bar text elements from OverlayFrame to main bar
	if self.Bar.OverlayFrame then
		self.Bar.LevelText = self.Bar.OverlayFrame.LevelText
		self.Bar.XPText = self.Bar.OverlayFrame.XPText
		self.Bar.PercentText = self.Bar.OverlayFrame.PercentText
	end

	-- Wire up below-bar text elements to the bar for easy access
	if self.BelowBarTextContainer then
		self.Bar.RateText = self.BelowBarTextContainer.RateText
		self.Bar.SessionText = self.BelowBarTextContainer.SessionText
		self.Bar.QuestSummaryText = self.BelowBarTextContainer.QuestSummaryText
	end
end

function FlatXPBarContainerMixin:OnShow()
	-- Ensure text elements are wired up (in case OnLoad timing issues)
	self:WireTextElements()
end

function FlatXPBarContainerMixin:OnHide()
	if self._dragRetryTimer then
		self._dragRetryTimer:Cancel()

		self._dragRetryTimer = nil
	end
end

-- Retry dragging setup if mixins weren't available at OnLoad
function FlatXPBarContainerMixin:RetryDraggingSetup()
	local Addon = XPBarEnhanced
	local PositionStoreMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.PositionStoreMixin
	local DraggableFrameMixin = Addon.UI and Addon.UI.Mixins and Addon.UI.Mixins.DraggableFrameMixin

	if PositionStoreMixin and DraggableFrameMixin then
		Mixin(self, PositionStoreMixin, DraggableFrameMixin)
		self:InitPositionStorage(
			function()
				return Addon.db and Addon.db.barPosition
			end,
			function(pos)
				if Addon.db then
					Addon.db.barPosition = pos
				end
			end,
			function()
				return Addon.defaults and Addon.defaults.barPosition
			end
		)

		self:EnableDrag(
			{
				button = "LeftButton",
				requireModifier = "SHIFT"
			}
		)
	end
end

-- Lock/unlock bar position
function FlatXPBarContainerMixin:SetLocked(locked)
	if locked then
		-- Disable dragging
		self:SetMovable(false)
		self.isDraggable = false
	else
		-- Enable dragging
		self:SetMovable(true)
		-- Re-enable drag if mixins are available
		if self.EnableDrag then
			self:EnableDrag(
				{
					button = "LeftButton",
					requireModifier = "SHIFT"
				}
			)
			self.isDraggable = true
		end
	end
end

-----------------------------------
-- Flat XP Bar Mixin (Solid colors)
-----------------------------------
local FlatXPBarMixin = CreateFromMixins(XPBarMixinBase)

function FlatXPBarMixin:OnLoad()
	-- Initialize shared state
	self:InitializeState()

	-- Identify style for debugging
	self._barStyle = "Flat"

	-- Initialize StatusBar with solid color
	if self.StatusBar then
		self.StatusBar:SetMinMaxValues(0, 1)
		self.StatusBar:SetValue(0)

		-- Use the StatusBar's default smoothing for the flat bar (legacy behavior).
		-- Do not disable built-in smoothing here to avoid visible jumps when other
		-- systems or templates drive the StatusBar value.

		-- Set initial color based on rested state
		self:UpdateStatusBarColor()
	end

	-- Initialize overlay colors once
	self:InitializeOverlayColors()

	-- No StatusBar:SetValue hook for flat bar — rely on the widget's smoothing
	-- instead of a complex override which can interact poorly with other addons.

	-- Register common events
	self:RegisterCommonEvents()

	-- Mark this instance as the Flat/StatusBar-based bar so AnimateToValue can
	-- use the StatusBar's native smoothing (if present) for visually reliable
	-- interpolation.
	self.isFlatBar = true
end

-- Set display value (override for StatusBar-based rendering)
-- For flat bars, this is only called by non-animation code paths since
-- flat bars use native StatusBar smoothing for animations.
function FlatXPBarMixin:SetDisplayValue(ratio)
	if not self.StatusBar then
		return
	end

	ratio = tonumber(ratio) or 0
	ratio = math.max(0, math.min(1, ratio))
	self:UpdateStatusBarValue(ratio)
end

-- Export mixins into the Addon namespace (namespaced) and global table for XML compatibility
Addon.Mixins = Addon.Mixins or {}
Addon.Mixins.FlatXPBarContainerMixin = FlatXPBarContainerMixin
Addon.Mixins.FlatXPBarMixin = FlatXPBarMixin
-- Legacy compatibility
_G.FlatXPBarContainerMixin = FlatXPBarContainerMixin
_G.FlatXPBarMixin = FlatXPBarMixin

function FlatXPBarMixin:OnEvent(event, ...)
	-- Use base handler
	self:HandleEvent(event, ...)
end

function FlatXPBarMixin:OnShow()
	if not self._eventsRegistered and self.RegisterCommonEvents then
		self:RegisterCommonEvents()
	end

	if not self._isUpdating then
		self:FullUpdate()
	end
end

function FlatXPBarMixin:OnHide()
	-- Clean up timers and unsubscribe from events to prevent leaks
	if self.CleanupTimers then
		self:CleanupTimers()
	end
	if self.UnsubscribeFromEvents then
		self:UnsubscribeFromEvents()
	end

	-- Restore original StatusBar SetValue method if we patched it
	if self.StatusBar and self.StatusBar._xpbar_origSetValue then
		self.StatusBar.SetValue = self.StatusBar._xpbar_origSetValue
		self.StatusBar._xpbar_origSetValue = nil
		self.StatusBar._xpbar_owner = nil
		self.StatusBar._xpbar_pendingExternal = nil
	end
end

-- Forward drag events to container for Shift+drag functionality
function FlatXPBarMixin:OnMouseDown(button)
	local container = self:GetParent()
	if container and IsShiftKeyDown() and button == "LeftButton" then
		-- Forward drag to container
		if container:IsMovable() and container.isDragging == nil then
			container:StartMoving()
			container.isDragging = true
		end
		return
	end
end

function FlatXPBarMixin:OnMouseUp(button)
	local container = self:GetParent()

	-- Stop drag if active
	if container and container.isDragging then
		container:StopMovingOrSizing()
		container.isDragging = nil
		-- Save position
		if container.SaveStoredPosition then
			container:SaveStoredPosition()
		end
		return
	end

	-- Alt + Click: Open options panel
	if IsAltKeyDown() then
		Addon.Config:OpenOptions()
		return
	end

	-- Ctrl + Click: Toggle stats window
	if IsControlKeyDown() then
		Addon.Stats:Toggle()
		return
	end
end

-- Implementation-specific: Update StatusBar color based on rested state (solid colors)
function FlatXPBarMixin:UpdateVisuals()
	self:UpdateStatusBarColor()
end

-- Initialize overlay colors once at startup
function FlatXPBarMixin:InitializeOverlayColors()
	-- Overlays are now on StatusBar, not on self
	if not self.StatusBar then
		return
	end

	local statusBar = self.StatusBar

	-- Rested overlay - now uses SetVertexColor since we added file="WHITE8X8"
	if statusBar.RestedOverlay then
		local c = XPBarColors:GetUserColor(Color.Rested)
		statusBar.RestedOverlay:SetVertexColor(c.r, c.g, c.b, c.a)
	end

	-- Note: Quest overlay colors are set in ApplyLayout when shown
	-- This allows dynamic color updates if needed
end

-- Called when user changes colors in color picker
function FlatXPBarMixin:UpdateBarOverlayColors()
	-- Update the main bar color immediately
	self:UpdateStatusBarColor()

	-- Re-apply current layout to update overlay colors
	local state = self:CalculateBarState()
	local layout = self:CalculateBarLayout(state)
	self:ApplyLayout(layout)
end

function FlatXPBarMixin:UpdateStatusBarColor()
	if not self.StatusBar then
		return
	end

	-- Use fully-rested visual when state indicates the rested portion covers
	-- the remaining XP; otherwise, apply regular rested or XP bar coloring.
	if self.state and self.state.isFullyRested then
		local color = XPBarColors:GetUserColor(Color.XpBarRested)
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
		return
	end

	-- Check if player has rested XP available (not just in rested area)
	if self.state and self.state.isRested then
		local color = XPBarColors:GetUserColor(Color.XpBarRested)
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
		return
	end

	local color = XPBarColors:GetUserColor(Color.XpBar)
	self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

-- Flash effect implementation (solid color)
function FlatXPBarMixin:SetFlashAlpha(alpha)
	if not self.GainFlash then
		return
	end

	if alpha > 0 then
		-- Check if this is a level-up flash (gold color)
		if self.animation and self.animation.isLevelUpFlash then
			-- Gold color for level-up celebration
			self.GainFlash:SetColorTexture(1.0, 0.84, 0.0, alpha)
		else
			-- Update flash color based on rested state for XP gains
			local isRested = self.animation and self.animation.isRestedGain
			if isRested then
				-- Use user's rested color for flash
				local c = XPBarColors:GetUserColor(Color.Rested)
				self.GainFlash:SetColorTexture(c.r, c.g, c.b, alpha)
			else
				-- Use user's XP bar color for flash
				local c = XPBarColors:GetUserColor(Color.XpBar)
				self.GainFlash:SetColorTexture(c.r, c.g, c.b, alpha)
			end
		end
		self.GainFlash:Show()
	else
		self.GainFlash:Hide()
	end
end

-- Implementation-specific: Update rested XP overlay (solid color texture)
function FlatXPBarMixin:UpdateRested()
	if not self.StatusBar then
		return
	end

	local statusBar = self.StatusBar
	if not statusBar.RestedOverlay then
		return
	end

	local restedDims = self:CalculateRestedDimensions()

	if restedDims then
		self.state.restedXP = restedDims.restedXP

		-- Show the rested overlay whenever there is a non-zero rested overlay portion
		-- even if the overall rested amount would fully cover the bar. The previous
		-- behavior hid the overlay when the total (current + quests + rested)
		-- exceeded the bar width which prevented the overlay from appearing for
		-- large rested values (e.g. 147%). Instead, compute the actual overlay
		-- width and display it when > 0.
		local questOffset = restedDims.questOffset or 0
		local offsetPixels = math.floor((questOffset / self.state.maxXP) * BAR_WIDTH)
		local width = restedDims.restedWidth

		if width and width > 0 then
			-- Bounds check: ensure we don't exceed bar width
			if offsetPixels + width <= BAR_WIDTH + 1 then -- +1 for floating point tolerance
				-- Update overlay size and position
				statusBar.RestedOverlay:ClearAllPoints()
				statusBar.RestedOverlay:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", offsetPixels, 0)
				statusBar.RestedOverlay:SetWidth(math.max(1, width)) -- Minimum 1 pixel
				statusBar.RestedOverlay:Show()
			else
				-- Clamp to remaining space
				local remainingWidth = math.max(0, BAR_WIDTH - offsetPixels)
				if remainingWidth > 1 then
					statusBar.RestedOverlay:ClearAllPoints()
					statusBar.RestedOverlay:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", offsetPixels, 0)
					statusBar.RestedOverlay:SetWidth(remainingWidth)
					statusBar.RestedOverlay:Show()
				else
					statusBar.RestedOverlay:SetWidth(0)
					statusBar.RestedOverlay:Hide()
				end
			end
		else
			statusBar.RestedOverlay:Hide()
		end
	else
		self.StatusBar.RestedOverlay:Hide()
	end
end

-----------------------------------
-- Quest Overlay System
-----------------------------------

-- NEW ARCHITECTURE: Apply calculated layout to UI
function FlatXPBarMixin:ApplyLayout(layout)
	if not layout.visible then
		if self.HideQuestOverlays then
			self:HideQuestOverlays()
		end
		return
	end

	if not self.StatusBar then
		return
	end

	local parent = self:GetParent()
	-- Only show the container for the active view; avoid revealing inactive views
	local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
	if activeView == self and parent then
		parent:Show()
	end

	-- Update main bar (already animated separately)
	-- Note: Main bar animation is handled by the animation system

	-- Apply quest complete overlay
	if layout.questComplete.visible and self.StatusBar.QuestOverlayComplete then
		-- Get color fresh from user settings
		local c = XPBarColors:GetUserColor(Color.QuestComplete)
		if c then
			self.StatusBar.QuestOverlayComplete:SetVertexColor(c.r, c.g, c.b, c.a)
		end
		self.StatusBar.QuestOverlayComplete:ClearAllPoints()
		self.StatusBar.QuestOverlayComplete:SetPoint(
			"BOTTOMLEFT",
			self.StatusBar,
			"BOTTOMLEFT",
			layout.questComplete.offsetPixels,
			0
		)
		self.StatusBar.QuestOverlayComplete:SetWidth(layout.questComplete.pixels)
		self.StatusBar.QuestOverlayComplete:Show()
	elseif self.StatusBar.QuestOverlayComplete then
		self.StatusBar.QuestOverlayComplete:Hide()
	end

	-- Apply quest incomplete overlay
	if layout.questIncomplete.visible and self.StatusBar.QuestOverlayIncomplete then
		-- Get color fresh from user settings
		local c = XPBarColors:GetUserColor(Color.QuestIncomplete)
		if c then
			self.StatusBar.QuestOverlayIncomplete:SetVertexColor(c.r, c.g, c.b, c.a)
		end
		self.StatusBar.QuestOverlayIncomplete:ClearAllPoints()
		self.StatusBar.QuestOverlayIncomplete:SetPoint(
			"BOTTOMLEFT",
			self.StatusBar,
			"BOTTOMLEFT",
			layout.questIncomplete.offsetPixels,
			0
		)
		self.StatusBar.QuestOverlayIncomplete:SetWidth(layout.questIncomplete.pixels)
		self.StatusBar.QuestOverlayIncomplete:Show()
	elseif self.StatusBar.QuestOverlayIncomplete then
		self.StatusBar.QuestOverlayIncomplete:Hide()
	end

	-- Apply rested overlay
	-- if the rested portion fully covers the remaining XP, hide
	-- the overlay and let the view change the gained-XP visuals to indicate
	-- a fully-rested state. Otherwise show the rested overlay for the
	-- partial rested portion.
	-- Note: isFullyRested state is now set in UpdateBarDisplay, not here
	if
		layout.rested.visible and not layout.rested.isFullyRested and (layout.rested.pixels or 0) > 0 and
			self.StatusBar.RestedOverlay
	 then
		-- Apply user color (fresh from config)
		local c = XPBarColors:GetUserColor(Color.Rested)
		self.StatusBar.RestedOverlay:SetVertexColor(c.r, c.g, c.b, c.a)
		self.StatusBar.RestedOverlay:ClearAllPoints()
		self.StatusBar.RestedOverlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", layout.rested.offsetPixels, 0)
		self.StatusBar.RestedOverlay:SetWidth(layout.rested.pixels)
		self.StatusBar.RestedOverlay:Show()
	elseif self.StatusBar.RestedOverlay then
		self.StatusBar.RestedOverlay:Hide()
	end

	-- Update status bar color based on current state
	self:UpdateStatusBarColor()
end

-----------------------------------
-- Color Update Methods
-----------------------------------

-- Update all bar colors from user settings
function FlatXPBarMixin:UpdateAllColors()
	-- Update main bar color
	self:UpdateStatusBarColor()

	-- Update rested overlay color
	if self.RestedOverlay then
		local c = XPBarColors:GetUserColor(Color.Rested)
		self.RestedOverlay:SetColorTexture(c.r, c.g, c.b, c.a)
	end

	-- Trigger full update to reapply all overlays with new colors
	self:UpdateBarDisplay()
end
