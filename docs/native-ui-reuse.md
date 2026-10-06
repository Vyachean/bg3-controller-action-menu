# Native UI reuse

## 0.0.37 native hotbar-filter composition

0.0.36 proved that the radial **assignment catalog** is a useful navigation reference but the wrong gameplay-dispatch model.

Current Patch 8 `HotBarSlotStyle` establishes the important type boundary:

```text
VMHotBarSlot
  Content -> VMCharacterAction / VMUpcast / VMItem / VMPassive
  CommandParameter -> VMHotBarSlot
```

CAM therefore uses native hotbar slot collections for executable cells and no longer sends raw `SpellsAndActions`, inventory or passive assignment objects to `UseSlotCommand`.

## Principle

The mod should not imitate Baldur's Gate 3 UI or gameplay semantics when an equivalent native controller/keyboard hotbar contract already exists.

CAM owns only thin composition:

- which proven native type/resource filters are presented;
- grid columns/spacing;
- the one-outer-list controller navigation shell;
- a project-owned equivalent of the proven radial focus handoff from the focused grid slot into BG3-owned commands.

BG3 owns:

- slot membership and ordering;
- resource/type filter semantics;
- slot visuals and action state;
- resource cost preview;
- tooltip data;
- `UseSlotCommand`;
- container/variant/upcast lifecycle.

## Two native contracts are composed

### Keyboard HotBar.xaml: filter semantics

The current `Mods/MainUI/GUI/Pages/HotBar.xaml` is development evidence, not an installer input.

A fresh developer capture is used when the contract must be checked. The self-contained runtime then records only the project-owned bindings needed to call the proven BG3 model:

- `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- `FilterActionResourceCommand`;
- `FilterCantripsCommand`;
- `SetCurrentShownDeckCommand`;
- `ClearSingleHotbarCommand`;
- `CurrentShownDeck`;
- `SingleHotBar.SlotList`;
- Common/Class/Item deck identifiers;
- `CurrentPlayer.SelectedCharacter.PassivesHotBar`.

Any concrete filter parameter that cannot be proven stable from current evidence remains a development blocker rather than being discovered dynamically on the tester's machine.

### Controller radial: focus/dispatch semantics

Captured current `PreloadedActionRadials_c.xaml` evidence remains authoritative for:

- `ActionRadialWidgetTemplate_P8`;
- exact `SelectorAssign` geometry;
- page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- native B/`ClearSingleHotbarCommand` lifecycle;
- `SingleHotBar.SlotList`;
- `HotBarRadial.LocalFocusChanged` behavior.

The self-contained controller resource must reproduce the proven main-radial `LocalFocusChanged` handoff for `CAM_FilteredSlotList`. The required BG3-owned actions are:

- writing `LocalFocus.Tag` to `ActionRadials.Tag`;
- `CreateFocusedTooltipDataCommand`;
- `HighlightResourcesCommand`;
- native controller hover feedback.

The PageView-specific radial tooltip-display call is omitted because the grid is not a radial PageView. Tooltip data itself remains native.

## Navigation reuse

The installed radial assignment UI proves the controller hierarchy:

```text
outer LSListBox
  LocalFocusSelector
  DirectionalNavigation = Contained
  scroll viewer
      |
      +-- child LSListBox
             DirectionalNavigation = Continue
             LSGrid(UIUp/UIDown/UILeft/UIRight)
```

0.0.36 split sources into independent focus roots and runtime showed navigation could break after reaching lower rows. 0.0.37 returns to one outer navigation/scroll owner and removes the fixed three-row action-grid height.

The self-contained selector must be authored from the captured current `SelectorAssign` contract and verified against that evidence; normal installation does not clone anything from the game.

## Action cells

The grid item container binds:

```xaml
Tag="{Binding .}"
```

where the data item is the native `VMHotBarSlot`. This is required because the native radial focus lifecycle reads `LocalFocus.Tag`.

The visible cell continues to use BG3-owned slot/icon resources. CAM does not define gameplay execution logic.

## Type and resource filters

LB/RB type filters use the currently proven native commands/decks:

- Common;
- current class;
- Items;
- Passives;
- Cantrips.

Resource filter cells are native `VMActionResourceCostPreview` entries from `ActionResourcesCostPreview`. Focus invokes `FilterActionResourceCommand` with the native object.

CAM does not classify actions by resource names, action names, spell levels or icons.

## Button hints

The self-contained template preserves the captured native `ButtonHintsContainer` behavior/layout contract. CAM does not replace it with a horizontal wrap panel and does not add separate LB/RB hint presenters.

Only radial customization is removed:

- `ShowContextMenu`;
- assign;
- swap;
- clear;
- add/remove radial.

## Why not copy the entire SpellBook page

The Spell Book remains design precedent for dense controller filtering, but it contains preparation/class-navigation state unrelated to combat action execution.

CAM instead composes the smallest current BG3-owned contracts needed for combat selection: keyboard hotbar filters, controller radial focus/dispatch, and native hotbar slot VMs.

Any future custom action classifier, resource calculator, execution command, focus frame or tooltip renderer should be treated as an architecture regression unless current native resources are proven insufficient.
