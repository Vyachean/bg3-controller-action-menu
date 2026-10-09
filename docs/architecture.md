# Architecture

## Objective

Replace Baldur's Gate 3 controller radial browsing with a controller-first, automatically populated **resource-first action bar** while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

The shipping artifact is one self-contained ordinary BG3 `.pak`, with no Script Extender, DLL/native loader, or install-time game-file derivation.

## No configured-radial provider

The **Original Radials** tab introduced in #140 was rejected. The `ControllerHotBars` collection represents a player's configured layout and cannot be an automatic action-discovery source. CAM keeps one resource-first tab level, backed by verified native executable providers. Uncovered gameplay capabilities block acceptance in #135 rather than creating a fallback based on manually assigned original slots.

## Runtime composition

```text
native ActionRadials state/page
          |
          v
project-owned ActionRadialWidgetTemplate_P8
          |
          +-- dynamic resource tabs
          |     CurrentPlayer.UIData.ActionResourcesCostPreview
          |                 |
          |                 v
          |     FilterActionResourceCommand(selected preview)
          |                 |
          |                 v
          |          SingleHotBar.SlotList
          |          native VMHotBarSlot variants
          |
          +-- controller action grid
          |     adaptive LSGrid
          |     item-local ls:MoveFocus focus chrome
          |
          +-- native tooltip/focus lifecycle
                LocalFocus.DataContext
                     |
                     +--> ActionRadials.Tag
                     +--> CreateFocusedTooltipDataCommand
                     +--> HighlightResourcesCommand
                     +--> LSTooltip / ShowTooltipOnUIElementCommand
                     |
                     v
                UIAccept -> UseSlotCommand(slot)
```

There is no return to the rejected raw Common/Class/Passives source-tab UI and no secondary resource-filter layer. Items are allowed only through BG3's native ItemHotBar deck materialization. The top level remains a single controller cost/source sequence. Cantrips are the one proven zero-cost special provider and use BG3's own `FilterCantripsCommand` rather than a raw catalog. Resource previews are the primary provider, but they are not assumed to be a complete executable catalog; proven native non-resource providers may join that same sequence when needed to satisfy action parity.

## Evidence boundary

The current contract is based on the captured Xbox App game package `1.8.910.0`. Source hashes and consumed seams are pinned in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

Proven current facts include:

- page/state: `ActionRadials`;
- context: `HotBar`;
- executable cells are native `VMHotBarSlot` objects;
- `ActionResourcesCostPreview` exposes native `VMActionResourceCostPreview` resource entries;
- `FilterActionResourceCommand` accepts the selected preview;
- filtered/native nested choices are materialized as `SingleHotBar.SlotList`;
- `VMUpcast` is a supported native slot-content type;
- A uses `UseSlotCommand(ActionRadials.Tag)`;
- native focus tooltip/resource highlighting is available;
- B has BG3-owned nested-state commands.

Historical public dumps and older CAM type-tab experiments are context only.

## Action coverage completion gate

The canonical completeness contract is `docs/action-coverage.md`.

CAM is complete only when:

```text
(keyboard HotBar executable actions
 UNION
 radial-assignment gameplay candidates)
 MINUS radial-editing-only operations
    subset-of
CAM reachable executable actions
```

The reference catalogs and the execution catalog intentionally use different object shapes.
`SpellsAndActions`, `Inventory.Slots` and raw passive predicates are valid reference
evidence, but CAM still dispatches only native `VMHotBarSlot` values.

Current shipping providers are:

- `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList`;
- native Cantrips via `FilterCantripsCommand(h7d02199dg44ecg4a1egbcacg9cc1cec197b3) -> SingleHotBar.SlotList`;
- native Items via `SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList`;
- native metamagic via `FixedSideBar.SlotList`;
- `PassivesHotBar.SlotList`;
- grouped `KeyboardHotBars[*].SlotList` as a final native keyboard-HotBar coverage fallback;
- `SingleHotBar.SlotList` for native nested/upcast/variant/throw state.

Static keyboard-HotBar source coverage is now complete by construction through the native `KeyboardHotBars` fallback. The remaining correctness blocker is semantic parity with the independent radial-assignment catalog: free/no-resource, scroll/charge, temporary, recast and mod-added radial-only cases still need one combined runtime proof.

A future provider must be proven against the current installed game and materialize
executable `VMHotBarSlot` values. This requirement does not authorize raw source tabs,
manual action tables or string/icon classification.

## Explicit initial controller focus for Metamagic (0.0.103 candidate)

The operator's 0.0.101/0.0.102 runtime test confirmed the Metamagic
LB/RB provider enters the side region, but **the first concrete slot
has no initial controller focus**. The prior entry only wrote the
`CAM_ResetFirstFocusToken` and reselected index zero; selecting a
ListBoxItem is not sufficient proof of native controller focus
transfer between independent lists.

Both Metamagic LB/RB entry timers now also call BG3's existing
`ls:SetMoveFocusAction(TargetName=ActionRadials,
FocusElement=CAM_FixedSideBarList, DeferFocusAction=True)`
before the first-slot selection. The proven item-container selection
trigger still promotes the chosen concrete VMHotBarSlot into native
focus after that. This does **not** re-enable both list owners or
mutate the provider mode from a passive focus event.

Static testing verifies symmetric entry and preserved command
bindings, but a Noesis runtime check remains necessary to prove
the initial frame, tooltip and A dispatch.

## Metamagic vertical D-pad boundary (#155, source-level candidate)

In the v0.0.109 operator test, pressing Down beyond the final native
`FixedSideBar.SlotList` entry moved focus outside the metamagic list.
The fixed side rail is a **one-column** `LSGrid` with
`ActionUpEvent=UIUp` / `ActionDownEvent=UIDown`, nested in the
`CAM_FixedSideBarList` `LSListBox` consuming those same events through
`ActionPrevEvent` / `ActionNextEvent`. The preceding
`KeyboardNavigation.DirectionalNavigation=Contained` on that list did not
provide a cyclic last-to-first/first-to-last boundary.

The smallest test candidate uses the Noesis/WPF list-navigation
`DirectionalNavigation=Cycle` **on the sidebar list only**. It does not
add an `LSInputBinding`, consume D-pad events at the root, change
`LSGrid` directional dispatch, alter the focus owner, or replace the
native `VMHotBarSlot -> ActionRadials.Tag -> UseSlotCommand` route.
`HotBarList` keeps `Contained`; BG3's nested states still own its
existing focus handoff. Static checks pin both boundaries and reject
second input routes.

**Proof limit:** the captured XAML proves event wiring, not how BG3's
custom `LSGrid` handles its terminal coordinate at runtime. Therefore
a green package/structural test does not establish the observed bug is
fixed. Verify repeated Up/Down at both endpoints, tooltip/A identity and
LB/RB return together with nested-metamagic UX (#158) in the next
combined sorcerer milestone. Keep #155 open until that proof.

## Native metamagic side rail (0.0.99 candidate)

The installed 1.8.910.0 keyboard HotBar renders native `FixedSideBar`
**beside** the primary deck. CAM now composes:

```text
                   ActionRadials (one BG3 UseSlotCommand)
                             ^
                   ActionRadials.Tag (focused VMHotBarSlot)
                          /          \
             sidebar LocalFocus    HotBarList LocalFocus
                      |                      |
          FixedSideBar.SlotList       resource-filtered SingleHotBar.SlotList
                      |                      |
             one-column LSGrid          adaptive LSGrid
```

The FixedSideBar column is native and count-conditional; it is not a
synthetic list of metamagic spells. LB/RB retains the historical
Metamagic entry to focus this separate column without replacing
`HotBarList.ItemsSource`. Entering from Items/Passives re-applies the
BG3-owned selected resource filter to keep spells in the central grid.
The game supplies `Content.IsModified`, `Content.IsMetaMagic`,
`IsActive`, and `MetamagicActive` (controller state); CAM reuses
shared native effect templates without duplicating the game rules.

Nested variant/upcast/throw flows temporarily focus the central action
list without changing the selected Metamagic tab. On their exit, the
Metamagic provider **must reapply** BG3's selected resource filter to
restore the spell grid and then return focus to the first native
`FixedSideBar.SlotList` slot. Restoring `HotBarList.SelectedIndex`
instead is the old, incorrect pre-0.0.99 behavior. The ordinary
`SingleHotBar.SlotList.Count` nested-restoration trigger must skip
Metamagic so it does not steal focus from the side rail. While a nested
choice is active, a main-list focus change must not be confused with
D-pad navigation out of the side rail.

The native controller radial supplies **two** spell feedback signals:
`Content.IsModified=True` makes the positive modified-spell glow,
while `PlayerCharacterProperties.MetamagicActive=True` dims other
native `SlotType=Spell` cells for which `Content.IsModified=False`.
The resource-filtered main grid now consumes both BG3 properties,
without inventing a compatibility classifier or changing action
execution. `VMHotBarSlot.IsActive` may remain true after reopening
CAM if the game still considers the passive active; the UI must not
force-clear BG3-owned metamagic activation on close.

The research source audit is [here](research/metamagic-parity-2026-10-08.md).
Independent sidebar focus, native tooltip and B/nested transitions
are **not** game-verified merely because the XAML and package pass CI;
#125 remains open for a combined sorcerer acceptance run.

## v0.0.100 runtime rejection: exclusive focus ownership

The operator tested `0.0.100`: the Metamagic tab could not be entered,
LB/RB ordering/reset failed, and the sidebar had a permanent selector which
moved in parallel with the action grid. The cause is visible in the XAML:

- `CAM_FixedSideBarList.LocalFocusChanged` wrote
  `CAM_ProviderModeMarker.Tag=CAM_MetamagicModeToken` without a shoulder
  transition, overriding the tab-cycle state.
- `CAM_MainSelector` and `CAM_FixedSideBarSelector` were visible whenever
  their respective lists were visible, irrespective of ownership.
- Both lists remained enabled and could update `ActionRadials.Tag` and
  native tooltips through independent focus events.

**Corrected presentation contract**: `FixedSideBar.SlotList` stays
visible beside the main grid, but is controller-enabled only when
`CAM_ProviderModeMarker.Tag==CAM_MetamagicModeToken` **and none of BG3's
nested flags is active**. `HotBarList` is controller-disabled during
that state, but its spells remain visible. During a native nested
variant/upcast/throw selection, main-list focus temporarily returns to
BG3, and afterwards the existing nested-restore contract reselects
the sidebar.

Only explicit LB/RB resource/provider transitions may write
`CAM_ProviderModeMarker.Tag`. `LocalFocusChanged` is strictly a
presentation/command-identity event, guarded by the list's enabled
state and its non-null `VMHotBarSlot`. Each native `SelectorTemplate`
is visible only while its list owns controller focus; selectors may
not simply track `LSListBox.Visibility`.

This isolates the two visual regions without depending on unproven
cross-`LSListBox` D-pad focus transport. Physical spatial crossing
is deferred until it has its own current-game proof. The current
Metamagic selector is entered/exited via the existing LB/RB provider
row. No gameplay costs, compatibility or metamagic state are
reimplemented.

Static CI can reject the old feedback path but **cannot validate**
Noesis focus activation/timing or actual spell compatibility. Treat
this as a new candidate; #125 remains open pending operator game proof.

## Resource-first navigation

LB/RB traverses one cost/source row. Resource entries invoke `FilterActionResourceCommand`; proven special providers use Cantrips, ItemHotBar, FixedSideBar, PassivesHotBar, and finally a grouped native `KeyboardHotBars` fallback. The executable identity remains `VMHotBarSlot` in every case.

The resource tab list:

- is bound directly to `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- hides entries with no resource object or `MaxValue == 0`;
- keeps BG3 ordering;
- renders SpellSlot/WarlockSpellSlot levels from native level data;
- renders unknown/mod resources from native resource names, with `ActionResource.TypeId` as a fallback when the name is null;
- has no class-specific cases.

The product target additionally includes FREE/SCROLLS/charge-based source groups. Those require a proven BG3-owned executable-slot source and must not be synthesized from raw assignment objects.

## Execution and upcast boundary

CAM never executes a raw `VMCharacterAction`, `VMUpcast`, `VMItem`, or `VMPassive` directly. The executable unit is the surrounding `VMHotBarSlot`.

Resource-filtered `SingleHotBar.SlotList` is intentionally used because it may already materialize resource-specific execution variants. For example, a Spell Slot IV filter may expose `VMHotBarSlot` entries whose content represents IV-level upcasts.

This is a runtime proof boundary. If BG3 still opens `IsSelectingUpcastedSpell` after selecting an action, CAM retains the native nested `SingleHotBar` fallback rather than recreating upcast rules.

## ACTION / BONUS primary-resource policy

The target UX does not want slot spells duplicated into ACTION merely because they also consume one Action.

CAM therefore distinguishes:

- **product policy:** choose the meaningful limiting resource as the primary tab;
- **current implementation seam:** BG3's native resource filter.

If native Action/Bonus filters are broader than product policy, CAM may refine them only using a current BG3 property/predicate over executable native slots. No class/spell-name tables or heuristics are permitted.

## Selector paint gutter from installed BG3 (issue #130)

The installed Patch 8 `DataTemplates.xaml` defines
`SelectorTemplate` with `LSNineSliceImage Margin="-12"`.
A 104px icon in a 120px cell has only 8px inset, so the
leftmost native selector can paint 4px past the sidebar's outer
left boundary. Moving only the selector would break the
0.0.29-proven shared coordinate root with `CAM_FixedSideBarList`.

CAM therefore uses a **12px left inset** on the complete
`CAM_FixedSideBarRegion` inside the shared clipped
`CAM_ActionRowClip`. This repositions the list and its native
sibling selector together, keeping the source-defined border
within the row clip without changing the selector template,
slot sizes, controller navigation or 120px focus-scroll margin.
The extra 12px uses horizontal space from the adaptive main grid
and may alter its column count at narrow sizes; that risk is
explicitly retained for runtime verification.

Reference: `docs/research/native-ui-command-parity-2026-10-08.md`.

## Selector chrome and row-boundary clipping (issue #130)

The runtime test of 0.0.103 confirmed that per-viewport
`ClipToBounds=True` **stopped visual focus-frame jumping during
scrolling**, without any change to the logically focused item.
However, the built-in `SelectorTemplate` is wider than its
104×104 slot icon and was then cut off where the two independent
viewport clips met, as well as at their edges.

The 0.0.104 candidate retains the same 84px tab header and 850px
action row but makes **one shared row-level clip surface**
(`CAM_ActionRowClip`, `Grid.Row=1`, `Grid.ColumnSpan=2`) for
both the native FixedSideBar and main action grid. The individual
selector/list regions no longer clip independently at their
shared column boundary. Each 104-in-120 LSGrid has 16px of
vertical clearance within the same fixed row: the list and viewport
are 818px tall with 16px insets top and bottom. BG3's
`LocalFocusSelector -> SelectorTemplate` stays in the same
coordinate root as its owning list. Native scroll transport
`ActionRadials.FocusedElement -> LSScrollViewer.ScrollToElement`,
120px focus-follow margin, `LSGrid` columns and live
`VMHotBarSlot` identity remain unchanged.

The inset is derived from the **120px cell versus 104px icon
size**, not from an inspected native selector border geometry.
Consequently static tests prove shared clipping and clearance
structure but cannot guarantee the complete ring is visible on all
edges. A combined game check remains necessary, including first
and last visible cells; never claim a perfect visual fix from CI.

## Metamagic entry wake uses native LocalFocus (issue #125)

Runtime v0.0.103 showed a native sidebar focus frame after LB/RB,
but no tooltip and no executable A target. A visible selector only
means `LocalFocus` can be rendered; it does not prove
`ActionRadials.Tag` was refreshed. The main `HotBarList`
already has a **proven** 70ms `SelectionChanged` wake after
programmatic selection, to publish `LocalFocus.DataContext`
into the native tooltip lifecycle and `ActionRadials.Tag`
even when `LocalFocusChanged` did not fire.

`CAM_FixedSideBarList` lacked that wake. It now mirrors
the same native `SelectionChanged` transition, guarded by
active Metamagic provider mode, enabled sidebar and a
non-null `LocalFocus.DataContext`. It publishes the exact
BG3 `VMHotBarSlot` rather than fabricating a slot from
`SelectedItem`. The explicit LB/RB `SetMoveFocusAction`
and selected concrete cell handoff remain. Any lack of a
real `LocalFocus` after that needs separate engine proof,
not a fake tooltip or unconditional UseSlot dispatch.

## Controller scrolling

The action grid follows the same current Patch 8 controller scroll transport as the
native radial:

```text
ActionRadials.FocusedElement
        |
        v
LSScrollViewer.ScrollToElement
```

This is derived from controller focus rather than `SelectedIndex` or a CAM-owned
scroll offset. The scroll target must therefore stay synchronized with the same native
focus used for tooltip and A dispatch.

## Tooltip

CAM has no custom Live Details panel.

The ordinary native tooltip is the details surface. On action focus:

- clear stale `ActionRadials.Tag`;
- after the captured delay, copy the focused `VMHotBarSlot` to `ActionRadials.Tag`;
- call `CreateFocusedTooltipDataCommand(slot)`;
- call `HighlightResourcesCommand(slot)`;
- show an `LSTooltip` whose content is `VMHotBarSlot.Content`.

## B / nested state

Resource filtering is the top-level browsing state, so a populated `SingleHotBar.SlotList` must not by itself make B behave as a nested-back action.

Top-level B closes CAM when no BG3 nested variant/upcast/throw state is active. When BG3 opens a real nested state such as `IsShowingAContainerWithVariants`, `IsSelectingUpcastedSpell`, or `IsShowingItemsToThrow`, B retains the native nested cancellation behavior.

## Rejected data paths

Do not use these as direct execution catalogs:

- `PlayerCharacterProperties.SpellsAndActions`;
- `Inventory.Slots`;
- raw passive collections;
- user-configured `ControllerHotBars`.

They may provide research evidence, but dispatch remains native `VMHotBarSlot`.

## Self-contained package boundary

Runtime source remains `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`.

The release PAK contains project-owned runtime resources only. Normal installation does not read `Game.pak`, run LSLib, generate XAML, or rebuild a PAK locally.

## Proof boundary

CI can prove:

- resource-first XAML is present;
- old type tabs/deck commands are absent from runtime;
- resource tabs bind the native preview collection;
- selection drives `FilterActionResourceCommand`;
- grid dispatches only native `VMHotBarSlot` entries from `SingleHotBar.SlotList`;
- native tooltip/A/nested-state seams remain;
- package and installer boundaries are intact.

CI cannot prove the semantic contents BG3 puts into each resource-filtered `SingleHotBar`. That requires one combined milestone game run after green package proof.


## Rejected 0.0.49 correction

The 0.0.49 attempt to solve upcast projection, nested-filter recovery, focus/scrolling, tab viewport behavior, and weapon shortcuts in one XAML change regressed the entire interaction model. In-game, tabs became unpredictable and delayed.

The runtime was therefore rolled back to the 0.0.48 architecture. The following defects were open at that rollback point and were then addressed or re-evaluated in isolated later revisions:

- spell-slot tabs show the base spell and A opens native upcast selection;
- returning from nested upcast/throw can leave the selected resource grid empty until a tab change;
- grid focus has invisible transitions;
- lower grid rows do not scroll into view;
- selector position is offset;
- resource-tab viewport shows too few tabs and does not follow selection;
- Toggle Weapon Set hint is present but ineffective.

Do not use re-entrant filter commands or multiple overlapping `UIAccept` consumers to solve these.


## Single-list controller architecture

The previous resource-first implementation retained three controller-list surfaces: an outer `HotBarList`, a nested `CAM_FilteredSlotList`, and a separate `SingleBar` for BG3 nested state. That composition is rejected as unnecessary duplication.

The target controller path is now:

```text
ActionResourcesCostPreview
        |
        v
FilterActionResourceCommand(selected resource)
        |
        v
SingleHotBar.SlotList
        |
        v
HotBarList
  -> CAM_ActionGridPanel
  -> item-local MoveFocus focus chrome
  -> native tooltip
  -> ScrollViewer
  -> 70 ms ActionRadials.Tag handoff
        |
        v
UseSlotCommand(ActionRadials.Tag)
```

`SingleHotBar.SlotList` is also the BG3-owned collection for nested container/upcast/throw state. CAM therefore does not switch to a second list when those states activate. The collection changes underneath the same `HotBarList`; focus may be explicitly returned to that same list, but no second controller focus tree is created.

This reduces CAM-owned state to presentation plus the selected resource filter. Gameplay rules and nested-state ownership remain entirely in BG3.


## Historical viewport correction after single-list runtime proof (superseded)

The one-list architecture is retained. This section records the intermediate 0.0.56–0.0.57 viewport correction. It is not the current presentation contract; the selectorless adaptive section below supersedes its fixed viewport and detached-selector requirements.

The corrected presentation model is:

```text
wide resource header
  CAM_ResourceTabs
  + AutoScrollBehavior(SelectedIndex)
          |
          v
resource SelectionChanged
  -> hide stale CAM_MainSelector
  -> FilterActionResourceCommand
  -> focus HotBarList

action viewport: exactly 800 x 850
  HotBarList
  CAM_MainSelector
  (same coordinate root)
          |
          v
CAM_ActionGridPanel
  scrolling enabled
  ScrollViewer.CanContentScroll = True
```

The captured assignment grid uses `DisableScrolling=True` because its child grids live under a separate outer scrolling list. That flag does not belong on CAM's direct single-list items panel.

The captured ModBrowser controller UI supplies the native tab-row pattern used here: `AutoScrollBehavior` tracks `SelectedIndex` and brings the selected item into view without moving D-pad focus into the tab row.


## Adaptive presentation with ActionRadials local-focus ownership

0.0.58 proved that the SpellBook grid pattern cannot replace the ActionRadials focus contract wholesale. Removing `LocalFocusSelector` made grid navigation stop and left page-level A without a valid `ActionRadials.Tag`, because the existing dispatch lifecycle is explicitly driven by `HotBarList.LocalFocus.DataContext`.

The corrected composition separates **logical focus ownership** from **focus presentation**:

```text
HotBarList : SingleHotBar.SlotList
  |
  +-- LocalFocusSelector -> CAM_LogicalFocusAnchor
  |     visible in layout, Opacity = 0
  |     owns no visible selector chrome
  |
  +-- ScrollViewer (pixel scrolling)
  |     VerticalScrollOffsetMargin = 120
  |
  +-- CAM_ActionGridPanel
        Columns = floor(ScrollContentPresenter.ActualWidth / 120)
        |
        +-- CAM_ActionGridSlotContainer
              focus chrome is local to the item
```

The invisible selector anchor preserves the captured ActionRadials/assignment `LSListBox.LocalFocus` machinery. 0.0.59 runtime proof shows that this logical focus is correct: tooltip and A follow navigation. The attached `ls:MoveFocus.IsFocused` state does not follow that logical focus in this hybrid composition, so it is not a valid visible-focus source.

On every `HotBarList.LocalFocusChanged`, CAM mirrors `LocalFocus.DataContext` into `HotBarList.SelectedItem`. The cell template renders focus from `ListBoxItem.IsSelected`. This creates one focus identity across navigation, tooltip/highlight, `ActionRadials.Tag`, A dispatch and visible chrome without making the invisible selector visible.

The current captured keyboard HotBar also confirms that `ActionResourcesCostPreview` is the game's own resource-filter button source. CAM keeps that source and `FilterActionResourceCommand`. Generic resource names are not given an arbitrary per-tab maximum width; overflow is handled by the bounded horizontal tab viewport and selected-index auto-scroll. Null/empty generic names still fall back to `ActionResource.TypeId`.

SpellSlot/WarlockSpellSlot are not generic text tabs. The current HotBar renderer presents their level with an `Image` using `RomanNumeralLevelImage` and `DataContext="{Binding ActionResource}"`; CAM reuses that exact presentation seam. MaxValue=0 resources remain hidden exactly as native HotBar does.

The custom `Toggle weapon set` shortcut is not part of this focus path. Repeated runtime attempts have shown no reliable ActionRadials transport, so CAM does not bind or advertise it until a proven native seam exists.


### 0.0.61 focus-chrome ownership and tab wrap

0.0.60 runtime proof separates the two action-focus visuals. `IsSelected` now follows `LocalFocus.DataContext` correctly, while the inherited `FocusVisualStyle` remains attached to the physically focused first cell. CAM therefore disables the item `FocusVisualStyle` and keeps only the selection-driven `CAM_CellFocus` overlay.

A resource switch replaces/refilters `SingleHotBar.SlotList`. Because the first logical slot may be implied before another `LocalFocusChanged`, CAM re-establishes visual selection at index 0 after the resource selection settles, then defers focus back to the same `HotBarList`. This is presentation/focus restoration only; `ActionRadials.Tag` and A still come from the existing native local-focus lifecycle.

For the resource strip, native-style shoulder cycling now uses `SelectNextListBoxItem ForceSelect=True ForceMode=Cycle`. The existing `AutoScrollBehavior(SelectedIndex, BringSelectionIntoView=True)` remains the sole scroll-follow mechanism; forcing selection ensures the last→first wrap emits the selection transition it needs.


### 0.0.62 — LocalFocus reset is the resource-switch boundary

0.0.61 demonstrated that `SelectedIndex` is not a controller-focus primitive. It can paint the first item while `HotBarList.LocalFocus` still points to the previous resource tab's slot. That splits visible selection, navigation, tooltip and A dispatch and is especially visible on one-item tabs.

The resource-switch lifecycle therefore resets the native focus owner itself:

```text
CAM_ResourceTabs.SelectionChanged
  -> ActionRadials.Tag = null
  -> HotBarList.SelectedItem = null
  -> HotBarList.LocalFocus = null
  -> ClearResourceHighlightsCommand
  -> FilterActionResourceCommand(selected preview)
  -> SetMoveFocusAction(ActionRadials -> HotBarList, deferred)
        |
        v
HotBarList.LocalFocusChanged
  -> SelectedItem = LocalFocus.DataContext
  -> tooltip/highlights
  -> 70 ms ActionRadials.Tag = LocalFocus.DataContext
```

This follows the native ActionRadials pattern that explicitly clears an LSListBox `LocalFocus` when relinquishing/resetting focus. No CAM-selected index is allowed to stand in for local focus.

The 0.0.61 `ForceSelect=True` shoulder workaround is removed because it forces selection of collapsed native previews, including `MaxValue == 0` entries, creating invisible tabs. Cycling remains `ForceMode=Cycle` only.

For tab-strip scrolling, `AutoScrollBehavior.ScrollIntoView` tracks `SelectedItem` instead of `SelectedIndex`. BG3's own AutoScrollBehavior accepts element objects (for example ActionRadials `FocusedElement`); using the selected preview object removes the special index-0 failure when wrapping back to the first resource.

Visible focus chrome is still independent from the invisible logical selector anchor, but it is a two-layer item-local presentation: translucent fill plus opaque border frame. Both are driven by the same `ListBoxItem.IsSelected` that mirrors `LocalFocus.DataContext`.


### 0.0.63 — invalidate the focus graph, not only LocalFocus

0.0.62 proved that `LocalFocus=null` clears the list-owned focused slot but does not clear the widget's cached directional focus geometry. Re-entering the refiltered list can therefore resume the previous tab's grid coordinate.

BG3's own ActionRadials invalidates focus when radial contents are created or removed. CAM now uses the same boundary after resource filtering:

```text
resource SelectionChanged
  -> clear Tag / SelectedItem / LocalFocus
  -> FilterActionResourceCommand(selected preview)
  -> SetMoveFocusAction(ActionRadials, InvalidateFocus=True)
  -> SetMoveFocusAction(ActionRadials -> HotBarList, DeferFocusAction=True)
       |
       v
CAM_ActionGridPanel AlwaysSelectFirst=True
       |
       v
first real VMHotBarSlot
       |
       v
LocalFocusChanged -> selection / tooltip / highlights / A target
```

Only `AlwaysSelectFirst` is borrowed from the captured SpellBook `LSGrid` pattern. `UseWidgetNavigation` and `ls:MoveFocus.InternalFocusable` remain forbidden because 0.0.58 proved that transplanting that whole focus tree breaks ActionRadials dispatch.

The action grid also sets `ExtendedRows=False`. CAM has no executable meaning for generated empty coordinates; focus must stay on actual list items rather than requiring synthetic empty-cell chrome.

The resource strip remains bounded and uses the native `AutoScrollBehavior`, but now requests `ScrollTo="Center"` while following `SelectedItem`. This keeps the selected left/right edge tab fully inside the viewport without introducing manual scroll offsets.


### 0.0.64 — selected container is an entry pointer; LocalFocus is the live owner

The 0.0.63 runtime result rejects widget-level invalidation and LSGrid entry flags as a way to establish the first ActionRadials slot. The useful positive evidence is the combination of 0.0.29 and 0.0.61.

0.0.29 proved this focus presentation in-game:

```text
shared focus root
  +-- LSListBox
  |     LocalFocusSelector -> Selector
  |     ItemsPanel -> LSGrid(... EmptyCellTemplate ...)
  +-- Selector
        Template = native SelectorTemplate
```

0.0.61 separately proved that delayed `SelectedIndex=0` correctly identifies the first cell after `FilterActionResourceCommand`; its defect was stopping at selection rather than handing focus to that concrete container.

The resource-switch path is now:

```text
CAM_ResourceTabs.SelectionChanged
  -> ActionRadials.Tag = null
  -> HotBarList.SelectedIndex = -1
  -> ClearResourceHighlightsCommand
  -> FilterActionResourceCommand(selected resource)
  -> 70 ms
  -> HotBarList.Tag = CAM_ResetFirstFocus
  -> HotBarList.SelectedIndex = 0
       |
       v
first ListBoxItem IsSelected=True + reset token
  -> SetMoveFocusAction(ActionRadials -> that ListBoxItem)
  -> clear reset token
       |
       v
HotBarList.LocalFocusChanged
  -> native selector moves
  -> tooltip/resource highlight lifecycle
  -> 70 ms ActionRadials.Tag = LocalFocus.DataContext
```

`SelectedIndex` is therefore not a second live focus model. It is only a one-shot lookup of the first realized item after a data-filter transition. During normal navigation CAM does not write `SelectedItem` from `LocalFocus`.

The selector shares `CAM_ActionViewport` with `HotBarList`, matching the 0.0.29 focus-origin correction. This is required because the selector is also the only focus surface capable of representing LSGrid empty-cell positions, where no `ListBoxItem` exists.

The resource strip uses `AutoScrollBehavior.ScrollIntoView=SelectedIndex` plus `ScrollTo=Center`. BG3 publicly uses `SelectedIndex` as the numeric AutoScroll target and `FocusedElement` as the element target; a VM `SelectedItem` is neither.


### 0.0.65 — complete entry presentation; let selection own tab scrolling

0.0.64 proves the concrete first-item focus handoff is the correct resource-entry boundary. The remaining tooltip defect is presentation/state completion, not focus establishment.

After `FilterActionResourceCommand` settles, the existing entry timer already sets `HotBarList.SelectedIndex=0`. At that exact boundary, `SelectedItem` is a valid one-shot pointer to the same first `VMHotBarSlot` that is handed to `SetMoveFocusAction`.

0.0.65 completes the initial state from that slot:

```text
resource SelectionChanged
  -> filter once
  -> 70 ms
  -> arm concrete-focus token
  -> SelectedIndex = 0
  -> CAM_ActionTooltip.Content = SelectedItem.Content
  -> ShowTooltipOnUIElementCommand(HotBarList)
  -> ActionRadials.Tag = SelectedItem
  -> CreateFocusedTooltipDataCommand(SelectedItem)
  -> HighlightResourcesCommand(SelectedItem)
       |
       v
selected ListBoxItem -> SetMoveFocusAction(that concrete item)
```

This is entry-only. Once the player moves, the existing `LocalFocusChanged` path remains authoritative for tooltip, Tag, highlight and A dispatch.

For resource tabs, 0.0.62–0.0.64 prove that explicit `AutoScrollBehavior.ScrollIntoView` targets do not reliably reveal the selected left edge. BG3 also exposes a selection-driven mode:

```xml
<ls:AutoScrollBehavior BringSelectionIntoView="True"/>
```

That mode is now used without `ScrollIntoView` or `ScrollTo`. The behavior follows the selected ListBox container directly, avoiding index/VM target interpretation and avoiding manual scroll offsets.


### 0.0.66 — LocalFocus reset, element-based tab scrolling, nested-return restoration

0.0.65 exposed a split-brain state: resource entry selected index 0 and populated tooltip/Tag from `SelectedItem`, while the visible selector could remain at another `LocalFocus` coordinate. That state is invalid because controller execution is defined by `LocalFocus.DataContext`.

The resource-switch lifecycle is therefore:

```text
resource SelectionChanged
  -> clear ActionRadials.Tag / tooltip / highlights
  -> HotBarList.LocalFocus = null
  -> HotBarList.SelectedIndex = -1
  -> FilterActionResourceCommand(selected resource)
  -> 70 ms
  -> arm CAM_ResetFirstFocusToken
  -> SelectedIndex = 0
       |
       v
selected concrete ListBoxItem
  -> SetMoveFocusAction(that ListBoxItem)
       |
       v
fresh HotBarList.LocalFocusChanged
  -> tooltip = LocalFocus.DataContext.Content
  -> ActionRadials.Tag = LocalFocus.DataContext
  -> CreateFocusedTooltipDataCommand(LocalFocus.DataContext)
  -> HighlightResourcesCommand(LocalFocus.DataContext)
```

There is no resource-entry tooltip or A state sourced from `SelectedItem`.

#### Resource strip scrolling

The installed Patch 8 radial proves the native scroll contract is UI-element based:

```xml
<ls:LSScrollViewer
  ls:LSScrollViewer.ScrollToElement="{Binding FocusedElement, ...}" />
```

CAM shoulder tabs do not own controller focus, so they cannot reuse `ActionRadials.FocusedElement`. Instead the selected tab container publishes its concrete `ListBoxItem` UIElement to `CAM_ResourceTabs.Tag`, and the resource `LSScrollViewer.ScrollToElement` follows that element. The scroll target is therefore neither the VM nor an integer index.

#### Returning from nested actions

`SingleHotBar.SlotList` has two meanings in CAM:
1. top-level result of `FilterActionResourceCommand`;
2. native nested/upcast/container result.

`ClearSingleHotbarCommand` correctly clears meaning (2), but cannot know that CAM then needs meaning (1) reconstructed. CAM records whether one of the native nested flags actually became true. On nested cancel, after all of these flags return false:
- `IsShowingAContainerWithVariants`;
- `IsSelectingUpcastedSpell`;
- `IsShowingItemsToThrow`;

CAM re-applies `FilterActionResourceCommand(CAM_ResourceTabs.SelectedItem)`, then re-enters the same LocalFocus reset/concrete-first-item path. The marker is not gameplay state; it is only a guard preventing top-level B/CloseWidget from invoking resource restoration.


### 0.0.67 — focus-data presentation trigger and template-safe tab scrolling

0.0.66 establishes the correct action focus identity and nested-return reconstruction, but reveals that `LocalFocusChanged` alone is not sufficient as a presentation signal.

A resource refilter or nested return can leave/reuse the same focus container while changing its `DataContext`. In that case:
- the selector can already be correct;
- `LocalFocus.DataContext` can already be the correct `VMHotBarSlot`;
- but `LocalFocusChanged` need not fire, so tooltip presentation is not refreshed.

The presentation lifecycle therefore becomes:

```text
HotBarList.LocalFocus.DataContext changes
  -> CAM_ActionTooltip.Content = LocalFocus.DataContext.Content
  -> ShowTooltipOnUIElementCommand(HotBarList) / hide on null
  -> ActionRadials.Tag = LocalFocus.DataContext
  -> CreateFocusedTooltipDataCommand(LocalFocus.DataContext)
  -> HighlightResourcesCommand(LocalFocus.DataContext)
```

The existing `LocalFocusChanged` event is retained only for the controller hover sound. This preserves `LocalFocus.DataContext` as the single source of truth while covering both ordinary D-pad motion and VM replacement under a reused focus container.

#### Resource-tab scroll namescope

The selected resource item already publishes its concrete `ListBoxItem` UIElement to `CAM_ResourceTabs.Tag`. The remaining problem in 0.0.66 is the binding site:

```xml
<!-- invalid/unreliable across ControlTemplate namescope -->
ls:LSScrollViewer.ScrollToElement="{Binding Tag, ElementName=CAM_ResourceTabs}"
```

Inside a `ControlTemplate`, the reliable source is the templated list itself:

```xml
<ls:LSScrollViewer
  ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}" />
```

This keeps the Patch 8-native UIElement scroll contract while removing the cross-namescope lookup.


### 0.0.68 — widget-focus wake-up, LocalFocus authority, wrapped resource row

0.0.67 proves that changing the binding form of resource scrolling and watching a nested LocalFocus binding are not effective runtime seams in this ActionRadials composition.

#### Action entry

CAM now separates the **state authority** from the **event that wakes presentation**:

```text
programmatic SetMoveFocusAction
        |
        v
ActionRadials.FocusedElement changes
        |
        v
read HotBarList.LocalFocus.DataContext
        |
        +--> CAM_ActionTooltip.Content
        +--> ShowTooltipOnUIElementCommand(HotBarList)
        +--> ActionRadials.Tag
        +--> CreateFocusedTooltipDataCommand
        +--> HighlightResourcesCommand

ordinary D-pad
        |
        v
HotBarList.LocalFocusChanged
        |
        +--> same LocalFocus.DataContext lifecycle
```

`FocusedElement` is only the wake-up signal for programmatic entry. It is not an alternate action identity.

#### Resource row

Horizontal scroll is removed. BG3's own action-resource UI uses `ls:AlignableWrapPanel`; CAM adopts that presentation family for `VMActionResourceCostPreview`.

The resource list remains one logical sequence controlled by LB/RB. When natural tab widths exceed the available width, the same sequence wraps to another visual row. Because every realized tab is laid out inside the bounded resource area, there is no scroll offset to synchronize and no selected edge tab can remain outside a scrolled viewport.

The action viewport remains 850px high. The resource header becomes auto-sized, so wrapping does not steal action-grid height.


### 0.0.69 — native resource icons, Passives mode, item counts, explicit first-cell entry

The top-level controller navigation now models what the player actually needs in combat: compact cost/resource choices plus Passives.

#### Resource visual contract

Each native `VMActionResourceCostPreview` uses the same presentation family as Patch 8 keyboard HotBar:

```text
VMActionResourceCostPreview
  -> 72x72 resource box
  -> LSActionPointResources
       DataContext = ActionResource
       Style       = ActionResourcesTemplateSelector
       Max          = MaxValue
       Available    = Value
       Highlighted  = Cost
  -> RomanNumeralLevelImage for spell-slot types
```

This replaces both text labels and wrapped rows.

#### Passives

Passives are not reconstructed from raw `Stats.Passives`. The tab uses the already-proven executable source:

```text
PlayerCharacterProperties.PassivesHotBar.SlotList
  -> VMHotBarSlot
  -> same HotBarList
  -> same selector / tooltip / UIAccept -> UseSlotCommand
```

`CAM_ResourceTabs.Tag = CAM_PassivesModeToken` is the mode state. It is presentation-only because the current capture proves `PassivesHotBar.SlotList` but does not prove a dedicated BG3 passives-deck toggle command/property. Resource selection clears the token; entering Passives sets it. `HotBarList.ItemsSource` switches declaratively from `SingleHotBar.SlotList` to `PassivesHotBar.SlotList`.

#### Item quantity

Patch 8 `HotBarSlotStyle` proves that a `VMHotBarSlot` with `SlotType=Item` presents `slot.Content` as a `VMItem` through native `Template.Item`. The template itself owns quantity and item chrome:

```text
VMHotBarSlot.Content : VMItem
  -> Template.Item
  -> VMItem.Count
  -> CountToVisibilityConverter
  -> AbbreviateNumberConverter
  -> ItemAmountTextStyle
```

CAM does not duplicate that overlay at the slot level.

#### Entry focus / tooltip

Tab changes are now an explicit first-cell transition:

```text
tab transition
  -> hide stale tooltip
  -> ActionRadials.Tag = null
  -> HotBarList.LocalFocus = null
  -> HotBarList.SelectedIndex = -1
  -> change source/filter
  -> settle
  -> SelectedIndex = 0
  -> concrete selected ListBoxItem receives SetMoveFocusAction
  -> entry-only tooltip/Tag/highlight = SelectedItem
  -> normal LocalFocusChanged owns all later navigation
```

This is deliberately different from 0.0.65: the stale LocalFocus is cleared before the first selected item becomes an entry source.


### 0.0.70 — HotBar resource icons and LocalFocus-only entry state

0.0.69 runtime showed that selection and controller focus can still diverge at a top-level tab transition. It also showed that the resource-point control used in 0.0.69 is not the visual icon used by the keyboard/mouse HotBar.

#### Resource visual contract

```text
VMActionResourceCostPreview
  -> 72x72 resource box
  -> Image
       DataContext = ActionResource
       Style       = SectionImageStyle
       TypeId      -> ActionResourceIconsPath / missing-resource icon path
  -> RomanNumeralLevelImage for SpellSlot / WarlockSpellSlot
```

`LSActionPointResources` remains a valid BG3 resource-count/point renderer elsewhere, but it is not the resource-tab icon renderer.

#### Entry focus contract

Programmatic tab entry is two separate facts: list selection identifies the intended first item; `LocalFocus` proves where controller navigation actually landed. Only the second fact may drive action state.

```text
top-level tab transition
  -> clear HotBarList.LocalFocus + SelectedIndex + stale tooltip/A state
  -> filter/switch ItemsSource
  -> settle
  -> HotBarList.Tag = CAM_ResetFirstFocus
  -> SelectedIndex = 0
  -> selected concrete ListBoxItem
       -> SetMoveFocusAction(DeferFocusAction=True)
       -> HotBarList.Tag = null
  -> delayed HotBarList.SelectionChanged wake
       -> read LocalFocus.DataContext only
       -> tooltip / highlights / ActionRadials.Tag
```

The wake-up does not use `SelectedItem`. If deferred focus has not produced a non-null `LocalFocus.DataContext`, the menu must not synthesize a first-cell tooltip or A target. The native `LocalFocusSelector` remains the visible focus source.


### 0.0.71 — exact HotBar resource renderer and non-reentrant Passives return

0.0.70 keeps the correct resource-first data model but uses the wrong visual seam and lets one shoulder-button click cross two tab-state machines.

#### Native resource visual

The keyboard HotBar resource button is reproduced as a presentation unit rather than reduced to a generic image:

```text
VMActionResourceCostPreview
  -> 72px resource box
  -> LSActionPointResources
       MaxActionPoints         = MaxValue
       AvailableActionPoints   = Value
       HighlightedActionPoints = Cost
       DataContext             = ActionResource
       Style                   = ActionResourcesTemplateSelector
  -> RomanNumeralLevelImage for SpellSlot / WarlockSpellSlot
  -> ResourcesNumeralDisplay for counts larger than the native point group
```

`SectionImageStyle` is removed from the tab renderer. It belongs to other native resource-icon surfaces, not the keyboard HotBar filter button itself.

#### Passives boundary

Passives is not a member of `ActionResourcesCostPreview`, so its transition must not masquerade as a normal list cycle within the same input event.

```text
Passives --RB--> selected resource 0
  click:
    clear stale action presentation
    filter resource 0 while HotBarList still shows Passives
    keep Passives mode + CAM_TabReturnFirstToken
  +70 ms:
    leave Passives mode
    HotBarList switches to prepared SingleHotBar.SlotList
    select/focus first concrete action

Passives --LB--> last resource
  click:
    clear stale action presentation
    keep Passives mode
    CAM_TabReturnLastToken
    move resource-list selection 0 -> last
  resource SelectionChanged:
    filter selected last resource while HotBarList still shows Passives
  +90 ms:
    leave Passives mode
    switch to prepared SingleHotBar.SlotList
    select/focus first concrete action
```

Because passive mode remains set during the originating click, ordinary resource LB/RB handlers cannot become newly eligible halfway through that same event.


### 0.0.72 — resource-tab chrome and native item quantity

0.0.71 runtime shows that two presentation details must be corrected without changing the resource-first architecture.

#### Resource-tab visual contract

```text
VMActionResourceCostPreview
  -> normal resource:
       box_resource_empty / box_resource_d / box_resource_h / box_resource_missing
       LSActionPointResources(ActionResourcesTemplateSelector)
  -> SpellSlot / WarlockSpellSlot:
       box_resourceNum_empty / box_resourceNum_d / box_resourceNum_h / box_resourceNum_missing
       LSActionPointResources(ActionResourcesTemplateSelector)
       RomanNumeralLevelImage
```

CAM does **not** add a resource-value text overlay to top-level tabs. Persistent selected state reuses the HotBar highlight chrome; it does not invent another tab visual language.

#### Item-cell presentation contract

Patch 8 `HotBarSlotStyle` proves that an item slot's content is `VMItem` and delegates item visuals to native inventory templates. CAM keeps the outer `VMHotBarSlot` as the executable/focus object but renders its item content through those same templates:

```text
VMHotBarSlot (SlotType=Item)
  -> Content : VMItem
  -> ordinary      Template.Item
       -> VMItem.Count
       -> CountToVisibilityConverter(>1)
       -> AbbreviateNumberConverter
       -> ItemAmountTextStyle
  -> equipment     Template.ItemEquipment
  -> item container Template.ItemContainer
```

Non-item cells retain the 104x104 `Content.Icon` assignment-style surface. No separate CAM quantity overlay remains.


### 0.0.73 — HotBar filter chrome, not resource-bar chrome

0.0.72 proves the resource-first execution model and native item rendering, but it still uses the wrong visual family for top-level tabs. The keyboard/mouse HotBar has two separate concepts:

- **action-resource bar** — `box_resource_*` / `LSActionPointResources`, used to display resources;
- **filter buttons** — `FilterButton` / `ActiveFilterButton`, using `btn_pil_*` nine-slice chrome and the active top marker.

CAM tabs are filters, so their outer presentation must use the second family.

```text
VMActionResourceCostPreview
  -> HotBar filter chrome
       normal   btn_pil_d
       selected btn_pil_active_d
       disabled btn_pil_disabled
       marker   btn_pil_inactivemod_d + ActiveModArrow
       Slices=36
       Padding=10
       item Margin=-4,0
  -> compact resource identity
       LSActionPointResources(ActionResourcesTemplateSelector)
       RomanNumeralLevelImage for SpellSlot/WarlockSpellSlot
```

The `box_resource_*` and `box_resourceNum_*` assets are no longer part of the top-level tab chrome. Resource-value text remains absent. Passives uses the same filter chrome so the full LB/RB sequence reads as one native filter row.


### 0.0.77 — native ActionResourcesList item, controller selection outside presentation

Controller selection and resource presentation are separate layers:

```text
CAM_ResourceTabs : LSListBox
  selection -> FilterActionResourceCommand
  no selection visual
  |
  +-- ItemContainerStyle
  |     transparent ContentPresenter only
  |     Margin=-4,0,-4,0
  |
  +-- ItemTemplate = captured ActionResourcesList visual
        LSButton Padding=0 Margin=4,-10,4,10
          Root Width=72
            box_resource_* layers
            LSActionPointResources
              MaxActionPoints=MaxValue
              AvailableActionPoints=Value
              HighlightedActionPoints=Cost
              DataContext=ActionResource
              MaxActionPointGroups=0
              SmallActionPointSize=24
              ActionPointGroupSize=56
              ActionResourcesTemplateSelector
            RomanNumeralLevelImage
            ResourcesNumeralDisplay
        visual triggers:
          Root.Tag=SpellSlot -> box_resourceNum_*
          IsMouseOver -> highlighted box
          Value=0 -> missing box
          BardicInspiration -> native numeral adjustment
```

LB/RB changes only selection/filter semantics. Native resource content does not know whether its outer controller list item is selected.


## Resource-strip overflow — 0.0.85 architecture

The controller row remains one logical LB/RB sequence, but dynamic native resources and fixed special providers have different presentation constraints. Special providers (Cantrips, Items, Metamagic, Passives, All) stay outside the scroll owner and therefore remain visible. Only `CAM_ResourceTabs` is a bounded horizontal viewport.

Provider identity and scroll transport are deliberately separate:

```text
CAM_ProviderModeMarker.Tag
  -> resource / Cantrips / Items / Metamagic / Passives / All mode

CAM_ResourceTabs.Tag
  -> selected concrete resource ListBoxItem UIElement
  -> LSScrollViewer.ScrollToElement
  -> TargetPosition
  -> TargetPositionChanged
  -> HorizontalScrollOffset = TargetPosition
```

The final two steps are copied from the current Patch 8 controller radial horizontal scroller. They are the material difference from the rejected 0.0.66–0.0.67 resource-strip experiments, which supplied a scroll target but did not commit the computed `TargetPosition`. `AutoScrollBehavior`, explicit SelectedIndex/SelectedItem targets, wrapped resource rows and hand-maintained numeric offsets remain rejected.


## Controller shortcut evidence boundary

Weapon-set switching is outside the action-catalog architecture and remains disabled until native input transport is proven. The grid keeps ordinary `UILeft` navigation. The read-only developer capture owns discovery: schema-v3 `hotbar-coverage-contract.json` records all XAML tags containing the weapon-set command/event/style/input symbols and their relevant transport attributes. CAM runtime must not add a shortcut merely because a command or visual hint exists; the evidence must show a repeatable ActionRadials-compatible transport that does not steal short grid-left input.


## 0.0.87 — development entry back to install

After complete schema-v3 readback (see `docs/research/schema-v3-capture-2026-10-08.md`), no gameplay/XAML change is made by the installer milestone. The fixed VBS downloads release-controlled `dev-entry.ps1`, which now delegates to proven `install-latest.ps1`, validates its explicit `install-status.txt` and version, and surfaces `dev-status.txt`/log/report. This is not a second installer implementation or a local source-build seam. Read-only capture stays an optional asset and remains outside normal installation.


## Provider mode versus tab-scroll state (0.0.88 regression repair)

In 0.0.85 the scroll target moved to `CAM_ResourceTabs.Tag`, but 22 older mode-comparison conditions still read that property and therefore compared a concrete `ListBoxItem` against mode tokens. In 0.0.88 all provider modes are read from `CAM_ProviderModeMarker.Tag`, including LB/RB and nested state; the resource list's `Tag` remains solely the native horizontal scroll target. Shoulder Click conditions also require a null `CAM_TabCycleMarker.Tag` so only one provider transition can start for each press. These are independent invariants: mode identity, single-event transition, and concrete resource scroll target.

Presentation retains the exact captured Patch 8 ActionResourcesList template for actual resource previews. The extra CAM-only providers have no corresponding native preview type; their resource-box frames now share the native background margins and consistent glyph sizing rather than claiming identical native categories.


## Original HotBar visual template instead of custom icons (0.0.89)

The original keyboard `HotBar.xaml` defines the `ActionResourcesList` visual in an **inline** `ItemsControl.ItemTemplate`, whose data type is `VMActionResourceCostPreview`. It is not an exported standalone template resource that can be imported into the controller page. CAM uses the captured template's resource indicator controls (`LSActionPointResources`, `RomanNumeralLevelImage`), images and trigger layout in the controller `LSListBox.ItemTemplate`. That list is the necessary controller adaptation: LB/RB changes the selected item and invokes native filter commands; none of the mouse-only HotBar page is loaded.

The captured keyboard page defines `ResourceBackgroundMargin=0` in its **own** resources. The former CAM alias `CAM_ResourceBackgroundMargin` was not declared at all; the controller now defines it locally with exactly that zero value. The original highlighted image `BoxResourceH` is selected on `IsMouseOver`. CAM maps selected `ListBoxItem` (only when provider mode is null) to the very same image visibility, rather than attempting to generate fake highlighted resource indicators. The exhausted-resource trigger takes precedence. The same local margin now resolves in all special-provider chrome images.

The top-level special providers are not entries in vanilla `ActionResourcesCostPreview`; their content must remain distinct even though their container uses native resource-box art. Further UI parity depends on runtime appearance proof rather than speculative image resizing.


## 0.0.91 — keyboard HotBar resource glyph boundary

The 2026-10-08 comparison at equal screenshot scale shows a real image-source
mismatch, **not only misplaced tabs**: the keyboard HotBar renders stars,
clovers, a flame and groups of squares, whereas CAM rendered enlarged basic
bars and rectangles for the corresponding resources. The 0.0.90 baseline
alignment fix did not address this.

CAM is hosted by the controller library, so reuse of
`ActionResourcesTemplateSelector` alone has not established visual parity
with the keyboard-mode HotBar. Patch 8 `DataTemplates.xaml` defines
resource-point image selection using
`IconIdToSourceConverter(ActionResourcePoint*IconsPath, TypeId)`.
The controller resource template now explicitly uses this native icon-source
mechanism for point **normal / highlight / used / missing** states. It sets
a local `ActionPointTemplate` on the existing `LSActionPointResources`;
the existing style still owns counts, resource grouping, costs and sizing.
There are no hard-coded resource TypeIds, icon assets or alternative filters.

This is an isolated *rendering* change. LB/RB, resource selection,
`FilterActionResourceCommand`, action grid focus, tooltip, A/B,
Passives, item quantity and nested lifecycle must remain unchanged.

**Proof boundary:** static validation and package CI can check bindings and
XAML structure but cannot prove Noesis image resolution or in-game visual
parity. If runtime still renders geometric fallback glyphs, inspect the
current installed 1.8.910.0 `DataTemplates.xaml` icon path resources and
controller dictionary lookup before another presentation change. Do not
guess scale factors or implement a CAM-specific resource-name/icon map.


## 0.0.93 — keyboard resource point visuals within controller tabs

The installed Xbox App 1.8.910.0 `DataTemplates_k.xaml` and
`DataTemplates_c.xaml` differ at the resource point group/style
boundary. CAM must preserve **keyboard hotbar resource presentation**
inside its controller-owned selected-tab transport, not inherit the
game's unrelated full-screen controller resource-bar dimensions.

The `VMActionResourceCostPreview` template therefore has one
presentation-only boundary:

```text
Controller CAM_ResourceTabs (LB/RB, filters, scrolling)
  -> native VMActionResourceCostPreview
     -> native LSActionPointResources(ActionResourcesTemplateSelector)
        -> CAM_KeyboardHotBarPointGroup
           -> native ActionResources.ActionGroup.ActionPoint glyph
     -> scoped keyboard resource group/point/small sizes 56 / 48 / 24
```

All resource identity, images, available/spent states, conditional
numerals, spell-level overlays, native `FilterActionResourceCommand`,
VMHotBarSlot execution, tooltip, item quantities, and B return remain
native. Do not merge `DataTemplates_k.xaml` globally or mutate
controller UI resource dictionaries. The literal keyboard mapping
removes the failed 0.0.91 hand-authored glyph template.


## 0.0.94 point-image diagnostic boundary

Do not infer visual acceptance from matching XAML or passing tests.
Temporary runtime probe in `CAM_ResourceTabTemplate` draws a second
direct icon through the **same** game's `IconIdToSourceConverter` and
`ActionResourcePointIconsPath` but without `LSActionPointResources`
and its internal point/group renderer. A per-resource `94` mark proves
the new resource item template itself is active. Both are
`IsHitTestVisible=False` and leave the gameplay renderer and
selection/focus/tooltip unchanged. A screenshot determines whether
the source image or its point-control presentation is responsible;
the diagnostic markup must then be removed.


## 0.0.95 point-image measurement boundary

v0.0.94 established live controller item-template execution and
isolated oversized/clipped point glyphs from correctly bounded
independent icon-source preview. The correction moves the bounded
image into a CAM-owned native `LSActionPointResources.ActionPointTemplate`
per-point renderer; the native style, `MaxGroupActionPoints`, resource
states and `VMActionResourceCostPreview.Cost` still choose count,
source and availability. The image uses the native icon converter
and each game's resource `TypeId`, constrained to the keyboard native
small-point size (24), with `Stretch=Uniform`. No hard-coded classes,
icons or resource mapping, no changes to controller navigation.
The ephemeral `94` and `B` diagnostic items are removed.


## 0.0.96 — literal keyboard HotBar group resources, not reimplementation

The visual failure in v0.0.95 is evidence that constraining individual
resource-point Images to `24×24` does not reproduce the keyboard HotBar.
The keyboard's actual Patch 8 resource group templates are defined in
`Public/Game/GUI/Library/DataTemplates_k.xaml`, while controller GUI
loads `DataTemplates_c.xaml`. The global shared style
`ActionResourcesTemplateSelector` uses `DynamicResource` to select
the group by `ActionResource.TypeId`; supplying one hand-written
`ActionPointTemplate` is not sufficient, because style triggers
override it for many resource types.

The self-contained CAM `VMActionResourceCostPreview` item therefore
locally declares **all 24** original keyboard `ActionResources.ActionGroup.*`
ControlTemplates, copied byte-for-byte from the installed Xbox App
v1.8.910.0 `DataTemplates_k.xaml`, along with the exact original
`56/48/24` group, point and small-point sizes. The copied templates
refer to the game's unmodified shared `ActionResources.ActionGroup.ActionPoint`
DataTemplate, including its original image source, per-state triggers,
animations, scale and grouping. This dictionary is intentionally
scoped **only to the resource item Grid** to avoid overriding the
controller UI outside CAM. No new TypeId table or duplicated textures.

Deleted the CAM-authored uniform-scaled point renderer introduced in
v0.0.95 and the explicit per-control `ActionPointTemplate` override:
they are not part of the original keyboard UI. Keep the
`LSActionPointResources` bindings (Value, MaxValue, Cost,
MaxActionPointGroups) and the native `ActionResourcesTemplateSelector`
style exactly as in the pinned `HotBar.xaml` page.

`tools/validate.py` pins the exact copied keyboard template block
using SHA-256 `9e017778ec41ef2e03f192392ca944640f7d8ad3c227f69d9742aefbdaff4651`;
`tools/test-self-contained-runtime.ps1` checks all 24 distinct keys and
rejects CAM-owned glyph overrides. These are **static proof** of exact
source composition, not proof of Noesis runtime dynamic resource
resolution. One real in-game screenshot must still establish parity.


## 0.0.98 — keyboard resource image path ownership

Resource icon parity requires both the original keyboard
`ActionResources.ActionGroup.*` group ControlTemplates and the
game's `ActionResources.ActionGroup.ActionPoint` DataTemplate
**resolved against keyboard theme path keys**. The former was
present in 0.0.96; the latter was incorrectly inherited from
controller-mode `DefaultTheme_c.Styles.xaml`.

The 1.8.910.0 capture proves keyboard `DefaultTheme.Styles.xaml`
defines resource-point bitmap paths under `Assets/Shared/Resources/`;
controller mode uses `Assets/ActionResources_c/Icons/Resources/`.
Because the game's shared point DataTemplate binds these strings via
`StaticResource`, merely supplying local group template keys cannot
change the globally resolved bitmap path.

Inside `CAM_ResourceTabTemplate`'s `Grid.Resources` only, declare:
1. Native keyboard group, point and small-point sizes 56/48/24.
2. Four original keyboard point bitmap directory strings, including
   Highlight, Missing and Used variants.
3. A source-exact native `DataTemplates.xaml`
   `ActionResources.ActionGroup.ActionPoint` DataTemplate (no CAM
   image code or uniform scaling).
4. All original 24 keyboard `DataTemplates_k.xaml` point-group
   ControlTemplates, referencing the point DataTemplate above.

The rest of BG3 controller mode retains original theme resources.
Native `LSActionPointResources`, TypeId, numeric counters, resource
availability/state, LB/RB, tooltip, grid focus and A/B execution do
not change. Validate SHA-256 of both copied native XAML blocks.


## 2026-10-09 source-level candidate: native action cost feedback (#166)

Existing action focus calls were intentionally disabled after 0.0.75 because the keyboard HotBar's transient mouse-hover preview `Cost` was left active by persistent controller focus. The player nevertheless needs the **original** native action-cost hint in the ordinary BG3 resource bar. In this candidate, the upper CAM tab display is treated as a persistent **navigation** presentation, not a hover-cost overlay: `LSActionPointResources.HighlightedActionPoints=0`, while `MaxActionPoints`, `AvailableActionPoints`, resource icons, spell level chrome, and resource filtering remain native.

The native BG3 controller-focus lifecycle becomes: immediate `LocalFocusChanged` clears old predicted cost, then the existing 70ms non-null/active-slot owner copies `LocalFocus.DataContext` to `ActionRadials.Tag`, creates the tooltip and passes that exact `VMHotBarSlot` to `HighlightResourcesCommand`. The programmatic tab-entry handoff uses the same source. The code must not clear the newly applied preview in either deferred path. Existing provider/tab transitions, nested return and normal close own invalidation; no calculated costs or secondary slot owner are introduced.

This is a **draft runtime candidate** with source/CI proof only, not a runtime-accepted correction. Combined in-game validation must prove ordinary HUD resource cost feedback and unchanged upper-tab visual quantities, and no stale feedback after leaving the menu.


### 2026-10-09 metamagic owner correction

`CAM_FixedSideBarList` owns its **own** native `FixedSideBar.SlotList` focus when the Metamagic provider is active and `HotBarList` is deliberately disabled. Consequently the main list's `HighlightResourcesCommand` cannot serve these focused metamagic entries. This candidate restores the exact same game-owned cost-preview call in both side-list 70ms stable-focus routes (`LocalFocusChanged` and programmatic `SelectionChanged`), using `CAM_FixedSideBarList.LocalFocus.DataContext` and only when the side list is enabled and Metamagic owns the provider. Its existing immediate focus event continues to clear stale resource highlights; `ActionRadials.Tag` and `UseSlotCommand` remain unchanged.

The final `All` provider remains a separate unproved branch: its outer selection is a `VMHotBar` group and inner entries are `VMHotBarSlot` children. No new `HighlightResourcesCommand(VMHotBar)` is permitted. A follow-on source/runtime owner proof is required for cost highlight, slot sound/haptics and action identity under All. Do not call #166 complete solely because the direct and sidebar routes are CI-green.


## 2026-10-09 partial correction — LB grouped-All opening sound (#160)

The original controller state machine distinguishes `OpenActionRadials` and `OpenActionRadialsEnd` by `ActionRadials.Metadata=MoveToEnd`. The first direct-resource opening already uses the native `HotBarList.LocalFocusChanged` sound `UI_HUD_Controller_RadialMenu_SlotHover`. The LB/MoveToEnd opening instead enters the grouped `KeyboardHotBars` All provider and, according to operator game testing, produces no sound or vibration. CAM now emits **one instance of the already-proven native slot-hover sound** in the existing `CAM_ResourceTabs.Loaded` branch guarded by `Metadata==MoveToEnd`. It does not emit it on ordinary LB/RB tab navigation, nor add a duplicate on the RB normal branch. The original 70ms first-slot handoff and selected All resource/provider remain unchanged.

This is a strictly **sound-only source candidate**, not proof of correct runtime playback or haptics. The game-owned haptic/vibration route is not identified by current pinned Patch 8 sources, so no fabricated rumble command or new input binding is introduced. In the next combined published-Release milestone, verify RB and LB opening each produces one sound and appropriate haptics, and that repeated tab changes don't double-play sounds. If LB still lacks vibration, #160 stays open until the actual engine-level event source is proven.


## 2026-10-09 runtime correction after published v0.0.111

Operator's actual test disproved three visual/audio assumptions in the preceding milestone:

- LB/MoveToEnd **double-played** its menu opening sound and still did not vibrate. The additional `LSPlaySound(UI_HUD_Controller_RadialMenu_SlotHover)` at `CAM_ResourceTabs.Loaded` was a duplicate; remove it. Opening audio/haptics must ultimately come from a **single proven native lifecycle**. Do not claim this source rollback fixes missing LB vibration.
- A 32px title row did **not** prevent selected resource/provider text from overlapping original tab art. New bounded visual candidate uses a **64px** reserved title lane, a top-aligned 44px clipped text box and 20px gutter. The center-offset is adjusted from -16 to -32 so native 84px tab row and 850px grid retain their prior positions. Actual scaled Noesis rendering is not proven by static geometry.
- Right-hand hint panel `MaxWidth=380` **clipped** original controller hints. Increase the bound to **600px** while keeping right-side placement and compact `Width=Auto` children; native center HUD non-overlap must be checked in game, not asserted from maximum width alone.

The same operator explicitly **confirmed resource-cost highlighting works**; preserve its native `HighlightResourcesCommand` paths, including focused metamagic slots, and do not disable them while repairing focus UI.

Other uncorrected v0.0.111 issues: in-menu weapon hold/progress, metamagic focus-frame divergence, selected metamagic not handing focus to compatible spell grid, duplicated IV-level upcast choice (#172), and LB haptics. Do not advertise any of these as fixed by the local audio/layout rollback. Prepare a combined source/CI-reviewed candidate and one published-Release gameplay check, never one release per tweak.
