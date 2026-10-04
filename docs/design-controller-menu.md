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

Top-level categories:

1. Actions
2. Spells
3. Items
4. Class / Passives

For **Spells**, do not start with separate level tabs. Mirror the native Spell Book / spell-preparation layout:

```text
SPELLS

Cantrips
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]

Level I
[ ][ ][ ][ ][ ]

Level II
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]

Level III
[ ][ ][ ][ ][ ]
```

The full category is one vertically scrollable surface. Controller focus moves naturally through the grid and the scroll view follows focus.

This preserves the user's key requirement: the available choices are visible spatially rather than hidden behind an arbitrary sequence of radial pages.

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

The controller Spell Book exposes a particularly useful model:

- `CurrentPlayer.SelectedCharacter.SpellBooks`;
- `ActionGroups`;
- a cantrip-group predicate;
- a spell-level-group predicate;
- action groups;
- passives and metamagic;
- native `VMCharacterAction` entries;
- an `LSGrid`-based icon layout with controller focus.

This means our desired menu is not a foreign UI concept; it is essentially a combat-oriented presentation of data structures BG3 already exposes elsewhere.

### Action radial

The old public radial page is Patch 2 Hotfix 1 and is no longer treated as a current data-source specification.

Current Patch 8 / 2026 evidence establishes the parts that matter independently:

- controller state/context: `ActionRadials` / `HotBar`;
- current native slot template: `HotBarSlotStyle`;
- native dispatch: owning `UIWidget.DataContext.UseSlotCommand`;
- dispatch parameter: the current slot object;
- current nested-state property: `CurrentSingleHotbarFilter`;
- current Patch 8 variant state: `IsShowingAContainerWithVariants`;
- current focus-scroll mechanism: `LSScrollViewer.ScrollToElement` following `FocusedElement`.

The exact controller-radial collection is still not published. A September-2026 production mod exposes `PlayerCharacterProperties.KeyboardHotBars[*].SlotList`, but engine mappings prove keyboard/controller state is distinct, so this cannot be used as the controller source.

## Architecture implication

Prefer:

```text
DCHotBar / selected-character native view models
                  |
                  v
       native-style grid presentation
                  |
                  v
           native UseSlotCommand
```

Do not implement spell execution, targeting, resource checks, upcast rules, recasts, or passive semantics ourselves.

## First functional target

The first functional replacement should prove:

1. the current radial state can load our presentation;
2. live native action entries can be rendered as focusable grid cells;
3. focused entry becomes the native command parameter;
4. `UIAccept` reaches `UseSlotCommand`;
5. `UICancel` exits cleanly.

Only after that proof should categorisation be made more sophisticated.

## Probe status

The runtime probe remains useful as a compatibility/debug tool, but it is no longer considered a hard prerequisite.

Open-source evidence is now enough to lock state, native slot rendering/dispatch and focus strategy, but not enough to name the controller collection. Do not build another gameplay candidate until that remaining collection/materialization seam is proven by a modern source or one read-only native-file capture.

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
