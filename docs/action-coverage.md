# Controller HotBar action coverage contract

## Goal

CAM is a controller-first HotBar, not a second independent action system.

BG3 owns action availability, costs, targeting, upcasts, variants, recasts, item state,
resources and execution. CAM owns only organization, controller navigation and presentation.

The completion invariant is:

```text
native keyboard HotBar executable actions
    UNION
native radial-assignment executable candidates
    MINUS
intentional radial-editing-only operations
        ⊆
CAM reachable executable actions
```

A release must not be described as a complete HotBar replacement while a known native
action class has no proven CAM route.

## Identity boundary

Coverage is about executable BG3 objects, not names or icons.

- CAM executes only native `VMHotBarSlot` values through `UseSlotCommand`.
- Raw `VMCharacterAction`, `VMItem`, `VMPassive`, SpellBook action groups, names,
  icons or class names are evidence/catalog inputs only.
- CAM must never synthesize membership with spell-name, class-name, icon or resource-name
  tables.
- Duplicate execution variants are valid when BG3 exposes different costs/upcasts.

## Current Patch 8 evidence

Pinned installed-game version: Xbox App / Microsoft Store PC `1.8.910.0`.

### Keyboard HotBar

Current captured `HotBar.xaml` proves these executable/deck seams:

| Native surface | Proven seam | CAM status |
| --- | --- | --- |
| resource filters | `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList` | shipping |
| Common/Class keyboard groups | `KeyboardHotBars[*] -> VMHotBar.SlotList` | shipping as grouped `All` fallback |
| Items deck | `SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList` | shipping / runtime-unverified |
| Cantrips | `FilterCantripsCommand` with captured parameter `h7d02199dg44ecg4a1egbcacg9cc1cec197b3` | shipping through `SingleHotBar.SlotList` |
| Passives | `PassivesHotBar.SlotList` | shipping |

### Controller radial assignment

Current captured `PreloadedActionRadials_c.xaml` proves the assignment catalog exposes:

- `PlayerCharacterProperties.SpellsAndActions[*].Actions`;
- `Stats.Passives` through `TogglablePassivePredicate`;
- `Stats.Passives` through `TogglableMetaMagicPassivePredicate`;
- `Inventory.Slots`.

Those raw catalog objects are **not** valid CAM dispatch parameters. They are the
independent reference set used to detect coverage gaps.

### Nested execution

These remain BG3-owned and are already part of CAM's execution path:

- `SingleHotBar.SlotList`;
- `IsShowingAContainerWithVariants`;
- `IsSelectingUpcastedSpell`;
- `IsShowingItemsToThrow`;
- `ClearSingleHotbarCommand`;
- `UseSlotCommand`.

## Coverage matrix

The following classes are the required parity matrix. `proven` means the current
shipping source is sufficient by native contract; `runtime-proof` means the source
exists but equality with the reference catalog cannot be established statically;
`missing-source` means a BG3-owned executable source/filter still has to be proven.

| Action class | Reference evidence | Current CAM path | Status |
| --- | --- | --- | --- |
| Action-resource actions | HotBar resource filters | resource filter -> `SingleHotBar.SlotList` | runtime-proof |
| Bonus-action-resource actions | HotBar resource filters | resource filter -> `SingleHotBar.SlotList` | runtime-proof |
| spell-slot variants | HotBar resource filters | resource filter -> `SingleHotBar.SlotList` / native upcast | runtime-proof |
| class-resource actions | HotBar resource filters | resource filter -> `SingleHotBar.SlotList` | runtime-proof |
| passives/toggles | radial + PassivesHotBar | `PassivesHotBar.SlotList` | runtime-proof |
| nested variants/containers | native radial | `SingleHotBar.SlotList` | proven |
| throw nested state | native radial | `SingleHotBar.SlotList` + native flag | proven |
| cantrips | HotBar + radial | `FilterCantripsCommand` -> `SingleHotBar.SlotList` | proven-source / runtime-unverified |
| free/no-resource actions | Common/Class/radial | grouped `KeyboardHotBars[*].SlotList` fallback | keyboard source covered / radial parity runtime-unverified |
| inventory/consumables | ItemHotBar + radial `Inventory.Slots` | `SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList` | proven keyboard source / radial parity runtime-unverified |
| scrolls | ItemHotBar + radial `Inventory.Slots` | ItemHotBar + grouped `KeyboardHotBars[*].SlotList` fallback | keyboard source covered / radial parity runtime-unverified |
| item-charge actions | ItemHotBar + radial `Inventory.Slots` | ItemHotBar + grouped `KeyboardHotBars[*].SlotList` fallback | keyboard source covered / radial parity runtime-unverified |
| metamagic toggles | radial metamagic predicate + native `FixedSideBar` | parallel `CAM_FixedSideBarList` bound to `FixedSideBar.SlotList`; native `IsActive`/`IsModified` presentation | proven-source / runtime-unverified |
| temporary actions | Common/Class/radial | grouped `KeyboardHotBars[*].SlotList` fallback | keyboard source covered / radial parity runtime-unverified |
| recasts | Common/Class/radial | grouped `KeyboardHotBars[*].SlotList` fallback + native nested behavior | keyboard source covered / radial parity runtime-unverified |
| mod-added actions/resources | native dynamic models | covered only when BG3 exposes a resource preview / proven slot source | runtime-proof |

This table is deliberately conservative. Absence of a known bug is not proof of parity.

## Metamagic is a parallel native provider

Installed-game `HotBar.xaml` (Xbox App 1.8.910.0) displays `FixedSideBar`
**at the same time** as the ordinary HotBar deck. It is not a resource
filter. CAM therefore displays native `FixedSideBar.SlotList` in a
separate, count-conditional vertical controller list. The Metamagic
LB/RB entry provides controller access to this list and restores the
last selected **native** resource filter for the center grid; it never
substitutes FixedSideBar slots for spell grid slots.

The shared installed-game `DataTemplates.xaml` uses
`Content.IsModified -> HotbarSlotGlow` for the spell-modification effect
and `Content.IsMetaMagic + IsActive -> HotBarActiveSlotIndicatorMetamagic`
for the active metamagic indicator. CAM must bind these existing game
values, not calculate compatible spells. A side slot is executed only
as `VMHotBarSlot` through the existing `ActionRadials.Tag ->
UseSlotCommand` route. Whether the filter materializes live modified
spell states and whether two-list focus/tooltip handoff behaves
correctly remain in-game acceptance gates for #125.

See [exact installed-source audit](research/metamagic-parity-2026-10-08.md).

## Provider architecture

The final controller HotBar keeps one top-level cost/source row and one executable grid,
but the row is allowed to use multiple **BG3-owned executable providers**.

```text
controller category/source
        |
        +-- ActionResource provider
        |     FilterActionResourceCommand
        |        -> SingleHotBar.SlotList
        |
        +-- proven native deck/filter provider
        |        -> VMHotBarSlot collection
        |
        +-- All fallback
        |     KeyboardHotBars[*].SlotList
        |        -> VMHotBarSlot
        |
        +-- Passives provider
              -> PassivesHotBar.SlotList
                     |
                     v
             one HotBarList
                     |
                     v
             UseSlotCommand(slot)
```

Resource filters remain the preferred path for Action/Bonus/spell slots/class resources.
A non-resource provider may be added only when current installed-game evidence proves
that it yields executable `VMHotBarSlot` values or invokes a BG3 filter that materializes
such values.

The provider architecture must **not** revive the rejected 0.0.35 raw
Actions/Items/Passives source-tab implementation.

## Controller focus and scrolling

`HotBarList.LocalFocus.DataContext` is the action identity authority.

The following must all derive from the same focus:

- visible selector;
- tooltip;
- `ActionRadials.Tag`;
- A dispatch;
- focus-follow action-grid scrolling.

The captured Patch 8 controller scroll seam is:

```text
ActionRadials.FocusedElement
        ->
LSScrollViewer.ScrollToElement
```

CAM should reuse that seam for the action grid rather than relying on the ordinary
ScrollViewer to infer controller focus.

## Capture diagnostics

The portable read-only capture emits a derived HotBar coverage report in addition to the
raw XAML. Research seams are **probes, not capture prerequisites**.

The report searches the whole captured XAML set for:

- `SetCurrentShownDeckCommand`;
- `FilterCantripsCommand`;
- `FilterActionResourceCommand`;

and records `Present`, `MatchCount`, source file and available attributes such as
`CommandParameter`, `Content` and `Tag`. Native bindings may use `DataContext.<Command>`
plus `RelativeSource`; discovery matches the command name inside the complete Binding
expression rather than requiring the short `{Binding Command}` spelling.

If a probe is absent, that absence is written to `MissingCommands`; it must not abort the
capture. Capture fails only for technical evidence failures such as inability to locate
or extract the required game/UI inputs.

This keeps the proprietary XAML out of the repository while making source movement,
renaming and absence machine-reviewable instead of turning an outdated assumption into
an operator-facing failure.

## Runtime milestone gate

No game run is needed for each source hypothesis.

Before the next requested run, CI must prove:

1. the coverage contract is present and its unresolved classes are explicit;
2. capture tooling records current deck/filter parameters automatically;
3. the action grid uses the proven focus-follow scroll seam;
4. no raw radial-assignment object is passed to `UseSlotCommand`;
5. current resource/passive/nested execution remains intact.

The next game milestone should answer the remaining semantic equality questions in one
run: whether the union of CAM providers contains representative free, item/scroll/charge,
temporary and recast actions, and whether ItemHotBar covers the relevant radial
`Inventory.Slots` cases, in addition to the already proven resource-bound/nested cases.
