# Architecture

## Objective

Replace Baldur's Gate 3 controller radial browsing with a controller-first, automatically populated **resource-first action bar** while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

The shipping artifact is one self-contained ordinary BG3 `.pak`, with no Script Extender, DLL/native loader, or install-time game-file derivation.

## Runtime composition

```text
native ActionRadials state/page
          |
          v
project-owned ActionRadialWidgetTemplate_P8
          |
          +-- dynamic resource tabs
          |     CurrentPlayer.UIData.ActionResourcesCostPreview
          |                 |
          |                 v
          |     FilterActionResourceCommand(selected preview)
          |                 |
          |                 v
          |          SingleHotBar.SlotList
          |          native VMHotBarSlot variants
          |
          +-- controller action grid
          |     LSGrid + LocalFocusSelector
          |
          +-- native tooltip/focus lifecycle
                LocalFocus.DataContext
                     |
                     +--> ActionRadials.Tag
                     +--> CreateFocusedTooltipDataCommand
                     +--> HighlightResourcesCommand
                     +--> LSTooltip / ShowTooltipOnUIElementCommand
                     |
                     v
                UIAccept -> UseSlotCommand(slot)
```

There is no Common/Class/Cantrips/Items/Passives primary navigation layer and no secondary resource-filter layer. Resource is the single top-level organization dimension.

## Evidence boundary

The current contract is based on the captured Xbox App game package `1.8.910.0`. Source hashes and consumed seams are pinned in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

Proven current facts include:

- page/state: `ActionRadials`;
- context: `HotBar`;
- executable cells are native `VMHotBarSlot` objects;
- `ActionResourcesCostPreview` exposes native `VMActionResourceCostPreview` resource entries;
- `FilterActionResourceCommand` accepts the selected preview;
- filtered/native nested choices are materialized as `SingleHotBar.SlotList`;
- `VMUpcast` is a supported native slot-content type;
- A uses `UseSlotCommand(ActionRadials.Tag)`;
- native focus tooltip/resource highlighting is available;
- B has BG3-owned nested-state commands.

Historical public dumps and older CAM type-tab experiments are context only.

## Resource-first navigation

LB/RB selects an item from the dynamic resource list. Selection immediately invokes `FilterActionResourceCommand`; the grid is always sourced from `SingleHotBar.SlotList`.

The resource tab list:

- is bound directly to `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- hides entries with no resource object or `MaxValue == 0`;
- keeps BG3 ordering;
- renders SpellSlot/WarlockSpellSlot levels from native level data;
- renders unknown/mod resources from native resource names;
- has no class-specific cases.

The product target additionally includes FREE/SCROLLS/charge-based source groups. Those require a proven BG3-owned executable-slot source and must not be synthesized from raw assignment objects.

## Execution and upcast boundary

The normal executable unit remains the native `VMHotBarSlot`. Patch 8 HotBar evidence additionally proves one narrow exception for native upcast execution:

```text
VMHotBarSlot.Content.SpellUpcast -> VMUpcast[]
HotBarSlotStyle:
  Command = UseSlotCommand
  CommandParameter = VMUpcast
```

Runtime 0.0.48 proved that `FilterActionResourceCommand(SpellSlot N)` still leaves upcastable spells as the base slot. CAM may therefore project a **native execution proxy** for spell-slot tabs: from the focused slot's existing `Content.SpellUpcast`, choose the `VMUpcast` whose `SlotLevel` equals the selected resource's `ActionResource.SpellSlotLevel`. That `VMUpcast` may be used directly for tooltip/resource highlight/`UseSlotCommand`, exactly as current HotBar does.

CAM still does not construct `VMUpcast`, calculate spell values, or use raw assignment catalogs. If no matching native `VMUpcast` exists, the base `VMHotBarSlot` remains the fallback and BG3 may open its native nested selector.

## ACTION / BONUS primary-resource policy

The target UX does not want slot spells duplicated into ACTION merely because they also consume one Action.

CAM therefore distinguishes:

- **product policy:** choose the meaningful limiting resource as the primary tab;
- **current implementation seam:** BG3's native resource filter.

If native Action/Bonus filters are broader than product policy, CAM may refine them only using a current BG3 property/predicate over executable native slots. No class/spell-name tables or heuristics are permitted.

## Tooltip

CAM has no custom Live Details panel.

The ordinary native tooltip is the details surface. On action focus:

- clear stale `ActionRadials.Tag`;
- after the captured delay, copy the focused `VMHotBarSlot` to `ActionRadials.Tag`;
- call `CreateFocusedTooltipDataCommand(slot)`;
- call `HighlightResourcesCommand(slot)`;
- show an `LSTooltip` whose content is `VMHotBarSlot.Content`.

## B / nested state

Resource filtering is the top-level browsing state, so a populated `SingleHotBar.SlotList` must not by itself make B behave as a nested-back action.

Top-level B closes CAM when no BG3 nested variant/upcast/throw state is active. Real nested state still uses `ClearSingleHotbarCommand`.

Runtime 0.0.48 proved an additional invariant: clearing nested state also clears the top-level resource-filter result. When the three nested-state flags return to false and a resource tab is still selected, CAM must immediately re-run `FilterActionResourceCommand(CAM_ResourceTabs.SelectedItem)` before restoring grid focus. Returning from nested B must never leave the selected resource tab visually active over an empty grid.

## Rejected data paths

Do not use these as direct execution catalogs:

- `PlayerCharacterProperties.SpellsAndActions`;
- `Inventory.Slots`;
- raw passive collections;
- user-configured `ControllerHotBars`.

They may provide research evidence, but dispatch remains native `VMHotBarSlot`.

## Self-contained package boundary

Runtime source remains `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.

The release PAK contains project-owned runtime resources only. Normal installation does not read `Game.pak`, run LSLib, generate XAML, or rebuild a PAK locally.

## Focus and scrolling

0.0.48 rejected the leftover two-list shell in which one outer list owned a single nested executable list. It produced invisible focus transitions, clipped lower rows, missing scroll tracking, and selector coordinate drift.

The main resource-filtered `HotBarList` now directly owns the executable `SingleHotBar.SlotList` cells, the `LSGrid`, the native tooltip, and `LocalFocusSelector`. Its selector shares the exact same coordinate root as the list. The vertical ScrollViewer follows the focused/selected cell instead of trying to scroll a wrapper item.

The resource-tab list is separate from D-pad navigation. LB/RB changes selection; the horizontal viewport must bring the newly selected tab into view and then return gameplay focus to the action grid.

## Preserved controller shortcuts

The native radial exposes weapon-set switching as a hold action on `UISelectionLeft` using `SwitchWeaponSetCommand`. CAM keeps that feature. Because the action grid consumes ordinary `UILeft` for navigation, the shortcut must bind the distinct `UISelectionLeft` event explicitly; the hint must not advertise a dead command.

## Proof boundary

CI can prove:

- resource-first XAML is present;
- old type tabs/deck commands are absent from runtime;
- resource tabs bind the native preview collection;
- selection drives `FilterActionResourceCommand`;
- grid dispatches only native `VMHotBarSlot` entries from `SingleHotBar.SlotList`;
- native tooltip/A/nested-state seams remain;
- package and installer boundaries are intact.

CI cannot prove the semantic contents BG3 puts into each resource-filtered `SingleHotBar`. That requires one combined milestone game run after green package proof.
