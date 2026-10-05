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

It still needs one combined in-game milestone proof for navigation, B and one simple A dispatch. It remains an ordinary Script-Extender-free `.pak`.

## Xbox App installation

For normal use, download **`install-latest.cmd` once** and run it by double-clicking it.

It always finds the newest published GitHub Release (including prereleases), downloads the matching CAM PAK and PowerShell installer, verifies both SHA-256 digests, and runs the existing fail-closed Xbox installation automatically.

The first installation still requires one small mod to have been installed and enabled through BG3's built-in Mod Manager so CAM can prove the real Xbox cache and mirror the machine's actual load-order schema. After that, the same `install-latest.cmd` can be reused for every CAM update.

The Xbox App build does not use the ordinary Steam/GOG mod path in the same way, so CAM still does **not** hard-code `C:\WpSystem` or assume one cache location.

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
