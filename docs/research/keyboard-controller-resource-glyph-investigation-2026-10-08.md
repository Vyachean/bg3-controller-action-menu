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


## 0.0.95 runtime rejection → 0.0.96 exact keyboard dictionary

The 0.0.95 operator screenshot shows dramatically reduced/clipped
point symbols and continued divergence from the keyboard HotBar.
The hypothesis that a fixed 24×24 point bitmap solves the problem is
rejected. We must stop inventing per-point sizes.

The installed game capture shows:
- `DataTemplates_k.xaml`: 24 `ActionResources.ActionGroup.*`
  ControlTemplates in one contiguous 6,186-character block.
- `DataTemplates_c.xaml`: different controller point-group definitions.
- `DataTemplates.xaml`: shared `ActionResourcesTemplateSelector`,
  using `DynamicResource ActionResources.ActionGroup.*` for every
  TypeId-specific point group. The same shared template has native
  animations, point-state image variants and paths.
- The original `HotBar.xaml` uses that shared selector with
  keyboard group templates and `56/48/24` base sizes.

The full keyboard block is copied into CAM's resource-tile local scope.
Cross-check of captured `DataTemplates_k.xaml` against the upstream
Patch 8 source copy agrees on 6,186 characters and FNV32
`5254fbdf`; authoritative capture SHA-256 for that exact
block is `9e017778ec41ef2e03f192392ca944640f7d8ad3c227f69d9742aefbdaff4651`.

We have not yet proved whether Noesis resolves all
`DynamicResource` lookups from this new local scope. If keyboard
parity remains absent in the next runtime proof, treat local-resource
resolution or more distant scope as the next investigation target
rather than copying another custom bitmap or changing its dimensions.


## 0.0.96 runtime rejection — theme source not included in earlier capture

Operator screenshot `image(10).png` demonstrates that copying the 24
unmodified keyboard group templates into controller CAM is **not**
sufficient. Specifically keyboard flame, blue sun and clover icons remain
collapsed into narrow columns and spell-slot square groups retain
incorrect aspect/size, while the original HotBar displays full shapes.

The native keyboard UI resource graph uses
`DefaultThemeLibs_k.xaml -> DefaultTheme_k.Styles.xaml`, while the
controller uses `DefaultThemeLibs_c.xaml -> DefaultTheme_c.Styles.xaml`.
The earlier archive contains `DefaultThemeLibs_c.xaml` but NOT
the keyboard/controller theme *style* files. The shared
`DataTemplates.xaml` actually creates each resource glyph from
`IconIdToSourceConverter` and `StaticResource ActionResourcePointIconsPath`,
plus three state-specific path keys. Literal keyboard group templates
continue to reference the same shared glyph; copying them does not
force the keyboard image-path keys or bitmap assets.

We must resolve the exact current 1.8.910.0 theme path definitions
BEFORE another art change. 0.0.97 restores the proven, read-only
release-controlled developer capture and targets the missing
`DefaultTheme_k.Styles.xaml`, `DefaultTheme_c.Styles.xaml`,
`DefaultShared.Styles.xaml` and theme dependency dictionaries.
It **does not** alter the game or CAM runtime. The helper requires
these three exact current-game XAML files and fails closed if missing,
preserving the archive and a missing-group diagnosis.

After obtaining the files, compare
`ActionResourcePoint[Highlight|Used|Missing]IconsPath`, the
default icon converter/TypeId mappings and keyboard-vs-controller theme
definitions. Then make **one source-proven** rendering change; do not
again copy keyboard group templates or scale individual bitmaps.


## 0.0.97 failed-capture archive — exact proven root cause, 0.0.98 correction

The operator's failed-status archive
`bg3-controller-action-menu-inputs-20261008-132651.zip` **is usable**.
Capture wrote all extracted XAML files before its erroneously strict
`KeyboardThemeStyles` group check. It required
`Public/Game/GUI/Theme/DefaultTheme_k.Styles.xaml`, a file that does
not exist in this installed BG3 1.8.910.0 package. The keyboard
dictionary is actually **`DefaultTheme.Styles.xaml`** and the
controller dictionary is `DefaultTheme_c.Styles.xaml`:

| Resource key | keyboard (DefaultTheme.Styles.xaml) | controller (DefaultTheme_c.Styles.xaml) |
| --- | --- | --- |
| `ActionResourcePointIconsPath` | `Assets/Shared/Resources/` | `Assets/ActionResources_c/Icons/Resources/` |
| `ActionResourcePointHighlightIconsPath` | `Assets/Shared/Resources/Highlight/` | `Assets/ActionResources_c/Icons/Resources/Highlight/` |
| `ActionResourcePointMissingIconsPath` | `Assets/Shared/Resources/Missing/` | `Assets/ActionResources_c/Icons/Resources/Missing/` |
| `ActionResourcePointUsedIconsPath` | `Assets/Shared/Resources/Used/` | `Assets/ActionResources_c/Icons/Resources/Used/` |

The installed `DefaultThemeLibs.xaml` merges
`DefaultTheme.Styles.xaml`, while `DefaultThemeLibs_c.xaml`
merges `DefaultTheme_c.Styles.xaml`. The shared game-owned
`DataTemplates.xaml` `ActionResources.ActionGroup.ActionPoint`
DataTemplate contains **StaticResource** bindings to these four
keys, including default, highlight, missing and used states.
When CAM runs in the controller theme, referencing that shared
native template does **not** force the keyboard bitmap directory.
The 24 copied keyboard group ControlTemplates of 0.0.96 still
reference the shared point DataTemplate and cannot change its
already-resolved StaticResource paths. This explains persistent
large, incorrect controller-mode glyphs despite source-identical
group templates.

The correction copies the original **8,143-character**
`ActionResources.ActionGroup.ActionPoint` DataTemplate *unchanged*
from the installed `DataTemplates.xaml` into CAM's resource tile
`Grid.Resources`; SHA-256
`eee27b44205de8d3fbacac302c9427b8c33f785fea0f39b9b4dfda51cba22d84`.
Immediately preceding the native point DataTemplate, local
`System:String` resources define the **four exact keyboard paths**.
The 24 original keyboard group ControlTemplates remain declared
after the local point DataTemplate, so each group's
`ContentPresenter ContentTemplate="{StaticResource
ActionResources.ActionGroup.ActionPoint}"` resolves the local
keyboard-themed template. The game retains the native converter,
resource TypeId, animations, cost, counters and
`ActionPointState` triggers without class-specific icon maps.

This makes all resource graphic dependencies explicit and scoped
inside the mod's resource item, not a global override to other game UI.
The incorrect Capture requirement is corrected to
`DefaultTheme.Styles.xaml`, and the same operator-facing VBS returns
to its canonical release-controlled install/update workflow for 0.0.98.

**Acceptance:** equality of native XAML and theme path sources is
proved statically, but actual Noesis rendering still needs one
in-game screenshot. If parity fails, inspect in-game resource
lookup/template precedence rather than editing image sizes again.
