-- XP Chronicle - Flat XP Bar Mixin (Solid colors, modern style)
-- Uses XPC_XPBarMixinBase for shared logic

-- Addon namespace
local Addon = XPChronicle

-- Get shared dimensions
local BAR_WIDTH, BAR_HEIGHT = XPC_XPBarMixinBase.GetBarDimensions()
BAR_HEIGHT = 30  -- Override for Flat bar height

-----------------------------------
-- Container Mixin
-----------------------------------
XPC_FlatXPBarContainerMixin = {}

function XPC_FlatXPBarContainerMixin:OnLoad()
	local Addon = XPChronicle
	
	-- IMPORTANT: Stay hidden until controller shows us based on barStyle setting
	self:Hide()
	
	-- Container sizing
	if self.Bar then
		self.Bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
		
		if self.Bar.StatusBar then
			self.Bar.StatusBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
		end
		
		-- Wire up on-bar text elements from StatusBar to main bar
		if self.Bar.StatusBar then
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
		
		self:EnableDrag({
			button = "LeftButton",
			requireModifier = "SHIFT",
		})
	else
		-- Schedule a retry after PLAYER_LOGIN
		C_Timer.After(1, function()
			if self.RetryDraggingSetup then
				self:RetryDraggingSetup()
			end
		end)
	end
end

-- Retry dragging setup if mixins weren't available at OnLoad
function XPC_FlatXPBarContainerMixin:RetryDraggingSetup()
	local Addon = XPChronicle
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
		
		self:EnableDrag({
			button = "LeftButton",
			requireModifier = "SHIFT",
		})
	end
end

-- Lock/unlock bar position
function XPC_FlatXPBarContainerMixin:SetLocked(locked)
	if locked then
		-- Disable dragging
		self:SetMovable(false)
	else
		-- Enable dragging
		self:SetMovable(true)
		-- Re-enable drag if mixins are available
		if self.EnableDrag then
			self:EnableDrag({
				button = "LeftButton",
				requireModifier = "SHIFT",
			})
		end
	end
end

-----------------------------------
-- Flat XP Bar Mixin (Solid colors)
-----------------------------------
XPC_FlatXPBarMixin = CreateFromMixins(XPC_XPBarMixinBase)

function XPC_FlatXPBarMixin:OnLoad()
	-- Initialize shared state
	self:InitializeState()
	
	-- Initialize StatusBar with solid color
	if self.StatusBar then
		self.StatusBar:SetMinMaxValues(0, 1)
		self.StatusBar:SetValue(0)
		
		-- Set initial color based on rested state
		self:UpdateStatusBarColor()
	end
	
	-- Initialize overlay colors once
	self:InitializeOverlayColors()

	-- Register common events
	self:RegisterCommonEvents()
end

function XPC_FlatXPBarMixin:OnEvent(event, ...)
	-- Use base handler
	self:HandleEvent(event, ...)
end

function XPC_FlatXPBarMixin:OnShow()
	self:FullUpdate()
end

function XPC_FlatXPBarMixin:OnHide()
	-- Cleanup if needed
end

-- Forward drag events to container for Shift+drag functionality
function XPC_FlatXPBarMixin:OnMouseDown(button)
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

function XPC_FlatXPBarMixin:OnMouseUp(button)
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
function XPC_FlatXPBarMixin:UpdateVisuals()
	self:UpdateStatusBarColor()
end

-- Initialize overlay colors once at startup
function XPC_FlatXPBarMixin:InitializeOverlayColors()
	-- Overlays are now on StatusBar, not on self
	if not self.StatusBar then return end
	
	-- Rested overlay - now uses SetVertexColor since we added file="WHITE8X8"
	if self.StatusBar.RestedOverlay then
		local c = XPC_XPBarColors:GetUserColor(Color.Rested)
		self.StatusBar.RestedOverlay:SetVertexColor(c.r, c.g, c.b, c.a)
	end
	
	-- Note: Quest overlay colors are set in ApplyLayout when shown
	-- This allows dynamic color updates if needed
end

-- Called when user changes colors in color picker
function XPC_FlatXPBarMixin:UpdateBarOverlayColors()
	-- Update the main bar color immediately
	self:UpdateStatusBarColor()
	
	-- Re-apply current layout to update overlay colors
	local state = self:CalculateBarState()
	local layout = self:CalculateBarLayout(state)
	self:ApplyLayout(layout)
end

function XPC_FlatXPBarMixin:UpdateStatusBarColor()
	if not self.StatusBar then 
		return 
	end
	
	local restedState = self:GetRestedState()
	
	if(restedState.isRested) then
		-- Use user's rested color for rested gain
		local color = XPC_XPBarColors:GetUserColor(Color.XpBarRested)
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
		return
	end

	local color = XPC_XPBarColors:GetUserColor(Color.XpBar)
	self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

-- Flash effect implementation (solid color)
function XPC_FlatXPBarMixin:SetFlashAlpha(alpha)
	if not self.GainFlash then
		return
	end
	
	if alpha > 0 then
		-- Check if this is a level-up flash (gold color)
		if self.animationState and self.animationState.isLevelUpFlash then
			-- Gold color for level-up celebration
			self.GainFlash:SetColorTexture(1.0, 0.84, 0.0, alpha)
		else
			-- Update flash color based on rested state for XP gains
			local isRested = self.animationState.isRestedGain
			if isRested then
				-- Use user's rested color for flash
				local c = XPC_XPBarColors:GetUserColor(Color.Rested)
				self.GainFlash:SetColorTexture(c.r, c.g, c.b, alpha)
			else
				-- Use user's XP bar color for flash
				local c = XPC_XPBarColors:GetUserColor(Color.XpBar)
				self.GainFlash:SetColorTexture(c.r, c.g, c.b, alpha)
			end
		end
		self.GainFlash:Show()
	else
		self.GainFlash:Hide()
	end
end

-- Implementation-specific: Update rested XP overlay (solid color texture)
function XPC_FlatXPBarMixin:UpdateRested()
	if not self.StatusBar or not self.StatusBar.RestedOverlay then return end
	
	local restedDims = self:CalculateRestedDimensions()
	
	if restedDims then
		self.state.restedXP = restedDims.restedXP
		
		-- Hide overlay if fully rested (same logic as Blizzard)
		if restedDims.isFullyRested then
			self.StatusBar.RestedOverlay:Hide()
		else
			-- Position overlay after quest overlays
			local questOffset = restedDims.questOffset or 0
			local offsetPixels = math.floor((questOffset / self.state.maxXP) * BAR_WIDTH)
			local width = restedDims.restedWidth

			-- Bounds check: ensure we don't exceed bar width
			if offsetPixels + width <= BAR_WIDTH + 1 then  -- +1 for floating point tolerance
				-- Update overlay size and position
				self.StatusBar.RestedOverlay:ClearAllPoints()
				self.StatusBar.RestedOverlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", offsetPixels, 0)
				self.StatusBar.RestedOverlay:SetWidth(math.max(1, width))  -- Minimum 1 pixel
				self.StatusBar.RestedOverlay:Show()
			else
				-- Clamp to remaining space
				local remainingWidth = math.max(0, BAR_WIDTH - offsetPixels)
				if remainingWidth > 1 then
					self.StatusBar.RestedOverlay:ClearAllPoints()
					self.StatusBar.RestedOverlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", offsetPixels, 0)
					self.StatusBar.RestedOverlay:SetWidth(remainingWidth)
					self.StatusBar.RestedOverlay:Show()
				else
					self.StatusBar.RestedOverlay:SetWidth(0)
					self.StatusBar.RestedOverlay:Hide()
				end
			end
		end
	else
		self.StatusBar.RestedOverlay:Hide()
	end
end

-----------------------------------
-- Quest Overlay System
-----------------------------------

-- NEW ARCHITECTURE: Apply calculated layout to UI
function XPC_FlatXPBarMixin:ApplyLayout(layout)
	if not layout.visible then
		self:Hide()
		return
	end
	
	if not self.StatusBar then return end
	
	-- Update main bar (already animated separately)
	-- Note: Main bar animation is handled by the animation system
	
	-- Apply quest complete overlay
	if layout.questComplete.visible and self.StatusBar.QuestOverlayComplete then
		-- Get color fresh from user settings
		local c = XPC_XPBarColors:GetUserColor(Color.QuestComplete)
		if c then
			self.StatusBar.QuestOverlayComplete:SetVertexColor(c.r, c.g, c.b, c.a)
		end
		self.StatusBar.QuestOverlayComplete:ClearAllPoints()
		self.StatusBar.QuestOverlayComplete:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", layout.questComplete.offsetPixels, 0)
		self.StatusBar.QuestOverlayComplete:SetWidth(layout.questComplete.pixels)
		self.StatusBar.QuestOverlayComplete:Show()
	elseif self.StatusBar.QuestOverlayComplete then
		self.StatusBar.QuestOverlayComplete:Hide()
	end
	
	-- Apply quest incomplete overlay
	if layout.questIncomplete.visible and self.StatusBar.QuestOverlayIncomplete then
		-- Get color fresh from user settings
		local c = XPC_XPBarColors:GetUserColor(Color.QuestIncomplete)
		if c then
			self.StatusBar.QuestOverlayIncomplete:SetVertexColor(c.r, c.g, c.b, c.a)
		end
		self.StatusBar.QuestOverlayIncomplete:ClearAllPoints()
		self.StatusBar.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", layout.questIncomplete.offsetPixels, 0)
		self.StatusBar.QuestOverlayIncomplete:SetWidth(layout.questIncomplete.pixels)
		self.StatusBar.QuestOverlayIncomplete:Show()
	elseif self.StatusBar.QuestOverlayIncomplete then
		self.StatusBar.QuestOverlayIncomplete:Hide()
	end
	
	-- Apply rested overlay
	if layout.rested.visible and not layout.rested.isFullyRested and self.StatusBar.RestedOverlay then
		-- Apply user color (fresh from config)
		local c = XPC_XPBarColors:GetUserColor(Color.Rested)
		self.StatusBar.RestedOverlay:SetVertexColor(c.r, c.g, c.b, c.a)
		self.StatusBar.RestedOverlay:ClearAllPoints()
		self.StatusBar.RestedOverlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", layout.rested.offsetPixels, 0)
		self.StatusBar.RestedOverlay:SetWidth(layout.rested.pixels)
		self.StatusBar.RestedOverlay:Show()
	elseif self.StatusBar.RestedOverlay then
		self.StatusBar.RestedOverlay:Hide()
	end
end

-- OLD ARCHITECTURE: Keep for backward compatibility during migration

-- Set complete quest overlay (orange) with offset support
function XPC_FlatXPBarMixin:SetCompleteQuestOverlay(percent, offset, show)
	if not self.StatusBar or not self.StatusBar.QuestOverlayComplete then return end
	
	if show and percent > 0 then
		-- Set user's color before showing
		local c = XPC_XPBarColors:GetUserColor(Color.QuestComplete)
		self.StatusBar.QuestOverlayComplete:SetVertexColor(c.r, c.g, c.b, c.a)

		-- Calculate width and position (minimum 1 pixel)
		local width = math.max(1, math.floor(BAR_WIDTH * percent))
		local offsetPixels = 0 -- Complete quest starts at current XP (no offset)

		-- Position and size the overlay
		self.StatusBar.QuestOverlayComplete:ClearAllPoints()
		self.StatusBar.QuestOverlayComplete:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", offsetPixels, 0)
		self.StatusBar.QuestOverlayComplete:SetWidth(width)
		
		self.StatusBar.QuestOverlayComplete:Show()
	else
		self.StatusBar.QuestOverlayComplete:SetWidth(0)
		self.StatusBar.QuestOverlayComplete:Hide()
	end
end

-- Set incomplete quest overlay (yellow) with offset support
function XPC_FlatXPBarMixin:SetIncompleteQuestOverlay(percent, offset, show)
	if not self.StatusBar or not self.StatusBar.QuestOverlayIncomplete then
		return
	end

	if show and percent > 0 then
		-- Set user's color before showing
		local c = XPC_XPBarColors:GetUserColor(Color.QuestIncomplete)
		self.StatusBar.QuestOverlayIncomplete:SetVertexColor(c.r, c.g, c.b, c.a)

		-- Calculate width and position (offset by complete quest XP)
		local width = math.max(1, math.floor(BAR_WIDTH * percent))
		local offsetPixels = math.floor((offset / self.state.maxXP) * BAR_WIDTH)

		-- Bounds check: ensure we don't exceed bar width
		if offsetPixels + width <= BAR_WIDTH then
			-- Position and size the overlay
			self.StatusBar.QuestOverlayIncomplete:ClearAllPoints()
			self.StatusBar.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", offsetPixels, 0)
			self.StatusBar.QuestOverlayIncomplete:SetWidth(width)
			
			self.StatusBar.QuestOverlayIncomplete:Show()
		else
			-- If it would exceed the bar, hide it
			self.StatusBar.QuestOverlayIncomplete:SetWidth(0)
			self.StatusBar.QuestOverlayIncomplete:Hide()
		end
	else
		self.StatusBar.QuestOverlayIncomplete:SetWidth(0)
		self.StatusBar.QuestOverlayIncomplete:Hide()
	end
end

-----------------------------------
-- Color Update Methods
-----------------------------------

-- Update all bar colors from user settings
function XPC_FlatXPBarMixin:UpdateAllColors()
	-- Update main bar color
	self:UpdateStatusBarColor()
	
	-- Update rested overlay color
	if self.RestedOverlay then
		local c = XPC_XPBarColors:GetUserColor(Color.Rested)
		self.RestedOverlay:SetColorTexture(c.r, c.g, c.b, c.a)
	end
	
	-- Trigger full update to reapply all overlays with new colors
	self:UpdateBarDisplay()
end
