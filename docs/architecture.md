# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The runtime boundary is now:

```text
native BG3 Controller state
          |
          v
native MainUI/Pages/ActionRadials.xaml
          |
          v
StaticResource ActionRadialWidgetTemplate_P8
          ^
          |
CAM controller library resource override
          |
          v
thin grid composition over native DCHotBar
          |
          v
native BG3 commands/state events
```

The installed Xbox App build 1.8.910.0 supplied the current Patch 8 radial contract directly. The main collection is `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`; each bar exposes `SlotList`; nested variants use `SingleHotBar.SlotList`.

The decisive architectural change after runtime builds 0.0.18–0.0.20 is that CAM no longer owns the `ActionRadials` state or page. BG3 keeps its native state machine entry and exact `Mods/MainUI/GUI/Pages/ActionRadials.xaml` root, including the `ActionRadials` widget name, `HotBar` context, automation identity, page-level Loaded/Unloaded/WidgetClosing triggers, focus restore and native state events.

CAM uses the documented BG3 controller library hook (`GUI/Library/Lib_Controller.xaml`) to provide the resource key consumed by that native page. This is the smallest ordinary-.pak hook that can still replace the radial presentation.

The shipping `.pak` contains only ordinary BG3 UI resources. It has **no Script Extender, DLL, native loader or external runtime dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

The custom layer owns:

- one controller resource-library override for `ActionRadialWidgetTemplate_P8`;
- ordering native groups;
- grid column count/spacing;
- main-list vs `SingleHotBar` variant presentation;
- a local menu panel over the live gameplay view;
- temporary visible diagnostics in prerelease candidates.

The custom layer must **not** override the `ActionRadials` state or replace `MainUI/Pages/ActionRadials.xaml`. It must not add a full-screen opaque/dim background; opening the action menu should preserve the gameplay view behind the local panel.

The custom layer should not own:

- whether an action is usable;
- spell slot/resource calculation;
- upcast rules;
- target validation;
- range/LOS checks;
- action execution;
- recast semantics;
- passive/class resource semantics;
- item counts/state;
- cell visuals already provided by native BG3 resources.

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

Current Patch 8 `HotBarSlotStyle` remains the preferred native visual template for square action cells. Its generic hotbar contract is:

```text
BoundEvent       <- slot.BoundEvent
Command          <- owning UIWidget.DataContext.UseSlotCommand
CommandParameter <- current slot object
```

The captured **controller radial** uses a more specific input seam for normal A:

```text
Focused controller slot
        |
        v
ActionRadials.Tag
        |
UIAccept
        |
        v
UseSlotCommand(Tag)
```

CAM reuses `HotBarSlotStyle` for cell visuals while keeping gameplay dispatch page-level.

Runtime builds 0.0.18–0.0.20 proved that rebuilding the whole page/state was the wrong ownership boundary:

- `0.0.18` proved `ControllerHotBars`, section materialization, native visuals and tooltip data, but directional navigation and B were dead;
- `0.0.19` changed input transport and regressed rendering/data bindings;
- `0.0.20` restored rendering and used the captured `LSListBox -> ListBoxItem -> LSGrid` focus hierarchy, but the custom page still had no working controller focus/input.

Therefore the page/state reconstruction is rejected. The native `ActionRadials.xaml` page now remains untouched and continues to own its original root widget identity and page-level lifecycle. The template override keeps the captured native `UseSlotBinding` / `CancelButton` command semantics and updates `ActionRadials.Tag` from grid focus so `UseSlotCommand(Tag)` remains BG3-owned.

The grid itself still follows the current Patch 8 2D controller pattern already present in the captured `PreloadedActionRadials_c.xaml`:

```text
LSListBox
    |
focusable ListBoxItem
    |
LSGrid
  ActionUpEvent    = UIUp
  ActionDownEvent  = UIDown
  ActionLeftEvent  = UILeft
  ActionRightEvent = UIRight
```

This keeps the custom surface limited to the resource template while the state/page lifecycle remains entirely native.


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

CAM no longer overrides the controller `ActionRadials` state/page. It participates through `Lib_Controller.xaml`, the documented controller-mode resource library hook.

A different UI mod that defines the same `ActionRadialWidgetTemplate_P8` resource key can still conflict by load order, but ordinary state-machine compatibility is improved because CAM no longer replaces the state itself.

If CAM's resource key is not selected, the native page/state remains valid and the expected fallback is BG3's normal radial UI rather than a dead custom page.
