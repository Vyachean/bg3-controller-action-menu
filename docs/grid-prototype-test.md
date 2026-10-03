# Grid prototype test

Version: `0.0.2-grid-prototype`

## What this build changes

This is the first functional attempt to replace the controller radial presentation.

It keeps BG3's native `DCHotBar` view model and native `UseSlotCommand`, but presents the existing hotbar/radial slots as vertically stacked controller grids.

The visual direction intentionally follows the controller Spell Book / spell-preparation screens:

- square icon cells;
- directional controller focus;
- scrollable grid;
- native tooltips;
- no radial-page carousel.

This prototype still groups entries using the existing native hotbar groups. Spell-level grouping and final category tabs come after the native dispatch proof.

## Test

1. Install the released `.pak`.
2. Load a save with a controller.
3. Open the normal action menu.
4. Confirm whether the radial is replaced by the grid.
5. Move focus in all four directions.
6. Select:
   - one normal action;
   - one spell;
   - one item if available.
7. Press B to close the menu.

## Expected proof

A successful run proves:

- the Patch 8 `ActionRadials` state override loads;
- `DCHotBar` bindings are still compatible;
- `CurrentPlayer.SelectedCharacter.HotBars` is available;
- focused `VMHotBarSlot` entries can be fed directly to `UseSlotCommand`;
- controller focus and scrolling work without custom Lua navigation.

## If the page fails

The manual probe is still available from the Script Extender console:

`!cam_probe`

The probe is no longer automatic in this build.
