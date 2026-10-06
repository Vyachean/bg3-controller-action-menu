# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Per-tab native focus/dispatch milestone candidate (`0.0.36-tab-focus-dispatch`).**

Runtime evidence through `0.0.25` now rules out three earlier approaches:

- CAM-owned replacement page: rendered data but controller focus/B stayed dead;
- hand-written replacement `ActionRadialWidgetTemplate_P8`: native page loaded but interaction still died;
- `Public/Game/GUI/...` resource override from the mod PAK: `0.0.25` produced no visible change at all.

The current Patch 8 `PreloadedActionRadials_c.xaml` already contains the controller grid we need: the UI used when choosing an action to insert into a radial. It uses `LSListBox + LocalFocusSelector + focusable ListBoxItem + LSGrid` with `UIUp/UIDown/UILeft/UIRight`.

`0.0.27-native-slot-assignment-grid` proved that exact focus/navigation pattern works in-game. It rendered real grids, but they inherited radial-page positioning/chrome: upper-left anchoring, circular radial shadows and the “Radial Customisation” hint.

`0.0.28-grid-presentation-cleanup` centered the grids and removed the radial backdrop. Runtime then exposed a narrower layout bug: the focus selector stayed in the PageView's old upper-left coordinate space because it was no longer colocated with the centered list.

`0.0.29-focus-origin-fix` completed the grid/focus proof: cells and focus now align correctly in-game.

`0.0.35-native-action-tabs` proved that the native tabs themselves render and switch in-game, but also exposed a composition defect: all tabs shared one outer `HotBarList.LocalFocus`. The visible tab changed while tooltip/dispatch focus could remain owned by the first tab, A received the wrong/stale candidate, the generic selector no longer matched assignment-cell geometry, and the centered footer hints overlapped the native action-resource lane.

`0.0.36-tab-focus-dispatch` removes that shared focus owner. Each tab now has its own assignment-style list, its own exact locally extracted `SelectorAssign`, and its own single writer to `ActionRadials.Tag`. Tab changes move focus directly to the selected list. The native footer hints return to their right-side lane.

The next architecture removes the remaining radial dependency. The main grid no longer reads `ControllerHotBars[*].SlotList`. Instead it uses the same automatic collections as BG3's native “choose action for radial slot” screen: `SpellsAndActions`, togglable passives/metamagic and inventory items. That means available actions appear automatically instead of requiring radial-wheel maintenance.

Radial customization (X / assign / swap / clear / add / remove wheel slots) is removed from CAM entirely.

The main catalog is now presented as controller tabs over those same native sources: `Actions / Spells`, `Items`, `Passives`, and an empty-filtered `Metamagic` tab. `UITabPrev` / `UITabNext` switch tabs. There is no `Custom` tab and tab selection never changes gameplay semantics.

Fine-grained Cantrip / spell-level headings are intentionally **not** guessed from `SpellSlotLevel` or the old public SpellBook dump. The historical predicate names remain research evidence until the current installed Patch 8 SpellBook contract proves them.

At install time CAM extracts the exact native radial dictionary from the user's installed `Game.pak` and locally generates `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.

The generated library preserves the exact native outer/template lifecycle needed for:

- `ActionRadialWidgetTemplate_P8`;
- A/B bindings;
- nested/upcast/container switching;
- `SingleHotBar` second-stage behavior;
- PageView and state-machine lifecycle.

The main surface itself uses locally extracted assignment-grid resources instead of radial slot containers. Radial editing commands are not retained as CAM functionality.

The main surface now reuses the native assignment catalog:

```text
[Actions / Spells] [Items] [Passives] [Metamagic*]
            ↓  UITabPrev / UITabNext
native automatic source selected for presentation
            ↓
AssignList-style LSListBox + LocalFocusSelector
            ↓
nested LSGrid groups
            ↓
ActionRadials.Tag
            ↓
UseSlotCommand
```

`SingleHotBar.SlotList` remains the native nested/upcast/variant surface. B remains BG3's native close/nested-cancel path.

No Larian XAML is committed to or distributed by this repository. The generated controller library exists only on the user's machine. Runtime remains Script-Extender/DLL/native-loader free.

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
