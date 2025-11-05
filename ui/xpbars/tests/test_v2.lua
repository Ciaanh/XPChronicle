-- XP Bar Enhanced - v2 Test Harness
-- Minimal, safe test harness that registers Addon.Tests and uses the StyleBuilder factory.
-- Slash command handling is centralized in core/Core.lua which will call Addon.Tests.* when dev mode is enabled.

local Addon = XPBarEnhanced
Addon.Tests = Addon.Tests or {}

-- Lightweight logger helpers (fall back to print)
local function logInfo(msg)
	if Addon and Addon.Logger and Addon.Logger.Info then
		Addon.Logger:Info(msg)
	else
		print(msg)
	end
end
local function logWarn(msg)
	if Addon and Addon.Logger and Addon.Logger.Warn then
		Addon.Logger:Warn(msg)
	else
		print(msg)
	end
end
local function logError(msg)
	if Addon and Addon.Logger and Addon.Logger.Error then
		Addon.Logger:Error(msg)
	else
		print(msg)
	end
end

local TestFrame = nil
local TestObserverId = nil -- Observer pattern registration ID
local STYLE_KEY = "flat"
local TEMPLATE_NAME = "FlatBarTemplate_v2"

local function create_frame_from_factory(config)
	config = config or {}
	if XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle then
		return XPBarStyleBuilder:CreateFrameForStyle(STYLE_KEY, config, TEMPLATE_NAME)
	elseif type(XPBarEnhanced_CreateFlatBarFrame) == "function" then
		return XPBarEnhanced_CreateFlatBarFrame(config)
	else
		logError("v2 test harness: no factory available to create frame")
		return nil
	end
end

-- CreateTestBar: create and initialize a single test frame (idempotent)
local function CreateTestBar(config)
	local frame
	if XPBarEnhanced_CreateFlatBarFrame then
		frame = XPBarEnhanced_CreateFlatBarFrame()
	elseif XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle then
		-- Fallback: create directly from style builder
		frame = XPBarStyleBuilder:CreateFrameForStyle("flat", nil, "FlatBarTemplate_v2")
	end

	if not frame then
		return
	end

	-- Store frame reference
	TestFrame = frame
	
	-- Register as global for easy access
	_G.FlatBar_v2 = frame

	-- Register with observer pattern (allows multiple bars to coexist)
	if Addon and Addon.XPBar and Addon.XPBar.RegisterObserver then
		TestObserverId = Addon.XPBar:RegisterObserver(frame, "flat_v2_test")
		logInfo(string.format("V2 test bar registered as observer: %s", TestObserverId))
	else
		logWarn("V2 test bar: XPBar observer pattern not available")
	end

	-- Ensure frame is shown
	frame:Show()

	-- Force initial visuals if context builder exists
	if frame.UpdateVisuals and XPBarContextBuilder and XPBarContextBuilder.BuildXPChangeContext then
		local ctx = XPBarContextBuilder:BuildXPChangeContext()
		frame:UpdateVisuals(ctx)
	end

	return frame
end

-- DestroyTestBar: best-effort cleanup
local function DestroyTestBar()
	if not TestFrame then
		logWarn("No test bar to destroy")
		return
	end

	-- Unregister from observer pattern
	if Addon and Addon.XPBar and Addon.XPBar.UnregisterObserver and TestObserverId then
		Addon.XPBar:UnregisterObserver(TestObserverId)
		logInfo(string.format("V2 test bar unregistered observer: %s", TestObserverId))
		TestObserverId = nil
	end

	if TestFrame.UnregisterAllEvents then
		pcall(TestFrame.UnregisterAllEvents, TestFrame)
	end
	if TestFrame.OnUnload then
		pcall(TestFrame.OnUnload, TestFrame)
	end
	TestFrame:Hide()
	_G.FlatBar_v2 = nil
	TestFrame = nil
	logInfo("v2 test bar destroyed")
end

-- PrintContext: output a sample context built by ContextBuilder (if available)
local function PrintContext()
	if not XPBarContextBuilder then
		logError("XPBarContextBuilder not available")
		return
	end

	-- First, print what's in the database
	if Addon and Addon.db then
		print("|cff00ff00Database Values:|r")
		print((" showCompleteQuestOverlay: %s (type: %s)"):format(
			tostring(Addon.db.showCompleteQuestOverlay), 
			type(Addon.db.showCompleteQuestOverlay)))
		print((" showIncompleteQuestOverlay: %s (type: %s)"):format(
			tostring(Addon.db.showIncompleteQuestOverlay), 
			type(Addon.db.showIncompleteQuestOverlay)))
	end

	local build = XPBarContextBuilder.BuildXPChangeContext or XPBarContextBuilder.BuildContext or XPBarContextBuilder.Build
	if not build then
		logError("ContextBuilder API not found")
		return
	end

	local ok, ctx = pcall(build, "PLAYER_XP_UPDATE")
	if not ok or not ctx then
		logError("Failed to build context")
		return
	end

	print("|cff00ff00v2 Context:|r")
	print((" Level: %d"):format(ctx.level or 0))
	print((" XP: %d / %d (%.1f%%)"):format(ctx.currentXP or 0, ctx.xpMax or ctx.maxXP or 0, (ctx.percentComplete or 0)))
	print((" Rested: %d (%.1f%%)"):format(ctx.restedXP or 0, (ctx.restedPercent or 0)))
	print((" showCompleteQuestOverlay: %s"):format(tostring(ctx.showCompleteQuestOverlay)))
	print((" showIncompleteQuestOverlay: %s"):format(tostring(ctx.showIncompleteQuestOverlay)))
end

-- TriggerFlash: attempt to play xp gain flash animation on the test frame
local function TriggerFlash(amount)
	if not TestFrame then
		logWarn("No test frame; creating one")
		CreateTestBar()
		if not TestFrame then
			logError("Cannot trigger flash without a test frame")
			return
		end
	end

	if TestFrame.FlashXPGain then
		pcall(TestFrame.FlashXPGain, TestFrame, amount or 1000)
		logInfo("Triggered FlashXPGain")
		return
	end
	if TestFrame.PlayXPGainAnimation then
		pcall(TestFrame.PlayXPGainAnimation, TestFrame, amount or 1000)
		logInfo("Triggered PlayXPGainAnimation")
		return
	end

	logWarn("No flash animation API found on test frame")
end

-- Export API for core/Core.lua and other consumers
Addon.Tests.CreateTestBar = CreateTestBar
Addon.Tests.DestroyTestBar = DestroyTestBar
Addon.Tests.PrintContext = PrintContext
Addon.Tests.TriggerFlash = TriggerFlash
