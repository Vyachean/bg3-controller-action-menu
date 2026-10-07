# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Self-contained Patch 8 runtime on the current development release line.**

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

The only LB/RB navigation dimension remains a controller cost/source row. Native resource previews from `ActionResourcesCostPreview` are the primary provider: selecting one invokes `FilterActionResourceCommand`, and the grid renders native `SingleHotBar.SlotList` slots. Passives use the proven `PassivesHotBar.SlotList` exception. There is no separate Live Details panel: focused cells use the ordinary BG3 tooltip. Native A/nested-state dispatch is retained, while radial customization remains unavailable.

The resource provider is **not treated as proof of a complete HotBar catalog**. CAM now has an explicit parity contract against both the keyboard HotBar and the radial assignment catalog. Known uncovered/proof-gated classes include free/no-resource actions, Cantrips, inventory/consumables, Scrolls, item-charge actions, metamagic toggles, temporary actions and recasts. See [Action coverage](docs/action-coverage.md).

The obsolete install-time `native-overlay.ps1` derivation path and its synthetic reference fixtures have been removed. The developer capture helper remains read-only evidence tooling only. It now derives a small `hotbar-coverage-contract.json` report containing the current native deck/filter command parameters, so future source work does not require manually inspecting raw captured XAML.

Resource-first semantics that depend on BG3 runtime materialization remain proof-gated. After green package CI, one combined milestone run should verify the remaining semantic parity questions rather than testing each source hypothesis separately.

## Universal development shortcut

`Install-BG3ControllerActionMenu.vbs` is a **temporary universal development shortcut** used only until CAM is delivered through the intended official mod-distribution path. The historical filename is kept for backward compatibility; the VBS is not limited to installation.

The operator keeps one VBS and double-clicks that same file for every development operation. On each run it resolves the newest published development release, downloads that release's `dev-entry.ps1`, and runs it hidden.

```text
same VBS
 -> newest published release
 -> dev-entry.ps1
 -> release-controlled task
      install/update | capture | diagnostics | ...
```

For development milestone `0.0.79-hotbar-coverage-capture`, `dev-entry.ps1` temporarily collects one read-only HotBar/radial evidence archive instead of installing the PAK. The same VBS remains the operator entry point.

For maintainers, a CI artifact is **not** a release. A development task becomes operator-visible only after the Release workflow publishes the corresponding `dev-entry.ps1` and assets. See [Release process](docs/release-process.md).

## Xbox App installation

For the current development workflow, extract **`BG3ControllerActionMenu-OneClickInstaller.zip`** once. Keep that folder: subsequent development installs/updates must use the same VBS without requiring a manual launcher refresh.

Then simply double-click:

`Install-BG3ControllerActionMenu.vbs`

There is no visible PowerShell or Command Prompt window. The launcher runs in the background and then shows a normal Windows success/error dialog.

Every run:

- the VBS itself checks the newest published GitHub Release;
- downloads that release's current `dev-entry.ps1` into `installer-work`;
- runs the release-controlled task;
- for the current install task, `dev-entry.ps1` downloads `install-latest.ps1`, which installs only the ready self-contained CAM PAK;
- after a successful legacy migration, the canonical installer refreshes the VBS and retires the obsolete local `bootstrap-latest.ps1`.

The extracted development folder is intentionally reusable. Internal scripts and even the kind of development task may change, but the same VBS remains the operator entry point.

One-time prerequisite: install and enable one small mod through BG3's built-in Mod Manager and exit BG3 normally. That proves the real Xbox Mods cache and provides the machine's actual `modsettings.lsx` schema.

The one-click folder is portable. Its `installer-work` directory beside the VBS launcher contains downloads, logs, status and diagnostics.

`installer-work\launcher-bootstrap.log` is created before any network request, so failures that happen before `dev-entry.ps1` is downloaded are still diagnosable.

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
- [Action coverage](docs/action-coverage.md)
- [Native UI reuse](docs/native-ui-reuse.md)
- [Testing strategy](docs/testing.md)
- [Release process](docs/release-process.md)
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)


## Developer-only native capture

There is no second permanent capture VBS.

If fresh native UI evidence is needed, the next development release can make the same universal `Install-BG3ControllerActionMenu.vbs` run `capture-self-contained-inputs.ps1` through `dev-entry.ps1`. Capture may inspect `Game.pak` read-only and produce the evidence ZIP beside the launcher, but it remains development tooling and is never a dependency of the shipping PAK or normal install path.
