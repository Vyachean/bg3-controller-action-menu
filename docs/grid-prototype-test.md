# Grid prototype — historical runtime result

Version: `0.0.2-grid-prototype` and later descendants through the first Xbox runtime sequence.

## Status

This prototype is **superseded research**, not a build the user should test.

The original implementation assumed the Patch 2 binding `CurrentPlayer.SelectedCharacter.HotBars` was still the Patch 8 controller collection. Real Xbox App runs later proved that the override/page shell could load while this grid remained empty.

The public source behind that assumption was subsequently dated to Patch 2 Hotfix 1 (2023-09-06).

## What the failed prototype still proved

Real Xbox App testing established:

- CAM can override the Patch 8 `ActionRadials` state;
- the shipping ordinary `.pak` is actually loaded by the Xbox App build;
- the `HotBar` context/root lifecycle is active enough for `CurrentPlayer.UIData.AreRadialsOpen`;
- imported native resources can render;
- package replacement/version changes reach the game.

It did **not** prove:

- `CurrentPlayer.SelectedCharacter.HotBars` is the current controller source;
- the custom section/materialization hierarchy is compatible;
- its B/cancel implementation is correct;
- its controller focus graph is correct.

## Current implementation gate

Before another runtime candidate:

1. identify the current controller-radial collection/materialization path;
2. keep Patch 8 `HotBarSlotStyle` for slot rendering and `UseSlotCommand(slot)` dispatch;
3. preserve native focus-driven scrolling;
4. ground radial-specific cancel behavior in current evidence;
5. change only composition/layout;
6. statically/package-verify those seams;
7. combine rendering, focus, B and one simple A dispatch into one milestone game test.

See `docs/research/open-source-findings.md` and `docs/native-ui-capture.md`.
