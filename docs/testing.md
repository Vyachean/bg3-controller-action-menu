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

### 2026-10-05 — 0.0.25 no-op runtime result

`0.0.25-native-radial-visual-mirror` installed without the earlier startup error, but the action UI was indistinguishable from vanilla: no grid appeared and the mod produced no visible runtime change.

That rejects the `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` override-from-mod-PAK strategy for this Xbox/App path. It must not be retried.

The useful observation from the user is also supported directly by the current captured XAML: BG3 already contains a working controller grid in the radial **slot-assignment** UI. Its contract is stronger than the previous generic list/grid experiments:

```text
AssignList
  SelectedIndex=0
  LocalFocusSelector=SelectorAssign
  KeyboardNavigation.DirectionalNavigation=Contained
  ActionNextEvent=UIDown
  ActionPrevEvent=UIUp
        |
        v
nested LSListBox
        |
        v
LSGrid
  ActionUpEvent=UIUp
  ActionDownEvent=UIDown
  ActionLeftEvent=UILeft
  ActionRightEvent=UIRight
  AutoIndex=True
```

### 0.0.27 architecture — native slot-assignment grid

The next candidate returns to the controller-library hook proven to load in 0.0.24, but it does **not** hand-write the outer ActionRadials template.

At install time it extracts the exact current native dictionary and locally copies these native resources into `Lib_Controller.xaml`:

- `ActionRadialWidgetTemplate_P8`;
- `RadialHotBarListItemContainer`;
- `BarPageViewStyle`;
- `SingleBarPageViewStyle`.

The outer template/container are byte-derived from the installed game and remain structurally native. Only the two `ls:Radial` renderer blocks inside the page styles are replaced with assignment-style `LSListBox + LocalFocusSelector + LSGrid` renderers while keeping the original element names `HotBarRadial` and `SingleBar`.

This preserves all existing native references to:

- `LocalFocus.Index`;
- `LocalFocus.DataContext`;
- delayed `ActionRadials.Tag` updates;
- swap-slot binding;
- context-menu slot index;
- `UseSlotBinding`;
- `CancelButton`;
- nested/main cancel switching.

Before the next runtime request CI must prove:

- the source fixture remains unchanged;
- generated XAML parses;
- both radial renderers are absent from the generated library;
- exactly two assignment-style LSListBox grids replace them under the original element names;
- `ActionRadialWidgetTemplate_P8` and `RadialHotBarListItemContainer` remain present;
- native A/B/swap/local-focus seams remain present;
- `AssignSlotCommand` is absent from action browsing;
- release PAK still contains no proprietary XAML;
- final installed PAK is generated locally.

### 2026-10-05 — 0.0.27 runtime result

`0.0.27-native-slot-assignment-grid` is the first build that proves the new architectural direction in-game:

- radial slot layouts are replaced by square grids;
- the native ActionRadials page still loads;
- the slot-assignment-derived grid focus model is active.

The screenshot exposes three presentation defects rather than another input/data failure:

1. each grid is anchored to the upper-left of its 1560×1560 native PageView instead of being centered;
2. the native radial backdrop ellipse remains visible as a dark circular shadow behind the grid;
3. the native radial footer still exposes radial-specific chrome, notably `Radial Customisation`.

No navigation/A/B architecture change is justified by this result.

### 0.0.28 presentation-only correction

`0.0.28-grid-presentation-cleanup` changes only presentation:

- replacement `LSListBox` is centered in the native PageView with a bounded 640×400 viewport;
- the 5-column `LSGrid` itself is centered in that viewport;
- the native 1260×1260 radial backdrop ellipse is collapsed in both main and nested PageView styles;
- the button-hint strip is centered/compact;
- the radial-specific context-menu prompt is visually suppressed while its command remains wired;
- `LocalFocus`, `ActionRadials.Tag`, A, B, swap and paging semantics are unchanged.

CI must prove these presentation seams in addition to all 0.0.27 focus/dispatch seams before another in-game run.

### 2026-10-05 — 0.0.28 runtime result

`0.0.28-grid-presentation-cleanup` fixes the main visual placement: action cells are centered and the old circular radial backdrop is gone.

One coordinate-space defect remains:

- the focus selector frame still renders at the old upper-left origin instead of on top of the centered cell;
- the focused data/navigation itself is not reported broken;
- X/ContextMenu still works even though 0.0.28 hid its hint;
- visible footer hints are therefore only A and B.

Root cause is now concrete: in 0.0.28 the `LSListBox` was centered inside the 1560×1560 PageView, while its `LocalFocusSelector` control remained a separate sibling anchored to the PageView's top-left. The native slot-assignment UI keeps `AssignList` and `SelectorAssign` in the **same Grid coordinate space**.

### 0.0.29 focus-origin correction

- wrap each replacement list and selector in one centered 640×400 `Grid`;
- stretch the list inside that shared root;
- keep the selector at top-left **of that same root**, matching native `AssignList + SelectorAssign`;
- do not change `LocalFocus`, directional events, `ActionRadials.Tag`, A/B, paging or swap;
- keep X/ContextMenu active because it still customizes the underlying hotbar slots;
- restore its hint with grid-neutral label `Customize`.

### 2026-10-05 — 0.0.29 installer post-pack verifier failure

The reusable bootstrap/update path worked correctly in the user's real environment:

- it selected `v0.0.29-focus-origin-fix`;
- downloaded and SHA-256 verified the current PAK, Xbox installer and native-overlay builder;
- discovered the Xbox BG3 1.8.910.0 target and reached `ReadyForApply`;
- entered native-derived package generation.

Installation then failed before writing the mod because the **post-pack verifier in `native-overlay.ps1` still required the obsolete 0.0.28 chrome state**:

```text
Opacity="0"
Width="0"
```

while 0.0.29 intentionally generates and validates:

```text
Opacity="1"
Width="Auto"
Tag="Customize"
```

This is not a game/runtime mismatch; it is an internal verifier drift defect.

### 0.0.30 verifier correction

The generator and post-pack round-trip now call the same semantic `Assert-GridChromeContract` function. The final verifier no longer carries independent stale visibility/width literals.

CI additionally rejects reintroduction of the old `Opacity="0" + Width="0"` packed verification pair.

### 2026-10-05 — 0.0.31 installer simplification

The 0.0.29 failure exposed a broader design problem: the installer duplicated semantic UI assertions that already belong in CI. Even after 0.0.30 unified those assertions, running them again after local packaging still adds failure modes without improving installation safety.

The install-time contract is now intentionally minimal:

1. resolve and SHA-256 verify release assets;
2. locate the installed BG3 and safe mod target;
3. extract the exact current native radial XAML;
4. require only the native **input compatibility seams** needed before transformation;
5. generate the controller library;
6. require only that generated XAML parses;
7. create the PAK;
8. require that package creation succeeds and the output file is non-empty;
9. install it.

Detailed grid/focus/chrome/A/B semantics remain fully tested by `test-native-overlay.ps1` and repository CI. They are no longer re-asserted inside the end-user installation path.

This keeps fail-closed behavior where it matters — changed game input structure, unsafe Xbox target, failed download/hash, invalid XML, failed package creation — without making the installer a second CI system.

### 0.0.31 — single-purpose installer

The installer is intentionally no longer a second verification system.

The 0.0.29 failure showed the problem directly: a stale install-time expectation for `Width="0"` blocked installation even though the released generator had intentionally moved to `Width="Auto"`.

From 0.0.31:

- the bundled bootstrap only downloads the newest release's `install-latest.ps1` and executes it;
- the current installer downloads that release's PAK, Xbox installer and native-overlay builder, then invokes installation;
- native-overlay performs transformation and packaging operations only;
- semantic XAML/focus/chrome assertions remain in CI fixtures and repository validation, not in the user's install path.

An installer failure should now correspond to an actual failed operation rather than an independent policy assertion disagreeing with the published release.

### 2026-10-05 — automatic-catalog boundary

Runtime 0.0.29 closes the grid/focus-layout line: cell rendering and the focus selector now align correctly.

The remaining product defect is semantic: the main grid still uses `ControllerHotBars[*].SlotList`, so it only reflects radial-wheel customization. The user explicitly rejects that model. Radial customization is also removed as a feature because its native context-menu operations are visually/semantically awkward in the grid.

The current captured Patch 8 XAML provides a stronger source directly inside `SlotAssignHolderStyle`:

```text
AssignList
  |
  +-- SpellsAndActions[*].Actions
  +-- Stats.Passives --TogglablePassivePredicate
  +-- Stats.Passives --TogglableMetaMagicPassivePredicate
  +-- Inventory.Slots
```

These collections are maintained by BG3 and are exactly what the native radial assignment screen offers to the player. They are therefore the new main-menu source of truth.

The automatic-catalog candidate must prove statically:

- main generated XAML contains no `ItemsSource` binding to `ControllerHotBars`;
- it contains `SpellsAndActions`, both passive predicates and `Inventory.Slots`;
- it uses the native `AssignList + LocalFocusSelector + LSGrid` hierarchy;
- focus updates `ActionRadials.Tag`;
- A remains `UseSlotCommand(Tag)`;
- B remains the native close/nested cancel command;
- nested `SingleHotBar.SlotList` grid remains present;
- `ShowContextMenu` is disabled/hidden and no `AssignSlotCommand` is reachable.

The only high-value runtime question after that is direct execution of an automatic catalog candidate through the existing `UseSlotCommand` seam, plus confirmation that newly available actions appear without radial customization.

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

### 2026-10-06 — 0.0.35 native action-tabs milestone

The automatic catalog is now split only along **current proven native-source boundaries**:

- `Actions / Spells` → `PlayerCharacterProperties.SpellsAndActions`;
- `Items` → `Inventory.Slots`;
- `Passives` → `Stats.Passives` + `TogglablePassivePredicate`;
- `Metamagic` → `Stats.Passives` + `TogglableMetaMagicPassivePredicate`.

The tab strip is an `LSListBox` with `ActionPrevEvent="UITabPrev"` and `ActionNextEvent="UITabNext"`. Filtered empty Passives/Metamagic tabs collapse. The selected tab index drives the automatic focus list; `SelectionChanged` clears the old action tag and uses `SetMoveFocusAction` to return focus to `HotBarList`.

Static fixture coverage must prove:

- generated XAML parses;
- `ControllerHotBars` is absent from the main catalog;
- every current automatic source/filter binding is present;
- all four tab identities and `UITabPrev/UITabNext` wiring are present;
- the tab selection index controls the main content list;
- focus handoff uses `SetMoveFocusAction`;
- `ShowContextMenu` has no input binding and is inert;
- `RequestAssignSlotCommand`, `AssignSlotCommand`, `SwapSlotCommand`, `ClearSlotCommand`, `AddRadialCommand` and `RemoveRadialCommand` do not survive generated XAML;
- no `Custom` tab exists;
- historical-only `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate` do not enter shipping generation without new current Patch 8 evidence;
- native A/B and `SingleHotBar.SlotList` seams remain;
- package build, verification and round-trip checks pass.

The one remaining proof boundary is runtime behavior. One milestone run should answer all of these together:

1. shoulder/tab input changes the selected tab;
2. empty filtered tabs do not trap navigation;
3. focus lands in the selected grid and remains aligned with the cell;
4. returning to a tab has sensible focus behavior;
5. representative actions/items/passives appear without radial customization;
6. one direct native candidate executes through A;
7. B closes the top level;
8. nested `SingleHotBar` / upcast / variant B still works when available.

Do not request an earlier game run for spell-level headings. Fine-grained Cantrip/Level I/Level II presentation stays blocked until the current installed SpellBook contract is captured rather than inferred from the old public dump.
