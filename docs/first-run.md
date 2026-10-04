# First in-game run — Xbox App / PC

Use **v0.0.16-template-dchotbar-context** or newer.

The runtime mod contains no Script Extender.

## When you get access to the gaming PC

### 1. Establish the real Xbox mod cache

Launch BG3 from Xbox App and install one small mod through the **built-in Mod Manager**. Enable it, then exit BG3 normally. That mod supplies both path evidence and the real `modsettings.lsx` schema for this Xbox build.

### 2. Download the CAM candidate

Download both release assets into the same folder:

- `BG3ControllerActionMenu-0.0.16-template-dchotbar-context.pak`
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

## First UI test

After a successful install:

1. launch BG3 normally through Xbox App;
2. use a disposable/pre-mod save;
3. switch to controller UI;
4. open the normal action menu;
5. check whether HotBar sections/icons are populated;
6. press B and verify the menu closes.

If either of those two checks fails, stop there and capture one screenshot. Only after both pass should focus, A dispatch and variants/upcast be tested.

The prerelease includes an on-screen diagnostic panel, so these screenshots should distinguish page-load, data-binding, focus and variant-state failures without Script Extender.

Do not overwrite an important campaign save during this external-PAK development test.
