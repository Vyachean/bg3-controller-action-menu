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
- current `HotBarSlotStyle` is still suitable for native square slot visuals, but its command parameter is the surrounding `VMHotBarSlot`; the `VMCharacterAction` / `VMUpcast` / `VMItem` / `VMPassive` DataTemplates render slot **content** and do not prove that those raw content objects are valid `UseSlotCommand` parameters;
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
- `0.0.36` rejects the source-tab/assignment-candidate architecture itself: navigation breaks when reaching lower rows and cannot reliably return upward, A still does not execute actions or open containers, the native bottom resource bar does not preview the focused action cost, button hints are not in the original vertical stack, and custom LB/RB hint presentation produces extra symbols. The user also clarified that tabs are semantic filters like the keyboard hotbar, not source pages.

The current Patch 8 native XAML also proves a working controller grid inside radial slot assignment:

- outer `AssignList` uses `LocalFocusSelector`, `KeyboardNavigation.DirectionalNavigation="Contained"`, `ActionNextEvent="UIDown"` and `ActionPrevEvent="UIUp"`;
- child lists use `LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- `AvailableSlotContainer` uses focusable `ListBoxItem` cells;
- A in assignment mode consumes `AssignList.LocalFocus.DataContext`.

Current mandatory architecture:

- do not override `Public/Game/GUI/...` from the CAM PAK;
- do not ship a hand-written replacement ActionRadials page/template;
- installer must extract the exact current native controller radial dictionary **and** current keyboard `Mods/MainUI/GUI/Pages/HotBar.xaml` from the local `Game.pak`;
- installer must locally generate `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`; no extracted Larian XAML may be committed or published;
- main gameplay candidates passed to `UseSlotCommand` must be native hotbar slot VMs (`VMHotBarSlot`), not raw radial-assignment catalog objects;
- `PlayerCharacterProperties.SpellsAndActions`, `Inventory.Slots`, and raw/passive assignment collections may be research/presentation evidence but must not be used as the main `ActionRadials.Tag -> UseSlotCommand` candidate path;
- type tabs are native **filters**, not independent data catalogs. Reuse the exact current installed hotbar seams for `SetCurrentShownDeckCommand` / `CurrentShownDeck.SlotList`, passives, cantrip filtering and `ClearSingleHotbarCommand`;
- resource filters come from the current `CurrentPlayer.UIData.ActionResourcesCostPreview` model and invoke the current native `FilterActionResourceCommand`; do not infer resource membership from action names, icons or CAM-owned rules;
- the installer may read only concrete source values required by the deterministic transformation (for example the current cantrip command parameter). Semantic compatibility of HotBar command/property names is CI-owned; do not scan/assert the installed file for an expected contract before transforming it;
- the main navigation hierarchy is one assignment-style outer `LSListBox + LocalFocusSelector` with scrolling. Child resource/action lists use `KeyboardNavigation.DirectionalNavigation="Continue"` and `LSGrid(UIUp/UIDown/UILeft/UIRight)`; do not split each filter into an independent focus root;
- do not hard-code a short/fixed action-grid height that truncates the navigation space;
- each action cell container must expose the native slot VM as its `Tag`, because the native radial focus lifecycle consumes `LocalFocus.Tag`;
- main slot focus must reuse the exact installed radial `LocalFocusChanged` lifecycle for `ActionRadials.Tag`, `CreateFocusedTooltipDataCommand`, `HighlightResourcesCommand` and hover feedback. Do not recreate resource-cost preview semantics;
- A remains the existing page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)` path;
- `SingleHotBar.SlotList` remains BG3-owned for filtered/nested/upcast/variant/container state and the native B lifecycle remains authoritative;
- preserve the installed `ButtonHintsContainer` composition. Do not restyle it horizontally and do not add duplicate LB/RB hint presenters;
- X/`ShowContextMenu` and radial Assign/Swap/Clear/Add/Remove customization must remain unreachable from CAM;
- historical SpellBook predicates and CAM-owned spell/resource classifiers remain forbidden without current installed-game proof;
- install-time generation must not run semantic/contract assertions over the installed XAML. It should perform the requested extraction/transformation directly and fail only when a required operation cannot be completed.

Do not revive the hidden-radial visual-mirror design from 0.0.25.

The end-user installer is not a verifier. `0.0.29` proved that duplicating release semantics inside the install path creates stale false failures. Detailed generated-XAML semantics, presentation literals, focus/A/B contracts, package round-trip checks and release-integrity assertions belong in CI/release workflows only. The runtime installer performs only the operations required to download, derive and install the package; it should fail only when an operation itself cannot be completed.

The next in-game test is justified only after CI proves the 0.0.35/0.0.36 source-tab architecture is absent, all main execution candidates come from native slot collections, the one-outer-list navigation hierarchy is restored, the native radial focus/resource-preview trigger is retained, native button hints are preserved, and A/B plus nested `SingleHotBar` seams remain. One milestone run should then check long-grid up/down navigation, type/resource filters, one simple A dispatch, one container/variant opening if naturally available, resource-cost highlighting, native vertical hints and top-level/nested B together.

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
