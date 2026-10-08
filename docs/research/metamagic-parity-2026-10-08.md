# Native metamagic UI contract — Xbox App BG3 1.8.910.0

## Input provenance

The operator's read-only Game.pak capture `bg3-controller-action-menu-inputs-20261008-132651.zip` was inspected; its `manifest.json` records game package version `1.8.910.0`, a single `Game.pak` scan, 45 extracted XAML files and no scan errors.

| Installed-game file | SHA-256 |
| --- | --- |
| `Mods/MainUI/GUI/Pages/HotBar.xaml` | `9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728` |
| `Public/Game/GUI/Library/DataTemplates.xaml` | `e536956cdfa04fc2a737bdc41e70696e5b712dfada966a90e7d7e69374911850` |
| `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` | `4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8` |

Raw captured Larian XAML is not shipped/committed here.

## Exact native findings

- Keyboard `HotBar.xaml` lines 1887–1893 render `FixedSideBar` **simultaneously** alongside other decks, with visibility bound to `FixedSideBar.SlotList.Count`; the sidebar `ContentControl` consumes the native `VMHotBar` via `HotBarTemplate` (`SlotList`).
- Shared `DataTemplates.xaml` defines `HotBarActiveSlotIndicatorMetamagic` at line 1213, with `IsActive=True` trigger at line 1225.
- Shared `DataTemplates.xaml` lines 1617–1630 select this active-slot adornment when the native `VMHotBarSlot.Content.IsMetaMagic=True`.
- The same template lines 1685–1688 sets `MetaMagicOverlay.Template=HotbarSlotGlow` when `VMHotBarSlot.Content.IsModified=True`. This is a **BG3-owned spell modification signal**.
- `HotbarSlotGlow` (lines 1333ff) uses `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.CurrentSpellTask` as an additional native animation condition.
- Native controller `PreloadedActionRadials_c.xaml` lines 377–380 likewise show modified action visuals for `Content.IsModified=True`; lines 410–418 dim unmodified spells while `MetamagicActive=True`; lines 420–427 use `IsActive` and `Content.IsMetaMagic` for active metamagic; lines 664–670 use `MetamagicActive` for non-modified slot dimming.
- The native controller radial's separate metamagic *assignment* catalog at lines 1274–1280 filters `Stats.Passives` with `TogglableMetaMagicPassivePredicate`; that is assignment data, **not** an executable hotbar slot provider, so CAM must not dispatch it.

## CAM regression at main c2dd4eaa

- `CAM_MetamagicModeToken` replaces the one `HotBarList.ItemsSource` with `FixedSideBar.SlotList`. This removes the spell grid rather than providing a parallel view.
- `CAM_ActionGridSlotTemplate` omits `IsModified` and active-metamagic presentation. Native VM status is not a substitute for a missing visual template.
- `FixedSideBar.SlotList` is not guaranteed to contain metamagic exclusively; display native list without a synthetic classifier.
- The resource glyph path correction in `0.0.98` is accepted and must be preserved unchanged.

## Safe composition

1. Render one additional, count-conditional `LSListBox` bound directly to native `FixedSideBar.SlotList`, in parallel with the existing action grid. Its cells must retain `VMHotBarSlot` identity.
2. The existing Metamagic shoulder navigation may focus the side list while preserving a BG3-native resource-filtered central spell grid; no new direct-execution path. All interactions continue through `ActionRadials.Tag -> UseSlotCommand(slot)`.
3. Add only native-state-driven modified-spell and active-metamagic indicators to the existing 104×104 controller cell template. Do not apply whole keyboard `HotBarSlotStyle` (keyboard geometry/hotkeys), invent compatible spell tables, or reimplement modifier/cost rules.
4. Keep one coherent focus/tooltip/action-tag owner at a time; both lists must clear stale focus state on handoff. Preserve B/nested behavior and resource visual/focus tests.

## Proof boundary

Static/package CI can prove bindings, source hashes, native template identifiers, XML validity, provider unchanged and no SE/installer regression. Whether native Noesis focuses the added list correctly, whether filtered spell VMs update their `IsModified` status and whether command effects/costs stay correct requires **one combined sorcerer in-game proof**, not a speculative series of graphical test builds.

Do not close #125 or claim gameplay parity before operator verification.

## Operator runtime observation on v0.0.100

The operator confirmed in BG3: entering the metamagic tab via LB/RB
fails, tab cycle resets to its first item, the parallel sidebar always
shows focus and mirrors main-grid focus, and metamagic cannot be
executed. This is a **runtime rejection** of the two-independent-focus
composition from 0.0.99/0.0.100, despite green CI.

Static source audit found that passive
`CAM_FixedSideBarList.LocalFocusChanged` wrote
`CAM_ProviderModeMarker.Tag`, mutating the top-level tab state, while
both selectors simply tracked list visibility instead of active focus
ownership. The corrected candidate keeps the sidebar visible but
disabled outside its explicit Metamagic mode, disables the main grid
while that mode owns input (except native nested actions), and gates
both tooltip/dispatch and selector visibility by actual owner. All
provider transitions are controlled by LB/RB, not events from the
background list. These are source-verified corrections, **not yet
proven in-game**.

## Operator runtime observation on v0.0.101 and sourced compatibility feedback

The operator confirmed in game that v0.0.101 now moves focus to the
Metamagic column and visibly toggles the native metamagic selection.
When CAM is closed/reopened the metamagic slot still shows active;
this is bound to BG3-owned `VMHotBarSlot.IsActive`, so persistence
alone is not evidence of a stale UI state. Whether a real spell
remains modified after reopening needs runtime proof; **do not**
automatically clear this native state.

The spell grid currently shows only `Content.IsModified ->
HotbarSlotGlow`, but omitted a second essential behavior of the
installed controller radial: BG3 `MetamagicActive=True` dims
**non-modified** spell slots. Source research above records the
installed controller `PreloadedActionRadials_c.xaml` native triggers.
A historical public ActionRadials XAML independently resolves the
scope of the same native property as
`UIWidget.DataContext.CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.MetamagicActive`
and applies a weak disabled overlay and opacity 0.7 for unmodified
spells. This older dump is corroboration, not the source of the
current Patch 8 slot-content property:
https://github.com/akintos/bg3-data/blob/main/Public/Game/GUI/Widgets/ActionRadials.xaml

The 0.0.102 candidate uses the current Patch 8 `Content.IsModified`
plus `SlotType=Spell` and native `MetamagicActive` to show the
original subdued incompatible-spell state while preserving the
existing native glow for modified spells. It neither changes spell
VMS nor reexecutes the resource filter and it does **not** prove that
`SingleHotBar.SlotList` exposes up-to-date modified state at runtime.
No claim of in-game success before verifying both spell highlights
and actual metamagic cost/effect. Issue #125 stays open.
