# Release process

## Purpose

This project uses a self-updating installer. A build is not a release merely because CI produced an artifact.

The installer reads the repository's **published GitHub Releases** and installs the newest published, non-draft release. Therefore a PR artifact, a successful build workflow, or a merge to `main` is only a release candidate until the release publication path completes.

This distinction is mandatory because otherwise the reusable one-click installer can correctly keep installing the previous version even though a newer CI artifact exists.

## Definition of release-ready

A version may be called **released**, **ready to install**, or **the newest installer version** only after all of the following are true:

1. The intended implementation PR has been merged to `main`.
2. `VERSION` on `main` contains the intended new version.
3. The **Release** workflow for the merge commit completed successfully.
4. GitHub contains a published, non-draft release whose tag is exactly `v<VERSION>`.
5. That release contains every installer-required asset:
   - `BG3ControllerActionMenu-<VERSION>.pak`
   - `BG3ControllerActionMenu-OneClickInstaller.zip`
   - `bootstrap-latest.ps1`
   - `install-latest.ps1`
   - `install-xbox-dev.ps1`
   - `native-overlay.ps1`
6. The new tag is the newest published release selected by the same release ordering used by `install-latest.ps1`.
7. `install-latest.ps1 -ResolveOnly`, against the live GitHub Releases API, resolves exactly `<VERSION>`.

Until all seven checks pass, describe the version as a **candidate** or **CI artifact**, not as a released version.

## Important: CI artifacts are not releases

GitHub Actions artifacts are useful for automated proof and private/manual candidate testing, but the one-click installer does not consume them.

In particular:

- a green **Build package** workflow does not publish a version;
- an artifact attached to a PR does not update the reusable installer;
- merging a PR does not by itself prove publication completed;
- the release is not ready merely because the package exists somewhere in Actions.

The publication boundary is the successful **Release** workflow plus the post-publication checks above.

## Preparing a release

### 1. Choose and record the version

Bump `VERSION` in the same PR that is intended to produce the release.

Use the repository's SemVer-like form:

```text
MAJOR.MINOR.PATCH
MAJOR.MINOR.PATCH-suffix
```

Milestone/test releases normally use a descriptive prerelease suffix, for example:

```text
0.0.35-native-action-tabs
```

A version containing `-` is published by the workflow as a GitHub prerelease.

Do not reuse an already published version. Release publication is treated as immutable.

### 2. Prepare the candidate completely before merge

Before merging:

- repository validation must pass;
- installer fixture tests must pass;
- Xbox installer tests must pass;
- native-overlay/static contract tests must pass;
- package verification must pass;
- documentation must describe any changed architecture or runtime proof boundary;
- the PR must state what remains runtime-only.

Do not merge merely to obtain a release artifact for unfinished work unless that is intentionally the milestone being published.

### 3. Merge to main

The normal publication path is the `Release` workflow triggered by a push to `main`.

The release-producing PR must touch at least one path watched by `.github/workflows/release.yml`. A `VERSION` bump satisfies this requirement and should therefore always be part of a release PR.

If publication needs to be retried without another source change, use the workflow's manual `workflow_dispatch` entry point rather than creating a duplicate release manually.

### 4. Require the Release workflow, not only Build package

After merge, inspect the workflow run for the actual merge commit.

A release is blocked if **Release** is:

- queued;
- in progress;
- cancelled;
- skipped unexpectedly;
- or failed.

A successful **Validate** or **Build package** run is not a substitute.

### 5. Verify the published GitHub Release

The workflow must create the exact tag:

```text
v<VERSION>
```

and all required assets listed above.

The project currently publishes prereleases frequently. Do not use GitHub's `/releases/latest` endpoint as release truth, because GitHub's "latest release" semantics can exclude prereleases. The installer intentionally enumerates published releases and sorts them by `published_at`.

Verification must therefore use the same model as the installer: published, non-draft releases ordered newest first.

### 6. Verify from the installer's point of view

The final proof is not "the release page exists"; it is "the installer resolves the intended version."

Run the canonical installer resolver against live GitHub metadata:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install-latest.ps1 -ResolveOnly
```

The output/status must identify exactly the version in `VERSION`.

The Release workflow also performs this check automatically after publication. Because GitHub can expose a newly created exact tag slightly before the releases collection used by the installer reflects it, the workflow retries the **canonical resolver** for a bounded number of attempts. It does not replace the resolver with a second implementation or accept an older version as success.

### 7. Only then announce or test the release

Only after the publication and resolver checks pass may project communication say:

- "version X is released";
- "the installer will install X";
- "rerun the same one-click installer to get X."

Before that point, say explicitly that X is only a candidate or CI artifact.

## Post-publication recovery

If the installer still selects the previous version:

1. Check published GitHub Releases first.
2. Check whether `v<VERSION>` exists and is non-draft.
3. Check the **Release** workflow for the merge commit.
4. Check that the required assets exist on that release.
5. Run `install-latest.ps1 -ResolveOnly`.
6. Only investigate or change installer selection logic if the intended release is published correctly and the resolver still chooses another version.

Do not modify the user-side installer to compensate for a release that was never published.

## Release workflow invariant

The release workflow must fail unless, after publication:

- the expected tag is the newest published non-draft release;
- all required installer assets are present;
- the canonical installer resolver selects the expected version.

This is a release-system invariant, not an optional manual check.
