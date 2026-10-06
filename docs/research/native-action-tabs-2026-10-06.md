# Native action-tab evidence audit — 2026-10-06

## Purpose

Record the evidence boundary for the first automatic tabbed CAM milestone without turning historical BG3 UI data into a Patch 8 runtime assumption.

## Current installed-game evidence

The repository's read-only Xbox App capture for BG3 1.8.910.0 is the authoritative source for the ActionRadials surface.

It proves the current radial/assignment contract used by CAM:

- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.SpellsAndActions`;
- `CurrentPlayer.SelectedCharacter.Stats.Passives`;
- `Data.TogglablePassivePredicate`;
- `Data.TogglableMetaMagicPassivePredicate`;
- `CurrentPlayer.SelectedCharacter.Inventory.Slots`;
- assignment-grid focus based on `AssignList + LocalFocusSelector + LSGrid`;
- root tab input events `UITabPrev` / `UITabNext`;
- page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- native `SingleHotBar.SlotList` nested choices and B lifecycle.

These bindings are sufficient to build source-oriented tabs without inventing an action model.

## Current public Patch 8 audit

The contemporary Patch 8 resource mirror used by this project exposes current UI resources including controller state-machine files and `DataTemplates.xaml`, but it does not currently publish the SpellBook/HotBar XAML required to independently verify the exact current SpellBook action-group bindings.

Repository/global code searches for these exact names:

- `CantripGroupPredicate`;
- `SpellLevelsGroupPredicate`;
- `AllActionsGroupPredicate`;

resolve to the older public `SpellBook_c.xaml` dump. That dump remains useful as design evidence, but it is not sufficient by itself to establish the concrete Patch 8 shipping contract.

## Historical SpellBook evidence

The old public SpellBook demonstrates native BG3 concepts that match the desired UX:

- an `LSListBox` tab/carousel controlled by `UITabPrev` / `UITabNext`;
- `VMActionGroup` objects with game-provided group names/actions;
- cantrip, spell-level and action grouping;
- passives and metamagic;
- controller grid presentation.

This justifies the design direction, not the exact current predicate/property names.

## 0.0.35 implementation decision

The milestone uses only current installed-game source boundaries:

| Tab | Current native source |
| --- | --- |
| Actions / Spells | `PlayerCharacterProperties.SpellsAndActions` |
| Items | `Inventory.Slots` |
| Passives | `Stats.Passives` filtered with `TogglablePassivePredicate` |
| Metamagic | `Stats.Passives` filtered with `TogglableMetaMagicPassivePredicate` |

The tab index controls presentation only. It does not copy actions or change execution semantics.

Empty filtered Passives/Metamagic tabs are collapsed. There is no `Custom` tab.

The milestone deliberately does **not**:

- classify actions by `SpellSlotLevel`;
- classify by slot type/name/icon/resource;
- hard-code `CantripGroupPredicate`, `SpellLevelsGroupPredicate` or `AllActionsGroupPredicate`;
- read keyboard or controller hotbar `SlotList` as the main catalog;
- add any radial customization workflow.

## Next proof boundary

Fine-grained headings such as Cantrips / Level I / Level II / Actions should be added only after the current installed Patch 8 SpellBook resource (or equivalently strong current evidence) confirms the exact native action-group collection/predicate contract.

That future change should remain presentation-only: BG3 group objects and names determine membership and labeling.

The 0.0.35 runtime milestone is instead responsible for proving:

- `UITabPrev` / `UITabNext` tab switching;
- empty-tab navigation;
- focus return to the selected grid;
- sensible focus when revisiting tabs;
- automatic content population;
- one direct A dispatch;
- top-level B;
- nested `SingleHotBar` behavior when encountered.
