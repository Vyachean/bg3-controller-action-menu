# Development VBS contract

## Role

`Install-BG3ControllerActionMenu.vbs` is a **temporary development delivery tool**.

It exists only while BG3 Controller Action Menu is under active development and is not yet distributed through the intended official mod-delivery path. It is not part of the long-term runtime architecture and must not influence the design of the shipping mod.

Its job is deliberately narrow:

1. the tester keeps one extracted development-installer folder;
2. the tester double-clicks the same VBS for every install or update;
3. the launcher/bootstrap resolves the newest development build and installs it;
4. no manual replacement or update of the VBS is required during normal development iteration;
5. after a successful install, the canonical installer refreshes the VBS/bootstrap in that same folder from the published development release, so future launcher changes migrate automatically.

When CAM moves to the official delivery path, this VBS workflow can be retired.

## Stability contract

The VBS itself must remain tiny and stable.

It may know only the stable bootstrap entry point and portable state paths. It must not know:

- release-specific asset sets;
- mod-version-specific behavior;
- XAML contracts;
- LSLib/game-PAK extraction logic;
- package-generation logic;
- validation/test policy.

Version-specific behavior belongs in scripts downloaded by the stable bootstrap. The bootstrap/VBS interface must remain backward-compatible so an already extracted development-installer folder continues to work without a manual refresh.

A change that would require the tester to download a newer VBS manually is an installer architecture regression. The canonical installer therefore publishes the VBS as a standalone release asset and refreshes the already-extracted launcher folder after a successful update. It also recovers the caller bootstrap directory for older launchers that predate the explicit `LauncherRoot` argument.

## One-click development workflow

The expected interaction is always:

```text
double-click the existing VBS
  -> resolve current development delivery metadata
  -> download current helper scripts/build
  -> install or update CAM
  -> show success/error
```

The VBS must not expose PowerShell consoles or require command-line parameters for normal development installation.

All installer-owned caches, logs, downloaded helpers and diagnostics belong beside the VBS under a portable working directory. Writes elsewhere are limited to the actual BG3 mod/profile installation and safety backups required for that installation.

## Development evidence / capture

During development, implementation work may require fresh evidence from the installed game.

In that case, repository scripts may be added or updated to:

- inspect BG3 files read-only;
- extract selected UI/resources;
- build manifests/reports;
- package the resulting evidence for upload back to the development chat.

Those are **development helper scripts**, not requirements of the final mod.

They may be exposed through a one-click VBS helper when useful, but they must remain separate from the normal install/update path unless a specific development build genuinely needs them. Their output should be created beside the launcher so the tester can simply return the generated archive.

The final self-contained mod must not depend on these capture/extraction steps.

## Self-contained runtime boundary

The target release PAK is self-contained. Development tooling may inspect the game to discover or verify the current native UI contract, but normal installation must not turn the tester's machine into a build environment.

In particular, the permanent mod architecture must not require:

- reading `Game.pak` during installation;
- installing/downloading LSLib during installation;
- generating runtime XAML during installation;
- repacking the mod on the tester's machine.

Those activities, if needed, belong to development/release preparation before the build is delivered.
