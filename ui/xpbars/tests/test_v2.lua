-- XP Bar Enhanced - v2 Test Harness
-- Development testing environment for v2 architecture

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

local AddonName = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon("XPBarEnhanced")

-------------------------------------------------------------------
-- TEST HARNESS GATE
-------------------------------------------------------------------

-- Only load test harness if development flag is enabled
if not XPChronicleConfig or not XPChronicleConfig.enableDevV2 then
	return
end

Addon.Logger:Info("Loading v2 test harness (enableDevV2 = true)")

-------------------------------------------------------------------
-- TEST FRAME CREATION
-------------------------------------------------------------------

local TestFrame = nil

--- Create test bar instance
local function CreateTestBar()
	if TestFrame then
		Addon.Logger:Warn("Test bar already exists. Use /xptest reset to recreate.")
		return TestFrame
	end
	
	-- Create frame from template
	TestFrame = CreateFrame("Frame", "XPBarEnhanced_TestBar_v2", UIParent, "FlatBarTemplate_v2")
	
	-- Apply FlatBar style
	XPBarEnhanced_ApplyFlatBarStyle(TestFrame, {
		position = {
			mode = "DRAGGABLE",
			positionKey = "TestBar_v2",
		},
		animation = {
			enabled = true,
			valueSmoothing = true,
			xpGainFlash = true,
			levelUpFlash = true,
		},
		interaction = {
			enabled = true,
		},
		tooltip = {
			enabled = true,
			provider = nil, -- Use default
		},
		style = {
			width = 565,
			height = 11,
			showQuestOverlays = true,
		},
	})
	
	-- Enable mouse for interaction
	TestFrame:EnableMouse(true)
	TestFrame:SetMouseClickEnabled(true)
	
	-- Show frame
	TestFrame:Show()
	
	Addon.Logger:Info("Test bar created and shown")
	return TestFrame
end

--- Destroy test bar
local function DestroyTestBar()
	if not TestFrame then
		Addon.Logger:Warn("No test bar to destroy")
		return
	end
	
	-- Hide and cleanup
	TestFrame:Hide()
	TestFrame:UnregisterAllEvents()
	TestFrame = nil
	
	Addon.Logger:Info("Test bar destroyed")
end

--- Reset test bar
local function ResetTestBar()
	DestroyTestBar()
	C_Timer.After(0.5, function()
		CreateTestBar()
	end)
end

-------------------------------------------------------------------
-- TEST COMMANDS
-------------------------------------------------------------------

--- Slash command handler
SLASH_XPTEST1 = "/xptest"
SlashCmdList["XPTEST"] = function(msg)
	local args = {strsplit(" ", msg)}
	local cmd = args[1] and args[1]:lower() or "help"
	
	if cmd == "help" then
		print("|cff00ff00XP Bar Enhanced v2 Test Commands:|r")
		print("  /xptest create - Create test bar")
		print("  /xptest destroy - Destroy test bar")
		print("  /xptest reset - Reset test bar")
		print("  /xptest show - Show test bar")
		print("  /xptest hide - Hide test bar")
		print("  /xptest refresh - Refresh test bar")
		print("  /xptest context - Print current context")
		print("  /xptest session - Print session stats")
		print("  /xptest flash - Test flash animation")
		print("  /xptest levelup - Simulate level up")
		print("  /xptest drag - Toggle draggable mode")
		print("  /xptest help - Show this help")
		
	elseif cmd == "create" then
		CreateTestBar()
		print("|cff00ff00Test bar created|r")
		
	elseif cmd == "destroy" then
		DestroyTestBar()
		print("|cff00ff00Test bar destroyed|r")
		
	elseif cmd == "reset" then
		ResetTestBar()
		print("|cff00ff00Test bar reset|r")
		
	elseif cmd == "show" then
		if TestFrame then
			TestFrame:Show()
			print("|cff00ff00Test bar shown|r")
		else
			print("|cffff0000No test bar to show. Use /xptest create first.|r")
		end
		
	elseif cmd == "hide" then
		if TestFrame then
			TestFrame:Hide()
			print("|cff00ff00Test bar hidden|r")
		else
			print("|cffff0000No test bar to hide|r")
		end
		
	elseif cmd == "refresh" then
		if TestFrame and TestFrame.Refresh then
			TestFrame:Refresh()
			print("|cff00ff00Test bar refreshed|r")
		else
			print("|cffff0000No test bar to refresh|r")
		end
		
	elseif cmd == "context" then
		local context = XPBarContextBuilder:BuildXPChangeContext()
		print("|cff00ff00Current Context:|r")
		print(string.format("  Level: %d", context.level))
		print(string.format("  XP: %d / %d (%.1f%%)", context.currentXP, context.maxXP, context.percentComplete))
		print(string.format("  Remaining: %d", context.xpRemaining))
		print(string.format("  Rested: %d (%.1f%%)", context.restedXP, context.restedPercent))
		print(string.format("  Quest XP: %d", context.questXP))
		if context.sessionStats then
			print(string.format("  Session XP: %d", context.sessionStats.sessionXP))
			print(string.format("  XP/hour: %d", context.sessionStats.xpPerHour))
			print(string.format("  Time to level: %s", context.sessionStats.timeToLevel))
		end
		
	elseif cmd == "session" then
		local sessionStats = XPBarContextBuilder:BuildSessionStats()
		print("|cff00ff00Session Stats:|r")
		print(string.format("  Session XP: %d", sessionStats.sessionXP))
		print(string.format("  XP/hour: %d", sessionStats.xpPerHour))
		print(string.format("  Time to level: %s", sessionStats.timeToLevel))
		print(string.format("  Session active: %s", sessionStats.isActive and "Yes" or "No"))
		
	elseif cmd == "flash" then
		if TestFrame and TestFrame.FlashXPGain then
			TestFrame:FlashXPGain(1000)
			print("|cff00ff00XP gain flash triggered|r")
		else
			print("|cffff0000No test bar or flash method not available|r")
		end
		
	elseif cmd == "levelup" then
		if TestFrame and TestFrame.FlashLevelUp then
			TestFrame:FlashLevelUp()
			print("|cff00ff00Level up flash triggered|r")
		else
			print("|cffff0000No test bar or flash method not available|r")
		end
		
	elseif cmd == "drag" then
		if not TestFrame then
			print("|cffff0000No test bar to toggle dragging|r")
			return
		end
		
		local config = TestFrame.__xpbar_config
		if config.position.mode == "STATIC" then
			config.position.mode = "DRAGGABLE"
			if TestFrame.EnableDragging then
				TestFrame:EnableDragging()
			end
			print("|cff00ff00Draggable mode enabled|r")
		else
			config.position.mode = "STATIC"
			if TestFrame.SetMovable then
				TestFrame:SetMovable(false)
				TestFrame:EnableMouse(true)
				TestFrame:SetMouseClickEnabled(true)
			end
			print("|cff00ff00Static mode enabled|r")
		end
		
		if TestFrame.ResetPosition then
			TestFrame:ResetPosition()
		end
		
	else
		print("|cffff0000Unknown command: " .. cmd .. "|r")
		print("Use /xptest help for available commands")
	end
end

-------------------------------------------------------------------
-- AUTO-INITIALIZATION
-------------------------------------------------------------------

-- Automatically create test bar on login
local function InitTestHarness()
	Addon.Logger:Info("Initializing v2 test harness")
	
	-- Wait for all systems to load
	C_Timer.After(2, function()
		CreateTestBar()
		print("|cff00ff00XP Bar Enhanced v2 test harness loaded|r")
		print("Use |cffff00ff/xptest help|r for test commands")
	end)
end

-- Register initialization
if Addon.IsInitialized then
	InitTestHarness()
else
	Addon:RegisterCallback("OnInitialized", InitTestHarness)
end
