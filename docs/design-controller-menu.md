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

The main surface has two filter dimensions, both owned by BG3:

1. **type/deck filters** switched with LB/RB;
2. **resource filters** derived from the same action-resource preview model used by the keyboard hotbar.

Type filters:

```text
[ Common ] [ Class ] [ Items ] [ Passives ] [ Cantrips ]
```

They do not own separate action catalogs. Common/Class/Items select the current native shown deck, Passives uses the native passives hotbar, and Cantrips invokes BG3's own current cantrip filter.

The resource row comes from `CurrentPlayer.UIData.ActionResourcesCostPreview`. Focusing a resource entry invokes `FilterActionResourceCommand` with that native resource-preview object. CAM does not infer Action/Bonus Action/Spell Slot/class-resource membership.

The action grid displays native hotbar slot VMs. This is required for execution and container behavior; raw `SpellsAndActions`, inventory and passive assignment objects are not used as `UseSlotCommand` candidates.

Controller navigation follows the complete assignment-screen hierarchy: one outer scrollable list, inner resource/action grids with directional continuation, and one exact native-derived selector. Long lists are not given a fixed three-row height.

### Spell-level grouping

Cantrips are exposed through the native hotbar filter because that concrete command can be proof-gated against the user's installed `HotBar.xaml`. Other desired spell-level filters remain blocked until current installed-game evidence exposes the exact native commands/predicates. Do not classify them from `SpellSlotLevel`, action names, icons or CAM-owned heuristics.

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

Current `HotBarSlotStyle` remains useful for square native cell visuals. Its button DataContext is the native hotbar slot; the `VMCharacterAction` / `VMUpcast` / `VMItem` / `VMPassive` DataTemplates render that slot's content. Its `UseSlotCommand` parameter therefore supports the VMHotBarSlot path, not the raw assignment-catalog path rejected by 0.0.36.

## Architecture implication

Prefer:

```text
installed HotBar.xaml
  native deck/resource/cantrip filters
          |
          v
native VMHotBarSlot collection
          |
          v
assignment-style grid navigation
          |
          v
installed radial LocalFocusChanged lifecycle
          |
          +-- ActionRadials.Tag
          +-- HighlightResourcesCommand
          |
          v
UIAccept -> UseSlotCommand(slot)
          |
          v
SingleHotBar when BG3 opens a filter/container/variant/upcast
```

Do not use `ControllerHotBars[*].SlotList` as the automatic main menu and do not use raw radial-assignment catalog objects as gameplay dispatch candidates.

Radial editing commands (X/context menu, assign, swap, clear, add/remove slots) are not part of CAM.

Do not implement spell execution, targeting, resource checks, filter membership, upcast rules, recasts, passive semantics or inventory use ourselves.

## Current milestone target — 0.0.37

Before another in-game run, static/package proof must establish all of the following together:

1. the main execution grid binds native slot collections (`CurrentShownDeck.SlotList`, `PassivesHotBar.SlotList`, `SingleHotBar.SlotList` where BG3 owns nested/filter state);
2. raw `SpellsAndActions`, `Inventory.Slots` and `Stats.Passives` are absent from the main dispatch path;
3. current installed `HotBar.xaml` is extracted and required to expose the exact deck/resource/cantrip filter seams;
4. LB/RB tabs invoke native type/deck filters rather than switching independent catalogs;
5. resource filters use `ActionResourcesCostPreview` + `FilterActionResourceCommand`;
6. one outer assignment-style list owns vertical continuation and scrolling; child grids use directional continuation;
7. the old fixed three-row grid height is absent;
8. the exact installed `HotBarRadial.LocalFocusChanged` lifecycle is reused for slot Tag, focused-tooltip data and resource highlighting;
9. A remains `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
10. container/variant/upcast state remains `SingleHotBar`/BG3-owned;
11. the installed native button-hint stack is preserved and duplicate custom LB/RB hints are absent;
12. X/radial customization remains unreachable;
13. package/release verification succeeds.

The next game run is one milestone test: traverse a long grid down and back up, switch type filters, use at least one resource filter, execute one direct action, open one container/variant if naturally available, confirm the bottom resource-cost preview follows focus, confirm the native vertical hint stack, and verify top-level/nested B.

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
