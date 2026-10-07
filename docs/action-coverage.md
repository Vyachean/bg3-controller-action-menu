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
| Common deck | `SetCurrentShownDeckCommand` + `CurrentShownDeck.SlotList` | coverage evidence only |
| Class deck | `SetCurrentShownDeckCommand` + `CurrentShownDeck.SlotList` | coverage evidence only |
| Items deck | `SetCurrentShownDeckCommand` + `CurrentShownDeck.SlotList` | coverage evidence only |
| Cantrips | `FilterCantripsCommand` (captured parameter) | coverage evidence only |
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
| cantrips | HotBar + radial | no dedicated shipping source | missing-source |
| free/no-resource actions | Common/Class/radial | no proven complete shipping source | missing-source |
| inventory/consumables | ItemHotBar + radial `Inventory.Slots` | only items incidentally returned by resource filter | missing-source |
| scrolls | ItemHotBar + radial `Inventory.Slots` | no proven complete source group | missing-source |
| item-charge actions | ItemHotBar + radial `Inventory.Slots` | no proven complete source group | missing-source |
| metamagic toggles | radial metamagic predicate | no proven equivalent executable-slot source | missing-source |
| temporary actions | Common/Class/radial | equality not proven | missing-source |
| recasts | Common/Class/radial | native nested behavior only when reached | missing-source |
| mod-added actions/resources | native dynamic models | covered only when BG3 exposes a resource preview / proven slot source | runtime-proof |

This table is deliberately conservative. Absence of a known bug is not proof of parity.

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

The portable read-only capture must emit a small derived HotBar coverage report in
addition to the raw XAML. The report records every current element using:

- `SetCurrentShownDeckCommand`;
- `FilterCantripsCommand`;
- `FilterActionResourceCommand`;

including its `CommandParameter`, and records whether the expected executable collection
bindings are present.

This keeps the proprietary XAML out of the repository while making future source changes
machine-reviewable.

## Runtime milestone gate

No game run is needed for each source hypothesis.

Before the next requested run, CI must prove:

1. the coverage contract is present and its unresolved classes are explicit;
2. capture tooling records current deck/filter parameters automatically;
3. the action grid uses the proven focus-follow scroll seam;
4. no raw radial-assignment object is passed to `UseSlotCommand`;
5. current resource/passive/nested execution remains intact.

The next game milestone should then answer the remaining semantic equality questions in
one run: whether the union of CAM providers contains representative free, cantrip,
item/scroll/charge, metamagic, temporary and recast actions in addition to the already
proven resource-bound/nested cases.
