# Better Hotbar 2: public-source comparison with CAM and pinned Patch 8

Date: 2026-10-09. Scope: research for #172, #176 and draft PR #193.
This comparison is **not** a source transplant or evidence that
a modern keyboard HotBar's compiled ViewModel is identical to a
2024 community fork. No changes to shipped XAML are authorized here.

## Verifiable material

| Source | Version and trust | What can be checked |
| --- | --- | --- |
| [Better Hotbar 2 fork by elijah-dev, 2024 HotBar.xaml](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/a27374490ab92e19773d4ea8ab50ae201f13e6b7/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml) | Public, pinned Git commit `a27374490ab92e19773d4ea8ab50ae201f13e6b7` and XAML blob SHA `5d08e9c9d192856c81a4796e041fe401a910aaa9`; historical, independently modified keyboard interface; **NOT** current 1.8.910.0 original | Exact command/view binding declarations only |
| [Official Better Hotbar 2 Nexus distribution](https://www.nexusmods.com/baldursgate3/mods/2417?tab=files) | Vova's Edition `2.0.0.34`, uploaded April 18, 2025, marked Patch 8 compatible | Distribution metadata and author descriptions. **Latest archive XAML not directly available** in this inspection |
| [Caites/BG3-UI-mods GitHub](https://github.com/caites/BG3-UI-mods) | Main has only `LICENSE`; its release archives are from 2023 | No authoritative current Patch 8 source in repository main |
| [A-V-Ernst/betterhotbar-bg3](https://github.com/A-V-Ernst/betterhotbar-bg3) | October 2026 related fork, repository tree contains a `.pak` only | Existence of newer binary, **not** independently parsed executable/UI semantics |
| [Our Xbox App 1.8.910.0 source pins](../evidence/patch8-1.8.910.0-runtime-contract.json) | Hashes of prior read-only installed-game capture | Proven original file identity **only if exact raw bytes are supplied and rechecked** |

The Nexus author [restricts modification, reupload and asset use without permission](https://www.nexusmods.com/baldursgate3/mods/2417?tab=description).
This project therefore records names/relations of **BG3-owned** bindings;
it does not vendor Better Hotbar assets, copy XAML blocks, claim a license
grant, or add Better Hotbar/ImpUI as a runtime dependency.

## Independently inspected public 2024 XAML — five relevant boundaries

| Public fork XML location | Proven behavior of that XML | CAM #193 comparison |
| --- | --- | --- |
| [L125–134, `HotBarSlotStyle1`](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/main/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml#L125-L134) | The actual UI button inherits `UseSlotCommand` from its `UIWidget` and dispatches the current control `DataContext` as the parameter. | CAM calls the same BG3 command on A but transports `HotBarList.LocalFocus.DataContext` through delayed `ActionRadials.Tag`. Equal command **name** does not prove equal slot object. |
| [L3108–3114 and L3193–3216, action resource preview](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/main/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml#L3193-L3216) | Item `VMActionResourceCostPreview` from `CurrentPlayer.UIData.ActionResourcesCostPreview` calls `FilterActionResourceCommand` with `{Binding}`, guarded against `CurrentSingleHotbarFilter == ActionResource.Name`. On equal filter the source instead performs a presentation hide action. | CAM uses `CAM_ResourceTabs.SelectedItem` of the **same** native preview collection and the same filter command, but has independent LB/RB tabs and presentation state. This difference is a **candidate** for source-state investigation; don't blindly add the keyboard Click toggle/guard to controller nested restoration. |
| [L2352–2357, game-owned deck controls](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/main/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml#L2352-L2357) | `SingleHotBar` is mounted via `HotBarTemplate`, with visibility from `CurrentSingleHotbarFilter`; independent `PassivesHotBar`, `CustomHotBar`, `SummonHotBar` content controls also exist. | CAM reads native `SingleHotBar.SlotList` and switchable native passives/summon providers. The keyboard-specific user-configured `CustomHotBar` does not prove an automatically complete controller catalog. |
| [L2576–2579, L2589–2593, L2645–2662, native upcast deck](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/main/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml#L2645-L2662) | **Separate** `UpcastSection` has `ItemsSource=CurrentActiveSlot.Spell.SpellUpcast`, `VMUpcast` items using `HotBarSlotStyle1`, `CommandParameter={Binding .}`, `IsEnabled={Binding CanUse}`; the active task publishes `CurrentPlayer.UIData.ActiveTask.Upcast.CostSummary`. | These are **game-owned** variant objects and costs, not CAM-created spell copies. CAM currently has no demonstrated `CurrentActiveSlot.Spell.SpellUpcast` owner in controller widget scope. |
| [L5941–5973, nested visibility](https://github.com/elijah-dev/bg3-better-hotbar-2-better-concentration/blob/main/BetterHotBar2_169_4x25/Public/Game/GUI/Widgets/HotBar.xaml#L5941-L5973) | `UpcastSection` appears under `IsSelectingUpcastedSpell` and `SingleHotBar` visibility conditions, with additional multi-target cases. | A level-picker is intentionally supported by this historical keyboard HotBar. Hiding the native controller picker just because the IV tab was selected risks suppressing engine state without executing the correct IV variant. |

## Consequences for #172

**Confirmed from the reference:** the correct command family is already
native: resource preview → BG3 resource filter → native hotbar
slot, and (when a separate upcast task is entered) a real
`VMUpcast` → native `UseSlotCommand` with `CanUse` and
native cost summary. We must not implement spell-slot level,
damage, spell availability, modifier compatibility or resource
spending in custom CAM code.

**Not established:** the user's observed **current** keyboard
IV tab → immediate IV spell/tooltip may be a later Patch 8 producer
contract or a different native `VMHotBarSlot` representation than
the 2024 fork. The old reference actually has a two-step upcast
panel, so **it does not explain the missing direct-IV behavior**.
The installed game's pinned original XAML and compiled `DCHotBar`
producer, including the live `CurrentSingleHotbarFilter` and
`CurrentActiveSlot.Spell.SpellUpcast` values, remain the stronger
inputs. The 2025 Vova's Edition source cannot be called
inspected merely because its release archive is listed.

**New diagnostic scope:** `tools/trace-upcast-parity.py` now
tracks the original `CurrentSingleHotbarFilter`,
`ActiveTask.Upcast.CostSummary` and `SpellSlotLevel` binding
families in addition to original filter, upcast collection,
main `VMHotBarSlot`, tooltip and `UseSlotCommand`. The
source report must keep community reference evidence distinct
from SHA-verified original Patch 8 sources.

## Next permitted work

1. Reopen and SHA-verify the **previously captured 1.8.910.0 original**
   `HotBar.xaml` using the existing read-only tool.
2. Compare whether a filtered native `VMHotBarSlot` in
   `SingleHotBar.SlotList` is itself an executable IV
   variant, or only a base spell opening the game's separate
   `CurrentActiveSlot.Spell.SpellUpcast` task.
3. If the game-owned executable IV variant is proven to exist in
   ActionRadials context, pass **that exact instance** to
   `UseSlotCommand` and derive tooltip/cost from the same
   instance. Otherwise preserve the native picker.
4. Keep PR #193 draft and do not publish a speculative release or
   ask for a new game micro-test based on community keyboard XAML.
