# Controller action menu design

## Decision

CAM is a **resource-first automatic action bar**.

The top level has exactly one navigation dimension: the resource/source used by an executable action variant. There are no class tabs, action-origin tabs, spellbook tabs, nested filter tabs, or user-maintained radial pages.

Target interaction:

```text
RESOURCE TABS
FREE | ACTION | BONUS | I | II | III | IV | ... | KI | SUPERIORITY | SCROLLS | ...
        |
        v
EXECUTABLE ACTION GRID
        |
        v
native BG3 tooltip for the focused variant
```

LB/RB changes the selected resource tab. D-pad/left stick moves through the grid. A executes the focused native slot. B backs out of native nested state or closes CAM.

## Resource tabs

The primary shipping source for dynamic resource tabs is the current Patch 8 HotBar model:

`CurrentPlayer.UIData.ActionResourcesCostPreview`

Each item is a native `VMActionResourceCostPreview`. Selecting a tab invokes:

`FilterActionResourceCommand(selectedResourcePreview)`

and CAM displays the resulting native:

`SingleHotBar.SlotList`

This gives CAM a generic path for Action, Bonus Action, spell-slot levels, Pact/Warlock slots, Ki, Bardic Inspiration, Sorcery Points, Superiority Dice, Channel Divinity, mod-added action resources, and any other resource that BG3 exposes through the same model. CAM must not hard-code classes or known ability names.

SpellSlot/WarlockSpellSlot tabs use the native resource level and Roman-numeral presentation. Other resource tabs use the native resource name. Tabs with `ActionResource.MaxValue == 0` are not presented.

The tab row is horizontal and may scroll; its order follows BG3's stable resource-preview order rather than CAM alphabetical sorting.

## Execution variants

The product model is an **execution variant**, not an abstract ability.

Examples:

```text
Fireball
  -> Action + Spell Slot III
  -> Action + Spell Slot IV
  -> Action + Spell Slot V
  -> Scroll
  -> mod resource
```

The same logical ability may therefore appear in several resource tabs. That duplication is intentional.

CAM does not synthesize executable variants. A cell must remain a native `VMHotBarSlot` and A remains `UseSlotCommand(slot)`. If BG3 materializes an upcast/resource-specific `VMHotBarSlot` in `SingleHotBar.SlotList`, CAM can expose it directly. If BG3 instead opens its native upcast/container state after A, that nested state remains the safe fallback until another current-game seam proves a flatter native variant source.

## ACTION and BONUS semantics

The product target treats Action/Bonus Action as the primary tab only when they are the main limiting resource. A spell whose meaningful consumable is Spell Slot IV should primarily belong to IV even though its complete cost also includes Action.

The current native `FilterActionResourceCommand` is the first implementation seam because it preserves BG3 semantics. CAM must not invent a classifier from names/icons/classes. If runtime proof shows that BG3's Action/Bonus filter includes every spell with that secondary cost, refine only with a current native executable-slot/property seam that identifies the primary resource. Do not solve this by hard-coded spell lists.

## Coverage-first source groups

The controller HotBar must satisfy the native parity contract in `docs/action-coverage.md`.
Resource filters are preferred, but they are not assumed to enumerate every gameplay action.

`FREE`, `SCROLLS`, item charges, consumables, temporary actions, recasts and similar source groups are part of the remaining correctness target. Cantrips and metamagic now have proven native providers, but they are not
allowed to be fabricated from raw assignment catalogs or string heuristics.

They may be added when a current BG3-owned source/filter yields executable `VMHotBarSlot` variants for that group. Raw `SpellsAndActions`, `Inventory.Slots`, or passive assignment objects remain research/presentation evidence only and are not direct dispatch candidates.

## Tooltip

There is **no separate CAM Live Details panel**.

Focused actions use the ordinary native BG3 tooltip. CAM supplies the focused `VMHotBarSlot.Content` to the captured `LSTooltip` / `ShowTooltipOnUIElementCommand` path and keeps `CreateFocusedTooltipDataCommand` / `HighlightResourcesCommand` on the native focus lifecycle.

This is sufficient for damage, range, save, complete costs, upcasted values, item data, and mod-provided tooltip data when BG3 exposes them.

## Scale

Design for the worst case: a character can have a very large action set, including modded abilities and resources.

Therefore:

- one resource-tab level only;
- no class tabs;
- no manual lists of known abilities;
- no fixed number of resources;
- horizontal resource-tab scrolling;
- resource order is stable/predictable;
- action grid scrolls by focus;
- duplicate execution variants across resource tabs are allowed.

## Current proof boundary

Patch 8 capture already proves:

- dynamic `ActionResourcesCostPreview`;
- `FilterActionResourceCommand`;
- `SingleHotBar.SlotList`;
- native `VMHotBarSlot` dispatch;
- `VMUpcast` content support;
- native tooltip costs/details;
- SpellSlot/WarlockSpellSlot level data.

The next runtime milestone must answer, in one combined game run:

1. does every selected resource tab populate the expected executable `SingleHotBar.SlotList`;
2. does a Spell Slot IV tab materialize IV-specific spell variants directly, or does A still enter native upcast state;
3. how broad are Action/Bonus native filters with respect to spells that also consume another resource;
4. do mod/custom resources appear automatically;
5. does top-level B close CAM while nested BG3 variant/upcast state still backs out normally.

Those questions determine how much of the final execution-variant flattening BG3 already provides without CAM gameplay logic.


## Runtime regression note

0.0.49 is not a valid implementation milestone. It attempted to flatten native upcasts and repair navigation in the same runtime revision; in-game this made resource-tab interaction delayed and unpredictable. The target resource-first UX is unchanged, but implementation returns to the 0.0.48 behavior before further isolated fixes.


## Simplified interaction model

The action surface has one focus owner. Resource tabs are changed by LB/RB; every executable top-level or nested option is rendered through the same `HotBarList` bound to `SingleHotBar.SlotList`.

There is no separate nested action window and no wrapper list around the grid. Entering a BG3 variant/upcast/throw state changes the contents of the same grid. B uses the native nested cancel path; top-level B closes the menu. This is the preferred baseline before any direct-upcast flattening or tab-layout refinements.


## Adaptive grid and focus rendering

The action grid must not have a fixed column count. Column count is derived from the current viewport width, matching the current controller SpellBook grid.

Focused action indication is rendered by the focused cell itself. There is no detached selector overlay. This is important both visually and semantically: when a resource tab replaces `SingleHotBar.SlotList`, the old focus visual disappears with the old cell rather than requiring separate reset logic.

Resource tabs remain one horizontal LB/RB strip. The strip scrolls to its selected item instead of making the entire menu wider. Generic resources without a localized name show their native TypeId as a diagnostic-safe fallback; spell slots remain level-based.
