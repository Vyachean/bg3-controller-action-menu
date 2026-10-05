# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native-radial visual-mirror candidate.**

Runtime evidence through `0.0.24` established that replacing either the page or the whole `ActionRadialWidgetTemplate_P8` breaks the native controller focus/input graph even when the grid renders correctly. In `0.0.24`, the native page was active — radial movement sounds played — but the replacement template still had no usable focus, A or B.

`0.0.25-native-radial-visual-mirror` stops reconstructing that input graph.

At install time, CAM now reads the exact `PreloadedActionRadials_c.xaml` files from the user's installed `Game.pak`, preserves the native page/template/PageView/Radial/A/B/nested/swap logic, and applies only a local presentation patch:

- the original native `HotBarRadial` and `SingleBar` controls remain present and continue to own input/focus;
- those native radial visuals are made transparent;
- a non-interactive grid mirrors the same items;
- grid selection mirrors the native radial's `LocalFocus.Index`.

The modified native files are generated locally and packed into the installed CAM PAK. **Larian XAML is not committed to this repository or distributed in the GitHub release.**

The published release PAK is therefore metadata/bootstrap only. The one-click installer downloads a pinned overlay builder, verifies its GitHub SHA-256 digest, derives the installable PAK from the locally installed BG3 version, then installs it through the existing fail-closed Xbox path.

The runtime remains Script-Extender/DLL/native-loader free.

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
