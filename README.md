# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Research reset — there is currently no runtime candidate worth testing.**

Runtime results through `0.0.25` invalidate the last three implementation directions:

- custom CAM page/state can render controller data but loses the native focus/input lifecycle;
- replacing the whole `ActionRadialWidgetTemplate_P8` through `Lib_Controller.xaml` activates the native page but still leaves the replacement template without usable A/B/focus;
- `0.0.25-native-radial-visual-mirror` derives `Public/Game/GUI/.../PreloadedActionRadials_c.xaml` locally, but the installed mod produces **no visible UI change at all**. That means this raw base-game resource-path override is not a proven runtime hook for a normal CAM mod PAK and must not be treated as architecture.

Do not ask for another in-game run yet.

The next work is research-first:

1. finish the source audit of current controller-radial mods, especially RadialHotbarCustomization v0.8.0.0 and current 2026 radial sorting/customisation implementations;
2. distinguish **data/storage APIs** from the **supported UI hook** that can actually restyle an existing controller page;
3. re-read Larian's current UI modding model (Library / Pages / StateMachines / restyling) against the successful and failed runtime evidence;
4. design the smallest hook that preserves the exact native `ActionRadials.xaml` root and current native controller behavior;
5. only then build one new milestone candidate.

The captured Xbox App 1.8.910.0 controller contract remains valid and useful: `ControllerHotBars`, `SlotList`, `SingleHotBar.SlotList`, native focus-driven scrolling, page-level A dispatch, and the native main/nested B switch are already known. The unresolved problem is **where/how to restyle the native controller UI without replacing its behavior**.

The shipping target remains an ordinary Script-Extender/DLL/native-loader-free BG3 `.pak`.

## Xbox App installation

For normal use, download **`BG3ControllerActionMenu-OneClickInstaller.zip`** from the newest GitHub Release and extract it once.

Then simply double-click:

`Install-BG3ControllerActionMenu.vbs`

There is no visible PowerShell or Command Prompt window. The launcher runs in the background and then shows a normal Windows success/error dialog.

Every run:

- checks GitHub Releases, including prereleases;
- selects the newest published release;
- downloads that release's base CAM `.pak`, `install-xbox-dev.ps1`, and `native-overlay.ps1`;
- verifies all three files against GitHub's SHA-256 digests;
- extracts the exact current radial XAML from the installed BG3 `Game.pak` and applies the presentation-only mirror patch locally;
- packs that locally derived result and runs the existing fail-closed Xbox installer.

So the extracted one-click installer can be kept and reused for future CAM updates.

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
