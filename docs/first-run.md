# First in-game run — Xbox App / PC

Use **v0.0.20-patch8-list-grid** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Download the CAM candidate

Download both release assets into the same folder:

- `BG3ControllerActionMenu-0.0.20-patch8-list-grid.pak`
- `install-xbox-dev.ps1`

### 3. Run the read-only discovery

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

Nothing in BG3 is modified. The script produces `xbox-dev-environment.json`.

### 4. If the target is proven, install

If the script says:

`A unique, evidence-backed Xbox mod target was found.`

run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply
```

If it says anything else, do not manually copy files. Send `xbox-dev-environment.json` instead.

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
