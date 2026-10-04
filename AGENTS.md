# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The primary runtime target includes the **Xbox App / Microsoft Store PC build**, so the shipping mod must work as a normal BG3 `.pak` without third-party runtime injection.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI composition.**
   Reuse BG3-owned view models, templates, styles and commands wherever possible. The mod should primarily change composition/layout.

3. **No Script Extender dependency in the shipping package.**
   `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu` must not contain a `ScriptExtender` directory. Script Extender experiments may live under `dev/`, but they are not part of the runtime package or required workflow.

4. **Xbox App / PC compatibility is a release gate.**
   Do not introduce DLL/native-loader/Script-Extender requirements into the primary build.

5. **Controller-first.**
   Every interactive element must have deterministic controller focus/navigation. Mouse support is secondary.

6. **Do not optimize around unverified assumptions.**
   If an engine binding, data shape, page/state name, or dispatch mechanism is not proven against the current game/toolkit/open Patch 8 resources, document it and isolate it.

7. **Minimize manual testing.**
   Add static validation, package round-trip verification and visible in-game diagnostics for everything that does not require a running game.

8. **Milestone game tests only.**
   In-game testing should be requested only when a build crosses a runtime proof boundary that cannot be established statically. Do not ask the user to validate one speculative binding/layout hypothesis per build. First exhaust current game-file inspection, public Patch 8 resources, deterministic fixtures and package checks; then combine remaining runtime-only questions into one high-information run.

## Current evidence boundary

Proven against Patch 8 / the real Xbox App build:

- controller state `ActionRadials` is still present in Patch 8 `Controller.xaml`;
- the state is reached by `OpenActionRadials` and removed by `CloseWidget` / `CloseRadials`;
- the real Xbox App build loads CAM's state override and `HotBar` context;
- current Patch 8 native resources still expose `HotBarSlotStyle`;
- Patch 8 `HotBarSlotStyle` binds its command to the owning `UIWidget.DataContext.UseSlotCommand` and passes the current slot as `CommandParameter`;
- a 2026-09-27 production mod confirms the live top-level `HotBar.DataContext`, `CurrentSingleHotbarFilter`, `PlayerCharacterProperties.KeyboardHotBars[*].SlotList` and `UseSlotCommand:Execute(slot)`;
- current BG3SE data mappings prove keyboard and controller hotbar state are distinct;
- the shipped Patch 8 controller radial has a runtime/preloaded file named `PreloadedActionRadials_c.xaml`.

Not yet proven for the current Patch 8 radial page:

- the exact current **controller-radial collection** path;
- the exact slot materialization/paging hierarchy;
- the exact top-level/nested `UICancel` path;
- whether the historical `SingleHotBar` collection path itself is unchanged.

Do not use the proven current `PlayerCharacterProperties.KeyboardHotBars` collection as a controller substitute: current engine mappings prove the two modes carry distinct state.

Do not reconstruct the visible radial/grid directly from `HotbarContainer` component memory. Current RadialHotbarCustomization research reports that the persisted hotbar/radial storage does not map cleanly to the visual radial layout. Component data is useful corroborating evidence, but the presentation source must come from the current native radial UI/view-model contract.

The public `ActionRadials.xaml` dump used earlier is Patch 2 Hotfix 1 (2023-09-06), not Patch 8. It may be used only as historical/secondary evidence.

Do not request another in-game test until the current installed game's native radial XAML has been captured and the candidate is rebuilt from that current contract.

Custom code should own only page composition/layout and diagnostics, preserve the live gameplay view, and leave gameplay state/dispatch to BG3.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
