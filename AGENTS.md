# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The primary runtime target includes the **Xbox App / Microsoft Store PC build**, so the shipping mod must work as a normal BG3 `.pak` without third-party runtime injection.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI composition.**
   Reuse BG3-owned view models, templates, styles and commands wherever possible. The `ActionRadials` behavior is BG3-owned. No specific restyling hook is currently accepted; it must be proven from current BG3 UI documentation or a concrete working modern mod before another runtime implementation.

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
- `0.0.23` failed at startup because a CAM-local component URI was interpreted as a missing literal XAML path;
- `0.0.24` proved the standard controller library hook and native page are active, but a full replacement `ActionRadialWidgetTemplate_P8` still lost usable A/B/focus;
- `0.0.25` packaged locally derived current native `PreloadedActionRadials_c.xaml` under `Public/Game/GUI/...`, but produced no visible in-game change.

No runtime restyling architecture is currently accepted.

Do **not** treat any of these as established solutions:

- CAM-owned replacement page/state;
- hand-written full `ActionRadialWidgetTemplate_P8` replacement;
- raw `Public/Game/GUI` resource-path overrides inside a normal mod PAK;
- install-time extraction/repacking of native XAML as a UI hook by itself.

Research gate before the next candidate:

1. inspect current 2025–2026 controller-radial mods for concrete data/UI hooks;
2. finish the RadialHotbarCustomization v0.8.0.0 source audit;
3. inspect Auto-Sorting Hotbar controller support and Sticky Temporaries where implementation is available;
4. reconcile findings with Larian's supported controller Library / Pages / StateMachines / restyling model;
5. choose the smallest hook that keeps exact native `ActionRadials` behavior;
6. only then implement one milestone candidate.

The next in-game test must not be requested until that research gate is complete. It must combine rendering, focus/navigation, top-level B and one simple A dispatch.

Installer reliability is also a release gate. The reusable VBS bundle must contain only a stable self-updating bootstrap, not a frozen version-specific `install-latest.ps1`. Every release must publish exactly one `bootstrap-latest.ps1` and one canonical `install-latest.ps1` with GitHub SHA-256 digests. The bundled bootstrap must update/handoff to the verified release bootstrap before invoking the canonical installer, and must never silently fall back to an older release.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
