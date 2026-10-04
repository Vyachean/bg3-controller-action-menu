# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader, DLL injection, or a Steam/GOG-specific executable layout.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Important: Xbox App installation differs from Steam/GOG

The standard Steam/GOG user folder:

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`

is **not the active external-mod location for the Xbox Play Anywhere build**.

The Xbox App version uses a Microsoft package cache. Community-confirmed paths use a layout like:

`<drive>:\WpSystem\<user SID>\AppData\Local\Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw\LocalCache\Local\Mods`

External `.pak` files also need a valid Xbox-profile load order; copying a file alone may not activate it.

For local Xbox App development, the release includes `install-xbox-dev.ps1`. Put it next to the released `.pak` and run it once; it discovers the Microsoft cache, backs up the current load order, installs the mod and adds only this mod's UUID.

See [Xbox App installation](docs/xbox-app-installation.md) before testing.

## Current status

**First Xbox App / no-Script-Extender in-game candidate.**

Current candidate:

- overrides controller `ActionRadials`;
- uses native `DCHotBar` data;
- renders `SpellsAndActions` with native `HotBarSlotStyle`;
- reuses Spell Book-style group chrome;
- keeps native `SingleHotBar` variants/upcast;
- includes a temporary on-screen diagnostic panel for the first Xbox run.

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
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
