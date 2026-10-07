# Xbox App / Microsoft Store PC installation

## Development installation: double click, no console

This VBS workflow is temporary and exists only while CAM is not yet on its intended official delivery path.

Extract **`BG3ControllerActionMenu-OneClickInstaller.zip`** once. The same extracted launcher must remain usable for later development installs/updates without a manual VBS replacement.

For every install or update:

1. exit Baldur's Gate 3;
2. double-click `Install-BG3ControllerActionMenu.vbs`;
3. wait for the normal Windows result dialog.

No PowerShell or Command Prompt window is shown.

The development launcher is deliberately reusable across builds and development tasks. It has one stable responsibility:

1. find the newest published non-draft release;
2. download that release's `dev-entry.ps1`;
3. run it hidden.

The release-controlled entry decides the current task. Development milestone `0.0.80-hotbar-coverage-capture-fix` temporarily downloads `capture-self-contained-inputs.ps1` and performs read-only evidence capture; normal install releases use `install-latest.ps1` to install the already-built self-contained PAK.

There is no permanent local bootstrap and no second capture VBS. Existing legacy VBS+bootstrap folders migrate automatically after one successful legacy install.

The extracted installer folder is portable. Runtime installer state is stored beside the launcher under:

`installer-work`

Useful files there include:

- `dev-task.log`;
- `dev-status.txt`;
- `dev-report.json`;
- release-controlled helper/download caches.

The normal installer does not place its own cache, logs or temporary build output in `%LOCALAPPDATA%`.

The old console launcher is not the development path. The VBS is only a temporary tester-facing delivery bridge; it should be retired when the official mod-delivery path is ready.


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

- find the Xbox BG3 profile/mod target;
- download the current self-contained release PAK;
- copy it into the Mods directory;
- update `modsettings.lsx`.

It does not read `Game.pak`, extract XAML, download LSLib, generate UI resources, or create a new PAK on the user's machine.

Semantic XAML checks, focus/A/B assertions, presentation literals, package round-trip checks and release-integrity test suites do **not** run during installation. They are CI/release gates.

Operational failures still stop installation naturally: failed release download, no usable target profile, or failed file writes.

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


## Developer capture (not part of installation)

When fresh game UI evidence is required, the same universal VBS remains the operator entry point. A development release can make `dev-entry.ps1` download and run the read-only `capture-self-contained-inputs.ps1` helper.

That helper may download its extraction tooling under the portable working directory, inspect `Game.pak` read-only, and create `bg3-controller-action-menu-inputs-*.zip` beside the launcher.

This capture never writes to the game installation, profile, saves, or Mods directory. It exists only to supply development evidence for the self-contained release package.


## VBS lifecycle rule

The development VBS must not require routine manual updates. If a new development build needs different behavior, the existing VBS must obtain the current `dev-entry.ps1` automatically.

A change that requires the operator to download a new VBS merely because the current task changed is considered a regression.

Read-only extraction/capture helpers may be selected by the release-controlled entry when development needs fresh evidence. Those helpers prepare artifacts for development; they are not part of the final mod runtime or normal installation design.

See [Development VBS contract](development-vbs.md).
