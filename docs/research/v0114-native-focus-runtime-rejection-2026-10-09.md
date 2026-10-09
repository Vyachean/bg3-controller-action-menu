# v0.0.114 real BG3 controller test — source-backed focus-owner correction

**Target:** Xbox App PC BG3 1.8.910.0; user-installed published
`v0.0.114-native-state-probe` on 2026-10-09.
**Proof:** direct operator report; no diagnostic-panel values/screenshots were
supplied, so do not reconstruct/guess those values from appearance.

## User-confirmed behavior

1. First entry into the Metamagic tab focuses the first native modifier.
2. Selecting it switches the grid focus to an ordinary action (`Throw`),
   confirming the list is **not** a compatible-spell-only provider.
3. B returns input toward the modifier sidebar, but there is **no visible
   focus anywhere**. Pressing Down highlights the *second* modifier.
4. B again closes the mod. Reopening shows the modifier still active.
5. After visiting other tabs and returning to Metamagic, again the ring is
   missing until Down highlights the second modifier.
6. The IV resource tab still opens BG3's separate level choice after
   selecting a skill.
7. Footer controller hints remain horizontally misaligned relative to vanilla.
8. Weapon switching is still broken.

## Proven XAML-level contradiction (#155)

PR #180 intentionally made the sidebar's `LSListBox` non-focusable to
align with the captured Patch 8 slot-grid structure. That was sound
only if focus is delegated to the *focusable* slot-item containers.
CAM nonetheless left **four** deferred `SetMoveFocusAction` calls
targeting the now non-focusable `CAM_FixedSideBarList`: from summoned
provider handoff, both shoulder tab-entry timers and B's phase-back
handler. At B exit, the code also set `SelectedIndex=0` while a
late deferred focus request still targeted the container.
The v0.0.114 observation distinguishes selection from actual focus:
index zero is selected, no ring is visible and the next Down lands
on index one.

The existing `CAM_ActionGridSlotContainer` has a source-backed
mechanism: when `CAM_ResetFirstFocusToken` is armed on the parent
list, *the first selected native ListBoxItem itself* invokes
`SetMoveFocusAction(DeferFocusAction=True)` with
`FocusElement={Binding RelativeSource Mode=TemplatedParent}` and
then clears the token.

## Smallest supported repair candidate

Use this **existing** item-local transport for all four sidebar
entry/return sites:
- Set `CAM_FixedSideBarList.Tag=CAM_ResetFirstFocusToken`.
- Force `SelectedIndex=-1` then `0` so selection triggers the item.
- After B's spell phase, reset `CAM_MetamagicSpellPhaseMarker`
  **before** arming the item, so the real sidebar is enabled.
- Remove the four invalid deferred focus calls to the list *itself*.

Keep `CAM_FixedSideBarList.Focusable=False`,
`CAM_FixedSideBarPanel` as the single directional owner,
`VMHotBarSlot -> ActionRadials.Tag -> UseSlotCommand`,
all native B/close commands, and tooltips/resource-preview paths
unchanged. Update **all** old assertions incorrectly requiring a
focus request to the non-focusable list. Add negative mutation coverage
rejecting its reintroduction. Static CI validates only source structure;
this remains an in-game **candidate**, not a proven terminal focus fix.

## Independent unresolved defects — do not infer fixes

- B's CAM phase reset is **not** proof that BG3 cancels
  `MetamagicActive`; the operator explicitly confirms stale selection
  after close/reopen. No speculative game-state mutation.
- The resource-filtered `SingleHotBar.SlotList` still contains
  `Throw` and other actions. `Content.IsModified` controls
  presentation, not proven executable membership.
- `FilterActionResourceCommand` does not prove a specific IV-level
  `VMUpcast`; retain native chooser until an engine-owned level-specific
  executable slot is established.
- Footer alignment and weapon hold/rearm input still require original
  Patch 8 source/behavior analysis, not arbitrary width/input changes.
- Because no state readout values were supplied, compiled cancel,
  pending spell task, or native binding effects remain **unknown**.

**Delivery:** branch-only code correction; no further incremental
published release or manual micro-test. If it passes CI, batch with
other *source-proven* independent corrections into the next
single operator game milestone. The published `0.0.114` remains
the original diagnostic experiment; a successful build is not a
runtime acceptance.
