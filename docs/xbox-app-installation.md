# Xbox App / Microsoft Store PC installation

## Normal installation: double click, no console

Download **`BG3ControllerActionMenu-OneClickInstaller.zip`** from any current GitHub Release and extract it once.

For every install or update:

1. exit Baldur's Gate 3;
2. double-click `Install-BG3ControllerActionMenu.vbs`;
3. wait for the normal Windows result dialog.

No PowerShell or Command Prompt window is shown.

The launcher is reusable across releases. Its bootstrap has one stable responsibility:

1. find the newest published non-draft release;
2. download that release's `install-latest.ps1`;
3. run it.

The downloaded current installer then downloads only the files required by that release, derives the local PAK from the installed BG3 files, and installs it.

There is no bootstrap self-update protocol, release-asset hash verification, or duplicated UI/package validation on the user's PC. Those checks belong to CI before a release is published.

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

## Installation behavior

The normal installer performs only the operations needed to install:

- find the Xbox BG3 package/profile paths;
- download the current release payload;
- extract the native radial XAML from the installed game;
- generate the local CAM controller library;
- create the derived PAK;
- copy it into the Mods directory and update `modsettings.lsx`.

Semantic XAML checks, focus/A/B assertions, presentation literals, package round-trip checks and release-integrity test suites do **not** run during installation. They are CI/release gates.

Operational failures still stop installation naturally: missing game files, failed download/extraction/packing, no usable target profile, or failed file writes.

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
