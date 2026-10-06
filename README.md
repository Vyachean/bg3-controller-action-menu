# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native hotbar-filter milestone candidate (`0.0.37-native-hotbar-filters`).**

Runtime through 0.0.36 has narrowed the architecture substantially:

- 0.0.27 proved BG3's own assignment-style controller grid can navigate inside `ActionRadials`;
- 0.0.29 proved cells and the native-derived focus selector can be aligned correctly;
- 0.0.35 proved LB/RB tabs render and switch;
- 0.0.36 disproved the remaining source-tab design: navigation breaks at longer grids, A/container opening still fails, resource preview is absent, and custom hint composition does not match the native radial.

The key correction is the execution data type. Current Patch 8 `HotBarSlotStyle` renders `VMCharacterAction`, `VMUpcast`, `VMItem` and `VMPassive` as **content of a native hotbar slot**; its command parameter is the surrounding `VMHotBarSlot`. The assignment catalog objects used by 0.0.35/0.0.36 are therefore no longer used as gameplay-dispatch candidates.

0.0.37 keeps the native `DCHotBar` workflow and composes two current BG3 contracts:

```text
installed keyboard HotBar.xaml
  type/resource filter commands
          |
          v
native VMHotBarSlot collections
  CurrentShownDeck.SlotList
  PassivesHotBar.SlotList
  SingleHotBar.SlotList
          |
          v
installed controller radial focus lifecycle
  LocalFocus.Tag -> ActionRadials.Tag
  CreateFocusedTooltipDataCommand
  HighlightResourcesCommand
          |
          v
UIAccept -> UseSlotCommand(slot)
```

The top LB/RB tabs are now **filters**, not independent catalogs:

- Common;
- current class;
- Items;
- Passives;
- Cantrips.

A resource-filter row is populated from `CurrentPlayer.UIData.ActionResourcesCostPreview`; focusing a resource uses BG3's own `FilterActionResourceCommand`. Cantrips use the current installed `FilterCantripsCommand`. Deck filters use the current installed `SetCurrentShownDeckCommand`.

The installer extracts both the current controller radial dictionary and the current keyboard `HotBar.xaml` from the user's installed `Game.pak`. Generation proceeds only against the exact command/property names present in that game version; no Larian XAML is committed or published.

Navigation also returns to the complete native assignment hierarchy: **one outer scrollable `LSListBox`** owns vertical continuation, while the resource/action grids inside it use `KeyboardNavigation.DirectionalNavigation="Continue"`. The old fixed three-row action-grid height is removed.

The installed native `ButtonHintsContainer` is preserved instead of restyled. CAM only disables the X/radial-customisation entry point. The extra custom LB/RB hint presenters from 0.0.36 are gone.

`SingleHotBar.SlotList` remains BG3-owned for filters, variants, containers and upcast choices. Radial customization (assign/swap/clear/add/remove wheel slots) remains outside CAM.

This candidate is statically/CI proof-gated but is **not yet claimed runtime-correct** until one milestone game test confirms navigation, action/container dispatch, resource highlighting, native button hints and filter behavior together.

## Installer principle

The user-side installer has one job: install the newest release.

For maintainers, a CI artifact is **not** a release. A version is installer-ready only after the Release workflow publishes it and the canonical resolver confirms that it is the newest published version. See [Release process](docs/release-process.md).

It does **not** run semantic XAML checks, package round-trip verification, focus-contract assertions, SHA assertions, or release-test logic on the user's PC. Those belong to CI before publication.

The reusable launcher is intentionally small:

```text
VBS
 -> bootstrap-latest.ps1
 -> newest release's install-latest.ps1
 -> download required release files
 -> build local BG3-derived PAK
 -> install it
```

The bootstrap never needs to understand a release-specific installer contract. It only downloads the newest `install-latest.ps1` and hands off.

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
- extracts the exact current radial XAML from the installed BG3 `Game.pak`, derives a controller library whose action pages use the native slot-assignment grid focus pattern, packs it locally, and runs the fail-closed Xbox installer.

After installing the self-updating launcher once, the extracted folder is intended to remain reusable even when the internal installer contract changes.

One-time prerequisite: install and enable one small mod through BG3's built-in Mod Manager and exit BG3 normally. That proves the real Xbox Mods cache and provides the machine's actual `modsettings.lsx` schema.

Logs and diagnostics are stored under `%LOCALAPPDATA%\BG3ControllerActionMenu`.

The lower-level `install-xbox-dev.ps1` remains available for manual diagnosis/development.

See [Xbox App installation](docs/xbox-app-installation.md) and [Xbox App research](docs/research/xbox-app-modding.md).

## Architecture

```text
installed Game.pak
      |
      v
native PreloadedActionRadials_c.xaml
      |
      | local extraction
      v
exact native ActionRadialWidgetTemplate_P8
      |
      +-- native A / B / nested / swap unchanged
      |
      +-- page slot renderer:
            native assignment-grid focus pattern
            LSListBox -> LocalFocusSelector -> LSGrid
      |
      v
locally generated Lib_Controller.xaml
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Release process](docs/release-process.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
