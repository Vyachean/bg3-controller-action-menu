# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native ActionRadials shell correction candidate.**

Runtime evidence now isolates the remaining problem:

- `0.0.18` proved `ControllerHotBars` data/materialization and populated Class / Actions / Items, but navigation/B failed;
- `0.0.19` was a rejected input-routing regression;
- `0.0.20` again rendered `Controller bars: 5` and all sections, but reported no widget/slot focus and all controller input remained dead.

`0.0.23-native-shell-focus` stops iterating on the fully custom `CAM_ActionMenu_c.xaml` root. It uses a native-named `ActionRadials.xaml` and preserves the captured Patch 8 root identity/lifecycle. Only the presentation template is custom.

Its focus tree mirrors the installed game's slot-assignment UI: outer `LSListBox` focus root with `SelectedIndex`, `LocalFocusSelector`, `ActionNext/ActionPrev`; focusable outer items; nested `LSListBox` grids; `LSGrid ContainerData="{Binding}"`; and native radial `LSButton` A/B primitives.

The one-click installer introduced in `0.0.22-hidden-one-click` is retained unchanged. This runtime candidate remains Script-Extender-free and is not claimed working until the next combined milestone proof.

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
