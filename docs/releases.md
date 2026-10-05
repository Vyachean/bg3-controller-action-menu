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
3. runs the Xbox installer and one-click bootstrap fixtures;
4. builds the mod with pinned LSLib;
5. verifies the packaged `.pak`;
6. builds `BG3ControllerActionMenu-OneClickInstaller.zip`;
7. creates the tag and GitHub Release;
8. uploads the versioned `.pak`, the diagnostic/manual installer, and the reusable one-click installer bundle.

The one-click bundle is intentionally version-independent from the user's point of view: its bootstrap queries GitHub Releases on every run and downloads both the newest published CAM package and that release's current fail-closed installer after verifying GitHub SHA-256 digests.

Published versions are immutable. If `v<VERSION>` already exists, the workflow does not overwrite the asset or move the tag.

## Making the next release

1. change `VERSION`;
2. merge through the normal PR/CI workflow;
3. the merge to `main` publishes the release automatically.

Do not reuse a published version number.

## Runtime package compatibility

Release packaging verifies that the extracted `.pak` contains no `ScriptExtender` directory.

The primary artifact is intended to remain compatible with the Xbox App / Microsoft Store PC build and therefore must not acquire DLL/native-loader/SE dependencies.
