# Circular  OnLoad Fix - Executive Summary

## The Problem

Circular  bar doesn't display correctly on initial load (`PLAYER_ENTERING_WORLD`):
- Bar segments show as empty/background color
- No text displays
- Bar only renders correctly after an XP event occurs

## Root Cause

**Early Return Bug in `RenderBar` Method:**

```lua
function CircularBarStyleTemplate:RenderBar(context)
    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        self:SetCurrentRatio(targetRatio)
        self:RenderBarFrame(targetRatio, context)
        return  -- ❌ EARLY EXIT - stops before overlay/text updates!
    end
    
    -- This code is never reached on first load:
    -- - UpdateRestedOverlay()
    -- - UpdateQuestCompleteOverlay()
    -- - UpdateTexts() at RenderBar level
end
```

## What Makes Circular Different

### Circular  (Broken Pattern)
```
RenderBar()
  ├─ If first load: RenderBarFrame() → RETURN ❌
  └─ [Overlay updates are never reached]
  
RenderBarFrame()
  ├─ SetArcProgress() - uses EMPTY cached overlay data
  └─ UpdateTexts() - called here but overlays not updated
```

### Classic/Vertical  (Working Pattern)
```
RenderBar()
  ├─ Animation decision
  ├─ RenderBarFrame() - sets bar position
  ├─ UpdateRestedOverlay() ✅
  ├─ UpdateQuestCompleteOverlay() ✅
  ├─ UpdateExhaustionTick() ✅
  └─ UpdateTexts() ✅
```

## The Fix

**Remove the early return** and follow the same pattern as Classic/Vertical:

```lua
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- Calculate target ratio
    local curXP = context.xpAfter or context.currentXP or 0
    local maxXP = context.xpMax or 1
    local targetRatio = (maxXP > 0) and (curXP / maxXP) or 0

    -- Initialize current ratio if not set (first update)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
        -- NO EARLY RETURN! Continue to overlay/text updates
    end

    -- ANIMATION DECISION
    if context.shouldAnimate then
        local xpContext = {
            xpBefore = context.xpBefore or context.previousXP or 0,
            xpAfter = context.xpAfter or context.currentXP or 0,
            xpMax = context.xpMax or 1,
            xpGained = context.xpGained or 0,
            restedXP = context.restedXP or 0,
            isResting = context.isResting or false,
            hasRestedXP = context.hasRestedXP or false,
            level = context.level or 1,
            timestamp = GetTime()
        }
        local config = self:GetAnimationConfig()
        self:StartAnimation(targetRatio, xpContext, config)
    else
        self:RenderBarFrame(targetRatio, context)
    end
    
    -- ✅ ALWAYS update overlays (matches Classic/Vertical pattern)
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
    
    -- ✅ ALWAYS update text (matches Classic/Vertical pattern)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end
```

## Secondary Issue: Duplicate OnLoad Call

Circular has custom `OnLoad` that calls `RenderBar` directly:

```lua
function CircularBarStyleTemplate:OnLoad()
    -- ... setup code ...
    
    -- Call base OnLoad
    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)  -- This calls Refresh() → RenderBar()
    end
    
    -- ❌ REMOVE THIS - duplicate call
    if XPBarContextBuilder then
        local context = XPBarContextBuilder.BuildXPChangeContext("PLAYER_ENTERING_WORLD")
        if context and self.RenderBar then
            self:RenderBar(context)  -- Duplicate! Base OnLoad already does this
        end
    end
end
```

**Solution:** Remove the duplicate `RenderBar` call from `OnLoad`. Let base `OnLoad` → `Refresh()` → `TriggerBarRefresh()` → `RenderBar()` handle it.

## Files to Modify

1. **`ui/xpbars/circular/CircularBarStyle.lua`**
   - Fix `RenderBar` method (remove early return, add overlay/text updates)
   - Fix `OnLoad` method (remove duplicate RenderBar call)

## Testing Checklist

After applying fix, verify:
- [ ] Bar displays with correct fill on login/reload
- [ ] Rested overlay shows if player has rested XP
- [ ] Quest overlays show if quests are tracked (if enabled)
- [ ] Text displays correctly (XP, %, level, rate, session)
- [ ] Exhaustion tick displays if player has rested XP
- [ ] Bar animates correctly when gaining XP
- [ ] No errors in `/console scriptErrors 1`

## Impact

- **Low risk:** Changes align circular bar with established Classic/Vertical pattern
- **High value:** Fixes critical UX issue where bar appears broken on load
- **No breaking changes:** Same behavior, just working correctly from start
