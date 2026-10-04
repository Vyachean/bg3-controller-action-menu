# Testing strategy

## Goal

Keep manual Baldur's Gate 3 testing infrequent and high-value.

The project distinguishes three proof levels.

## Level 1 — static proof

Runs on every change.

Examples:

- XML/XAML well-formedness;
- required project paths/files;
- duplicate resource keys where detectable;
- forbidden placeholder/experimental markers in release builds;
- deterministic fixture tests for categorization and navigation helpers;
- packaging manifest consistency;
- documentation checks for unverified assumptions.

A failure here must block a test build.

## Level 2 — package/build proof

Runs when packaging is available.

Examples:

- mod folder shape is valid;
- generated archive/PAK contains expected files;
- metadata references the correct module UUID/name;
- no development-only fixtures are packaged;
- reproducible artifact naming.

This proves only that the artifact is structurally valid, not that BG3 will render it correctly.

## Level 3 — in-game proof

Requested only for milestones that cannot be proven outside the game **after current game-file inspection is exhausted**.

Do not ask the user to validate one speculative binding/layout hypothesis per build. Before requesting a run, inspect the installed/native current UI contract where possible, update deterministic fixtures, and make the single run answer several remaining runtime-only questions.

Expected milestones:

### M1 — UI hook proof

One run should establish:

- the custom controller page/state loads;
- opening/closing works;
- controller focus is visible and responsive.

### M2 — native action data proof

One run should establish:

- native actions appear without a manually maintained spell/action list;
- disabled/available state tracks the game;
- action identity survives selection.

### M3 — dispatch proof

One run should establish:

- selecting a simple action enters the native targeting/execution path;
- cancel returns to the custom menu correctly.

### M4 — edge-case matrix

A deliberately chosen test character/save should cover, in as few runs as possible:

- normal action;
- cantrip;
- leveled spell;
- upcast;
- multi-variant action;
- recast;
- toggle/passive;
- consumable/item action;
- class-resource action;
- temporary action.

## Diagnostic builds

Milestone artifacts should expose enough diagnostics to avoid repeated blind tests.

For Xbox App-compatible candidates, diagnostics must not require Script Extender.

Where possible include:

- visible build/version identifier;
- on-screen debug overlay using ordinary BG3/XAML bindings;
- action-group/hotbar/variant counts;
- focus and variant/upcast state;
- screenshots as the first-line diagnostic artifact.

Script Extender logging may be used only by optional developer builds under `dev/`, never as a requirement for the shipping package.

Debug instrumentation must be removable/disabled for stable releases.

## Runtime evidence

### 2026-10-04 — Xbox App 1.8.910.0

Confirmed by real runs:

- CAM's `ActionRadials` state override loads;
- release version changes are visible in-game, so package delivery/replacement works;
- `CurrentPlayer.UIData.AreRadialsOpen` can be read/written from the root HotBar context;
- the page shell and imported resources render;
- builds through 0.0.16 did **not** populate the intended action grid;
- B did **not** close the menu in those builds;
- the original CAM full-screen dim/background was undesirable and must not return.

Important correction:

- blank object-level diagnostic fields such as `CurrentPlayer:` / `SelectedCharacter:` were produced using `NullToBoolFalseConverter` and are not reliable evidence that those VM objects were absent;
- the public `ActionRadials.xaml` used for several design decisions is Patch 2 Hotfix 1 (2023-09-06), not Patch 8;
- therefore the 0.0.14–0.0.17 sequence contained too much inference from stale/native-adjacent evidence.

No further in-game run should be requested until the current installed Patch 8/Xbox radial XAML is captured and the next candidate is rebuilt from that current contract.

## Manual test report format

A useful report is:

```text
Build:
Game version:
Controller:

Open menu: pass/fail
Navigation: pass/fail
Action list populated: pass/fail
Selected action:
What happened after A:
What happened after B:
Screenshot/video/log:
```

Do not request broad exploratory testing when one targeted assertion can answer the current question.
