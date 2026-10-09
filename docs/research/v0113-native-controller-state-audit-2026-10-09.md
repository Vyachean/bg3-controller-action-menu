# v0.0.113 runtime failure: original BG3 state vs CAM presentation

**Date:** 2026-10-09. **Runtime:** Xbox App BG3 Patch 8 `1.8.910.0`. **Accepted observed build:** `v0.0.113-metamagic-focus-visibility` (`6807dad0d36afc0135ff6662fedd564929d596d0`). **Source evidence:** installed-game XAML originally captured in `bg3-controller-action-menu-inputs-20261008-132651.zip`, pinned by SHA in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`. The original *compiled ViewModel implementations are not included in that XAML capture*.

This document separates (A) first-hand operator observations, (B) provable XAML wiring, and (C) unknown engine/Noesis semantics. **No source-only prediction is a pass of a controller-in-game test.** See P0 #176.

## Confirmed positive behavior to preserve

- Duplicate LB opening sound was eliminated by removing the extra `LSPlaySound`; the user confirmed the double sound is gone in v0.0.112. This does **not** prove LB's vibration and overall feedback match RB.
- Selecting a metamagic modifier now transfers controller navigation to the spell-grid region; this does **not** prove only compatible spells are executable/focusable.
- The ordinary BG3 resource-cost preview follows a focused action (confirmed in v0.0.111). Don't remove `HighlightResourcesCommand` to address other defects.

## Fault graph — seven rejected or unproven contracts

| ID | Operator observation | Concrete CAM source / game evidence | Precise proof gap | Must be demonstrated before claiming fixed |
|---|---|---|---|---|
| 1 | LB opening still differs from RB | Native state machine uses `OpenActionRadials` vs `OpenActionRadialsEnd` (`Metadata=MoveToEnd`); CAM selects different first/last provider. The previous LB-only hover sound doubled playback and was reverted. | Native feedback and rumble owner on each opening path is **not** captured by a standalone LSPlaySound. | Both entry directions keep intended first/last selection, but identical normal sound/vibration feedback and no double sound. |
| 2 | Pressing Down after last metamagic cell loses native ring/selection | `CAM_FixedSideBarPanel` is custom one-column `LSGrid` with `ActionDownEvent=UIDown`; `CAM_FixedSideBarList` also consumes `ActionNextEvent=UIDown`; `KeyboardNavigation.DirectionalNavigation=Cycle`. v0.0.113's 70ms guard repairs only `LocalFocus.DataContext == null`. | The custom LSGrid may leave its last cell into another *non-null* focus owner; neither Cycle nor a null-only timer bounds native focus. | Real first/last item boundary on both Up and Down; native frame, tooltip and A reference the same actual VMHotBarSlot, without intercepting global D-pad. |
| 3 | After enabling metamagic, visible list still has incompatible choices | Main HotBarList defaults to `SingleHotBar.SlotList`, constructed via `FilterActionResourceCommand` (resource selector). `Content.IsModified` and `MetamagicActive` only change glow/opacity/disabled overlay in the cell DataTemplate. | No source-proven compatible **executable VMHotBarSlot ItemsSource / predicate**. `Content.IsModified` might denote compatibility but mere hiding/greying leaves noncompatible *navigable* slots and can change cell layout. | The real selection/focus scope comprises only actions that BG3 will accept under active metamagic, including mod-added spells and dynamic circumstances; cost, tooltip and A stay game-owned. |
| 4 | B from spell choice does not restore focus to metamagic choices | `CancelButton` uses `UICancel`. CAM's spell-phase template setter changes `Command` and `CommandParameter` to `{x:Null}` and tries to restore a selector from `LSButtonReleased`. Vanilla invokes `ActionCancelCommand` on release and has `ClearSingleHotbarCommand`/top-level `CustomEvent(CloseWidget)` branches. | Whether the commandless LSButton fires the release event is **not proven**; `SelectedIndex=0` and focus on the list are not proof of a focused actual item or native cancel. | Exactly one native back transition: cancel modifier choice and restore a real metamagic item with frame, tooltip and dispatch. Nested/upcast B keeps vanilla semantics. |
| 5 | Closing menu before choosing spell keeps metamagic active | `MetamagicActive` is BG3-owned. CAM clears only its own `CAM_MetamagicSpellPhaseMarker` on provider changes; `CustomEvent(CloseWidget)` is the main-level exit path, without a verified native metamagic cancellation/cleanup path in that exit. | XAML cannot prove `CloseWidget` clears the current spell task/modifier; the user explicitly observes it doesn't. Calling a presentation reset or changing glow is **not** a gameplay cancellation. | B returns/cancels according to native semantics, and *any* menu close with no chosen spell leaves no stale game-owned modifier or altered subsequent action. No artificial `MetamagicActive=False` property writes. |
| 6 | On resource tab IV, choosing a spell prompts for IV again | `ActionResourcesCostPreview.SelectedItem -> FilterActionResourceCommand -> SingleHotBar.SlotList`. `UseSlotCommand` takes `ActionRadials.Tag` (whole VMHotBarSlot), **no confirmed level variant parameter**. `IsSelectingUpcastedSpell` remains a separate native nested state. | Filtered resource/cost eligibility does not prove that the chosen executable VMHotBarSlot already carries IV as its effective level. Compiled `FilterActionResourceCommand` and `VMUpcast` selection are absent from capture. | Selecting IV and a valid spell consumes **exactly IV**, produces correct upcast tooltip/effect, and does not repeat an identical choice; no wrong-slot or wrong-level cast. Until proven, preserve safe native second picker. |
| 7 | Hint row does not match original radial horizontally | Pinned native `ButtonHintsContainer`: Right/Right/RTL + `Width=1000`, margin `26,0,26,56`. Separate native narrow variant changes layout and hint child widths to Auto with Center/Center/LTR. CAM currently mixes Right/Right/RTL with `Width=Auto`, `MaxWidth=600` and Auto-width children. | A hybrid of two native layouts is **not** evidence of faithful alignment. Simple width cap changes caused center-HUD overlap, clipped hints and now offset hints in earlier builds. | Compare complete native container **and children** positioning at actual supported UI scale, preserving original HUD resource bar, all control glyphs, hold animation and native horizontal alignment. |

## Architectural correction: one game-owned transition per player intent

Represent the *desired behavior* as controller-visible transitions, with original BG3 input/command/state owning execution:

```text
Open via LB/RB
  -> native entry feedback + intended initial provider
  -> Metamagic native VMHotBarSlot focused (ring / tooltip / A agree)
  -> A selects modifier through original UseSlotCommand
  -> BG3-owned compatible executable spell-choice scope
       - D-pad stays within concrete eligible VMHotBarSlot objects
       - A selects executable native spell/upcast variant
       - B invokes native cancel/back, restores metamagic real-slot focus
       - CloseWidget invokes native cancel/rollback when modifier not consumed
  -> other resource tab IV
       - tab selects *cost* and true executable IV variant, or shows the native picker explicitly
       - never silently force a cast level
```

A CAM phase token is permitted only as presentation state **derived from native state**; it cannot substitute for (1) the game-owned modifier/cancel transaction, (2) a compatible executable collection, or (3) an upcast variant identity. The current model confuses those three. Adding timers, copying `SelectedItem`, hiding incompatible icons, or cancelling via `Command={x:Null}` alone is insufficient.

## Minimum source/proof plan — no premature release

1. Build a **read-only provider/command inventory** for the original `PreloadedActionRadials_c.xaml`, `ActionRadials.xaml`, `HotBar.xaml`, `Controller.xaml`, and the current CAM XAML, matched by installed-pak SHA and exact states. The 2026-10-08 capture already pins 45 native XAML files; do not claim it includes compiled VM logic. Reuse this data rather than asking the operator to run the game repeatedly.
2. Verify any native ability to materialize a **compatible and level-specific executable VMHotBarSlot** from the existing ViewModel. If the only native surface is visual `Content.IsModified`, report the limitation and do not fake a complete filter under the current no-SE/no-DLL contract.
3. Verify native `ActionCancelCommand`, `ClearSingleHotbarCommand`, and controller state-machine exit sequencing before revising B/close. The observed stale `MetamagicActive` must be fixed via a native semantic cancel, **not** local glow/phase clearing.
4. Prove true LSGrid terminal navigation and one unified focus owner. Capture an exact deterministic test fixture of terminal Down, B-back and one real action dispatch; a parse/static assertion that a timer or `Cycle` exists is **not** the test.
5. Match the full original radial footer layout, not a mix of attributes across separate native variants; check fallback/adaptive widths and the default HUD overlap boundary.
6. Only after source/architecture review: produce **one consolidated experimental version**, green CI **and** signed-off remaining source limitations, successful published non-draft Release and latest-VBS resolver. Ask for **one** combined game test. Do not bump VERSION or merge speculative edits just to repeat one operator test.

## Acceptance status and evidence rule

Every row is **open / runtime-rejected / source-unproven**. The fact that CI Validated/Build package/Release were green in 0.0.111–0.0.113 is **mechanical delivery proof**, not semantic controller-input proof. When a row is fixed, attach the relevant source lines, deterministic test results, and the one operator gameplay observation before marking it accepted. Maintain #154, #155, #158, #160, #165, #167, #172 and parent #176 as appropriate.
