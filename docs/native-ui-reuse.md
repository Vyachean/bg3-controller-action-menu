# Native UI reuse

## Principle

The mod should not imitate Baldur's Gate 3 UI when an equivalent native controller resource already exists.

The combat page owns only composition:

- which native action collections are shown;
- their order;
- the number of grid columns;
- the transition between the main list and `SingleHotBar` variants.

BG3 owns cell rendering, action state, tooltips, focus visuals and dispatch.

## Native Patch 8 resources used

The page imports game-owned resource dictionaries:

- `GustavNoesisGUI/Library/DataTemplates.xaml`;
- `GustavNoesisGUI/Library/FocusableControls_c.xaml`;
- `MainUI/Library/Tooltips.xaml`.

The following native resources are consumed directly:

- `HotBarSlotStyle`;
- `ExpanderButtonTemplateSpellBook`;
- `LS_InventoryGridSurround`;
- native font/color resources;
- native controller button hints.

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

## Group layout

Groups use BG3's controller Spell Book expander chrome:

`ExpanderButtonTemplateSpellBook`

and the same inventory-grid surround resource.

The remaining custom grid only decides the spatial arrangement (currently six columns) and binds controller directional events.

## Why not copy the entire SpellBook page

The Spell Book page contains preparation, class navigation, learning-spell controls and other non-combat state. Replacing Action Radials with the whole page would couple combat selection to unrelated logic.

Instead, the mod reuses the smallest native pieces needed for combat while leaving gameplay state in `DCHotBar`.

## Current custom visual surface

Intentional custom surface should remain limited to:

- page width/height;
- section ordering;
- grid column count and spacing;
- main-vs-variant visibility.

If a future change introduces a custom action icon frame, focus frame, disabled overlay or tooltip renderer, it should be treated as an architecture regression unless the native resource cannot satisfy the requirement.
