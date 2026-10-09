# Native sidebar list focus handoff — source candidate

**Date:** 2026-10-09. **Tracking:** #176, #155. **State:** candidate;
not runtime accepted. The published v0.0.115 release remains rejected.

## Concrete discrepancy

In game-tested v0.0.29, `New-GridRenderer` replaced a native radial with
a real `ls:LSListBox`, kept `LocalFocusSelector` in the same visual root,
and transplanted the native `Interaction.Triggers` untouched. Its
`LSListBox` did **not** opt out of focus with `Focusable=False`.

The v0.0.115 metamagic sidebar instead explicitly sets
`CAM_FixedSideBarList.Focusable=False`. Five independent entry/return
routes arm `CAM_ResetFirstFocusToken`, toggle `SelectedIndex=-1 -> 0`,
and rely on a DataTrigger in the templated `ListBoxItem` to request
`SetMoveFocusAction(DeferFocusAction=True)`. That trigger's request does
not prove a new `LocalFocus`; the user observes no selector after B or
tab re-entry, and Down moves to the next cell. Current markup also
writes `ActionRadials.Tag` both on native-like delayed
`LocalFocusChanged` and on another delayed `SelectionChanged`.

These are inspectable CAM-specific deviations, not evidence of a
Noesis engine bug or confirmed causal explanation.

## Constrained change

- Re-enable native list-level focus on `CAM_FixedSideBarList` with
  `Focusable=True` and `ls:MoveFocus.Focusable=True`.
- Every one of the five sidebar entry/restore routes makes an explicit
  deferred `SetMoveFocusAction` to this now-focusable list, **after**
  selecting its first item. The list's actual `LocalFocus` still
  determines the executable `VMHotBarSlot`; `SelectedIndex` does not.
- Remove sidebar `CAM_ResetFirstFocusToken` arming; leave the shared
  container's existing token-based handling for *other providers*
  untouched in this deliberately limited change.
- Remove sidebar's additional `SelectionChanged` delayed dispatch
  publisher. Preserve the original captured-native-like immediate
  clear / 70ms `LocalFocusChanged` publish and native
  `UseSlotCommand(ActionRadials.Tag)` execution.
- Preserve the resource-first filter providers, nested/upcast handling,
  metamagic execution, original B binding and installer unchanged.

## Verification

`tools/test-native-sidebar-focus.py` verifies actual XAML structure,
five concrete sidebar entry paths, one focus publication event source,
and fault-injected negative cases (unfocusable list, misrouted transfer,
duplicate selection dispatcher). `tools/validate.py` executes it.
The source audit does **not** pretend to simulate or certify Noesis.

## Follow-up: main-list focus and execution owner

A separate, concrete ordering gap was found during the source review:
the Passives and Items *nested-return* branches wrote
`HotBarList.Tag=CAM_ResetFirstFocusToken` followed by
`SelectedIndex=0`, without first deselecting the previous index.
The same pattern occurred on the initial delayed Loaded path.
But `CAM_ActionGridSlotContainer` requests real focus only inside
a `b:DataTrigger(IsSelected=True)`, conditional on the parent token.
If the container was already selected, the selection event is not
guaranteed by these actions, so the focus request can be skipped.
That is a direct markup-level control-flow gap; it does **not**
constitute proof of a specific game engine event failure.

The candidate now clears stale `HotBarList.LocalFocus` on those
two direct-provider returns and explicitly cycles `SelectedIndex=-1`
then `0` on both, plus on initial Loaded. This ensures an actual
selection-state transition is requested for the token-gated item
focus action, rather than merely writing its existing value.

Main `HotBarList` also had two event sources publishing
`ActionRadials.Tag`: native-like delayed `LocalFocusChanged` and
another 70 ms delayed `SelectionChanged`. The latter was removed
because selection is not itself a focus commit; it could re-publish
a previous `LocalFocus` during a source switch. The main list and
the metamagic sidebar now both write non-null dispatch identity
only on their `LocalFocusChanged` lifecycle. The separately
rendered lists must still be proved mutually exclusive at runtime;
their source-level `IsEnabled` guards alone do not prove atomic
handoff across nested states.

**Regression risk:** the old `SelectionChanged` timer also served
as a fallback for tooltip/cost presentation on programmatic
selection. If `LocalFocusChanged` never fires after the new
deselection / focus request, initial tooltip and A may remain
unavailable. That is safer than dispatching the wrong slot but
does not satisfy UX acceptance. No static test can resolve this:
the game-owned `LSListBox` must be observed at a later consolidated
milestone. Never claim this is runtime-fixed solely from a green
package check.

## Follow-up: focus-loss invalidation and resource switch

The sidebar's synchronous `LocalFocusChanged` event had a conditional
expression requiring `LocalFocus.DataContext != null` **around the
entire handler**. That made its `ActionRadials.Tag = null` action
unreachable when the actual focus became null while the sidebar was
still enabled. Even if the native selector cleared itself, BG3's
`UIAccept -> UseSlotCommand(ActionRadials.Tag)` would still be allowed
to reference the previously selected metamagic slot. The side-list
handler now requires only `IsEnabled=true` for synchronous
invalidation, clears its native tooltip if focus/content is lost,
and keeps the 70 ms *non-null* guard for setting a new `VMHotBarSlot`.
The main grid already follows this two-stage native pattern.
A submenu/tab transition still explicitly clears `ActionRadials.Tag`
before disabling one owner and enabling the other.

The resource strip's delayed `SelectionChanged` branch also wrote
`HotBarList.Tag=CAM_ResetFirstFocusToken` and only
`SelectedIndex=0`, so it had the same idempotent-selection problem as
the direct-provider return. It now requests `-1 -> 0` before allowing
the item-level deferred native focus handoff. This does **not**
verify that Larian's list supports the exact focus transition.

These are control-flow correctness improvements, not evidence that a
new `LSGrid` first-item focus route actually works in game. In
particular, no automatic test can synthesize the engine's native
`LocalFocusChanged` event semantics. Keep draft and do not publish.

## Native deactivation changes executable focus owner

A third existing control-flow omission was independently located in the
`MetamagicActive` `PropertyChangedTrigger`. If game-owned
`MetamagicActive` became `False` while CAM's spell-choice phase was
active, the handler **only** cleared
`CAM_MetamagicSpellPhaseMarker.Tag`. This re-enabled the sidebar
`LSListBox` and disabled the central `HotBarList`, without
invalidating its executable `ActionRadials.Tag` or requesting focus
inside the sidebar. That is a concrete code path capable of losing
input ownership after native metamagic deactivation, independently of
the explicit B handler.

The candidate now handles this transition analogously to the existing
B parent return: invalidate the previous executable slot, close its
tooltip and native highlight, clear old main/sidebar `LocalFocus`,
reset both selections, clear the presentation phase, then request
deferred focus to the native sidebar list. It additionally guards
the branch on being in the Metamagic provider. **No BG3-owned game
state is set, cleared or simulated.**

If `ActionCancelCommand` synchronously toggles `MetamagicActive`,
this native-property observer and the B event handler can both request
the same sidebar focus in one frame. Their ownership destination
agrees, but the exact Larian Noesis event order is not provable
outside the game and should be observed at the combined milestone.
This is not a claim that native B correctly cancels metamagic.

## Further native ownership review: remove redundant selection writer

The sidebar's `LocalFocusChanged` callback explicitly assigned
`CAM_FixedSideBarList.SelectedItem` from its *own*
`LocalFocus.DataContext`. A read-through of the complete
shipping `Lib_Controller.xaml` found **no consumer** of
`CAM_FixedSideBarList.SelectedItem` or `SelectedIndex`
outside its own source-level handoff. The selector ring is bound
to `LocalFocusSelector`, tooltip and highlights use
`LocalFocus.DataContext`, and A still uses
`UseSlotCommand(ActionRadials.Tag)`.

Therefore the synchronous `LocalFocusChanged -> SelectedItem` write
had no separate gameplay role and coupled focus change back into
selection change. The candidate removes **only** this redundant write.
The list's normal `SelectedIndex=-1 -> 0` entry behavior is kept.
This is a cleaner single-owner dataflow, not a claim of execution
success.

Independent NoesisGUI [bug #1641](https://www.noesisengine.com/bugs/view.php?id=1641)
documents an assertion caused by selecting/focusing a ListBoxItem
from an `IsSelected` style trigger during an ongoing selection
change. That report concerns an unrelated Noesis SDK version,
not Larian's `LSListBox`. It supports treating focus/selection
reentrancy as a research risk, **not** as proof the game has that
exact failure. This change introduces no new XAML-shape tests.

## Native summon-owner handoff

A separate trigger on `SummonHotBar.SlotList.Count > 0` makes
`HotBarList` show native summoned `VMHotBarSlot` values and
chooses `CAM_ActionGridSlotContainer`, but previously only
cycled `SelectedIndex=-1 -> 0` before requesting focus on the
outer `HotBarList`. Unlike other direct slot-entry paths,
it did **not** set `HotBarList.Tag=CAM_ResetFirstFocusToken`,
even though the item container's `IsSelected`-driven deferred
focus request is conditional on that exact token.
Consequently selection alone did not activate the defined
concrete-item handoff. The candidate now invalidates old list
`LocalFocus`, arms the existing token, then cycles selection.
It preserves the game-owned `SummonHotBar.SlotList`, A dispatch,
and the existing nested/upcast source overrides.

This is a source-level missing precondition repair; the native
Noesis sequencing, whether a summon override transitions
`ItemsSource` before item selection, and actual controller
focus remain **unverified**. Do not promote draft/release
based only on a successful PAK build.

## Independent Noesis focus evidence, checked 2026-10-09

NoesisGUI's [FocusManager documentation](https://www.noesisengine.com/docs/Gui.Core._FocusManager.html)
distinguishes **keyboard focus** from **logical focus** and explicitly
states that different focus scopes can retain separate logical focus.
Its [extension action guide](https://www.noesisengine.com/docs/Gui.Core.ExtensionsTutorial.html)
has *different* actions for selecting a ListBoxItem (`SelectAction`)
and requesting focus (`SetFocusAction`/`MoveFocusAction`).
Accordingly, `SelectedIndex=0` is not a documented substitute for
focus, and more than one visible list does not prove which focused
`VMHotBarSlot` BG3 will execute.

These are **general Noesis** documents, not authoritative information
about Larian's custom `ls:SetMoveFocusAction`, `LSListBox.LocalFocus`,
or the exact Noesis version used by Xbox App BG3. This candidate
requests list-level focus instead of merely selecting a child, but
**there is no independent evidence that this produces a focused first
ListBoxItem**. Therefore do not merge or release it solely because
the package compiles. The former source-shape gate suite was retired
in PR #192: no new gameplay-XAML-specific CI assertions are justified.

## Other issues not mechanically solvable from this source

The game's `ControllerHoldButtonStyle` / `ToggleWeaponSet`
declaration (captured native source, see
`docs/research/schema-v3-capture-2026-10-08.md`) intentionally has
**no explicit** `BoundEvent=UISelectionLeft`. A preceding game
attempt to add such a binding failed or intercepted ordinary controller
navigation. Copying that native declaration cannot by itself prove
weapon hold input is live in a CAM override.

`FilterActionResourceCommand` yields source VMHotBarSlot collections,
but no source proof maps a selected resource tab to a concrete
level-specific `VMUpcast` executable. `Content.IsModified` can dim
incompatible metamagic spells without excluding them. Neither is a
functional fix, and neither justifies bypassing the BG3 action command.

## Boundaries and remaining work

The exact original `PreloadedActionRadials_c.xaml` (pinned hash in
`docs/evidence/patch8-1.8.910.0-runtime-contract.json`) was captured
previously but its original bytes cannot currently be reopened for an
independent comparison. The legacy 0.0.29 generator is direct
historical code/runtime evidence, **not** proof that this adapted
`SetMoveFocusAction` transition works in the current compiled engine.

The central `HotBarList` still has a `SelectionChanged` publisher and
a separate selected-item token path. That is an independent second
candidate to simplify **after** its entry contract is grounded. Likewise,
metamagic-compatible spell filtering, active modifier rollback, direct
upcast variant identity, footer geometry, and weapon hold remain open.
Do not issue a release or request a one-off user game check until the
whole focus/dispatcher architecture and loaded-PAK identity have a
combined credible proof strategy.
