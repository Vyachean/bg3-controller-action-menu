# Technical spike: native controller action path

## Purpose

Before implementing the final grid, prove the native controller action data and dispatch path in the current Baldur's Gate 3 build.

## Why this comes first

A visually complete grid built against guessed data bindings would create large amounts of disposable XAML and force repeated in-game trial and error.

The project instead requires evidence for the data/dispatch seam first.

## Questions to answer

1. What controller state opens when the player requests the combat action menu?
2. Which page/template renders each radial action?
3. Which bound collection contains the displayed actions?
4. Which fields expose:
   - identity;
   - name;
   - icon;
   - availability;
   - action type/category;
   - spell level;
   - cost/resources;
   - variants/upcast relationships?
5. What command/event/state transition is invoked when the player confirms an action?
6. What happens after confirmation for:
   - immediately executable actions;
   - targeted actions;
   - actions with variants;
   - upcastable spells?
7. How does cancellation return to the radial?
8. Which parts can be extended instead of overridden?

## Evidence sources

Use, in order:

1. current BG3 Toolkit/UI resources from the installed current game;
2. official Larian UI modding documentation;
3. current open-source UI mods such as ImprovedUI as structural examples;
4. older extracted UI sources only as secondary evidence, never as the sole basis for current binding names.

## Public evidence collected

### Official UI architecture

Larian's official UI guide confirms:

- BG3 UI mods are XAML-based;
- controller mode loads `Lib_Controller.xaml`;
- UI flow is connected through `StateMachines/Controller.xaml`;
- pages can be extended or overridden through the state machine;
- a UI mod can overhaul the flow, but load order matters when multiple mods touch the same state.

Reference:
https://mod.io/g/baldursgate3/r/ui-basic-setup

### Current open-source UI mod structure

The current public ImprovedUI tree contains:

- `GUI/Library/Lib_Controller.xaml`;
- controller-specific page files with the `_c.xaml` suffix;
- `GUI/StateMachines/Controller.xaml`.

It does **not** currently include the combat action-radial page in its public tree, so it is only structural evidence for this spike, not a source for the action-data binding itself.

Reference:
https://github.com/TheRealDjmr/BG3ImprovedUI

### Current Patch 8 radial filename / focus evidence

A July 2026 BG3 Script Extender issue reports testing against **SE v31 / Patch 8** and explicitly identifies the shipped controller file:

`PreloadedActionRadials_c.xaml`

The report states that Larian's `LSScrollViewer.ScrollToElement` is used there and is bound to gamepad `FocusedElement`. This is important evidence for the proposed grid:

- the current shipped controller radial page is identifiable;
- controller scrolling is already tied to focus movement;
- the grid should prefer native controller focus behavior instead of depending on scripted scroll-offset mutation.

Reference:
https://github.com/Norbyte/bg3se/issues/584

This still does **not** prove the action collection or dispatch binding; those must be read from the current shipped XAML/view-model.

### Historical radial source correction

The commonly referenced public file:

`akintos/bg3-data/Public/Game/GUI/Widgets/ActionRadials.xaml`

is **not Patch 8**. Git history shows its latest update is commit `31f3e066e90d4d5ce2b43b4a32d5917547765750`, dated 2023-09-06, message `Patch2 Hotfix1`.

It is useful only for historical concepts such as `HotBars`, `PagedList/PageView`, `SingleHotBar` and `UseSlotCommand`. It must not be used as proof that those exact bindings survive in Patch 8.

Patch 8 `Controller.xaml` independently confirms that the state is still named `ActionRadials`, while a July 2026 runtime report independently confirms a shipped/preloaded controller file named `PreloadedActionRadials_c.xaml`. The exact relationship between source `ActionRadials.xaml` and the preloaded runtime page should be resolved from the installed game files.

## Current working plan

The next runtime candidate is blocked on current-file evidence, not on another game test.

1. automatically locate the installed Microsoft/Xbox BG3 package;
2. scan its PAKs read-only for `ActionRadials.xaml` and `PreloadedActionRadials_c.xaml`;
3. extract only matching XAML files plus a machine-readable manifest;
4. compare the current page against Patch 8 `Controller.xaml`, Patch 8 shared resources and the old Patch 2 page;
5. identify the current action collection, materialization hierarchy, focus/scroll path, confirm command and cancel path;
6. rebuild CAM by preserving those native seams and changing only slot layout/composition;
7. run static/package checks that compare CAM against the captured contract where mechanically possible;
8. request one in-game run only after all remaining questions are inherently runtime-only.

Script Extender remains optional developer tooling and is not part of the shipping package.

## Deliverable

Commit a research note containing:

- exact current state/page/resource names;
- minimal relevant XAML excerpts or descriptions where licensing permits;
- the native data binding path;
- the native selection/dispatch path;
- a proposed minimal hook;
- compatibility implications;
- unknowns that still require one in-game proof.

Then implement the smallest possible proof page.

## Success criterion

The spike is successful when a custom controller presentation can:

1. display at least one entry sourced from the native action collection; and
2. invoke that entry through the native action flow without hard-coding the action's gameplay behavior.

Until both are proven, do not build the full tab/grid product UI.
