# Xbox App / Microsoft Store PC modding research

Last reviewed: 2026-10-04.

## Conclusions

1. The Xbox App / Play Anywhere PC build must not be treated as the Steam/GOG build.
2. `C:\WpSystem` is not a universal required location. Modern PC GDK installs normally expose game files under a configurable `[drive]:\XboxGames` directory, while per-user package data may also exist under `%LOCALAPPDATA%\Packages\<PackageFamilyName>`.
3. Larian's official documentation does not provide a supported manual path for injecting an unpublished external `.pak` specifically into the Xbox App PC build.
4. Nexus Mods App itself documents BG3 support for Steam/GOG, not Xbox App; its general Xbox Game Pass support remains incomplete.
5. In September 2026 Nexus received Xbox-PC-specific BG3 manager packages. Their descriptions explicitly state that they detect a Microsoft mod cache / cached Xbox profile and export `modsettings.lsx` there. This independently confirms that Xbox PC uses a different mod-cache/profile path from normal Steam/GOG BG3.
6. Those Xbox-specific Nexus packages are experimental, build-specific, community tools. At least one corresponding Nexus page is currently under moderation. They are evidence for the storage model, not a dependency of this project.
7. Patch 7+ third-party `.pak` mods should be treated as load-order entries. Do not assume the old pre-Patch-7 `Override` behavior means `modsettings.lsx` can be skipped.

## Sources

### Microsoft GDK

- https://learn.microsoft.com/en-us/xbox/gdk/docs/features/common/packaging/overviews/packaging-getting-started-for-pc
  - PC GDK packages use flat-file installs under `[drive]:\XboxGames` by default.
  - PC GDK mods are supported by default.
- https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/packaging-flatfileinstall
  - players can choose the game drive and modify game resources directly.
- https://learn.microsoft.com/en-us/xbox/gdk/docs/features/common/game-save/game-saves-walkthroughs-and-samples
  - package-scoped user data uses `%LOCALAPPDATA%\Packages\<PACKAGE_NAME>` for GDK save providers.

### Nexus Mods App

- https://github.com/Nexus-Mods/NexusMods.App/blob/main/docs/developers/games/0003-BaldursGate3.md
  - BG3 supported stores are Windows Steam/GOG, Linux Steam/GOG and macOS Steam/GOG.
  - documents `modsettings.lsx` as the PAK load-order source for supported PC builds.
- https://github.com/Nexus-Mods/NexusMods.App/blob/main/CHANGELOG.md
  - Xbox Game Pass support was disabled / remains unfinished in Nexus Mods App.

### Xbox-PC-specific BG3 community tooling on Nexus

- Nexus page https://www.nexusmods.com/baldursgate3/mods/25204
  - currently shown by Nexus as under moderation (since 2026-09-22).
- Nexus RSS copies preserve descriptions for `BG3 Mod Support for the Xbox App on PC`, `BG3 Xbox Mod Manager`, and `Xbox PC and Microsoft Store Mod Support`.
  - these describe a manager configured for the Microsoft mod cache;
  - automatic detection of game/profile with a manual `Content` folder fallback;
  - import -> Active Mods -> Export Order to Game;
  - backups / rollback;
  - exact support target package 1.8.907.0 / engine 4.1.1.7445165.
  - therefore these tools cannot be assumed compatible with later builds.

### Current third-party PAK/load-order behavior

- https://github.com/Nexus-Mods/NexusMods.App/blob/main/docs/developers/games/0003-BaldursGate3.md
  - PAK mods are loaded according to `modsettings.lsx`.
- https://www.nexusmods.com/baldursgate3/mods/680
  - current Patch 8 mod author explicitly notes that the old `Override` concept no longer avoids normal activation/list handling after Patch 7.

## Development policy derived from the evidence

The release installer must not hard-code `WpSystem` as the normal path and must not select the newest profile by guesswork.

Instead:

1. query Windows package identity dynamically with `Get-AppxPackage`;
2. inspect `%LOCALAPPDATA%\Packages\<PackageFamilyName>` first;
3. treat `WpSystem` only as a read-only fallback candidate;
4. require an already-existing `Mods` directory containing at least one `.pak` installed through BG3's in-game manager;
5. require exactly one valid `modsettings.lsx` in the same package cache;
6. report everything without changes by default;
7. require explicit `-Apply` before writing;
8. back up load order and the previous CAM PAK;
9. modify only CAM's UUID;
10. fail closed on multiple profiles, multiple plausible caches, missing evidence or unknown XML shape.

This gives the first run on the user's PC a ground-truth anchor from the game itself rather than relying on a Reddit path or a third-party manager's assumptions.
