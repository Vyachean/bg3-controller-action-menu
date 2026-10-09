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

## v0.0.115 two-layer composition — runtime rejected

The previous source candidate combined two **different** native layouts:

1. custom outer `CAM_ControllerHintRightLane`:
   bottom-right, `MaxWidth=600`, original margin;
2. inner `ButtonHintsContainer` copied from the game's separate compact
   center/center/LeftToRight, `Width=Auto` variant.

The operator's v0.0.115 run reported no meaningful improvement and the
horizontal placement still did not match the original radial. Treat this
composition as **historical rejected evidence**, not the current architecture
contract. In particular, neither `MaxWidth=600` nor the outer wrapper is
source-proven game behavior.

Static validation now intentionally ignores footer geometry. It protects only:

- exactly one semantic `ButtonHintsContainer`;
- required native A/B/concentration/weapon/dual-wield/throw controls;
- the hidden radial editor;
- established command/input ownership invariants.

The exact installed game still proves two whole native variants: default
right/right/RightToLeft with 1000px sizing, and a separate
center/center/LeftToRight auto-width variant. The old capture summary did not
retain the **trigger condition** that selects the compact variant, so a new
hybrid cannot be derived safely from those summaries.

Schema-v5 read-only capture now records the original trigger-owned
`Setter` mutations for `ButtonHintsContainer` and its controller hints,
together with the full `ControllerHoldButtonStyle` definition. A future
single capture can therefore recover both the native wide↔compact condition
and the hold/re-arm presentation lifecycle without another gameplay
micro-release.

No changes to `BoundEvent`, `UICancel`, `UIAccept`,
`UISelectionLeft`, `SwitchWeaponSetCommand`, `UseSlotCommand` or radial
dispatch are justified by the rejected layout.

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
