# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

The mod intentionally reuses BG3-owned data and UI resources instead of reimplementing gameplay or drawing a separate visual system.

## Current status

**First in-game candidate.**

Current release line:

- native `DCHotBar` / `SpellsAndActions` data;
- native `HotBarSlotStyle` for action, upcast, item and passive cells;
- native Spell Book expander/group chrome;
- native `UseSlotCommand` dispatch;
- native `SingleHotBar` nested variants/upcast flow;
- automatic bounded first-run diagnostics.

The first game session is now intended to validate runtime-only behavior rather than discover basic architecture.

See [docs/first-run.md](docs/first-run.md) before the first launch.

## Target interaction

The intended combat menu is structurally similar to BG3's controller Spell Book:

```text
Actions
[ ][ ][ ][ ][ ][ ]

Cantrips
[ ][ ][ ][ ][ ][ ]

Level I
[ ][ ][ ][ ][ ][ ]

Level II
[ ][ ][ ][ ][ ][ ]

Items
[ ][ ][ ][ ][ ][ ]

Passives
[ ][ ][ ][ ][ ][ ]
```

Nested variants and upcast choices switch to the native `SingleHotBar` selection surface and return with B.

## Architecture

```text
BG3 native DCHotBar / character view models
                 |
                 v
      BG3 native UI resources
  HotBarSlotStyle / SpellBook chrome
                 |
                 v
        thin combat composition
      groups + six-column LSGrid
                 |
                 v
       native UseSlotCommand
```

The custom layer owns layout and state composition only. It must not reimplement spell availability, costs, targeting, upcasting, recasts, cooldowns, resources or execution.

## Development principles

- Controller-first.
- Reuse native BG3 data, templates and commands wherever possible.
- Keep the presentation layer thin.
- Prefer deterministic CI validation over repeated in-game testing.
- Manual testing occurs at explicit proof boundaries.
- First-run candidates must collect enough diagnostics to avoid blind retry cycles.

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [First in-game run](docs/first-run.md)

## References

- Larian UI modding setup: https://mod.io/g/baldursgate3/r/ui-basic-setup
- BG3 ImprovedUI: https://github.com/TheRealDjmr/BG3ImprovedUI
- BG3 Script Extender: https://github.com/Norbyte/bg3se
