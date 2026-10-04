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

The exact current Patch 8 **controller collection** is not yet proven. Normal slot dispatch is now proven independently by current Patch 8 `HotBarSlotStyle`: it invokes `UseSlotCommand` on the owning `UIWidget` and passes the slot object as the command parameter.

The shipping `.pak` contains only ordinary BG3 mod resources. It has **no Script Extender, DLL, native loader or external runtime dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

The custom layer owns:

- replacing the `ActionRadials` page/state presentation;
- ordering native groups;
- grid column count/spacing;
- main-list vs `SingleHotBar` variant presentation;
- a local menu panel over the live gameplay view;
- temporary visible diagnostics in prerelease candidates.

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

Confirmed current Patch 8 structural evidence:

- `Controller.xaml` still defines the `ActionRadials` state and points it at `ActionRadials.xaml`;
- Patch 8 pages such as `CharacterPanel.xaml` use `ls:UIWidget.Template/ControlTemplate` and direct view-model bindings inside that root template;
- Patch 8 `DataTemplates.xaml` uses `(ls:WidgetData.DataContext)` + `TemplatedParent` in nested reusable templates where the templated parent is not the root widget;
- a July 2026 Patch 8 runtime report identifies `PreloadedActionRadials_c.xaml` and focus-driven `LSScrollViewer.ScrollToElement`.

Therefore neither direct binding nor `WidgetData.DataContext` should be treated as a universal rule. The correct choice must match the actual current radial template boundary.

The older public `Public/Game/GUI/Widgets/ActionRadials.xaml` is Patch 2 Hotfix 1 from 2023-09-06. Its `HotBars`, `PagedList/PageView`, `SingleHotBar` and radial-specific cancel structure are historical evidence only. `UseSlotCommand` itself is separately confirmed current by Patch 8 `HotBarSlotStyle` and September-2026 production code.

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

Current evidence proves the **data model is mode-sensitive** but does not yet publish the Patch 8 controller collection property exposed to XAML.

Current engine/component evidence:

- `HotbarContainer.Containers` stores arrays of native bars;
- each bar has `Index`, `Controller`, `Elements`, dimensions and name;
- hotbar mutation/event structures explicitly carry `HotBarController` / `IsController`.

Current UI evidence from a production mod dated 2026-09-27:

- top-level widget name: `HotBar`;
- live view model: `HotBar.DataContext`;
- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList` exists;
- `CurrentSingleHotbarFilter` exists;
- `UseSlotCommand:Execute(slot)` works.

The word **Keyboard** is significant. The current engine data proves keyboard and controller state are distinct, so `KeyboardHotBars` is evidence of the modern view-model shape, not the controller source CAM should render.

Historical Patch 2 `ActionRadials.xaml` used `CurrentPlayer.SelectedCharacter.HotBars`, per-bar `SlotList` and `PagedList/PageView`. That path must not be promoted to Patch 8 truth without current evidence.

## Native slot dispatch

Current Patch 8 `HotBarSlotStyle` supplies the gameplay seam CAM wants to preserve:

```text
BoundEvent       <- slot.BoundEvent
Command          <- owning UIWidget.DataContext.UseSlotCommand
CommandParameter <- current slot object
```

Therefore CAM must not add its own gameplay execution command. Once the correct controller slot collection is identified, native slot buttons should continue to use `HotBarSlotStyle`.


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
