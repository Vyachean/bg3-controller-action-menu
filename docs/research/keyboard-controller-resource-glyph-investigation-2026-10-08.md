# Keyboard vs controller resource glyphs — 2026-10-08

## Observed failure

The native keyboard HotBar uses small star, clover, flame, and square-group
resource glyphs; CAM 0.0.91 renders oversized basic bars, rectangles,
triangles and circles. The operator reports **no visible change after
0.0.91**. Treat the point-template override as **runtime rejected**.

## Authoritative available evidence

The operator archive
`bg3-controller-action-menu-inputs-20261008-093541.zip` contains
installed Xbox App BG3 package 1.8.910.0 XAML. Its HotBar.xaml SHA-256 is
`9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.

- `HotBar.xaml` has an inline resource preview renderer using native
  `VMActionResourceCostPreview` and `LSActionPointResources`.
- `Public/Game/GUI/Library/DataTemplates.xaml` defines
  `ActionResourcesTemplateSelector` and per-TypeId resource templates.
- `Public/Game/GUI/Library/Libs_Controller.xaml` explicitly imports
  `DataTemplates_c.xaml` and `ActionResourceTemplates_c.xaml`.

The latter two files were **not** in the original 22-file capture: the
capture glob `*DataTemplates.xaml` missed all suffixed dictionaries,
and there was no `ActionResourceTemplates_c` target at all.

Older open source BG3 controller dictionaries confirm that keyboard and
controller presentation families can use different image assets
(`Assets/ActionResources_c/Icons/c_ico_*` in controller mode) and
different point-size resource values (keyboard 48, controller 80).
These historical differences are leads, **not proof of the current
installed-game dictionaries**.

## Next evidence gate

Do not introduce another image scale, hard-coded resource icon, provider
classifier, or global resource override until the precise current
`DataTemplates_c.xaml`, `DataTemplates_k.xaml`, and
`ActionResourceTemplates_c.xaml` are inspected.

The universal VBS is temporarily switched to the **read-only**
`Game.pak` capture task. The capture helper collects both mode-specific
dictionaries and fails closed if the required files are missing; normal
game/mod files remain untouched. No BG3 test run is needed at this stage.

The subsequent implementation must have a narrow, provable interface:
controller tab browsing stays CAM-owned, resource classification and
costs stay BG3-owned, and the **keyboard** icon/point-count semantics
are selected explicitly without mutating other game UI dictionaries.
