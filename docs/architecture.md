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

CAM never executes a raw `VMCharacterAction`, `VMUpcast`, `VMItem`, or `VMPassive` directly. The executable unit is the surrounding `VMHotBarSlot`.

Resource-filtered `SingleHotBar.SlotList` is intentionally used because it may already materialize resource-specific execution variants. For example, a Spell Slot IV filter may expose `VMHotBarSlot` entries whose content represents IV-level upcasts.

This is a runtime proof boundary. If BG3 still opens `IsSelectingUpcastedSpell` after selecting an action, CAM retains the native nested `SingleHotBar` fallback rather than recreating upcast rules.

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

Top-level B closes CAM when no BG3 nested variant/upcast/throw state is active. When BG3 opens a real nested state such as `IsShowingAContainerWithVariants`, `IsSelectingUpcastedSpell`, or `IsShowingItemsToThrow`, B retains the native nested cancellation behavior.

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
