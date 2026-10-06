# First in-game run — Xbox App / PC

Use **v0.0.34-auto-action-catalog** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Install/update CAM

Download `BG3ControllerActionMenu-OneClickInstaller.zip` from the newest GitHub release and extract it once.

Double-click:

`Install-BG3ControllerActionMenu.vbs`

No console window is shown. The bundled bootstrap resolves the newest published development release and hands off to its canonical installer. The current installer downloads the already-built self-contained PAK and installs it directly; it does not inspect `Game.pak` or build UI resources on this machine.

After this self-updating OneClickInstaller has been extracted once, future installer-internal changes should not require replacing the folder.

On success a normal Windows dialog shows the installed version.

On failure, inspect:

- `%LOCALAPPDATA%\BG3ControllerActionMenu\install-latest.log`;
- `%LOCALAPPDATA%\BG3ControllerActionMenu\xbox-dev-environment.json`.

Do not manually copy files when the installer refuses the target.

## Single milestone UI test

After a successful install, perform **one combined run**:

1. launch BG3 normally through Xbox App;
2. use a disposable/pre-mod save;
3. switch to controller UI and open the normal action menu;
4. confirm the main menu is one automatically populated grid/catalog rather than a set of user-configured radial pages;
5. confirm actions that were **not manually placed into radial wheels** are present (for example compare against the native “choose action for radial slot” screen);
6. confirm spells/actions, relevant passive/metamagic entries and inventory items populate from the selected character automatically;
7. confirm there is **no X / Customize / Radial Customisation** prompt and pressing X does not enter radial editing;
8. move with D-pad/stick through several rows/groups and confirm focus remains aligned with the selected cell and the view follows focus;
9. press A on one simple direct action (for example Jump) and confirm BG3 enters its normal action/targeting path;
10. press B from the top level and confirm the menu closes;
11. if A naturally opens an upcast/variant/container choice, confirm the nested `SingleHotBar` grid appears and B returns from it correctly.

This run is intentionally focused on the remaining runtime-only seam: whether BG3's existing `UseSlotCommand` accepts the same native action candidates that the radial-assignment catalog exposes. Everything else in this candidate is checked in CI.

There is deliberately no CAM-owned gameplay execution logic and no radial customization workflow. BG3 remains responsible for availability, costs, targeting, variants/upcasts and execution.

Do not overwrite an important campaign save during this external-PAK development test.
