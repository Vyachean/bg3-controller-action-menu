# Architecture

## Objective

Replace Baldur's Gate 3 controller radial browsing with a controller-first, automatically populated **resource-first action bar** while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

The shipping artifact is one self-contained ordinary BG3 `.pak`, with no Script Extender, DLL/native loader, or install-time game-file derivation.

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

There is no return to the rejected raw Common/Class/Items/Passives source-tab UI and no secondary resource-filter layer. The top level remains a single controller cost/source sequence. Cantrips are the one proven zero-cost special provider and use BG3's own `FilterCantripsCommand` rather than a raw catalog. Resource previews are the primary provider, but they are not assumed to be a complete executable catalog; proven native non-resource providers may join that same sequence when needed to satisfy action parity.

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
- `PassivesHotBar.SlotList`;
- `SingleHotBar.SlotList` for native nested/upcast/variant/throw state.

Current unresolved source classes are free/no-resource actions, inventory/consumables,
scrolls, item charges, metamagic toggles, temporary actions and recasts. These are correctness blockers for a complete HotBar replacement.

A future provider must be proven against the current installed game and materialize
executable `VMHotBarSlot` values. This requirement does not authorize raw source tabs,
manual action tables or string/icon classification.

## Resource-first navigation

LB/RB selects an item from the dynamic resource list. Selection immediately invokes `FilterActionResourceCommand`; the grid is always sourced from `SingleHotBar.SlotList`.

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
