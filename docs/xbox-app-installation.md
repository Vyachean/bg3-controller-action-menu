# Xbox App / Microsoft Store PC installation

## Recommended local-development workflow

For this project, do not use Mod.io or a patched third-party mod manager for every iteration.

Each GitHub prerelease includes:

- the versioned `BG3ControllerActionMenu-*.pak`;
- `install-xbox-dev.ps1`.

Put both files in the same folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

## One-time prerequisite

Before the first install:

1. Launch the Xbox App version of BG3.
2. Open the in-game Mod Manager once.
3. Exit the game normally.

This causes the Microsoft package cache/profile files to exist.

## What the installer does

The installer detects the Xbox package root, including the `WpSystem` layout used by Xbox Play Anywhere, then works only inside that package's `LocalCache\Local` tree.

It:

1. finds the released `.pak` next to the installer;
2. finds `LocalCache\Local\Mods`;
3. recursively finds `modsettings.lsx` under the Xbox cache;
4. if there are several profiles, chooses the most recently modified one and prints the candidates;
5. validates that `ModuleSettings`, `ModOrder` and `Mods` exist;
6. creates a timestamped backup of `modsettings.lsx`;
7. backs up the previous CAM `.pak` if present;
8. copies the new package as `BG3ControllerActionMenu.pak`;
9. removes stale entries for UUID `c4be2039-13bf-4413-8d4f-2642f86d4a8e`;
10. appends exactly one CAM entry to `ModOrder` and `Mods`;
11. reloads `modsettings.lsx` and verifies both entries.

If the structure is unexpected, the installer stops rather than generating a new load-order file from guesses.

## Dry run

To see what it would use without modifying files:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -DryRun
```

## Repository development

When working from a repository checkout, developers can instead run:

```powershell
.\tools\deploy-xbox-dev.ps1
```

That command builds the current version and then invokes the same tested installer.

## Why this is necessary

The Xbox Play Anywhere build uses a Microsoft package cache rather than the normal Steam/GOG user-mod path. Recent successful external-`.pak` reports use a path shaped like:

`<drive>:\WpSystem\<SID>\AppData\Local\Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw\LocalCache\Local\Mods`

and also move/export `modsettings.lsx` into the corresponding Xbox profile cache.

## Safety

- A backup is created before changing the load order.
- Other mods are preserved.
- Only this project's UUID is removed/re-added.
- The script is fixture-tested in CI for idempotence and preservation of unrelated mods.
- External `.pak` support on Xbox App remains unofficial; use a disposable save while testing.
