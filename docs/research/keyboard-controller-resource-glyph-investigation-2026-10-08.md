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


## 0.0.92 result — installed 1.8.910.0 native proof

New operator capture:
`bg3-controller-action-menu-inputs-20261008-114231.zip`.
The original `HotBar.xaml` and shared `DataTemplates.xaml` retain
their earlier pinned hashes. The previously missing exact files are now
present and structurally valid:

| File | SHA-256 |
| --- | --- |
| `Public/Game/GUI/Library/DataTemplates_k.xaml` | `08c5c2757ac3e5211a8675b54d548d4bb810119273f3085ba16a636ebf8cd72f` |
| `Public/Game/GUI/Library/DataTemplates_c.xaml` | `7eccd8900dcf0cf3a58a0cd1e7a44ab9dd895845e95d320036324b7a7c21a1f9` |
| `Public/Game/GUI/Library/ActionResourceTemplates_c.xaml` | `aef0e16dd6aae46af6275e48b24a89fa604a65e3670db9a9ec92390aafcd9783` |

The installed `Libs_Keyboard.xaml` merges `DataTemplates_k.xaml`;
`Libs_Controller.xaml` merges `DataTemplates_c.xaml` and
`ActionResourceTemplates_c.xaml`.

The core visual difference is now **confirmed**, not inferred:

| Resource key | Keyboard | Controller |
| --- | ---: | ---: |
| `ActionResources.ActionPointGroupSize` | 56 | 80 |
| `ActionResources.ActionPointSize` | 48 | 80 |
| `ActionResources.ActionPointSmallSize` | 24 | 36 |

For `ActionPoint` and `BonusActionPoint` the keyboard-specific
`ControlTemplate` resolves `ActionResources.ActionGroup.ActionPoint`
(the shared, TypeId-driven native glyph). Their controller
counterparts instead resolve `ActionResources.ActionGroup.ActionPointWithBG`
(the shared background-backed glyph). Other keyboard resource groups,
including SpellSlot, also forward to the same shared point glyph.

The controller `ActionResourceTemplates_c.xaml` introduces an independent
`ActionResourcesTemplateSelectorResourcePoints` and a
`ActionResources.ActionGroup.ActionPointResourcePoints` template used
by the native controller resource bar. CAM does **not** use that style,
but does inherit controller-mode resource sizes and dynamic
group-template keys from the loaded controller dictionary.

## 0.0.93 isolated keyboard presentation adaptation

Instead of adding another CAM-specific bitmap renderer, the
controller-owned preview explicitly selects one locally named
`CAM_KeyboardHotBarPointGroup` whose only content is the **native shared**
`ActionResources.ActionGroup.ActionPoint` DataTemplate, matching the
actual keyboard-specific group mappings.

Within the `VMActionResourceCostPreview` item root (not globally), CAM
defines the exact keyboard `ActionResources.ActionPoint*` resource values
56 / 48 / 24. The existing native `ActionResourcesTemplateSelector`
continues to own TypeId-specific sizes (e.g. 44 for action and spell
points), MaxGroupActionPoints, available/used/hover state,
quantities and icon-path selection.

The rejected 0.0.91 CAM image duplication is deleted. No keyboard
library is globally merged, no original game UI file is copied, no
TypeId/character-class icon table is invented, and no provider,
controller input or action-dispatch semantics change.

**Evidence boundary:** both template and sizes are pinned to the
installed game XAML; CI verifies markup, package and VBS install flow.
Noesis binding resolution and actual visual pixel parity remain
runtime-unverified until one game observation. If there is still no
visual improvement after 0.0.93, investigate dynamic resource
lookup/visual-tree resolution rather than creating new scale variants.
