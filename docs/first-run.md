# First in-game run — Xbox App / PC

Use **v0.0.21-one-click-installer** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Install/update CAM

Download `BG3ControllerActionMenu-OneClickInstaller.zip` from the newest GitHub release and extract it once.

Then double-click:

`Install-BG3ControllerActionMenu.vbs`

No console window is shown. The launcher automatically selects the newest published release, downloads the matching CAM `.pak` and current fail-closed installer, verifies their GitHub SHA-256 digests, and installs them.

On success it shows a normal Windows dialog with the installed version.

On failure it fails closed and points to:

- `%LOCALAPPDATA%\BG3ControllerActionMenu\install-latest.log`;
- `%LOCALAPPDATA%\BG3ControllerActionMenu\xbox-dev-environment.json`.

Do not manually copy files when the installer refuses the target; the report is the diagnostic evidence.

## Single milestone UI test

After a successful install, perform **one combined run**:

1. launch BG3 normally through Xbox App;
2. use a disposable/pre-mod save;
3. switch to controller UI and open the normal action menu;
4. confirm the gameplay view remains visible behind the local panel;
5. confirm the grid is populated and the diagnostic overlay reports a non-zero `Controller bars` / `Sections` count;
6. move focus in all four directions far enough to require scrolling and confirm the scroll view follows focus;
7. press B from the top level and confirm the menu closes;
8. reopen the menu and use A on one simple non-container action (for example Jump or another ordinary action) and confirm BG3 enters its normal action/targeting path;
9. if that action or another visible slot naturally opens a nested variant/upcast/container menu during the same run, press B once there and confirm it returns to the main grid rather than closing the whole menu.

Do not perform separate runs for each assertion. If something fails, one screenshot (or a short video if focus/scroll is the failure) plus the visible diagnostic overlay is sufficient.

The prerelease includes an on-screen diagnostic panel so this single run can distinguish page-load, controller-source, focus and nested-state failures without Script Extender.

Do not overwrite an important campaign save during this external-PAK development test.
