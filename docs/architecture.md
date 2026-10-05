# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The main grid is no longer a presentation of configured controller radial slots.

```text
native ActionRadials state/page
          |
          v
locally derived ActionRadialWidgetTemplate_P8
          |
          +-- MAIN: automatic native action catalog
          |     |
          |     +-- SpellsAndActions[*].Actions
          |     +-- togglable Passives
          |     +-- togglable Metamagic
          |     +-- Inventory.Slots (Items)
          |     |
          |     v
          |  AssignList-style LSListBox
          |     + LocalFocusSelector
          |     + nested LSGrid groups
          |
          +-- NESTED: native SingleHotBar.SlotList
                |
                v
          proven assignment-style grid renderer

A / B / targeting / costs / upcast rules remain BG3-owned.
```

The installed Patch 8 `PreloadedActionRadials_c.xaml` already contains the complete automatic source catalog used when the player chooses an action to insert into a radial:

- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.SpellsAndActions`;
- each spell/action group exposes `Actions`;
- `CurrentPlayer.SelectedCharacter.Stats.Passives` filtered with `Data.TogglablePassivePredicate`;
- the same passives collection filtered with `Data.TogglableMetaMagicPassivePredicate`;
- `CurrentPlayer.SelectedCharacter.Inventory.Slots`.

That screen also proves the focus hierarchy CAM needs: `AssignList` + `SelectorAssign`, nested `LSListBox` groups, and `LSGrid(UIUp/UIDown/UILeft/UIRight)`.

The previous 0.0.27–0.0.29 line reused only the **navigation** from that screen while still binding content to `ControllerHotBars[*].SlotList`. Runtime proved the grid mechanics work, but that data source is semantically wrong for CAM: it only shows whatever the user has configured in radial wheels.

The new main catalog therefore reuses both halves of the native assignment screen:

1. its automatic data collections;
2. its controller-focus composition.

On focus change, the selected native candidate is stored in `ActionRadials.Tag`. The existing page-level `UIAccept -> UseSlotCommand(Tag)` remains the execution boundary. This does not add spell/item/passive execution logic to CAM.

There is independent native precedent for `UseSlotCommand` receiving non-radial action objects directly: the game hotbar uses `HotBarSlotStyle`/direct action bindings for fixed actions such as the main attack and direct call-allies entries. The exact current catalog-candidate dispatch still requires one runtime proof and is kept isolated to this single seam.

`SingleHotBar.SlotList` remains unchanged as the native second-stage source for upcast, variants, containers and other nested selections after A.

Radial customization is outside CAM's product boundary. `ShowContextMenu`/X and Assign/Swap/Clear/Add/Remove wheel operations are disabled from the generated grid UI.

No Larian XAML is committed to or distributed by this repository. `Lib_Controller.xaml` is derived locally from the installed game. The shipping runtime remains Script-Extender/DLL/native-loader free.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

CAM owns:

- composition and ordering of the automatic action catalog;
- controller grid layout/focus composition reused from the native assignment UI;
- section presentation for Actions/Spells, Passives/Metamagic and Items;
- transition between the automatic main catalog and BG3's native `SingleHotBar` nested results.

BG3 owns:

- which actions/spells/passives/items exist for the selected character;
- usability/cost/resource/targeting state;
- `UseSlotCommand` execution;
- `ClearSingleHotbarCommand` and nested-state lifecycle;
- upcast/variant/container generation;
- action tooltips and native view models.

CAM explicitly does **not** own radial-wheel customization. The generated UI must not expose `ShowContextMenu`, `RequestAssignSlotCommand`, `AssignSlotCommand`, slot swap/clear, or add/remove radial commands.

The main catalog must not depend on `ControllerHotBars` membership. A newly learned/obtained native action should appear because the corresponding native automatic collection changed, without asking the player to edit a radial.

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

A separate September-2026 production mod still proves `PlayerCharacterProperties.KeyboardHotBars[*].SlotList`. The names are now directly symmetrical and must remain distinct: CAM renders `ControllerHotBars`, never `KeyboardHotBars`.

## Native grid focus and action dispatch

The installed Patch 8 slot-assignment UI already proves the controller-grid mechanics CAM needs:

```text
AssignList
  LocalFocusSelector -> SelectorAssign
  KeyboardNavigation.DirectionalNavigation = Contained
          |
          v
nested LSListBox
          |
          v
LSGrid
  ActionUpEvent    = UIUp
  ActionDownEvent  = UIDown
  ActionLeftEvent  = UILeft
  ActionRightEvent = UIRight
  AutoIndex        = True
```

CAM adapts that mechanism to each native controller `SlotList`. The list keeps the existing element names `HotBarRadial` / `SingleBar` deliberately so the untouched native triggers, swap bindings and context-menu bindings continue to address the same local-focus source.

The native delayed dispatch seam remains:

```text
grid LocalFocusChanged
        |
        v
ActionRadials.Tag = LocalFocus.DataContext
        |
        v
UIAccept -> UseSlotCommand(Tag)
```

Top-level/nested B remains the untouched native `CancelButton` command switch.

This is distinct from the failed 0.0.18–0.0.25 approaches: CAM is no longer reconstructing the page/template lifecycle and no longer attempting to mirror a radial. It substitutes the radial **slot renderer** with a grid using a controller-focus pattern already working in the same current native XAML file.

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

The installed package contains a locally generated `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`. It is derived from the user's exact current `PreloadedActionRadials_c.xaml`, so the native outer template and control semantics track the installed game version.

Another UI mod overriding the same ActionRadials resource keys can still conflict by load order. The installer therefore remains fail-closed and records the native source hash used to derive the library.

No proprietary native XAML is stored in GitHub or release assets.
