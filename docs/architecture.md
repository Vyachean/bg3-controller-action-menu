# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The accepted runtime ownership boundary is:

```text
installed BG3 Game.pak
          |
          v
native PreloadedActionRadials_c.xaml
          |
          | local, fail-closed presentation patch
          v
native ActionRadials template/PageViews/Radials preserved
          |
          +-- native Radial: invisible input/focus engine
          |
          +-- CAM grid: non-interactive visual mirror
                         SelectedIndex <- Radial.LocalFocus.Index
          |
          v
locally derived CAM PAK
```

The installed Xbox App build 1.8.910.0 supplied the current Patch 8 radial contract directly. The root collection is `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`; each bar exposes `SlotList`; nested variants use `SingleHotBar.SlotList`.

Runtime builds 0.0.18–0.0.24 established progressively that CAM must not reconstruct the native focus/input lifecycle:

- 0.0.18/0.0.20 could render correct data but had dead navigation/B;
- 0.0.19 regressed bindings while changing input transport;
- 0.0.23 proved the controller-library secondary-XAML path assumption wrong at startup;
- 0.0.24 proved the native page and CAM resource override were active (native radial movement sounds played), yet a full replacement `ActionRadialWidgetTemplate_P8` still had no usable focus/A/B.

Therefore CAM no longer ships a page, StateMachine, controller library, replacement ActionRadials template, or copied native XAML.

The one-click installer downloads only CAM-authored code plus a metadata-only base PAK. On the user's PC, `tools/native-overlay.ps1` extracts the two current `PreloadedActionRadials_c.xaml` resources from that installation's `Game.pak`, verifies required native seams, modifies only the two radial visual locations, and packs the derived files under their original `Public/Game/GUI/...` resource paths.

The original `ls:Radial` elements remain in the XAML and keep native `LocalFocus`, `UseSlotBinding`, `CancelButton`, nested/swap behavior, PageView focus transitions and state-machine lifecycle. CAM makes those radial visuals transparent and adds a non-focusable/non-hit-test grid that mirrors the same items and selected native index.

No Larian XAML is committed to or distributed by this repository. The runtime remains a normal BG3 `.pak` with **no Script Extender, DLL or native loader dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

CAM owns only:

- install-time extraction/verification of the current native radial resources;
- a deterministic presentation patch that hides native radial artwork without removing the native radial control;
- a non-interactive grid mirror using native slot visuals;
- local packaging of those derived resources.

CAM must not own or replace:

- the `ActionRadials` state or native page;
- `ActionRadialWidgetTemplate_P8` as a hand-written replacement;
- PageView focus lifecycle;
- radial `LocalFocus` calculation;
- A/B input routing;
- nested/upcast/swap state transitions;
- whether an action is usable;
- spell/resource/targeting/execution rules.

The patcher is fail-closed: if expected current Patch 8 seams are missing, it must refuse to build an installable package rather than guess against a changed game version.

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

## Native slot rendering and dispatch

The captured native controller radial owns the gameplay seams:

```text
native Radial.LocalFocus
        |
        v
ActionRadials.Tag
        |
UIAccept
        |
        v
UseSlotCommand(Tag)
```

Top-level/nested B remains the native `CancelButton` command switch; swap-slot behavior remains native as well.

CAM's visual mirror does **not** receive focus or input. Its cells reuse `HotBarSlotStyle` with command disabled and hit testing/focus disabled. The grid's selected index is a one-way mirror of the still-running native radial's `LocalFocus.Index`.

This is intentionally different from the failed 0.0.18–0.0.24 approaches: input is no longer reconstructed, forwarded or emulated by CAM.

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

The derived PAK overrides the exact native `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` and Clairmont counterpart from the user's installed version. This is inherently a UI-resource conflict surface: another mod overriding the same files can conflict by load order.

Because CAM derives from the installed files rather than bundling a fixed copy, game updates are handled fail-closed: the patcher re-reads the current `Game.pak` and refuses to patch if the required native seams no longer match.

No proprietary native XAML is stored in GitHub or release assets.
