# Self-contained runtime

## Shipping contract

CAM ships one ordinary BG3 `.pak`. Runtime XAML required by the mod is project-owned source under:

```text
BG3ControllerActionMenu/
  Mods/BG3ControllerActionMenu/
    GUI/Library/Lib_Controller.xaml
```

CI packages that source before publication. Normal installation only downloads the prebuilt PAK, locates the Xbox mod/profile target, copies the PAK and updates `modsettings.lsx`.

Normal installation must not:

- read or extract `Game.pak`;
- require or invoke LSLib / `divine.exe`;
- generate XAML;
- patch or repack the PAK;
- use Script Extender, a DLL, or another native loader.

LSLib remains acceptable as a maintainer/CI packaging tool for creating and inspecting the already-defined release artifact. It is not an end-user/runtime dependency.

## Patch 8 evidence

The current runtime contract was consumed from the Xbox App capture for game package `1.8.910.0`.

The compact, reviewable evidence record is:

```text
docs/evidence/patch8-1.8.910.0-runtime-contract.json
```

It pins the source hashes and the exact seams used by CAM, including:

- `ActionRadials` / `HotBar`;
- `ActionRadialWidgetTemplate_P8`;
- native `VMHotBarSlot` collections;
- deck, cantrip and resource filter commands;
- `LocalFocus.DataContext` focus handoff with the native 70 ms delay;
- `CreateFocusedTooltipDataCommand`;
- `HighlightResourcesCommand`;
- `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- native B/`ClearSingleHotbarCommand` lifecycle;
- `SingleHotBar.SlotList`;
- assignment-style `LSListBox -> ListBoxItem -> LSGrid` navigation;
- current `ButtonHintsContainer` layout.

Raw captured Larian XAML is not runtime source and is not copied into the PAK.

## Development capture

`Capture-BG3ControllerArtifacts.vbs` and `capture-self-contained-inputs.ps1` are development-only, read-only evidence tools. They may inspect the installed game and prepare a ZIP when a future Patch changes a native contract.

They do not generate shipping XAML and are not part of installation.

A capture must be analyzed before changing the pinned runtime contract. If current evidence no longer proves a seam, release should fail closed rather than discover or derive that seam on the tester's machine.

## Runtime ownership

CAM owns thin presentation/composition only:

- semantic filter tabs;
- grid layout and focus shell;
- the project-owned resource dictionary that connects proven native seams.

BG3 continues to own:

- slot membership and availability;
- costs and resources;
- targeting and execution;
- variants, containers and upcasting;
- native slot visuals/content;
- tooltip data and resource highlighting;
- A/B behavior and state transitions.

## CI/release proof

The self-contained boundary is checked by:

- `tools/test-self-contained-runtime.ps1` — verifies the pinned Patch 8 runtime contract and rejects stale/raw-catalog seams;
- `tools/assert-self-contained-release.ps1` — rejects any normal-install path that reads/builds from game files and requires the runtime library;
- `tools/verify-package.ps1` — round-trips the built PAK and requires the project-owned runtime XAML to be present byte-for-byte, while rejecting copied `Public/Game` resources, Script Extender and native executable payloads.

A green package proves structure and contract consistency, not actual BG3 runtime behavior. One milestone game run remains required after package proof.
