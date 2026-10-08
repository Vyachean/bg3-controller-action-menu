# Native BG3 controller/keyboard functionality audit — 2026-10-08

## Evidence and claim boundaries

- Installed Xbox App BG3 package: **1.8.910.0**.
- Read-only original capture: `bg3-controller-action-menu-inputs-20261008-132651.zip`, including 45 actual XAML files and `hotbar-coverage-contract.json`.
- Source comparison: `Mods/MainUI/GUI/Pages/HotBar.xaml` versus `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`, pinned hashes in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`.
- CAM source: `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.
- Machine-readable command inventory: `docs/evidence/native-ui-command-audit-1.8.910.0.json`.
- Runnable source auditor: `python tools/audit-native-ui-commands.py --capture path/to/bg3-controller-action-menu-inputs-20261008-132651.zip --json` (capture optional; default CI uses the pinned manifest).

**Important:** UI command parity and action-catalog parity are different. Recognizing a command binding in XAML proves a native source seam, not that an instance of a class, item, spell, recast or mod-added action appears at runtime, is reachable by a particular character, or executes successfully.

## Findings

The capture contains **36 distinct native command names** across the keyboard HotBar and controller radial. The audit classifies each exactly once; CI fails if a known covered command or any core provider disappears, or if the classification set becomes internally incomplete. Classes are:

| Classification | Count | Relevant findings |
| --- | ---: | --- |
| Present in CAM as a native command | 11 | `UseSlotCommand`, `ClearSingleHotbarCommand`, `ReleaseConcentrationCommand`, `ToggleDualWieldingCommand`, filter/deck/tooltip commands |
| Present but intentionally restricted | 1 | `HighlightResourcesCommand`: action focus does not emulate permanent mouse-hover resource highlighting, preventing incorrect resource preview |
| Missing as direct CAM gameplay/utility UI transport | 8 | `SwitchWeaponSetCommand`, `SwapLightSourceCommand`, `UseMeleeWeaponCommand`, `UseRangedWeaponCommand`, `LaunchDefaultActionCommand`, `CancelTaskCommand`, `TargetGameobjectCommand`, `SetCursorCommand` |
| Native radial editing / layout / debug not shipped | 16 | `AddRadialCommand`, `AssignSlotCommand`, `SwapSlotCommand`, `ClearSlotCommand`, `RequestAssignSlotCommand`, `RemoveRadialCommand`, `ShowContextMenuCommand`, rows/columns and debug setters |

The eight UI commands not in CAM are **real missing direct UI integrations**, but this does *not* prove that their gameplay effects cannot be invoked via the game's global shortcuts or a BG3-owned `VMHotBarSlot`. Conversely, the keyboard `KeyboardHotBars[*].SlotList` fallback only proves coverage of **slots that the keyboard HotBar collection exposes**. It is not an independent proof that all raw `SpellsAndActions`, `Inventory.Slots`, passive predicates, temporary/recast or mod-provided radial candidates are executable from CAM.

`SwitchWeaponSetCommand` is a known previous failure: a hand-written controller hold shortcut was tested unsuccessfully and removed from CAM intentionally. Restore only when a real native ActionRadials transport is demonstrated; do not confuse a missing convenience command with missing attack/weapon actions.

## Source-route regression guard

The auditor requires all of these real BG3-owned routes to remain present:

| Provider | CAM transport | Static status | Runtime equality with native reference |
| --- | --- | --- | --- |
| Costed actions/spell levels/class resources | `FilterActionResourceCommand -> SingleHotBar.SlotList` | present | unproven |
| Cantrips | `FilterCantripsCommand -> SingleHotBar.SlotList` | present | unproven |
| Items and scrolls | `SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList` | present | **unproven against** radial `Inventory.Slots` |
| Metamagic | `FixedSideBar.SlotList -> VMHotBarSlot` | present | gameplay and tooltip/A entry unproven |
| Passives | `PassivesHotBar.SlotList` | present | parity against radial predicate unproven |
| Keyboard All fallback | `KeyboardHotBars[*].SlotList` grouped | present | source slots only; not all radial actions |
| Containers/upcasts/throw | `SingleHotBar.SlotList` with native nested flags | present | generic route proven; each variant not exhaustively tested |
| Execution | `UIAccept -> UseSlotCommand(ActionRadials.Tag)` | present | requires native focused `VMHotBarSlot` at runtime |

A new native game update must be audited using `--capture`; the source hashes and command inventory then fail closed on drift rather than silently treating a new XAML as the old contract.

## What automatic checks cannot establish

Neither the shipping self-contained XAML nor read-only **game asset capture** can enumerate every runtime `VMHotBarSlot` for every build/class/status/inventory/mod combination. The static source auditor is specifically designed **not to claim** such coverage.

The outstanding **functional parity** gate remains: derive two live sets for representative character states, (a) BG3's keyboard executable slots plus the radial's gameplay candidate catalog and (b) CAM-reachable `VMHotBarSlot` identities, excluding radial editing controls; compare IDs and activation viability. A native, read-only runtime probe would be required to do this automatically. Such a probe must be isolated to development and cannot introduce a Script Extender or native loader requirement into the shipping Xbox App PAK. Until such evidence exists, treat free/temporary/recast/charges/modded radial-only actions as unresolved, not implemented merely because a provider name matches.

## Visual selector defect (issue #130)

The exact current installed `Public/Game/GUI/Library/DataTemplates.xaml`, line 2794, defines native `SelectorTemplate` as `LSNineSliceImage Margin="-12" Slices="16"`; its inner border uses `Margin="12"` (lines 2794–2795). CAM uses 104px square items in 120px grid cells, leaving **8px per side**. Therefore native paint may reach at least 4px to the left of the first column's origin. With `CAM_ActionRowClip` on the outer two-column row, a zero-inset sidebar still clips the selector at x=0.

The source-backed correction sets `CAM_FixedSideBarRegion.Margin="12,16,0,16"` (rather than `0,16,0,16`), shifting **both LSListBox and sibling native selector together** inside the unchanged row-level clip. This reserves the entire source-defined paint margin at the left boundary while retaining 16px vertical clearance; central adaptive-grid width may decrease by 12px, which must be considered at narrow viewport sizes. The native `SelectorTemplate`, `LSGrid`, 120px scroll margin and all commands remain unchanged. This is geometry proof, not in-game visual acceptance.
