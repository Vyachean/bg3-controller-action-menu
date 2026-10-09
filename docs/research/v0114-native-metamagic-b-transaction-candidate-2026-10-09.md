# Metamagic parent B: restore the game-owned cancellation seam

**Date:** 2026-10-09  
**Target:** Xbox App BG3 1.8.910.0  
**Status:** **source-backed runtime candidate, NOT game-accepted**.  
**Shipping release:** remains `v0.0.114-native-state-probe`, not rebuilt.

## Operator rejection and root cause

In the published 0.0.114 run, choosing a metamagic modifier
transitioned to the general action grid; pressing B moved CAM back
toward the metamagic list; another B closed Actions; reopening still
showed the modifier active in BG3. The first B was only a presentation
return, not a game-owned cancellation attempt. CAM explicitly deleted
the ordinary native `ActionCancelCommand` from that route because it
previously assumed preserving `MetamagicActive` was correct.

The currently pinned controller UI proves that BG3's ordinary/nested
`LSButtonReleased` routes invoke the existing
`ActionCancelCommand` on `UICancel`. The four routes for ordinary
providers and nested variants, upcast and Throw are already present.
CAM's metamagic spell-choice **parent**, when all nested flags are
false, was the sole exception: `CancelButton.Command={x:Null}` and
the release handler only cleared CAM marker/focus/tooltip.

PR #184 previously corrected the *tests* that had incorrectly
required the rejected behavior. This PR restores the same native
command on the fifth, disjoint parent route.

## Minimal shipping XAML delta

Inside the single guarded `CancelButton.LSButtonReleased` handler for
`CAM_MetamagicModeToken` +
`CAM_MetamagicSpellPhaseToken` +
`IsShowingAContainerWithVariants=False` +
`IsSelectingUpcastedSpell=False` +
`IsShowingItemsToThrow=False`:

1. Invoke `{Binding ActionCancelCommand}` **exactly once**.
2. Then clear local `ActionRadials.Tag`, tooltip, highlights and
   main-grid focus.
3. Reset `CAM_MetamagicSpellPhaseMarker` and rearm the existing
   first real `CAM_FixedSideBarList` item-focus token established by
   #182. Do **not** focus the non-focusable outer list.

All ordinary/nested native cancel branches are untouched. No custom
Osiris `UseSpell`, passive ID, `TogglePassive`, `VMUpcast`,
synthetic action-cost calculation, second gameplay command, imported
library or additional bound controller event.

## Source-only mechanical acceptance

`tools/audit-controller-known-runtime-failures.py --assert-cancel-source`
now refuses:

- an absent or duplicated native parent `ActionCancelCommand`;
- that command placed after local UI presentation reset;
- loss of one of the other four native cancel routes;
- disabled native `UICancel`/`ClearSingleHotbarCommand`;
- broken top-level `CloseWidget`;
- redirected focus to non-focusable sidebar;
- loss of concrete slot focus handoff.

It includes intentional negative mutations for missing, double and
late command, and asserts `runtimeAccepted=False` and native
metamagic rollback `UNPROVEN` even for the correct XAML. The shipping
PowerShell test separately gates exact source count and order.

## Explicit gameplay proof boundary

- **Unproven:** the implementation of the compiled BG3
  `ActionCancelCommand` and whether it clears the game-owned
  `PlayerCharacterProperties.MetamagicActive`, selected native
  metamagic passive, and pending task in this precise context.
- **Unproven:** whether `CancelButton` with `Command={x:Null}`
  forwards the same release semantics in all gamepad configurations.
  0.0.114 B's visible local transition confirms the handler runs in
  at least the operator's observed setup, not a universal guarantee.
- **Unchanged:** choosing a modifier still uses the native
  `UseSlotCommand`; central resources can still include Throw and
  other incompatible actions. This PR does NOT claim filtering.
- **Unchanged:** selected IV still enters native upcast level choice;
  skipping it without a `VMUpcast` identity remains unsafe.
- **Unchanged:** direct close from other states (including LB/RB
  provider change without B), weapon-switch input, footer and
  metamagic last-item boundary are not repaired by this one call.

**One future combined game test** (not one special-purpose version):
select modifier, confirm active; B once; inspect game-owned active
metamagic and focused real sidebar slot; B close; reopen and verify no
stale modifier and no extra spell resource spent. Also test one native
nested metamagic-upcast B return and ordinary no-metamagic B, along
with other already queued independent runtime candidates.

If the native command does not actually rollback, keep #158 open and
reinvestigate the native transaction; do NOT fake `MetamagicActive`
with presentation-only markers or a guessed toggle.
