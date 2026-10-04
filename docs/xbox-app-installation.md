# Xbox App / Microsoft Store PC installation

## Why this is different

Baldur's Gate 3 on Xbox Play Anywhere uses a Microsoft package data/cache layout that differs from the Steam/GOG Win32 profile layout.

For this build, copying an external `.pak` only to:

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`

does not make the Xbox App version load it.

Fresh community reports identify the live mod cache under a path shaped like:

`<install drive>:\WpSystem\<user SID>\AppData\Local\Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw\LocalCache\Local\Mods`

The exact drive and SID vary by machine.

## Preferred long-term distribution

The clean target is the official BG3 Mod.io pipeline.

A Mod.io-installed PC mod is managed by the game's own Mod Manager and Microsoft package cache. Once this project is ready for wider testing, Mod.io should be the preferred installation channel for Xbox App users.

## Current development/testing path

Until the mod is published on Mod.io, external `.pak` testing on Xbox App is experimental.

A community-proven workflow is:

1. Launch BG3 from Xbox App.
2. Open the in-game Mod Manager once.
3. Exit BG3 normally.
4. Use an Xbox-PC-aware BG3 Mod Manager / compatibility build that targets the Microsoft mod cache.
5. Import this project's `.pak`.
6. Move it to Active Mods.
7. Export the load order to the Xbox profile/cache.
8. Launch BG3 again from Xbox App.
9. Check the in-game Installed tab and then test the mod.

A currently reported Xbox-PC compatibility tool supports Microsoft package **1.8.907.0** / game build **4.1.1.7445165**. Do not use a compatibility build against a different game/package version unless that build explicitly supports it.

## Manual cache inspection

Run:

`tools/find-xbox-mod-cache.ps1`

The script is read-only. It searches common Microsoft package locations and prints:

- detected Xbox package root(s);
- `LocalCache\Local`;
- candidate `Mods` directories;
- any `modsettings.lsx` files found underneath the package cache.

It does not copy files or change load order.

## Test-only warning

Community testing of raw external `.pak` mods on the Xbox App build has also reported save/reload problems.

For development builds:

- use a disposable save;
- avoid saving progress until the mod-loading method has been verified;
- prefer the official Mod.io pipeline before normal play.
