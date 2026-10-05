# Native UI reuse

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
- `SelectorTemplate`;
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

The grid focus hierarchy is also copied from the same native assignment screen: outer `AssignList` semantics, nested lists, `LocalFocusSelector` and directional `LSGrid`.

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
