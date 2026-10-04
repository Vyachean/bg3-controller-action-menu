# Open-source findings: controller action UI

## Conclusion

The project **does need current native radial-file evidence before another in-game candidate**.

Public sources prove the Patch 8 state name, shared UI resources and the existence of the shipped/preloaded `PreloadedActionRadials_c.xaml`, but they do not publish that file's current action collection, materialization hierarchy or cancel/dispatch bindings.

The earlier public `ActionRadials.xaml` used as implementation evidence is Patch 2 Hotfix 1 from 2023-09-06. It is historical evidence only.

Instead of asking for repeated gameplay tests, use a read-only extractor to scan the installed current game PAKs and capture the native radial XAML first.

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

From the captured current files, document:

- root context and template structure;
- exact action/hotbar collection;
- nested slot hierarchy;
- focus and scroll path;
- `UIAccept` command + parameter;
- top-level and nested `UICancel` behavior;
- variant/upcast state.

Then compare those facts with Patch 8 shared resources and state-machine files.

### Phase C — minimal grid candidate

Only after Phase B:

1. retain the current native data, focus, selection and cancel seams;
2. alter only the geometry/composition necessary to replace radials with a compact grid;
3. statically verify the packaged candidate against the captured contract;
4. request one combined runtime test for rendering, focus, B and one simple A dispatch.

## Remaining unknown

Open sources found so far do not publish the exact current property names for the action collection and selection/cancel commands inside `PreloadedActionRadials_c.xaml`.

This is now a **game-file inspection problem**, not a reason for another speculative gameplay build.
