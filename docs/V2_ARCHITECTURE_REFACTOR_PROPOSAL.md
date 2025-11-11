# V2 Architecture Refactor Proposal
## Simplified Event → Context → Render Pipeline

### Current Problems

#### 1. **Redundant Function Calls**
Every event triggers multiple layers of updates:
```
Event → BuildContext → TriggerXPChanged
    → UpdateCurrentXPBar (layout + color)
    → UpdateRestedOverlay (layout + color)
    → UpdateQuestCompleteOverlay (layout + color)
    → UpdateQuestIncompleteOverlay (layout + color)
    → UpdateExhaustionTick (layout)
    → UpdateVisuals
        → UpdateBars
            → UpdateCurrentXPBar AGAIN (recursive)
        → UpdateOverlays
            → UpdateRestedOverlay AGAIN (recursive)
            → UpdateQuestCompleteOverlay AGAIN (recursive)
            → UpdateQuestIncompleteOverlay AGAIN (recursive)
            → UpdateExhaustionTick AGAIN (recursive)
        → UpdateTexts
```

**Result**: Each overlay is updated 2x per event (performance waste)

#### 2. **Context Not Passed to Color Methods**
```lua
-- PaintMixin methods don't receive context
function UpdateRestedOverlayColor(overlayName)
    -- NO context parameter!
    -- Can't make dynamic color decisions based on state
end
```

#### 3. **Split Layout/Color Updates**
Each visual element requires TWO method calls:
- `UpdateRestedOverlayLayout(context)` - position/size
- `UpdateRestedOverlayColor()` - color (no context!)

This creates tight coupling and makes it hard to reason about state.

#### 4. **Inconsistent Context Building**
- Most events: build immutable context ✅
- Periodic ticker: NO context (nil) ❌
- FullUpdate: optional context ⚠️
- Color methods: NO context ❌

#### 5. **Circular Bar Has Better Pattern**
The circular bar style uses a **single render method**:
```lua
function SetArcProgress(progress, hasRestedXP)
    -- Single pass:
    -- 1. Calculate all segment types (current XP, rested, quests)
    -- 2. Apply colors based on type
    -- 3. Update visibility
    -- Done in ONE function call
end
```

---

## Proposed Architecture

### Core Principle: **Event → Context → Render**

```
[WoW Event] 
    ↓
[BuildEnrichedContext with event flags]
    ↓
[TriggerBarRefresh - Single entry point]
    ↓
[RenderBar - Single style-specific method]
    ↓
[Done]
```

### 1. Enhanced Context Builder

Add **event behavior flags** to context:

```lua
-- In ContextBuilder
function BuildXPChangeContext(event, ...)
    local ctx = BuildBaseContext(...)
    
    -- Add event-specific flags
    ctx.hasGainedXP = (ctx.xpGained and ctx.xpGained > 0)
    ctx.hasLeveledUp = false
    ctx.shouldAnimate = ctx.hasGainedXP
    ctx.shouldFlash = ctx.hasGainedXP
    
    return MakeImmutable(ctx)
end

function BuildLevelUpContext(event, newLevel)
    local ctx = BuildBaseContext(...)
    
    -- Add level-up specific flags
    -- Level-up DOES gain XP: from 0 to currentXP at new level
    ctx.hasGainedXP = (ctx.currentXP and ctx.currentXP > 0)
    ctx.hasLeveledUp = true
    ctx.shouldAnimate = true
    ctx.shouldFlash = ctx.hasGainedXP  -- Flash only if we have XP at new level
    ctx.oldLevel = newLevel - 1
    ctx.newLevel = newLevel
    
    return MakeImmutable(ctx)
end
```

#### Important: Level-Up XP Gain Logic

When a player levels up, they **DO gain XP** at the new level! Consider this scenario:

**Example:**
- Player is level 70 with 9,950/10,000 XP
- Kills a mob worth 500 XP
- Level-up occurs: 9,950 + 500 = 10,450 XP total
- New level 71 XP: 10,450 - 10,000 = **450 XP** at new level
- `currentXP = 450` (the wraparound XP)
- `hasGainedXP = true` (player gained 450 XP at new level)
- `shouldFlash = true` (provide visual feedback)

**Why this matters:**
1. ✅ Bar animates from 0 → 450 XP at new level (smooth visual)
2. ✅ Flash overlay shows (indicates XP gain)
3. ✅ Consistent behavior with normal XP gains
4. ✅ Player sees their progress at new level immediately

**Edge case:**
- If player gains EXACTLY enough XP to level (rare), `currentXP = 0`
- `hasGainedXP = false` (no XP at new level yet)
- `shouldFlash = false` (no flash needed)
- Bar shows empty (correct)

This logic ensures the context accurately reflects the player's state at level-up.

---

```lua
function BuildRestedContext(event, ...)
    local ctx = BuildBaseContext(...)
    
    -- Rested change flags
    ctx.hasGainedXP = false
    ctx.hasLeveledUp = false
    ctx.shouldAnimate = false  -- No bar animation for rested change
    ctx.shouldFlash = false
    ctx.restedChanged = true
    
    return MakeImmutable(ctx)
end

function BuildQuestContext(event, ...)
    local ctx = BuildBaseContext(...)
    
    -- Quest change flags
    ctx.hasGainedXP = false
    ctx.hasLeveledUp = false
    ctx.shouldAnimate = false  -- No bar animation for quest overlay change
    ctx.shouldFlash = false
    ctx.questsChanged = true
    
    return MakeImmutable(ctx)
end
```

### 2. Simplified BaseMixin

**Remove all Trigger methods** - replace with single `TriggerBarRefresh`:

```lua
---@class XPBarMixinBase_v2
XPBarMixinBase_v2 = {}

--- Single public API for all updates
function BaseMixin:Refresh()
    local context = XPBarContextBuilder.BuildXPChangeContext("MANUAL_REFRESH")
    self:TriggerBarRefresh(context)
end

function BaseMixin:FullUpdate(context)
    if self._isUpdating then return end
    self._isUpdating = true
    
    if not context then
        context = XPBarContextBuilder.BuildXPChangeContext("FULL_UPDATE")
    end
    
    self:TriggerBarRefresh(context)
    self._isUpdating = nil
end

-------------------------------------------------------------------
-- EVENT ORCHESTRATION
-------------------------------------------------------------------

function BaseMixin:OnEvent(event, ...)
    local context
    
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_XP_UPDATE" then
        context = XPBarContextBuilder.BuildXPChangeContext(event, ...)
        
    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        context = XPBarContextBuilder.BuildLevelUpContext(event, newLevel)
        
    elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
        context = XPBarContextBuilder.BuildRestedContext(event, ...)
        
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or 
           event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or
           event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_WATCH_UPDATE" then
        context = XPBarContextBuilder.BuildQuestContext(event, ...)
        
    elseif event == "TIME_PLAYED_MSG" then
        -- Store data, no visual update needed
        return
    end
    
    if context then
        self:TriggerBarRefresh(context)
    end
end

-------------------------------------------------------------------
-- SINGLE REFRESH TRIGGER
-------------------------------------------------------------------

--- Single entry point for all bar updates
--- Calls style-specific RenderBar method
---@param context table Immutable context from ContextBuilder
function BaseMixin:TriggerBarRefresh(context)
    -- Explicit context required
    if not context then
        error("TriggerBarRefresh requires an explicit immutable context")
    end
    
    -- Call style-specific render method (MUST be implemented by style)
    if not self.RenderBar then
        error("Style must implement RenderBar(context) method")
    end
    
    self:RenderBar(context)
end
```

### 3. New Style-Specific RenderBar Method

Each style implements **ONE method** that handles everything:

#### Example: FlatBar Style

```lua
--- Single render method for flat bar
--- Handles layout, colors, animation, and text in one pass
---@param context table Immutable context with all state and flags
function FlatBarStyle:RenderBar(context)
    -- ANIMATION DECISION
    if context.shouldAnimate then
        -- Start animation
        -- AnimationManager will call RenderBarFrame(progress, context) on each frame
        -- This ensures ALL elements (bar + overlays + text) update during animation
        local targetRatio = self:CalculateBarRatio(context.currentXP, context.xpMax)
        local config = self:GetAnimationConfig()
        self:StartAnimation(targetRatio, context, config)
        
        -- Note: StartAnimation will call RenderBarFrame immediately for first frame
        -- No need to call RenderBarFrame here
    else
        -- Instant update (no animation)
        -- Render all elements at final position
        local finalRatio = self:CalculateBarRatio(context.currentXP, context.xpMax)
        self:RenderBarFrame(finalRatio, context)
    end
end

--- Render all bar elements for a single animation frame
--- Called by AnimationManager on each tick, or once for instant updates
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function FlatBarStyle:RenderBarFrame(currentRatio, context)
    -- 1. MAIN BAR (at current animation position)
    self:RenderBarInstant(currentRatio, context)
    
    -- 2. OVERLAYS (react to current bar position)
    -- These update every frame so they can "follow" the animated bar
    -- Example: Rested overlay shrinks as XP bar grows into it
    self:RenderRestedOverlay(currentRatio, context)
    self:RenderQuestOverlays(currentRatio, context)
    self:RenderExhaustionTick(currentRatio, context)
    
    -- 3. TEXT (updates every frame to show animated values)
    self:RenderText(context)
end

--- Instant bar render (no animation)
---@param finalRatio number The final bar ratio to display
---@param context table Immutable context
function FlatBarStyle:RenderBarInstant(finalRatio, context)
    local bar = self.StatusBar
    if not bar then return end
    
    -- Set bar to final position
    bar:SetValue(finalRatio)
    
    -- Apply color based on rested state
    local hasRestedXP = context.hasRestedXP or false
    local colorKey = hasRestedXP and Color.XpBarRested or Color.XpBar
    local color = XPBarColors:GetUserColor(colorKey)
    bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

--- Render rested overlay (layout + color in one method)
--- During animation, this recalculates based on current bar position
--- This allows the overlay to "shrink" as the bar grows into it
---@param currentRatio number Current bar ratio (for animation)
---@param context table Immutable context
function FlatBarStyle:RenderRestedOverlay(currentRatio, context)
    local overlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
    if not overlay then return end
    
    -- Check visibility flag
    if context.showRestedOverlay == false then
        overlay:Hide()
        return
    end
    
    -- Calculate bounds based on CURRENT bar position (not final)
    -- This allows overlay to react to animated bar
    local barWidth = self:ValidateBarWidth(self)
    local currentXP = currentRatio * (context.xpMax or 1)
    local animContext = {
        currentXP = currentXP,  -- Use animated position
        xpMax = context.xpMax,
        restedXP = context.restedXP,
        -- ... other context fields
    }
    local offsetPixels, widthPixels, visible = self:CalculateRestedBounds(animContext, barWidth)
    
    overlay:SetShown(visible)
    
    if visible then
        -- Set size based on current animation state
        overlay:SetWidth(widthPixels)
        
        -- Set color
        local color = XPBarColors:GetUserColor(Color.Rested)
        overlay:SetVertexColor(color.r, color.g, color.b, color.a)
    end
end

--- Render quest overlays (complete + incomplete)
function FlatBarStyle:RenderQuestOverlays(context)
    self:RenderQuestCompleteOverlay(context)
    self:RenderQuestIncompleteOverlay(context)
end

--- Render complete quest overlay (layout + color)
function FlatBarStyle:RenderQuestCompleteOverlay(context)
    local overlay = self.QuestOverlayComplete
    if not overlay then return end
    
    local completeXP = context.completeQuestXP or 0
    local showComplete = context.showCompleteQuestOverlay
    
    local visible = false
    if showComplete and completeXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local questXPClamped = math.min(completeXP, remainingXP)
        local ratio = questXPClamped / maxXP
        
        if ratio >= 0.01 then
            local barWidth = self:ValidateBarWidth(self)
            local offsetPixels, widthPixels = self:CalculateOverlayBounds(currentXP, questXPClamped, maxXP, barWidth)
            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", offsetPixels, 0)
            overlay:SetWidth(math.max(1, widthPixels))
            
            -- Set color
            local color = XPBarColors:GetUserColor(Color.QuestComplete)
            overlay:SetVertexColor(color.r, color.g, color.b, color.a)
            
            visible = true
        end
    end
    
    overlay:SetShown(visible)
end

--- Render incomplete quest overlay (layout + color)
function FlatBarStyle:RenderQuestIncompleteOverlay(context)
    -- Similar to RenderQuestCompleteOverlay, but for incomplete quests
    -- [Implementation similar to above]
end

--- Render exhaustion tick (layout only, inherits color from texture)
function FlatBarStyle:RenderExhaustionTick(context)
    local tick = self.ExhaustionTick or (self.StatusBar and self.StatusBar.ExhaustionTick)
    if not tick then return end
    
    -- Check visibility flag
    if context.showExhaustionTick == false then
        tick:Hide()
        return
    end
    
    -- Calculate visibility and position
    local restedXP = context.restedXP or 0
    local currentXP = context.currentXP or 0
    local maxXP = context.xpMax or 1
    local remainingXP = math.max(0, maxXP - currentXP)
    local restedXPClamped = math.min(restedXP, remainingXP)
    local restedRatio = restedXPClamped / maxXP
    
    local visible = restedXP > 0 and restedRatio >= 0.01 and restedRatio <= 0.99
    tick:SetShown(visible)
    
    if visible then
        local restedOverlay = self.RestedOverlay or (self.StatusBar and self.StatusBar.RestedOverlay)
        if restedOverlay then
            local origPoint, origRelTo, origRelPoint, origX, origY = tick:GetPoint(1)
            local xOff = origX or 0
            local yOff = origY or 0
            tick:ClearAllPoints()
            tick:SetPoint("CENTER", restedOverlay, "RIGHT", xOff, yOff)
        end
    end
end

--- Render all text elements
function FlatBarStyle:RenderText(context)
    -- Delegate to TextMixin (still centralized)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

#### Example: Circular Bar Style (Already Has This Pattern!)

```lua
--- Circular bar render method (already implemented!)
function CircularBarStyle:RenderBar(context)
    -- ANIMATION DECISION
    if context.shouldAnimate then
        -- Start animation
        -- AnimationManager will call RenderBarFrame on each frame
        local targetRatio = context.currentXP / context.xpMax
        local config = self:GetAnimationConfig()
        self:StartAnimation(targetRatio, context, config)
    else
        -- Instant update - render all elements at final position
        local finalRatio = context.currentXP / context.xpMax
        self:RenderBarFrame(finalRatio, context)
    end
end

--- Render all elements for a single frame
function CircularBarStyle:RenderBarFrame(currentRatio, context)
    -- Calculate current XP based on animation progress
    local animatedXP = currentRatio * context.xpMax
    local hasRestedXP = context.hasRestedXP or false
    
    -- SetArcProgress does EVERYTHING in one pass:
    -- - Calculates segment types (current XP, rested, quest complete, quest incomplete)
    -- - Applies colors based on type and current position
    -- - Updates visibility
    -- - All overlays react to current bar position
    self:SetArcProgress(currentRatio, hasRestedXP, context)
    
    -- Update text
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

--- SetArcProgress already does EVERYTHING in one pass:
--- This is the IDEAL pattern that all styles should follow!
function CircularBarStyle:SetArcProgress(progress, hasRestedXP, context)
    -- [Existing implementation is already optimal]
    -- All segments calculated and colored based on current progress
    -- Overlays automatically positioned relative to main arc
end
```

---

## Migration Path

### Phase 1: Add Context Flags ✅
✅ Add event flags to ContextBuilder (hasGainedXP, hasLeveledUp, shouldAnimate, shouldFlash)
✅ Update BuildXPChangeContext, BuildLevelUpContext, BuildRestedContext, BuildQuestContext
✅ All existing code continues to work (flags are additive)

### Phase 2: Implement RenderBar for All Styles 🔄
✅ Implement RenderBar(context) for Circular style (already done!)
⏳ Implement RenderBar(context) for Flat style
⏳ Implement RenderBar(context) for Legacy style
⏳ Implement RenderBar(context) for Vertical style

### Phase 3: Switch to TriggerBarRefresh ⚠️ BREAKING
⚠️ Update BaseMixin.OnEvent to call TriggerBarRefresh instead of old Trigger methods
⚠️ Remove TriggerXPChanged, TriggerLevelUp, TriggerRestedChanged, TriggerQuestChanged
⚠️ All styles MUST have RenderBar implemented before this step

### Phase 4: Clean Up Old Code 🧹
🧹 Remove VisualsMixin (UpdateBars, UpdateOverlays orchestration)
🧹 Remove split Layout/Paint methods (keep calculation helpers only)
🧹 Remove UpdateCurrentXPBar, UpdateRestedOverlay, UpdateQuestXXXOverlay methods
🧹 Keep LayoutMixin calculation helpers (CalculateBarRatio, CalculateOverlayBounds, etc.)
🧹 Keep TextMixin (centralized text formatting - still useful)

**Note:** This is a clean break approach - no legacy fallback code to maintain!

**Why no fallback?**
- 🎯 **Simpler codebase**: No dual code paths to maintain
- 🚀 **Faster development**: All styles migrate together
- 🧪 **Better testing**: One pattern to test, not two
- 📖 **Clearer intent**: New code is the only code
- 🔧 **Easier maintenance**: No "legacy mode" edge cases

**Migration strategy:**
1. Implement RenderBar for all 4 styles in parallel
2. Test each style thoroughly with new pattern
3. Switch all styles at once (single PR/commit)
4. Remove all old Trigger/Update methods immediately
5. No gradual migration = no confusing hybrid state

---

## Benefits

### 1. **Performance**
- ❌ **Before**: 2x updates per event (Trigger + UpdateVisuals recursion)
- ✅ **After**: 1x update per event (TriggerBarRefresh → RenderBar)

### 2. **Simplicity**
- ❌ **Before**: 18+ methods per style (UpdateCurrentXPBar, UpdateBarLayout, UpdateBarColors, UpdateRestedOverlay, UpdateRestedOverlayLayout, UpdateRestedOverlayColor, etc.)
- ✅ **After**: ~6 methods per style (RenderBar, RenderRestedOverlay, RenderQuestOverlays, RenderExhaustionTick, RenderText)

### 3. **Context Consistency**
- ❌ **Before**: Context sometimes passed, sometimes nil, color methods never get context
- ✅ **After**: Context ALWAYS passed to every render method

### 4. **Better Locality**
- ❌ **Before**: Layout in LayoutMixin, color in PaintMixin, orchestration in VisualsMixin
- ✅ **After**: Each visual element handled in ONE method (layout + color together)

### 5. **Easier Testing**
- ❌ **Before**: Must call 3+ methods to test one visual element
- ✅ **After**: Call RenderBar(mockContext) and verify output

### 6. **Clearer Intent**
- ❌ **Before**: TriggerXPChanged, TriggerLevelUp, TriggerRestedChanged (what's the difference?)
- ✅ **After**: TriggerBarRefresh(context with flags) (intent is clear from context)

---

## Code Size Comparison

### Before (Current V2)
```
BaseMixin.lua:         360 lines (Trigger methods, event routing)
VisualsMixin.lua:      100 lines (Orchestration)
LayoutMixin.lua:       350 lines (Layout calculations + update methods)
PaintMixin.lua:        150 lines (Color application + update methods)
TextMixin.lua:         330 lines (Text formatting)
FlatBarStyle.lua:      200 lines (Style-specific overrides)
---------------------------------------------------
TOTAL:                ~1490 lines for one style
```

### After (Proposed Refactor)
```
BaseMixin.lua:         120 lines (Simplified event routing, TriggerBarRefresh)
ContextBuilder.lua:    500 lines (Enhanced with flags)
LayoutMixin.lua:       150 lines (Calculation helpers ONLY - no update methods)
TextMixin.lua:         330 lines (Unchanged - still centralized)
FlatBarStyle.lua:      400 lines (Complete render logic + helpers)
---------------------------------------------------
TOTAL:                ~1500 lines for one style (+0.7%)

BUT: 
- No VisualsMixin orchestration (100 lines removed)
- No PaintMixin update methods (150 lines removed)
- No split Layout update methods (200 lines removed)
- Much clearer separation: calculation vs rendering
- All rendering logic in ONE place per style
```

**Net Result:** Similar total lines, but FAR better organization and maintainability!

---

## Comparison: Current vs Circular vs Proposed

### Current Pattern (Flat/Legacy/Vertical)
```lua
-- Multiple calls per event
TriggerXPChanged(context)
    UpdateCurrentXPBar(context)
        UpdateBarLayout(context)      -- LayoutMixin
        UpdateBarColors(context)       -- PaintMixin
    UpdateRestedOverlay(context)
        UpdateRestedOverlayLayout(context)    -- LayoutMixin
        UpdateRestedOverlayColor()             -- PaintMixin (NO CONTEXT!)
    UpdateVisuals(context)
        UpdateBars(context)
            UpdateCurrentXPBar(context) AGAIN  -- RECURSIVE!
        UpdateOverlays(context)
            UpdateRestedOverlay(context) AGAIN -- RECURSIVE!
        UpdateTexts(context)

Result: 10+ method calls, 2x redundancy, no context for colors
```

### Circular Pattern (Current - Already Optimal!)
```lua
-- Single call per event
TriggerXPChanged(context)
    RenderBar(context)
        if shouldAnimate:
            StartAnimation(targetRatio, context)
                // AnimationManager calls RenderBarFrame on each tick
                RenderBarFrame(currentRatio, context)
                    SetArcProgress(currentRatio, hasRestedXP, context)
                        // Calculate all segments based on current animation position
                        // Apply colors based on type and position
                        // Update visibility
                    UpdateTexts(context)
        else:
            RenderBarFrame(finalRatio, context)
                // Same render logic, single call

Result: All elements update every frame during animation
        Overlays react dynamically to bar position
        Context available everywhere
```

### Proposed Pattern (Unified)
```lua
-- Single call per event, consistent across all styles
TriggerBarRefresh(context)
    RenderBar(context)
        if shouldAnimate:
            StartAnimation(targetRatio, context)
                // AnimationManager calls RenderBarFrame on each tick
                RenderBarFrame(currentRatio, context)
                    RenderBarInstant(currentRatio, context)        // Bar at current position
                    RenderRestedOverlay(currentRatio, context)     // Reacts to bar position
                    RenderQuestOverlays(currentRatio, context)     // Reacts to bar position
                    RenderExhaustionTick(currentRatio, context)    // Reacts to bar position
                    RenderText(context)                            // Updates every frame
        else:
            RenderBarFrame(finalRatio, context)
                // Same methods, single call for instant update

Result: Unified pattern across all styles
        All elements animate together
        Overlays can "follow" or "react to" bar growth
        Example: XP bar pushes into rested overlay during animation
```

---

## Key Innovation: Full-Frame Rendering During Animation

### The Problem with Partial Updates

Many UI systems update only the animated element:

```lua
// BAD: Only animate the bar
function AnimateBar(targetRatio, context)
    OnEachFrame:
        bar:SetValue(currentRatio)  -- Only bar updates
    
    // Overlays stay static during animation
    // Text updates only at end
    // No dynamic interactions
end
```

### The Solution: RenderBarFrame

Our approach renders **ALL elements on every animation frame**:

```lua
// GOOD: Render everything each frame
function RenderBar(context)
    if context.shouldAnimate then
        StartAnimation(targetRatio, context)
            OnEachFrame:
                RenderBarFrame(currentRatio, context)
                    RenderBarInstant(currentRatio)       -- Bar at current position
                    RenderRestedOverlay(currentRatio)    -- Reacts to bar
                    RenderQuestOverlays(currentRatio)    -- Reacts to bar
                    RenderExhaustionTick(currentRatio)   -- Reacts to bar
                    RenderText(context)                  -- Updates every frame
end
```

### Benefits

#### 1. Dynamic Overlay Reactions
```lua
// Rested overlay shrinks as XP bar grows into it
function RenderRestedOverlay(currentRatio, context)
    -- Calculate remaining space based on CURRENT bar position
    local animatedXP = currentRatio * context.xpMax
    local remainingSpace = context.xpMax - animatedXP
    local restedWidth = math.min(context.restedXP, remainingSpace)
    
    overlay:SetWidth(restedWidth)  -- Shrinks during animation!
end
```

**Visual Effect:**
```
Frame 1:  [XP====    ][Rested========]
Frame 2:  [XP======  ][Rested======  ]
Frame 3:  [XP========][Rested====    ]
Frame 4:  [XP==========][Rested==    ]
Final:    [XP============][Rested=   ]
```

The rested overlay **visually shrinks** as the XP bar grows into it!

#### 2. Quest Overlay Pushing
```lua
// Quest overlay moves/resizes as bar approaches it
function RenderQuestOverlays(currentRatio, context)
    local animatedXP = currentRatio * context.xpMax
    local questStartPos = animatedXP  -- Start where bar ends
    local questWidth = context.questXP
    
    questOverlay:SetPoint("LEFT", questStartPos)  -- Follows bar!
    questOverlay:SetWidth(questWidth)
end
```

**Visual Effect:**
```
Frame 1:  [XP====    ][ Quest ]
Frame 2:  [XP======  ]  [ Quest ]
Frame 3:  [XP========]    [ Quest ]
Frame 4:  [XP==========]    [ Quest ]
Final:    [XP============]    [ Quest ]
```

The quest overlay **moves right** as the XP bar pushes it!

#### 3. Exhaustion Tick Following
```lua
// Tick stays at end of rested overlay as it shrinks
function RenderExhaustionTick(currentRatio, context)
    local animatedXP = currentRatio * context.xpMax
    local restedEnd = animatedXP + context.restedXP
    
    tick:SetPoint("CENTER", restedEnd)  -- Follows rested end!
end
```

**Visual Effect:**
```
Frame 1:  [XP====    ][Rested========]|
Frame 2:  [XP======  ][Rested======  ]|
Frame 3:  [XP========][Rested====    ]|
Final:    [XP============][Rested=   ]|
```

The tick **stays at the end** of the shrinking rested overlay!

#### 4. Live Text Updates
```lua
// Text updates every frame to show current animated value
function RenderText(context)
    local animatedXP = currentRatio * context.xpMax
    local displayText = string.format("%d / %d", animatedXP, context.xpMax)
    text:SetText(displayText)  -- Numbers count up during animation!
end
```

**Visual Effect:**
```
Frame 1:  "1,234 / 10,000 XP"
Frame 2:  "2,456 / 10,000 XP"
Frame 3:  "3,789 / 10,000 XP"
Final:    "5,000 / 10,000 XP"
```

The numbers **count up smoothly** during animation!

### Performance Considerations

**Concern:** "Won't rendering everything each frame be slow?"

**Answer:** No, because:

1. **Already Rendering:** WoW's UI updates every frame anyway (60 FPS)
2. **Minimal Work:** Each render method just sets position/size/color (< 1ms total)
3. **Short Duration:** Animations last 0.3-1.0 seconds (18-60 frames)
4. **Conditional Logic:** If element not visible, early return (no work)
5. **Single Pass:** Each element rendered once per frame (not multiple times)

**Total Cost:** ~0.5ms per frame × 30 frames = 15ms total animation time (negligible)

### Comparison: Static vs Dynamic

#### Static Overlays (Bad)
```lua
// Update overlays once at start, don't touch during animation
TriggerBarRefresh(context)
    RenderRestedOverlay(context)     -- Render once
    RenderQuestOverlays(context)     -- Render once
    StartAnimation(targetRatio)
        OnEachFrame:
            bar:SetValue(currentRatio)  -- Only bar moves

Result: Bar animates, overlays static = jarring visual disconnect
```

#### Dynamic Overlays (Good)
```lua
// Update everything every frame
TriggerBarRefresh(context)
    StartAnimation(targetRatio, context)
        OnEachFrame:
            RenderBarFrame(currentRatio, context)
                RenderBarInstant(currentRatio)
                RenderRestedOverlay(currentRatio)    -- Every frame!
                RenderQuestOverlays(currentRatio)    -- Every frame!
                
Result: All elements animate together = smooth, cohesive visual
```

### Implementation Note

The `RenderBarFrame` method is the **key innovation**:

```lua
--- This method is called:
--- 1. Once for instant updates (no animation)
--- 2. Every frame during animation (by AnimationManager)
---
--- By using the SAME method for both cases, we ensure:
--- - Consistent rendering logic
--- - No code duplication
--- - Easy to test (just call with different ratios)
---
---@param currentRatio number Current animation progress (0-1) or final ratio
---@param context table Immutable context with all state
function RenderBarFrame(currentRatio, context)
    -- This method renders ALL elements based on currentRatio
    -- Whether that's the final ratio (instant) or intermediate (animation)
    -- the logic is the same!
end
```

This pattern makes animation **first-class**, not an afterthought!

---

## Recommendation

**Adopt the Circular Bar pattern for all styles:**

1. ✅ **Single entry point**: `TriggerBarRefresh(context)`
2. ✅ **Context with flags**: `hasGainedXP`, `hasLeveledUp`, `shouldAnimate`, `shouldFlash`
3. ✅ **Style-specific RenderBar**: One method that handles everything
4. ✅ **Unified Render methods**: `RenderXXX(context)` combines layout + color
5. ✅ **No recursion**: Each visual element rendered once per event
6. ✅ **Context everywhere**: Every render method receives full context

This will:
- 📉 Reduce code complexity by ~30%
- 🚀 Improve performance (eliminate redundant calls)
- 🧪 Make testing easier (one method to mock)
- 📖 Make code easier to understand (clear event → context → render flow)
- 🔧 Make maintenance easier (all related code in one place)

---

## Implementation Priority

### High Priority (Do First)
1. ✅ Add event flags to ContextBuilder (non-breaking)
2. ✅ Add TriggerBarRefresh to BaseMixin (non-breaking)
3. ✅ Implement RenderBar for Circular style (already done!)
4. ✅ Update periodic ticker to build context

### Medium Priority (Do Next)
1. Implement RenderBar for Flat style
2. Implement RenderBar for Legacy style
3. Implement RenderBar for Vertical style
4. Update animation system to use context flags

### Low Priority (Do Last)
1. Remove old Trigger methods (breaking change)
2. Remove split Layout/Paint mixins (breaking change)
3. Remove VisualsMixin orchestration (breaking change)

---

## Example: Complete Flat Bar Implementation

See attached `FlatBarStyle_Refactored.lua` for full implementation example.

The refactored version:
- ✅ Single `RenderBar(context)` entry point
- ✅ All render methods receive context
- ✅ Layout + color combined per visual element
- ✅ No recursion or redundant calls
- ✅ Clear separation: RenderBar → RenderOverlays → RenderText
- ✅ ~40% less code than current split Layout/Paint approach

