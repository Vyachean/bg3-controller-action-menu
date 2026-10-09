# Restoring the native controller focus owner: 0.0.29 vs 0.0.115

**Date:** 2026-10-09. **Target game:** Xbox App PC BG3 1.8.910.0.
**Status:** research + deterministic source diagnostic; **NO game-code change**,
**NO new release**. The operator directly rejected 0.0.115's runtime
behavior despite green package/CI checks.

## Stronger, unusually relevant historical proof: CAM itself

The repository's immutable release
[`v0.0.29-focus-origin-fix`](https://github.com/Vyachean/bg3-controller-action-menu/releases/tag/v0.0.29-focus-origin-fix)
has commit `6dcc62c4abfb9cae6dafe54ac5bec3894c2c7fc9`
and its **source generator** is
[`tools/native-overlay.ps1`](https://github.com/Vyachean/bg3-controller-action-menu/blob/6dcc62c4abfb9cae6dafe54ac5bec3894c2c7fc9/tools/native-overlay.ps1).

This was the old **developer-side game-PAK-derived** build workflow,
NOT a permissible install-time dependency for current end users.

Specific, inspectable architecture:
- `Get-FirstInteractionTriggers`, lines 152–166, extracts the
  native `<b:Interaction.Triggers>...</b:Interaction.Triggers>`
  **unchanged** from each original `ls:Radial` renderer.
- `New-GridRenderer`, lines 169–216, replaces only the radial
  renderer with a focusable-slot `LSListBox`, matching
  `LocalFocusSelector` and grid selector inside the **same visual
  root**. It re-inserts the original interaction trigger markup,
  rather than reimplementing `ActionRadials.Tag` publication.
- `Convert-PageStyleToGrid`, lines 317–340, operates on the
  native `HotBarRadial` and `SingleBar`; no CAM metamagic-phase
  state machine or 70ms `LocalFocusChanged` Tag adapter.
- `New-ControllerLibraryFromNative`, lines 356–514, extracts
  *specific* current native page styles, item container and
  `ActionRadialWidgetTemplate_P8` and changes presentation,
  leaving BG3's page and outer A/B commands intact.

**Actual historical runtime observations**, documented in the
same commit's
[`docs/testing.md`](https://github.com/Vyachean/bg3-controller-action-menu/blob/6dcc62c4abfb9cae6dafe54ac5bec3894c2c7fc9/docs/testing.md):
- 0.0.27: grid actions and native input/focus worked;
- 0.0.28: central grid positioning worked, but **selector frame**
  was misplaced due to different coordinate-space parent; **data
  focus/navigation was not reported broken**;
- 0.0.29: both selector and list placed inside one root to fix the
  verified visual coordinate-space defect without changing native
  `LocalFocus`, `ActionRadials.Tag`, A/B, or paging.

**Important limitation:** these releases used user-configured
radial slot data, not the promised automatic, resource-filtered,
mod-compatible catalog. Rolling the old mod back wholesale would
break the product goal. The established benefit is the **native
focus transaction and co-located selector**, not its source list.

## Compared to source-shipping 0.0.115

The current
[`Lib_Controller.xaml`](https://github.com/Vyachean/bg3-controller-action-menu/blob/33570653dbb3722b1800f38834478992cb1f9981/BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml)
keeps native `UseSlotCommand(ActionRadials.Tag)` for A and real
`VMHotBarSlot` providers. But it has drifted from the proven
focus-transaction structure:

- The `CAM_ActionGridSlotContainer` ItemTemplate observes
  `ListBoxItem.IsSelected`; when the ancestor list stores a
  `CAM_ResetFirstFocusToken`, it requests deferred
  `SetMoveFocusAction(FocusElement=TemplatedParent)` and clears
  that token. The requested focus does not itself establish the
  game-owned `LocalFocus.DataContext`.
- The metamagic `CAM_FixedSideBarList` is not focusable; individual
  children are declared focusable. Its selector remains hidden
  unless `CAM_FixedSideBarList.LocalFocus.DataContext` is non-null.
  B and LB/RB can reset `SelectedIndex=-1 -> 0` while actual native
  focus remains unproven.
- `CAM_FixedSideBarList.LocalFocusChanged` **synchronously sets**
  `ActionRadials.Tag` to `{x:Null}`. A separate 70ms delayed
  `LocalFocusChanged` publisher writes
  `LocalFocus.DataContext` to the tag. A third publisher,
  70ms-delayed `SelectionChanged`, also writes it. The main
  `HotBarList` has its own focus/selection handlers and delayed
  actions. Meanwhile A always sends `ActionRadials.Tag` to
  BG3-owned `UseSlotCommand`.
- This proves an explicit **transient null parameter** and **more
  than one source publisher** in static markup. It does **NOT** prove
  which callback fired in a particular frame, or a specific engine
  misdispatch. The operator's invisible focus / unchanged
  metamagic and hint failures must remain separately logged.

Independent supporting primary sources:
- [Official NoesisGUI extensions](https://www.noesisengine.com/docs/Gui.Core.ExtensionsTutorial.html)
  separates `SetFocusAction` and `SelectAction`; choosing a
  selector item does not necessarily move keyboard/controller focus.
- [Older Noesis #1641](https://www.noesisengine.com/bugs/view.php?id=1641)
  documents a reentrant selection/focus trigger in **2.2.6**;
  this cannot be asserted as a BG3 3.1.6 bug.
- [Historical native ActionRadials](https://github.com/akintos/bg3-data/blob/31f3e066e90d4d5ce2b43b4a32d5917547765750/Public/Game/GUI/Widgets/ActionRadials.xaml)
  commits `LocalFocus.Tag` on `LocalFocusChanged`,
  preserving tooltip/highlight/dispatch identity. This is an
  older *different game UI version* and cannot replace current
  Patch 8 direct evidence.

## Reproducible source audit (not a fake engine emulator)

New `tools/audit-focus-owner-drift.py` reads shipping XAML,
derives actual per-list `LocalFocusChanged` and `SelectionChanged`
tag writers, records synchronous nulls, delayed slot writes,
event ownership, actual UIAccept command and IsSelected-triggered
focus requests in JSON. It can be rerun as:

```shell
python tools/audit-focus-owner-drift.py
python tools/audit-focus-owner-drift.py --self-test
python tools/audit-focus-owner-drift.py --require-single-owner
python tools/audit-focus-owner-drift.py --native-capture /path/to/PreloadedActionRadials_c.xaml
```

- The optional `--native-capture` command refuses to inspect the
  original resource unless its bytes match the **exact**
  `PreloadedActionRadials_c.xaml` SHA-256 from the operator's
  pinned Xbox App 1.8.910.0 evidence. When matched, it enumerates
  `HotBarRadial`/`SingleBar` native focus-to-tag publisher paths.
  No original proprietary bytes are committed or shipped, and a
  mismatched public Patch 8 archive cannot silently substitute.
- Default report and `--self-test` are **read-only** and do not
  make unsupported gameplay-success claims.
- `--require-single-owner` is deliberately **expected to fail**
  on current rejected 0.0.115 until the source structure is
  corrected. It is an **opt-in future architecture gate**,
  NOT a gate that makes current CI fail forever.
- Fixture self-test checks rejection of immediate-null + deferred
  write, confirms the special IsSelected focus-request contract
  and verifies a clean synthetic example **still reports
  `runtimeAccepted=false`**. It must never be represented
  as an actual BG3 focus/input unit test.
- Repository Validate runs the fixture; the rejected source report
  remains inspectable but not a release certificate.

## Next implementation design — proof obligations, not approved XAML

1. Obtain the **exact original pinned**
   `PreloadedActionRadials_c.xaml` from a previously captured
   read-only user archive, or a fresh authorized developer capture
   if no copy is accessible. Require the pinned
   `4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b`
   SHA-256 before treating any native focus handler as authoritative.
   The original proprietary XAML was intentionally not committed.
2. Reconstruct the original per-list *native* focus transaction:
   the game-owned actual focus item is committed to
   `ActionRadials.Tag` immediately from a single active focus
   event, and the selector is co-located in the same coordinate
   space. Compare against native selector
   `LocalFocusSelector`, first materialized focusable slot
   and native `LSGrid` event source.
3. Keep the **new resource-first automatic VMHotBarSlot providers**
   and exclusive active input owner for Metamagic and normal tabs;
   do not revert to manually configured radial wheels. Ensure
   original BG3 tooltip and cost highlight follow **the same**
   focused executable VM slot before considering release.
4. Make one constrained source and fixture-backed architectural
   correction; retain all native B/closing/upcast transactions.
   Do not claim game-owned metamagic rollback from
   `ActionCancelCommand` naming or bypass the upcast picker.
5. Ensure final user-installed artifact is still a self-contained
   GitHub-built PAK; the previous 0.0.29 installed-game derivation
   must **never** be restored as an installation requirement.
6. Once the actual native source equivalence and source regression
   contract are proven, plan **one consolidated** runtime milestone;
   do not require the operator to test each hypothesis.

Latest production `v0.0.115` stays **gameplay rejected**.
No game XAML, version, package, installer, controller action
or player-controlled configuration changed in this PR.
