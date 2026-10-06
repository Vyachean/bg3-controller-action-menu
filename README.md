# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Self-contained Patch 8 runtime candidate on draft PR #56.**

A fresh Xbox App capture from game package **1.8.910.0** has now been consumed as the current runtime source of evidence. The shipping source contains a project-owned controller library at:

`Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`

and CI packages that file into the ordinary CAM `.pak`. Normal installation does not read `Game.pak`, invoke LSLib, generate XAML, or rebuild the package.

The current composition is:

```text
captured Patch 8 HotBar contract
  SetCurrentShownDeckCommand / FilterCantripsCommand
  ActionResourcesCostPreview / FilterActionResourceCommand
            |
            v
native VMHotBarSlot collections
  CurrentShownDeck.SlotList
  CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList
  SingleHotBar.SlotList
            |
            v
captured controller-radial focus lifecycle
  LocalFocus.DataContext -> ActionRadials.Tag
  CreateFocusedTooltipDataCommand
  HighlightResourcesCommand
            |
            v
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

The fresh capture corrected two stale development-fixture assumptions:

- current `SelectorAssign` has no hard-coded `Width`, `Height` or `Margin`;
- current radial focus uses `LocalFocus.DataContext`, with the native 70 ms delayed handoff, rather than `LocalFocus.Tag`.

The LB/RB tabs are semantic filters (Common, current class, Items, Passives, Cantrips), not independent raw action catalogs. Resource filters are native `ActionResourcesCostPreview` objects. `SingleHotBar.SlotList` remains BG3-owned for nested/container/upcast/variant state. Native A/B dispatch is retained, while radial customization is deliberately unavailable.

The obsolete install-time `native-overlay.ps1` derivation path and its synthetic reference fixtures have been removed. The developer capture helper remains read-only evidence tooling only.

This candidate is not yet claimed runtime-correct. Static/package CI must be green first; after that, one milestone in-game run should verify long-grid navigation, semantic filters, resource preview, A dispatch, one natural nested/container case, native hints, and top-level/nested B together.

## Development installer principle

The VBS installer is a **temporary development tool** used only until CAM is delivered through the intended official mod-distribution path. It has one job during development: one-click install/update of the newest usable build.

For maintainers, a CI artifact is **not** a release. A version is installer-ready only after the Release workflow publishes it and the canonical resolver confirms that it is the newest published version. See [Release process](docs/release-process.md).

It does **not** run semantic XAML checks, package round-trip verification, focus-contract assertions, SHA assertions, or release-test logic on the user's PC. Those belong to CI before publication.

The reusable launcher is intentionally small:

```text
VBS
 -> bootstrap-latest.ps1
 -> newest release's install-latest.ps1
 -> download the prebuilt self-contained PAK
 -> install it
```

The bootstrap never needs to understand a release-specific installer contract. It only downloads the newest `install-latest.ps1` and hands off.

## Xbox App installation

For the current development workflow, extract **`BG3ControllerActionMenu-OneClickInstaller.zip`** once. Keep that folder: subsequent development installs/updates must use the same VBS without requiring a manual launcher refresh.

Then simply double-click:

`Install-BG3ControllerActionMenu.vbs`

There is no visible PowerShell or Command Prompt window. The launcher runs in the background and then shows a normal Windows success/error dialog.

Every run:

- starts from a tiny stable `bootstrap-latest.ps1` bundled beside the VBS launcher;
- checks the newest published GitHub Release;
- resolves the newest published development release;
- downloads that release's current `install-latest.ps1`;
- the canonical installer downloads only the self-contained CAM `.pak` and `install-xbox-dev.ps1` for installation;
- installs that prebuilt PAK directly; it does not read or rebuild from BG3 game PAKs;
- after success, refreshes the VBS/bootstrap in the already-extracted development-installer folder from standalone release assets.

The extracted development-installer folder is intentionally reusable. Internal helper scripts/builds may change, but an existing VBS/bootstrap contract must continue to work without asking the tester to download a replacement launcher.

One-time prerequisite: install and enable one small mod through BG3's built-in Mod Manager and exit BG3 normally. That proves the real Xbox Mods cache and provides the machine's actual `modsettings.lsx` schema.

The one-click folder is portable. Its `installer-work` directory beside the VBS launcher contains downloads, logs, status and diagnostics.

The lower-level `install-xbox-dev.ps1` remains available for manual diagnosis/development.

See [Development VBS contract](docs/development-vbs.md), [Xbox App installation](docs/xbox-app-installation.md), and [Xbox App research](docs/research/xbox-app-modding.md).

## Architecture

```text
development evidence capture
  current BG3 XAML / native contracts
            |
            v
project-owned controller resources
  Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml
            |
            v
CI-built self-contained CAM .pak
            |
            v
development VBS
  download PAK -> copy to Mods -> update modsettings.lsx
```

See:

- [Architecture](docs/architecture.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Release process](docs/release-process.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)


## Developer-only native capture

If the implementation needs fresh native UI evidence, use `Capture-BG3ControllerArtifacts.vbs` together with `capture-self-contained-inputs.ps1`.

The capture is separate from installation: it reads the installed game without modifying it and writes the downloaded extraction tool, log, extracted UI files, manifest and final ZIP beside the VBS launcher. The ZIP is then used as development input for the self-contained package; end users do not need this step.
