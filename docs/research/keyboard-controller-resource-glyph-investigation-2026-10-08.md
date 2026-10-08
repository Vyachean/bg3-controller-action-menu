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


## 0.0.94 — fail-closed runtime diagnostic (not a visual fix)

Operator explicitly reports no tab-icon improvement after installed
v0.0.93. The version-specific 56/48/24 XAML values were partly already
set on native point control in earlier versions, and 0.0.93's locally
named `ActionPointTemplate` did not prove which image actually wins.
The previous visual hypothesis is rejected.

This diagnostic places two independently rendered representations
inside the **same native VMActionResourceCostPreview item** without
changing its commands, selection, spell overlays, resource counts or
source collections:

1. A = existing `LSActionPointResources` and all its native styles;
2. B = 20x20 `Image` with explicit `IconIdToSourceConverter`, using
   `ActionResourcePointIconsPath` and the item's
   `ActionResource.TypeId`, not the `LSActionPointResources` point
   template, grouping or point-state logic;
3. `94` = visible yellow per-item fingerprint proving active CAM
   resource-item template, independent of which VBS or PAK was installed.

Read the screenshot as follows:

| Observed | Conclusion | Next step |
| --- | --- | --- |
| `94` absent | The new CAM resource template is not active or visible. | Prove package/load conflict; do not alter icon sizes. |
| `94` present, B correct shape, A malformed | Point control/style/group presentation differs. | Repair effective renderer, not icon path. |
| `94` present, B malformed like A | Effective native point-path/icon/fallback is suspect. | Capture actual named asset(s) and create a resource path with proven keyboard bitmap. |
| `94` present, B blank | Direct TypeId/source converter binding failed. | Inspect binding scope; cannot conclude bitmap mismatch. |

The B icon is deliberately uniform-scaled, so **compare shape**, not
relative size. The overlay is temporary and must be removed after
one discriminating observation. This does not complete issue #119.


## 0.0.94 observed runtime result and 0.0.95 change

Screenshot `image(8).png` proves the in-game resource row is the
0.0.94 template: the extra per-resource yellow/magenta overlays appear,
so XAML installation and item renderer activity are established.
The large native A glyphs remain partially clipped (flame appears as
a solid vertical red bar; clover as green bar; spell-slot points
appear as elongated cyan rectangles). The small independently bounded
B renderer uses the same native `IconIdToSourceConverter` and
`ActionResourcePointIconsPath` but does not inherit
`LSActionPointResources` image sizing.

This distinguishes an image-measurement/clipping problem from an
unapplied item template. It does **not** establish identical keyboard
bitmap contents at any specific size or the exact XAML precedence of
the `LSActionPointResources.ActionPointTemplate`.

0.0.95 removes both proof overlays and replaces the native per-point
unbounded `Image Stretch=None` with a state-aware native converter
image constrained by `Width=24 Height=24 Stretch=Uniform`, matching
the captured keyboard `SmallActionPointSize=24`. The
`LSActionPointResources` source/count/availability grouping still
owns every per-resource point. The 0.0.91 attempt also authored a
native converter image, but left `Stretch=None`, which did not
resolve the underlying image clipping; do not mistake that earlier
failed attempt for proof that explicit image measurement is ineffective.

Static and package checks prove XAML shape only. If an in-game screenshot
still shows wrong native resource bitmap shapes or counts, do not
claim correction or add another arbitrary size multiplier: investigate
native `ActionResourcePointIconsPath` source resolution and the
keyboard/controller bitmap identity before another release.
