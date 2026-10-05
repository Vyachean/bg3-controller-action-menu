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
5. uploads the versioned `.pak`, the advanced PowerShell installer, and the evergreen `install-latest.cmd` launcher.

Published versions are immutable. If `v<VERSION>` already exists, the workflow does not overwrite the asset or move the tag.

## Making the next release

1. change `VERSION`;
2. merge through the normal PR/CI workflow;
3. the merge to `main` publishes the release automatically.

Do not reuse a published version number.

## Runtime package compatibility

Release packaging verifies that the extracted `.pak` contains no `ScriptExtender` directory.

The primary artifact is intended to remain compatible with the Xbox App / Microsoft Store PC build and therefore must not acquire DLL/native-loader/SE dependencies.


## Evergreen one-click installer

Every release publishes `install-latest.cmd`.

Unlike the versioned PAK, this launcher is intentionally reusable across releases. On each run it queries the GitHub Releases API, selects the newest published non-draft release (including prereleases), downloads that release's PAK and `install-xbox-dev.ps1`, verifies their GitHub SHA-256 digests, and invokes the fail-closed Xbox installer.

Users therefore do not need to download a new installer for every development build.
