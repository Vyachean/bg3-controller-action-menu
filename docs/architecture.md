# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

Runtime 0.0.36 rejects the radial-assignment catalog as CAM's top-level **execution** model.

Current Patch 8 `HotBarSlotStyle` establishes the native boundary:

```text
VMHotBarSlot
  Content -> VMCharacterAction / VMItem / VMPassive / VMUpcast / ...
  Command -> DCHotBar.UseSlotCommand
  CommandParameter -> VMHotBarSlot
  resource preview -> HighlightResourcesCommand(VMHotBarSlot)
```

The visible content object and the executable hotbar slot are therefore not interchangeable. The automatic assignment collections remain useful discovery evidence, but CAM must not send their raw candidates to `UseSlotCommand`.

The next runtime composition is:

```text
native ActionRadials state/page
          |
          v
locally derived ActionRadialWidgetTemplate_P8
          |
          +-- MAIN: installed DCHotBar deck/resource filters
          |       |
          |       v
          |    native VMHotBarSlot result set
          |       |
          |       v
          |    one flat LSListBox + LSGrid + LocalFocusSelector
          |       |
          |       +--> tooltip/resource-preview commands(slot)
          |       |
          |       v
          |    ActionRadials.Tag = slot
          |
          +-- SECOND STAGE: native SingleHotBar.SlotList
                  |
                  v
              same flat grid
          |
          v
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

### Native filter semantics

CAM follows the keyboard hotbar's native filter model rather than inventing action categories.

Two conceptual filter axes are relevant:

| Axis | Native semantics |
| --- | --- |
| deck/type | Common, Class, Items, Passives |
| action/resource | Action, Bonus Action, spell-slot resources, cantrips and class-specific resources exposed by DCHotBar |

`Custom` is deliberately excluded because CAM is automatic, not a user-managed layout.

Historical `HotBar.xaml` demonstrates this model through `CurrentShownDeck`, `SetCurrentShownDeckCommand`, `CurrentSingleHotbarFilter`, `FilterActionResourceCommand`, `FilterCantripsCommand`, `ActionResourcesCostPreview` and `PassivesHotBar`. Those exact names are not accepted as shipping authority by themselves.

The installer must extract the **current installed** keyboard `HotBar.xaml` from `Game.pak`. Generated XAML may use a concrete deck/filter command or property only when that current local source contains the required seam.

This is the same local-native-derivation boundary already used for `PreloadedActionRadials_c.xaml`; no Larian XAML is committed or published.

### Flat-grid focus and dispatch

0.0.36 used multiple assignment lists and nested grids. Runtime proved that navigation can become trapped at the bottom row. Top-level CAM therefore has exactly one visible focus owner and one flat grid.

On focus change CAM passes the **VMHotBarSlot wrapper** through the same native controller/hotbar seams:

```text
LocalFocus.DataContext (VMHotBarSlot)
        |
        +--> CreateFocusedTooltipDataCommand(slot)
        +--> HighlightResourcesCommand(slot)
        |
        v
ActionRadials.Tag = slot
        |
        v
UIAccept -> UseSlotCommand(slot)
```

When focus leaves or changes, CAM clears the previous resource highlight through the native clear command before highlighting the new slot.

`SingleHotBar.SlotList` remains BG3-owned for native resource-filter results and for containers, upcast and variants.

### Controller chrome

CAM no longer reflows `ButtonHintsContainer` and no longer creates CAM-authored LB/RB hint presenters. The installed ActionRadials hint layout is preserved exactly except that radial-edit entry points are disabled/hidden.

Radial customization remains outside CAM: X/context menu, assign, swap, clear and add/remove radial operations are unreachable.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

CAM owns:

- tab/grid presentation over BG3-owned automatic collections;
- controller focus composition reused from native BG3 UI patterns;
- hiding empty presentation tabs;
- transition between the automatic main catalog and BG3's native `SingleHotBar` nested results.

CAM does **not** own membership or semantic classification inside those native collections.

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

Current engine/component evidence proves the hotbar slot/container model:

- hotbar bars carry index/controller/elements metadata;
- bar index mapping is `0=Common, 1=Class, 2=Item`;
- native slot wrappers are the unit passed through hotbar execution;
- container/deck components remain engine-owned.

Current installed controller evidence proves:

- state/context: `ActionRadials` / `HotBar`;
- native A: `UseSlotCommand(ActionRadials.Tag)`;
- nested/filter result surface: `SingleHotBar.SlotList`;
- current nested/filter state: `CurrentSingleHotbarFilter`;
- container/upcast state remains DCHotBar-owned.

A September-2026 production mod independently proves live Patch 8 `KeyboardHotBars[*].SlotList` VMHotBarSlot wrappers and direct `UseSlotCommand(slot)` use under the HotBar context.

The previous rule that keyboard hotbar data must never participate in CAM is superseded by the 0.0.36 runtime result. What remains forbidden is treating a persisted/manual keyboard layout as an invented source of truth. CAM uses the **native DCHotBar deck/filter semantics and VMHotBarSlot execution wrappers**, with the concrete current contract sourced from installed `HotBar.xaml`.

## Native grid focus and action dispatch

The assignment UI remains useful only as controller-grid precedent. CAM's top-level result set is no longer a hierarchy of assignment groups.

The main surface uses one flat `LSListBox` backed by a directional `LSGrid`. This removes cross-list `Continue/Contained` transitions from top-level navigation.

The native dispatch seam is:

```text
grid LocalFocusChanged
        |
        +--> native tooltip/resource preview(slot)
        |
        v
ActionRadials.Tag = VMHotBarSlot
        |
        v
UIAccept -> UseSlotCommand(slot)
```

Native A therefore receives the same wrapper type used by `HotBarSlotStyle`; raw `VMCharacterAction`, `VMItem` or `VMPassive` content objects are not command parameters.

Top-level/nested B remains the untouched native `CancelButton` / `ClearSingleHotbarCommand` lifecycle.

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
