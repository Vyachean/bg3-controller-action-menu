# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Runtime contract reconstruction after the first Xbox App proof.**

The Xbox App build has already proven that CAM's `ActionRadials` override loads, but the early grid prototype does not yet materialize the current controller action collection correctly. It is therefore **not a usable release candidate**.

Current proven seams:

- Patch 8 still owns the controller `ActionRadials` state and `HotBar` context;
- Patch 8 `HotBarSlotStyle` still renders native slot types and dispatches through `UseSlotCommand` with the slot object;
- current UI code still exposes the live `HotBar.DataContext`, nested-hotbar state and per-bar `SlotList` objects;
- controller and keyboard hotbar state are distinct.

Current research target:

- identify the exact Patch 8 controller-radial collection/materialization path;
- preserve its native focus/paging/cancel behavior;
- change only presentation to a compact grid;
- request no further gameplay test until that contract is grounded in current evidence.

## Xbox App local development

The Xbox App build does not use the ordinary Steam/GOG mod path in the same way. The project therefore does **not** hard-code `C:\WpSystem` or assume one cache location.

Release `v0.0.9-xbox-schema-mirror` and newer includes the schema-grounded `install-xbox-dev.ps1`.

First establish ground truth by installing one small mod through BG3's built-in Mod Manager. Then run:

```powershell
powershell -NoExit -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

This is read-only and creates `xbox-dev-environment.json`. Only when it finds one unambiguous cache, an existing PAK, a valid BG3 `modsettings.lsx`, and one reusable schema written by an already-active in-game mod should installation be allowed:

```powershell
powershell -NoExit -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply
```

See [Xbox App installation](docs/xbox-app-installation.md) and [Xbox App research](docs/research/xbox-app-modding.md).

## Architecture

```text
BG3 ActionRadials state
        |
        v
   HotBar context
        |
        v
current controller slot collection
        |
        v
native HotBarSlotStyle
        |
        v
thin custom grid composition
        |
        v
native UseSlotCommand(slot)
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
