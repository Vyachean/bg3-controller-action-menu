# Xbox App / Microsoft Store PC installation

## Normal installation: double click, no console

Download **`BG3ControllerActionMenu-OneClickInstaller.zip`** from any current GitHub Release and extract it once.

For every install or update:

1. exit Baldur's Gate 3;
2. double-click `Install-BG3ControllerActionMenu.vbs`;
3. wait for the normal Windows result dialog.

No PowerShell or Command Prompt window is shown.

The launcher is reusable across releases. Every run:

1. queries the repository's GitHub Releases list, including prereleases;
2. selects the newest published non-draft release;
3. requires that exact release's `BG3ControllerActionMenu-<version>.pak`, `install-xbox-dev.ps1`, and `native-overlay.ps1`;
4. downloads all three files;
5. verifies both against the SHA-256 digests published by GitHub;
6. runs the downloaded fail-closed Xbox installer with `-Apply`.

It deliberately does **not** silently fall back to an older version when the newest release is malformed.

Installer state is stored under:

`%LOCALAPPDATA%\BG3ControllerActionMenu`

Useful files:

- `install-latest.log`;
- `install-status.txt`;
- `xbox-dev-environment.json`;
- verified downloads under `installer-cache\<release-tag>`.

The old console launcher is no longer the recommended path. The release ZIP is the normal user-facing installer.


## One-time preparation on the gaming PC

The safe Xbox installer still needs evidence from the game's own mod system.

Before the first CAM installation:

1. launch Baldur's Gate 3 from Xbox App;
2. open the built-in Mod Manager;
3. install **one small mod from the built-in catalog** and enable it;
4. exit BG3 normally;
5. double-click `Install-BG3ControllerActionMenu.vbs`.

That existing in-game-installed PAK proves which Mods cache this machine actually uses. Its active load-order entry also supplies the LSX schema that CAM mirrors instead of guessing a Steam/GOG or test-fixture layout.

This is a one-time prerequisite. Later CAM updates use the same one-click launcher.

## Fail-closed behavior

Double-click installation does **not** remove the existing safety checks.

The installer refuses to write when:

- no BG3 Xbox package data can be found;
- no existing PAK proves which Mods directory the built-in manager uses;
- no valid `modsettings.lsx` exists;
- no active non-CAM mod supplies a reusable load-order schema;
- active mods expose conflicting LSX schemas;
- more than one profile/load-order file is plausible;
- more than one package cache is independently plausible;
- the BG3 XML structure is unexpected;
- the newest GitHub Release does not contain exactly one expected CAM PAK and installer;
- a downloaded release asset does not match GitHub's SHA-256 digest.

In these cases the launcher reports failure and pauses. The underlying Xbox installer remains fail-closed; ambiguous cache/load-order discovery does not become an automatic write.

The generated `xbox-dev-environment.json` in the installer cache is the diagnostic artifact to inspect if installation is refused.

## What the underlying installer still does

After a unique target is proven, `install-xbox-dev.ps1`:

1. backs up `modsettings.lsx`;
2. backs up an existing CAM PAK if present;
3. copies the selected release PAK into the proven Mods directory;
4. removes only stale entries for CAM UUID `c4be2039-13bf-4413-8d4f-2642f86d4a8e`;
5. writes exactly one CAM load-order/module entry using the proven donor schema;
6. writes through a temporary XML file;
7. reopens and validates the result;
8. restores the original `modsettings.lsx` if verification fails.

## Advanced/manual mode

The PowerShell installer remains available in each release for diagnostics and development:

Discovery only:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

Install a specific PAK:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply -PackagePath .\BG3ControllerActionMenu-<version>.pak
```

Normal users should use the extracted one-click ZIP instead.

## Why this approach

Microsoft documents modern PC GDK games as flat-file installs under a configurable `[drive]:\XboxGames`, so `C:\WpSystem` is not a universal game location. Microsoft also documents package-scoped user data under `%LOCALAPPDATA%\Packages\<PackageFamilyName>` for GDK storage scenarios.

CAM therefore discovers the real Xbox cache/profile on the machine and keeps that evidence-based, fail-closed write path. The one-click launcher changes only how the latest release is acquired and invoked.
