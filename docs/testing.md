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

Requested only for milestones that cannot be proven outside the game.

Each manual test request must be short and diagnostic. Prefer one build that answers several questions.

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

Where possible include:

- visible build/version identifier;
- optional debug overlay showing current UI state, tab, focus index, and selected native action identifier;
- logging for state transitions and action selection.

Debug instrumentation must be removable/disabled for release builds.

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
