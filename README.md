# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require:

- Script Extender;
- Native Mod Loader;
- DLL injection;
- a Steam/GOG-specific executable layout.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**First Xbox App / no-Script-Extender in-game candidate.**

Current candidate:

- overrides controller `ActionRadials`;
- uses native `DCHotBar` data;
- renders `SpellsAndActions` with native `HotBarSlotStyle`;
- reuses Spell Book-style group chrome;
- keeps native `SingleHotBar` variants/upcast;
- includes a temporary on-screen diagnostic panel for the first Xbox run.

See [docs/first-run.md](docs/first-run.md).

## Installation on PC / Xbox App

Place the released `.pak` in:

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`

Then launch BG3, open **Mod Manager**, verify the mod appears under **Installed**, and enable it.

Do not install anything into the protected Xbox App game directory or `WpSystem`.

Official Larian manual-mod instructions use the same Local AppData Mods folder:
https://baldursgate3.game/mods-how-to/

## Architecture

```text
BG3 ActionRadials state
        |
        v
      DCHotBar
        |
        +--> SpellsAndActions
        +--> HotBars
        |
        v
BG3 native UI resources
HotBarSlotStyle / SpellBook chrome
        |
        v
thin custom grid composition
        |
        v
native BG3 action execution
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [First in-game run](docs/first-run.md)
