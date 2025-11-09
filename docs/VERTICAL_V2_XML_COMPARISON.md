# Vertical Bar XML Comparison: V1 vs V2

## Key Differences

### Structure Approach

**V1 (Old Architecture):**
- Two-level hierarchy: Container → Bar
- Container has `VerticalXPBarContainerMixin`
- Bar has `VerticalXPBarMixin`
- Explicit `<Scripts>` section declaring all event handlers
- Bar creates textures programmatically in Lua

**V2 (New Architecture):**
- Single-level template (no container/bar split)
- One mixin: `VerticalBarXPBarMixin`
- No `<Scripts>` section (handled by BaseMixin)
- All textures declared in XML (declarative approach)

### Detailed Comparison

#### Template Declaration

```xml
<!-- V1 -->
<Frame name="VerticalXPBarTemplate" mixin="VerticalXPBarMixin" virtual="true">
    <Scripts>
        <OnLoad method="OnLoad"/>
        <OnEvent method="OnEvent"/>
        <OnEnter method="OnEnter"/>
        <OnLeave method="OnLeave"/>
        <OnMouseDown method="OnMouseDown"/>
        <OnMouseUp method="OnMouseUp"/>
        <OnShow method="OnShow"/>
    </Scripts>
</Frame>

<!-- V2 -->
<Frame name="VerticalBarTemplate_v2" virtual="true" mixin="VerticalBarXPBarMixin">
    <!-- No Scripts section - BaseMixin handles this -->
</Frame>
```

#### Texture Creation

**V1:** All textures created programmatically in `VerticalXPBarMixin:SetupTextures()`
```lua
-- In Lua code
if not self.FilledTexture then
    self.FilledTexture = self:CreateTexture(nil, "ARTWORK")
end
```

**V2:** All textures declared in XML
```xml
<!-- In XML -->
<Texture parentKey="FilledTexture" file="Interface\Buttons\WHITE8X8">
    <Size x="60" y="0"/>
    <Anchors>
        <Anchor point="BOTTOMLEFT" x="0" y="0"/>
        <Anchor point="BOTTOMRIGHT" x="0" y="0"/>
    </Anchors>
</Texture>
```

#### Text Elements

**V1:** Text created programmatically
```lua
if not self.LevelText then
    self.LevelText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end
```

**V2:** Text declared in XML within `OverlayFrameTextContainer`
```xml
<Frame parentKey="OverlayFrameTextContainer">
    <Layers>
        <FontString parentKey="LevelText" inherits="GameFontNormal">
```

### V2 Benefits

1. **Declarative Structure:** Visual hierarchy clear in XML
2. **No Duplicate Code:** BaseMixin handles all common events
3. **Easier Debugging:** Can see all UI elements in XML
4. **Standard Pattern:** Matches flat bar and legacy bar V2

### Potential Issues Identified

#### ✅ Correct in V2:
- Mixin name: `VerticalBarXPBarMixin` (created by StyleBuilder)
- No Scripts section (BaseMixin provides OnLoad, OnShow, etc.)
- All textures declared in XML
- Text containers properly structured

#### ⚠️ Potential Issue:
The V2 template doesn't have explicit `<Scripts>` handlers, which is correct for V2 architecture. However, the mixin MUST be properly composed with BaseMixin for this to work.

### Verification Checklist

- [x] Mixin name matches: `VerticalBarXPBarMixin`
- [x] StyleBuilder creates mixin: `XPBarStyleBuilder:Create(XPBarMixinBase_v2, VerticalBarStyleTemplate, DefaultConfig)`
- [x] StyleBuilder registers: `XPBarStyleBuilder:RegisterStyle("vertical", VerticalBarXPBarMixin)`
- [x] All required textures in XML: FilledTexture, FallingTexture, RestedOverlay, Quest overlays, GainFlash
- [x] Text containers: OverlayFrameTextContainer, BelowBarTextContainer
- [x] OnLoad override calls parent: `XPBarMixinBase_v2.OnLoad(self)`

### V2 Template Structure Summary

```
VerticalBarTemplate_v2 (Frame)
├── Layers
│   ├── BACKGROUND-1: Background
│   ├── ARTWORK-1: FilledTexture (current XP)
│   ├── ARTWORK-2: RestedOverlay
│   ├── ARTWORK-3: QuestOverlayComplete
│   ├── ARTWORK-3: QuestOverlayIncomplete
│   ├── ARTWORK-4: FallingTexture (animated)
│   └── OVERLAY-5: GainFlash
└── Frames
    ├── OverlayFrameTextContainer (MEDIUM strata)
    │   └── LevelText, PercentText, XPPerHourText
    └── BelowBarTextContainer (MEDIUM strata)
        └── RateText, SessionText, QuestSummaryText, XPText
```

### V1 vs V2 Architecture Flow

**V1 OnLoad Flow:**
1. XML declares `<OnLoad method="OnLoad"/>`
2. WoW calls `VerticalXPBarMixin:OnLoad()`
3. Mixin manually calls `self:InitializeState()`
4. Mixin manually calls `self:SetupTextures()`
5. Mixin manually registers events

**V2 OnLoad Flow:**
1. XML declares mixin (no Scripts needed)
2. StyleBuilder composes: BaseMixin + VerticalBarStyleTemplate
3. When frame created, WoW automatically calls `OnLoad` (from BaseMixin)
4. `VerticalBarStyleTemplate:OnLoad()` calls `XPBarMixinBase_v2.OnLoad(self)` first
5. Parent's OnLoad handles: config init, animation init, position init, event registration, observer pattern
6. Child's OnLoad adds: gravity state, particle pool, custom OnUpdate

### Conclusion

The V2 XML is **correct** and follows the proper V2 architecture pattern. The differences from V1 are intentional improvements:

1. ✅ No `<Scripts>` section (BaseMixin handles this)
2. ✅ Declarative textures in XML (not programmatic)
3. ✅ Single mixin instead of container+bar split
4. ✅ Cleaner, more maintainable structure

The issue you encountered was not the XML, but the OnLoad implementation trying to call non-existent `BaseOnLoad` method, which has now been fixed.
