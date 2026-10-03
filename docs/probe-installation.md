# Probe build installation

This is the first runnable diagnostic build. It **does not replace the radial menu yet** and does not execute actions.

## Requirements

- Baldur's Gate 3 Patch 8.
- BG3 Script Extender v30 or newer.
- A controller.

## Install

1. Download \`BG3ControllerActionMenu-probe.pak\` from the GitHub Actions artifact named \`BG3ControllerActionMenu-probe\`.
2. Copy the \`.pak\` to:

   \`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\`

3. Enable **BG3 Controller Action Menu** in your normal BG3 mod manager/load order.
4. Start the game with Script Extender.

## One required test

1. Load a save.
2. Use the controller.
3. Open the normal action radial once.
4. Move around the radial briefly.
5. Close it.

The probe listens only in short bounded bursts after controller input.

## Result

The probe writes:

\`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3ControllerActionMenu\probe.json\`

Send that file back for the next implementation step.

The Script Extender console should also contain a line like:

\`[BG3ControllerActionMenu] radial candidate captured: ...\`

## Manual fallback

If automatic detection does not trigger and the Script Extender console is enabled, run \`!cam_probe\`, then open the radial immediately.

To clear the existing capture, run \`!cam_probe_reset\`.

## Safety

- reads the live Noesis UI tree and DataContext properties;
- never calls discovered game commands;
- never mutates action state;
- does not touch saves;
- caps traversal depth and total visited nodes;
- stops each detection burst automatically.
