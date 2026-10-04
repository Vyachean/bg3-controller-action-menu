# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

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

## Xbox App local development

The Xbox App build does not use the ordinary Steam/GOG mod path in the same way. The project therefore does **not** hard-code `C:\WpSystem` or assume one cache location.

Release `v0.0.8-xbox-discovery-first` and newer includes `install-xbox-dev.ps1`.

First establish ground truth by installing one small mod through BG3's built-in Mod Manager. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

This is read-only and creates `xbox-dev-environment.json`. Only when it finds one unambiguous cache containing both an existing PAK and a valid BG3 `modsettings.lsx` should installation be allowed:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply
```

See [Xbox App installation](docs/xbox-app-installation.md) and [Xbox App research](docs/research/xbox-app-modding.md).

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
