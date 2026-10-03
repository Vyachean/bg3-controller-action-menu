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
5. uploads the versioned `.pak`.

Published versions are immutable. If `v<VERSION>` already exists, the workflow does not overwrite the asset or move the tag.

## Making the next release

1. change `VERSION`;
2. merge through the normal PR/CI workflow;
3. the merge to `main` publishes the release automatically.

Do not reuse a published version number.
