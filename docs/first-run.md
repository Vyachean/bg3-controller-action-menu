# First in-game run — Xbox App / PC

Use **v0.0.28-grid-presentation-cleanup** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Install/update CAM

Download `BG3ControllerActionMenu-OneClickInstaller.zip` from the newest GitHub release and extract it once.

Double-click:

`Install-BG3ControllerActionMenu.vbs`

No console window is shown. The bundled bootstrap first updates itself and the canonical installer from the newest published release when necessary, verifying GitHub SHA-256 digests. The current canonical installer then verifies the base PAK, Xbox installer and native-overlay builder and derives the installable PAK locally from this machine's exact BG3 `Game.pak`.

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
4. confirm the gameplay view remains visible behind the local panel;
5. confirm each action page is rendered as a square grid centered on the native page position;
6. confirm there is no dark circular radial backdrop behind the grid and no visible “Radial Customisation” hint;
7. move with D-pad/stick in all four directions and confirm selection moves cell-to-cell using the same controller behavior as the native “choose action for radial slot” screen;
8. press B from the top level and confirm the menu closes;
9. reopen the menu and use A on one simple non-container action (for example Jump) and confirm BG3 enters its normal action/targeting path;
10. if a nested variant/upcast/container opens naturally, press B once and confirm native nested cancel behavior still works.

Do not perform separate runs for each assertion. If something fails, one screenshot (or a short video if focus/scroll is the failure) plus the visible diagnostic overlay is sufficient.

There is deliberately no CAM-owned page or gameplay input dispatcher. The generated controller library preserves BG3's native outer ActionRadials template and A/B commands; only the per-page slot renderer uses the game's own slot-assignment grid focus pattern.

Do not overwrite an important campaign save during this external-PAK development test.
