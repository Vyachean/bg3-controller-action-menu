# Open-source findings: controller action UI

## Conclusion

Open sources now prove more of the current Patch 8 controller contract than the first investigation found.

**Current, independently supported facts:**

- the Patch 8 state is still `ActionRadials` with the `HotBar` context;
- `HotBarSlotStyle` is current Patch 8 and dispatches through the owning `UIWidget.DataContext.UseSlotCommand`;
- its command parameter is the current slot object (`CommandParameter="{Binding}"`);
- a late-September-2026 production mod obtains the live `HotBar` widget DataContext and successfully calls `UseSlotCommand:Execute(slot)`;
- that same current mod uses `CurrentSingleHotbarFilter`, proving the nested-hotbar filter still exists;
- current Patch 8 templates use `IsShowingAContainerWithVariants`;
- controller and keyboard hotbar state are distinct at the game-component level;
- the shipped Patch 8 controller radial uses focus-driven `LSScrollViewer.ScrollToElement`.

The public-source boundary was reached without exposing the exact controller-radial XAML collection. That remaining seam has now been resolved by a read-only capture of the installed Xbox App build 1.8.910.0.

The installed native contract names `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars` as the root controller collection, `SlotList` as the per-bar collection, and `SingleHotBar.SlotList` as the nested collection.

The earlier public `ActionRadials.xaml` is Patch 2 Hotfix 1 from 2023-09-06. It remains historical evidence only.

## 1. Hotbar/radial data is publicly mapped

Current BG3 Script Extender maps `eoc::hotbar::ContainerComponent` as `HotbarContainer`.

Relevant public shape:

- `Containers`
- `ActiveContainer`
- `Locked`
- each bar has:
  - `Index` (documented in source as Common / Class / Item)
  - `Controller`
  - `Elements`
- each slot can identify:
  - an item;
  - a `SpellId`;
  - a passive;
  - the slot index.

Script Extender's own tests read this component from a character and resolve a concrete spell slot.

References:

- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/GameDefinitions/Components/Hotbar.h
- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/LuaScripts/Tests/CharacterComponentTests.lua

This means we do not need to invent the action identity model from scratch.

## 2. Controller and keyboard hotbar state are distinct

The public component mappings contain controller-specific fields, including `Bar.Controller`, `AddSlotEntryData.HotBarController`, and event data with `IsController`.

The current RadialHotbarCustomization mod also documents that version 0.8.0 was substantially rewritten after the author identified how BG3 differentiates keyboard/mouse hotbar state from controller radial state.

References:

- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/GameDefinitions/Components/Hotbar.h
- https://www.nexusmods.com/baldursgate3/mods/18194

This is useful for categorization/state observation, but the UI should still prefer the native radial view-model as the immediate presentation source when possible.

## 3. Script Extender can inspect native Noesis UI at runtime

Current Script Extender exposes the necessary Noesis operations on every `BaseObject`:

- `Type`
- `TypeInfo`
- `GetProperty(name)`
- `GetAllProperties()`
- `DirectProperties()`
- `DependencyProperties()`
- `SetProperty(name, value)`

UI tree traversal exposes:

- `Find`
- `Child`
- `VisualChild`
- child counts and parents.

Noesis commands expose:

- `CanExecute(parameter)`
- `Execute(parameter)`.

Reference:

- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/GameDefinitions/PropertyMaps/UI.inl
- https://github.com/Norbyte/bg3se/blob/main/Docs/API.md

Therefore a probe can inspect a live radial DataContext without knowing its concrete C++ type in advance.

## 4. This technique is proven by a current Patch 8 mod

`bg3-name-your-summons` uses the same Noesis API in production.

Its current native-UI code:

- starts at `ContentRoot`;
- walks the live visual tree;
- reads a DataContext's `GetAllProperties()` property bag;
- obtains native game commands;
- checks `CanExecute`;
- calls `Execute`;
- avoids caching Noesis objects across ticks.

Its August 2026 architecture verification documents this approach as proven in BG3 Patch 8 / Script Extender v30.

References:

- https://github.com/whme/bg3-name-your-summons/issues/50
- https://github.com/whme/bg3-name-your-summons/blob/main/NameYourSummons/Mods/NameYourSummons/ScriptExtender/Lua/Client/NativeRenameUI.lua

This substantially reduces the risk of using runtime introspection for the radial.

## 5. Current radial filename and focus mechanism are independently confirmed

A July 2026 Script Extender issue, tested on Patch 8 / SE v31, identifies the shipped controller file as:

`PreloadedActionRadials_c.xaml`

It also reports that the page uses Larian's `LSScrollViewer.ScrollToElement` bound to gamepad `FocusedElement`.

Reference:

- https://github.com/Norbyte/bg3se/issues/584

This supports using native gamepad focus movement for a future grid rather than inventing script-driven scrolling.

## 6. Patch 8 `HotBarSlotStyle` proves current dispatch semantics

The Patch 8 `DataTemplates.xaml` snapshot contains the complete current `HotBarSlotStyle`.

Its relevant setters are:

- `BoundEvent = {Binding BoundEvent}`;
- `Command = {Binding DataContext.UseSlotCommand, RelativeSource=AncestorType ls:UIWidget}`;
- `CommandParameter = {Binding}`.

The template is explicitly designed around `VMHotBarSlot` and related native content types.

This is stronger evidence than the old radial page. We no longer need the current radial XAML to prove the normal slot dispatch command or parameter: a CAM slot that uses `HotBarSlotStyle` under the real `HotBar` UIWidget should leave execution to BG3.

Reference:

- `Coyote-31/bg3-advanced-character-sheet/Sources/BG3/Patch8/Game/Public/Game/GUI/Library/DataTemplates.xaml`

## 7. A September 2026 mod confirms the live HotBar view model

`belakarkache/bg3-shared-actions`, commit `2459fa91fb95a4795659840cb5930c695bfa0dab` dated 2026-09-27, contains production runtime code that:

1. walks `Ext.UI.GetRoot()`;
2. finds the top widget named `HotBar`;
3. reads its `DataContext`;
4. reads `context.CurrentSingleHotbarFilter`;
5. finds slots in `context.CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList`;
6. calls `context.UseSlotCommand:Execute(slot)`.

This gives unusually fresh proof that the following names still exist in the live Patch 8-era UI context:

- `CurrentPlayer`;
- `SelectedCharacter`;
- `PlayerCharacterProperties`;
- `KeyboardHotBars`;
- per-bar `SlotList`;
- `CurrentSingleHotbarFilter`;
- `UseSlotCommand`.

The important limitation is equally useful: `KeyboardHotBars` is explicitly the keyboard collection. BG3SE's current hotbar component mapping and RadialHotbarCustomization both show that controller state is distinct, so CAM must not use `KeyboardHotBars` as the controller menu source merely because it is publicly visible.

Reference:

- https://github.com/belakarkache/bg3-shared-actions/blob/main/src/Mods/SharedActions/ScriptExtender/Lua/Client/VariantMenu.lua

## 8. Current controller state is independently distinct from keyboard state

Current BG3SE mappings expose:

- `Bar.Controller`;
- `AddSlotEntryData.HotBarController`;
- `SlotEventData.IsController`.

RadialHotbarCustomization v0.8.0.0 (tagged 2026-02-22) was rewritten specifically after its author identified how BG3 distinguishes keyboard/mouse hotbar state from controller radial state.

The tagged v0.8.0.0 source makes that storage contract concrete:

- its entity declarations map `HotbarContainer.Containers.DefaultBarContainer`;
- its legacy bar field `field_1` is documented from observation as `0` for keyboard/mouse hotbars and `1` for controller radials;
- its player persistence code reads, serializes and restores `DefaultBarContainer`, using that field to distinguish the two UI modes;
- current BG3SE maps the same legacy `field_1` to the named `Bar.Controller` field.

This is strong evidence for the persisted controller discriminator and shared storage container. It is **not** evidence for the current Noesis/XAML controller collection or for how persisted bars become visual radial wheels. That presentation seam still has to come from the native radial UI contract.

Tagged-source references:

- https://gitlab.com/saghm/RadialHotbarCustomization/-/blob/v0.8.0.0/src/entity.d.tl
- https://gitlab.com/saghm/RadialHotbarCustomization/-/blob/v0.8.0.0/src/tl/Server/Player.tl
- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/GameDefinitions/Components/Hotbar.h

A separate current mod, Auto-Sorting Hotbar v1.1.0.0/1.1.0.1 (August/September 2026), added controller radial support and its author documents behavior that differs from keyboard ordering:

- one radial wheel contains 12 slots;
- families are kept together where possible rather than split across wheels;
- basic actions and combat toggles such as Metamagic start their own wheel.

These projects corroborate that the controller radial should be treated as its own persisted/ordered data surface, not as a visual projection of `KeyboardHotBars`.

RadialHotbarCustomization's September 2026 author comments add an important architectural limit: keyboard hotbars and controller radials are stored in the same mapped hotbar area with a controller/radial marker, but the persisted memory layout does **not** map cleanly to the visual radial wheels. On 2026-09-27 the author described ongoing work toward interacting more directly with the native gamepad/Noesis UI.

Those September comments describe **unreleased experimentation**, not additional code in the v0.8.0.0 release. They therefore corroborate the presentation-model direction but do not publish the controller collection/property path CAM still needs.

That matches the current BG3SE mapping (`Bar.Controller`, `HotBarController`, `IsController`) and rules out using `HotbarContainer` as CAM's presentation model. CAM needs the native radial UI/view-model materialization, not just the underlying persisted slots.

References:

- https://github.com/Norbyte/bg3se/blob/main/BG3Extender/GameDefinitions/Components/Hotbar.h
- https://gitlab.com/saghm/RadialHotbarCustomization/-/tags/v0.8.0.0
- https://www.nexusmods.com/baldursgate3/mods/18194?tab=posts
- https://www.nexusmods.com/baldursgate3/mods/24369

## 9. Patch 8 gives two valid close patterns, but radial-specific nesting is still unknown

Current Patch 8 pages demonstrate both:

- `BoundEvent="UICancel" Command="ls:UIWidget.CloseRequestCommand"` for a normal top-level controller page (`CharacterPanel.xaml`);
- `BoundEvent="UICancel" Command="{Binding CustomEvent}" CommandParameter="..."` for pages whose state owns a specific close event (`LearnSpells.xaml`).

This proves that both mechanisms are valid BG3 patterns. It does **not** prove which exact main/nested cancel switch the current radial uses. The radial-specific `UICancel` behavior remains one of the few seams worth reading from the current native page rather than guessing.

Reference:

- `Coyote-31/bg3-advanced-character-sheet/Sources/BG3/Patch8/Game/Mods/MainUI/GUI/Pages/CharacterPanel.xaml`
- `Coyote-31/bg3-advanced-character-sheet/Sources/BG3/Patch8/Game/Mods/MainUI/GUI/Pages/LearnSpells.xaml`

## 10. Installed Xbox App capture closes the radial presentation seam

A read-only capture performed against Xbox App package version `1.8.910.0` found three current radial files in `Game.pak`:

- `Mods/MainUI/GUI/Pages/ActionRadials.xaml`;
- `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`;
- `Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml`.

The source page is a thin `HotBar`-context widget whose template is `ActionRadialWidgetTemplate_P8`.

Both preloaded dictionaries agree on the gameplay/control contract:

- main controller collection: `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`;
- per-bar slots: `PagedList ItemsSource="{Binding SlotList}"`;
- nested slots: `SingleHotBar.SlotList`;
- focus scrolling: `LSScrollViewer.ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"`;
- normal A: hidden `UseSlotBinding` with `BoundEvent="UIAccept"`, `Command="{Binding UseSlotCommand}"`, and `CommandParameter="{Binding Tag, ElementName=ActionRadials}"`;
- default B: `ClearSingleHotbarCommand`;
- top-level B: when `SingleHotBar.SlotList.Count == 0` and `IsShowingItemsToThrow == False`, triggers replace B with `CustomEvent` + `CloseWidget`;
- swap-slot B: `UseSlotCommand(null)`.

The Clairmont copy differs from the normal library copy only in visual scaling/text-size resources in the captured diff; the data, focus, A and B seams above are the same.

This capture also revealed a diagnostic bug in CAM's analyzer: unrelated tooltip/cost `ItemsSource` bindings mentioning `ElementName=ActionRadials` were being mistaken for root controller sources. The analyzer must identify collection names, not arbitrary occurrences of "ActionRadials".

## Revised technical plan

### Phase A — current game-file capture

Use a read-only tool that:

1. resolves the installed BG3 package;
2. scans package files with pinned LSLib;
3. lists matches for `ActionRadials.xaml` and `PreloadedActionRadials_c.xaml`;
4. extracts only those matching XAML files;
5. records source PAK, packaged path, SHA-256 and BG3 package version;
6. performs no write to the game install or profile.

### Phase B — native contract audit

The capture tool performs the first audit automatically and emits `native-contract-analysis.json` / `.txt`.

It must identify without guessing:

- candidate main controller collection bindings;
- per-bar `SlotList` materialization bindings separately from root collection candidates;
- keyboard-only bindings separately;
- nested `SingleHotBar` / variant state;
- list/paging/grid/radial materialization structure;
- focus and scroll bindings;
- `UIAccept` command + parameter;
- top-level and nested `UICancel` behavior;
- conflicting base/patch copies of the same radial XAML.

The implementation gate is fail-closed: incomplete scans, missing controller-source evidence, conflicting native copies, missing cancel/focus or missing nested-state evidence remain explicit blockers.

Then compare those facts with Patch 8 shared resources and state-machine files.

### Phase C — minimal grid candidate

Only after Phase B:

1. retain the current native data, focus, selection and cancel seams;
2. alter only the geometry/composition necessary to replace radials with a compact grid;
3. statically verify the packaged candidate against the captured contract;
4. request one combined runtime test for rendering, focus, B and one simple A dispatch.

## Remaining unknown

The high-value static contract unknowns are closed by the installed-game capture.

What remains is runtime-only proof of the rebuilt presentation:

1. `ControllerHotBars` renders through the custom grid;
2. controller focus moves through cells and the scroll view follows it;
3. top-level B reaches `CloseWidget`;
4. nested B reaches `ClearSingleHotbarCommand` when a nested selection is opened;
5. one simple A reaches native `UseSlotCommand(focused slot)` exactly once.

These must be checked together in one milestone run. No additional speculative builds should be inserted between these assertions.


## 11. Resource-filter visual boundary: deck filters are not resource filters

The 0.0.73 runtime result exposed a terminology/presentation mistake in CAM's research.

Keyboard `HotBar.xaml` contains at least two independent filter-like surfaces:

1. **Deck/category filter buttons** — textual controls such as Common/Class/Items/Passives, historically presented through `FilterButton / ActiveFilterButton` and the `btn_pil_*` asset family.
2. **Action-resource filter bar** — icon/resource controls whose data source is `CurrentPlayer.UIData.ActionResourcesCostPreview` and whose selection invokes `FilterActionResourceCommand`.

The operator's visual reference is the second surface. Therefore the 0.0.73 use of `btn_pil_*` for CAM's resource tabs was structurally the wrong component even though those assets are genuinely used elsewhere by HotBar.

Historical/public HotBar markup confirms the separation and shows a resource strip built around 72px resource controls and `LSActionPointResources`, but historical markup is not authoritative for Patch 8 styling. The repo already has a read-only extractor that captures `*HotBar*.xaml` from the installed Xbox App `Game.pak`. The exact current file must be captured and inspected before another presentation change.

Implementation gate:
- do not infer current resource-filter chrome from the textual deck filters;
- do not promote old public HotBar XAML to Patch 8 truth;
- use the freshly captured installed `Mods/MainUI/GUI/Pages/HotBar.xaml` as the visual authority;
- keep the proven `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList` semantics unchanged.


## 12. Exact 1.8.910.0 Action Resources presentation

The operator returned the 0.0.74 read-only capture from Xbox App package `1.8.910.0`. The archive contains `Mods/MainUI/GUI/Pages/HotBar.xaml` at the already-pinned SHA-256 `9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.

This closes the remaining visual ambiguity.

The current HotBar has a dedicated resource strip:

```text
ActionResourcesContainer
  HotbarBodyResourcesBg -> bar_resources.png
  ActionResources
    ActionResourcesList
      VMActionResourceCostPreview
        72px resource button
          box_resource_* chrome
          LSActionPointResources
          optional RomanNumeralLevelImage
          conditional large-value numeral
```

Important exact values:

- `HotbarBodyResourcesBg`: height 64, min width 208, `Slices=104,0`, width = `ActionResources.ActualWidth + 208`;
- resource LSButton: `Padding=0`, `Margin=4,-10,4,10`;
- resource root: width 72;
- item container ContentPresenter: `Margin=-4,0,-4,0`;
- renderer sizes: 24 / 56;
- SpellSlot/WarlockSpellSlot switches to `box_resourceNum_*` and offsets that chrome by -8px;
- spell numeral image uses `RomanNumeralLevelImage` at top margin -10px;
- value 0 uses the missing resource chrome;
- the scalar number is hidden by default and shown only when the resource value exceeds the point renderer's `MaxGroupActionPoints`.

The same file separately defines `FilterButton / ActiveFilterButton` using `btn_pil_*` for textual deck/category controls. This proves 0.0.73 used a genuine HotBar component, but the wrong one.

CAM should therefore adapt the exact Action Resources presentation while retaining its controller-only selection semantics rather than copying the textual filter pills.
