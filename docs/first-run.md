# First in-game run — Xbox App / PC

Use **v0.0.7-xbox-dev-installer** or newer.

This candidate contains **no Script Extender**.

## Install

Download these two assets from the same GitHub release into one folder:

- `BG3ControllerActionMenu-0.0.7-xbox-dev-installer.pak`
- `install-xbox-dev.ps1`

Before the first install:

1. Launch Baldur's Gate 3 from Xbox App.
2. Open the in-game **Mod Manager** once.
3. Exit BG3 normally.

Then open PowerShell in the folder with the two downloaded files and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1
```

The installer will:

- find the Xbox/Microsoft BG3 package cache;
- find the active `modsettings.lsx` under that cache;
- back up the existing load order;
- copy the `.pak` into the Xbox `LocalCache\Local\Mods` directory;
- remove any old entries for this mod's UUID;
- add exactly one entry to `ModOrder` and one to `Mods`;
- reopen the file and verify the entries.

If it cannot identify the cache or load-order structure safely, it stops **before modifying anything**.

## Test

1. Launch BG3 normally from Xbox App.
2. Load a disposable/test save with controller UI active.
3. Open the normal controller action menu.
4. Take a screenshot immediately.
5. Move left/right/up/down across several actions and groups.
6. Take another screenshot.
7. If available, open an upcast/variant action and take a screenshot.
8. Press B and check that you return to the main grid.
9. Select one ordinary action/spell and verify BG3 reaches its normal targeting/execution flow.

Do not save over an important campaign save during this external-`.pak` development test.
