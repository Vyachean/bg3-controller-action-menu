# Universal development VBS contract

## Role

`Install-BG3ControllerActionMenu.vbs` is the **one operator-facing VBS** used during active CAM development.

Despite the historical filename, it is not semantically an installer anymore. It is a universal development shortcut.

The operator keeps the same VBS and always starts development operations by double-clicking that file. The VBS itself does not decide what work should happen.

Its stable flow is:

```text
double-click the same VBS
  -> query the newest published development release
  -> download that release's dev-entry.ps1
  -> execute dev-entry.ps1 hidden
  -> show the task result
```

The release-controlled `dev-entry.ps1` owns the actual behavior.

A release may therefore make the same VBS perform, for example:

- normal install/update of the ready self-contained PAK;
- read-only capture of current BG3 resources;
- diagnostics;
- install followed by diagnostics;
- another temporary development operation.

Changing those behaviors must not require the operator to download or learn a new launcher.

No manual replacement or update of the VBS is required when release behavior changes.

When CAM moves to the intended official delivery path, this development shortcut can be retired.

## Stability contract

The VBS must remain tiny and backward-compatible.

It may know only:

- the repository/release discovery endpoint;
- the stable release asset name `dev-entry.ps1`;
- portable state paths beside itself;
- the generic status contract used to show success/failure.

It must not know:

- which development task is current;
- release-specific asset sets beyond `dev-entry.ps1`;
- mod-version-specific behavior;
- XAML contracts;
- LSLib/game-PAK extraction rules;
- package-generation logic;
- validation/test policy.

All changeable behavior belongs behind `dev-entry.ps1`.

Downloaded PowerShell helpers use normal PowerShell semantics: a helper invoked with `&` succeeds when it returns without a terminating exception and fails by throwing. `$LASTEXITCODE` is reserved for native/child-process boundaries and must not be used as the result of an in-process `.ps1` helper because it may be null or stale.

A change that would require the operator to download a newer VBS manually is a development-launcher architecture regression.

## One-file operator contract

The reusable operator-facing bundle contains only:

`Install-BG3ControllerActionMenu.vbs`

All downloaded scripts, caches, logs, metadata and diagnostics are runtime state created beside it under:

`installer-work\`

The launcher itself must create `installer-work\launcher-bootstrap.log` **before the first network request**. This log covers the part of execution that happens before `dev-entry.ps1` exists: GitHub release discovery, asset lookup/download and handoff to the downloaded entry.

If bootstrap fails, the error dialog must point to that existing bootstrap log. It must never claim that a diagnostic file was written when that file does not exist.

The operator must not need to keep a second bootstrap VBS/PS1 or a separate capture launcher.

The old `bootstrap-latest.ps1` two-file protocol is obsolete. The canonical installer keeps a migration path for an already extracted legacy launcher: one successful legacy run refreshes the VBS and retires the old local bootstrap.

## Release-controlled development entry

Every development release must publish:

`dev-entry.ps1`

The universal VBS downloads a fresh copy on every invocation.

That script is intentionally allowed to change between releases. It is the control plane for the current development operation.

For development milestone `0.0.79-hotbar-coverage-capture` the task is one read-only native evidence capture:

```text
VBS
  -> current release dev-entry.ps1
  -> current release capture-self-contained-inputs.ps1
  -> inspect Game.pak read-only
  -> write bg3-controller-action-menu-inputs-....zip beside the VBS
```

This milestone does not install/update CAM. A later release can switch `dev-entry.ps1` back to the normal install path without changing the operator's VBS.

## Capture boundary

Capture is a development operation, not part of the shipping mod or normal installation.

A release-controlled development task may:

- inspect the installed BG3 files read-only;
- download development-only tooling such as LSLib;
- read selected resources from `Game.pak`;
- produce manifests/reports;
- create a ZIP beside the universal VBS for upload to the development chat.

Those operations are allowed because they sit behind the universal development entry, outside the normal install/runtime boundary.

There must not be a second permanent `Capture-BG3ControllerArtifacts.vbs`.

## Self-contained runtime boundary

The final PAK remains self-contained regardless of what development task the universal launcher performs.

The **normal install/update helper** must not:

- read `Game.pak`;
- install or invoke LSLib;
- generate runtime XAML;
- rebuild/repack the PAK;
- require Script Extender, a DLL, or a native loader.

Development capture may read the game to discover or verify contracts. That does not make capture a runtime or install dependency.

The distinction is:

```text
universal development shortcut
  -> release-controlled task
       -> install path: ready PAK only
       -> capture path: read-only game inspection is allowed
```

This keeps the operator workflow universal while preserving a genuinely self-contained shipping mod.
