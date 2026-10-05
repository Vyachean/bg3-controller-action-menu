# First in-game run — Xbox App / PC

Use **v0.0.23-native-page-library-override** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Install/update CAM

Download `BG3ControllerActionMenu-OneClickInstaller.zip` from the newest GitHub release and extract it once.

Double-click:

`Install-BG3ControllerActionMenu.vbs`

No console window is shown. The launcher automatically downloads the newest published CAM release, verifies the GitHub SHA-256 digests for both the PAK and the current Xbox installer, then runs the fail-closed installation.

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
5. confirm the CAM diagnostic overlay is visible and `Controller bars` is non-zero; if the overlay is absent and the vanilla radial appears, stop there — that means the library override did not win, but the native state/page remained safe;
6. move focus in all four directions far enough to require scrolling and confirm the scroll view follows focus;
7. press B from the top level and confirm the menu closes;
8. reopen the menu and use A on one simple non-container action (for example Jump or another ordinary action) and confirm BG3 enters its normal action/targeting path;
9. if that action or another visible slot naturally opens a nested variant/upcast/container menu during the same run, press B once there and confirm it returns to the main grid rather than closing the whole menu.

Do not perform separate runs for each assertion. If something fails, one screenshot (or a short video if focus/scroll is the failure) plus the visible diagnostic overlay is sufficient.

The prerelease includes an on-screen diagnostic panel inside the controller-library template. The native BG3 state/page are no longer replaced, so failure to apply the resource override should fall back to the normal radial rather than trap the player in a dead custom page.

Do not overwrite an important campaign save during this external-PAK development test.
