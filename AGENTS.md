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

Proven directly from the installed Xbox App build 1.8.910.0 plus current Patch 8 resources:

- controller state `ActionRadials` still uses the `HotBar` context;
- the real Xbox App build loads CAM's state override;
- the native page uses `ActionRadialWidgetTemplate_P8` from `PreloadedActionRadials_c.xaml`;
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

- `0.0.18` had the correct controller data/rendering path but no working navigation/B;
- `0.0.19` regressed the page by replacing native radial input controls and adding unrelated grid flags;
- `0.0.20` restored rendering (`Controller bars: 5`, Class/Actions/Items visible) but still had no widget focus, slot focus, navigation or B.

Do not iterate again on the fully custom `CAM_ActionMenu_c.xaml` architecture. The remaining failure is the page lifecycle/focus boundary, not the controller data source.

The next architecture must:

- ship a native-named `ActionRadials.xaml` root with the captured Patch 8 root identity/lifecycle;
- preserve native root focus mappings (`UITabPrev`/`UITabNext`), Loaded/WidgetClosing/Layout refocus triggers and `ActionRadials` element name;
- use the captured slot-assignment focus root: outer `LSListBox` with `SelectedIndex=0`, `LocalFocusSelector`, `ActionNextEvent=UIDown`, `ActionPrevEvent=UIUp`;
- keep outer section `ListBoxItem` containers focusable;
- use inner `LSGrid` with `ContainerData="{Binding}"` and `UIUp/UIDown/UILeft/UIRight`;
- preserve native radial `LSButton` A/B primitives.

The superseded `CAM_ActionMenu_c.xaml` must not ship.

Another in-game test is allowed only after this native-shell architecture passes static validation, native-capture fixture and package round-trip verification. The test must combine rendering, controller focus/scroll, top-level B, nested B if encountered, and one simple A dispatch.

Custom code owns only template composition/layout and diagnostics, preserves the live gameplay view, and leaves gameplay state/dispatch to BG3.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
