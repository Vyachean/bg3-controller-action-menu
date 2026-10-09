# External-source audit: can native XAML + StateMachine + Osiris solve CAM action dispatch?

Date: **2026-10-09**. Target installed Xbox App PC BG3 **1.8.910.0**.
Previous release: `v0.0.114-native-state-probe`.
**Conclusion:** The native UI→Osiris bridge is a REAL supported no-Script-Extender
capability, but the inspected implementations do **not** provide a
runtime-selected `VMHotBarSlot` or `VMUpcast` to a gameplay-safe
Osiris call. Do not replace existing BG3 `UseSlotCommand` or native
cancel with `UseSpell`. This is an evidence result, **not a proof of
impossibility of all future solutions**.

## 1. Source references and versions

| Source | Precisely inspected evidence | Relevance |
|---|---|---|
| [NMCM repo](https://github.com/Luiznunes12/bg3-nmcm/tree/3f14c694e30d0c96c7de391e8bafa97e1cb062a1), commit `3f14c694e30d0c96c7de391e8bafa97e1cb062a1` | `docs/architecture.md`, `docs/gamepad.md`, `docs/integration.md`, `examples/controls/button/button-row.xaml`, `examples/example-mod/Mods/NMCM_Example/Story/RawFiles/Goals/NMCM_Example_Config.txt`, `examples/example-mod/Mods/NMCM_Example/GUI/StateMachines/Controller.xaml` | Exact, implemented, no-SE GUI→Osiris→passive/resource→GUI protocol |
| [Official UI StateMachine extending](https://mod.io/g/baldursgate3/r/ui-extending-the-ui) | StateMachine events can add/remove page states; `ModType=Extend` avoids replacing vanilla state | Page lifecycle and additional widgets, not gameplay slot execution |
| [Official UI general setup](https://mod.io/g/baldursgate3/r/ui-basic-setup) | XAML uses built-in BG3 UI models and game-specific Noesis classes | XAML can only access exposed properties/commands; does not expose their compiled implementation |
| [Official TutorialEvent](https://docs.baldursgate3.game/index.php?title=TutorialEvent) and [TogglePassive](https://docs.baldursgate3.game/index.php?title=TogglePassive) | Fixed `TutorialEvent(CHARACTER,TUTORIALEVENT)` identifier; `TogglePassive(GUIDSTRING,STRING)` requires explicit passive ID | Can change a **known** stat/persistent choice, cannot by itself locate a dynamic selected metamagic VM slot |
| [Official UseSpell](https://docs.baldursgate3.game/index.php?title=UseSpell) and [UseSpellAtPosition](https://docs.baldursgate3.game/index.php?title=UseSpellAtPosition) | Server-side cast calls intentionally **ignore availability and action resource preconditions** | Incompatible with CAM's correct costs/cooldowns/targeting/upcast requirement |
| [Metamagic Extended source](https://github.com/darkcharl/metamagic-extended/tree/cd17922d7815b5143cc04e2c404583f6a8f2b559) | `PAK/Public/MetamagicExtended/Stats/Generated/Data/Passive_Metamagic.txt`, `PAK/Scripts/thoth/helpers/MetamagicExtended.khn`, `PAK/Mods/MetamagicExtended/ScriptExtender/Lua/BootstrapServer.lua` | Demonstrates engine-defined spell predicates and `UnlockSpellVariant` but NOT an enumerable compatible controller VMHotBarSlot provider. Transmuted dynamic behavior explicitly uses `Ext.Events.DealDamage` |
| [Radial Hotbar Customization](https://gitlab.com/saghm/bg3-radial-mods) / [Nexus](https://www.nexusmods.com/baldursgate3/mods/18194) | Public source location and published dependency contract; full GitLab file contents **not retrieved** in this pass | Requires Script Extender and MCM; hotbar serialization/locking is separate from XAML-only VMUpcast execution |
| [Patch 8 Osiris reference](https://github.com/Geminitrix/bg3-arcana-deckbuilder/blob/main/Docs/OSIRIS.md) | Distinguishes `CastSpell`, `CastedSpell`, `UsingSpell`; project itself uses Script Extender Lua | Events report casting phases, they do not substitute UI targeting/cost-conserving `UseSlotCommand` |
| [CAM capture](native-radial-contract-1.8.910.0.md), [CAM verified UI state](v0113-native-controller-state-audit-2026-10-09.md), [v0.0.114 game result](v0114-native-focus-runtime-rejection-2026-10-09.md) | `ActionRadials`, `SingleHotBar.SlotList`, `VMHotBarSlot`, `UseSlotCommand`, `FilterActionResourceCommand`, `IsSelectingUpcastedSpell`, `MetamagicActive` | Authoritative current-game XAML; still lacks compiled ViewModel body |

Source confidence: actual NMCM example and Metamagic Extended GitHub trees
**inspected**; official Larian descriptions **public and inspectable**;
Radial Hotbar Customization identified but **no file-level semantics
claimed**. Old `akintos/bg3-data` XAML is **not** pinned Patch 8 proof.

## 2. What NMCM actually transfers

```text
LSButton.Click
  -> UIWidget.DataContext.TutorialEvent(CommandParameter=<compile-time UUID>)
  -> Osiris TutorialEvent(Entity,UUID)
  -> predetermined Osiris goal branch
  -> DB fact, AddPassive/RemovePassive or party action-resource mirror
  -> UI reads Stats.Passives[*].Name.Str / Stats.ActionResources
```

- One fixed UUID per meaningful control/value. The click callback is
  **not** a command with an arbitrary native `VMHotBarSlot` argument.
- `EnableTutorialEvent` must be called per player, including existing
  saves. The event's Entity is the **host**, not necessarily the
  selected party character. This matters for multiplayer/companions.
- An NMCM numeric selection uses N *declared* UUIDs, not an arbitrary
  runtime level/slot payload. A passive/resource mirror is additional
  synthetic state and does **not** set BG3's own `VMUpcast`.
- The client example demonstrates working XAML+Osiris for settings;
  it **does not** show invoking `ActionRadials.UseSlotCommand`,
  serializing `VMHotBarSlot` identity, passing dynamic spell costs
  or cancelling a pending metamagic transaction.
- NMCM depends on a **Story build**, TutorialEvents.lsx, compiled
  stats, localization markers and per-character setup. This is much
  more invasive than a read-only XAML extension; adding it without
  proving the missing gameplay operation is unwarranted.

### Native possibilities — distinctly not solutions

- **`TogglePassive(Entity, PassiveID)` exists.** It can toggle an
  explicit known passive. There is no source-backed mapping from the
  current selected `FixedSideBar.SlotList` native `VMHotBarSlot`
  into the `STRING PassiveID` accepted by that call. Guessing the ID,
  globally removing a passive, or enumerating sorcerer names would
  break mod-added/passive-state behavior and may not end the original
  native spell-selection task.
- **`UnlockSpellVariant(predicate, ...)` is engine-level stats
  expression**, seen in Metamagic Extended with
  `ModifyIconGlow()` / `ModifyUseCosts()`. Its presence is direct
  evidence that BG3 can decide which spells are modified; it is NOT
  evidence that CAM has a corresponding XAML-bindable list of only
  executable compatible `VMHotBarSlot` entries.
- **`UseSpell(Caster, SpellID, Target)` is an incorrect shortcut.**
  Larian explicitly documents that it ignores preconditions such as
  owning the spell and available spell resources, and the call has
  no selected `VMUpcast` UI argument. Do not use it for regular CAM
  A dispatch or for a direct level-IV cast.
- **`CastSpell`/`CastedSpell`/ `UsingSpell` are observations**, not
  evidence that using `ActionCancelCommand` in a new UI phase rolls
  back `MetamagicActive`.

## 3. Answer to the three P0 gameplay questions

| Requirement | Confirmed bridge | Missing contract | Decision |
|---|---|---|---|
| One B cancels pending active metamagic | `UICancel`, existing BG3 `ActionCancelCommand`, Osiris `TogglePassive` for a known ID | Exact current metamagic toggle identity; effect of native cancel on game-owned `MetamagicActive`; whether pending targeting task survives close | **UNPROVEN**. Native cancellation remains candidate, not accepted behavior; no guessed toggling or local marker reset masquerading as rollback |
| Only compatible, executable spells after metamagic | BG3-owned `Content.IsModified` visual signal; `UnlockSpellVariant` stats predicate | Current Patch 8 XAML-bindable **dynamic executable** filtered `VMHotBarSlot` source with stable focus, A and cost semantics, including mod-added actions | **UNPROVEN**. Do not replace provider with a static catalog or treat opacity as eligibility. A separate navigable-slot focus filter would require its own source/runtime proof |
| Selecting resource IV directly executes level IV | `FilterActionResourceCommand`, `SingleHotBar.SlotList`, `UseSlotCommand(VMHotBarSlot)`, native upcast selector | Engine-owned `VMUpcast` level-specific executable identity and explicit IV selection/tooltip/resource cost | **UNPROVEN**. Preserve the game's second selector until proven; never synthesize `UseSpell` |

## 4. Useful verified no-SE techniques

Two practical techniques *are* suitable for the CAM presentation
architecture, but not as a substitute for gameplay commands:

1. **Controller focus is separate from selection.** NMCM's documented
   gamepad source explicitly uses `ls:MoveFocus.IsFocused` rather
   than keyboard/mouse `IsMouseOver`. For conditionally visible
   rows, `SetMoveFocusAction(JumpFocus=First)` is documented to
   target the first focusable row; `Visibility=Collapsed` differs
   from `IsEnabled=False`. A *new* CAM focus contract would still
   require verifying whether the native `LSGrid` slot containers
   honor that behavior at list bounds. The v0.0.114 operator already
   observed lost focus, so do not claim this documentation proves
   our current sidebar fix.
2. **UI StateMachine Extend avoids wholesale page overriding** when
   adding separate widgets, as demonstrated by NMCM and official
   guides. CAM intentionally replaces the radial content, so this
   can improve auxiliary overlays but not safely replace its
   native action/cancel transaction.

## 5. Next implementation gate (not another research micro-release)

1. Look for a **Patch 8 native gameplay command** accepting current
   native metamagic selection/cancel transaction and a **native
   upcast-level-specific slot**. Exposed XAML alone has not shown
   these parameters. If available, route existing exact VM identities
   and original native event semantics through CAM.
2. If an actual controller focus-only issue remains after merge #182,
   use the NMCM exact focus-owner pattern as a separately bounded
   XAML candidate; never combine it with fake compatibility filtering.
3. If engine semantics cannot be obtained within ordinary .pak data
   and existing exposed commands, keep issues #158/#172 blocked and
   **consider a clearly disclosed feature limitation** under the
   no-DLL/no-SE requirement instead of compromising cost correctness.
4. Do not add NMCM as a runtime dependency; its **architecture**
   can be learned from, but a separate settings framework does not
   solve dynamic combat action dispatch. Preserve one-click VBS,
   Xbox App targeting, self-contained .pak, native input/tooltip and
   action-cost highlight.

**Implementation status:** research result only. No runtime XAML,
story scripts, PAK dependencies, `VERSION`, universal installer or
gameplay action commands changed. Green automated tests, if any,
would prove structure only. One future combined game test remains
appropriate when a real source-backed candidate exists.
