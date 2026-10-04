# First in-game run — Xbox App / PC

Use **v0.0.6-xbox-app-candidate** or newer.

This candidate intentionally contains **no Script Extender**.

## Install

1. Download the released `.pak`.
2. Copy it to:

   `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`

3. Launch the Xbox App version of Baldur's Gate 3.
4. Open the in-game **Mod Manager**.
5. Check **Installed** and make sure **BG3 Controller Action Menu** is present and enabled.
6. Load a save with controller UI active.

Do not copy the mod into the Xbox App installation directory or `WpSystem`.

## What the diagnostic panel means

The first candidate displays a small panel in the top-right corner when the custom action page loads.

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

Prefer:

- the screenshots from the steps above;
- a brief note for any step that failed;
- if the game crashes, the newest crash/gold log available from the game installation/report location.

If the mod does not appear in **Mod Manager → Installed**, send a screenshot of that screen and confirm the `.pak` is present in the Local AppData Mods folder.

If the mod appears and is enabled but the vanilla radial still opens, that is a state-override/load-order failure.

If the radial disappears or the page is blank, the diagnostic panel (or its absence) tells us whether the custom page reached the rendering/binding stage.

## Why no automatic JSON log

The Xbox App-compatible shipping package cannot depend on Script Extender. The previous SE-based JSON recorder is retained only under `dev/script-extender` for developer research and is not packaged.
