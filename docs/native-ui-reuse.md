# Native UI reuse

## 0.0.37 hotbar-slot filter composition

0.0.36 proves the assignment screen is the wrong top-level execution source even when its focus geometry is copied correctly.

CAM now reuses two current installed-game contracts for different purposes:

- `PreloadedActionRadials_c.xaml` — controller lifecycle, A/B bindings, selector/focus primitives and `SingleHotBar` second stage;
- `HotBar.xaml` — DCHotBar deck/resource filter semantics and the VMHotBarSlot execution model.

Current Patch 8 `HotBarSlotStyle` confirms that the slot wrapper is the command/resource-preview parameter and its `Content` owns the visible action/item/passive representation.

The top-level surface therefore has one flat slot grid. It does not copy `AvailableSlotContainer`, `SpellGroupListTemplate`, `InventoryGrid` or other assignment-catalog presentation resources anymore.

The deck/type filter set is Common / current Class / Items / Passives. `Custom` remains excluded. Resource/action filter semantics are accepted only from the current installed DCHotBar contract; CAM does not classify by names, slot type or spell level.

Controller button hints are also native-owned. CAM keeps the installed `ButtonHintsContainer` layout untouched and only disables the radial-customization entry points.

## Principle

The mod should not imitate Baldur's Gate 3 UI when an equivalent native controller resource already exists.

The combat page owns only composition:

- which **automatic native action collections** are shown;
- their order;
- the number of grid columns;
- the transition between the main catalog and `SingleHotBar` variants.

The main menu deliberately does **not** use `ControllerHotBars[*].SlotList`; radial membership is user customization state, not the source of truth for CAM.

BG3 owns cell rendering, action state, tooltips, focus visuals and dispatch.

## Native Patch 8 resources used

The page imports game-owned resource dictionaries:

- `GustavNoesisGUI/Library/DataTemplates.xaml`;
- `GustavNoesisGUI/Library/FocusableControls_c.xaml`;
- `MainUI/Library/Tooltips.xaml`.

The main catalog derives exact current resources from the installed radial-assignment UI:

- `AvailableSlotContainer`;
- `AvailableSlotsListPanelTemplate`;
- `SpellGroupListTemplate`;
- `InventoryCellTemplate`;
- `InventoryGrid`;
- the exact assignment-screen `SelectorAssign` control geometry (cloned locally per tab, still using its native template);
- native font/color/tooltip resources.

Nested `SingleHotBar` cells continue to reuse the existing native slot visuals.

## Action cells

`HotBarSlotStyle` is the same game style that handles:

- `VMCharacterAction`;
- `VMUpcast`;
- `VMItem`;
- `VMPassive`;
- disabled state;
- active state;
- sub-selection indicator;
- resource highlighting;
- native `UseSlotCommand` dispatch.

The mod does not define its own icon frames, disabled overlays, active overlays or action execution logic.

## Automatic catalog sources

The current Patch 8 radial-assignment UI already maintains the lists CAM needs:

- `PlayerCharacterProperties.SpellsAndActions`;
- each group's `Actions`;
- togglable `Stats.Passives`;
- metamagic passives;
- `Inventory.Slots`.

CAM reuses those collections directly. Learning a spell, gaining an action or changing inventory should therefore change the catalog without editing a radial wheel.

The assignment screen contributes only proven controller focus primitives (`SelectorAssign`, `LocalFocusSelector`, directional `LSGrid`). Top-level CAM uses one flat focus domain; nested assignment-group list composition is no longer reused.

## Why not copy the entire SpellBook page

The Spell Book page contains preparation, class navigation, learning-spell controls and other non-combat state. Replacing Action Radials with the whole page would couple combat selection to unrelated logic.

Instead, the mod reuses the smallest native pieces needed for combat while leaving gameplay state in `DCHotBar`.

## Current custom visual surface

Intentional custom surface should remain limited to:

- page width/height;
- section ordering;
- grid column count and spacing;
- main-vs-variant visibility;
- category/group ordering of the automatic catalog.

Radial customization controls are intentionally outside this surface.

If a future change introduces a custom action icon frame, focus frame, disabled overlay or tooltip renderer, it should be treated as an architecture regression unless the native resource cannot satisfy the requirement.
