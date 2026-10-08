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

## Scope: presentation replacement, not a second gameplay engine

CAM replaces the original gamepad **radial layout and manual slot editor**
with a **read-only, automatically populated grid**. Keyboard HotBar is a
visual reference, not the contract that determines which controller actions
exist. The gameplay authority is still BG3's controller action model and its
native commands/targeting. A player must not arrange, clear, or synchronize
radial slots before opening CAM. One horizontal resource/category tab level
organizes the available actions; no nested category tabs or manual grids.

Parity includes not just successful `UseSlotCommand` execution but native
refusal feedback, cancellation, target/variant selection, cost and
availability explanations, combat/control shortcuts, and tooltip behavior.
Replacing a visual control must preserve the original semantics when an
action **cannot** be executed.

### First confirmed visual transport regression: unavailable-action feedback

Installed Xbox App 1.8.910.0
`Public/Game/GUI/Library/PreloadedActionRadials_c.xaml:1897–1915`
has `SelectButtonVisual` wired to `BoundEvent="UIAccept"`,
`EatInput="False"`. Its `Click` trigger plays `UI_Shared_Error`
only when the **game-owned** focused slot reports `Tag.CanUse == False`
and `Tag.ThothError` is nonempty. BG3's neighboring
`UseSlotBinding` is separately gated by `Tag.CanUse`; the error sound
does not try to cast an unavailable action.

CAM previously kept the select visual and native execution gating but
accidentally dropped this `Click` trigger. Restore the original conditional
sound verbatim. This is a controller feedback regression, not a reason to
replace native `VMHotBarSlot` execution or create a second catalog. The
native dynamic warning/cost presentation remains a separate UX review.
Static XAML presence tests are not proof that an input event fires in-game.

## Capability preservation, not radial preservation

The player must never configure or browse **Original Radials** to make actions accessible in CAM. The original `ControllerHotBars` collection is useful as comparison evidence but is not a CAM provider: cleared or incomplete vanilla radial slots must not remove actions from the automatic catalogue. Preserve keyboard and controller gameplay, including native global commands, weapon/light switches, targeting, nesting, metamagic and other-mod actions. Unknown executable providers or omitted capabilities remain blocking, not reasons to expose raw radial layout.

Static provider/command checks are not proof of real action reachability. Separate runtime identity and execution coverage are required under #134 and #135.

## Controller weapon-set switch — preserve the original hold control

The original installed Xbox App BG3 1.8.910.0 `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml:1925–1928` renders `ToggleWeaponSet` as an `ls:LSButton` with:

- `Style="{StaticResource ControllerHoldButtonStyle}"`;
- a visual hint for `UISelectionLeft` through `FindInputEventConverter`;
- `Command="{Binding SwitchWeaponSetCommand}"`, with **no explicit `BoundEvent`** and `EatInput="False"`;
- a native `HasRangedAttack=False` trigger that collapses the button.

This is a **gameplay control**, not a configurable radial slot, and must not
disappear in CAM merely because actions render as a grid. CAM restores the
exact native button and visibility policy in the existing button-hints row.
The grid's `UILeft` navigation stays untouched.

**Known failed alternatives (operator-proven):** adding
`BoundEvent="UISelectionLeft"` to the visual button fired only once;
raw `LSInputBinding UISelectionLeft` captured short presses; rebinding
`LSInputBinding ToggleWeaponSet` also captured short presses; a custom
`HoldTimeShortcuts` input binding was not repeatable. Do **not** recreate
those listeners or claim that reproducing the original XAML alone proves
repeatable hold handling inside CAM.

The source-backed restoration is guarded by structural CI tests, but actual
repeatable gamepad hold behavior remains a single **milestone runtime check**,
alongside the rest of the menu, not a reason to request a separate build test.

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
| summoned creature action hotbar | native `SummonHotBar.SlotList` | automatic native-list override of main grid while nonempty; nested `SingleHotBar` stays higher priority | source wired / game behavior unverified |
| conditional Call Allies action | original `ActionRadials.xaml` page Loaded/Metadata action | native page+state-machine route retained outside CAM template | page-level source preserved / effect unverified |
| custom keyboard deck | native `CustomHotBar` | no direct provider; editing excluded, unique playable actions require independent coverage | unresolved |

This table is deliberately conservative. Absence of a known bug is not proof of parity.

## Additional native producers proved by actual 1.8.910.0 XAML archive

The actual `bg3-controller-action-menu-inputs-20261008-132651.zip`
was parsed offline, all 45 XAML files intact. Two independent sources
previously absent from the checklist are native **`HotBarTemplate`
content providers**, not ordinary `ItemsSource` list bindings:

- `SummonHotBar` (current original `HotBar.xaml:1759`, visibility
  by `SummonHotBar.SlotList.Count`) was absent before #146. CAM now binds
  `SummonHotBar.SlotList` as a native executable override and keeps
  `SingleHotBar` above it when nested. Gameplay behavior remains
  unverified; do not assume the other providers contain its slots.
- `PlayerCharacterProperties.CustomHotBar` (current original
  `HotBar.xaml:1752–1754`) is a configured native deck not directly
  bound in CAM. This **does not** justify bringing back configurable
  radials, but any unique playable ability from it must be available
  through an automatic game-owned executable source.
- `PlayerCharacterProperties.CallAllies` is used directly with
  `UseSlotCommand` in keyboard `HotBar.xaml:4519–4532`, but original
  *controller* `ActionRadials.xaml:31–39` independently invokes native
  `CallAllies` when `Metadata=CallAllies`; the native state machine
  supplies that metadata (`Controller.xaml:676–678`). CAM replaces
  the controller **template**, not that page/state. Source composition
  preserves this page-level route; runtime effects are not proven.

The exact SHA-256-backed extraction evidence is in
[`patch8-independent-gameplay-producers-2026-10-08.json`](evidence/patch8-independent-gameplay-producers-2026-10-08.json)
and [the source audit](research/source-only-capability-parity-2026-10-08.md).

**No completeness claim** follows merely from shared `UseSlotCommand`
names. The independent native `SummonHotBar` requires a concrete
CAM-reachable implementation or equivalent producer proof.

## Native summon overlay (source-backed implementation #146)

Original installed 1.8.910.0 `HotBar.xaml:1–11` and `ActionRadials.xaml:1–15`
both declare the same `ls:UIWidget.ContextName="HotBar"` and
`DCHotBar` design context. Therefore the original `{Binding SummonHotBar}`
provider is directly available to CAM's **same** game-owned view model
without an adapter, script extender, or synthesized actions.

Original `HotBar.xaml:1759` renders `SummonHotBar` through
`HotBarTemplate` (native `VMHotBar.SlotList`) whenever
`SummonHotBar.SlotList.Count` is nonzero. Original
`HotBar.xaml:4897–4900` hides ordinary `KeyboardHotBars` while this
summon provider is visible. Original `HotBar.xaml:4903–4910` lets
`SingleHotBar` overlay the summon provider during native nested selection.

CAM follows that owner/source order:

1. Nonempty `SummonHotBar.SlotList` overrides the ordinary resource,
   item, passive and grouped All **main grid ItemsSource** with the original
   executable `VMHotBarSlot` list. No new tab is introduced; summoned
   action mode takes priority automatically, as in original HotBar.
2. When any native `IsShowingAContainerWithVariants`,
   `IsSelectingUpcastedSpell` or `IsShowingItemsToThrow` is true, the
   existing **later-priority** `SingleHotBar.SlotList` returns to the
   same main grid. It uses the original `UseSlotCommand` dispatch.
3. The main-grid slot item styles, tooltip/focus and action dispatch
   must remain `VMHotBarSlot`-based even if the stored CAM provider
   selection had been grouped All or Metamagic.
4. Nonempty summon source disables the otherwise Metamagic-owned
   `CAM_FixedSideBarList` **input**, enabling the main grid only; keep
   native sidebar visuals. This avoids two independent controller
   selectors/dispatch authorities.
5. Reaching the new summon source resets stale main focus, `ActionRadials.Tag`
   and tooltip and moves focus to the first native summon `VMHotBarSlot`.
   Normal resource/other mode selection returns when the native summon
   source becomes empty. The existing selected resource token need not be
   modified.

The resource tab row is unchanged while this temporary native overlay is
active. Availability/level/cost/validity are solely owned by BG3. The
installed-game source proves this direct `DCHotBar` binding and
`VMHotBarSlot` identity path; behavior after real summon switching
remains a **separate runtime acceptance gate**, not something CI can assert
from XAML. All other cross-catalog parity blockers (#134/#135) remain open.

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

## Automated native UI command audit (2026-10-08)

The installed Patch 8 keyboard and controller XAML contain 36 distinct command
names. These are independently inventoried and classified in
[the complete source audit](research/native-ui-command-parity-2026-10-08.md).
The corresponding manifest is
`docs/evidence/native-ui-command-audit-1.8.910.0.json`, checked on each
Validate CI run by `tools/audit-native-ui-commands.py`.

The auditor checks all available native provider/dispatch source seams, the
classification of every observed command, and—when supplied with an existing
read-only capture ZIP—checks both the pinned BG3 source hash and the exact
source command inventory. It **does not infer character-specific action
reachability** from a command name.

An additional eight native keyboard/gameplay UI commands are absent from CAM's
XAML (including switch weapon set, light source, melee/ranged selection and
default attack). These are known missing **direct UI transports**, not proof
that every gameplay effect is unavailable through native slots/global controls.
Treat actual missing actions as a separate runtime parity task.

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

## All-gameplay-capability preservation gate (#135)

Preserving all BG3 gameplay **capabilities** is a hard requirement, not
merely preserving the 36 native UI command names. Source-only equality
with keyboard `KeyboardHotBars[*].SlotList` does **not** imply
controller radial gameplay parity, because `SpellsAndActions`,
`Inventory.Slots`, passives, dynamic equipment, temporary actions,
recasts, mod-added resources and global gamepad controls form
independent reference sources.

The [machine-readable capability matrix](evidence/native-gameplay-capabilities.json)
lists **25 gameplay capability groups**, each with native source,
current CAM route, known status and acceptance gate. Statuses
`blocked`, `unverified` and `source-present` deliberately do not
mean `gameplay-verified`. In particular, the failed weapon-set hold
transport remains blocked. Mouse resize and user-requested removal
of radial layout editing are not gameplay omissions; essential B
cancellation/targeting nonetheless remains a capability group.

`tools/compare-runtime-gameplay.py` provides an **executable
identity-set** comparison, rather than a command-name comparison.
It consumes one read-only observation containing native keyboard +
controller playable slot identities, CAM identities and native
global controller capabilities for each captured game state.
It reports any native executable action absent from CAM, any
lost native global controller capability, incomplete observations,
unknown capability groups and game-version drift. Distinct
resources/upcast variants must have distinct native identities.
Duplicated appearances of the *same executable identity* in
multiple native providers are valid.

Run `python tools/compare-runtime-gameplay.py --self-test` without
game access to check that synthetic missing actions and global
controls **fail**. When a suitable dev-only, read-only runtime
probe is available, run
`python tools/compare-runtime-gameplay.py --observation <path> --json`
for its output. No such real observation is present today.
This checker does not introduce a Script Extender requirement
in the shipping PAK and cannot, on its own, capture game state.

**Full gameplay compatibility is not accepted** until actual native
runtime inventories can be compared across representative game
states and all blocked capabilities have proven BG3-backed routes.
See [issue #135](https://github.com/Vyachean/bg3-controller-action-menu/issues/135).

## Developer-only native action inventory snapshot

The existing early Script Extender probe previews only 10 entries from
a collection, and cannot establish BG3 action parity for real characters.
A new optional, **read-only** development module
`dev/script-extender/Lua/Client/GameplayInventoryProbe.lua`
collects the complete available sizes and a bounded, explicitly
truncation-marked scan of nine independent native source collections
plus CAM's live list/focus state. It never invokes BG3 action commands
or changes the shipping PAK.

`tools/analyze-gameplay-inventory.py` compares provider **counts**
and focus under explicit CAM mode, without pretending a raw radial
candidate is an executable `VMHotBarSlot`. CI synthetic fixtures
fail when a displayed provider loses a native entry or a report
incorrectly claims identity equivalence. Static CI cannot
validate that Script Extender's old Noesis API still works in the
user's Xbox App build, and this is not a new requirement for users.
See [dev inventory guide](development-gameplay-inventory.md).

The **full-gameplay acceptance gate remains open**: only a
source-proven, resource-aware runtime executable identity adapter
can feed `tools/compare-runtime-gameplay.py`. No visual,
command-name or count-only comparison is enough.

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
