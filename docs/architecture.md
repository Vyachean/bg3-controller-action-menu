# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The accepted runtime boundary is now:

```text
native ActionRadials state/page
          |
          v
native ActionRadialWidgetTemplate_P8
  (copied locally from this installed Game.pak)
          |
          +-- native outer lifecycle / A / B / nested / swap unchanged
          |
          +-- BarPageViewStyle / SingleBarPageViewStyle
                |
                v
         LSListBox + LocalFocusSelector
                |
                v
             LSGrid
      UIUp / UIDown / UILeft / UIRight
```

The key correction is that CAM no longer tries to make `ls:Radial` behave like a grid, and no longer keeps a hidden radial as the navigation engine. The installed Patch 8 XAML already contains a working controller grid in the **slot-assignment UI** (`AssignList` / `AvailableSlotsListPanelTemplate`). CAM reuses that focus/navigation contract for action browsing.

At install time CAM extracts the exact current `PreloadedActionRadials_c.xaml` from the user's `Game.pak`. It locally derives a `GUI/Library/Lib_Controller.xaml` containing the exact native:

- `ActionRadialWidgetTemplate_P8`;
- `RadialHotBarListItemContainer`;
- `BarPageViewStyle`;
- `SingleBarPageViewStyle`.

Only the two page-view styles are transformed: their `ls:Radial` slot renderer is replaced with the controller-grid pattern proven by the native slot-assignment UI. Runtime 0.0.27 proved this focus model works. The presentation layer then centers the grid within the existing PageView and collapses the obsolete circular radial backdrop:

- `LSListBox`;
- `LocalFocusSelector`;
- focusable `ListBoxItem` cells;
- `LSGrid ActionUpEvent/ActionDownEvent/ActionLeftEvent/ActionRightEvent`;
- `KeyboardNavigation.DirectionalNavigation="Contained"`;
- native `LocalFocusChanged` / delayed `ActionRadials.Tag` update semantics;
- centered 640×400 grid viewport inside the native 1560×1560 page;
- radial background ellipse collapsed without changing PageView focus/lifecycle.

The copied outer template remains native. Therefore `UseSlotBinding`, `CancelButton`, top-level vs nested B switching, swap-slot commands, split-screen close behavior, `PagedList`, context menu and state-machine lifecycle are not reimplemented. CAM only adjusts the visible hint strip for the common grid layout: it centers the strip and suppresses the obsolete “Radial Customisation” prompt while leaving the underlying context-menu command wired.

The grid cells are visual-only slot representations. The focused VM still reaches the native page through `ActionRadials.Tag`, and normal A remains `UIAccept -> UseSlotCommand(Tag)`.

No Larian XAML is committed to or distributed by this repository. The derived `Lib_Controller.xaml` is produced only on the user's machine from their installed game. The runtime remains a normal BG3 `.pak` with **no Script Extender, DLL or native loader dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

CAM owns only:

- install-time extraction and contract verification of the current native radial dictionary;
- local generation of a controller library from native resources already present in the user's game;
- replacement of the **slot renderer inside the two native PageView styles** with the proven slot-assignment `LSListBox + LSGrid` focus pattern;
- compact centered grid cell presentation;
- removal of obsolete radial-only visual chrome (circular backdrop and radial-specific customization prompt).

CAM must not own or reimplement:

- the `ActionRadials` state or page;
- outer `ActionRadialWidgetTemplate_P8` lifecycle;
- A/B input commands;
- nested/upcast/container switching;
- swap-slot semantics;
- targeting/execution/resource rules;
- controller action source data.

The patcher is fail-closed. If the installed game's current radial or slot-assignment seams no longer match the known contract, installation must stop before replacing the active CAM package.

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
