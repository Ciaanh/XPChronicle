local Addon = XPChronicle
Addon.App = Addon.App or {}
Addon.App.Config = Addon.App.Config or {}
Addon.App.Config.SlashCommands = Addon.App.Config.SlashCommands or {}

local SlashCommands = Addon.App.Config.SlashCommands
local Config = Addon.App.Config.Config or Addon.Config
local L = function(key, ...) return Addon.L and Addon.L(key, ...) or key end

local function printUnknown(command)
    print("|cFFFF0000" .. L("MSG_UNKNOWN_COMMAND") .. "|r " .. (command or ""))
    if Config and Config.ShowHelp then
        Config:ShowHelp()
    end
end

local function handleStats()
    local stats = Addon.App.Features and Addon.App.Features.stats
    if stats and stats.Toggle then
        stats:Toggle()
        return
    end

    local statsView = Addon.UI.Views and Addon.UI.Views.Stats
    if statsView and statsView.Toggle then
        statsView:Toggle()
        return
    end

    print("|cFFFF0000" .. L("MSG_STATS_UNAVAILABLE") .. "|r")
end

local function handleOptions()
    if Config and Config.OpenOptions then
        Config:OpenOptions()
        return
    end

    print("|cFFFF0000" .. L("MSG_OPTIONS_UNAVAILABLE") .. "|r")
end

local function handleReset()
    if Config and Config.Reset then
        Config:Reset()
        return
    end

    print("|cFFFF0000" .. L("MSG_RESET_UNAVAILABLE") .. "|r")
end

local function handleResetStats()
    if Config and Config.ResetStats then
        Config:ResetStats()
        return
    end

    print("|cFFFF0000" .. L("MSG_RESET_STATS_UNAVAILABLE") .. "|r")
end

function SlashCommands:Handle(message)
    local command, arg = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        if Config and Config.ShowHelp then
            Config:ShowHelp()
        end
        return
    end

    if command == "stats" then
        handleStats()
        return
    end

    if command == "options" or command == "config" or command == "settings" then
        handleOptions()
        return
    end

    if command == "reset" then
        handleReset()
        return
    end

    if command == "resetstats" or command == "clearstats" then
        handleResetStats()
        return
    end

    if command == "resetcolors" then
        if Addon.defaults and Addon.defaults.colors then
            Addon.db = Addon.db or {}
            Addon.db.colors = {}
            
            -- Copy default colors
            for colorKey, colorValue in pairs(Addon.defaults.colors) do
                Addon.db.colors[colorKey] = {
                    r = colorValue.r,
                    g = colorValue.g,
                    b = colorValue.b,
                    a = colorValue.a
                }
            end
            
            print("|cFF00FF00XP Chronicle:|r Colors reset to defaults. Please /reload")
        else
            print("|cFFFF0000XP Chronicle:|r Could not find default colors")
        end
        return
    end

    -- Bar style command
    if command == "style" or command == "barstyle" or command == "mode" then
        local style = string.lower(arg or "")
        if style == "" then
            -- Show current style
            local currentStyle = Addon.db.barStyle or "legacy"
            print("|cFF00FF00XP Chronicle:|r Current bar style: " .. currentStyle)
            print("Usage: /xpc style <none|legacy|flat>")
            return
        end
        
        if style == "none" or style == "legacy" or style == "flat" then
            local controller = Addon.App.Features.xpbar
            if controller and controller.SetBarStyle then
                controller:SetBarStyle(style)
                print("|cFF00FF00XP Chronicle:|r Bar style set to: " .. style)
            else
                print("|cFFFF0000XP Chronicle:|r XP Bar controller not available")
            end
        else
            print("|cFFFF0000XP Chronicle:|r Invalid style. Use: none, legacy, or flat")
        end
        return
    end

    -- Test commands
    if command == "test" then
        local testCommand = string.lower(arg or "")
        
        if testCommand == "celebration" or testCommand == "levelup" then
            -- Test level-up celebration animation
            -- Try to get the active bar (Legacy or Flat)
            local bar = nil
            local barType = Addon.db and Addon.db.barStyle or "legacy"
            
            if barType == "flat" and _G.XPC_FlatXPBar then
                bar = _G.XPC_FlatXPBar.Bar
            elseif barType == "legacy" and _G.XPC_LegacyXPBar then
                bar = _G.XPC_LegacyXPBar.Bar
            end
            
            if bar and bar.PlayLevelUpCelebration then
                local currentLevel = UnitLevel("player")
                print("|cFF00FF00XP Chronicle:|r Testing level-up celebration for level " .. currentLevel)
                bar:PlayLevelUpCelebration(currentLevel)
            else
                print("|cFFFF0000XP Chronicle:|r XP Bar not available (current style: " .. barType .. ")")
                print("Try: /xpc style legacy or /xpc style flat")
            end
            return
        end
        
        if testCommand == "flash" then
            -- Test XP gain flash
            local bar = nil
            local barType = Addon.db and Addon.db.barStyle or "legacy"
            
            if barType == "flat" and _G.XPC_FlatXPBar then
                bar = _G.XPC_FlatXPBar.Bar
            elseif barType == "legacy" and _G.XPC_LegacyXPBar then
                bar = _G.XPC_LegacyXPBar.Bar
            end
            
            if bar and bar.TriggerXPGainFlash then
                print("|cFF00FF00XP Chronicle:|r Testing XP gain flash")
                bar:TriggerXPGainFlash(false) -- false = not rested
            else
                print("|cFFFF0000XP Chronicle:|r XP Bar not available (current style: " .. barType .. ")")
                print("Try: /xpc style legacy or /xpc style flat")
            end
            return
        end
        
        -- Show test help
        print("|cFF00FF00XP Chronicle:|r Test commands:")
        print("  /xpc test celebration - Test level-up celebration animation")
        print("  /xpc test flash - Test XP gain flash effect")
        return
    end

    printUnknown(command)
end

function SlashCommands:Register()
    if self._registered then
        return
    end

    if not _G.SLASH_XPCHRONICLE1 then
        _G.SLASH_XPCHRONICLE1 = "/xpc"
    end
    if not _G.SLASH_XPCHRONICLE2 then
        _G.SLASH_XPCHRONICLE2 = "/xpchronicle"
    end

    rawset(SlashCmdList, "XPCHRONICLE", function(msg)
        self:Handle(msg)
    end)

    self._registered = true
end

SlashCommands:Register()

return SlashCommands
