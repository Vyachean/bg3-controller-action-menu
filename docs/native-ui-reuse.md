# Native UI reuse

## Principle

CAM does not reimplement Baldur's Gate 3 gameplay semantics. The self-contained controller library composes the smallest current Patch 8 contracts needed to present native executable slots in a controller grid.

The consumed Xbox App `1.8.910.0` evidence is pinned in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

## Execution type boundary

Current `HotBarSlotStyle` establishes the important boundary:

```text
VMHotBarSlot
  Content -> VMCharacterAction / VMUpcast / VMItem / VMPassive
  execution parameter -> VMHotBarSlot
```

Therefore CAM's executable main cells come only from native hotbar-slot collections:

- `CurrentShownDeck.SlotList`;
- `CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList`;
- `SingleHotBar.SlotList`.

Raw radial-assignment `SpellsAndActions`, inventory slots and passive objects are not gameplay-dispatch candidates.

## HotBar filter semantics

The current keyboard `HotBar.xaml` capture proves the model/commands used by CAM:

- `SetCurrentShownDeckCommand("CommonHotBar")`;
- `SetCurrentShownDeckCommand("ClassHotBar")`;
- `SetCurrentShownDeckCommand("ItemHotBar")`;
- `FilterCantripsCommand` with the captured current parameter;
- `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- `FilterActionResourceCommand`;
- `ClearSingleHotbarCommand`.

The tabs are semantic filters, not independent source catalogs. CAM does not classify actions by names, icons, spell levels or custom resource rules.

## Controller focus and dispatch

The current native radial lifecycle uses the focused item's **DataContext**.

```text
CAM_FilteredSlotList.LocalFocus.DataContext
        |
        +--> ActionRadials.Tag
        +--> CreateFocusedTooltipDataCommand(slot)
        +--> HighlightResourcesCommand(slot)
        |
        v
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

The capture proves the native sequence:

1. on `LocalFocusChanged`, clear the previous tag/tooltip/resource highlight and play the hover sound;
2. after the native 70 ms delay, write `LocalFocus.DataContext` into `ActionRadials.Tag`;
3. create focused tooltip data and highlight resources for that same native slot.

The older development fixture's `LocalFocus.Tag` handoff is rejected.

The item container may still expose `Tag="{Binding .}"` as ordinary presentation metadata, but the current gameplay-facing focus lifecycle does not depend on it.

## Navigation reuse

The current assignment UI proves the controller hierarchy:

```text
outer LSListBox
  LocalFocusSelector
  DirectionalNavigation = Contained
  ActionNextEvent = UIDown
  ActionPrevEvent = UIUp
        |
        +-- child LSListBox
              DirectionalNavigation = Continue
              |
              v
            LSGrid
              UIUp / UIDown / UILeft / UIRight
```

The fresh `1.8.910.0` `SelectorAssign` element has no fixed width, height or margin. CAM reproduces that current selector contract instead of retaining the stale synthetic `118x118` geometry.

One outer list owns scrolling/vertical continuation. Resource and action grids remain children of that navigation shell.

## Native nested state and B

`SingleHotBar.SlotList` remains BG3-owned for container, variant and upcast state.

A remains:

```text
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

B remains the native command lifecycle:

- default: `ClearSingleHotbarCommand`;
- top level: native `CustomEvent("CloseWidget")` condition;
- swap state: native `UseSlotCommand(null)` behavior.

CAM does not implement separate cancel semantics.

## Resource filters

Resource filter cells are the current native `VMActionResourceCostPreview` objects from `ActionResourcesCostPreview`.

The project-owned renderer uses the captured model shape (`ActionResource`, `MaxValue`, `Value`, `Cost`) and sends the focused preview object to `FilterActionResourceCommand`.

Resource membership and action costs remain BG3-owned.

## Button hints and customization

The project-owned template retains the captured right-stacked `ButtonHintsContainer` composition and native input glyph/content resources.

Radial editing is outside CAM. `ShowContextMenu` is hidden/inert and assign/swap/clear/add/remove radial mutation commands are absent from the project-owned runtime.

## Resource ownership

CAM references already-loaded native styles/templates such as slot visuals, selector chrome, input hints and action-resource rendering. It does not copy the full Larian controller dictionary or any `Public/Game/GUI` resource into the mod.

If a future Patch changes one of these dependencies, the developer capture is refreshed and the project-owned contract is reviewed before release. Installation never derives a replacement from the user's local game.
