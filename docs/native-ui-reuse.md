# Native UI reuse

## Principle

CAM does not reimplement Baldur's Gate 3 gameplay semantics. The self-contained controller library composes the smallest current Patch 8 contracts needed to present native executable slots in a controller grid.

The consumed Xbox App `1.8.910.0` evidence is pinned in `docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

## Execution type boundary

Current `HotBarSlotStyle` establishes the important boundary:

```text
VMHotBarSlot
  Content -> VMCharacterAction / VMUpcast / VMItem / VMPassive
  execution parameter -> VMHotBarSlot
```

Therefore CAM executes only native hotbar-slot VMs. Current HotBar evidence proves several native slot collections, but the shipping resource-first surface intentionally uses one executable source: `SingleHotBar.SlotList`, populated by BG3's own `FilterActionResourceCommand` and reused for nested variant/upcast/container state.

Raw radial-assignment `SpellsAndActions`, inventory slots and passive objects are not gameplay-dispatch candidates. `CurrentShownDeck.SlotList` and `PassivesHotBar.SlotList` remain evidence of the VMHotBarSlot boundary, not additional top-level CAM lists.

## Controller cell presentation

The fresh capture distinguishes three presentation contracts:

- `HotBarSlotStyle` is keyboard-hotbar presentation. It proves the execution type boundary, but it also renders `HotKey` and is therefore rejected in CAM.
- `SlotIconStyle` belongs to the controller radial renderer, but its own captured inner icon style is 120×120. Wrapping it in a 104×104 control does not make the visible icon 104×104 and was proven in-game to leave the focus frame mismatched.
- the current controller **assignment grid** uses a real 104×104 icon surface (`Rectangle Fill="{Binding Icon}" Width="104" Height="104"`) inside a 120×120 `LSGrid` cell. This is the geometry CAM now reproduces for `VMHotBarSlot.Content.Icon`.

The focused/executed object remains the surrounding `VMHotBarSlot`; only presentation dereferences `slot.Content.Icon`. The action `ListBoxItem` itself is 104×104.

The detached selector experiment is retired. Current CAM follows the Patch 8 SpellBook controller pattern: each action item is `ls:MoveFocus.Focusable=True`, its own template reacts to `ls:MoveFocus.IsFocused`, and `LSGrid.Columns` is derived from the enclosing `ScrollContentPresenter.ActualWidth`. Focus chrome therefore lives in the same item coordinate space as the executable slot and cannot remain behind when a resource result is replaced.

The top-level navigation is the resource strip itself. CAM binds one horizontal LB/RB list directly to `ActionResourcesCostPreview`; `SelectionChanged` invokes `FilterActionResourceCommand(selectedPreview)` and returns focus to the action list. SpellSlot/WarlockSpellSlot entries retain native level presentation. Generic entries use `ActionResource.Name`, with `ActionResource.TypeId` only as a null-name fallback. The strip is bounded and follows its selected index instead of widening the whole menu.

## Controller organization

CAM has one top-level organization dimension:

```text
dynamic resource tabs
        |
        v
FilterActionResourceCommand(selected VMActionResourceCostPreview)
        |
        v
SingleHotBar.SlotList
        |
        v
VMHotBarSlot grid
```

The former Common/Class/Cantrips/Items/Passives controller carousel is retired. Type/deck tabs are not part of the target product.

The resource row binds directly to `CurrentPlayer.UIData.ActionResourcesCostPreview`. SpellSlot/WarlockSpellSlot entries retain native level data; other and mod-added resources use the native resource name. Duplicated actions across resource tabs are allowed when BG3 exposes separate executable variants.

`FREE`, `SCROLLS`, and other non-ActionResource source groups are product targets but require a proven native executable-slot source. They must not be reconstructed from raw assignment catalogs.

There is no CAM Live Details panel. The ordinary native action tooltip remains the only details surface.

## HotBar filter semantics

The current keyboard `HotBar.xaml` capture proves the model/commands used by the resource-first runtime:

- `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- `FilterActionResourceCommand`;
- `SingleHotBar.SlotList`;
- `ClearSingleHotbarCommand` for actual BG3 nested state.

Resource tabs are native filters, not independent source catalogs. CAM does not classify actions by class, names, icons, spell names or custom ability tables.

## SpellBook evidence boundary

The same 1.8.910.0 capture confirms current SpellBook predicates `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate`. Their captured input is `SelectedItem.ActionGroups`, not `VMHotBarSlot`.

They remain useful evidence for how BG3 groups SpellBook presentation, but they are not CAM gameplay-dispatch sources and are not copied into the main grid. Spell-slot/resource filtering stays on the native HotBar/resource model until BG3 exposes a current VMHotBarSlot-compatible level filter.

## Controller focus and dispatch

The current native radial lifecycle uses the focused item's **DataContext**.

```text
HotBarList.LocalFocus.DataContext
        |
        +--> ActionRadials.Tag
        +--> CreateFocusedTooltipDataCommand(slot)
        +--> HighlightResourcesCommand(slot)
        |
        v
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

The capture proves the native sequence:

1. on `LocalFocusChanged`, clear the previous tag/tooltip/resource highlight and play the hover sound;
2. after the native 70 ms delay, write `LocalFocus.DataContext` into `ActionRadials.Tag`;
3. create focused tooltip data and highlight resources for that same native slot.

The older development fixture's `LocalFocus.Tag` handoff is rejected.

The item container may still expose `Tag="{Binding .}"` as ordinary presentation metadata, but the current gameplay-facing focus lifecycle does not depend on it.

## Focused action descriptions

`CreateFocusedTooltipDataCommand` populates radial-specific focused-slot data, but that command alone does not render a tooltip. The captured slot-assignment UI proves the missing visual bridge: an `LSTooltip` is owned by the outer controller list, its content is updated from local focus, and `ShowTooltipOnUIElementCommand` shows/hides it.

CAM applies that pattern to executable slots:

```text
HotBarList.LocalFocus.DataContext = VMHotBarSlot
        |
        +--> tooltip.Content = VMHotBarSlot.Content
        +--> ShowTooltipOnUIElementCommand(HotBarList)
        +--> existing 70 ms ActionRadials.Tag / focused-tooltip-data lifecycle
```

The tooltip content is the native action/item/passive object, not CAM-authored description text. Variants/upcasts reuse the same `HotBarList` because BG3 replaces `SingleHotBar.SlotList` rather than CAM switching to a second list.

## Navigation reuse

The captured assignment UI proves the four controller direction events and focusable action cells; the current SpellBook adds the simpler adaptive-grid pattern used by CAM.

The resource-first runtime has one executable controller list:

```text
HotBarList
  ItemsSource = SingleHotBar.SlotList
  DirectionalNavigation = Contained
  ScrollViewer = pixel scrolling
        |
        v
CAM_ActionGridPanel
  UIUp / UIDown / UILeft / UIRight
  Columns = floor(ScrollContentPresenter.ActualWidth / 120)
  UseWidgetNavigation = true
  AlwaysSelectFirst = true
        |
        v
CAM_ActionGridSlotContainer
  MoveFocus.Focusable = true
  item-local focus chrome
```

The list owns scrolling, tooltip updates and the native delayed `LocalFocus.DataContext -> ActionRadials.Tag` lifecycle. This removes the old wrapper lists and detached selector so navigation, focus presentation, tooltip and execution all observe the same focused slot.

## Native nested state and B

`SingleHotBar.SlotList` is both the resource-filtered top-level result and BG3's nested container/variant/upcast/throw collection. The same `HotBarList` renders both states; CAM does not swap visibility to a separate `SingleBar`.

A remains:

```text
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

B remains the native command lifecycle:

- default: `ClearSingleHotbarCommand`;
- top level: `CustomEvent("CloseWidget")` when the three nested-state flags are false;
- nested-state focus restoration targets the same `HotBarList`.

A later isolated fix may reapply the selected resource filter after nested B if BG3 leaves `SingleHotBar.SlotList` empty. That recovery is deliberately not coupled to the focus-tree simplification itself.

## Resource filters

Resource tabs are the current native `VMActionResourceCostPreview` objects from `ActionResourcesCostPreview`.

Selecting a resource sends that preview object to `FilterActionResourceCommand`. The executable grid then consumes BG3's `SingleHotBar.SlotList`. Resource membership, costs, and any upcast/resource-specific slot materialization remain BG3-owned.

Action/Bonus primary-resource refinement is deliberately not implemented through class/spell-name heuristics. If native filters are too broad, a future correction must be based on a proven current property/predicate over executable native slots.

The current evidence also does not expose a per-preview "has executable slots" property. A tab that filters to an empty `SingleHotBar.SlotList` must not be hidden by a re-entrant `SelectionChanged -> filter -> empty -> select/filter again` loop; that family of recovery was rejected in 0.0.49. Empty-tab removal remains blocked on a proven native seam or a higher-information runtime capture.

## Button hints and customization

The project-owned template retains the captured right-stacked `ButtonHintsContainer` composition and native input glyph/content resources.

Radial editing is outside CAM. `ShowContextMenu` is hidden/inert and assign/swap/clear/add/remove radial mutation commands are absent from the project-owned runtime.

## Resource ownership

CAM references already-loaded native styles/templates such as input hints, focus visual resources and action-resource rendering. It does not copy the full Larian controller dictionary or any `Public/Game/GUI` resource into the mod.

If a future Patch changes one of these dependencies, the developer capture is refreshed and the project-owned contract is reviewed before release. Installation never derives a replacement from the user's local game.


## Rejected 0.0.49 composition

The 0.0.49 composition that layered per-cell VMUpcast controls, extra UIAccept bindings, automatic empty-list refiltering, and a focus-tree rewrite is rejected by runtime proof because it made tab interaction delayed and unpredictable. Reuse native seams only when they do not introduce overlapping input consumers or re-entrant filter/state transitions.


## Current Patch 8 patterns adopted after 0.0.57

Fresh installed-game evidence supersedes the detached selector/fixed-grid experiment.

From `Mods/MainUI/GUI/Pages/SpellBook_c.xaml`:
- `SpellGridStyle` sets `UseWidgetNavigation=True`, `AlwaysSelectFirst=True`, `ls:MoveFocus.InternalFocusable=True`, and the four controller direction events;
- `LSGrid.Columns` is computed with `DivideMultiConverter` from the ancestor `ScrollContentPresenter.ActualWidth` and cell size;
- action entries are explicit `ls:MoveFocus.Focusable=True` controls;
- focus presentation follows the focused control rather than a page-level coordinate overlay;
- scrolling uses an ordinary ScrollViewer around the action content.

From current `HotBar.xaml`:
- `ActionResourcesCostPreview` is directly rendered as resource filter buttons;
- clicking a preview invokes `FilterActionResourceCommand(preview)`;
- the native item container hides only `ActionResource.MaxValue == 0`;
- resource presentation is icon/level oriented, so `ActionResource.Name` is not guaranteed to be the only useful visual identifier.

CAM therefore keeps native resource filtering but removes `CAM_MainSelector`, removes fixed `Columns=5`, and does not treat missing resource names as a reason to discard a resource.
