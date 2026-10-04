# Architecture

## Objective

Replace Baldur's Gate 3 controller action radial browsing with a native-style grid while preserving BG3 gameplay semantics and supporting the Xbox App / Microsoft Store PC build.

## Runtime architecture

```text
BG3 controller ActionRadials state
              |
              v
        DCHotBar context
              |
              |
              v
           HotBars
        VMHotBarSlot
              |
              v
     native BG3 UI resources
 HotBarSlotStyle / SpellBook chrome
              |
              v
      thin custom composition
   groups + six-column LSGrid
              |
              v
     native action execution
```

The shipping `.pak` contains only ordinary BG3 mod resources. It has **no Script Extender, DLL, native loader or external runtime dependency**.

## Primary target

The primary runtime target includes:

- Xbox App / Microsoft Store PC;
- Steam PC;
- GOG PC.

A change that requires Script Extender is not acceptable for the primary package. Experimental SE-based tools may exist under `dev/` for developer research only.

## Boundary

The custom layer owns:

- replacing the `ActionRadials` page/state presentation;
- ordering native groups;
- grid column count/spacing;
- main-list vs `SingleHotBar` variant presentation;
- temporary visible diagnostics in prerelease candidates.

The custom layer should not own:

- whether an action is usable;
- spell slot/resource calculation;
- upcast rules;
- target validation;
- range/LOS checks;
- action execution;
- recast semantics;
- passive/class resource semantics;
- item counts/state;
- cell visuals already provided by native BG3 resources.

## Native widget contract

The replacement page must follow BG3's controller-widget structure:

- `ls:UIWidget.ContextName="HotBar"`;
- `ls:UIWidget.Template`;
- a `ControlTemplate` containing the interactive controls.

Do not build the interactive controller page through `UIWidget.ContentTemplate/DataTemplate`. Runtime testing showed that this can render visuals while failing to behave like the native DCHotBar controller widget for input/focus/data composition.

Inside the `ControlTemplate`, bindings that depend on `DCHotBar` must resolve explicitly through the owning `ls:UIWidget` (`DataContext.…` + `RelativeSource AncestorType=ls:UIWidget`). Do not assume that the template content inherits the runtime context in the same way as root-level interaction triggers.

## Native UI reuse

The current implementation consumes game-owned resources including:

- `DataTemplates.xaml`;
- `FocusableControls_c.xaml`;
- `Tooltips.xaml`;
- `HotBarSlotStyle`;
- `ExpanderButtonTemplateSpellBook`;
- `LS_InventoryGridSurround`.

Action cells should remain native. Recreating focus frames, disabled overlays, item counters, upcast indicators or tooltip rendering is an architecture regression unless a native resource is proven insufficient.

## Controller data

The main page uses:

- `CurrentPlayer.SelectedCharacter.HotBars` as the authoritative normal radial/action source;
- each hotbar's native `SlotList` / `VMHotBarSlot` entries for actions, spells, items and passives;
- `SingleHotBar.SlotList` for nested variants and upcast selections.

`SpellsAndActions` is intentionally **not** the main runtime source: BG3's native `ActionRadials.xaml` uses it inside the slot-assignment popup. The first Xbox runtime test proved that treating it as the normal menu source leaves the replacement menu empty.

Selection remains in the game's native action path through `HotBarSlotStyle`, whose native command binding invokes `UseSlotCommand` with the slot VM.

## First-run diagnostics without Script Extender

Because Xbox App cannot rely on Script Extender, the first Xbox candidate exposes a small on-screen diagnostic panel using ordinary XAML bindings.

It shows:

- action-group count;
- hotbar count;
- nested variant count;
- variant/upcast state;
- `AreRadialsOpen`;
- focused element name;
- focused action usability.

This does not replace full runtime introspection, but it makes the first Xbox run useful without introducing a third-party runtime dependency.

## Compatibility

UI mods can conflict when they override the same state/page. The current mod overrides the controller `ActionRadials` state, so another mod replacing that state can conflict by load order.

Prefer reusing native dictionaries and the smallest custom state/page surface possible.
