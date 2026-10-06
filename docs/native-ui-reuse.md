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

Therefore CAM's executable main cells come only from native hotbar-slot collections:

- `CurrentShownDeck.SlotList`;
- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList`;
- `SingleHotBar.SlotList`.

Raw radial-assignment `SpellsAndActions`, inventory slots and passive objects are not gameplay-dispatch candidates.

## Controller cell presentation

The fresh capture distinguishes three presentation contracts:

- `HotBarSlotStyle` is keyboard-hotbar presentation. It proves the execution type boundary, but it also renders `HotKey` and is therefore rejected in CAM.
- `SlotIconStyle` belongs to the controller radial renderer, but its own captured inner icon style is 120×120. Wrapping it in a 104×104 control does not make the visible icon 104×104 and was proven in-game to leave the focus frame mismatched.
- the current controller **assignment grid** uses a real 104×104 icon surface (`Rectangle Fill="{Binding Icon}" Width="104" Height="104"`) inside a 120×120 `LSGrid` cell. This is the geometry CAM now reproduces for `VMHotBarSlot.Content.Icon`.

The focused/executed object remains the surrounding `VMHotBarSlot`; only presentation dereferences `slot.Content.Icon`. The action `ListBoxItem` itself is 104×104, while `SelectorTemplate` remains geometry-free and follows that focused item. This keeps selector sizing derived from the real cell instead of hard-coding selector dimensions.

The semantic type tabs now reproduce the current HotBar `FilterButton`/`ActiveFilterButton` presentation: `btn_pil_d.png` / `btn_pil_active_d.png`, `BtnTextGlow`, `SmallFontSize`, native padding and `-4,0` margins. CAM does not invent fixed 150×64 tab geometry or a 32px font.

The current HotBar resource controls are a separate compact 72px strip. CAM therefore does not present `ActionResourcesCostPreview` as 104/120px action cells or draw `ActionResource.Name` below them. The resource strip follows the action catalog, and controller focus alone does not change the filter; `UIAccept` invokes `FilterActionResourceCommand`, matching the native click-to-filter semantics.

## HotBar filter semantics

The current keyboard `HotBar.xaml` capture proves the model/commands used by CAM:

- `SetCurrentShownDeckCommand("CommonHotBar")`;
- `SetCurrentShownDeckCommand("ClassHotBar")`;
- `SetCurrentShownDeckCommand("ItemHotBar")`;
- `FilterCantripsCommand` with the captured current parameter;
- `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- `FilterActionResourceCommand`;
- `ClearSingleHotbarCommand`.

The tabs are semantic filters, not independent source catalogs. CAM does not classify actions by names, icons, spell levels or custom resource rules.

## SpellBook evidence boundary

The same 1.8.910.0 capture confirms current SpellBook predicates `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate`. Their captured input is `SelectedItem.ActionGroups`, not `VMHotBarSlot`.

They remain useful evidence for how BG3 groups SpellBook presentation, but they are not CAM gameplay-dispatch sources and are not copied into the main grid. Spell-slot/resource filtering stays on the native HotBar/resource model until BG3 exposes a current VMHotBarSlot-compatible level filter.

## Controller focus and dispatch

The current native radial lifecycle uses the focused item's **DataContext**.

```text
CAM_FilteredSlotList.LocalFocus.DataContext
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

## Navigation reuse

The current assignment UI proves the controller hierarchy:

```text
outer LSListBox
  LocalFocusSelector
  DirectionalNavigation = Contained
  ActionNextEvent = UIDown
  ActionPrevEvent = UIUp
        |
        +-- child LSListBox
              DirectionalNavigation = Continue
              |
              v
            LSGrid
              UIUp / UIDown / UILeft / UIRight
```

The fresh `1.8.910.0` `SelectorAssign` element has no fixed width, height or margin. CAM reproduces that current selector contract instead of retaining the stale synthetic `118x118` geometry.

One outer list owns scrolling/vertical continuation. Resource and action grids remain children of that navigation shell.

## Native nested state and B

`SingleHotBar.SlotList` remains BG3-owned for container, variant and upcast state.

A remains:

```text
UIAccept -> UseSlotCommand(ActionRadials.Tag)
```

B remains the native command lifecycle:

- default: `ClearSingleHotbarCommand`;
- top level: native `CustomEvent("CloseWidget")` condition;
- swap state: native `UseSlotCommand(null)` behavior.

CAM does not implement separate cancel semantics.

## Resource filters

Resource filter cells are the current native `VMActionResourceCostPreview` objects from `ActionResourcesCostPreview`.

The project-owned renderer uses the captured model shape (`ActionResource`, `MaxValue`, `Value`, `Cost`) and sends the focused preview object to `FilterActionResourceCommand`.

Resource membership and action costs remain BG3-owned.

## Button hints and customization

The project-owned template retains the captured right-stacked `ButtonHintsContainer` composition and native input glyph/content resources.

Radial editing is outside CAM. `ShowContextMenu` is hidden/inert and assign/swap/clear/add/remove radial mutation commands are absent from the project-owned runtime.

## Resource ownership

CAM references already-loaded native styles/templates such as slot visuals, selector chrome, input hints and action-resource rendering. It does not copy the full Larian controller dictionary or any `Public/Game/GUI` resource into the mod.

If a future Patch changes one of these dependencies, the developer capture is refreshed and the project-owned contract is reviewed before release. Installation never derives a replacement from the user's local game.
