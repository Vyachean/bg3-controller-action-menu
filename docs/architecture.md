# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The main grid is not a presentation of user-configured controller radial slots and is no longer built from raw radial-assignment catalog objects.

```text
native ActionRadials state/page
          |
          v
project-owned ActionRadialWidgetTemplate_P8 override
          |
          +-- type/resource filters proven from current HotBar contract
          |     |
          |     +-- SetCurrentShownDeckCommand
          |     +-- FilterActionResourceCommand
          |     +-- FilterCantripsCommand
          |     |
          |     v
          |  native VMHotBarSlot collections
          |     +-- CurrentShownDeck.SlotList
          |     +-- PassivesHotBar.SlotList
          |     +-- SingleHotBar.SlotList
          |
          +-- focus lifecycle from installed controller radial
                |
                +-- LocalFocus.Tag -> ActionRadials.Tag
                +-- CreateFocusedTooltipDataCommand
                +-- HighlightResourcesCommand
                |
                v
          UIAccept -> UseSlotCommand(slot)
```

### Why 0.0.35/0.0.36 were wrong

The assignment screen is valid evidence for **controller navigation**, but its catalog objects are not the same contract as hotbar execution slots.

Current Patch 8 `HotBarSlotStyle` has `VMHotBarSlot` as its button data context. Its local DataTemplates render `VMCharacterAction`, `VMUpcast`, `VMItem` and `VMPassive` as the slot's content. The style's command parameter is the slot object itself.

Therefore the previous inference:

```text
SpellsAndActions item -> UseSlotCommand
```

is rejected. Runtime 0.0.36 confirms the consequence: A and container opening remain dead even though the actions render.

The current execution rule is:

```text
native VMHotBarSlot
      |
      v
ActionRadials.Tag
      |
      v
UseSlotCommand(slot)
```

### Filter model

Tabs now behave like filters rather than source pages. LB/RB selects a native type/deck filter:

| Filter | Native source/command |
| --- | --- |
| Common | `SetCurrentShownDeckCommand("CommonHotBar")` -> `CurrentShownDeck.SlotList` |
| Class | `SetCurrentShownDeckCommand("ClassHotBar")` -> `CurrentShownDeck.SlotList` |
| Items | `SetCurrentShownDeckCommand("ItemHotBar")` -> `CurrentShownDeck.SlotList` |
| Passives | `CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList` |
| Cantrips | current proven `FilterCantripsCommand` contract |

Resource filters are populated from `CurrentPlayer.UIData.ActionResourcesCostPreview` and invoke the current proven `FilterActionResourceCommand` contract with the native resource-preview VM.

Those command/property names are development evidence, not installer-discovered configuration. Fresh game captures are used when the contract must be re-verified; the release XAML then records the proven contract explicitly and is packaged by CI.

This keeps BG3 responsible for action membership, resource membership, ordering and filtering semantics without making installation a build step.

### Navigation model

Runtime 0.0.36 proved that splitting the surface into independent focus roots still breaks long-grid traversal. The current assignment screen already shows the correct composition:

```text
one outer scrollable LSListBox
  LocalFocusSelector -> exact SelectorAssign clone
  DirectionalNavigation = Contained
        |
        +-- resource filter LSListBox
        |     DirectionalNavigation = Continue
        |     LSGrid
        |
        +-- action slot LSListBox
              DirectionalNavigation = Continue
              LSGrid
```

The outer list owns vertical continuation and scrolling. The inner grids own four-way cell movement. The old fixed action-grid height is removed.

### Focus, dispatch and resource preview

Captured current controller-radial evidence remains authoritative for the focus lifecycle. The self-contained CAM template reproduces the proven `HotBarRadial.LocalFocusChanged` handoff for the main slot grid. That lifecycle feeds the focused slot through:

- `ActionRadials.Tag`;
- `CreateFocusedTooltipDataCommand`;
- `HighlightResourcesCommand`;
- native controller hover feedback.

This restores the same resource-cost preview path that the radial uses. CAM does not calculate or paint resource costs itself.

`SingleHotBar.SlotList` remains BG3-owned for filtered/nested/upcast/variant/container state.

### Native button hints

The captured `ButtonHintsContainer` layout/behavior contract is preserved rather than re-laid out. CAM removes only the radial-customisation/X entry point and its mutation commands. The extra LB/RB presentation-only hints introduced by 0.0.36 are gone.

Raw captured Larian XAML is not committed or distributed as runtime source. CAM ships project-owned `Lib_Controller.xaml` built from the proven contract and remains Script-Extender/DLL/native-loader free.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

CAM owns:

- the controller presentation of native type/resource filters;
- grid column/spacing composition;
- the one-outer-list controller focus shell;
- local retargeting of already-native focus/resource-preview actions.

BG3 owns:

- which native hotbar slots exist;
- type/resource filter semantics;
- action usability, costs, targeting and cooldowns;
- `UseSlotCommand`;
- `HighlightResourcesCommand` / `ClearResourceHighlightsCommand`;
- `SingleHotBar` filter/variant/upcast/container lifecycle;
- A/B and state-machine transitions;
- button-hint localization/input glyphs.

CAM explicitly does not own radial-wheel customization and does not classify raw spells/items/passives into gameplay categories.

## Native widget contract

Confirmed from the installed Xbox App build 1.8.910.0 capture:

- `Mods/MainUI/GUI/Pages/ActionRadials.xaml` is a thin `HotBar`-context widget using `ActionRadialWidgetTemplate_P8`;
- `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` binds the main list to `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`;
- each controller bar is materialized through `PagedList ItemsSource="{Binding SlotList}"`;
- nested variants/upcasts/containers use `SingleHotBar.SlotList`;
- focus-driven scrolling uses `LSScrollViewer.ScrollToElement <- FocusedElement`;
- normal A dispatch is `UseSlotBinding: UIAccept -> UseSlotCommand(Tag)`;
- default B dispatch is `ClearSingleHotbarCommand`, while a main-menu trigger (`SingleHotBar.SlotList.Count == 0` and not throwing) switches B to `CustomEvent("CloseWidget")`;
- swap-slot mode switches B to `UseSlotCommand(null)`.

The captured normal library and Clairmont override copies agree on those gameplay/control seams; their differences are visual scaling/text sizing only.

The older public `Public/Game/GUI/Widgets/ActionRadials.xaml` is Patch 2 Hotfix 1 from 2023-09-06 and remains historical evidence only.

## Native UI reuse

The current implementation consumes game-owned resources including:

- `DataTemplates.xaml`;
- `FocusableControls_c.xaml`;
- `Tooltips.xaml`;
- `HotBarSlotStyle`;
- `ExpanderButtonTemplateSpellBook`;
- `LS_InventoryGridSurround`.

Action cells should remain native. Recreating focus frames, disabled overlays, item counters, upcast indicators or tooltip rendering is an architecture regression unless a native resource is proven insufficient.

## Controller data

Current evidence now proves both the mode-sensitive storage model and the Patch 8 controller collection exposed to XAML.

Current engine/component evidence:

- `HotbarContainer.Containers` stores arrays of native bars;
- each bar has `Index`, `Controller`, `Elements`, dimensions and name;
- hotbar mutation/event structures explicitly carry `HotBarController` / `IsController`.

Current installed-game UI evidence:

- top-level widget/context: `ActionRadials` / `HotBar`;
- controller root collection: `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`;
- per-bar slots: `SlotList`;
- nested slots: `SingleHotBar.SlotList`;
- nested-state filter: `CurrentSingleHotbarFilter`.

A separate September-2026 production mod still proves `PlayerCharacterProperties.KeyboardHotBars[*].SlotList`. Both keyboard and controller hotbar collections are persisted player layouts. They must remain distinct, and neither is the source for CAM's automatic main catalog. `ControllerHotBars` remains relevant only as the vanilla radial/storage contract; `KeyboardHotBars` must never be substituted for it.

## Native grid focus and action dispatch

The installed Patch 8 assignment UI proves the controller navigation hierarchy, while the installed radial proves the gameplay-facing focus lifecycle.

Navigation:

```text
outer HotBarList
  LocalFocusSelector -> CAM_MainSelector (exact SelectorAssign clone)
  KeyboardNavigation.DirectionalNavigation = Contained
          |
          v
child LSListBox
  KeyboardNavigation.DirectionalNavigation = Continue
          |
          v
LSGrid
  UIUp / UIDown / UILeft / UIRight
```

Dispatch:

```text
CAM_FilteredSlotList.LocalFocus.Tag = VMHotBarSlot
          |
          +--> ActionRadials.Tag
          +--> CreateFocusedTooltipDataCommand(slot)
          +--> HighlightResourcesCommand(slot)
          |
          v
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

The item-container `Tag` binding is therefore not presentation metadata: it is the native slot handoff consumed by the radial lifecycle.

Top-level/nested B remains the native `CancelButton` command switch. No CAM-owned targeting, resource calculation or container-opening command is introduced.

## First-run diagnostics without Script Extender

Because Xbox App cannot rely on Script Extender, the first Xbox candidate exposes a small on-screen diagnostic panel using ordinary XAML bindings.

It shows:

- action-group count;
- hotbar count;
- nested variant count;
- variant/upcast state;
- `AreRadialsOpen`;
- focused element name;
- focused action usability.

This does not replace full runtime introspection, but it makes the first Xbox run useful without introducing a third-party runtime dependency.

## Compatibility

The installed package contains project-owned `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml` inside the published PAK. Its gameplay-facing bindings are gated against captured current-game evidence before release.

Another UI mod overriding the same ActionRadials resource keys can still conflict by load order. Installation does not attempt to resolve or rebuild around that conflict.

Raw captured proprietary XAML is development evidence only and is not shipped as copied game resources.
