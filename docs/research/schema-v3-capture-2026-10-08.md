# 2026-10-08 — schema-v3 native capture readback

## Input and integrity

Operator archive: `bg3-controller-action-menu-inputs-20261008-093541.zip`.
Xbox App package: `1.8.910.0`. Game source: `Game.pak`.
The archive includes 22 captured XAML files, zero scan errors, and
`hotbar-coverage-contract.json` schema 3. Every one of those 22 XAML files
has identical SHA-256 content to the prior
`bg3-controller-action-menu-inputs-20261007-223832.zip`; this is new
*analysis* over unchanged installed-game UI, not a game patch.

Pinned `HotBar.xaml` hash:
`9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.

## Weapon-set transport evidence

`InputTransportProbes` has the following **match counts across all 22
targeted files**, including repeated files under Clairmont override:

| Symbol | Count | Readback |
| --- | ---: | --- |
| `SwitchWeaponSetCommand` | 4 | Native HotBar setters plus native ActionRadials button (including override) |
| `ToggleWeaponSet` | 27 | Mostly trigger/style references; not 27 working input bindings |
| `UISelectionLeft` | 2 | Controller ActionRadials hint on `ToggleWeaponSet` |
| `ControllerHoldButtonStyle` | 6 | Native hold-style button references |
| `WeaponSetSwitchStyle` | 3 | Keyboard HotBar radio-button style |
| `LSInputBinding` | 49 | Other native input binding sites |
| `HoldTimeShortcuts` | 0 | Absent in these *selected Game.pak XAML inputs*, not proof of global absence |

Native controller radial has `ls:LSButton x:Name="ToggleWeaponSet"` with
`Style="{StaticResource ControllerHoldButtonStyle}"`,
`Command="{Binding SwitchWeaponSetCommand}"`, and a **display hint**
`ConverterParameter='UISelectionLeft'`. This declaration does not contain
`BoundEvent="UISelectionLeft"`. It also uses `ToggleWeaponSet.IsPressed`
for change-notification conditions; these are not executable command
transports. Native keyboard HotBar instead defines
`WeaponSetSwitchStyle` with `BoundEvent="ToggleWeaponSet"`, and binds the
weapon-set command to the inactive melee/ranged radio control.

No captured evidence proves that transplanting either the native controller
button or the keyboard radio-button event yields a repeatable
`ActionRadials` shortcut with ordinary left-grid navigation intact.
Versions 0.0.51–0.0.54 already rejected four attempted CAM transports at
runtime. **No weapon-set shortcut is restored.**

## What this source set cannot prove

`ExecutableCollections` reports literal substring presence, **not**
runtime collection availability or dispatch identity. In particular,
`CurrentShownDeck.SlotList` and `PassivesHotBar.SlotList` are false in
the report; that alone cannot overturn separately captured
`VMHotBar -> SlotList` templates or current provider evidence.

The capture contains XAML and static command bindings, not a snapshot of
the running `VMHotBarSlot` catalogs for a selected character. It therefore
cannot establish the full `keyboard HotBar ∪ radial assignment ⊆ CAM`
parity invariant for temporary/recast, scroll/item-charge or mod-added
actions. Nor does it prove that resource-tab focus, scrolling and grouped
All navigation now work in-game.

## Decision

Static UI inspection of this installed version has reached its useful
limit. Retain all unsupported parity claims as runtime-unverified,
return the universal development VBS to its normal **install** task for
the next single combined game milestone, and keep the weapon-set shortcut
disabled. Do not ask for another read-only capture of unchanged 1.8.910.0
XAML or create another speculative weapon input mapping.

In the combined game milestone verify resource and special tab cycling,
first-cell focus/tooltip/A identity, action-grid focus-follow scrolling,
native upcast/variant/container B return, item counts, and a representative
range of free, cantrip, spell, resource, consumable/scroll, temporary,
recast and metamagic cases. Weapon switching remains a known unsupported
controller shortcut; do not make it an input regression during this test.
