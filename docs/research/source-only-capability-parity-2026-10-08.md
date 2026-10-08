## Subsequent source-backed implementation — native SummonHotBar (#146)

The exact raw-source comparison below describes pre-#146 CAM state. The
source-backed implementation in `feature/native-summon-hotbar-provider`
binds `SummonHotBar.SlotList` directly to `HotBarList.ItemsSource` when
`SummonHotBar.SlotList.Count > 0`, using the existing `VMHotBarSlot`
styles, source focus and `UseSlotCommand`. The original keyboard HotBar and
controller ActionRadials use the same DCHotBar context. Native
`SingleHotBar.SlotList` nested/upcast/throw state retains priority.
The separate metamagic sidebar's input is disabled while the summoned
source owns the main grid. **No new UI tab or action catalog is created.**

This proves a code-level native source integration, **not** execution or
first-frame controller focus in-game; other action coverage gaps remain.

## Exact installed-game archive verification — 2026-10-08

# BG3 vs CAM: static gameplay-capability parity audit (2026-10-08)



The operator supplied the **original read-only capture** `bg3-controller-action-menu-inputs-20261008-132651.zip`. This archive was opened and all **45 native XAML files parsed offline**, without launching BG3. ZIP integrity check passed; the package manifest says Xbox App `1.8.910.0`; the two critical raw XAML files match the pinned byte-level SHA-256 values:

- `Mods/MainUI/GUI/Pages/HotBar.xaml`: `9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.
- `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`: `4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b`.

**Important correction to the earlier audit:** the previously hypothetical additional keyboard providers are **definitively present in the current installed Patch 8 capture**. This is not a conclusion from a 2024 open-source dump.

| Original source (exact game file/lines) | Verified native construction | CAM counterpart | Source-only verdict |
| --- | --- | --- | --- |
| `HotBar.xaml:1565–1566` | `KeyboardHotBars` collection | Grouped All list | Same provider reference present; completeness of game action catalog not proven |
| `HotBar.xaml:1759` | `ContentControl Content="{Binding SummonHotBar}"`, `HotBarTemplate`, visible when `SummonHotBar.SlotList.Count` | Pre-#146: absent. #146: native `SummonHotBar.SlotList` override of main `HotBarList` | Source-level route restored; real focus/dispatch still runtime-unverified |
| `HotBar.xaml:1752–1754` | `PlayerCharacterProperties.CustomHotBar`, `HotBarTemplate`, guarded by `IsShowingCustomDeck` | **No `CustomHotBar` reference** | Configurable UI excluded from design, but any unique gameplay entries must be available automatically elsewhere |
| `HotBar.xaml:4516–4532` | Native `CallAllies` object used directly by `UseSlotCommand`, with game-owned `BoundEvent` | No explicit CAM-template button | Not sufficient to declare a gameplay loss: original controller page has independent semantic path (next rows) |
| `ActionRadials.xaml:31–39` | On `Loaded`, if `Metadata == CallAllies`, invokes game `CallAllies` command | **Native page unchanged**; CAM changes the template `ActionRadialWidgetTemplate_P8` | **Page-level transport retained by source composition**, not proof of all effects |
| `StateMachines/Controller.xaml:676–678` | `OpenActionRadialsAndCallAllies` opens state with `Metadata="CallAllies"` | Native state machine unchanged | Independent engine-owned event retained |
| `PreloadedActionRadials_c.xaml:160–161,1250–1287` | Raw assignment choices: `SpellsAndActions[*].Actions`, passive/metamagic predicates, `Inventory.Slots` | Resource/keyboard/item/passive providers | **No source-proven equality of executable identities**; do not pass raw assignment objects to `UseSlotCommand` |
| `PreloadedActionRadials_c.xaml:1516` | `ControllerHotBars`: user-assigned radial slots | Deliberately absent | Correctly rejected as an automatic catalog; must prove independent producer coverage |
| `PreloadedActionRadials_c.xaml:1926–1928` | `SwitchWeaponSetCommand` on native `ToggleWeaponSet` | Absent | Confirmed direct transport difference; 0.0.51–0.0.54 guessing already failed |
| `HotBar.xaml:1493–1494` | `SwapLightSourceCommand`, enabled on `Equipment.LightSource.Item` | Absent | Confirmed direct keyboard source difference |
| `HotBar.xaml:1079–1085` | `LaunchDefaultActionCommand` for Jump/Shove/Throw/Hide with native event names and parameters | Absent | Direct command differences; their gameplay effects may still appear as source-provider slots |
| `HotBar.xaml:1348–1362` | Native melee/ranged commands, plus `MainMeleeSpell` slot style | Absent direct command | Equivalent automatic executable source not proven |

**Source-only status:** 45 actual XAML files have now been inspected programmatically. `SummonHotBar` is a newly confirmed independent native source that the current CAM template does not bind. `CallAllies` is *not* assumed lost: the actual original page/state-machine call route is present independently of the replaced template. The original game is closed-source at the ViewModel implementation level; no static XAML comparison proves `SummonHotBar` is absent from *all* other CAM providers or that any in-game action has disappeared.

Machine-readable exact observations: `docs/evidence/patch8-independent-gameplay-producers-2026-10-08.json`.

## Scope and explicit proof boundary

Operator requirement: compare **the original game code/assets with CAM** to establish that no original gameplay capability is omitted **without starting BG3**. This is an inspection of sources, native UI bindings and control flow, not an operator gameplay test. The conclusion must never conflate an executable action with a visible icon or a shared command name.

Current source-side CAM comparison uses `main` through `23f70223bd0e1dcd2e51ad0a603674c49f516d7b`; original game build is Xbox App 1.8.910.0.

- CAM implementation: `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.
- Original installed-game XAML **as recorded by prior read-only capture**: `Mods/MainUI/GUI/Pages/HotBar.xaml`, `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`, `Mods/MainUI/GUI/Pages/ActionRadials.xaml`, `Mods/MainUI/GUI/StateMachines/Controller.xaml`, `Public/Game/GUI/Library/DataTemplates.xaml`.
- Existing exact source SHA-256 inventory and source-backed binding contracts: `docs/evidence/patch8-1.8.910.0-runtime-contract.json`; native command classification: `docs/evidence/native-ui-command-audit-1.8.910.0.json`.
- Gameplay requirements: `docs/evidence/native-gameplay-capabilities.json` (25 groups).
- **Limits of this pass:** The operator's 45-file original native XAML archive was now parsed and compared offline, but it is **not committed** into the repository; GitHub retains derived source pointers and SHA evidence only. The captured UI does not include compiled implementations of `FilterActionResourceCommand`, `SetCurrentShownDeckCommand`, `SpellsAndActions`, `UseSlotCommand`, `VMHotBar` or their provider builders. These unavailable implementations must **not** be treated as source-proven equal. This remains an incomplete functional parity result, not a claim that all game engine code was inspected.

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

## Additional original controller input readback

`docs/research/schema-v3-capture-2026-10-08.md` records a real `Game.pak` extraction of 22 targeted native XAML files, identical by SHA-256 to the preceding read-only capture. The original controller radial uses `ls:LSButton x:Name="ToggleWeaponSet"` with `ControllerHoldButtonStyle` and `SwitchWeaponSetCommand`; `UISelectionLeft` appears as the displayed controller hint, **not** a direct `BoundEvent="UISelectionLeft"` on that element. The keyboard HotBar uses `WeaponSetSwitchStyle` with `BoundEvent="ToggleWeaponSet"`. These are distinct input mechanisms, so neither is a proven drop-in CAM mapping. The existing 0.0.51–0.0.54 direct event adaptations failed the player's actual controller acceptance tests. The source-only result is **native transport unresolved**, not evidence that arbitrary new hold bindings are safe.

The readback explicitly states that the 22 extracted XAML files have already been examined; repeating that unchanged capture cannot reveal compiled ViewModel producer logic. Inspect those producer implementations **offline from available game binaries** if legally and technically accessible, and preserve a hard evidence blocker if not.

## Executable call-site audit of existing offline native capture

`tools/audit-native-ui-commands.py --capture <previously-extracted-capture.zip> --json`
now scans **every** original `.xaml` file under the archive's `files/`
directory (not only the two pinned command-inventory inputs). It parses
the actual XML elements and reports:

- `nativeExecutableSourceSites.nativeUseSlotCallSites`: every native
  `UseSlotCommand` invocation and its `CommandParameter`, event, enablement,
  visibility, element identity and inherited collection sources;
- `nativeCollectionBindings`: independent `ItemsSource` binding expressions
  across all captured game-XAML files, including providers not present in the
  manually curated 25-group matrix;
- `camUseSlotCallSites` and `camCollectionBindings`: corresponding actual CAM
  XAML expressions;
- `nativeCallSitesWithoutIdenticalCamParameter`: **investigation candidates**,
  not automatically missing gameplay. `ActionRadials.Tag` may transport the
  same native VM object by a different expression, so literal inequality is not
  semantic proof; literal equality also does not prove the game-origin object
  is available in CAM.

The original game's `HotBar.xaml` and `PreloadedActionRadials_c.xaml`
still receive the pre-existing pinned SHA-256 and command-inventory checks.
A malformed or duplicate captured file fails closed. CI covers the extractor
with artificial `CallAllies`/summon-slot provenance fixtures: it must not
mistake a shared `UseSlotCommand` for proof of equal action coverage.
**No native file is committed, no game is launched, and no synthetic
`VMHotBarSlot` is added to CAM.**

This extends source provenance, not full game-code access: proprietary compiled
producer logic behind `SpellsAndActions`, `Inventory.Slots` and
`KeyboardHotBars` still needs independent offline evidence. An archive
not accessible to this review cannot be treated as if it were inspected.

## Required next source-inspection steps (still no game launch)

1. **Original input:** inspect the entire previously captured native Patch 8 XAML archive (the repository currently holds hashes/derived findings, not complete source), not merely the 36 command-name manifest. For every gameplay-relevant original element, record its actual command parameter, binding data owner, relevant `DataTrigger` conditions, `BoundEvent` and provider scope; compare with the complete CAM template and game-owned page/state logic.
2. **Provider construction:** trace the implementation or authoritative native semantics of `SpellsAndActions[*].Actions` versus `KeyboardHotBars[*].SlotList`, `Inventory.Slots` versus `ItemHotBar/CurrentShownDeck.SlotList`, raw passive predicates versus `PassivesHotBar`, and the filter → `SingleHotBar` conversion. Without this, neither a textual XAML match nor a command-name audit proves “every game action”.
3. **Global commands:** prove native safe controller availability or add the source-backed command/control for weapon sets, light, default melee/ranged, Jump/Shove/Throw/Hide and targeting. Do **not** repeat failed weapon shortcut guesses, override ordinary `UILeft`, or make a new Original Radials tab.
4. **Mod extension contract:** identify how additional game mods register abilities/slots and ensure CAM is connected to the same dynamic source mechanism, rather than hard-coding spell or class lists.
5. **Complete verdict:** mark a capability as statically covered only with a source-backed chain from its **vanilla reference producer** to a **CAM-reachable executable slot/native command**. Any uninspected compiled producer or missing input contract remains an explicit blocker; never convert unknown to passed.

This is a **source-only comparative audit**. It intentionally makes no request to launch the game or to enumerate actions manually. Source-level equivalence and actual runtime side effects are different claims.
