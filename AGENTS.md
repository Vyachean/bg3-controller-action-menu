# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The primary runtime target includes the **Xbox App / Microsoft Store PC build**, so the shipping mod must work as a normal BG3 `.pak` without third-party runtime injection.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI composition.**
   Reuse BG3-owned view models, templates, styles and commands wherever possible. The `ActionRadials` state/page and outer native template semantics are BG3-owned. CAM may replace only the radial slot renderer inside the native PageView styles, using the controller-grid focus contract already proven by the current slot-assignment UI.

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

Runtime evidence additionally proves:

- `0.0.18` had the correct controller data/rendering path but dead navigation/B;
- `0.0.19` regressed the page by changing input transport;
- `0.0.20` restored rendering but controller focus/input was still dead;
- `0.0.23` failed at startup because a CAM-local secondary XAML URI was treated as a literal missing path;
- `0.0.24` proved the native page and controller-library override load, but a hand-written full `ActionRadialWidgetTemplate_P8` still had dead interaction;
- `0.0.25` attempted to override `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` from the mod PAK and produced no visible runtime change, so that resource-path strategy is rejected;
- `0.0.27` proves the native slot-assignment grid focus model works inside ActionRadials: grids render and replace radial slot layouts;
- `0.0.28` centers the visible grids and removes the radial backdrop, but runtime proves the `LocalFocusSelector` visual stayed at the old upper-left coordinate origin because the list was centered independently from its selector. X/ContextMenu also remains functionally useful even though its hint was hidden.

The current Patch 8 native XAML also proves a working controller grid inside radial slot assignment:

- outer `AssignList` uses `LocalFocusSelector`, `KeyboardNavigation.DirectionalNavigation="Contained"`, `ActionNextEvent="UIDown"` and `ActionPrevEvent="UIUp"`;
- child lists use `LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- `AvailableSlotContainer` uses focusable `ListBoxItem` cells;
- A in assignment mode consumes `AssignList.LocalFocus.DataContext`.

Current mandatory architecture:

- do not override `Public/Game/GUI/...` from the CAM PAK;
- do not ship a hand-written replacement ActionRadials page/template;
- installer must extract the exact current native radial dictionary from local `Game.pak`;
- installer must locally generate `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`;
- generated library must preserve the exact native outer `ActionRadialWidgetTemplate_P8`, `RadialHotBarListItemContainer`, native A/B/nested/swap semantics;
- only `BarPageViewStyle` and `SingleBarPageViewStyle` may replace their `ls:Radial` renderer with the proven slot-assignment-style `LSListBox + LocalFocusSelector + LSGrid` structure;
- keep element names `HotBarRadial` and `SingleBar` so existing native bindings/triggers keep addressing the local-focus source;
- grid presentation must center a **shared focus root** containing both the replacement list and its `LocalFocusSelector`; never center the list independently from the selector;
- the obsolete radial backdrop ellipse may be collapsed;
- ContextMenu/X remains useful for editing the underlying hotbar slots and should stay active, but its visible label must be grid-neutral (`Customize`), not `Radial Customisation`;
- no copied Larian XAML may be committed or published; generation is local-only;
- fail closed if required native seams are absent.

Do not revive the hidden-radial visual-mirror design from 0.0.25.

The end-user installer is not a verifier. `0.0.29` proved that duplicating release semantics inside the install path creates stale false failures. Detailed generated-XAML semantics, presentation literals, focus/A/B contracts, package round-trip checks and release-integrity assertions belong in CI/release workflows only. The runtime installer performs only the operations required to download, derive and install the package; it should fail only when an operation itself cannot be completed.

The next in-game test is justified only after CI proves on a representative fixture that the generated library preserves native focus/A/B/swap seams, centers both assignment-style grids, collapses both radial backdrop ellipses, and removes the radial-specific customization prompt from visible grid chrome.

## Installer boundary

The stable bootstrap contract must remain tiny: newest release -> download `install-latest.ps1` -> execute it. Do not make the bootstrap understand version-specific assets.

Do not add SHA/digest gates, XAML semantic assertions, expected UI literals, or package round-trip verification to `bootstrap-latest.ps1`, `install-latest.ps1`, or the runtime path in `native-overlay.ps1`. Those belong in CI before publication.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
