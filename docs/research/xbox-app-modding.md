# Xbox App / Microsoft Store PC modding research

Last reviewed: 2026-10-04.

## Current conclusion

The safest local-development path is **discovery first, write only from machine-local evidence**:

1. let BG3's built-in Mod Manager install and enable at least one catalog mod;
2. discover the real package cache and signed-in `PlayerProfiles` order read-only;
3. require exactly one Mods directory and one profile `modsettings.lsx` with `ModuleSettings/root/Mods`;
4. mirror an existing active `ModuleShortDesc` schema when adding CAM;
5. back up, write atomically, verify, and fail closed on ambiguity.

Do not hard-code `C:\WpSystem`, do not select a profile by recency, and do not assume the Steam/GOG `%LOCALAPPDATA%\Larian Studios\...` layout applies to Xbox App.

## Evidence by confidence

### Official / documented

- Microsoft GDK documents modern PC game installs as modifiable flat files under a configurable `[drive]:\XboxGames` location. `C:\WpSystem` is therefore not a universal game-install location.
- Windows/MSIX documentation identifies redirected per-package data under `%LOCALAPPDATA%\Packages\<PackageFamilyName>\LocalCache`; Microsoft GDK save documentation likewise uses `%LOCALAPPDATA%\Packages\<PACKAGE_NAME>` for package-scoped PC data.
- Larian's official Toolkit installation guide currently documents Toolkit setup for **Steam and GOG**. It does not document the Xbox App build as a Toolkit development target.
- Larian/mod.io documents the built-in Mod Manager as the supported way to browse/install/manage supported mods.
- Nexus Mods App's current BG3 integration lists Windows Steam/GOG, Linux Wine Steam/GOG, and macOS Steam/GOG. Xbox App / Microsoft Store is not listed.

These sources establish platform/storage boundaries, but they do **not** by themselves establish BG3's exact Xbox `LocalCache\Local\Mods` path.

### Confirmed by source code

The current community Xbox compatibility project is:

- `titoreinaldo/bg3-xbox-pc-mod-support`
- Nexus BG3 mod **25204** (`BG3 Mod Support for the Xbox App on PC`), currently shown by Nexus as under moderation.

Current GitHub prerelease **0.2.3**:

- accepts Microsoft package **1.8.907.0 or newer** and engine build **7445165 or newer**;
- retains package name `LarianStudiosGamesLtd.baldurssgate3`, publisher identity, and x64 checks;
- was reported by its maintainer to launch on Microsoft package **1.8.910.0** on 2026-10-03;
- did **not** receive a fresh gameplay/save-load validation pass for 0.2.3.

Its BG3 Mod Manager patch documents a Microsoft-specific cached profile/order view, two directory junctions in `ManagerView`, Microsoft AUMID launch, and a live export whose XML survived a game startup unchanged. This is strong implementation evidence, but it remains an unofficial prerelease and is **not** a dependency of CAM.

The current upstream BG3 Mod Manager source is more important than the older `ModOrder` assumption:

- `XML_MOD_SETTINGS_TEMPLATE` contains `ModuleSettings/root/Mods` only;
- each active entry is a `ModuleShortDesc`;
- `GenerateModSettingsFile` serializes active mods in list order;
- `LoadModSettingsFileAsync` reads that same `Mods` list in file order;
- the current template does **not** require a separate `ModOrder` node.

Each `ModuleShortDesc` contains `Folder`, `MD5`, `Name`, `PublishHandle`, `UUID`, and `Version64`; the template uses `uint64` for `PublishHandle`, `guid` for `UUID`, and `int64` for `Version64`.

A real Microsoft package 1.8.910.0 discovery on 2026-10-04 matched this Mods-only shape in the signed-in cache under `SystemAppData/xgs/.../PlayerProfiles/.../modsettings.lsx`. A different `modsettings.lsx` inside `LocalCache/Local/Mods/<uuid>` had a similar shape but is package-local data, not the signed-in profile order. Therefore path role and XML shape are both required.

This corrected two earlier CAM assumptions: UUIDs must not use the old `FixedString` fixture, and Xbox profile order must not require `ModOrder`. The installer mirrors the active profile's `ModuleShortDesc` schema instead of inventing one.

### Multiple independent reports / implementations

The Xbox-specific community manager descriptions and its source both describe:

- a Microsoft mod cache / cached Xbox profile;
- external PAK import;
- Active Mods;
- `Export Order to Game`;
- backup/rollback behavior.

Together with Microsoft's package-scoped storage model, this makes a separate Xbox cache/profile layout much more credible than the ordinary Steam/GOG path.

### Single report only

A Reddit Xbox Play Anywhere user reported:

`[Install Drive]:\WpSystem\[SID]\AppData\Local\Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw\LocalCache\Local\Mods`

and reported that external PAKs could be activated after moving the generated load order into the Xbox cache. The same user later reported that saves created with those external mods would not reload.

Treat this as a useful path candidate and risk signal, **not** as universal ground truth.

### Inference

It is reasonable to expect the exact package-data path to vary with Xbox/Gaming Services storage configuration. Therefore discovery should inspect both normal `%LOCALAPPDATA%\Packages` package data and accessible `WpSystem` candidates, then accept only evidence created by the game itself.

## Current community Xbox manager

The current player package can be useful as an implementation reference, but it is not the preferred CAM development dependency:

- release 0.2.3 is marked prerelease;
- the Nexus page remains under moderation;
- its setup is centered on an Xbox-compatible Script Extender plus optional MCM;
- CAM deliberately has no Script Extender runtime dependency;
- 0.2.3 has launch confirmation but no fresh gameplay/save-load validation.

For CAM, only its open source and observed cache/load-order behavior are used as supporting evidence.

## Workflow comparison

| Method | Current assessment |
| --- | --- |
| Patched Xbox BG3 Mod Manager | Useful reference and possible fallback; not preferred while prerelease/moderated and SE-oriented |
| CAM discovery-first deploy script | Best local iteration path **only when** cache and LSX schema are proven from the target machine |
| Official mod.io | Best official distribution path; less suitable for rapid unpublished local iteration |
| Nexus Mods App / Vortex | Nexus Mods App currently does not document Xbox App BG3 support |
| Manual cache editing | Avoid; too easy to select the wrong cache/profile or serialize stale assumptions |

## Development policy

The Xbox development tool must:

1. query installed BG3 package identity when available;
2. inspect `%LOCALAPPDATA%\Packages` and treat `WpSystem` only as a fallback candidate;
3. require existing PAK evidence in the discovered Mods cache;
4. exclude package-local `modsettings.lsx` files under the Mods cache from profile-order selection;
5. require exactly one writable `PlayerProfiles/.../modsettings.lsx` with `ModuleSettings/root/Mods`;
6. require an active non-CAM `ModuleShortDesc` that provides one unambiguous reusable LSX schema;
7. report all evidence without changing BG3 by default;
8. permit `-Apply` only when every proof gate passes;
9. mirror donor LSX attribute types/fields and preserve the profile's Mods-only vs legacy layout;
10. back up the profile order and any previous CAM PAK;
11. modify only CAM's entry and verify the resulting XML;
12. fail closed on missing evidence, multiple profiles/caches, conflicting schemas, or unexpected XML.

## Sources

- Microsoft GDK: Mods support for PC GDK titles  
  https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/packaging-mods
- Microsoft GDK: Getting started with packaging for PC  
  https://learn.microsoft.com/en-us/xbox/gdk/docs/features/common/packaging/overviews/packaging-getting-started-for-pc
- Microsoft MSIX troubleshooting / redirected LocalCache  
  https://learn.microsoft.com/en-us/windows/msix/msix-troubleshooting-guide
- Larian official Toolkit installation  
  https://docs.baldursgate3.game/index.php?title=Getting_Started%3A_Installing_the_Toolkit
- Larian/mod.io official modding guidelines  
  https://mod.io/g/baldursgate3/r/modding-guidelines
- Nexus Mods App BG3 integration  
  https://github.com/Nexus-Mods/NexusMods.App/blob/main/docs/developers/games/0003-BaldursGate3.md
- LaughingLeader BG3 Mod Manager source  
  https://github.com/LaughingLeader/BG3ModManager/blob/master/src/Core/DivinityApp.cs
- LaughingLeader BG3 modding snippets  
  https://github.com/LaughingLeader/BG3ModdingTools/blob/master/.vscode/BaldursGate3.code-snippets
- Xbox community compatibility source  
  https://github.com/titoreinaldo/bg3-xbox-pc-mod-support
- Nexus page 25204  
  https://www.nexusmods.com/baldursgate3/mods/25204
