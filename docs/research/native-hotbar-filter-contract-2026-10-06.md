# Native hotbar execution/filter contract — 2026-10-06

## Why 0.0.36 is not the right top-level architecture

The Xbox App runtime result for `0.0.36-tab-focus-dispatch` proves that fixing tab-local focus ownership is not sufficient:

- directional navigation can become trapped after reaching the bottom row;
- A does not execute the selected action;
- action containers / nested choices do not open;
- the action-resource bar does not preview the selected action's cost;
- CAM-authored shoulder-hint presentation does not match the native controller chrome;
- source tabs do not behave like the keyboard hotbar's filters.

These failures share one boundary mistake: CAM uses the **radial assignment catalog** as if it were the **runtime hotbar execution model**.

## Current Patch 8 slot-wrapper evidence

Current Patch 8 `DataTemplates.xaml` shows that `HotBarSlotStyle` is a style for an `ls:LSButton` whose data context is the hotbar slot wrapper.

The style:

- renders the slot's `Content` as `VMCharacterAction`, `VMUpcast`, `VMItem`, `VMPassive`, etc.;
- binds `UseSlotCommand` with `CommandParameter="{Binding}"`;
- invokes `HighlightResourcesCommand` with the same slot wrapper on hover;
- invokes `ClearResourceHighlightsCommand` with the same slot wrapper when leaving.

Therefore the execution/resource-preview object is the **VMHotBarSlot wrapper**, while the visible action/item/passive is its `Content`.

The 0.0.34–0.0.36 automatic assignment catalog instead exposes raw assignment candidates. Passing those candidates directly to `ActionRadials.Tag -> UseSlotCommand` is not equivalent to the native hotbar path.

## Controller radial corroboration

The installed Patch 8 capture already proves:

- page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- `SingleHotBar.SlotList` for container/upcast/variant second stages;
- `CurrentSingleHotbarFilter`;
- native B via `ClearSingleHotbarCommand`, switching to top-level close when no second stage is active.

Historical ActionRadials XAML provides compatible behavioral precedent: radial focus writes the focused **slot** into the page tag and invokes tooltip/resource-highlight commands for that slot.

The historical file is not used as a current binding contract; it only explains why the current runtime symptoms line up with the missing slot wrapper.

## Keyboard hotbar filter model

Engine data and historical hotbar UI agree on two independent axes:

1. **deck/type** — Common, Class, Items, with Passives as a separate native deck;
2. **resource/action filter** — Action, Bonus Action, spell-slot resources, cantrips and class-specific action resources.

Engine hotbar bars have an index mapping `0=Common, 1=Class, 2=Item`.

Historical `HotBar.xaml` exposes the intended UI model through names such as:

- `CurrentShownDeck`;
- `SetCurrentShownDeckCommand`;
- `CurrentSingleHotbarFilter`;
- `FilterActionResourceCommand`;
- `FilterCantripsCommand`;
- `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- `CurrentPlayer.SelectedCharacter.PassivesHotBar`.

Those exact names are **historical evidence until the installed current HotBar resource confirms them**.

## New proof boundary

The installer already derives controller UI from the user's exact installed `Game.pak`. The next architecture extends that same boundary to the keyboard `HotBar.xaml`:

1. extract the current installed HotBar resource;
2. require the native deck/filter/slot seams needed by CAM generation;
3. generate the controller library from the installed radial + installed hotbar contracts;
4. never infer filter membership from spell names, `SlotType`, `SpellSlotLevel` or CAM-owned resource lists.

A missing native seam is a compatibility failure in generation, not permission to silently fall back to assignment candidates.

## Next top-level composition

The top-level CAM surface becomes:

```text
native deck/resource filter state
            |
            v
native VMHotBarSlot collection
            |
            v
one flat controller LSGrid
            |
            +--> focus tooltip/resource preview
            |
            v
ActionRadials.Tag = VMHotBarSlot
            |
            v
UIAccept -> UseSlotCommand(slot)
            |
            v
native SingleHotBar.SlotList for container/upcast/variant
```

Rules:

- one flat focus owner/grid for the visible result set;
- no nested assignment-group lists at top level;
- no raw assignment candidate may be passed to `UseSlotCommand`;
- resource highlighting follows the native hotbar slot command path;
- deck/resource filters are native DCHotBar semantics;
- `Custom` is excluded because CAM is automatic, not a user-managed layout;
- the original native controller button-hint container layout is preserved; CAM only removes radial-edit actions;
- CAM does not add its own LB/RB hint presenters.

## Runtime proof remaining

After static/package proof, one game run should verify together:

1. grid navigation can travel from first to last rows and back without a focus trap;
2. the focused action description follows the slot;
3. bottom resource preview highlights the selected slot's real cost;
4. A executes a simple action;
5. A opens a container/upcast/variant second stage when appropriate;
6. B returns from the second stage and closes at top level;
7. deck/resource filters change the visible VMHotBarSlot set;
8. button hints retain the original vertical/native layout with no stray shoulder text.
