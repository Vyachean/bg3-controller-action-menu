# One consolidated 0.0.115 Xbox App controller milestone

**Build:** `v0.0.115-consolidated-native-input`  
**Game:** Xbox App / PC BG3 1.8.910.0  
**Publication gate:** ordinary merge after Validate and Build package,
then successful non-draft GitHub Release + verified installer resolution.  
**Game runtime:** UNVERIFIED until the operator's one combined run.

## Delta from operator-tested v0.0.114

| Change | Source change | What CI proves | What the game must still prove |
| --- | --- | --- | --- |
| #182 / #155 Metamagic tab and B focus | The first focusable native `ListBoxItem` receives `CAM_ResetFirstFocusToken` and a fresh -1 → 0 selection, no focus request to non-focusable `CAM_FixedSideBarList` | Exact four return/entry routes, native item focus ownership, no competing sidebar direction handlers | Visible ring, tooltip, A dispatch agree on first real modifier after B and LB/RB revisit; Down doesn't select the second as the first visible result |
| #183 / #167 Footer | Separate bounded right/bottom lane from native compact center/center/LTR auto-width hint arrangement | Exact source layout and native hint control/command continuity; no new shortcuts | Horizontally aligned in original BG3 lane without overlap, including 1080p |
| #186 / #158 Parent metamagic B | Restore exactly one game-owned `ActionCancelCommand` *before* CAM local phase/focus reset; four ordinary/nested cancel paths unchanged | Native call exists, exactly once, on guarded parent B; negative mutants reject missing/duplicate/late call | Native `MetamagicActive` genuinely clears and stays cleared after close/reopen without consuming resources; no double B exit |
| v0.0.114 probe retirement | Remove all 17 passive diagnostic Text bindings and whole probe border | `tools/audit-state-probe.py` fails if it survives in non-diagnostic versions | Screen no longer has temporary right-side debug panel |

**This is a normal candidate release for *one* combined game test, not
a claim that those three corrections are game-proven.**

## Operator test — single run, no new diagnostics setup

Open the latest release with the existing universal VBS, in an
existing sorcerer save, then check all of the following *during one
game session*. No extra character, recording, new installer or log
collection needed.

1. **B and game-owned metamagic:** On the Metamagic tab A-select one
   modifier, then B once. Verify a visible focus ring on the first
   modifier, and whether that metamagic is no longer active. B again
   should close exactly one menu. Reopen and check that metamagic
   did not remain selected. If it *does*, the compiled native cancel
   semantics are still unknown; do not claim this candidate succeeded.
2. **Repeated focus handoff:** LB/RB away and back to Metamagic:
   does the *first* modifier have an actual ring/tooltip without an
   initial Down? Test Down at the final modifier once if convenient;
   it must not land on an invisible focus target.
3. **Original controller footer:** Check button hints at bottom right
   horizontally align as in vanilla, do not intrude on the original
   lower-middle resource HUD. With ranged weapon access, look for the
   weapon-hold glyph/progress; attempt two consecutive holds only if
   convenient. A broken weapon switch remains #154 regardless of
   correct geometry.

Report a brief result with 1–2 screenshots if a problem is visible.
There is **no need to re-test the known broken spell-compatible
action catalog or IV upcast twice**; they are explicitly out of
scope of this build.

## Known unresolved defects (not hidden by release)

- #158/#125: `SingleHotBar.SlotList` is still resource-filtered, not
  proven compatible-only; after selecting a modifier, ordinary
  "Throw" can still appear. Do NOT filter by static spell names or
  treat the visual `Content.IsModified` as an executable collection.
- #172/#156: selecting IV still uses BG3's safe native upcast chooser.
  The historical keyboard `CurrentActiveSlot.Spell.SpellUpcast`
  / `VMUpcast` evidence has not been verified as an available
  level-specific executable source in installed Patch 8 controller.
- #154: no proven native repeatable on-menu weapon hold
  transport/haptic/animation; footer layout does not prove input.
- #160: LB opening haptic/sound parity remains unverified.
- #155: terminal D-pad focus under dynamic list updates remains
  unproven, even with the valid item-level focus owner.

Keep those issues open until direct game proof. Native costs, targeting,
execution, highlighting, modifier state, preview and localization
remain game-owned.

## Packaging and rollback

One self-contained `.pak`, no Script Extender, DLL, native overlay,
runtime Game.pak extraction, or installer changes. Published
`v0.0.114-native-state-probe` remains immutable as a rollback
reference. The universal VBS should select the latest non-draft
published release only after the Release workflow confirms its
assets and installer-visible tag. No rebases or squash merges.
