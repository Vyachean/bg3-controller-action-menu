# BG3 Controller Action Menu

A controller-first action menu replacement for **Baldur's Gate 3**.

## Goal

Replace the default sequence of radial wheels with a controller-native grid that reuses Baldur's Gate 3's own Spell Book / spell-preparation UI language and native action execution path.

## Runtime compatibility

The shipping mod is an ordinary BG3 `.pak` and does **not** require Script Extender, Native Mod Loader or DLL injection.

The primary target includes the **Xbox App / Microsoft Store PC build**.

## Current status

**Native slot-assignment grid, presentation cleanup candidate.**

Runtime evidence through `0.0.25` now rules out three earlier approaches:

- CAM-owned replacement page: rendered data but controller focus/B stayed dead;
- hand-written replacement `ActionRadialWidgetTemplate_P8`: native page loaded but interaction still died;
- `Public/Game/GUI/...` resource override from the mod PAK: `0.0.25` produced no visible change at all.

The current Patch 8 `PreloadedActionRadials_c.xaml` already contains the controller grid we need: the UI used when choosing an action to insert into a radial. It uses `LSListBox + LocalFocusSelector + focusable ListBoxItem + LSGrid` with `UIUp/UIDown/UILeft/UIRight`.

`0.0.27-native-slot-assignment-grid` proved that exact focus/navigation pattern works in-game. It rendered real grids, but they inherited radial-page positioning/chrome: upper-left anchoring, circular radial shadows and the “Radial Customisation” hint.

`0.0.28-grid-presentation-cleanup` keeps the proven 0.0.27 focus/input path unchanged and fixes only that presentation: grids are centered in their PageViews, radial backdrop ellipses are collapsed, and the visible hint strip is converted to compact grid chrome without the radial-specific customization prompt.

At install time CAM extracts the exact native radial dictionary from the user's installed `Game.pak` and locally generates `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.

The generated library preserves the exact native:

- `ActionRadialWidgetTemplate_P8`;
- `RadialHotBarListItemContainer`;
- A/B bindings;
- nested/upcast/container switching;
- swap-slot semantics;
- PageView and state-machine lifecycle.

Only the two page-view slot renderers are transformed:

```text
ls:Radial
   ↓
LSListBox + LocalFocusSelector
   ↓
LSGrid(UIUp / UIDown / UILeft / UIRight)
```

The focused slot still updates `ActionRadials.Tag`, and A remains BG3's native `UseSlotCommand(Tag)`. B remains BG3's native top-level/nested switch.

No Larian XAML is committed to or distributed by this repository. The generated controller library exists only on the user's machine. Runtime remains Script-Extender/DLL/native-loader free.

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
- [Xbox App installation](docs/xbox-app-installation.md)
- [First in-game run](docs/first-run.md)
