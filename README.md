# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native page + controller-library override candidate.**

Runtime evidence now separates the problem clearly:

- `0.0.18` proved the captured `ControllerHotBars` data path, section rendering, native slot visuals and tooltips, but directional navigation and B were dead;
- `0.0.19` changed input transport and regressed both rendering and bindings;
- `0.0.20` restored rendering and used the captured LSListBox/LSGrid hierarchy, but controller focus/input was still completely dead;
- `0.0.21` and `0.0.22` changed installation UX only and did not change runtime behavior.

The common failure was architectural: CAM replaced the game's `ActionRadials` state/page and then tried to reconstruct the radial widget's lifecycle, focus and input contract.

`0.0.23-native-page-library-override` removes that replacement. BG3 now owns the original state and original `Mods/MainUI/GUI/Pages/ActionRadials.xaml` page. CAM contributes only a controller resource-library override for the page's `ActionRadialWidgetTemplate_P8` resource.

That preserves the native page name (`ActionRadials`), HotBar context, page-level focus lifecycle, automation identity and state-machine close events. The custom resource still presents the already-proven `ControllerHotBars` data as a compact grid and keeps the captured native `UseSlotBinding` / `CancelButton` command seams.

If the library override is not selected by BG3, the fallback is the game's normal radial page rather than a dead custom state.

The package remains an ordinary Script-Extender-free `.pak`.

## Xbox App installation

For normal use, download **`BG3ControllerActionMenu-OneClickInstaller.zip`** from the newest GitHub Release and extract it once.

Then simply double-click:

`Install-BG3ControllerActionMenu.vbs`

There is no visible PowerShell or Command Prompt window. The launcher runs in the background and then shows a normal Windows success/error dialog.

Every run:

- checks GitHub Releases, including prereleases;
- selects the newest published release;
- downloads that release's exact CAM `.pak` and current `install-xbox-dev.ps1`;
- verifies both files against GitHub's SHA-256 digests;
- runs the existing fail-closed Xbox installer.

So the extracted one-click installer can be kept and reused for future CAM updates.

One-time prerequisite: install and enable one small mod through BG3's built-in Mod Manager and exit BG3 normally. That proves the real Xbox Mods cache and provides the machine's actual `modsettings.lsx` schema.

Logs and diagnostics are stored under `%LOCALAPPDATA%\BG3ControllerActionMenu`.

The lower-level `install-xbox-dev.ps1` remains available for manual diagnosis/development.

See [Xbox App installation](docs/xbox-app-installation.md) and [Xbox App research](docs/research/xbox-app-modding.md).

## Architecture

```text
native BG3 ActionRadials state
        |
        v
native MainUI/Pages/ActionRadials.xaml
        |
        v
ActionRadialWidgetTemplate_P8 resource
        ^
        |
CAM Lib_Controller.xaml override
        |
        v
ControllerHotBars / SlotList grid
        |
        v
native UseSlotCommand / CloseWidget seams
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
