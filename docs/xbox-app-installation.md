# Xbox App / Microsoft Store PC installation

## Current development method

The project uses a **discovery-first** installer. It does not assume that `C:\WpSystem` exists and it does not write anything on its first run.

Each prerelease contains:

- `BG3ControllerActionMenu-*.pak`;
- `install-xbox-dev.ps1`.

## One-time preparation on the gaming PC

1. Launch Baldur's Gate 3 from Xbox App.
2. Open the built-in Mod Manager.
3. Install **one small mod from the built-in catalog** and enable it.
4. Exit BG3 normally.

The existing official/in-game-installed PAK becomes ground-truth evidence for the directory that this particular Xbox build actually uses.

## Phase 1 — discover only

Put the CAM `.pak` and `install-xbox-dev.ps1` in the same folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

This writes only `xbox-dev-environment.json` next to the script. It does not touch BG3 files.

The report contains:

- Windows BG3 package name, PackageFamilyName and version when available;
- game `InstallLocation` reported by Windows;
- package-data roots discovered under `%LOCALAPPDATA%\Packages`;
- any `WpSystem` candidate only as a fallback;
- actual `LocalCache\Local` paths;
- discovered `Mods` directories;
- number/names of existing `.pak` files;
- discovered `modsettings.lsx` files and whether their expected BG3 XML shape is valid;
- whether there is exactly one evidence-backed target safe enough for automatic installation.

## Phase 2 — install

Only if phase 1 prints:

`A unique, evidence-backed Xbox mod target was found.`

run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply
```

The installer then:

1. uses only the previously provable cache shape;
2. backs up `modsettings.lsx`;
3. backs up an existing CAM PAK if present;
4. copies the current CAM PAK into the proven Mods directory;
5. removes only stale entries for CAM UUID `c4be2039-13bf-4413-8d4f-2642f86d4a8e`;
6. adds exactly one CAM entry to `ModOrder` and one to `Mods`;
7. writes through a temporary XML file;
8. reopens and validates the resulting load order;
9. restores the original `modsettings.lsx` if verification fails.

## Fail-closed cases

The script refuses to write when:

- no BG3 Xbox package data can be found;
- no existing PAK proves which Mods directory the built-in manager uses;
- no valid `modsettings.lsx` exists;
- more than one profile/load-order file is plausible;
- more than one package cache is independently plausible;
- the BG3 XML structure is unexpected.

In those cases send `xbox-dev-environment.json`; no manual `WpSystem` editing is required.

## Why this approach

Microsoft documents modern PC GDK games as flat-file installs under a configurable `[drive]:\XboxGames`, so `C:\WpSystem` is not a universal game location. Microsoft also documents package-scoped user data under `%LOCALAPPDATA%\Packages\<PackageFamilyName>` for GDK storage scenarios.

Nexus Mods App currently documents BG3 support for Steam/GOG rather than Xbox App. Separate experimental Xbox-PC BG3 managers appeared on Nexus in September 2026 and explicitly describe a Microsoft mod cache / cached Xbox profile plus `Export Order to Game`; they provide independent evidence that the Xbox App build uses a different cache/profile path, but they are not an official Larian workflow and are build-specific.

See [research/xbox-app-modding.md](research/xbox-app-modding.md) for the evidence and source list.

## Subsequent development builds

Once the target has been proven on the machine, the same command with `-Apply` can be reused for later CAM packages. The UUID stays stable, so the installer replaces only CAM's PAK and refreshes its two load-order entries.
