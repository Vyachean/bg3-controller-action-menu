# Controller action menu design

## Decision

The combat action menu should deliberately follow Baldur's Gate 3's existing controller spell-selection language instead of introducing a visually unrelated UI.

The closest native references are:

- controller Spell Book;
- spell preparation in Character Creation / Level Up / Respec.

These screens already solve the exact controller problem we need:

- icon grids;
- directional focus;
- automatic scrolling driven by focus;
- grouped spell levels;
- native tooltips;
- familiar BG3 visual hierarchy.

## Target interaction

The current proof-gated milestone uses four automatic tabs:

```text
[ Actions / Spells ] [ Items ] [ Passives ] [ Metamagic* ]
```

`Metamagic` is present only when BG3's native metamagic predicate produces candidates. Passives follows the same empty-filter rule. There is no `Custom` tab and there is no CAM-owned slot editor.

The mapping is deliberately mechanical:

- **Actions / Spells** → `PlayerCharacterProperties.SpellsAndActions`;
- **Items** → `Inventory.Slots`;
- **Passives** → `Stats.Passives` filtered by `TogglablePassivePredicate`;
- **Metamagic** → the same passives collection filtered by `TogglableMetaMagicPassivePredicate`.

The tabs do not decide whether an action is a spell, common action, class action, usable item, or valid target. They only choose which BG3-owned source is visible.

Controller navigation uses `UITabPrev` / `UITabNext` on an `LSListBox`. The content stays in the already-proven two-dimensional assignment-style grid. Runtime 0.0.35 showed that one shared outer focus root is not sufficient: visual selection changed while tooltip/dispatch focus could remain on the first tab. Each tab now owns its own assignment-style focus list and native-derived selector; `SetMoveFocusAction` targets the newly selected list directly, and only that list updates `ActionRadials.Tag`.

### Spell-level grouping

The desired end state still follows BG3's own Spell Book semantics: cantrips and spell-level/action groups should be shown under BG3-provided group names when the exact current contract is proven.

Do **not** produce that layout by manually inspecting `SpellSlotLevel`, slot type, action names, icons, resources, or any CAM-owned heuristic.

The historical public SpellBook XAML contains `CantripGroupPredicate`, `SpellLevelsGroupPredicate`, `AllActionsGroupPredicate` and `VMActionGroup.Name`, but that public file is not current Patch 8 proof. The 0.0.35 milestone therefore preserves the native `SpellsAndActions` grouping/order without hard-coding those historical predicate names. Current installed-game SpellBook evidence is required before adding the finer headings.

## Native UI evidence

### Spell preparation

The shipped controller spell-preparation template uses:

- `SpellPrepare.PreparableByLevel`;
- grouped spell levels;
- an icon grid inside each level group;
- a controller scroll viewer;
- focusable controller items.

ImprovedUI and HybridUI both retain this same structural pattern in current public mod sources.

### Spell Book

The controller Spell Book is strong **design precedent** for:

- controller tabs driven by `UITabPrev` / `UITabNext`;
- action groups with game-provided names;
- cantrip / spell-level / action separation;
- passives and metamagic;
- `LSGrid`-based icon layouts and focus-driven scrolling.

The exact public SpellBook file currently available for the named group predicates is historical, so those particular binding/property names are not treated as a shipping Patch 8 contract. The semantics remain the target; the current installed resource must prove the concrete bindings before CAM adopts them.

### Action radial and assignment catalog

The old public radial page is Patch 2 Hotfix 1 and is no longer treated as a current data-source specification. The installed Patch 8 preloaded radial is authoritative and, importantly, contains the current **slot-assignment catalog** used when choosing what to put into a radial.

The installed Xbox App build 1.8.910.0 now establishes the current radial contract directly:

- controller state/context: `ActionRadials` / `HotBar`;
- configured radial storage/presentation: `ControllerHotBars[*].SlotList`;
- automatic assignment catalog: `PlayerCharacterProperties.SpellsAndActions`, togglable `Stats.Passives`, metamagic and `Inventory.Slots`;
- nested execution choices: `SingleHotBar.SlotList`;
- nested-state property: `CurrentSingleHotbarFilter`;
- variant/upcast state: `IsShowingAContainerWithVariants` / `IsSelectingUpcastedSpell`;
- focus-scroll mechanism: `LSScrollViewer.ScrollToElement` following `FocusedElement`;
- normal controller A: a page-level `UIAccept` binding invokes `UseSlotCommand` with the focused slot stored in the page `Tag`;
- B: `ClearSingleHotbarCommand` for nested state, dynamically changed to `CustomEvent("CloseWidget")` at the top level.

Current `HotBarSlotStyle` remains useful for square native cell visuals, but its generic per-slot `BoundEvent` is not the captured radial-specific A-input mechanism.

## Architecture implication

Prefer:

```text
native ActionRadials state/page
          |
locally derived ActionRadialWidgetTemplate_P8
          |
automatic assignment catalog
SpellsAndActions / Passives / Metamagic / Items
          |
AssignList-style controller grid
          |
ActionRadials.Tag
          |
native UseSlotCommand
          |
SingleHotBar grid when BG3 opens variants/upcast/container
```

Do **not** use `ControllerHotBars[*].SlotList` for the main menu. That collection describes the player's manually configured radial wheels and would make CAM depend on exactly the customization workflow it is intended to replace.

Radial editing commands (X/context menu, assign, swap, clear, add/remove slots) are not part of CAM.

Do not implement spell execution, targeting, resource checks, upcast rules, recasts, passive semantics or inventory use ourselves.

## Current milestone target — 0.0.36

Before another in-game run, static/package proof must establish all of the following together:

1. the main menu does not bind `ControllerHotBars[*].SlotList`;
2. the four tab definitions map only to current BG3-owned automatic sources;
3. `UITabPrev` / `UITabNext` are wired on the tab `LSListBox`;
4. filtered empty Passives/Metamagic tabs collapse;
5. every tab owns a separate assignment-style focus list and exact native-derived `SelectorAssign` clone;
6. tab changes clear stale `ActionRadials.Tag` and move focus directly to the selected tab list through `SetMoveFocusAction`;
7. only the selected tab list writes the current native candidate to `ActionRadials.Tag`;
8. the existing `AssignList + LocalFocusSelector + LSGrid` focus model remains the content renderer;
9. X/context-menu editing and Assign/Swap/Clear/Add/Remove radial mutations are unreachable;
10. A remains `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
11. B and nested `SingleHotBar.SlotList` remain BG3-owned;
12. native footer hints remain in the right-side lane and do not occupy the center-bottom resource lane;
13. the package builds and survives package verification/round-trip checks.

The next game run is one milestone test, not a sequence of one-binding experiments. It should verify tab switching, empty-tab behavior, focus after switching, representative automatic content, one simple A dispatch, top-level B, and nested/upcast B if naturally available.

## Probe status

The runtime probe remains useful as a compatibility/debug tool, but it is no longer considered a hard prerequisite.

The read-only installed-game capture closed the collection/materialization/cancel seam. Runtime 0.0.18–0.0.20 then proved that reconstructing the whole state/page leaves controller input dead even when rendering is correct. The next candidate therefore preserves the native page/state and changes only the controller library template resource. It may be tested only after static/package verification proves that ownership boundary.

## Visual policy

Do not clone the entire spell-preparation page.

Reuse BG3's interaction conventions:

- square spell/action icons;
- compact focus indicator;
- level/category headers;
- one scrollable surface;
- native tooltip behavior;
- controller focus rather than mouse-centric navigation.

The combat menu should be denser than Character Creation and should not include preparation-specific explanatory panels.
