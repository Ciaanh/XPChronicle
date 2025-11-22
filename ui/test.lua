-- XP Bar Enhanced -  Test Harness
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
local TEMPLATE_NAME = "FlatBarTemplate"

local function create_frame_from_factory(config)
	config = config or {}
	if XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle then
		return XPBarStyleBuilder:CreateFrameForStyle(STYLE_KEY, config, TEMPLATE_NAME)
	elseif type(XPBarEnhanced_CreateFlatBarFrame) == "function" then
		return XPBarEnhanced_CreateFlatBarFrame(config)
	else
		logError(" test harness: no factory available to create frame")
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
		frame = XPBarStyleBuilder:CreateFrameForStyle("flat", config, "FlatBarTemplate")
	end

	if not frame then
		return
	end

	-- Store frame reference
	TestFrame = frame
	
	-- Register as global for easy access
	_G.FlatBar = frame

	-- Register with observer pattern (allows multiple bars to coexist)
	if Addon and Addon.XPBar and Addon.XPBar.RegisterObserver then
		TestObserverId = Addon.XPBar:RegisterObserver(frame, "flat_test")
		logInfo(string.format(" test bar registered as observer: %s", TestObserverId))
	else
		logWarn(" test bar: XPBar observer pattern not available")
	end

	-- Ensure frame is shown
	frame:Show()

	-- Force initial visuals if context builder exists
	if frame.UpdateVisuals and XPBarContextBuilder and XPBarContextBuilder.BuildContext then
		local ctx = XPBarContextBuilder:BuildContext()
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
		logInfo(string.format(" test bar unregistered observer: %s", TestObserverId))
		TestObserverId = nil
	end

	if TestFrame.UnregisterAllEvents then
		pcall(TestFrame.UnregisterAllEvents, TestFrame)
	end
	if TestFrame.OnUnload then
		pcall(TestFrame.OnUnload, TestFrame)
	end
	TestFrame:Hide()
	_G.FlatBar = nil
	TestFrame = nil
	logInfo(" test bar destroyed")
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

	local build = XPBarContextBuilder.BuildContext or XPBarContextBuilder.BuildContext or XPBarContextBuilder.Build
	if not build then
		logError("ContextBuilder API not found")
		return
	end

	local ok, ctx = pcall(build, "PLAYER_XP_UPDATE")
	if not ok or not ctx then
		logError("Failed to build context")
		return
	end

	print("|cff00ff00 Context:|r")
	print((" Level: %d"):format(ctx.level or 0))
	print((" XP: %d / %d (%.1f%%)"):format(ctx.currentXP or 0, ctx.xpMax or ctx.maxXP or 0, (ctx.percentComplete or 0)))
	print((" Rested: %d (%.1f%%)"):format(ctx.restedXP or 0, (ctx.restedPercent or 0)))
	print((" showCompleteQuestOverlay: %s"):format(tostring(ctx.showCompleteQuestOverlay)))
	print((" showIncompleteQuestOverlay: %s"):format(tostring(ctx.showIncompleteQuestOverlay)))
end

-- TriggerFlash: attempt to play xp gain flash animation on the test frame
local function TriggerFlash(amount)
	-- Try to find any available test frame
	local targetFrame = nil
	
	-- Priority: Vertical > Classic > Flat
	if VerticalTestFrame and VerticalTestFrame:IsShown() then
		targetFrame = VerticalTestFrame
	elseif ClassicTestFrame and ClassicTestFrame:IsShown() then
		targetFrame = ClassicTestFrame
	elseif TestFrame and TestFrame:IsShown() then
		targetFrame = TestFrame
	end
	
	-- If no frame is shown, try any that exist
	if not targetFrame then
		targetFrame = VerticalTestFrame or ClassicTestFrame or TestFrame
	end
	
	if not targetFrame then
		logWarn("No test frame exists; creating flat bar")
		CreateTestBar()
		targetFrame = TestFrame
		if not targetFrame then
			logError("Cannot trigger flash without a test frame")
			return
		end
	end
	
	-- Log which frame we're triggering on
	local frameName = "unknown"
	if targetFrame == VerticalTestFrame then
		frameName = "Vertical Bar "
	elseif targetFrame == ClassicTestFrame then
		frameName = "Classic Bar "
	elseif targetFrame == TestFrame then
		frameName = "Flat Bar "
	end
	logInfo(string.format("Triggering flash on: %s", frameName))

	-- Try  animation methods (used by all  bars)
	if targetFrame.TriggerXPChanged and XPBarContextBuilder then
		-- Build a fake XP gain context
		local baseCtx = XPBarContextBuilder.BuildContext("TEST_FLASH")
		if baseCtx then
			-- Context is immutable, so create a new table with modified values
			local testXPGain = amount or 1000
			local xpAfter = math.min((baseCtx.xpBefore or 0) + testXPGain, baseCtx.xpMax or 1)
			
			-- Create mutable test context by copying immutable base
			local testCtx = {
				-- Copy base context fields
				level = baseCtx.level,
				currentXP = xpAfter,
				xpMax = baseCtx.xpMax,
				xpBefore = baseCtx.xpBefore,
				xpAfter = xpAfter,
				xpGained = testXPGain,
				restedXP = baseCtx.restedXP,
				hasRestedXP = baseCtx.hasRestedXP,
				completeQuestXP = baseCtx.completeQuestXP,
				incompleteQuestXP = baseCtx.incompleteQuestXP,
				percentComplete = (xpAfter / (baseCtx.xpMax or 1)) * 100,
				showCompleteQuestOverlay = baseCtx.showCompleteQuestOverlay,
				showIncompleteQuestOverlay = baseCtx.showIncompleteQuestOverlay,
				showRestedOverlay = baseCtx.showRestedOverlay,
				changeSource = "TEST_FLASH"
			}
			
			pcall(targetFrame.TriggerXPChanged, targetFrame, testCtx)
			logInfo("Triggered TriggerXPChanged with fake XP gain")
			return
		end
	end

	-- Fallback to V1 methods (for compatibility)
	if targetFrame.FlashXPGain then
		pcall(targetFrame.FlashXPGain, targetFrame, amount or 1000)
		logInfo("Triggered FlashXPGain")
		return
	end
	if targetFrame.PlayXPGainAnimation then
		pcall(targetFrame.PlayXPGainAnimation, targetFrame, amount or 1000)
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
-- Trigger a flash specifically for circular bar  and report a summary of segment alphas
local function TriggerCircularFlash(amount)
	if not CircularBar then
		if XPBarEnhanced_CreateCircularBarFrame then
			CircularBar = XPBarEnhanced_CreateCircularBarFrame()
		else
			CircularBar = XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle("circular", nil, "CircularBarTemplate")
		end
	end
	if not CircularBar then
		logError("CircularBar not available")
		return
	end

	-- Create a fake XP gain context and trigger it on the circular bar
	if CircularBar.TriggerXPChanged and XPBarContextBuilder and XPBarContextBuilder.BuildContext then
		local baseCtx = XPBarContextBuilder.BuildContext("TEST_FLASH")
		if baseCtx then
			local testXPGain = amount or 1000
			local xpAfter = math.min((baseCtx.xpBefore or 0) + testXPGain, baseCtx.xpMax or 1)
			local testCtx = {
				level = baseCtx.level,
				currentXP = xpAfter,
				xpMax = baseCtx.xpMax,
				xpBefore = baseCtx.xpBefore,
				xpAfter = xpAfter,
				xpGained = testXPGain,
				restedXP = baseCtx.restedXP,
				hasRestedXP = baseCtx.hasRestedXP,
				completeQuestXP = baseCtx.completeQuestXP,
				incompleteQuestXP = baseCtx.incompleteQuestXP,
				percentComplete = (xpAfter / (baseCtx.xpMax or 1)) * 100,
				showCompleteQuestOverlay = baseCtx.showCompleteQuestOverlay,
				showIncompleteQuestOverlay = baseCtx.showIncompleteQuestOverlay,
				showRestedOverlay = baseCtx.showRestedOverlay,
				changeSource = "TEST_FLASH_CIRCULAR"
			}
			pcall(CircularBar.TriggerXPChanged, CircularBar, testCtx)
			logInfo("Triggered circular Test Flash")
			-- Print a summary of first 10 segment alphas for manual verification
			local alphasSummary = {}
			for i = 1, math.min(10, #CircularBar.segments) do
				local seg = CircularBar.segments[i]
				local r,g,b,a = seg:GetVertexColor()
				table.insert(alphasSummary, string.format("%d: %.2f", i, a))
			end
			logInfo("Circular segment alpha summary (first 10): " .. table.concat(alphasSummary, ", "))
			return
		end
	end
	logWarn("Could not trigger circular flash")
end
Addon.Tests.TriggerCircularFlash = TriggerCircularFlash
-- Toggle quest XP setting then force update and log circular bar state
local function ToggleQuestXPForCircular(toggle)
	if not Addon or not Addon.db then
		logError("Addon db not available")
		return
	end
	Addon.db.showQuestXP = toggle
	if Addon.XPBar and Addon.XPBar.Update then
		Addon.XPBar:Update()
	end
	-- Print post-update context and circular cached values
	if CircularBar and CircularBar.FullUpdate then
		local ctx = XPBarContextBuilder and XPBarContextBuilder.BuildContext and XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
		if ctx then
			pcall(CircularBar.FullUpdate, CircularBar, ctx)
		end
	end
	print("Toggled showQuestXP to:", tostring(toggle))
end
Addon.Tests.ToggleQuestXPForCircular = ToggleQuestXPForCircular

local function SimulateLevelUpOnCircular(newLevel)
	if not XPBarContextBuilder then
		logError("ContextBuilder not available")
		return
	end
	local ctx = XPBarContextBuilder.BuildContext("PLAYER_LEVEL_UP", newLevel)
	if not ctx then
		logError("Could not build level up context")
		return
	end
	if CircularBar and CircularBar.TriggerBarRefresh then
		pcall(CircularBar.TriggerBarRefresh, CircularBar, ctx)
	end
	print("Simulated level up for CircularBar to level:", tostring(newLevel))
end
Addon.Tests.SimulateLevelUpOnCircular = SimulateLevelUpOnCircular

-------------------------------------------------------------------
-- CLASSIC BAR  TEST FUNCTIONS
-------------------------------------------------------------------

local ClassicTestFrame = nil
local ClassicTestObserverId = nil

-- CreateClassicTestBar: create and initialize Classic Bar  test frame
local function CreateClassicTestBar(config)
	local frame
	if XPBarEnhanced_CreateClassicBarFrame then
		frame = XPBarEnhanced_CreateClassicBarFrame()
	elseif XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle then
		-- Fallback: create directly from style builder
		frame = XPBarStyleBuilder:CreateFrameForStyle("classic", config, "ClassicBarTemplate")
	end

	if not frame then
		logError("Failed to create Classic Bar  test frame")
		return
	end

	-- Store frame reference
	ClassicTestFrame = frame
	
	-- Register as global for easy access
	_G.ClassicBar = frame

	-- Register with observer pattern (allows multiple bars to coexist)
	if Addon and Addon.XPBar and Addon.XPBar.RegisterObserver then
		ClassicTestObserverId = Addon.XPBar:RegisterObserver(frame, "classic_test")
		logInfo(string.format("Classic  test bar registered as observer: %s", ClassicTestObserverId))
	else
		logWarn("Classic  test bar: XPBar observer pattern not available")
	end

	-- Ensure frame is shown
	frame:Show()

	-- Force initial visuals if context builder exists
	if frame.UpdateVisuals and XPBarContextBuilder and XPBarContextBuilder.BuildContext then
		local ctx = XPBarContextBuilder:BuildContext()
		frame:UpdateVisuals(ctx)
	end

	logInfo("Classic Bar  test frame created successfully!")
	return frame
end

-- DestroyClassicTestBar: cleanup Classic Bar  test frame
local function DestroyClassicTestBar()
	if not ClassicTestFrame then
		logWarn("No Classic Bar  test frame to destroy")
		return
	end

	-- Unregister from observer pattern
	if Addon and Addon.XPBar and Addon.XPBar.UnregisterObserver and ClassicTestObserverId then
		Addon.XPBar:UnregisterObserver(ClassicTestObserverId)
		logInfo(string.format("Classic  test bar unregistered observer: %s", ClassicTestObserverId))
		ClassicTestObserverId = nil
	end

	if ClassicTestFrame.UnregisterAllEvents then
		pcall(ClassicTestFrame.UnregisterAllEvents, ClassicTestFrame)
	end
	if ClassicTestFrame.OnUnload then
		pcall(ClassicTestFrame.OnUnload, ClassicTestFrame)
	end
	ClassicTestFrame:Hide()
	_G.ClassicBar = nil
	ClassicTestFrame = nil
	logInfo("Classic Bar  test frame destroyed")
end

-- Export Classic Bar  test functions
Addon.Tests.CreateClassicTestBar = CreateClassicTestBar
Addon.Tests.DestroyClassicTestBar = DestroyClassicTestBar

-------------------------------------------------------------------
-- VERTICAL BAR  TEST FUNCTIONS
-------------------------------------------------------------------

local VerticalTestFrame = nil
local VerticalTestObserverId = nil

-- CreateVerticalTestBar: create and initialize Vertical Bar  test frame
local function CreateVerticalTestBar(config)
	local frame
	if XPBarEnhanced_CreateVerticalBarFrame then
		frame = XPBarEnhanced_CreateVerticalBarFrame()
	elseif XPBarStyleBuilder and XPBarStyleBuilder.CreateFrameForStyle then
		-- Fallback: create directly from style builder
		frame = XPBarStyleBuilder:CreateFrameForStyle("vertical", config, "VerticalBarTemplate")
	end

	if not frame then
		logError("Failed to create Vertical Bar  test frame")
		return
	end

	-- Store frame reference
	VerticalTestFrame = frame
	
	-- Register as global for easy access
	_G.VerticalBar = frame

	-- Register with observer pattern (allows multiple bars to coexist)
	if Addon and Addon.XPBar and Addon.XPBar.RegisterObserver then
		VerticalTestObserverId = Addon.XPBar:RegisterObserver(frame, "vertical_test")
		logInfo(string.format("Vertical  test bar registered as observer: %s", VerticalTestObserverId))
	else
		logWarn("Vertical  test bar: XPBar observer pattern not available")
	end

	-- Ensure frame is shown
	frame:Show()

	-- Force initial visuals if context builder exists
	if frame.UpdateVisuals and XPBarContextBuilder and XPBarContextBuilder.BuildContext then
		local ctx = XPBarContextBuilder:BuildContext()
		frame:UpdateVisuals(ctx)
	end

	logInfo("Vertical Bar  test frame created successfully!")
	logInfo("Test gravity animation with: /xptest flash")
	return frame
end

-- DestroyVerticalTestBar: cleanup Vertical Bar  test frame
local function DestroyVerticalTestBar()
	if not VerticalTestFrame then
		logWarn("No Vertical Bar  test frame to destroy")
		return
	end

	-- Unregister from observer pattern
	if Addon and Addon.XPBar and Addon.XPBar.UnregisterObserver and VerticalTestObserverId then
		Addon.XPBar:UnregisterObserver(VerticalTestObserverId)
		logInfo(string.format("Vertical  test bar unregistered observer: %s", VerticalTestObserverId))
		VerticalTestObserverId = nil
	end

	if VerticalTestFrame.UnregisterAllEvents then
		pcall(VerticalTestFrame.UnregisterAllEvents, VerticalTestFrame)
	end
	if VerticalTestFrame.OnUnload then
		pcall(VerticalTestFrame.OnUnload, VerticalTestFrame)
	end
	VerticalTestFrame:Hide()
	_G.VerticalBar = nil
	VerticalTestFrame = nil
	logInfo("Vertical Bar  test frame destroyed")
end

-- Export Vertical Bar  test functions
Addon.Tests.CreateVerticalTestBar = CreateVerticalTestBar
Addon.Tests.DestroyVerticalTestBar = DestroyVerticalTestBar
