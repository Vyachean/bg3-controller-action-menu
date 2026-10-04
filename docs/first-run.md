# First in-game run

Use **v0.0.5-first-run-diagnostics** or newer. Older candidates do not collect enough information for a one-session diagnosis.

## Before launching BG3

For this first diagnostic session only, enable Script Extender runtime logging in the game's `bin/ScriptExtenderSettings.json`.

If the file already exists, preserve its existing settings and add:

```json
"LogRuntime": true
```

If it does not exist, a minimal file is:

```json
{
  "LogRuntime": true
}
```

The mod itself enables Script Extender's Noesis error reporting, so XAML/resource failures are written to the runtime log when `LogRuntime` is enabled.

## Install

Install:

`BG3ControllerActionMenu-0.0.5-first-run-diagnostics.pak`

Enable it in the normal BG3 mod load order and start the game through Script Extender.

Do not run `cam_probe` manually. Diagnostics are automatic and bounded.

## One-session test sequence

After loading a save with controller UI active:

1. Open the normal controller action menu.
2. Move focus left/right/up/down across several entries.
3. Move far enough to cross at least one action/spell group boundary and force scrolling.
4. Focus a normal action.
5. Open a spell/action that has a nested choice, variant, or upcast option if one is available.
6. Move focus inside the nested selection and press **B** to go back.
7. Open the action menu again.
8. Select one ordinary action or spell far enough to enter BG3's native targeting/execution flow.
9. Cancel targeting if you do not want to actually perform it.
10. Close the action menu.

If the custom page is blank, broken, or does not appear, do not troubleshoot manually in that session. Close the game after reproducing it once; the diagnostics are designed to preserve the failure evidence.

## Files to provide after that same session

### 1. Automatic mod diagnostics

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\BG3ControllerActionMenu\diagnostics.json`

This file records:

- game version;
- Script Extender API version;
- session state;
- controller button sequence;
- whether `CAM_ActionMenu` was created;
- whether vanilla `ActionRadials` was seen instead;
- relevant Noesis UI nodes and filenames;
- runtime UI/DataContext types;
- `DCHotBar` properties and native commands;
- `UseSlotCommand:CanExecute` for the focused action;
- action-group and hotbar counts plus bounded samples;
- focused action identity/properties;
- `SingleHotBar` variant/upcast state;
- named grid/scroll/variant elements and item counts;
- internal diagnostic exceptions;
- an automatic `FailureClass`.

### 2. Script Extender runtime log

Upload the newest file matching:

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender Logs\Extender Runtime *.log`

This is needed mainly if the page cannot be created at all. The mod calls `Ext.UI.EnableErrorReporting(true)`, so Noesis XAML/resource errors are emitted into this log.

## What should be diagnosable from one session

The pair `diagnostics.json + Extender Runtime log` is intended to distinguish:

- mod/Lua did not load;
- ActionRadials state override did not apply;
- custom XAML failed to load;
- a native resource dictionary/key failed to resolve;
- wrong DataContext;
- missing `SpellsAndActions`;
- action groups are empty or malformed;
- controller focus was never established;
- focused action is wrong;
- `UseSlotCommand` is unavailable or cannot execute the focused action;
- nested `SingleHotBar` variants/upcast did not appear;
- B/back behavior did not restore the main grid.

The recorder does not execute discovered commands on its own; it only observes them and calls `CanExecute`.
