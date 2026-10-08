# BG3 vs CAM: static gameplay-capability parity audit (2026-10-08)

## Scope and explicit proof boundary

Operator requirement: compare **the original game code/assets with CAM** to establish that no original gameplay capability is omitted **without starting BG3**. This is an inspection of sources, native UI bindings and control flow, not an operator gameplay test. The conclusion must never conflate an executable action with a visible icon or a shared command name.

Checked against repository `main` at `9910cf1f843ef9974b859ed40b4c2f31cb6cd50f` (Xbox App native package 1.8.910.0 pinned evidence).

- CAM implementation: `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.
- Original installed-game XAML **as recorded by prior read-only capture**: `Mods/MainUI/GUI/Pages/HotBar.xaml`, `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`, `Mods/MainUI/GUI/Pages/ActionRadials.xaml`, `Mods/MainUI/GUI/StateMachines/Controller.xaml`, `Public/Game/GUI/Library/DataTemplates.xaml`.
- Existing exact source SHA-256 inventory and source-backed binding contracts: `docs/evidence/patch8-1.8.910.0-runtime-contract.json`; native command classification: `docs/evidence/native-ui-command-audit-1.8.910.0.json`.
- Gameplay requirements: `docs/evidence/native-gameplay-capabilities.json` (25 groups).
- **Limits of this pass:** The repository contains the captured XAML **hashes and extracted findings**, not the original 45-file native XAML archive itself; this pass did not re-parse every original vanilla element or inspect the underlying compiled implementations of `FilterActionResourceCommand`, `SetCurrentShownDeckCommand`, `SpellsAndActions`, `UseSlotCommand`, `VMHotBar` and their provider builders. Those unavailable implementations must **not** be treated as source-proven equal. This audit is a concrete incomplete parity result, not a claim that full game source code was inspected.

## Verified static connections

The following **exact native integration points** exist in CAM's non-comment XAML:

- `UIAccept -> UseSlotCommand(ActionRadials.Tag)`: original native execution command reused by CAM; a slot must still be an actual `VMHotBarSlot`.
- `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList`: resource/spell level/class resource selection.
- `FilterCantripsCommand -> SingleHotBar.SlotList`: cantrip provider.
- `SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList`: native item deck.
- `KeyboardHotBars[*].SlotList`: grouped `All` keyboard-source fallback.
- `PassivesHotBar.SlotList`: native passives.
- `FixedSideBar.SlotList`: visible separate metamagic/fixed-sidebar native slots; proof of the live input handoff is outside static XAML.
- `SingleHotBar.SlotList` with native container/upcast/throw flags and `ClearSingleHotbarCommand`: nested action path.
- `ReleaseConcentrationCommand`, `ToggleDualWieldingCommand`: bound natively in CAM.

These connections prove source presence and reuse **only**. They do not prove that `KeyboardHotBars` contains all radial assignment candidates or that `ItemHotBar` exhausts `Inventory.Slots`. `ControllerHotBars` is deliberately not a CAM provider: it is the player's configured radial layout, not the universe of available actions.

## Gameplay group-by-group static verdict

| Group | BG3 native reference | Direct CAM route or gap | Static verdict |
| --- | --- | --- | --- |
| Melee default attack | `UseMeleeWeaponCommand`; radial `SpellsAndActions` | Native command absent; keyboard/native slot route not proven equal | **Gap: equivalent transport unproven** |
| Ranged default attack | `UseRangedWeaponCommand`; radial `SpellsAndActions` | Native command absent; slot route not proven equal | **Gap: equivalent transport unproven** |
| Weapon-set switching | `SwitchWeaponSetCommand`/native gamepad input | No CAM binding; 0.0.51–0.0.54 attempted transports failed | **Blocked** |
| Equipped light-source switching | `SwapLightSourceCommand` with equipment condition | No CAM binding; no equivalent native slot/transport established | **Blocked** |
| Jump | `LaunchDefaultActionCommand(Jump)` or radial gameplay candidate | Generic direct command absent; All/source equality unproven | **Gap: source equivalence unproven** |
| Shove | `LaunchDefaultActionCommand(Shove)` or radial gameplay candidate | As above | **Gap: source equivalence unproven** |
| Throw | `LaunchDefaultActionCommand(Throw)`/native throw action | Direct command absent; nested throw slot path exists | **Partial source path, equality unproven** |
| Hide | `LaunchDefaultActionCommand(Hide)` or radial candidate | Direct command absent; All/source equality unproven | **Gap: source equivalence unproven** |
| Action/Bonus resource actions | `FilterActionResourceCommand` | BG3-owned filter and executable list bound | **Source present, full catalog unproven** |
| Leveled spells and upcast | Resource filter and `IsSelectingUpcastedSpell` | Native filter plus nested slot list/flag | **Source present, all variants unproven** |
| Cantrips | `FilterCantripsCommand` | Native filter plus slot list | **Source present, full catalog unproven** |
| Class resources | Action resource previews and `SpellsAndActions` | Native resource filter | **Source present, dynamic catalog equality unproven** |
| Passive toggles | `Stats.Passives` + `TogglablePassivePredicate` | `PassivesHotBar.SlotList` | **Source present, predicate-set equality unproven** |
| Metamagic | Native metamagic predicate and `FixedSideBar.SlotList` | Native sidebar/modified state; input/A handoff is separately unresolved (#125) | **Known functional blocker** |
| Consumables | Radial `Inventory.Slots` | Native `ItemHotBar` materialized slots | **Source present, inventory equality unproven** |
| Scrolls | Radial `Inventory.Slots` | `ItemHotBar`/All sources | **Source present, full inventory equality unproven** |
| Item charges | Radial `Inventory.Slots` | `ItemHotBar`/All sources | **Source present, charged-variant equality unproven** |
| Temporary actions | Radial `SpellsAndActions` | Grouped keyboard All / resource filter | **Gap: dynamic source equivalence unproven** |
| Recasts | Radial `SpellsAndActions` | Grouped All / nested state | **Gap: dynamic source equivalence unproven** |
| Nested containers/variants | Native `SingleHotBar.SlotList`, nested state flags | Same native path in CAM | **Source present, execution behavior unproven** |
| Release concentration | `ReleaseConcentrationCommand` | Same native command bound in CAM | **Direct source match** |
| Toggle dual wield | `ToggleDualWieldingCommand` | Same native command bound in CAM | **Direct source match** |
| Targeting and cancellation | Native targeting/ `ClearSingleHotbarCommand`, `CancelTaskCommand`, `TargetGameobjectCommand` | Native UIAccept/B and nested state present; two keyboard commands absent | **Partial match, full command parity unproven** |
| Free/no-resource actions | Radial `SpellsAndActions`; keyboard Common/Class | `KeyboardHotBars` grouped All fallback | **Source present, radial catalog equivalence unproven** |
| Other-mod-added actions | Dynamic game/mod native actions and resources | Only if game populates a currently bound slot provider | **Unverified for new providers/variants** |

**Do not reinterpret “gap” as proof a move is impossible in the game.** It means the available static source does not establish an equivalent reachable CAM route. Conversely, a shared resource filter is not proof of a full dynamic action catalog.

## Exact command-level static comparison

The pinned original Patch 8 keyboard+controller XAML inventory has **36 distinct native UI command names**. The current CAM source has 12 command bindings (11 standard plus intentionally restricted `HighlightResourcesCommand`).

Seven absent **direct gameplay/utility-related bindings** requiring equivalence proof:
`SwitchWeaponSetCommand`, `SwapLightSourceCommand`, `UseMeleeWeaponCommand`, `UseRangedWeaponCommand`, `LaunchDefaultActionCommand`, `TargetGameobjectCommand`, `CancelTaskCommand`.

`SetCursorCommand` is the eighth omitted utility command, but it controls the keyboard-only hotbar resize cursor and is **not** a missing gameplay capability. The other 16 omitted native command names concern original radial editing, keyboard layout, or debug/presentation; they are not automatically required merely because their names appear in the vanilla XAML.

## Required next source-inspection steps (still no game launch)

1. **Original input:** inspect the entire previously captured native Patch 8 XAML archive (the repository currently holds hashes/derived findings, not complete source), not merely the 36 command-name manifest. For every gameplay-relevant original element, record its actual command parameter, binding data owner, relevant `DataTrigger` conditions, `BoundEvent` and provider scope; compare with the complete CAM template and game-owned page/state logic.
2. **Provider construction:** trace the implementation or authoritative native semantics of `SpellsAndActions[*].Actions` versus `KeyboardHotBars[*].SlotList`, `Inventory.Slots` versus `ItemHotBar/CurrentShownDeck.SlotList`, raw passive predicates versus `PassivesHotBar`, and the filter → `SingleHotBar` conversion. Without this, neither a textual XAML match nor a command-name audit proves “every game action”.
3. **Global commands:** prove native safe controller availability or add the source-backed command/control for weapon sets, light, default melee/ranged, Jump/Shove/Throw/Hide and targeting. Do **not** repeat failed weapon shortcut guesses, override ordinary `UILeft`, or make a new Original Radials tab.
4. **Mod extension contract:** identify how additional game mods register abilities/slots and ensure CAM is connected to the same dynamic source mechanism, rather than hard-coding spell or class lists.
5. **Complete verdict:** mark a capability as statically covered only with a source-backed chain from its **vanilla reference producer** to a **CAM-reachable executable slot/native command**. Any uninspected compiled producer or missing input contract remains an explicit blocker; never convert unknown to passed.

This is a **source-only comparative audit**. It intentionally makes no request to launch the game or to enumerate actions manually. Source-level equivalence and actual runtime side effects are different claims.
