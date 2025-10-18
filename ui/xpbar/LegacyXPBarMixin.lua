-- XP Bar Enhanced - Legacy XP Bar Mixin (Blizzard-style with atlases)
-- Uses XPBarMixinBase for shared functionality

-- Addon namespace
local Addon = XPBarEnhanced

-- Get shared dimensions
local BAR_WIDTH, BAR_HEIGHT = XPBarMixinBase.GetBarDimensions()

-----------------------------------
-- Exhaustion Tick Mixin
-----------------------------------
ExhaustionTickMixin = {}

function ExhaustionTickMixin:OnEnter()
	local exhaustionStateID, exhaustionStateName, exhaustionStateMultiplier = GetRestState()
	if not exhaustionStateID then
		return
	end
	
	local bar = self:GetParent()
	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")
	local percentXP = math.ceil((currentXP / maxXP) * 100)
	
	local tooltip = GameTooltip
	GameTooltip_SetDefaultAnchor(tooltip, UIParent)
	
	-- Use Blizzard's global constants if available, fallback to manual text
	if GameTooltip_SetTitle and XP_TEXT then
		GameTooltip_SetTitle(tooltip, XP_TEXT:format(BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP), percentXP))
	else
		tooltip:SetText(string.format("XP: %s / %s (%d%%)", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP), percentXP), 1.0, 1.0, 1.0)
	end
	
	-- Add exhaustion state info
	if GameTooltip_AddHighlightLine and EXHAUST_TOOLTIP1 then
		GameTooltip_AddHighlightLine(tooltip, EXHAUST_TOOLTIP1:format(exhaustionStateName, exhaustionStateMultiplier * 100))
	elseif exhaustionStateName then
		tooltip:AddLine(string.format("Bonus: %s (%d%% XP gain)", exhaustionStateName, exhaustionStateMultiplier * 100), 1, 1, 1, true)
	end
	
	if not IsResting() and (exhaustionStateID == 4 or exhaustionStateID == 5) then
		if GameTooltip_AddHighlightLine and EXHAUST_TOOLTIP2 then
			GameTooltip_AddHighlightLine(tooltip, EXHAUST_TOOLTIP2)
		end
	end
	
	tooltip:Show()
end

-----------------------------------
-- Container Mixin
-----------------------------------
LegacyXPBarContainerMixin = {}

function LegacyXPBarContainerMixin:OnLoad()
	-- IMPORTANT: Stay hidden until controller shows us based on barStyle setting
	self:Hide()
	
	-- Container is already sized correctly by XML (571x60)
	-- Bar is already positioned by XML (BOTTOMLEFT 1, 43)
	-- Just ensure bar has correct size (in case it needs runtime adjustment)
	if self.Bar then
		self.Bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
		
		-- Ensure StatusBar is also sized correctly
		if self.Bar.StatusBar then
			self.Bar.StatusBar:SetSize(BAR_WIDTH, BAR_HEIGHT - 1)
		end
		
		-- Wire up text elements
		self:WireTextElements()
	end
	
	-- Position this container to match Blizzard's XP bar
	-- Try immediately, and retry after a delay if Blizzard bar not found
	self:PositionToMatchBlizzardBar()
	
	-- Retry positioning after 0.5s in case Blizzard bars aren't loaded yet
	C_Timer.After(0.5, function()
		if self and self.PositionToMatchBlizzardBar then
			self:PositionToMatchBlizzardBar()
		end
	end)
end

function LegacyXPBarContainerMixin:WireTextElements()
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

function LegacyXPBarContainerMixin:OnShow()
	-- Ensure text elements are wired up (in case OnLoad timing issues)
	self:WireTextElements()
end

function LegacyXPBarContainerMixin:PositionToMatchBlizzardBar()
	-- Simple and reliable: anchor to MainStatusTrackingBarContainer's top-left
	local container = _G.MainStatusTrackingBarContainer
	
	if not container then
		return
	end
	
	self:ClearAllPoints()
	self:SetPoint("TOP", container, "TOP", 0, 5)
end

-----------------------------------
-- Legacy XP Bar Mixin (Blizzard-style)
-----------------------------------
---@class LegacyXPBarMixin : XPBarMixinBase
---@field StatusBar XPStatusBar
LegacyXPBarMixin = CreateFromMixins(XPBarMixinBase)

function LegacyXPBarMixin:OnLoad()
	-- Initialize shared state
	self:InitializeState()
	
	-- Initialize StatusBar
	if self.StatusBar then
		self.StatusBar:SetMinMaxValues(0, 1)
		self.StatusBar:SetValue(0)
		
		-- Set initial colors
		self:UpdateStatusBarColor()
	end
	
	-- Register common events
	self:RegisterCommonEvents()
end

function LegacyXPBarMixin:OnEvent(event, ...)
	-- Use base handler
	self:HandleEvent(event, ...)
end

function LegacyXPBarMixin:OnShow()
	if not self._isUpdating then
		self:FullUpdate()
	end
end

function LegacyXPBarMixin:OnHide()
	-- Unsubscribe from events to prevent memory leaks
	if self.UnsubscribeFromEvents then
		self:UnsubscribeFromEvents()
	end
end

-- Implementation-specific: Update StatusBar appearance based on rested state
function LegacyXPBarMixin:UpdateVisuals()
	self:UpdateStatusBarColor()
end

-- Initialize overlay colors (called from View:Initialize after SavedVariables are loaded)
function LegacyXPBarMixin:InitializeColors()
	-- Apply user's custom colors
	self:UpdateAllColors()
	-- DO NOT call UpdateBarDisplay() here - it would show the container!
	-- Controller will handle visibility via SetBarStyle()
end

-- Initialize overlay colors once at startup
function LegacyXPBarMixin:InitializeOverlayColors()
	-- Apply user's custom colors
	self:UpdateAllColors()
end

-- Legacy bar now supports color customization (like Flat bar)
function LegacyXPBarMixin:UpdateBarOverlayColors()
	-- Update the main bar color immediately
	self:UpdateStatusBarColor()
	
	-- Re-apply current layout to update overlay colors
	local state = self:CalculateBarState()
	local layout = self:CalculateBarLayout(state)
	self:ApplyLayout(layout)
end

function LegacyXPBarMixin:UpdateStatusBarTexture()
	-- No longer using atlas - colors are now customizable
	-- StatusBar color is set by UpdateStatusBarColor()
end

function LegacyXPBarMixin:UpdateStatusBarColor()
	if not self.StatusBar then 
		return 
	end
	
	local restedState = self:GetRestedState()
	
	if restedState.isRested then
		-- Use user's rested color for rested state
		local color = XPBarColors:GetUserColor(Color.XpBarRested)
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
	else
		-- Use user's normal XP bar color
		local color = XPBarColors:GetUserColor(Color.XpBar)
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
	end
end

function LegacyXPBarMixin:UpdateGainFlashTexture()
	-- No longer using atlas - flash is now solid color
	-- Flash color is set by SetFlashAlpha()
end

-- Flash effect implementation (solid color for customization)
function LegacyXPBarMixin:SetFlashAlpha(alpha)
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
			local isRested = self.animationState and self.animationState.isRestedGain
			if isRested then
				-- Use user's rested overlay color for flash
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

-- Implementation-specific: Update rested XP overlay (now with customizable colors)
function LegacyXPBarMixin:UpdateRested()
	if not self.ExhaustionLevelFillBar then return end
	
	-- Apply user's rested overlay color
	local restedColor = XPBarColors:GetUserColor(Color.Rested)
	self.ExhaustionLevelFillBar:SetVertexColor(restedColor.r, restedColor.g, restedColor.b, restedColor.a)
	
	local restedDims = self:CalculateRestedDimensions()
	
	if restedDims then
		self.state.restedXP = restedDims.restedXP
		
		-- Hide overlay if fully rested (Blizzard behavior)
		if restedDims.isFullyRested then
			self.ExhaustionLevelFillBar:Hide()
			if self.ExhaustionTick then
				self.ExhaustionTick:Hide()
			end
		else
			-- Position overlay after quest overlays
			local questOffset = restedDims.questOffset or 0
			local offsetPixels = math.floor((questOffset / self.state.maxXP) * BAR_WIDTH)
			local width = restedDims.restedWidth
			
			-- Bounds check: ensure we don't exceed bar width
			if offsetPixels + width <= BAR_WIDTH + 1 then  -- +1 for floating point tolerance
				-- Update texture size and position
				self.ExhaustionLevelFillBar:ClearAllPoints()
				self.ExhaustionLevelFillBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offsetPixels, 0)
				self.ExhaustionLevelFillBar:SetWidth(math.max(1, width))  -- Minimum 1 pixel
				self.ExhaustionLevelFillBar:Show()
			else
				-- Clamp to remaining space
				local remainingWidth = math.max(0, BAR_WIDTH - offsetPixels)
				if remainingWidth > 1 then
					self.ExhaustionLevelFillBar:ClearAllPoints()
					self.ExhaustionLevelFillBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offsetPixels, 0)
					self.ExhaustionLevelFillBar:SetWidth(remainingWidth)
					self.ExhaustionLevelFillBar:Show()
				else
					self.ExhaustionLevelFillBar:SetWidth(0)
					self.ExhaustionLevelFillBar:Hide()
					if self.ExhaustionTick then
						self.ExhaustionTick:Hide()
					end
				end
			end
			
			-- Show exhaustion tick ONLY if not at edges
			if self.ExhaustionTick then
				if restedDims.showTick then
					self.ExhaustionTick:Show()
				else
					self.ExhaustionTick:Hide()
				end
			end
		end
	else
		self.ExhaustionLevelFillBar:Hide()
		
		if self.ExhaustionTick then
			self.ExhaustionTick:Hide()
		end
	end
end

-----------------------------------
-- Quest Overlay System
-----------------------------------

-- NEW ARCHITECTURE: Apply calculated layout to UI
function LegacyXPBarMixin:ApplyLayout(layout)
	if not layout.visible then
		if self.HideQuestOverlays then
			self:HideQuestOverlays()
		end
		return
	end

	local parent = self:GetParent()
	-- Only show the container for the active view; avoid revealing inactive views
	local activeView = Addon.XPBar and Addon.XPBar:GetActiveView()
	if activeView == self and parent then
		parent:Show()
	end

	---@type XPStatusBar
	local statusBar = self.StatusBar
	
	-- Update main bar (already animated separately)
	-- Note: Main bar animation is handled by the animation system
	
	-- Apply quest complete overlay (now with user customizable color)
	if layout.questComplete.visible and statusBar and statusBar.QuestOverlayComplete then
		-- Use user's quest complete color
		local color = XPBarColors:GetUserColor(Color.QuestComplete)
		statusBar.QuestOverlayComplete:SetVertexColor(color.r, color.g, color.b, color.a)
		statusBar.QuestOverlayComplete:ClearAllPoints()
		statusBar.QuestOverlayComplete:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", layout.questComplete.offsetPixels, 0)
		statusBar.QuestOverlayComplete:SetWidth(layout.questComplete.pixels)
		statusBar.QuestOverlayComplete:Show()
	elseif statusBar and statusBar.QuestOverlayComplete then
		statusBar.QuestOverlayComplete:Hide()
	end
	
	-- Apply quest incomplete overlay (now with user customizable color)
	if layout.questIncomplete.visible and statusBar and statusBar.QuestOverlayIncomplete then
		-- Use user's quest incomplete color
		local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
		statusBar.QuestOverlayIncomplete:SetVertexColor(color.r, color.g, color.b, color.a)
		statusBar.QuestOverlayIncomplete:ClearAllPoints()
		statusBar.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", layout.questIncomplete.offsetPixels, 0)
		statusBar.QuestOverlayIncomplete:SetWidth(layout.questIncomplete.pixels)
		statusBar.QuestOverlayIncomplete:Show()
	elseif statusBar and statusBar.QuestOverlayIncomplete then
		statusBar.QuestOverlayIncomplete:Hide()
	end
	
	-- Apply rested overlay (now with user customizable color)
	if layout.rested.visible and not layout.rested.isFullyRested and statusBar and statusBar.ExhaustionLevelFillBar then
		-- Apply user's rested overlay color
		local restedColor = XPBarColors:GetUserColor(Color.Rested)
		statusBar.ExhaustionLevelFillBar:SetVertexColor(restedColor.r, restedColor.g, restedColor.b, restedColor.a)
		statusBar.ExhaustionLevelFillBar:ClearAllPoints()
		statusBar.ExhaustionLevelFillBar:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", layout.rested.offsetPixels, 0)
		statusBar.ExhaustionLevelFillBar:SetWidth(layout.rested.pixels)
		statusBar.ExhaustionLevelFillBar:Show()
		
		-- Show exhaustion tick if appropriate (now child of StatusBar)
		if statusBar.ExhaustionTick and layout.rested.showTick then
			statusBar.ExhaustionTick:Show()
		elseif statusBar.ExhaustionTick then
			statusBar.ExhaustionTick:Hide()
		end
	elseif statusBar and statusBar.ExhaustionLevelFillBar then
		statusBar.ExhaustionLevelFillBar:Hide()
		if statusBar.ExhaustionTick then
			statusBar.ExhaustionTick:Hide()
		end
	end
end

-- OLD ARCHITECTURE: Keep for backward compatibility during migration
-- Set the complete quest overlay width and visibility with offset support
function LegacyXPBarMixin:SetCompleteQuestOverlay(percent, offset, show)
	if not self.QuestOverlayComplete then
		return
	end
	
	if show and percent > 0 then
		-- Use user's quest complete color
		local color = XPBarColors:GetUserColor(Color.QuestComplete)
		self.QuestOverlayComplete:SetVertexColor(color.r, color.g, color.b, color.a)
		
		-- Calculate width and position (minimum 1 pixel)
		local width = math.max(1, math.floor(BAR_WIDTH * percent))
		local offsetPixels = 0  -- Complete quest starts at current XP (no offset)
		
		-- Position and size the overlay
		self.QuestOverlayComplete:ClearAllPoints()
		self.QuestOverlayComplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offsetPixels, 0)
		self.QuestOverlayComplete:SetWidth(width)
		self.QuestOverlayComplete:Show()
	else
		self.QuestOverlayComplete:SetWidth(0)
		self.QuestOverlayComplete:Hide()
	end
end

-- Set incomplete quest overlay with offset support
function LegacyXPBarMixin:SetIncompleteQuestOverlay(percent, offset, show)
	if not self.QuestOverlayIncomplete then
		return
	end
	
	if show and percent > 0 then
		-- Use user's quest incomplete color
		local color = XPBarColors:GetUserColor(Color.QuestIncomplete)
		self.QuestOverlayIncomplete:SetVertexColor(color.r, color.g, color.b, color.a)
		
		-- Calculate width and position (offset by complete quest XP)
		local width = math.max(1, math.floor(BAR_WIDTH * percent))
		local offsetPixels = math.floor((offset / self.state.maxXP) * BAR_WIDTH)
		
		-- Bounds check: ensure we don't exceed bar width
		if offsetPixels + width <= BAR_WIDTH then
			-- Position and size the overlay
			self.QuestOverlayIncomplete:ClearAllPoints()
			self.QuestOverlayIncomplete:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offsetPixels, 0)
			self.QuestOverlayIncomplete:SetWidth(width)
			self.QuestOverlayIncomplete:Show()
		else
			-- If it would exceed the bar, hide it
			self.QuestOverlayIncomplete:SetWidth(0)
			self.QuestOverlayIncomplete:Hide()
		end
	else
		self.QuestOverlayIncomplete:SetWidth(0)
		self.QuestOverlayIncomplete:Hide()
	end
end

-----------------------------------
-- Color Update Methods
-----------------------------------

-- Update all bar colors from user settings
function LegacyXPBarMixin:UpdateAllColors()
	-- Legacy bar now supports full color customization
	-- Apply user colors to:
	--   - Main bar: User's XP bar or rested bar color
	--   - Rested overlay: User's rested color
	--   - Quest Complete: User's quest complete color
	--   - Quest Incomplete: User's quest incomplete color
	
	-- Update main StatusBar color
	self:UpdateStatusBarColor()
	
	-- Update overlays (will apply colors in ApplyLayout)
	if self.StatusBar and self.StatusBar.ExhaustionLevelFillBar then
		local restedColor = XPBarColors:GetUserColor(Color.Rested)
		self.StatusBar.ExhaustionLevelFillBar:SetVertexColor(restedColor.r, restedColor.g, restedColor.b, restedColor.a)
	end
end

-----------------------------------
-- Mouse Click Handler
-----------------------------------
function LegacyXPBarMixin:OnMouseUp(button)
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
