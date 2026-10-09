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
