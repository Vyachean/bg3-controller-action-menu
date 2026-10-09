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

This draft originally included `tools/test-native-sidebar-focus.py`
and had its structural assertions invoked through `tools/validate.py`.
Those exact-markup tests were retired with the operator-approved
cleanup in merged PR #192. They were **not carried forward** into this
minimal draft PR. The current fast validation checks only package
inputs/XML/metadata/forbidden payloads; Windows CI separately builds
the actual Divine .pak and round-trips it through extraction, plus
installer checks. Neither stage exercises Larian's controller focus,
metamagic gameplay or Noesis runtime. A green build is not acceptance.

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

## Native summon disappearance and active-owner restoration

Follow-up source review exposed the reverse half of the
`SummonHotBar.SlotList.Count > 0` transition. When the native
summon collection becomes empty, an unconditional handler invalidated
`ActionRadials.Tag`, changed `HotBarList.SelectedIndex=-1 -> 0`,
but **did not invalidate old `LocalFocus` or arm**
`CAM_ResetFirstFocusToken`. The next guarded handler merely
requested outer list focus. The item template would not request focus
of its first `VMHotBarSlot` without that token.

The candidate now separates concerns: the shared change first clears
the old dispatch slot, tooltip and `HotBarList.LocalFocus`; the
conditional branch for an enabled `HotBarList` arms its existing
first-slot token, cycles the selected index and requests deferred
list focus. If instead the enabled owner is the metamagic sidebar,
its existing index reset/list focus route is preserved.

A second independent defect was in the fallback guard:
`CAM_ProviderModeMarker != CAM_MetamagicModeToken` excluded an
**enabled HotBarList while metamagic spell-choice or native nested
state is active**. Metamagic is the provider mode, not necessarily
the input owner; source `HotBarList.IsEnabled` is the existing
focus-ownership signal. That guard was removed, allowing the main
list to restore focus whenever it is enabled, including a nested
metamagic spell grid. This has no effect on the native
`SummonHotBar.SlotList` materialization itself.

**Important:** These are explicit missing guard/token facts in
shipped source; actual Noesis scheduling, especially initial
`Count=False` activation and animated list reuse, remains unproved.
No new source-shape gameplay tests were added, and no release was
created.

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

## Resource-IV keyboard HotBar behavior — new operator evidence (#172)

**Observed behavior, supplied by the operator on 2026-10-09:** in the
unmodified keyboard/mouse HotBar, selecting the level-IV resource
filter and then a spell selects the **level-IV upcasted variant**;
its normal tooltip also describes the level-IV result. Thus a
resource-first, level-specific action and matching preview is an
existing BG3 gameplay/UI capability. Previous wording that implied
the **game** had no such mechanism was too broad. The actual unknown
is whether the **controller ActionRadials UI currently reaches the
same native executable VMHotBarSlot**.

Prior exact installed 1.8.910.0 capture-derived evidence
[`source-only-capability-parity-2026-10-08.md`](source-only-capability-parity-2026-10-08.md)
records that keyboard HotBar and controller ActionRadials use the
game's `DCHotBar` context, and both expose
`FilterActionResourceCommand`, `SingleHotBar.SlotList` and
`UseSlotCommand`. The exact original HotBar.xaml SHA-256 is
`9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.
The source archive is not committed, so this turn did **not** reopen
that exact blob or inspect compiled `DCHotBar` implementation.

Additional independent, but **NOT byte-identical to installed game**
Patch 8 source:
[DataTemplates.xaml, Coyote-31 archive](https://github.com/Coyote-31/bg3-advanced-character-sheet/blob/71fe9015ac3b848fa11fbba53c6286872f140e3e/Sources/BG3/Patch8/Game/Public/Game/GUI/Library/DataTemplates.xaml)
defines `HotBarSlotStyle` with
`Command = DataContext.UseSlotCommand` and
`CommandParameter = {Binding}`; this binds **the current VM slot**,
not a spell name or a resource number. Its `VMUpcast` template
uses the native level-specific visual and its tooltip is
`DataContext.Content`. An older published
[keyboard HotBar.xaml derivative](https://gist.github.com/rkr87/d73c7129567846c0ed72524138585be3)
shows `FilterActionResourceCommand` taking the entire
`VMActionResourceCostPreview` item, and a separate
`CurrentActiveSlot.Spell.SpellUpcast` choice region. These are
architecture clues, not independent proof of Patch 8 casting
semantics.

Current CAM XAML:
- LB/RB selects a real `VMActionResourceCostPreview` and invokes
  `FilterActionResourceCommand(SelectedItem)`.
- Normal resource-mode `HotBarList.ItemsSource` is
  `SingleHotBar.SlotList` (real `VMHotBarSlot` objects).
- Controller A invokes
  `UseSlotCommand(ActionRadials.Tag)`, where `Tag` is published
  after `HotBarList.LocalFocusChanged` (native-like 70 ms delay).
- Tooltip uses `LocalFocus.DataContext.Content` with the native
  tooltip command. If `Tag` and `LocalFocus.DataContext` refer
  to different/old slots, the controller UI can disagree with
  the keyboard UI even though both command names are the same.

**New diagnosis priority:** compare the specific instance
`HotBarList.LocalFocus.DataContext`, `ActionRadials.Tag`,
`SingleHotBar.SlotList` item content (base `VMCharacterAction`
vs native `VMUpcast`), and rendered tooltip with the equivalent
keyboard resource-IV slot *before* adding any new upcast UI.
Also check that the controller widget is actually using the same
DCHotBar instance, not merely the same command type. This is a
hypothesis about a transport/context mismatch, **not a proven
root cause**.

**Acceptance for #172:** the resource-IV tab shows the very same
IV-level variant in both tooltip and execution as keyboard HotBar;
A must not force the player to select IV a second time, and
native `UseSlotCommand` must continue to apply all gameplay cost,
targeting, metamagic and modified spell rules. Do not force IV,
inject a synthetic `VMUpcast`, bypass native commands or suppress
the game's legitimate secondary selector by hiding its markup.
A coherent console/gamepad owner must be proven before release.

## First runtime-bound change following keyboard IV evidence

The user's keyboard HotBar observation narrows #172 to the **identity
of the engine-created IV variant** in the controller source and A
dispatch. A direct no-guesswork parity correction is possible for
tooltip/dispatch synchronization, but **not** for construction of
the chosen IV-level VM slot without the game's model implementation.

Previously in both CAM slot lists the synchronous
`LocalFocusChanged` handler immediately set
`CAM_ActionTooltip.Content` or `CAM_FixedSideBarTooltip.Content`
to `LocalFocus.DataContext.Content` and showed it, then invalidated
`ActionRadials.Tag`. Actual A used the later `Tag` updated
on a 70ms `LocalFocusChanged` timer. This could display a **new**
spell's level/damage/resource preview while A's committed parameter
was **null**, and offered no invariant tying a visible tooltip to
a committed native `VMHotBarSlot`.

The candidate now clears/hides the slot tooltip immediately during
the native focus invalidation. Only inside the same delayed
`LocalFocusChanged` timer, and under the **same non-null current
native focus and IsEnabled owner guards** as
`ActionRadials.Tag = LocalFocus.DataContext`, it writes tooltip
Content from that object's Content and calls the existing BG3
`ShowTooltipOnUIElementCommand`. This keeps the standard
70ms native focus transaction, tooltips and resource highlighting,
without an independent selection publisher or extra input binding.
It applies equally to main resource grids and metamagic sidebar.

**Scope:** this removes a concrete timing/identity inconsistency.
It does *not* establish whether `SingleHotBar.SlotList` already
contains an executable `VMUpcast` for the chosen IV resource, nor
does it prevent the game's nested upcast level picker. The
correct native IV spell execution, metadata, cost and effects remain
#172's unresolved engine parity requirement. A blank tooltip for
70ms or failure to show on missing native `LocalFocusChanged`
is a known behavioral trade-off, not accepted UX. This should be
assessed only in the consolidated game milestone, not asserted
from the PAK CI result.

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

The central `HotBarList` formerly had an additional
`SelectionChanged` dispatcher. It was removed in this same draft,
so both active slot lists now publish non-null `ActionRadials.Tag`
only on the captured-native-like delayed `LocalFocusChanged` path.
The `IsSelected`-triggered token route remains a **focus request**,
not independently verified focus. Metamagic-compatible spell filtering,
game-owned modifier rollback, direct upcast-variant identity, footer
geometry, and weapon hold remain open.
Do not issue a release or request a one-off user game check until the
whole focus/dispatcher architecture and loaded-PAK identity have a
combined credible proof strategy.
