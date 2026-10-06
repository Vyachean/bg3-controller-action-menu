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

0.0.36 proves that assignment candidates cannot be treated as executable hotbar slots.

Prefer:

```text
native ActionRadials state/page
          |
current installed HotBar deck/resource filter semantics
          |
native VMHotBarSlot result set
          |
one flat controller grid
          |
focus -> tooltip/resource preview(slot)
          |
ActionRadials.Tag = slot
          |
native UseSlotCommand(slot)
          |
SingleHotBar grid when BG3 opens filter/container/upcast/variant results
```

The grid may reuse controller navigation primitives learned from the assignment screen, but **not** its raw candidate object model.

Do not implement spell execution, targeting, resource checks, upcast rules, recasts, passive semantics, inventory use or action classification ourselves.

Do not derive filters from `SlotType`, `SpellSlotLevel`, names, icons or hard-coded class resources. Use the installed current DCHotBar contract.

Do not expose the keyboard `Custom` deck or any radial editing workflow.

## Current milestone target — 0.0.37

Before another in-game run, static/package proof must establish all of the following together:

1. the top-level generated surface no longer binds assignment candidates from `SpellsAndActions`, passive predicates or `Inventory.Slots`;
2. the installer extracts current `HotBar.xaml` as an operational input alongside current ActionRadials resources;
3. concrete filter commands/properties used in shipping generation must exist in that current local hotbar source;
4. the visible action result surface is one flat `LSListBox + LSGrid + LocalFocusSelector`;
5. every result cell represents a native VMHotBarSlot wrapper and renders its `Content`;
6. focus writes that wrapper to `ActionRadials.Tag`;
7. focus invokes native tooltip/resource-preview commands for the same wrapper;
8. A remains `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
9. native `SingleHotBar.SlotList` remains the filter/container/upcast/variant result surface;
10. deck semantics include Common/Class/Items/Passives and exclude Custom;
11. resource/action filters are DCHotBar-owned, not CAM heuristics;
12. the original native button-hint container layout is not modified, and CAM-authored shoulder hints are absent;
13. radial editing remains unreachable;
14. package verification and round-trip checks pass.

The next game run is one milestone test. It should verify navigation from first to last rows and back, filter changes, resource-cost preview on focus, one simple A dispatch, one container/upcast transition, nested/top-level B, and native vertical button-hint layout.

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
