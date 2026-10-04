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
   In-game testing should be requested only when a build crosses a runtime proof boundary that cannot be established statically.

## Current architecture

The current candidate intentionally uses:

- controller state `ActionRadials`;
- `DCHotBar` context;
- `SelectedCharacter.HotBars` as the normal controller action source;
- native `SlotList` / `VMHotBarSlot` entries from those hotbars;
- `SelectedCharacter.SpellsAndActions` only where BG3 itself uses it (slot assignment), not as the normal replacement-menu source;
- native `HotBarSlotStyle`;
- native Spell Book group chrome;
- native `SingleHotBar` for variants/upcast;
- native action dispatch owned by `HotBarSlotStyle`;
- the native interactive widget contract: `UIWidget.Template/ControlTemplate`, not `UIWidget.ContentTemplate/DataTemplate`;
- Patch 8 ControlTemplate data access through `(ls:WidgetData.DataContext)` + `TemplatedParent`;
- native `UIWidget.CloseRequestCommand` for top-level controller cancel.

Custom code owns only the page composition, grid geometry, section ordering and first-run diagnostic overlay. It must preserve the live gameplay view rather than adding a full-screen opaque/dim background.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
