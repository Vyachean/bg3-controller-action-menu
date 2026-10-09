# 0.0.114 controller hints — separate game-owned layout from placement

**Game target:** Xbox App BG3 1.8.910.0. **Operator observation:**
in the published `0.0.114-native-state-probe`, controller button
hints are *still horizontally aligned incorrectly* compared with the
original unmodded controller ActionRadials. Weapon-set switching remains
broken; no new gameplay diagnostics were provided.

## Native source facts versus CAM hybrid

The pinned installed-game XAML contract
(`docs/evidence/patch8-1.8.910.0-runtime-contract.json`)
records the **default** `ButtonHintsContainer`:

- `Style=ButtonHint.Container.CenterWrap`
- `HorizontalAlignment=Right`, `HorizontalContentAlignment=Right`
- `FlowDirection=RightToLeft`, `Width=1000`
- `Margin=26,0,26,56`.

The separate narrow layout from the **same** installed
`PreloadedActionRadials_c.xaml:2151-2167` uses compact controls with
`Width=Auto` and container center/center/LeftToRight. These are
**alternative native variants**. They are not evidence that a single
right/right/RightToLeft container containing 600px-wide compact hints
is the game's intended result. Previous 380px/600px width guesses
and direct centered layout failed operator tests or overlapped the
game's center-bottom resource HUD.

## Candidate composition — not gameplay proof

The menu requires two distinct constraints, which cannot be applied
as one inherited alignment:

1. **Placement:** outer `CAM_ControllerHintRightLane` is attached to
   bottom-right, `MaxWidth=600` and original margin. This keeps the
   entire group out of the HUD's central region without making every
   hint 1000px wide.
2. **Contents:** direct child `ButtonHintsContainer` preserves the
   game's narrow variant center/center/LeftToRight with `Width=Auto`,
   zero inside margin, unmodified `ButtonHint.Container.CenterWrap`
   style and the original native hint controls.

No changes to `BoundEvent`, `UICancel`, `UIAccept`,
`UISelectionLeft`, `ControllerHoldButtonStyle`,
`SwitchWeaponSetCommand`, `UseSlotCommand`, or radial dispatch.
The existing original BG3 resource HUD is not moved.

`tools/audit-native-ui-commands.py` enforces both source layers,
their correct ownership, that hints stay compact and the editor
stub remains hidden. Negative mutations must reject central outer
placement, overlarge outer bounds, RTL reversal of the compact
buttons and widened weapon hint.

This is **only a source/CI candidate**. It is not accepted until an
actual Noesis/BG3 screenshot shows correct button sequence and
horizontal alignment at 1080p and no overlap with HUD resources.
Exact `MaxWidth=600` is a constrained candidate, **not a proven
responsive safe-area metric**. The plugin must not create another
release exclusively to test width or input speculation.

## Independent evidence still missing

- **Weapon set:** `SwitchWeaponSetCommand` and vanilla hold style
  are preserved, but earlier attempts to attach
  `BoundEvent=UISelectionLeft` or `ToggleWeaponSet` grabbed short
  directional input or didn't rearm. Original off-menu hold worked in
  an earlier game run, while on-menu shortcut remains broken. The
  footer geometry might restore visibility of the hold hint, but
  cannot establish functioning input transport.
- **Metamagic:** no verified executable compatible-only provider or
  game-owned cancellation hook. `Content.IsModified` indicates
  native visual modification, not a proven new action collection.
- **Upcast IV:** `FilterActionResourceCommand` cannot by itself
  guarantee the specified `VMUpcast` selected by BG3; retain the
  native level selector until its execution contract is captured.

**Next:** one consolidated runtime milestone after several
source-backed fixes, not serial one-change game tests.
