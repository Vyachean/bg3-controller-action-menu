# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Captured Patch 8 list-grid correction candidate.**

A read-only capture of the installed Xbox App build 1.8.910.0 established the current Patch 8 radial contract. The candidate now uses:

- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars` as the controller source;
- each bar's native `SlotList`;
- `SingleHotBar.SlotList` for nested variants/upcasts/containers;
- focus-driven scrolling following the page's `FocusedElement`;
- the native radial A seam: `UIAccept -> UseSlotCommand(focused slot)`;
- the native radial B switch: nested `ClearSingleHotbarCommand`, top-level `CustomEvent("CloseWidget")`.

`0.0.18-native-controller-contract` proved the controller data path and rendering in-game, but directional navigation and B failed. `0.0.19-native-input-routing` then regressed rendering/data and is rejected.

`0.0.20-patch8-list-grid` returns to the proven 0.0.18 rendering/input base and changes the slot container to the exact current Patch 8 controller-grid hierarchy already present in `PreloadedActionRadials_c.xaml`: `LSListBox -> focusable ListBoxItem -> LSGrid`. Native radial `LSButton` A/B controls are retained.

`0.0.22-hidden-one-click` keeps that same runtime candidate and changes installation UX only (plus the visible diagnostic version marker).

It still needs one combined in-game milestone proof for navigation, B and one simple A dispatch. It remains an ordinary Script-Extender-free `.pak`.

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
