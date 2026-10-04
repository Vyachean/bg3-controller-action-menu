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

The exact current Patch 8 collection and dispatch bindings are **not yet proven**. They must be taken from the installed game's current radial XAML before the next runtime candidate is accepted.

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

The older public `Public/Game/GUI/Widgets/ActionRadials.xaml` is Patch 2 Hotfix 1 from 2023-09-06. Its `HotBars`, `PagedList/PageView`, `UseSlotCommand`, `SingleHotBar` and cancel structure are historical evidence only.

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

Current evidence does **not** yet prove the Patch 8 action collection path.

Historical Patch 2 `ActionRadials.xaml` used:

- `CurrentPlayer.SelectedCharacter.HotBars`;
- per-hotbar `SlotList`;
- `PagedList/PageView` wrappers;
- `SingleHotBar.SlotList` for nested choices;
- native `UseSlotCommand` dispatch.

Patch 8 public resources prove that `HotBarSlotStyle` still exists, but the current controller radial page itself is not publicly available. The next implementation must be based on a read-only extraction of the installed game's current `ActionRadials.xaml` / `PreloadedActionRadials_c.xaml`, not on the 2023 file.

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
