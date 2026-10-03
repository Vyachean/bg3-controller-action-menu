# Architecture

## Objective

Replace the controller action browsing experience without replacing Baldur's Gate 3 gameplay semantics.

The intended architecture is:

```text
BG3 native action/UI model
          │
          ▼
  Action menu adapter
          │
          ├── category projection
          ├── spell-level projection
          └── presentation metadata only
          │
          ▼
 Controller grid / tabs
          │
          ▼
 native action dispatch / targeting flow
```

## Boundary

The custom layer should own:

- category grouping;
- ordering;
- grid layout;
- controller focus/navigation;
- tab/filter state;
- presentation-only persistence such as last selected tab.

The custom layer should not own unless unavoidable:

- whether an action is currently usable;
- spell slot/resource calculation;
- upcast rules;
- target validation;
- range/LOS checks;
- action execution;
- recast semantics;
- class resource semantics;
- temporary action lifetime.

## UI framework

Larian documents BG3 UI modding as XAML-based. Controller mode loads a controller-specific library and controller state machine. Pages are connected through the state machine.

Current official reference:
https://mod.io/g/baldursgate3/r/ui-basic-setup

Open-source ImprovedUI demonstrates the current mod folder shape and controller-specific XAML/state-machine files:
https://github.com/TheRealDjmr/BG3ImprovedUI

ImprovedUI is useful as a structural reference, but it does not currently expose a complete replacement implementation of the combat action radial in its public tree.

## Proposed logical model

The UI should consume a normalized view of native action entries:

```text
ActionEntry
  id/native identity
  display name
  icon
  availability/disabled state
  native category/type metadata
  spell level (when applicable)
  resource/cost presentation
  variant relationship (when applicable)
  native dispatch handle/binding
```

This is a conceptual contract, not a commitment to invent a new runtime data model. If BG3 bindings already expose a collection suitable for direct binding, prefer that.

## Navigation

Initial target:

- open action menu using the existing controller action-menu flow where possible;
- LB/RB: top-level tabs;
- D-pad / left stick: grid navigation;
- A: select/activate;
- B: back/close;
- secondary button: details if the native UI exposes an equivalent action.

Focus must remain deterministic when:

- switching tabs;
- filtering changes the item count;
- an action disappears;
- returning from targeting/variant selection.

## Tabs

Initial categories:

1. Actions
2. Spells
3. Items
4. Class

These are product-level categories. The exact mapping from native action metadata is part of the technical spike and must not be hard-coded before inspection of actual data.

## Spells

The preferred spell view is a grid with optional level filters:

- All
- Cantrip
- I
- II
- III
- ...

Upcast must continue through the native mechanism. The grid should not synthesize independent upcast actions unless that is how the native action model already represents them.

## Compatibility

UI mods can conflict when they modify the same UI state/page. Compatibility strategy must be based on the smallest possible override/extension after the target state is identified.

Do not copy whole vanilla pages unless the toolkit/API leaves no narrower extension point.

## Open questions

The technical spike must answer:

1. Which controller state/page owns combat action browsing in the current build?
2. Which view-model collection feeds radial entries?
3. Can that collection be rebound to a different ItemsControl/ListBox-style presentation?
4. How is a selected radial action dispatched?
5. Are variants/upcasts separate entries, nested collections, or state transitions?
6. What is the smallest state-machine change required?
7. Can the mod coexist with ImprovedUI without both replacing the same state?
