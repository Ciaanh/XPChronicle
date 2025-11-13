# Circular V2 OnLoad Issue Analysis

## Problem Statement
The Circular V2 bar does not display the bar status and texts on initial load (`PLAYER_ENTERING_WORLD` event). The bar remains empty until a player XP event occurs (like gaining XP).

In contrast, Legacy V2 and Vertical V2 bars display correctly on initial load.

## Root Cause Analysis

### Issue 1: Early Return in RenderBar
The circular bar has a critical early return in its `RenderBar` method that prevents initial rendering:

**CircularBarStyle.lua** (lines 447-453):
```lua
function CircularBarStyleTemplate:RenderBar(context)
    -- ...
    
    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
        -- Render instant for first time
        self:RenderBarFrame(targetRatio, context)
        return  -- ⚠️ EARLY RETURN - STOPS HERE!
    end
    
    -- ANIMATION DECISION (use context flags)
    if context.shouldAnimate then
        -- ...
    end
end
```

**The Problem:**
- On first load, `_currentRatio` is `nil`
- The code calls `RenderBarFrame(targetRatio, context)` BUT **immediately returns**
- This return happens **BEFORE** overlays and text updates are called
- The bar segments are drawn, but **NO OVERLAYS** and **NO TEXT** are rendered

### Issue 2: Missing Updates After RenderBar
Compare with Legacy V2 and Vertical V2, which update overlays and text **AFTER** the animation decision:

**LegacyBarStyle.lua** (lines 115-138):
```lua
function LegacyBarStyleTemplate:RenderBar(context)
    -- Calculate target ratio
    local targetRatio = 0
    if context.xpMax and context.xpMax > 0 then
        targetRatio = (context.currentXP or 0) / context.xpMax
    end

    -- ANIMATION DECISION
    if context.shouldAnimate then
        self:StartAnimation(targetRatio, xpContext, config)
    else
        self:RenderBarFrame(targetRatio, context)
    end

    -- ✅ Update overlays (always update, even during animation)
    if self.UpdateRestedOverlay then
        self:UpdateRestedOverlay(context)
    end
    if self.UpdateQuestCompleteOverlay then
        self:UpdateQuestCompleteOverlay(context)
    end
    if self.UpdateQuestIncompleteOverlay then
        self:UpdateQuestIncompleteOverlay(context)
    end
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick(context)
    end

    -- ✅ Update text
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

**Key Difference:**
- Legacy/Vertical styles update overlays and text **at the RenderBar level**
- Circular style only updates text **inside RenderBarFrame**
- When the early return happens, overlays and text are never updated

### Issue 3: RenderBarFrame Only Updates Text (Not Overlays)
**CircularBarStyle.lua RenderBarFrame** (lines 483-500):
```lua
function CircularBarStyleTemplate:RenderBarFrame(currentRatio, context)
    -- 1. MAIN BAR (at current animation position)
    local hasRestedXP = context.hasRestedXP or false
    self:SetArcProgress(currentRatio, hasRestedXP)

    -- Update current ratio tracking
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    -- 2. TEXT (updates every frame to show animated values)
    if self.UpdateTexts then
        self:UpdateTexts(context)  -- ✅ Text IS called
    end

    -- Note: Overlays are handled inside SetArcProgress for circular bar
    -- ❌ BUT on first load, the overlay UPDATE methods are never called
    -- because RenderBar returns early before reaching overlay updates!
}
```

**The Comment is Misleading:**
- The comment says "Overlays are handled inside SetArcProgress"
- This is **partially true**: `SetArcProgress` uses **cached overlay data** (`cachedRestedXP`, `cachedCompleteQuestXP`, etc.)
- BUT these caches are **NOT populated on first load** because the overlay update methods are never called!

## Workflow Comparison

### Circular V2 (Broken) - First Load Flow
```
OnLoad()
  └─> XPBarMixinBase_v2.OnLoad(self)
        └─> self:Refresh()
              └─> BuildXPChangeContext("PLAYER_ENTERING_WORLD")
                    └─> TriggerBarRefresh(context)
                          └─> RenderBar(context)
                                ├─> _currentRatio is nil
                                ├─> SetCurrentRatio(targetRatio)
                                ├─> RenderBarFrame(targetRatio, context)
                                │     ├─> SetArcProgress() - uses EMPTY cached overlay data
                                │     └─> UpdateTexts(context)
                                └─> return ❌ EARLY EXIT
                                
                                ❌ UpdateRestedOverlay() - NEVER CALLED
                                ❌ UpdateQuestCompleteOverlay() - NEVER CALLED
                                ❌ UpdateQuestIncompleteOverlay() - NEVER CALLED
                                ❌ UpdateExhaustionTick() - NEVER CALLED
```

### Legacy/Vertical V2 (Working) - First Load Flow
```
OnLoad()
  └─> XPBarMixinBase_v2.OnLoad(self)  [Note: No style-specific OnLoad]
        └─> self:Refresh()
              └─> BuildXPChangeContext("PLAYER_ENTERING_WORLD")
                    └─> TriggerBarRefresh(context)
                          └─> RenderBar(context)
                                ├─> Calculate targetRatio
                                ├─> Animation decision (instant update)
                                ├─> RenderBarFrame(targetRatio, context)
                                │     ├─> StatusBar:SetValue(currentRatio)
                                │     └─> UpdateBarColors(context)
                                ├─> ✅ UpdateRestedOverlay(context)
                                ├─> ✅ UpdateQuestCompleteOverlay(context)
                                ├─> ✅ UpdateQuestIncompleteOverlay(context)
                                ├─> ✅ UpdateExhaustionTick(context)
                                └─> ✅ UpdateTexts(context)
```

### Circular V2 - After XP Event (Works)
```
OnEvent("PLAYER_XP_UPDATE")
  └─> BuildXPChangeContext("PLAYER_XP_UPDATE")
        └─> TriggerBarRefresh(context)
              └─> RenderBar(context)
                    ├─> _currentRatio EXISTS now
                    ├─> Animation decision
                    ├─> StartAnimation() OR RenderBarFrame()
                    │     ├─> SetArcProgress() - now uses populated cached data
                    │     └─> UpdateTexts(context)
                    └─> NO EARLY RETURN! ✅
                    
                    [But overlays/text are still not updated here!]
```

## Additional Discovery: Circular OnLoad Implementation
The circular bar has a **custom OnLoad** that differs from other styles:

**CircularBarStyle.lua OnLoad** (lines 49-77):
```lua
function CircularBarStyleTemplate:OnLoad()
    -- Circular bar specific setup
    self.segments = {}
    self.segmentTypes = {}
    self.lastProgress = 0
    self.targetProgress = 0
    self.isAnimating = false

    -- Initialize cached overlay data
    self.cachedRestedXP = 0
    self.cachedCompleteQuestXP = 0
    self.cachedIncompleteQuestXP = 0
    self.cachedHasRestedXP = false

    -- Create ring segments
    self:CreateRingSegments()

    -- Call base OnLoad first (initializes animation system)
    if XPBarMixinBase_v2 and XPBarMixinBase_v2.OnLoad then
        XPBarMixinBase_v2.OnLoad(self)
    end
    
    -- Build initial context and render
    if XPBarContextBuilder then
        local context = XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD")
        if context and self.RenderBar then
            self:RenderBar(context)  -- ❌ Calls RenderBar which hits early return!
        end
    end
end
```

**Problems:**
1. Calls `RenderBar` directly from `OnLoad` (before base `Refresh` is called)
2. This triggers the early return path
3. The base `OnLoad` **also** calls `Refresh()` which triggers another `RenderBar` call
4. **Both calls** hit the early return because `_currentRatio` is still nil after the first call sets it

**Legacy/Vertical V2 have NO custom OnLoad** - they rely solely on base `OnLoad` → `Refresh` → `RenderBar` flow.

## Why Text Shows Up Eventually

Text actually **does** get updated on first load because:
1. `RenderBarFrame` is called (before early return)
2. `RenderBarFrame` calls `UpdateTexts(context)`

However, overlays (rested, quest complete, quest incomplete, exhaustion tick) are **never** updated because:
1. The early return happens before reaching overlay update calls
2. The cached overlay data remains at initialized zero values
3. `SetArcProgress` uses these empty cached values to draw segments

## Solution Options

### Option 1: Remove Early Return (Recommended)
Remove the early return and follow the same pattern as Legacy/Vertical:

```lua
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Determine target ratio
    local curXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1
    local targetRatio = (maxXP > 0) and (curXP / maxXP) or 0

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end

    -- ANIMATION DECISION (use context flags)
    if context.shouldAnimate then
        -- Start animation
        local xpContext = { ... }
        local config = self:GetAnimationConfig()
        self:StartAnimation(targetRatio, xpContext, config)
    else
        -- Instant update
        self:RenderBarFrame(targetRatio, context)
    end
    
    -- ✅ Always update overlays and text (like Legacy/Vertical)
    if self.UpdateRestedOverlay then
        self:UpdateRestedOverlay(context)
    end
    if self.UpdateQuestCompleteOverlay then
        self:UpdateQuestCompleteOverlay(context)
    end
    if self.UpdateQuestIncompleteOverlay then
        self:UpdateQuestIncompleteOverlay(context)
    end
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick(context)
    end
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

### Option 2: Remove Custom OnLoad
Remove the circular-specific `OnLoad` and let base `OnLoad` handle initialization:

```lua
-- Remove custom OnLoad entirely, move segment creation elsewhere
function CircularBarStyleTemplate:OnLoad()
    -- Circular bar specific setup
    self.segments = {}
    self.segmentTypes = {}
    self.lastProgress = 0
    self.targetProgress = 0
    self.isAnimating = false

    -- Initialize cached overlay data
    self.cachedRestedXP = 0
    self.cachedCompleteQuestXP = 0
    self.cachedIncompleteQuestXP = 0
    self.cachedHasRestedXP = false

    -- Create ring segments
    self:CreateRingSegments()

    -- Call base OnLoad (will handle Refresh)
    if XPBarMixinBase_v2 and XPBarMixinBase_v2.OnLoad then
        XPBarMixinBase_v2.OnLoad(self)
    end
    
    -- ❌ REMOVE THIS - let base OnLoad call Refresh
    -- if XPBarContextBuilder then
    --     local context = XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD")
    --     if context and self.RenderBar then
    --         self:RenderBar(context)
    --     end
    -- end
end
```

### Option 3: Update Overlays Before Early Return
Move overlay updates before the early return:

```lua
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Calculate target ratio
    local curXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1
    local targetRatio = (maxXP > 0) and (curXP / maxXP) or 0

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
        
        -- ✅ Update overlays BEFORE rendering
        if self.UpdateRestedOverlay then
            self:UpdateRestedOverlay(context)
        end
        if self.UpdateQuestCompleteOverlay then
            self:UpdateQuestCompleteOverlay(context)
        end
        if self.UpdateQuestIncompleteOverlay then
            self:UpdateQuestIncompleteOverlay(context)
        end
        if self.UpdateExhaustionTick then
            self:UpdateExhaustionTick(context)
        end
        
        -- Render instant for first time
        self:RenderBarFrame(targetRatio, context)
        return
    end

    -- Rest of animation logic...
end
```

## Recommendation

**Use Option 1 (Remove Early Return) + Option 2 (Simplify OnLoad)**

This approach:
1. Makes circular bar consistent with legacy/vertical patterns
2. Ensures overlays and text are always updated
3. Removes unnecessary complexity and duplicate render calls
4. Follows the established V2 architecture pattern

The early return was likely added as an optimization but actually breaks the initialization flow.
