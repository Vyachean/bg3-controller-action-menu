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

### 2026-10-05 — native radial capture from Xbox App 1.8.910.0

The read-only installed-game capture closed the remaining static seams:

- root controller collection is `PlayerCharacterProperties.ControllerHotBars`;
- per-bar materialization is `SlotList`;
- nested materialization is `SingleHotBar.SlotList`;
- focus scrolling follows `FocusedElement`;
- normal controller A is page-level `UIAccept -> UseSlotCommand(focused slot)`;
- B defaults to `ClearSingleHotbarCommand` and switches to `CustomEvent("CloseWidget")` at the main level;
- swap mode uses `UseSlotCommand(null)` for B.

The next in-game run is therefore justified, but it must combine M1–M3 into one milestone run: populated rendering, directional focus/scroll, top-level B, nested B if naturally encountered, and one simple A dispatch.

### 2026-10-05 — 0.0.18 native-contract runtime result

The first candidate built from the captured data contract produced a populated grid in the real Xbox App build:

- `Controller bars: 5`;
- Class / Actions / Items sections rendered;
- native icons and tooltip details rendered;
- initial focus reached a real spell slot.

Two runtime assertions failed:

- directional controller navigation did not move focus;
- B did not close the window.

This means the captured **data/materialization contract is correct**, while CAM's custom input/navigation composition was not.

The data/rendering result remains valid, but the first input correction was not.

### 2026-10-05 — 0.0.19 input-routing regression

`0.0.19-native-input-routing` regressed substantially in the real Xbox App build:

- the Class / Actions / Items sections no longer rendered;
- diagnostic values were empty;
- controller inputs still did not work.

That build replaced the captured radial `LSButton` input controls with custom player-scoped `LSInputBinding` and added grid flags taken from other BG3 screens. Because the regression crossed the data/template boundary, those changes are rejected rather than iterated further. `0.0.19` must not be tested again.

A second audit of the **same captured Patch 8 `PreloadedActionRadials_c.xaml`** found a stronger native grid precedent that was already present in the installed game:

```text
LSListBox
  -> focusable ListBoxItem
  -> LSGrid(ActionUp=UIUp, ActionDown=UIDown,
            ActionLeft=UILeft, ActionRight=UIRight)
```

The current radial uses this exact structure for its slot-assignment spell/action/passive grids. Therefore `0.0.20-patch8-list-grid`:

- restores the proven `0.0.18` ControllerHotBars rendering and native `LSButton` A/B controls;
- replaces only the non-navigable per-section `ItemsControl` with the captured Patch 8 `LSListBox + ListBoxItem + LSGrid` pattern;
- keeps focus on the `ListBoxItem`, while the inner `HotBarSlotStyle` button is visual-only;
- removes the speculative 0.0.19 grid flags and `LSInputBinding` replacement;
- uses the current native ActionRadials root's `UITabPrev/UITabNext` left/right mapping instead of intercepting `UILeft/UIRight` at the root.

No further data-source experimentation is justified.

### 2026-10-05 — 0.0.20 list-grid runtime result

`0.0.20-patch8-list-grid` again rendered the Class / Actions / Items sections and showed `Controller bars: 5`, but the diagnostic overlay reported no focused element/slot and every controller input remained dead, including B.

That result closes the custom-page line of investigation. The common denominator across 0.0.18 and 0.0.20 is the CAM-owned replacement `ActionRadials` state/page. Changing child focus containers is no longer justified.

`0.0.21` and `0.0.22` changed installation UX only and did not change this runtime candidate.

### Next runtime boundary — native page/library override

`0.0.23-native-page-library-override` removes the CAM `ActionRadials` StateMachine override and removes `CAM_ActionMenu_c.xaml` from the package.

BG3 owns:

- the native `ActionRadials` state;
- the native `MainUI/Pages/ActionRadials.xaml` root;
- the `ActionRadials` widget name;
- the `HotBar` context;
- native page Loaded/Unloaded/WidgetClosing/focus lifecycle;
- native state events such as `CloseWidget`.

CAM now participates only through `GUI/Library/Lib_Controller.xaml`, the documented controller-mode library hook, and overrides the `ActionRadialWidgetTemplate_P8` resource consumed by the native page.

Automatic proof for this candidate must establish:

- no packaged CAM controller StateMachine;
- no packaged CAM replacement page;
- controller library merges the CAM radial resource;
- override key is exactly `ActionRadialWidgetTemplate_P8`;
- captured ControllerHotBars / SingleHotBar / focus / A / B seams are present;
- package remains Script-Extender-free.

Only after those checks pass is one combined in-game test justified. If the resource override is not selected by BG3, the expected fallback is the vanilla radial page rather than a trapped/dead custom state.

### 2026-10-05 — 0.0.23 startup failure

`0.0.23-native-page-library-override` did not reach the main menu. BG3 showed:

```text
Missing XAML
No XAML file or mod found in root./
BG3ControllerActionMenu;component/Library/
CAM_ActionRadials.xaml
```

This is direct runtime evidence that the CAM-local component URI used by `Lib_Controller.xaml` is not resolved as a resource URI in this loader path; it is interpreted as a literal missing XAML path.

The correction does not substitute another path spelling. `0.0.24-inline-controller-library` removes the external CAM dictionary entirely and defines `ActionRadialWidgetTemplate_P8` plus its helper resources directly inside `Lib_Controller.xaml`.

The package verifier now fails if either:

- `GUI/Library/CAM_ActionRadials.xaml` is packaged; or
- `Lib_Controller.xaml` contains a CAM-local `CAM_ActionRadials.xaml` reference.

This makes the 0.0.23 startup failure structurally impossible to reproduce from the same mechanism.

### 2026-10-05 — 0.0.24 full-template runtime result

`0.0.24-inline-controller-library` starts successfully and activates the native `ActionRadials` page: the user hears the normal radial movement/click sounds. However, the replacement window still has no effective interaction and cannot be closed with B.

This is high-value negative evidence:

- native state/page lifecycle is active;
- CAM's controller resource override is selected;
- replacing the whole `ActionRadialWidgetTemplate_P8` is still outside the safe ownership boundary.

No further full-template reconstruction is justified.

### 0.0.25 architecture — native Radial remains the input engine

The next candidate is derived locally from the exact installed `PreloadedActionRadials_c.xaml` instead of shipping a reconstructed template.

The deterministic patch:

1. leaves the native `ActionRadialWidgetTemplate_P8` intact;
2. leaves the native `PageView`, `HotBarRadial`, `SingleBar`, `UseSlotBinding`, `CancelButton`, nested/swap and state-machine logic intact;
3. makes only the native radial artwork transparent;
4. inserts a non-focusable, non-hit-test grid mirror next to each native radial;
5. mirrors `SelectedIndex` one-way from the native radial's `LocalFocus.Index`;
6. derives and packages both normal and Clairmont radial dictionaries locally from the current `Game.pak`.

The GitHub release does not contain Larian XAML.

Before asking for a runtime test, CI must prove:

- source XAML is not modified by patch-only fixture mode;
- native `ls:Radial` controls remain present;
- native A/B commands remain present;
- exactly two visual mirrors are inserted;
- native radial controls are hidden with opacity rather than removed/collapsed by CAM;
- the published base PAK contains no runtime/native XAML;
- one-click release resolution requires and verifies the native-overlay builder;
- Xbox apply builds the derived PAK before touching the installed mod package/load order.

### 2026-10-05 — 0.0.25 native-resource mirror runtime result

`0.0.25-native-radial-visual-mirror` installed and the game ran, but CAM produced **no visible UI change**.

This invalidates the assumption behind the 0.0.25 runtime architecture:

- packaging locally derived files under `Public/Game/GUI/Library/...` and the Clairmont counterpart is not proven to override those base-game UI resources from a normal CAM mod PAK;
- static/package checks proved only that the files existed in the generated PAK, not that the BG3 mod UI loader consumes those paths as overrides;
- therefore the install-time native-overlay machinery is not an accepted UI hook.

Combined with 0.0.24, the evidence boundary is now:

- the normal mod controller-library route is definitely loaded;
- the native `ActionRadials` page/state is definitely active;
- a hand-written replacement of the whole native template is too broad and breaks behavior;
- a raw `Public/Game/GUI` file override in the mod PAK demonstrates no effect.

**No new in-game build should be requested until a supported, narrower restyling hook is proven from current sources or a concrete working mod.**

The next work returns to source research: current controller-radial mods plus Larian's Library / Pages / StateMachines / restyling model.

### 0.0.26 installer reliability boundary

The 0.0.25 runtime package itself was not the cause of the reported one-click failure. The uploaded installation log proved the VBS launcher executed correctly, selected 0.0.25, and then paired a **stale bundled `install-latest.ps1`** with the newer release's `install-xbox-dev.ps1`. The newer Xbox installer required `-NativeOverlayPath`, which the stale bootstrap did not know to pass.

This is an installer architecture defect: an extracted folder must not embed version-specific release knowledge.

The replacement protocol is:

```text
VBS
 |
stable bootstrap-latest.ps1
 |
latest GitHub Release
 |-- verified latest bootstrap-latest.ps1
 |-- verified latest install-latest.ps1
 |
canonical version-specific release resolution
```

Automatic proof must cover:

- current bootstrap downloads itself and `install-latest.ps1` by stable asset names;
- both files require GitHub SHA-256 digests;
- a stale bundled bootstrap transfers control to the verified newer bootstrap;
- canonical installer execution is proven by fixture;
- malformed newest release never falls back to an older release;
- bootstrap digest mismatch fails closed;
- the OneClickInstaller ZIP contains `bootstrap-latest.ps1`, not a frozen `install-latest.ps1`.

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
