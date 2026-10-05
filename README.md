# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native ActionRadials shell correction in development.**

The installed Xbox App 1.8.910.0 capture has already proven the controller data and gameplay command contract. Runtime builds also established a clear boundary:

- `0.0.18`: populated Class / Actions / Items, but no navigation/B;
- `0.0.19`: rejected input-routing regression;
- `0.0.20`: populated grid again, but no widget/slot focus and no controller input.

The project is therefore no longer iterating on the fully custom `CAM_ActionMenu_c.xaml` root.

The current architecture keeps the captured native `ActionRadials` root identity/lifecycle and changes only its presentation template. The focus hierarchy mirrors the current Patch 8 slot-assignment UI, including the outer `LSListBox` focus root, `LocalFocusSelector`, focusable outer items, inner `LSGrid ContainerData="{Binding}"`, and native radial `LSButton` A/B primitives.

No new in-game test is requested until this architecture passes static validation and package round-trip verification.

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
