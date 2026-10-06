# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The primary runtime target includes the **Xbox App / Microsoft Store PC build**, so the shipping mod must work as a normal BG3 `.pak` without third-party runtime injection.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI composition.**
   Reuse BG3-owned view models, templates, styles and commands wherever possible. The `ActionRadials` state/page and outer native template semantics are BG3-owned. The main CAM surface is an automatically populated action catalog derived from the same current native collections used by radial slot assignment; the user must not have to maintain radial slots for CAM. `SingleHotBar` remains BG3-owned for nested/upcast/variant choices.

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

Proven directly from the installed Xbox App build 1.8.910.0 plus current Patch 8 resources:

- controller state `ActionRadials` still uses the `HotBar` context;
- historical runtime builds proved CAM can replace the state/page, but those replacements left controller focus/input dead and are now rejected;
- the native page uses `ActionRadialWidgetTemplate_P8` from `PreloadedActionRadials_c.xaml`;
- official BG3 UI documentation confirms `Lib_Controller.xaml` is loaded in controller mode before mod StateMachines, making a controller resource-library override the preferred hook;
- the exact main controller collection is `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`;
- each controller bar exposes `SlotList` and native materialization uses `PagedList`;
- nested variants/upcasts/containers use `SingleHotBar.SlotList`;
- `CurrentSingleHotbarFilter`, `IsShowingAContainerWithVariants` and `IsSelectingUpcastedSpell` are current;
- focus-driven scrolling is `LSScrollViewer.ScrollToElement <- FocusedElement`;
- the captured preloaded radial contains a current working 2D controller-grid pattern: `LSListBox -> focusable ListBoxItem -> LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- the root radial page does not intercept the four `UI*` directional events; its root left/right mappings are `UITabPrev` / `UITabNext`;
- normal controller A dispatch is page-level: `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- default B dispatch is `ClearSingleHotbarCommand`; when `SingleHotBar.SlotList.Count == 0` and items-to-throw is false, native triggers switch B to `CustomEvent("CloseWidget")`;
- swap-slot mode switches B to `UseSlotCommand(null)`;
- current `HotBarSlotStyle` is still suitable for native square slot visuals;
- `KeyboardHotBars` remains a separate keyboard/mouse collection and must never be substituted for `ControllerHotBars`.

Do not reconstruct the visible grid from `HotbarContainer` component memory. Component data is useful corroborating/storage evidence, but the presentation source is the captured native controller UI/view-model contract.

The public `ActionRadials.xaml` dump from 2023-09-06 is Patch 2 Hotfix 1 and is historical evidence only.

The public SpellBook dump that exposes the names `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate` is likewise historical evidence, not sufficient Patch 8 proof by itself. Do not put those predicate names, a hand-written `SpellSlotLevel` classifier, or any equivalent CAM-owned spell-level heuristic into shipping XAML until the exact current installed-game contract is captured. Until then, preserve the current native `SpellsAndActions` grouping instead of guessing how to split it.

Runtime evidence additionally proves:

- `0.0.18` had the correct controller data/rendering path but dead navigation/B;
- `0.0.19` regressed the page by changing input transport;
- `0.0.20` restored rendering but controller focus/input was still dead;
- `0.0.23` failed at startup because a CAM-local secondary XAML URI was treated as a literal missing path;
- `0.0.24` proved the native page and controller-library override load, but a hand-written full `ActionRadialWidgetTemplate_P8` still had dead interaction;
- `0.0.25` attempted to override `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` from the mod PAK and produced no visible runtime change, so that resource-path strategy is rejected;
- `0.0.27` proves the native slot-assignment grid focus model works inside ActionRadials: grids render and replace radial slot layouts;
- `0.0.28` centers the visible grids and removes the radial backdrop, but runtime proves the `LocalFocusSelector` visual stayed at the old upper-left coordinate origin because the list was centered independently from its selector;
- `0.0.29` fixes the focus-selector coordinate origin in-game. The remaining architectural mismatch is now explicit: the main grid still mirrors user-configured `ControllerHotBars[*].SlotList`, so it cannot satisfy CAM's original “all available actions automatically” goal. X/ContextMenu radial customization also behaves poorly against the grid and is no longer part of the product.
- `0.0.35` proves the native-source tabs render and switch, but rejects the "one shared outer `HotBarList.LocalFocus` for all tabs" composition: runtime showed the first tab could retain focus/tooltip ownership after a visual tab switch, A did not execute the selected action, the generic selector frame no longer matched the assignment cells, and centered footer hints collided with the action-resource display.
- `0.0.36` disproves the assignment-catalog execution architecture itself: per-tab focus ownership no longer explains the failures. Runtime shows bottom-row navigation can trap focus, A still does not execute, containers do not open, and resource-cost highlighting is absent. Current Patch 8 `HotBarSlotStyle` explains the boundary: native hotbar execution/highlighting consumes a `VMHotBarSlot` wrapper whose `Content` is the visible action/item/passive; CAM 0.0.34–0.0.36 passed raw assignment candidates instead.

The current Patch 8 native XAML also proves a working controller grid inside radial slot assignment:

- outer `AssignList` uses `LocalFocusSelector`, `KeyboardNavigation.DirectionalNavigation="Contained"`, `ActionNextEvent="UIDown"` and `ActionPrevEvent="UIUp"`;
- child lists use `LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- `AvailableSlotContainer` uses focusable `ListBoxItem` cells;
- A in assignment mode consumes `AssignList.LocalFocus.DataContext`.

Current mandatory architecture:

- do not override `Public/Game/GUI/...` from the CAM PAK;
- do not ship a hand-written replacement ActionRadials page/template;
- installer must extract the exact current native radial dictionary from local `Game.pak`;
- installer must also extract the exact current keyboard `HotBar.xaml` contract needed for deck/resource filtering;
- installer must locally generate `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`;
- the top-level execution model must use native **VMHotBarSlot wrappers**; raw `SpellsAndActions`, passive or inventory assignment candidates are discovery evidence only and must never be sent directly to `UseSlotCommand`;
- one visible result set uses one flat `LSListBox + LSGrid + LocalFocusSelector` focus owner. Do not compose top-level results from nested assignment-group lists;
- top-level filter semantics come from the current installed DCHotBar contract:
  - deck/type axis: Common, Class, Items and Passives;
  - resource/action axis: native action resources, spell-slot resources, cantrips and class-specific resources exposed by the current hotbar;
  - `Custom` remains excluded because CAM is not a user-managed layout;
- do not infer filter membership from `SlotType`, `SpellSlotLevel`, action names, icons or CAM-owned resource tables;
- current installed `HotBar.xaml` must prove any concrete filter property/command name before it is used by generated shipping XAML. Historical `HotBar.xaml` is design precedent only;
- focus changes must write the focused VMHotBarSlot to `ActionRadials.Tag` and invoke the native tooltip/resource-preview commands for that slot;
- A remains the native page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)`; no custom gameplay dispatch;
- `SingleHotBar.SlotList` remains the native second-stage surface for containers, upcast, variants and native filters;
- B remains BG3's native `ClearSingleHotbarCommand` / top-level close lifecycle;
- preserve the installed native `ButtonHintsContainer` layout. CAM may remove radial-edit controls but must not reposition/reflow the surviving native hints and must not add custom LB/RB hint presenters;
- X/`ShowContextMenu` and radial Assign/Swap/Clear/Add/Remove customization must remain unreachable;
- no copied Larian XAML may be committed or published; all native derivation is local-only;
- install-time compatibility checks remain operational: generation may fail when a required current native element cannot be extracted, but detailed duplicated semantic verification belongs in CI.


Do not revive the hidden-radial visual-mirror design from 0.0.25.

The end-user installer is not a verifier. `0.0.29` proved that duplicating release semantics inside the install path creates stale false failures. Detailed generated-XAML semantics, presentation literals, focus/A/B contracts, package round-trip checks and release-integrity assertions belong in CI/release workflows only. The runtime installer performs only the operations required to download, derive and install the package; it should fail only when an operation itself cannot be completed.

The next in-game test is justified only after CI proves the 0.0.36 assignment-candidate architecture is absent, the visible grid contains VMHotBarSlot wrappers under one flat focus owner, current installed hotbar filter seams are source-gated, slot focus drives tooltip/resource preview, native button-hint layout is preserved, and native A/B plus `SingleHotBar` seams remain. One milestone run should then verify full-row navigation, resource preview, one simple A dispatch, one container/upcast transition, filter switching and B.

## Installer boundary

The stable bootstrap contract must remain tiny: newest release -> download `install-latest.ps1` -> execute it. Do not make the bootstrap understand version-specific assets.

Do not add SHA/digest gates, XAML semantic assertions, expected UI literals, or package round-trip verification to `bootstrap-latest.ps1`, `install-latest.ps1`, or the runtime path in `native-overlay.ps1`. Those belong in CI before publication.

## Release readiness contract

A CI artifact is not a release. The reusable installer consumes **published GitHub Releases**, not pull-request or workflow artifacts.

Before describing a version as released, ready to install, or available through the one-click installer, all of these must be proven:

- the implementation PR is merged to `main`;
- `VERSION` on `main` is the intended version;
- the **Release** workflow for that merge completed successfully;
- the exact `v<VERSION>` GitHub Release is published and non-draft;
- every installer-required release asset exists;
- that tag is the newest published release under the same ordering used by `install-latest.ps1`;
- the canonical `install-latest.ps1 -ResolveOnly` path resolves that exact version against live GitHub metadata.

Never treat a green **Build package** workflow or an Actions artifact as proof that the one-click installer can see the version.

If the installer resolves an older version, verify publication first. Do not change installer selection logic to compensate for a release that was never published.

The complete release procedure and recovery checklist are in [docs/release-process.md](docs/release-process.md).

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
