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


## Reusable hidden one-click installer

Every release publishes `BG3ControllerActionMenu-OneClickInstaller.zip`.

After extracting it once, the user launches `Install-BG3ControllerActionMenu.vbs` by double-clicking it. WScript starts the PowerShell bootstrap with window style 0, so no console is shown. A normal Windows dialog reports success or failure.

The bundle is intentionally reusable across releases. On every run its bootstrap queries GitHub Releases, selects the newest published release (including prereleases), downloads that release's exact PAK plus current `install-xbox-dev.ps1`, verifies GitHub SHA-256 digests, and invokes the fail-closed Xbox installer.

The bootstrap refuses malformed newest releases instead of silently installing an older one.
