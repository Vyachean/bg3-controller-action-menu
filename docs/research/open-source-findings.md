# Open-source findings: controller action UI

## Conclusion

The project does **not** currently need a manual extraction of `PreloadedActionRadials_c.xaml` as a prerequisite.

Public sources expose enough of BG3's hotbar model and the current Script Extender Noesis API to build a small runtime probe that discovers the remaining radial-specific bindings automatically.

The exact current radial DataContext property names and dispatch command names are still unverified. They should be discovered from the live UI rather than guessed.

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

### Phase A — automated radial probe

Build a temporary diagnostic Script Extender module that activates only while the controller radial is visible.

It should:

1. start at `ContentRoot`;
2. locate nodes whose name/file/type suggests the radial page;
3. record:
   - widget name;
   - `FileName`;
   - runtime Noesis type;
   - DataContext type;
   - all DataContext property names;
4. classify values:
   - collections;
   - commands;
   - primitive state;
   - nested viewmodels;
5. for likely action collections, inspect a small number of entries and record their property names;
6. never mutate or execute anything in the discovery pass.

### Phase B — dispatch proof

After the probe identifies likely commands:

1. bind a temporary test control to the native action entry/command;
2. call the same native command path the radial uses;
3. verify one simple action enters BG3's normal targeting/execution flow.

### Phase C — grid

Only after Phase B passes, replace the temporary presentation with tabs + grid.

## Manual-test requirement

This changes the expected manual workload.

We should **not** ask the user to extract game XAML manually.

The first useful manual test should be one instrumented build:

1. open BG3 with a controller;
2. open the normal action radial once;
3. close it;
4. provide the generated probe log.

That single run should reveal the current radial DataContext, collections and command surface. If the data is sufficient, the next manual run can already test the first functional grid/dispatch proof.

## Remaining unknown

Open sources found so far do not publish the exact current property names for the action collection and selection command inside `PreloadedActionRadials_c.xaml`.

That is now a small runtime-discovery problem, not an architectural blocker.
