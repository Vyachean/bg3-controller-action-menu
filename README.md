# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native input-routing correction candidate.**

A read-only capture of the installed Xbox App build 1.8.910.0 established the current Patch 8 radial contract. The candidate now uses:

- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars` as the controller source;
- each bar's native `SlotList`;
- `SingleHotBar.SlotList` for nested variants/upcasts/containers;
- focus-driven scrolling following the page's `FocusedElement`;
- the native radial A seam: `UIAccept -> UseSlotCommand(focused slot)`;
- the native radial B switch: nested `ClearSingleHotbarCommand`, top-level `CustomEvent("CloseWidget")`.

`0.0.18-native-controller-contract` proved the controller data path and rendering in-game, but directional navigation and B failed. `0.0.19-native-input-routing` keeps the proven data path and replaces the custom input layer with BG3's navigable-grid flags plus player-scoped `LSInputBinding`.

It still needs one combined in-game milestone proof for navigation, B and one simple A dispatch. It remains an ordinary Script-Extender-free `.pak`.

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
PlayerCharacterProperties.ControllerHotBars
        |
        v
per-bar SlotList / SingleHotBar.SlotList
        |
        v
native HotBarSlotStyle visuals
        |
        v
thin custom grid composition
        |
        v
UIAccept -> native UseSlotCommand(focused slot)
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
