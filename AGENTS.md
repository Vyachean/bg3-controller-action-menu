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
- the vanilla radial still exposes `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`, but that persisted user layout is **not** CAM's automatic main catalog;
- executable CAM cells come from current native hotbar-slot collections such as `CurrentShownDeck.SlotList`, `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList`, and `SingleHotBar.SlotList`;
- nested variants/upcasts/containers use `SingleHotBar.SlotList`;
- `CurrentSingleHotbarFilter`, `IsShowingAContainerWithVariants` and `IsSelectingUpcastedSpell` are current;
- focus-driven scrolling is `LSScrollViewer.ScrollToElement <- FocusedElement`;
- the captured preloaded radial contains a current working 2D controller-grid pattern: `LSListBox -> focusable ListBoxItem -> LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- the root radial page does not intercept the four `UI*` directional events; its root left/right mappings are `UITabPrev` / `UITabNext`;
- normal controller A dispatch is page-level: `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- default B dispatch is `ClearSingleHotbarCommand`; when `SingleHotBar.SlotList.Count == 0` and items-to-throw is false, native triggers switch B to `CustomEvent("CloseWidget")`;
- swap-slot mode switches B to `UseSlotCommand(null)`;
- current `HotBarSlotStyle` still proves the keyboard-hotbar execution boundary because its command parameter is the surrounding `VMHotBarSlot`, but it is **not** CAM's controller-grid renderer: it is an 88px keyboard presentation and includes the `HotKey` overlay; the current controller radial/assignment `SlotIconStyle` is the appropriate presentation seam for CAM's 104px action cells; raw `VMCharacterAction` / `VMUpcast` / `VMItem` / `VMPassive` content objects still do not become valid `UseSlotCommand` parameters;
- `KeyboardHotBars` remains a separate keyboard/mouse collection and must never be substituted for `ControllerHotBars`.

Do not reconstruct the visible grid from `HotbarContainer` component memory. Component data is useful corroborating/storage evidence, but the presentation source is the captured native controller UI/view-model contract.

The public `ActionRadials.xaml` dump from 2023-09-06 is Patch 2 Hotfix 1 and is historical evidence only.

The fresh Xbox App 1.8.910.0 capture now confirms that current `SpellBook_c.xaml` still uses `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate`. That does **not** make them valid CAM execution filters: the captured predicates consume SpellBook `SelectedItem.ActionGroups`, not executable `VMHotBarSlot` objects. Do not route those raw ActionGroups into `UseSlotCommand` or recreate spell-level classification in CAM. Spell-slot/resource filtering must stay on the proven HotBar/resource model unless a future current-game contract proves a VMHotBarSlot-compatible level filter.

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
- `0.0.36` rejects the source-tab/assignment-candidate architecture itself: navigation breaks when reaching lower rows and cannot reliably return upward, A still does not execute actions or open containers, the native bottom resource bar does not preview the focused action cost, button hints are not in the original vertical stack, and custom LB/RB hint presentation produces extra symbols. The user also clarified that tabs are semantic filters like the keyboard hotbar, not source pages.

The current Patch 8 native XAML also proves a working controller grid inside radial slot assignment:

- outer `AssignList` uses `LocalFocusSelector`, `KeyboardNavigation.DirectionalNavigation="Contained"`, `ActionNextEvent="UIDown"` and `ActionPrevEvent="UIUp"`;
- child lists use `LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- `AvailableSlotContainer` uses focusable `ListBoxItem` cells;
- A in assignment mode consumes `AssignList.LocalFocus.DataContext`.

Current mandatory architecture:

- the **shipping PAK is self-contained**. Normal installation must not read, extract, patch, or rebuild from BG3 game PAKs;
- do not override `Public/Game/GUI/...` from the CAM PAK;
- runtime UI resources required by CAM live inside `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu` and are built into the release PAK by CI;
- raw captured Larian XAML is development evidence only and must not be committed as runtime source. Project-owned XAML may be authored from the proven contract and shipped normally;
- the end-user installer only resolves/downloads the prebuilt release PAK, locates the Xbox mod/profile target, copies the PAK, and updates `modsettings.lsx`;
- normal installation must never invoke LSLib, `native-overlay.ps1`, `Game.pak` extraction, or local PAK creation;
- if new native evidence is needed, use the separate portable `Capture-BG3ControllerArtifacts.vbs` developer tool. It is read-only against the game and writes its tools/logs/captured artifacts beside the launcher;
- main gameplay candidates passed to `UseSlotCommand` must be native hotbar slot VMs (`VMHotBarSlot`), not raw radial-assignment catalog objects;
- `PlayerCharacterProperties.SpellsAndActions`, `Inventory.Slots`, and raw/passive assignment collections may be research/presentation evidence but must not be used as the main `ActionRadials.Tag -> UseSlotCommand` candidate path;
- type tabs are native **filters**, not independent data catalogs. Reuse the current captured/proven hotbar seams for `SetCurrentShownDeckCommand` / `CurrentShownDeck.SlotList`, passives, cantrip filtering and `ClearSingleHotbarCommand`. Their presentation must follow the captured HotBar `FilterButton`/`ActiveFilterButton` pattern (`BtnTextGlow`, `SmallFontSize`, native pill assets/padding/margins) rather than CAM-invented fixed tab geometry;
- resource filters come from the current `CurrentPlayer.UIData.ActionResourcesCostPreview` model and invoke the current native `FilterActionResourceCommand`; present them as the captured compact 72px HotBar resource strip without `ActionResource.Name` text, after the action catalog rather than as leading action-grid rows. Controller focus alone must not mutate the filter: `UIAccept` applies the focused resource filter, matching native click-to-filter semantics; do not infer resource membership from action names, icons or CAM-owned rules;
- release XAML must not depend on install-time discovery of HotBar command parameters or binding names. Any required current values must be captured during development and represented explicitly in project-owned runtime resources/tests;
- the main navigation hierarchy is one assignment-style outer `LSListBox + LocalFocusSelector` with scrolling. Child resource/action lists use `KeyboardNavigation.DirectionalNavigation="Continue"` and `LSGrid(UIUp/UIDown/UILeft/UIRight)`; do not split each filter into an independent focus root. The fresh `1.8.910.0` `SelectorAssign` contract has no fixed width/height/margin, so do not restore the old synthetic `118x118` selector geometry;
- do not hard-code a short/fixed action-grid height that truncates the navigation space;
- action cells are native `VMHotBarSlot` objects. Presentation must use the captured assignment geometry directly: a 104×104 `Content.Icon` surface in a 120×120 `LSGrid` cell, with the focused `ListBoxItem` itself kept at 104×104. Do not use keyboard `HotBarSlotStyle` (keyboard `HotKey` overlay) or radial `SlotIconStyle` (captured 120×120 inner icon) as CAM's action-cell renderer. The selector remains geometry-free and follows the actual focused item. The container may retain `Tag="{Binding .}"` for presentation compatibility, but the current `1.8.910.0` gameplay-facing radial focus lifecycle consumes `LocalFocus.DataContext`;
- main slot focus must reproduce the captured current radial `LocalFocusChanged` lifecycle: clear stale focus state immediately, then after the native 70 ms delay copy `LocalFocus.DataContext` to `ActionRadials.Tag` and invoke `CreateFocusedTooltipDataCommand` / `HighlightResourcesCommand` with that same slot. Do not invent alternative resource-cost preview semantics;
- A remains the existing page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)` path;
- `SingleHotBar.SlotList` remains BG3-owned for filtered/nested/upcast/variant/container state and the native B lifecycle remains authoritative;
- preserve the captured current `ButtonHintsContainer` layout/behavior contract. Do not restyle it horizontally and do not add duplicate LB/RB hint presenters;
- X/`ShowContextMenu` and radial Assign/Swap/Clear/Add/Remove customization must remain unreachable from CAM;
- historical SpellBook predicates and CAM-owned spell/resource classifiers remain forbidden without current installed-game proof;
- there is no install-time XAML generation. Semantic/contract assertions and package construction are CI/development responsibilities.

Do not revive the hidden-radial visual-mirror design from 0.0.25.

The end-user installer is not a verifier or build pipeline. `0.0.29` and `0.0.37` proved that install-time derivation/contract logic creates avoidable failures. Detailed XAML semantics, presentation literals, focus/A/B contracts, package round-trip checks and release-integrity assertions belong in CI/release workflows only. The runtime installer installs an already-built self-contained PAK.

The next in-game test is justified only after CI proves the 0.0.35/0.0.36 source-tab architecture is absent, all main execution candidates come from native slot collections, the one-outer-list navigation hierarchy is restored, the native radial focus/resource-preview trigger is retained, native button hints are preserved, and A/B plus nested `SingleHotBar` seams remain. One milestone run should then check long-grid up/down navigation, type/resource filters, one simple A dispatch, one container/variant opening if naturally available, resource-cost highlighting, native vertical hints and top-level/nested B together.

## Development VBS contract

`Install-BG3ControllerActionMenu.vbs` is a temporary development delivery bridge, not the final public distribution mechanism.

Until CAM is available through the intended official delivery path:

- the tester must be able to keep one extracted folder and double-click the **same VBS** for every install/update;
- normal development iteration must never require manually downloading or replacing that VBS;
- the VBS must stay tiny and stable: stable bootstrap + portable status/log paths only;
- version-specific assets, migration logic and installer behavior belong in bootstrap-downloaded helper scripts, not in VBS;
- the VBS/bootstrap compatibility contract is backward-compatible. Requiring an already-installed development launcher to be refreshed manually is an architecture regression;
- helper scripts may be added for read-only game inspection, resource extraction or preparing an archive to return to the developer, but those are development evidence tools and must not become runtime dependencies of the final mod;
- installer/capture-owned artifacts belong beside the launcher. Do not scatter development state through machine-global directories.

The VBS workflow is expected to be retired once the official delivery path is in place. Do not optimize the permanent mod architecture around the temporary VBS.

See [docs/development-vbs.md](docs/development-vbs.md).

## Installer boundary

The stable bootstrap contract must remain tiny: newest release -> download `install-latest.ps1` -> execute it. Do not make the bootstrap understand version-specific assets.

The VBS installer is portable: caches, downloaded release assets, logs, status and diagnostics belong under a directory beside the VBS launcher. The only writes outside that portable directory are the intentional BG3 mod PAK/profile changes and their safety backups.

Do not add LSLib, game-PAK reads, XAML derivation, SHA/digest policy gates, semantic assertions, expected UI literals, or package round-trip verification to the normal install path. Those belong in CI/development capture before publication.

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
