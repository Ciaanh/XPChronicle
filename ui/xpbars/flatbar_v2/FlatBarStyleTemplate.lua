-- XP Bar Enhanced - FlatBar Style Template v2
-- Visual methods and layout for flat/linear XP bar

-------------------------------------------------------------------
-- FLAT BAR STYLE TEMPLATE
-------------------------------------------------------------------

local FlatBarStyleTemplate = {}

-- Bar dimensions
local BAR_WIDTH = 565
local BAR_HEIGHT = 10

-------------------------------------------------------------------
-- VISUAL BUILDING (Required by Base)
-------------------------------------------------------------------

--- Build all visual elements
function FlatBarStyleTemplate:BuildVisuals()
	-- Note: StatusBar is created by XML template
	-- This method creates additional textures and overlays
	
	if not self.StatusBar then
		error("FlatBarStyleTemplate:BuildVisuals - StatusBar not found in XML")
		return
	end
	
	-- Rested overlay (created by BuildRestedOverlay)
	if not self.StatusBar.RestedLevel then
		self:BuildRestedOverlay()
	end
	
	-- Quest overlays (created by BuildQuestOverlays)
	if not self.StatusBar.QuestOverlayComplete then
		self:BuildQuestOverlays()
	end
	
	-- Exhaustion tick (created by BuildExhaustionTick)
	if not self.StatusBar.ExhaustionTick then
		self:BuildExhaustionTick()
	end
	
	-- Flash overlay (created by BuildFlashOverlay)
	if not self.GainFlash then
		self:BuildFlashOverlay()
	end
	
	-- Text overlays already created by XML
end

--- Build rested overlay texture
function FlatBarStyleTemplate:BuildRestedOverlay()
	if not self.StatusBar then return end
	
	local overlay = self.StatusBar:CreateTexture(nil, "ARTWORK", nil, -1)
	overlay:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	overlay:SetSize(0, BAR_HEIGHT)
	overlay:SetPoint("BOTTOMLEFT", 0, 0)
	
	-- Color will be set by UpdateRestedOverlay
	self.StatusBar.RestedLevel = overlay
	self.RestedLevel = overlay -- Also store on main frame for easy access
end

--- Build quest overlay textures
function FlatBarStyleTemplate:BuildQuestOverlays()
	if not self.StatusBar then return end
	
	-- Complete quest overlay
	local completeOverlay = self.StatusBar:CreateTexture(nil, "OVERLAY", nil, 1)
	completeOverlay:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	completeOverlay:SetSize(0, BAR_HEIGHT)
	completeOverlay:SetPoint("BOTTOMLEFT", 0, 0)
	completeOverlay:Hide()
	
	self.StatusBar.QuestOverlayComplete = completeOverlay
	self.QuestOverlayComplete = completeOverlay
	
	-- Incomplete quest overlay
	local incompleteOverlay = self.StatusBar:CreateTexture(nil, "OVERLAY", nil, 2)
	incompleteOverlay:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	incompleteOverlay:SetSize(0, BAR_HEIGHT)
	incompleteOverlay:SetPoint("BOTTOMLEFT", 0, 0)
	incompleteOverlay:Hide()
	
	self.StatusBar.QuestOverlayIncomplete = incompleteOverlay
	self.QuestOverlayIncomplete = incompleteOverlay
end

--- Build exhaustion tick marker
function FlatBarStyleTemplate:BuildExhaustionTick()
	if not self.StatusBar or not self.StatusBar.RestedLevel then return end
	
	local tick = CreateFrame("Button", nil, self.StatusBar)
	tick:SetSize(10, 14)
	tick:SetPoint("CENTER", self.StatusBar.RestedLevel, "RIGHT", 0, 0)
	tick:Hide()
	
	-- Set texture (use atlas if available)
	local texture = tick:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ExperienceBar-Frame-Pip") then
		texture:SetAtlas("UI-HUD-ExperienceBar-Frame-Pip")
	else
		-- Fallback to simple marker
		texture:SetTexture("Interface\\Buttons\\UI-MicroButton-Spellbook-Up")
	end
	tick.texture = texture
	
	-- Tooltip (uses TooltipMixin if available)
	tick:SetScript("OnEnter", function(frame)
		if self.OnEnter then
			self:OnEnter()
		end
	end)
	tick:SetScript("OnLeave", function(frame)
		GameTooltip:Hide()
	end)
	
	self.StatusBar.ExhaustionTick = tick
	self.ExhaustionTick = tick
end

--- Build flash overlay
function FlatBarStyleTemplate:BuildFlashOverlay()
	local flash = self:CreateTexture(nil, "OVERLAY", nil, 3)
	flash:SetAllPoints(self)
	flash:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	flash:SetVertexColor(1, 1, 1, 0) -- White, fully transparent initially
	flash:Hide()
	
	self.GainFlash = flash
end

-------------------------------------------------------------------
-- VISUAL UPDATES (Required by Base)
-------------------------------------------------------------------

--- Update all visual elements based on current state
function FlatBarStyleTemplate:UpdateVisuals()
	-- Update StatusBar color based on rested state
	local currentXP = UnitXP("player") or 0
	local restedXP = GetXPExhaustion() or 0
	local isRested = restedXP > 0
	
	local colorKey = isRested and Color.XpBarRested or Color.XpBar
	local color = XPBarColors:GetUserColor(colorKey)
	
	if self.StatusBar then
		self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
	end
	
	-- Update text if text frames exist
	if self.XPText then
		local maxXP = UnitXPMax("player") or 1
		local percent = 0
		if maxXP > 0 then
			percent = (currentXP / maxXP) * 100
		end
		self.XPText:SetFormattedText("%s / %s", BreakUpLargeNumbers(currentXP), BreakUpLargeNumbers(maxXP))
	end
	
	if self.PercentText then
		local maxXP = UnitXPMax("player") or 1
		local percent = 0
		if maxXP > 0 then
			percent = (currentXP / maxXP) * 100
		end
		self.PercentText:SetFormattedText("%.1f%%", percent)
	end
	
	if self.LevelText then
		local level = UnitLevel("player") or 1
		self.LevelText:SetFormattedText("%d", level)
	end
end

-------------------------------------------------------------------
-- STYLE CONFIGURATION (Optional)
-------------------------------------------------------------------

--- Apply style-specific configuration
---@param styleConfig table Style configuration from config.style
function FlatBarStyleTemplate:ApplyStyle(styleConfig)
	if not styleConfig then return end
	
	-- Apply width/height if specified
	if styleConfig.width and styleConfig.height then
		self:SetSize(styleConfig.width, styleConfig.height)
		if self.StatusBar then
			self.StatusBar:SetSize(styleConfig.width, styleConfig.height - 1)
		end
	end
	
	-- Apply colors (will be overridden by user colors from options)
	-- This is mainly for initial setup
end

return FlatBarStyleTemplate
