# Release process

## Version source

The repository root `VERSION` file is the release source of truth.

Current release channel:

- versions containing a suffix such as `0.0.1-probe` are published as GitHub prereleases;
- plain semantic versions such as `0.1.0` are published as normal releases.

## Automatic publication

Every push to `main` that changes release-relevant files runs `.github/workflows/release.yml`.

The workflow:

1. reads and validates `VERSION`;
2. checks whether GitHub Release `v<VERSION>` already exists;
3. builds the mod with pinned LSLib;
4. creates the tag and GitHub Release;
5. builds `BG3ControllerActionMenu-OneClickInstaller.zip`;
6. uploads the versioned `.pak`, the advanced PowerShell installer, and the reusable hidden one-click installer bundle.

Published versions are immutable. If `v<VERSION>` already exists, the workflow does not overwrite the asset or move the tag.

## Making the next release

1. change `VERSION`;
2. merge through the normal PR/CI workflow;
3. the merge to `main` publishes the release automatically.

Do not reuse a published version number.

## Runtime package compatibility

Release packaging verifies that the extracted `.pak` contains no `ScriptExtender` directory.

The primary artifact is intended to remain compatible with the Xbox App / Microsoft Store PC build and therefore must not acquire DLL/native-loader/SE dependencies.


## Reusable universal development shortcut

Every release publishes `BG3ControllerActionMenu-OneClickInstaller.zip`, containing the single operator-facing file `Install-BG3ControllerActionMenu.vbs`.

After extracting it once, the operator keeps and reuses that same VBS. On every invocation it queries GitHub Releases, selects the newest published release (including prereleases), downloads that release's `dev-entry.ps1`, and executes it hidden.

`dev-entry.ps1` is intentionally release-controlled. The current task is install/update of the ready self-contained PAK, but later releases may switch the same VBS to capture, diagnostics, or another development operation.

Release publication therefore includes the universal VBS, `dev-entry.ps1`, and the helper assets that the current/future entry may need. There is no permanent second capture VBS and no local bootstrap file required beside the operator shortcut.
