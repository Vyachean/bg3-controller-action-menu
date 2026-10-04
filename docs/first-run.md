# First in-game run — Xbox App / PC

Use **v0.0.6-xbox-app-candidate** or newer.

This candidate intentionally contains **no Script Extender**.

## Install first

Do **not** place the test `.pak` only in:

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`

That is the normal Steam/GOG workflow and is not sufficient for the Xbox Play Anywhere build.

Follow [xbox-app-installation.md](xbox-app-installation.md) and make sure the mod is actually present in the Xbox package cache and active in the Xbox profile load order before testing.

## Diagnostic panel

When the custom action page loads, a small panel appears in the top-right corner.

It shows:

- **Action groups** — number of native `SpellsAndActions` groups;
- **Hotbars** — number of native hotbar groups;
- **Variant slots** — current `SingleHotBar` nested choices;
- **Variants open** — whether BG3 reports a variant container;
- **Upcast open** — whether BG3 reports upcast selection;
- **Radials flag** — native `AreRadialsOpen`;
- **Focus name** — current controller-focused UI element;
- **Focused usable** — native usability state for the focused action.

If action groups are zero, the panel also shows **NO ACTION GROUPS**.

## One-run test sequence

1. Open the normal controller action menu.
2. Take a screenshot immediately.
3. Move left/right/up/down through several actions.
4. Move far enough to cross a group boundary and force scrolling.
5. Take a second screenshot while an action is focused.
6. Open an action/spell with variants or upcast if available.
7. Take a screenshot of the nested selection.
8. Press **B** and confirm it returns to the main grid.
9. Open the menu again.
10. Select one ordinary action or spell and confirm it reaches BG3's normal targeting/execution flow.
11. Cancel targeting if desired.
12. Close the menu.

## What to send back

- screenshots from the steps above;
- a brief note for any failed step;
- if the game crashes, the newest crash/gold log available.

For the external-`.pak` Xbox workaround, use a disposable test save and avoid saving progress until save/reload behavior has been verified.
