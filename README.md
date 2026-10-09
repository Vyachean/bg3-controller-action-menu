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
  CurrentShownDeck.SlotList (only native ItemHotBar in shipping CAM)
  CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList
  CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList
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

The resource provider is **not treated as proof of a complete HotBar catalog**. CAM now has an explicit parity contract against both the keyboard HotBar and the radial assignment catalog. The native keyboard-HotBar source side is now covered by resource/Cantrips/Items/Metamagic/Passives providers plus a final grouped `KeyboardHotBars[*].SlotList` fallback. Remaining proof-gated work is equality with the independent radial-assignment catalog, including free, scroll/charge, temporary, recast and mod-added radial-only cases. See [Action coverage](docs/action-coverage.md).

The obsolete install-time `native-overlay.ps1` derivation path and its synthetic reference fixtures have been removed. The developer capture helper remains read-only evidence tooling only. It now derives schema-v4 `hotbar-coverage-contract.json` by searching the whole captured XAML set. Besides HotBar command/source probes, it records structured controller-input transport evidence for weapon-set symbols, including **DataContext separately from visual Content**, BoundEvent, hold/tap thresholds, commands, styles, setter values, raw tags and source files. This distinction matters for `ControllerHoldButtonStyle`: an input-event object bound through DataContext is not interchangeable with a visual hint placed in Content. Missing research seams are evidence rather than capture failures.

Dynamic resource overflow is handled by a bounded resource-only `LSScrollViewer`: the selected concrete resource container is the scroll target, and the captured Patch 8 `TargetPositionChanged -> HorizontalScrollOffset = TargetPosition` commit keeps it visible. Special provider tabs remain fixed outside that viewport.

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

Milestones 0.0.80–0.0.86 used this entry for read-only native HotBar/radial capture. That capture has now been inspected (see [schema-v3 readback](docs/research/schema-v3-capture-2026-10-08.md)). Starting in 0.0.87, the same VBS returns to the normal self-contained PAK **install/update** task. In **0.0.92**, the release-controlled task temporarily switches back to a **read-only resource-dictionary capture** because 0.0.91 did not correct the keyboard vs controller resource glyphs. Running the existing VBS for this milestone creates a new ZIP beside the launcher; it does **not** install a new gameplay mod package. It downloads the release-controlled `install-latest.ps1` and installs through the existing Xbox helper; no manual launcher replacement is necessary. Capturing native evidence remains an optional developer operation.

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
- for the current capture milestone, `dev-entry.ps1` downloads `capture-self-contained-inputs.ps1` and creates the read-only evidence ZIP beside the VBS;
- this milestone does not change the installed CAM package or BG3 profile state.

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


### Current operator task (0.0.92)

Run the **same existing VBS once** to collect the keyboard/controller resource style dictionaries missing from the previous archive. It reads Game.pak only, does not launch BG3 and does not install/update the PAK. Upload the resulting `bg3-controller-action-menu-inputs-*.zip`; the required new members are `DataTemplates_k.xaml`, `DataTemplates_c.xaml` and `ActionResourceTemplates_c.xaml`. Do not test CAM icons in game for this capture-only version.


### 0.0.93 resource-indicator appearance

The 0.0.92 dictionary capture is complete. Release 0.0.93 restores
the one-file development VBS to normal self-contained PAK installation
and adapts the native controller resource preview to the exact
installed keyboard HotBar point-group template and local sizes.
The operator does **not** need another capture. In-game visual
parity remains to be confirmed; the 0.0.91 glyph workaround is retired.


### 0.0.94 temporary visual diagnostic

The successful v0.0.93 installation did not fix controller resource
icons. Version 0.0.94 is intentionally a diagnostic package **not** a
finished UI release. The same VBS installs it normally. Every native
resource tab temporarily displays a yellow `94` and a magenta `B`
reference icon while preserving the original point symbols. A single
in-game screenshot of the resource tab strip establishes which renderer
or image source is actually active. Remove this overlay in the next
evidence-based fix.


### 0.0.95 native point-glyph correction candidate

Diagnostic 0.0.94 confirmed the current XAML was loading, and that
the independent bounded icon could display compactly while the
unbounded native point was enlarged/clipped. 0.0.95 removes the
diagnostic marks and constrains **each** native resource-point
image to 24x24 uniform scaling while retaining the native resource
group/availability logic. This is a visual correction candidate
awaiting game verification, not a completed parity claim.


### 0.0.96 — native keyboard HotBar resource indicators

The v0.0.95 per-point scaling approach was visually unsuccessful.
v0.0.96 replaces that approximation with the **complete 24-template
resource-group block from the installed Patch 8 keyboard HotBar**,
scoped to CAM's resource tabs. This preserves the native selector,
original resource-state images and animations, and LB/RB controls.
The release requires an in-game screenshot for final parity acceptance.


### 0.0.97 read-only resource-theme research

v0.0.96 did not achieve visual parity. v0.0.97 temporarily sets the
**same universal VBS** back to a read-only Game.pak input collection
to capture the original keyboard/controller theme style XAML that
was absent from the previous archive. It does not install a modified
gameplay PAK or launch BG3. The output ZIP is created beside the VBS.
This evidence is needed before another rendering fix can be justified.


### 0.0.98 native keyboard resource icons

The 0.0.97 archive was created successfully even though its
post-capture status errored on an incorrect expected filename.
It proved that keyboard and controller modes use distinct
resource-point bitmap directories. Version 0.0.98 now scopes
the **original keyboard bitmap path strings and unmodified native
point DataTemplate** inside the resource tabs, retaining all 24
original keyboard group templates from 0.0.96. No guessed image
sizes and no replacement icon assets. The existing universal VBS
has resumed normal mod installation; no further capture is needed.
In-game visual parity remains to be confirmed.
