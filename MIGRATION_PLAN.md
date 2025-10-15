# XPBarEnhanced Migration Plan

**Version:** 1.0.1 → 2.0.0  
**Target Name:** XPBarEnhanced  
**Migration Date:** October 2025  
**Complexity:** Medium (Full restructure + rename)

---

## Executive Summary

This migration transforms the current **XPChronicle** addon into **XPBarEnhanced** with:
- Complete project rename (avoid naming conflict with existing "XP Chronicle" addon)
- Simplified architecture (reduce from 30+ files to ~12 files)
- ~50% reduction in code complexity while maintaining all current features
- Improved maintainability and performance

**Estimated Effort:** 10-14 hours of development + 3-4 hours testing

---

## Table of Contents

1. [Phase 1: Project Rename](#phase-1-project-rename)
2. [Phase 2: Architecture Simplification](#phase-2-architecture-simplification)
3. [Phase 3: Testing & Validation](#phase-3-testing--validation)
4. [Appendices](#appendices)

---

## Phase 1: Project Rename

**Duration:** 2 hours  
**Risk Level:** Low  
**Dependencies:** None

### 1.1 File & Directory Renaming

#### Files to Rename
```
XPChronicle.toc           → XPBarEnhanced.toc
Frames.xml                → (keep - referenced in TOC)
README.md                 → (update content only)
ARCHITECTURE.md           → (update content only)
LICENSE                   → (keep as-is)
```

#### Global Namespace Changes
Replace all occurrences of `XPChronicle` → `XPBarEnhanced`
Replace all occurrences of `/xpc` → `/xpbe`

**Files requiring namespace changes:**
- All `.lua` files in `app/`
- All `.lua` files in `ui/`
- All `.lua` files in `locales/`
- All `.xml` files

**Saved Variable Rename:**
```lua
-- Old
XPChronicleDB = XPChronicleDB or {}

-- New
XPBarEnhancedDB = XPBarEnhancedDB or {}
```

#### TOC File Updates

**Current (XPChronicle.toc):**
```toc
## Interface: 110205
## Title: XP Chronicle
## Notes: Enhanced experience bar with quest XP tracking and leveling statistics
## Author: Ciaanh
## Version: 1.0.1
## SavedVariables: XPChronicleDB
## Category: Quests & Leveling
## IconTexture: 4675649
```

**New (XPBarEnhanced.toc):**

```toc
## Interface: 110205
## Title: XP Bar Enhanced
## Notes: Enhanced XP bar with quest XP tracking and comprehensive statistics
## Author: Ciaanh
## Version: 2.0.0
## SavedVariables: XPBarEnhancedDB
## Category: Quests & Leveling
## IconTexture: 4675649
## X-Website: https://github.com/Ciaanh/XPBarEnhanced
## X-Curse-Project-ID: [TBD]
```

### 1.2 SavedVariables Migration

Create migration handler to preserve user settings:

**Location:** `core/Migration.lua` (new file)

```lua
local Addon = XPBarEnhanced
Addon.Migration = {}

function Addon.Migration:MigrateFromXPChronicle()
    -- Check if old data exists
    if XPChronicleDB and not XPBarEnhancedDB then
        XPBarEnhancedDB = XPChronicleDB
        print("|cff33ff99XPBarEnhanced|r: Migrated settings from XP Chronicle")
        
        -- Clean up old variable after confirmation
        C_Timer.After(5, function()
            XPChronicleDB = nil
        end)
        
        return true
    end
    return false
end
```

### 1.3 Documentation Updates

**README.md:**

- Update title: "XP Bar Enhanced"
- Add note about name change from XPChronicle
- Update all command examples: `/xpc` → `/xpbe`
- Add "Migration from XP Chronicle" section

**ARCHITECTURE.md:**

- Update all references to new addon name
- Simplify based on new structure (see Phase 2)

**CHANGELOG.md:**

```markdown
## [2.0.0] - 2025-10-XX

### Breaking Changes

- Renamed addon from "XP Chronicle" to "XP Bar Enhanced"
- Slash command changed from `/xpc` to `/xpbe`
- SavedVariables renamed to `XPBarEnhancedDB` (auto-migrated)

### Changed

- Simplified architecture (fewer files, clearer structure)
- Improved performance through reduced abstraction layers
```


---

## Phase 2: Architecture Simplification

**Duration:** 8-10 hours  
**Risk Level:** Medium-High  
**Dependencies:** Phase 1 complete

### 2.1 Target File Structure

```
XPBarEnhanced/
├── XPBarEnhanced.toc
├── Frames.xml
├── README.md
├── CHANGELOG.md
├── LICENSE
│
├── core/
│   ├── Core.lua              # Main initialization, event routing (from Addon.lua)
│   ├── Config.lua            # Merged: Config.lua + Defaults.lua + OptionsMetadata.lua
│   ├── Database.lua          # Merged: SavedVariables.lua + Migration.lua
│   ├── Session.lua           # Merged: SessionService.lua + TimePlayedService.lua
│   ├── Utils.lua             # Keep as-is
│   ├── Logger.lua            # Keep as-is
│   └── Locale.lua            # Keep as-is
│
├── features/
│   ├── QuestOverlay.lua      # Refactored from QuestXPService.lua
│   ├── XPBarController.lua   # Simplified from current controller
│   ├── StatsController.lua   # Simplified from current controller
│   └── OptionsController.lua # Simplified from current controller
│
├── ui/
│   ├── xpbar/
│   │   ├── XPBarCommon.xml
│   │   ├── FlatXPBar.xml
│   │   ├── LegacyXPBar.xml
│   │   ├── FlatXPBarMixin.lua
│   │   ├── LegacyXPBarMixin.lua
│   │   ├── XPBarMixinBase.lua
│   │   ├── XPBarColors.lua
│   │   ├── XPBarTextFormatter.lua
│   │   ├── XPBarTooltip.lua      # Enhanced with breakdown
│   │   ├── XPBarView.lua
│   │   └── BlizzardBarControl.lua
│   │
│   ├── stats/
│   │   ├── StatsFrame.xml
│   │   └── StatsView.lua          # Enhanced with breakdown
│   │
│   ├── options/
│   │   ├── OptionsPanel.xml
│   │   ├── OptionsPanelTemplates.xml
│   │   └── Options.lua
│   │
│   └── mixins/
│       ├── DraggableFrameMixin.lua
│       └── PositionStoreMixin.lua
│
├── locales/
│   └── enUS.lua
│
└── libs/
    ├── LibStub/
    └── AceLocale-3.0/
```

**Files Reduced:** 30+ → 12  
**Lines of Code:** ~3000 → ~1800 (estimate)

### 2.2 File Consolidation Map

| Old Files | New File | Action |
|-----------|----------|--------|
| `app/core/Addon.lua` | `core/Core.lua` | Simplify event system |
| `app/core/Config.lua`<br>`app/core/Defaults.lua`<br>`app/config/OptionsMetadata.lua` | `core/Config.lua` | Merge into single config file |
| `app/core/SavedVariables.lua`<br>`app/core/Migration.lua` (new) | `core/Database.lua` | Consolidate data layer |
| `app/services/SessionService.lua`<br>`app/services/TimePlayedService.lua` | `core/Session.lua` | Merge related services |
| `app/services/QuestXPService.lua` | `features/QuestOverlay.lua` | Refactor as feature |
| `app/core/EventBus.lua`<br>`app/core/EventTypes.lua` | *REMOVE* | Use direct event handlers |
| `app/config/SlashCommands.lua` | `core/Core.lua` | Integrate into main file |

### 2.3 Removed Abstractions

#### EventBus → Direct Event Handlers

**Old Pattern (Over-engineered):**
```lua
-- EventBus.lua
EventBus:Subscribe(EventTypes.PLAYER_XP_UPDATE, function(data)
    -- handler code
end)

-- Multiple files subscribing to same event
-- Hard to trace event flow
```

**New Pattern (Simple, Standard):**
```lua
-- Core.lua
local eventHandlers = {}

function eventHandlers:PLAYER_XP_UPDATE()
    Session:OnXPUpdate()
    XPTracking:RecordGain()
    XPBarController:Refresh()
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](eventHandlers, ...)
    end
end)
```

**Benefits:**
- Clear event → action mapping
- Easy to debug (single file for event routing)
- No publish/subscribe complexity
- Standard WoW addon pattern

#### Service Layer → Direct Access

**Old Pattern:**
```lua
-- Calling through service layer
local session = Addon.App.Services.SessionService:GetSession()
local timePlayed = Addon.App.Services.TimePlayedService:GetTimePlayed()
```

**New Pattern:**
```lua
-- Direct access to consolidated modules
local session = Addon.Session:GetCurrent()
local timePlayed = session.totalTime
```

### 2.4 Key Architecture Changes

#### Core.lua Structure

```lua
-- XP Bar Enhanced - Core.lua
local ADDON_NAME, ns = ...
XPBarEnhanced = XPBarEnhanced or {}
local Addon = XPBarEnhanced

-- Initialize namespaces
Addon.Config = {}
Addon.Database = {}
Addon.Session = {}
Addon.XPTracking = {}
Addon.QuestOverlay = {}
Addon.Utils = {}
Addon.Logger = {}

-- Event routing
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function eventHandlers:ADDON_LOADED(name)
    if name ~= ADDON_NAME then return end
    
    Addon.Database:Initialize()
    Addon.Config:Initialize()
    Addon.Session:Initialize()
    Addon.XPTracking:Initialize()
    -- etc.
end

function eventHandlers:PLAYER_LOGIN()
    Addon.Database:MigrateFromXPChronicle()
    Addon.Session:Start()
    Addon.XPBarController:Initialize()
    Addon.StatsController:Initialize()
    Addon.OptionsController:Initialize()
end

function eventHandlers:PLAYER_XP_UPDATE()
    Addon.Session:OnXPUpdate()
    Addon.XPBarController:Refresh()
end

function eventHandlers:CHAT_MSG_COMBAT_XP_GAIN(message)
    Addon.XPTracking:OnCombatXP(message)
end

function eventHandlers:QUEST_TURNED_IN(questID, xpReward)
    Addon.XPTracking:OnQuestXP(questID, xpReward)
end

function eventHandlers:CHAT_MSG_SYSTEM(message)
    Addon.XPTracking:OnSystemMessage(message)
end

function eventHandlers:COMBAT_LOG_EVENT_UNFILTERED()
    Addon.XPTracking:OnCombatLog()
end

-- Event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](eventHandlers, ...)
    end
end)

-- Register events
for event in pairs(eventHandlers) do
    eventFrame:RegisterEvent(event)
end

-- Slash commands
SLASH_XPBARENHANCED1 = "/xpbe"
SLASH_XPBARENHANCED2 = "/xpbarenhanced"
SlashCmdList["XPBARENHANCED"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "options" or command == "config" then
        Addon.OptionsController:Open()
    elseif command == "stats" then
        Addon.StatsController:Toggle()
    elseif command == "reset" then
        Addon.Database:Reset()
    elseif command == "help" then
        print("|cff33ff99XP Bar Enhanced|r Commands:")
        print("/xpbe options - Open options panel")
        print("/xpbe stats - Toggle statistics window")
        print("/xpbe reset - Reset all settings")
    else
        print("|cff33ff99XP Bar Enhanced|r: Use /xpbe help for commands")
    end
end
```

---

## Phase 3: Testing & Validation

**Duration:** 3-4 hours  
**Risk Level:** Low  
**Dependencies:** Phases 1-2 complete

### 3.1 Test Plan

#### 3.1.1 Rename Testing

- [ ] Addon loads without errors
- [ ] SavedVariables migrated from XPChronicleDB
- [ ] New slash commands (/xpbe) work correctly
- [ ] No namespace conflicts with other addons

#### 3.1.2 Architecture Testing

- [ ] All events registered correctly
- [ ] Event handlers execute without errors
- [ ] No performance degradation
- [ ] Memory usage comparable or improved
- [ ] All existing features still work

#### 3.1.3 Edge Cases


### 3.2 Performance Testing

```lua
-- Add performance monitoring
local function measurePerformance()
    local start = debugprofilestop()
    
    -- Execute operation
    Addon.XPBarController:Refresh()
    
    local elapsed = debugprofilestop() - start
    print(string.format("XP bar refresh took %.2f ms", elapsed))
end
```

**Targets:**

- Event handling: < 1ms per event
- Tooltip render: < 5ms
- Stats window render: < 10ms
- Memory usage: < 2MB total

### 3.3 Compatibility Testing

**WoW Versions:**

- [ ] Retail (11.0.2+)
- [ ] Classic Era (optional)
- [ ] Classic Cata (optional)

**Conflict Testing:**

- [ ] No conflicts with original "XP Chronicle" addon
- [ ] Works alongside popular XP addons
- [ ] Works with quest addons (Questie, etc.)
- [ ] Works with UI replacements (ElvUI, etc.)

---

## Appendices

### Appendix A: File-by-File Migration Checklist

#### Core Files

- [ ] **Addon.lua → Core.lua**
  - Remove EventBus dependency
  - Implement direct event handlers
  - Integrate slash commands
  - Add initialization sequence

- [ ] **Config.lua + Defaults.lua + OptionsMetadata.lua → Config.lua**
  - Merge default values
  - Merge option metadata
  - Simplify getter/setter methods
  - Remove unnecessary abstractions


- [ ] **SavedVariables.lua → Database.lua**
  - Add migration function
  - Simplify data access methods
  - Remove complex validation layers

- [ ] **SessionService.lua + TimePlayedService.lua → Session.lua**
  - Merge session tracking
  - Merge time tracking
  - Consolidate related functions

#### Feature Files

- [ ] **QuestXPService.lua → QuestOverlay.lua**
  - Refactor as feature module
  - Simplify API
  - Remove service layer abstractions

- [ ] **XPBarController.lua**
  - Simplify controller logic
  - Remove EventBus dependencies
  - Direct method calls

#### UI Files

- [ ] **XPBarTooltip.lua**
  - Maintain current tooltip functionality
  - Ensure proper formatting

- [ ] **StatsView.lua**
  - Maintain current stats display
  - Update for new data structure


### Appendix B: Migration Command Reference

```bash
# Phase 1: Rename operations (PowerShell)

# 1. Rename main TOC file
Rename-Item "XPChronicle.toc" "XPBarEnhanced.toc"

# 2. Find and replace in all files
Get-ChildItem -Recurse -Include *.lua,*.xml,*.toc | 
    ForEach-Object {
        (Get-Content $_.FullName) -replace 'XPChronicle', 'XPBarEnhanced' | 
        Set-Content $_.FullName
    }

# 3. Update SavedVariables references
Get-ChildItem -Recurse -Include *.lua | 
    ForEach-Object {
        (Get-Content $_.FullName) -replace 'XPChronicleDB', 'XPBarEnhancedDB' | 
        Set-Content $_.FullName
    }
```

### Appendix C: Testing Macro

```lua
-- In-game testing macro for XP breakdown
/run local A = XPBarEnhanced; if A and A.XPTracking then local b = A.XPTracking:GetSessionBreakdown(); print("|cff33ff99Breakdown:|r Quest:", b.quest, "Kill:", b.kill, "Discovery:", b.discovery, "Other:", b.generic) else print("XP Tracking not loaded") end
```

### Appendix D: Pre-Migration Backup

**Create backup before starting:**

```bash
# PowerShell backup command
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$source = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XPChronicle"
$backup = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XPChronicle_backup_$timestamp"
Copy-Item -Path $source -Destination $backup -Recurse
Write-Host "Backup created: $backup"
```

### Appendix E: Rollback Plan

If migration fails:

1. Delete `XPBarEnhanced` folder
2. Restore backup: `Copy-Item -Path $backup -Destination $source -Recurse -Force`
3. Restore `XPChronicleDB` from WTF backup
4. `/reload` in-game

### Appendix F: Post-Migration Cleanup

After successful migration and 1-2 weeks of testing:

```lua
-- Remove migration code from Database.lua
-- Remove old XPChronicleDB cleanup
-- Archive refs/ folder (move outside addon directory)
```

---

## Timeline Summary

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1: Rename | 2 hours | Day 1 | Day 1 |
| Phase 2: Architecture | 8-10 hours | Day 1 | Day 2-3 |
| Phase 3: Testing | 3-4 hours | Day 3 | Day 3 |
| **Total** | **13-16 hours** | **Day 1** | **Day 3** |


---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during migration | Low | High | Backup SavedVariables, auto-migration script |
| Event handling breaks | Low | High | Comprehensive testing, direct event pattern |
| Performance degradation | Low | Medium | Performance monitoring, profiling |
| User confusion (rename) | Medium | Low | Clear messaging, migration guide |

---

## Success Criteria

- ✅ All users' settings migrated successfully
- ✅ No addon errors in live gameplay
- ✅ Performance within 10% of current version
- ✅ All existing features working
- ✅ Code complexity reduced by 40%+
- ✅ File count reduced from 30+ to ~12

---

## Notes

- Keep `refs/` folder during development for reference
- Consider beta release to select users before full release
- Update CurseForge/Wago descriptions
- Create migration FAQ for users
- XP breakdown feature deferred to future version (3.0+)

---

**Document Version:** 2.0  
**Last Updated:** October 15, 2025  
**Author:** Ciaanh

