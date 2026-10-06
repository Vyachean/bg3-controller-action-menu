# Architecture

## Objective

Replace Baldur's Gate 3 controller radial browsing with a controller-native action grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

The shipping artifact is one self-contained ordinary BG3 `.pak`, with no Script Extender, DLL/native loader, or install-time game-file derivation.

## Runtime composition

```text
native ActionRadials state/page
          |
          v
project-owned ActionRadialWidgetTemplate_P8
          |
          +-- semantic filters
          |     SetCurrentShownDeckCommand
          |     FilterCantripsCommand
          |     FilterActionResourceCommand
          |             |
          |             v
          |     native VMHotBarSlot collections
          |       CurrentShownDeck.SlotList
          |       CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList
          |       SingleHotBar.SlotList
          |
          +-- assignment-style controller navigation
          |     outer LSListBox + LocalFocusSelector
          |     child LSListBox + LSGrid
          |
          +-- native radial focus lifecycle
                LocalFocus.DataContext
                     |
                     +--> ActionRadials.Tag
                     +--> CreateFocusedTooltipDataCommand
                     +--> HighlightResourcesCommand
                     |
                     v
                UIAccept -> UseSlotCommand(slot)
```

## Evidence boundary

The current contract is based on the captured Xbox App game package `1.8.910.0`. Source hashes and the exact consumed seams are pinned in:

`docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

Important current facts:

- page/state: `ActionRadials`;
- context: `HotBar`;
- controller resource key: `ActionRadialWidgetTemplate_P8`;
- executable cells are native `VMHotBarSlot` objects;
- main filter sources are `CurrentShownDeck.SlotList` and `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList`;
- nested/filter/container/upcast state remains `SingleHotBar.SlotList`;
- current focus handoff uses `LocalFocus.DataContext` after the native 70 ms delay;
- A uses `UseSlotCommand(ActionRadials.Tag)`;
- B remains the native `ClearSingleHotbarCommand` / top-level close lifecycle;
- the current assignment selector has no fixed width/height/margin.

Historical public dumps and older synthetic fixtures may be useful context, but they are not allowed to override this current captured evidence.

## Why raw assignment catalogs are rejected

0.0.35/0.0.36 proved that radial assignment collections are useful evidence for navigation but are the wrong execution data model.

`VMCharacterAction`, inventory and passive objects may be rendered as content or offered by assignment UI, but the proven execution parameter is the surrounding native `VMHotBarSlot`.

Therefore the main gameplay path must not use:

- `PlayerCharacterProperties.SpellsAndActions`;
- `Inventory.Slots`;
- raw passive collections;
- user-configured `ControllerHotBars` as the automatic CAM catalog.

The assignment UI contributes its controller focus/navigation pattern only.

## Semantic filters

LB/RB selects native semantic filters:

| CAM filter | Native contract |
| --- | --- |
| Common | `SetCurrentShownDeckCommand("CommonHotBar")` -> `CurrentShownDeck.SlotList` |
| Class | `SetCurrentShownDeckCommand("ClassHotBar")` -> `CurrentShownDeck.SlotList` |
| Items | `SetCurrentShownDeckCommand("ItemHotBar")` -> `CurrentShownDeck.SlotList` |
| Passives | `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList` |
| Cantrips | captured current `FilterCantripsCommand` contract |

Resource filters use `CurrentPlayer.UIData.ActionResourcesCostPreview` and `FilterActionResourceCommand`.

CAM does not calculate resource membership or create a parallel action taxonomy.

## Controller navigation

The proven hierarchy is:

```text
HotBarList: LSListBox
  DirectionalNavigation = Contained
  LocalFocusSelector = CAM_MainSelector
  ActionNextEvent = UIDown
  ActionPrevEvent = UIUp
        |
        +-- resource LSListBox
        |     DirectionalNavigation = Continue
        |     ItemsPanel = LSGrid(UI directions)
        |
        +-- action LSListBox
              DirectionalNavigation = Continue
              ItemsPanel = LSGrid(UI directions)
```

The outer list owns scrolling/vertical continuation. Child grids own cell movement. There is no fixed three-row action-grid height.

The fresh Patch 8 `SelectorAssign` contract is reproduced without the stale synthetic `118x118` selector geometry.

## Focus, tooltip and resource preview

On action-cell focus change the project-owned template follows the current radial lifecycle:

- clear stale `ActionRadials.Tag`;
- clear tooltip/resource-highlight input;
- play native hover feedback;
- after 70 ms, write the current `LocalFocus.DataContext` (`VMHotBarSlot`) to `ActionRadials.Tag`;
- call `CreateFocusedTooltipDataCommand(slot)`;
- call `HighlightResourcesCommand(slot)`.

CAM does not calculate tooltip or resource-cost semantics itself.

## Nested state and dispatch

`SingleHotBar.SlotList` remains BG3-owned. CAM presents the native nested slot collection in a controller grid but does not decide variant/upcast/container membership.

A is the native `UIAccept -> UseSlotCommand(ActionRadials.Tag)` path.

B remains native:

- `ClearSingleHotbarCommand` by default;
- top-level close through the captured `CustomEvent("CloseWidget")` conditions;
- native swap-state cancellation.

## Button hints and radial customization

The captured native `ButtonHintsContainer` right-side layout is retained. CAM does not add duplicate custom LB/RB glyph presenters.

Radial customization is deliberately unavailable. `ShowContextMenu` is hidden/inert and radial assign/swap/clear/add/remove commands are absent.

## Self-contained package boundary

Runtime source is:

`BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.

The mod PAK must not contain copied game-owned `Public/Game/GUI` resources.

Normal installation:

```text
VBS (temporary development launcher)
  -> bootstrap-latest.ps1
  -> release install-latest.ps1
  -> download prebuilt PAK
  -> install-xbox-dev.ps1
  -> copy PAK + update modsettings.lsx
```

It does not read `Game.pak`, use LSLib, generate XAML or repack a PAK.

Developer capture is a separate read-only evidence workflow and never a runtime/install dependency.

## Primary compatibility target

Primary package:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC;
- no Script Extender;
- no native loader/DLL.

Other UI mods that override the same controller resource key may conflict by load order. CAM does not attempt install-time merging or derivation to work around such conflicts.

## Proof boundary

CI can prove:

- current captured seams are represented in project-owned XAML;
- obsolete raw assignment/source-tab paths are absent;
- XAML parses;
- installer is direct/self-contained;
- built PAK contains the project-owned runtime byte-for-byte;
- copied `Public/Game` XAML, Script Extender and native executable payloads are absent.

CI cannot prove BG3 runtime focus/resource/template resolution. After green package proof, one combined milestone game run is required rather than a sequence of speculative micro-tests.
