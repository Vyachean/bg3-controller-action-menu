# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

The intended boundary is still:

```text
BG3 controller ActionRadials state
              |
              v
        native HotBar context
              |
              v
     current native action/slot VM
              |
              v
      thin custom grid layout
              |
              v
       native BG3 dispatch
```

The installed Xbox App build 1.8.910.0 has now provided the current Patch 8 radial contract directly. The main collection is `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`; each bar materializes `SlotList` through `PagedList`; nested variants use `SingleHotBar.SlotList`.

Controller-radial normal A dispatch is page-level: `UIAccept -> UseSlotCommand(ActionRadials.Tag)`, where the native page updates `ActionRadials.Tag` from the focused radial slot. `HotBarSlotStyle` remains a current native slot visual/command style, but CAM must not assume its per-slot `BoundEvent` is the radial-specific A-dispatch contract.

The shipping `.pak` contains only ordinary BG3 mod resources. It has **no Script Extender, DLL, native loader or external runtime dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

The custom layer owns:

- overriding the `ActionRadials` state only to resolve a mod-owned, native-named `ActionRadials.xaml`;
- replacing the native radial template body with a grid while preserving the captured native root widget identity/lifecycle;
- ordering native groups;
- grid column count/spacing;
- main-list vs `SingleHotBar` variant presentation;
- a local menu panel over the live gameplay view;
- temporary visible diagnostics in prerelease candidates.

The project no longer ships a separately invented `CAM_ActionMenu_c.xaml` root. Runtime 0.0.18–0.0.20 showed that recreating enough of the root lifecycle/focus semantics was a larger and less reliable surface than replacing only the presentation template.

The custom page must not add a full-screen opaque/dim background; opening the action menu should preserve the gameplay view behind the local panel.

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

The first three runtime candidates clarified the focus/input boundary:

- `0.0.18` proved `ControllerHotBars`, section materialization and native visuals/tooltips, but navigation and B did not work;
- `0.0.19` replaced native radial `LSButton` input controls with `LSInputBinding` and added grid flags from unrelated screens; it regressed rendering/data bindings and is rejected;
- `0.0.20` restored the populated grid but still reported no widget/slot focus and no controller input, proving that the failure remained at the custom root/focus lifecycle boundary.

The installed Patch 8 radial itself contains the required 2D controller-grid precedent in its slot-assignment UI:

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

The captured slot-assignment grid adds two details that are now architecture requirements, not optional hints:

- the outer `LSListBox` is the focus root: `SelectedIndex=0`, `LocalFocusSelector`, `ActionNextEvent=UIDown`, `ActionPrevEvent=UIUp`, `KeyboardNavigation.DirectionalNavigation=Contained`;
- the inner `LSGrid` sets `ContainerData="{Binding}"`.

CAM mirrors that hierarchy. Outer section `ListBoxItem` containers remain focusable; each inner slot list uses a focusable `ListBoxItem` plus `LSGrid`; the nested `HotBarSlotStyle` button is non-focusable and visual-only.

The page root is now also the native `ActionRadials` root contract: same element name, HotBar context, root focus mappings, Loaded/GotKeyboardFocus/WidgetClosing lifecycle, Layout refocus behavior and automation-id shape. Normal A and B use the captured native radial `LSButton` pattern (`UseSlotBinding` and `CancelButton`).

This reduces custom ownership to template composition while keeping navigation and dispatch inside mechanisms proven in the installed game's own current XAML.


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

UI mods can conflict when they override the same state/page. The current mod overrides the controller `ActionRadials` state, so another mod replacing that state can conflict by load order.

Prefer reusing native dictionaries and the smallest custom state/page surface possible.
