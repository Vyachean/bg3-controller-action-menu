# BG3 native metamagic cancellation and selected-level upcast: execution proof boundary

Date: 2026-10-09. Runtime: Xbox App PC BG3 1.8.910.0.
This decision follows the operator's **published v0.0.114** run and the
source inspection of the current `Lib_Controller.xaml`. The resulting
source audit change is **test-only**: it does not pretend to repair
gameplay without proving compiled BG3 ViewModel behavior.

## Actual operator results

- Modifier selection opens the central grid on an unmodified ordinary
  action ("Throw"), not a compatible-spells-only executable provider.
- B backs out of CAM's spell-choice phase but there was no focused item
  (later addressed source-only in PR #182). Closing and reopening shows
  metamagic still active in BG3.
- Choosing a spell under resource IV still opens BG3's level selector.
- Hints and weapon input have independent unresolved runtime failures.

## What the current installed UI source *does* prove

1. `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.MetamagicActive`
   is a **game-owned state**; `CAM_MetamagicSpellPhaseMarker` is an
   invented **presentation-only** phase token.
2. `FixedSideBar.SlotList` yields native metamagic `VMHotBarSlot`
   entries; `UseSlotCommand(ActionRadials.Tag)` executes the selected
   native slot. Selecting one causes BG3's `MetamagicActive` to change.
3. The central `SingleHotBar.SlotList` results from
   `FilterActionResourceCommand(SelectedItem)`: this command's
   **input is the cost resource**, not an identified
   metamagic-compatibility predicate. The game's original
   `Content.IsModified` lights modified spells and dims unmodified
   slots but is not a source-proven enumerable of *executable-only*
   spells. It cannot be used as a fabricated engine filter without
   risking unreachable mod-added spells/ghost focus.
4. The native B controller has `UICancel`,
   `ClearSingleHotbarCommand`, `ActionCancelCommand` on original
   ordinary/nested branches and `CustomEvent(CloseWidget)` for
   top-level. CAM's metamagic spell-choice parent previously
   **overrides the default command with null** and only changes
   CAM presentation. This is consistent with the observed lingering
   modifier. It does NOT prove that simply adding
   `ActionCancelCommand` in that branch will roll back BG3 state.
5. `FilterActionResourceCommand` only selects a resource-list view.
   The subsequent selected `VMHotBarSlot` sent to
   `UseSlotCommand` has no captured level-specific
   `VMUpcast` construction; `IsSelectingUpcastedSpell` confirms BG3
   owns a further nested choice. Discarding it in XAML would risk
   spending the wrong spell slot.
6. The original XAML exposes bindings and command **names**. It does
   not contain C++ ViewModel implementations, native command
   effects, compatible-spell collection generation, or selected
   `VMUpcast` executable identity. Neither official public BG3 UI
   modding documentation nor source-tree checks have supplied those
   compiled semantics. This is a *limit of current evidence*, not a
   claim that no possible native mechanism exists.

## Architectural decision

- Keep the no-Script-Extender/no-DLL self-contained shipping contract.
- **Do not** synthesize spell-cost classes, `VMHotBarSlot`, compatibility
  lists, or metamagic rollback with user-facing XAML tokens.
- **Do not** hide the second upcast picker until a true level-IV native
  executable slot identity, cost and tooltip match are proven.
- Do not force gameplay behavior because a source-only test passes.
- A future native `ActionCancelCommand` candidate at the meta-parent
  level is allowed to pass **source shape** checks, but remains
  `runtimeAccepted=False`, and must be shown to cancel game-owned
  `MetamagicActive` in the *single consolidated* game milestone.
- Preserve nested ordinary `ActionCancelCommand` branches, native
  `UICancel`, `ClearSingleHotbarCommand`, focusable slot-item
  restoration, and separate `CloseWidget` behavior.
- Never ask the operator to repeat micro-tests after each source
  correction. Consolidate game validation and distinguish source
  acceptance from executable gameplay semantics.

## CI correction (#176 / #158)

The old `--assert-cancel-source` and package contract embedded an
accidental **prohibition** on including the native
`ActionCancelCommand` in metamagic parent B. That codified the
user-rejected local-only B behavior and made a future legitimate fix
fail mechanical CI. The new audit:

- requires the **four pre-existing** ordinary/variant/upcast/throw
  native `ActionCancelCommand` routes;
- requires one metamagic-parent B branch and concrete sidebar slot
  focus handoff;
- forbids deleting global native `UICancel`/
  `ClearSingleHotbarCommand`, top-level `CloseWidget` or rerouting
  focus to the non-focusable sidebar root;
- permits a *hypothetical* fifth native `ActionCancelCommand` in the
  guarded metamagic-parent B branch, with a positive source fixture;
- explicitly records whether that new source call is present and
  **always leaves native rollback = UNPROVEN**, until independent
  gameplay evidence exists.

Thus CI protects *safe structure*, not a wrong behavioral conclusion.
This PR introduces **no shipping XAML modifications** and **no new
release**. The latest published version remains the immutable
`v0.0.114-native-state-probe`. Main after #182/#183 contains
source-only UI/focus candidates that are also not game-accepted.

## Next substantive proof needed

Find an **existing** installed Patch 8 game-provided native command
that rolls back the active metamagic transaction; a true
metamagic-compatible executable-slot provider; and a level-specific
`VMUpcast` source from the **same current** client runtime. Confirm
their parameters and lifecycle, not just command names. Without
that evidence, #158 and #172 must remain explicitly blocked under
the no-DLL/no-SE runtime constraint. Avoid another UI-only
diagnostic prerelease that cannot observe compiled command effects.
