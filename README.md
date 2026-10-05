# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Research reset — there is currently no runtime candidate worth testing.**

Runtime results through `0.0.25` invalidate the last implementation directions:

- CAM-owned page/state replacements can render controller data but lose the native focus/input lifecycle;
- replacing the whole `ActionRadialWidgetTemplate_P8` through the standard controller library hook activates the native page but still loses usable A/B/focus inside the replacement;
- `0.0.25-native-radial-visual-mirror` derives the installed game's native radial XAML and packages it under `Public/Game/GUI/...`, but produced **no visible in-game change**. Therefore that raw base-game resource-path override is not a proven mod UI hook.

Do not ask for another in-game run yet.

The captured Xbox App 1.8.910.0 controller contract remains valid: `ControllerHotBars`, `SlotList`, `SingleHotBar.SlotList`, native focus-driven scrolling, page-level A dispatch, and the native main/nested B switch are known. The unresolved problem is narrower: **which supported BG3 UI hook can restyle the existing controller radial without replacing its behavior**.

Next work is research-first:

1. finish the source audit of current controller-radial mods, especially RadialHotbarCustomization v0.8.0.0;
2. inspect current Auto-Sorting Hotbar controller support, Sticky Temporaries, and other 2026 implementations for concrete hooks;
3. reconcile those findings with Larian's supported UI model: controller Library, Pages, StateMachines, and restyling;
4. select the smallest hook that preserves the exact native `ActionRadials` behavior;
5. only then build one combined runtime milestone.

The shipping target remains an ordinary Script-Extender/DLL/native-loader-free BG3 `.pak`.

## Xbox App installation

For normal use, download **`BG3ControllerActionMenu-OneClickInstaller.zip`** from the newest GitHub Release and extract it once.

Then simply double-click:

`Install-BG3ControllerActionMenu.vbs`

There is no visible PowerShell or Command Prompt window. The launcher runs in the background and then shows a normal Windows success/error dialog.

Every run:

- starts from a tiny stable `bootstrap-latest.ps1` bundled beside the VBS launcher;
- checks the newest published GitHub Release;
- downloads and SHA-256 verifies that release's current `bootstrap-latest.ps1` and `install-latest.ps1`;
- automatically hands off to the newer bootstrap first if the bundled bootstrap is stale;
- the current canonical installer then downloads and verifies the release's base CAM `.pak`, `install-xbox-dev.ps1`, and `native-overlay.ps1`;
- extracts the exact current radial XAML from the installed BG3 `Game.pak`, applies the presentation-only mirror patch locally, packs the derived result, and runs the fail-closed Xbox installer.

After installing the self-updating launcher once, the extracted folder is intended to remain reusable even when the internal installer contract changes.

One-time prerequisite: install and enable one small mod through BG3's built-in Mod Manager and exit BG3 normally. That proves the real Xbox Mods cache and provides the machine's actual `modsettings.lsx` schema.

Logs and diagnostics are stored under `%LOCALAPPDATA%\BG3ControllerActionMenu`.

The lower-level `install-xbox-dev.ps1` remains available for manual diagnosis/development.

See [Xbox App installation](docs/xbox-app-installation.md) and [Xbox App research](docs/research/xbox-app-modding.md).

## Architecture

```text
installed BG3 Game.pak
        |
        v
native PreloadedActionRadials_c.xaml
        |
        | local install-time patch
        v
native Radial stays as invisible input/focus engine
        +
non-interactive grid mirrors Radial.LocalFocus.Index
        |
        v
locally derived CAM .pak
```

The native `ActionRadials` state/page, `ActionRadialWidgetTemplate_P8`, A/B commands, nested/swap behavior and PageView focus lifecycle are not reconstructed by CAM.

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
