# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of many radial wheels with a controller UI that scales to characters with large action sets.

Target interaction:

- open the action menu with the normal controller action-menu input;
- switch top-level categories such as **Actions**, **Spells**, **Items**, and **Class**;
- browse actions in a compact grid;
- filter spells by level when useful;
- navigate entirely with D-pad / stick;
- preserve Baldur's Gate 3 as the source of truth for action availability, costs, targeting, upcasting, recasts, and execution.

The mod should change presentation and navigation, not reimplement game rules.

## Status

**Research / technical spike.**

The first milestone is deliberately narrow: prove that a custom controller page can consume the same action data used by the game UI and dispatch a selected action through the existing game UI/action flow.

Do not treat the current repository as an installable mod yet.

## Design direction

Primary UI:

```
[ Actions ] [ Spells ] [ Items ] [ Class ]

[ All ] [ Cantrip ] [ I ] [ II ] [ III ] ...

┌──────┬──────┬──────┬──────┬──────┐
│      │      │      │      │      │
├──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │      │
└──────┴──────┴──────┴──────┴──────┘
```

A small favorites/quick radial may be added later, but it is not part of the first milestone.

## Development principles

- Controller-first.
- Reuse BG3 action data and execution semantics.
- Keep the presentation layer thin.
- Prefer deterministic validation over repeated in-game testing.
- Manual game testing happens at explicit milestones, not after every commit.
- Keep experimental assumptions documented and fail visibly when an assumption is unverified.

See [docs/architecture.md](docs/architecture.md) and [docs/testing.md](docs/testing.md).

## References

- Larian UI modding setup: https://mod.io/g/baldursgate3/r/ui-basic-setup
- BG3 ImprovedUI: https://github.com/TheRealDjmr/BG3ImprovedUI
