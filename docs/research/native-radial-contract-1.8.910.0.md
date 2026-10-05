# Native radial contract — Xbox App 1.8.910.0

## Evidence

Captured read-only from the installed Xbox App / Microsoft Store PC build on 2026-10-05 with `tools/capture-native-radials.ps1`.

Game package:

`LarianStudiosGamesLtd.baldurssgate3 1.8.910.0`

The proprietary game XAML itself is **not** committed to this repository. This document records only paths, hashes and derived contract facts needed by CAM.

| Packaged path | SHA-256 |
| --- | --- |
| `Mods/MainUI/GUI/Pages/ActionRadials.xaml` | `bce01b1043915eda64277e4f5a3d9b9f0893ac9226b32cb9d394a4bea325371a` |
| `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` | `4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b` |
| `Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml` | `cbd5141734063dce4e41b319775eefc3b905e4b42c86bbe37f3fbf16e20e2bba` |

All three came from `Game.pak`. The capture scanned 74 PAKs with zero scan errors.

## Root page

The current `ActionRadials.xaml` is a thin `ls:UIWidget`:

- name: `ActionRadials`;
- context: `HotBar`;
- design VM: `DCHotBar`;
- template: `ActionRadialWidgetTemplate_P8`.

The actual controller radial composition lives in `PreloadedActionRadials_c.xaml`.

## Main controller data

The current root collection is:

`CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`

The native `HotBarList` materializes each bar with:

`PagedList ItemsSource="{Binding SlotList}"`

The native list suppresses `PassivesHotBar` and `FixedSideBar` as ordinary radial pages.

This replaces the obsolete Patch 2 assumption:

`CurrentPlayer.SelectedCharacter.HotBars`

and must not be replaced with the separately proven keyboard collection:

`PlayerCharacterProperties.KeyboardHotBars`.

## Nested state

Current nested materialization is:

`SingleHotBar.SlotList`

Current nested/variant state also exposes:

- `CurrentSingleHotbarFilter`;
- `IsShowingAContainerWithVariants`;
- `IsSelectingUpcastedSpell`;
- `IsShowingItemsToThrow`.

## Focus and scrolling

The current main radial list uses:

`LSScrollViewer.ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"`

The current root `ActionRadials.xaml` maps only:

- `FocusLeft="UITabPrev"`;
- `FocusRight="UITabNext"`.

It does **not** map `UILeft/UIRight/UIUp/UIDown` directly at the root.

More importantly, the captured Patch 8 preloaded template already contains a working 2D controller grid in the radial slot-assignment UI. Its structure is:

```text
LSListBox (Focusable=False)
  ItemContainerStyle -> focusable ListBoxItem
  ItemsPanel         -> LSGrid
                         ActionUpEvent    = UIUp
                         ActionDownEvent  = UIDown
                         ActionLeftEvent  = UILeft
                         ActionRightEvent = UIRight
                         AutoIndex        = True
```

The same preloaded file uses this pattern for spell/action, passive and metamagic slot grids.

This is stronger evidence than importing navigation flags from unrelated screens. CAM's grid should therefore use `LSListBox + focusable ListBoxItem + LSGrid` and leave the four `UI*` directional events to that grid rather than intercepting them at the root.

CAM should preserve the same focus-driven scroll model rather than script its own navigation.

## Normal A dispatch

The captured radial does **not** rely on a focused slot's generic `HotBarSlotStyle.BoundEvent` for normal controller A.

The page owns a hidden binding equivalent to:

```text
Focused radial slot
      |
      v
ActionRadials.Tag
      |
   UIAccept
      |
      v
UseSlotCommand(Tag)
```

Contract:

- `BoundEvent="UIAccept"`;
- `Command="{Binding UseSlotCommand}"`;
- `CommandParameter="{Binding Tag, ElementName=ActionRadials}"`.

CAM may still reuse `HotBarSlotStyle` for native square cell visuals, but controller A should follow this page-level seam.

## B / UICancel

Default native B:

- `BoundEvent="UICancel"`;
- `Command="{Binding ClearSingleHotbarCommand}"`.

At the top level, when:

- `SingleHotBar.SlotList.Count == 0`; and
- `IsShowingItemsToThrow == False`;

the native template switches the same button to:

- `Command="{Binding CustomEvent}"`;
- `CommandParameter="CloseWidget"`.

The native template also forces `CloseWidget` for shapeshifted characters, summons and followers.

In `InSwapSlotState`, B changes to:

- `UseSlotCommand(null)`;

and normal A dispatch is disabled.

## Duplicate preloaded dictionaries

The normal and Clairmont preloaded dictionaries agree on the data, focus and A/B contracts above.

Their captured differences are presentation-only:

- radial scale resources;
- one scaled font-size resource.

Those differences do not change CAM's runtime contract.

## Resource-library hook

Official BG3 UI documentation states that:

- `Lib_Controller.xaml` is the library loaded in controller mode;
- mod Resources/Libraries are loaded before mod StateMachines;
- libraries are the supported place for reusable `ControlTemplate` and `Style` resources.

Reference: https://docs.baldursgate3.game/index.php?title=UI

Runtime 0.0.18–0.0.20 showed that replacing the entire `ActionRadials` state/page leaves controller focus/input dead even when the data and rendering are correct. The preferred hook is therefore the controller resource library, while BG3 retains its native state and `MainUI/Pages/ActionRadials.xaml`.

This also gives a safer failure mode: if CAM's `ActionRadialWidgetTemplate_P8` resource does not win resource lookup, BG3 still has a valid native state/page and should fall back to the vanilla radial UI.

## Implementation consequence

The first candidate built from the captured data evidence was `0.0.18-native-controller-contract`.

The current implementation gate for `0.0.23-native-page-library-override` is:

1. do **not** package a CAM `ActionRadials` StateMachine override;
2. do **not** package a CAM replacement Page;
3. load CAM through `GUI/Library/Lib_Controller.xaml`;
4. override the `ActionRadialWidgetTemplate_P8` resource consumed by the native page;
5. source from `ControllerHotBars`;
6. render per-bar `SlotList`;
7. render nested `SingleHotBar.SlotList`;
8. update native `ActionRadials.Tag` from grid focus;
9. keep captured `UIAccept -> UseSlotCommand(Tag)` and native main/nested B semantics;
10. keep the gameplay view visible;
11. remain Script-Extender-free.
