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
- pinned Patch 8 runtime evidence and project-owned XAML contract checks;
- rejection of stale `LocalFocus.Tag` / fixed-selector fixtures and raw assignment catalogs;
- normal-installer checks proving no `Game.pak`, LSLib, XAML generation or repack seam;
- documentation checks for unverified assumptions.

A failure here must block a test build.

## Level 2 — package/build proof

Runs when packaging is available.

Examples:

- mod folder shape is valid;
- built PAK contains project-owned `GUI/Library/Lib_Controller.xaml` byte-for-byte;
- metadata references the correct module UUID/name;
- copied `Public/Game/GUI` XAML is absent;
- Script Extender and native executable payloads are absent;
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
4. read only concrete source fragments/values required by the transformation;
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

### 2026-10-06 — 0.0.35 runtime result and 0.0.36 correction

The real Xbox App run proves:

- the four native-source tabs render;
- `UITabPrev` / `UITabNext` switch the visible tab;
- the 0.0.35 shared outer focus model is wrong: after switching tabs, focus/tooltip ownership can remain on the first tab;
- action description therefore remains sourced from first-tab cells;
- A does not execute the visually selected action because `ActionRadials.Tag` is not reliably owned by the visible tab;
- the generic shared selector frame does not match the current assignment-cell geometry;
- centering `ButtonHintsContainer` puts native controller hints over the center-bottom action-resource display.

0.0.36 corrects these as one focus/dispatch architecture change rather than independent visual patches:

1. every tab gets its own assignment-style `LSListBox + LocalFocusSelector`;
2. every tab gets a clone of the exact current installed `SelectorAssign` element, preserving native selector geometry;
3. tab change clears the stale tag and moves focus directly to that tab's list;
4. only the active list's local-focus trigger writes its candidate to `ActionRadials.Tag`;
5. Inventory keeps its required `.Object` unwrap; other native candidates use direct `LocalFocus.DataContext`;
6. footer hints return to the native right-side lane while remaining compact.

Static proof for 0.0.36 must reject the old `CAM_AutoCatalogSelector` / tab-index-driven outer `HotBarList` model and prove all four focus-owner/selector/candidate-writer pairs.

The next game run should be a single milestone check of: tab switching, selector alignment, description following the current tab/cell, A on one simple direct action, B at top level, and nested/upcast B if naturally available.



### 2026-10-06 — 0.0.36 runtime result and 0.0.37 architecture correction

The Xbox App runtime test rejects the remaining 0.0.36 source-tab composition:

- grid navigation becomes unstable at the lower row and can no longer reliably return to the upper rows;
- A does not execute the focused action;
- A does not open action containers/variants;
- the bottom action-resource bar does not highlight the resources that the focused action would spend;
- controller button hints are not in the original vertical stack;
- extra presentation symbols appear beside the RB hint;
- the product-level tab semantics are wrong: tabs should filter the action set by native type/resource semantics like the keyboard hotbar, not switch between independent Actions/Items/Passives/Metamagic source catalogs.

This runtime result also corrects a prior static inference. Patch 8 `HotBarSlotStyle` does **not** prove that a raw `VMCharacterAction` is the direct `UseSlotCommand` parameter. The style's button DataContext is `VMHotBarSlot`; its `VMCharacterAction`, `VMUpcast`, `VMItem` and `VMPassive` DataTemplates render the slot's content. Its command parameter is the slot VM itself.

The 0.0.37 correction therefore has these proof obligations before another game run:

1. executable main cells come only from native slot collections such as `CurrentShownDeck.SlotList` / `PassivesHotBar.SlotList`;
2. raw radial-assignment `SpellsAndActions`, inventory and passive objects are absent from the main dispatch path;
3. the exact installed keyboard `HotBar.xaml` is extracted locally and must expose the current deck/resource/cantrip filter commands before derivation continues;
4. resource filters use `CurrentPlayer.UIData.ActionResourcesCostPreview` and `FilterActionResourceCommand`;
5. cantrips use the parameter attached to the current installed `FilterCantripsCommand`, not a frozen historical handle;
6. one outer assignment-style `LSListBox + LocalFocusSelector` owns scrolling/vertical continuation; inner resource/action grids use `DirectionalNavigation=Continue`;
7. the action grid has no old fixed three-row height;
8. the current installed `HotBarRadial.LocalFocusChanged` trigger is reused for `ActionRadials.Tag`, focused tooltip data, `HighlightResourcesCommand` and hover feedback;
9. slot containers expose `Tag="{Binding .}"` so the native radial lifecycle receives `VMHotBarSlot`;
10. page A remains `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
11. nested/filter/container state remains BG3-owned through `SingleHotBar`;
12. the installed native `ButtonHintsContainer` is preserved and 0.0.36's extra LB/RB hint presenters are absent;
13. radial customization remains unreachable;
14. generated XAML parses and build/package/release CI is green.

Only after those checks pass should the next milestone runtime test be requested. One run should answer all of the remaining runtime-only questions:

1. navigate several rows down and back to the first row;
2. switch Common/Class/Items/Passives/Cantrips with LB/RB;
3. focus at least one action-resource filter and confirm the action set changes;
4. execute one simple direct action with A;
5. open one natural container/variant/upcast choice if available;
6. verify the bottom resource bar highlights the cost of the currently focused action;
7. verify button hints use the native vertical stack with no extra RB symbols;
8. verify top-level B and nested/filter B.

Do not request intermediate in-game tests for individual bindings.


### 2026-10-06 — 0.0.38 install-path simplification

The 0.0.37 runtime architecture accidentally reintroduced an installer-side semantic gate through `Assert-CurrentHotBarFilterContract`. That duplicated CI knowledge on the user's machine and violated the single-purpose installer rule established after 0.0.29/0.0.31.

0.0.38 removes that contract scan entirely.

The runtime installer may still fail when an operation it actually needs cannot be performed — for example the required source file cannot be extracted, a concrete value needed by the transformation cannot be read, package creation fails, or the Xbox target is unsafe. It must not iterate through expected HotBar command/property names merely to approve the installed game before transformation.

CI now explicitly rejects reintroduction of:

- `Assert-CurrentHotBarFilterContract`;
- install-time "missing required filter seam" checks.

The 0.0.37 UI/filter implementation itself is unchanged by this release.


### 2026-10-06 — self-contained runtime migration

The fresh developer capture from Xbox App package `1.8.910.0` has been consumed. It closed two stale fixture assumptions before project-owned XAML was authored:

- current radial focus passes `LocalFocus.DataContext` after the native 70 ms delay, not `LocalFocus.Tag`;
- current `SelectorAssign` has no hard-coded `118x118` geometry or margin.

The shipping source now contains project-owned `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml`. It composes current native filter commands, native `VMHotBarSlot` collections, current radial focus/tooltip/resource-highlight behavior, native A/B, `SingleHotBar.SlotList`, assignment-style navigation, and the captured button-hint layout.

The old install-time derivation path is obsolete and removed:

- `native-overlay.ps1`;
- `test-native-overlay.ps1`;
- capture-to-reference generator/fixture tooling.

The developer capture remains read-only evidence tooling only. It does not generate or patch the shipping runtime.

Current automated proof must establish:

1. `tools/test-self-contained-runtime.ps1` passes against the pinned `1.8.910.0` evidence;
2. the universal VBS stays task-agnostic and the normal install helpers contain no game-PAK/LSLib/build/repack seam;
3. the built PAK contains the project-owned controller library byte-for-byte;
4. copied `Public/Game` XAML, Script Extender and native executable payloads are absent;
5. repository/build CI is green.

Only after those checks pass was another in-game test justified. That milestone was subsequently superseded by the resource-first single-list runtime described below.

### 2026-10-07 — 0.0.58 selectorless adaptive-grid milestone

0.0.55–0.0.57 runtime evidence proved that the remaining focus/scroll defects were presentation ownership problems, not a reason to add more executable lists. The 0.0.58 candidate therefore adopts current Patch 8 SpellBook controller patterns:

- one `HotBarList` bound to `SingleHotBar.SlotList`;
- no `CAM_MainSelector`, `CAM_SelectorTemplate`, or `LocalFocusSelector`;
- item-local focus chrome driven by `ls:MoveFocus.IsFocused`;
- adaptive `LSGrid.Columns = floor(ScrollContentPresenter.ActualWidth / 120)`;
- pixel scrolling with the existing vertical focus margin;
- one bounded LB/RB resource strip with SelectedIndex auto-scroll;
- `ActionResource.TypeId` fallback only when the native resource name is null.

Static/package proof must reject any return of the detached selector, fixed five-column grid, content scrolling, duplicate executable list, type/class tabs, or install-time derivation.

The next in-game run is intentionally one combined milestone. It should answer:

1. after LB/RB resource changes, is focus chrome immediately on the logically focused first action rather than the old tab position;
2. can navigation reach lower rows and scroll them into view, then return upward;
3. does the action grid adapt to the available width without clipping or detached focus;
4. does the resource strip keep the selected tab visible without widening the menu, and do generic resources have a usable label/TypeId fallback;
5. do A, tooltip/resource highlighting, top-level B, and one natural nested/upcast/container path still work;
6. which resource previews, if any, produce an empty `SingleHotBar.SlotList`.

Do not auto-hide an empty resource preview during this milestone. Current native evidence exposes only the preview and filter command, not a proven per-preview executable-count predicate, and 0.0.49 already rejected re-entrant automatic refiltering.

### 2026-10-07 — 0.0.58 runtime result

The game run rejects the pure selectorless SpellBook focus-tree transplant:

- D-pad/left-stick navigation in the action grid does not work;
- A does not execute the selected action;
- resource labels are truncated by the 144px per-tab cap;
- one resource renders as truncated `Luck...`, followed by four visually unnamed resource tabs;
- the custom `Toggle weapon set` transport remains incorrect.

The first two failures share one architectural cause: ActionRadials dispatch depends on `HotBarList.LocalFocus.DataContext`. 0.0.58 removed the captured `LocalFocusSelector` seam while retaining LocalFocusChanged-based tooltip/highlight/Tag dispatch. The next candidate must therefore restore LocalFocus ownership without restoring the detached visible selector.

0.0.59 proof obligations:

1. `HotBarList` again has a `LocalFocusSelector`, pointing to an always-laid-out zero-opacity logical anchor;
2. the old visible `CAM_MainSelector` / compensated selector template remains absent;
3. adaptive columns and pixel scrolling remain;
4. the local-focus lifecycle still writes the focused native slot to `ActionRadials.Tag`, so A uses the same object navigation selected;
5. resource tabs allow materially wider labels and provide a TypeId fallback for null **and empty** displayed names;
6. no CAM-owned weapon-set input binding or hint remains;
7. no extra executable list, class/type tab, re-entrant resource filter, Script Extender dependency, or install-time derivation is introduced.

The next game run should verify only the corrected seams: four-direction grid navigation, A on one direct action, lower-row scrolling, LB/RB tab labels including the formerly blank entries, and absence of the broken weapon-set shortcut.


### 2026-10-07 — 0.0.59 runtime result / 0.0.60 proof boundary

0.0.59 partially succeeds:

- controller navigation works logically: the native tooltip follows the currently focused action;
- A executes the focused action;
- visible focus is wrong: the frame remains on the first cell while logical focus moves;
- some long generic resource names still truncate;
- the four formerly blank resource tabs remain visually blank.

The focus result proves `HotBarList.LocalFocus.DataContext` is correct and rejects further changes to the logical navigation/dispatch path. The defect is the independent `ls:MoveFocus.IsFocused` presentation state. 0.0.60 must mirror `LocalFocus.DataContext` into `HotBarList.SelectedItem` and render focus from `IsSelected`.

The resource result identifies two presentation corrections:

- remove individual resource-tab maximum widths/text trimming while keeping the outer horizontal viewport bounded and selected-index-following;
- render SpellSlot/WarlockSpellSlot with the native HotBar `Image + RomanNumeralLevelImage` contract instead of the incorrect CAM `TextBlock + SpellSlotNumberStyle` approximation.

Automatic proof must verify the LocalFocus->SelectedItem bridge, reject `ls:MoveFocus.IsFocused` as the cell-focus trigger, reject per-tab MaxWidth/TextTrimming, and require the native spell-level Image style. The next game run should not retest already-proven A semantics beyond a quick regression check; its main runtime questions are moving focus chrome, lower-row scrolling, and resource-tab labels/levels.


### 2026-10-07 — 0.0.60 runtime result / 0.0.61 proof boundary

0.0.60 runtime result:

- logical navigation, tooltip and A remain correct;
- the new selected-item highlight follows navigation;
- a second focus rectangle remains on the first cell, proving it is the inherited physical `FocusVisualStyle`, not CAM's logical-focus chrome;
- immediately after switching resource tabs, no CAM selection is shown until navigation, although first-slot focus is implied;
- resource labels/level presentation are materially improved and fit;
- when the resource strip has scrolled right, cycling from the last tab directly to the first does not scroll the first tab back into view.

0.0.61 automatic proof must require:

1. action-cell `FocusVisualStyle={x:Null}` and no native focus rectangle in addition to `CAM_CellFocus`;
2. resource-selection restoration of `HotBarList.SelectedIndex=0` after filtering without invoking `FilterActionResourceCommand` a second time;
3. deferred focus restoration to the same `HotBarList`;
4. both shoulder-cycle actions use `ForceSelect=True` and `ForceMode=Cycle`;
5. the existing bounded `AutoScrollBehavior` remains and no manual horizontal-offset mechanism is added.

The next game run should verify only: one moving focus visual with no stale first-cell rectangle; visible first-cell selection immediately after a tab switch; and last→first tab wrap bringing the first tab back into the visible strip.


### 2026-10-07 — 0.0.61 runtime result / 0.0.62 proof boundary

0.0.61 runtime result:

- removing the native physical `FocusVisualStyle` eliminated the stale first-cell rectangle, but the replacement exposed that CAM was still treating visual selection and controller focus as separate state;
- after a tab switch, the first cell is highlighted while D-pad navigation starts from the previous tab's old slot;
- A cannot immediately execute after switching tabs; one-item tabs are effectively unusable until another navigation event occurs;
- a strong border frame is still required in addition to fill because some focusable cells have little/no visible icon surface;
- `ForceSelect=True` introduced roughly four invisible/empty resource tabs by allowing shoulder cycling through collapsed `MaxValue=0` preview containers;
- the resource viewport still does not bring the first tab back into view after wrapping from the end.

0.0.62 automatic proof must require:

1. resource `SelectionChanged` clears `HotBarList.LocalFocus` and `HotBarList.SelectedItem` before filtering;
2. no resource-switch code writes `HotBarList.SelectedIndex`;
3. `SetMoveFocusAction(..., DeferFocusAction=True)` returns focus to the same `HotBarList` with no separate resource-switch timer, allowing the native `LocalFocusChanged` lifecycle to establish the first actual slot;
4. resource shoulder actions use `ForceMode=Cycle` but contain no `ForceSelect=True`;
5. `AutoScrollBehavior.ScrollIntoView` binds to `CAM_ResourceTabs.SelectedItem`, not `SelectedIndex`;
6. MaxValue=0/null previews remain visually collapsed and are not made forcibly selectable;
7. the cell focus template contains a translucent fill and a separate opaque border, both shown only for `IsSelected=True`;
8. A/tooltip/highlight still consume only `LocalFocus.DataContext` and `ActionRadials.Tag` through the existing native lifecycle.

The next game run should verify: no invisible tabs; last→first tab wrap shows the first tab; switching a resource immediately establishes a real first-slot focus and A works without any D-pad movement; one-item tabs execute immediately; and a visible border follows navigation even on visually empty cells.


### 2026-10-07 — 0.0.62 runtime result / 0.0.63 proof boundary

0.0.62 runtime result:

- invisible resource tabs are removed;
- the opaque frame and fill move together on real action cells;
- after a resource switch there is still no active first-slot focus, and the next directional move starts from the previous resource tab's old grid coordinate;
- generated empty grid coordinates are still navigable, but have neither action chrome nor useful interaction;
- while cycling resources left, the selected leftmost tab can remain outside the visible strip.

0.0.63 automatic proof must require:

1. resource SelectionChanged still clears `SelectedItem` and `LocalFocus`, filters exactly once, then invokes `SetMoveFocusAction InvalidateFocus=True` before the deferred return to `HotBarList`;
2. `CAM_ActionGridPanel` sets `AlwaysSelectFirst=True` while `UseWidgetNavigation=True` and `ls:MoveFocus.InternalFocusable=True` remain absent;
3. `CAM_ActionGridPanel` sets `ExtendedRows=False`, and CAM does not introduce an `EmptyCellTemplate` or synthetic empty action source;
4. the resource-strip `AutoScrollBehavior` follows `SelectedItem`, keeps `BringSelectionIntoView=True`, and adds `ScrollTo="Center"`;
5. no `SelectedIndex` resource-switch synthesis or `ForceSelect=True` regression returns;
6. A, tooltip and highlight still derive from the existing `LocalFocusChanged -> ActionRadials.Tag` lifecycle.

The next game run should verify only the runtime-only seams: tab switch starts on the first real action immediately; one-item tabs execute immediately; directional navigation cannot enter generated empty grid positions; and the selected tab remains visible when cycling in either direction.


### 2026-10-07 — 0.0.63 runtime result / 0.0.64 proof boundary

0.0.63 produced no noticeable behavioral difference from 0.0.62:

- resource-tab switch still leaves no active action focus and the next move begins from the previous tab's coordinate;
- one-item tabs still cannot be executed immediately;
- unoccupied grid coordinates remain navigable without visible focus or navigation feedback;
- cycling left can still leave the selected leftmost resource tab outside the visible strip.

This rejects the 0.0.63 hypotheses (`InvalidateFocus`, `AlwaysSelectFirst`, `ExtendedRows=False`, and `SelectedItem + ScrollTo=Center`) as fixes for these defects.

0.0.64 returns to runtime-proven seams:

1. a visible native `SelectorTemplate` is again the `HotBarList.LocalFocusSelector`, in the same `CAM_ActionViewport` coordinate root;
2. `CAM_ActionGridPanel` restores `EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"`;
3. `AlwaysSelectFirst` and `ExtendedRows` are absent;
4. resource `SelectionChanged` sets `SelectedIndex=-1`, filters exactly once, and does not clear `LocalFocus`, invalidate widget focus, or focus the list itself;
5. a 70 ms resource-switch timer arms `CAM_ResetFirstFocusToken` before setting `SelectedIndex=0`;
6. the selected concrete `ListBoxItem` consumes that token with `SetMoveFocusAction(... TemplatedParent ...)` and clears it;
7. `LocalFocusChanged` no longer mirrors the focused slot into `SelectedItem`; selector position, tooltip/highlight and A dispatch stay owned by LocalFocus;
8. resource AutoScroll uses `SelectedIndex`, `BringSelectionIntoView=True`, and `ScrollTo=Center`;
9. `ForceSelect=True` remains forbidden and hidden resource previews remain disabled.

The next game run is justified only after full package/release CI. Its focused questions are: immediate first-slot focus/A after a tab change (including a one-item tab), visible selector movement through occupied and native empty grid cells, and selected resource-tab visibility when cycling left/right.


### 2026-10-07 — 0.0.64 runtime result / 0.0.65 proof boundary

0.0.64 runtime result:

- resource-switch focus and subsequent D-pad navigation are materially improved;
- the first focused action after a resource switch does not show the normal tooltip until D-pad movement;
- the selected left-edge resource tab can still remain outside the visible strip.

0.0.65 automatic proof must require:

1. the 0.0.64 concrete-item focus handoff and native `CAM_MainSelector -> SelectorTemplate` path remain unchanged;
2. the resource-entry 70 ms timer still selects index 0, then uses only that one-shot `HotBarList.SelectedItem` to populate `CAM_ActionTooltip.Content`, invoke `ShowTooltipOnUIElementCommand`, set `ActionRadials.Tag`, and invoke `CreateFocusedTooltipDataCommand` / `HighlightResourcesCommand`;
3. normal `LocalFocusChanged` retains the existing tooltip/Tag/highlight lifecycle and does not mirror `LocalFocus` into `SelectedItem`;
4. resource `AutoScrollBehavior` has `BringSelectionIntoView=True` but no explicit `ScrollIntoView` and no `ScrollTo`;
5. no manual horizontal offset action, `ForceSelect=True`, or extra resource tab layer is introduced.

The next in-game check is limited to two seams: the tooltip must already be visible on the first focused action immediately after a tab change, and the selected resource tab must remain visible while cycling in both directions.


### 2026-10-07 — 0.0.65 runtime result / 0.0.66 proof boundary

Observed in 0.0.65:

- focus/navigation remains better than pre-0.0.64 builds;
- after switching a resource tab, tooltip describes the first slot while visible focus can remain on the previous coordinate;
- selected left-edge resource tab can still remain outside the viewport;
- pressing B to leave a nested action/upcast/container can leave the selected resource tab with an empty action grid.

0.0.66 automatic proof must require:

1. resource `SelectionChanged` clears `HotBarList.LocalFocus` and `SelectedIndex` before invoking `FilterActionResourceCommand`;
2. the 70 ms entry timer only arms the concrete-item focus token and selects index 0; it must not write tooltip content, `ActionRadials.Tag`, tooltip-data or highlight state from `SelectedItem`;
3. the existing `LocalFocusChanged` lifecycle remains the sole source for tooltip/Tag/highlight/A state;
4. selected resource item containers publish their templated-parent UIElement to `CAM_ResourceTabs.Tag`;
5. the resource template uses `ls:LSScrollViewer.ScrollToElement="{Binding Tag, ElementName=CAM_ResourceTabs}"` and contains no resource-strip `AutoScrollBehavior`;
6. entering any native nested flag arms a CAM nested-return marker;
7. B/top-level close does not restore the filter unless that marker was armed;
8. after nested cancel and return of all native nested flags to false, CAM re-applies exactly the currently selected native resource filter and re-establishes action LocalFocus;
9. `ClearSingleHotbarCommand`, native nested flags, `UseSlotCommand`, and resource-filter semantics remain BG3-owned.

The next game run should verify only these user-visible seams: tooltip and selector never disagree after resource switching; the selected edge resource tab is actually visible in both directions; B from one real nested/upcast/container view returns to a populated version of the same resource tab.


### 2026-10-07 — 0.0.66 runtime result / 0.0.67 proof boundary

Observed in 0.0.66:

- nested/upcast/container B return works and repopulates the original resource tab;
- after a resource switch, the focused action still may not show a tooltip until D-pad movement;
- after nested return, the focused action likewise may not show a tooltip until movement;
- the selected resource tab still does not scroll into view.

0.0.67 automatic proof must require:

1. the 0.0.66 nested-return marker/filter restoration remains byte-semantically intact;
2. action presentation is driven by `PropertyChangedTrigger Binding="{Binding LocalFocus.DataContext, ElementName=HotBarList}"`;
3. that trigger owns tooltip content/show-hide, `ActionRadials.Tag`, tooltip data, and resource highlighting from `LocalFocus.DataContext`;
4. `LocalFocusChanged` no longer owns those presentation writes and remains only for navigation sound;
5. there is no delayed `TimerTrigger EventName="LocalFocusChanged"` presentation path;
6. resource `LSScrollViewer.ScrollToElement` binds through `RelativeSource TemplatedParent`;
7. the resource template contains no `ElementName=CAM_ResourceTabs` scroll binding, no `AutoScrollBehavior`, and no manual offset logic.

The next game check should be limited to: tooltip immediately present after a resource switch, tooltip immediately present after nested B return, and selected edge resource tabs visibly scrolling in both directions.


### 2026-10-07 — 0.0.67 runtime result / 0.0.68 proof boundary

Observed in 0.0.67:

- resource strip still does not scroll;
- switching resource tabs still leaves the newly focused action without a tooltip until subsequent navigation;
- nested B return remains functionally correct, but the restored focused action likewise lacks its tooltip until navigation;
- no observable improvement over 0.0.66 in these two seams.

0.0.68 therefore removes both rejected mechanisms rather than varying them again.

Automatic proof must require:

1. 0.0.66 nested-return marker/filter restoration remains unchanged;
2. `HotBarList.LocalFocusChanged` again owns normal D-pad tooltip/Tag/highlight synchronization from `LocalFocus.DataContext`;
3. a widget-level `PropertyChangedTrigger` on `FocusedElement` performs the same synchronization for programmatic entry while still sourcing the action from `HotBarList.LocalFocus.DataContext`;
4. no action presentation or dispatch path uses `HotBarList.SelectedItem` or `FocusedElement.DataContext`;
5. the ineffective `PropertyChangedTrigger(LocalFocus.DataContext)` is absent;
6. `CAM_ResourceTabsPanel` is an `ls:AlignableWrapPanel`;
7. the resource list template has no ScrollViewer/LSScrollViewer and no AutoScrollBehavior;
8. the resource header row is auto-sized while `CAM_ActionViewport` remains 850px high;
9. LB/RB shoulder cycling remains one-dimensional and the native resource filter contract is unchanged.

The next runtime check is limited to: immediate tooltip after tab switch, immediate tooltip after nested B return, and all selected resource tabs remaining visible without horizontal scrolling.


### 2026-10-07 — 0.0.68 runtime result / 0.0.69 proof boundary

0.0.68 runtime:
- resource tabs are visible but wrap into multiple rows, which is undesirable;
- tooltip still does not appear after resource tab switching;
- previously proven nested B return remains functional.

0.0.69 automatic proof must require:

1. resource tabs use `LSActionPointResources`, `ActionResourcesTemplateSelector`, the native 72px resource-box geometry and `RomanNumeralLevelImage`;
2. text resource-name/fallback labels and `AlignableWrapPanel` are absent from the resource tab row;
3. `PassivesHotBar.SlotList` enters shipping runtime only as the explicit Passives top-level mode;
4. one `HotBarList` switches between `SingleHotBar.SlotList` and `PassivesHotBar.SlotList`; no second executable grid is introduced;
5. passive mode uses only the CAM presentation token on `CAM_ResourceTabs.Tag`; no unproven BG3 passives-mode command/property exists in runtime;
6. LB/RB cycling can cross both boundaries between the native resource sequence and Passives;
7. item action cells delegate `VMHotBarSlot.Content` to native `Template.Item`, which owns `VMItem.Count`, `AbbreviateNumberConverter`, and `ItemAmountTextStyle`;
8. tab entry clears LocalFocus before selecting index 0;
9. entry-only tooltip/Tag/highlight state comes from the same first `HotBarList.SelectedItem` handed to concrete-item focus;
10. normal `LocalFocusChanged` remains the live navigation authority;
11. the 0.0.68 `FocusedElement` presentation trigger is absent;
12. 0.0.66 nested-return restoration remains unchanged for resource mode.

Next runtime proof should be limited to:
- one-row native resource icons;
- Passives reachable in both LB/RB directions and populated;
- first action immediately focused with matching tooltip after resource and Passives transitions;
- item/scroll/potion quantities visible when count > 1;
- nested B return still works.


### 2026-10-07 — 0.0.69 runtime result / 0.0.70 proof boundary

0.0.69 runtime:
- compact tabs render, but their inner resource visuals do not match the keyboard/mouse HotBar icons;
- after a top-level tab switch the tooltip is populated from the first cell while controller focus/selection remains at the previous coordinate;
- therefore the `CAM_EntryFocusCommittedToken -> SelectedItem` path is rejected as proof of focus.

0.0.70 automatic proof must require:

1. resource tabs render `ActionResource` with native `SectionImageStyle`; `LSActionPointResources` is absent from the tab template;
2. spell-slot tabs retain `RomanNumeralLevelImage`;
3. the concrete selected-item `SetMoveFocusAction(DeferFocusAction=True)` handoff remains, and consuming `CAM_ResetFirstFocusToken` clears the token directly;
4. `CAM_EntryFocusCommittedToken` and entry-only `SelectedItem` tooltip/Tag/highlight writes are absent;
5. programmatic entry refresh reads only `HotBarList.LocalFocus.DataContext`;
6. stale `LocalFocus`, tooltip, A target and resource highlights are cleared before filtering/switching lists;
7. ordinary D-pad presentation remains `LocalFocusChanged -> LocalFocus.DataContext`;
8. Passives, item counts and nested-return behavior from 0.0.69 remain intact.

Next runtime proof should check only:
- resource tab icons against the keyboard/mouse HotBar;
- resource -> resource, resource -> Passives and Passives -> resource transitions all visibly move the selector to cell 1;
- tooltip belongs to that same visibly focused cell immediately after the transition;
- one D-pad move continues from that first cell rather than from the old tab coordinate.


### 2026-10-07 — 0.0.70 runtime result / 0.0.71 proof boundary

0.0.70 runtime:
- Passives does not behave like an ordinary tab, especially on return to resources;
- resource-tab visuals still do not match the keyboard/mouse HotBar.

0.0.71 automatic proof must require:

1. resource tabs use `LSActionPointResources + ActionResourcesTemplateSelector`, not `SectionImageStyle`;
2. resource point bindings match the HotBar preview contract: MaxValue / Value / Cost over ActionResource;
3. SpellSlot and WarlockSpellSlot retain `RomanNumeralLevelImage`;
4. the resource-value numeral overlay exists and is hidden for values representable by the native point group;
5. Passives -> resource-right keeps passive mode set until the delayed return boundary and filters the preserved first resource before mode switch;
6. Passives -> resource-left uses a distinct `CAM_TabReturnLastToken`, changes only the resource-list selection during the click, filters that last resource while passive mode remains active, then switches mode after the click;
7. ordinary resource-cycle Click handlers are ineligible while passive mode is active;
8. one LB/RB press cannot execute both a Passives-return path and an ordinary resource-cycle path;
9. action focus/tooltip remains LocalFocus-owned and nested-return behavior remains unchanged.

Next runtime proof should be limited to:
- compare Action, Bonus Action and at least one spell-slot/resource tab directly with the keyboard HotBar;
- enter Passives from both ends and return with the opposite shoulder;
- verify each shoulder press advances exactly one logical tab;
- verify the returned resource grid starts at the first action with matching tooltip.


### 2026-10-07 — 0.0.71 runtime result / 0.0.72 proof boundary

0.0.71 runtime:
- top-level resource tabs show unwanted/stray numeric overlays;
- item-backed action cells still do not show stack quantity like inventory/keyboard HotBar;
- resource-tab chrome still differs from the current keyboard HotBar, especially spell-slot resources.

0.0.72 automatic proof must require:

1. `ResourcesNumeralDisplay` and any CAM-authored resource-value `TextBlock` are absent from the top-level tab template;
2. normal resources use captured `box_resource_*` assets;
3. SpellSlot and WarlockSpellSlot switch to captured `box_resourceNum_*` assets and retain `RomanNumeralLevelImage`;
4. the resource glyph remains `LSActionPointResources + ActionResourcesTemplateSelector`;
5. the action-grid template contains no `GameObject.Count` quantity overlay;
6. `SlotType=Item` switches to a `ContentPresenter Content="{Binding Content}"` using native `Template.Item`;
7. item equipment/container presentation uses `Template.ItemEquipment` / `Template.ItemContainer`;
8. non-item actions retain the 104x104 `Content.Icon` assignment surface;
9. focus, tooltip, Passives serialization, nested return and A/B dispatch remain unchanged.

Runtime proof should verify:
- no stray numbers appear on resource tabs;
- Action / Bonus Action / spell-slot tabs visually match the keyboard HotBar resource chrome;
- stacked scrolls, potions and other usable items show the same stack quantity treatment as inventory/keyboard HotBar.


### 2026-10-07 — 0.0.72 runtime result / 0.0.73 proof boundary

0.0.72 runtime:
- stray tab numbers are gone;
- item stack counts now render correctly;
- top-level tabs still do not resemble the keyboard/mouse HotBar filters.

The remaining issue is presentation-only. Automatic proof for 0.0.73 must require:

1. top-level resource tabs use the current HotBar `FilterButton / ActiveFilterButton` asset family: `btn_pil_d`, `btn_pil_active_d`, `btn_pil_disabled`;
2. selected tabs expose the native top marker using `btn_pil_inactivemod_d + ActiveModArrow`;
3. filter chrome uses nine-slice `Slices=36`, `Padding=10`, and native `Margin=-4,0`;
4. `box_resource_*` and `box_resourceNum_*` are absent from the top-level tab template and Passives tab;
5. resource identity remains native `LSActionPointResources + ActionResourcesTemplateSelector`;
6. spell-slot tabs retain `RomanNumeralLevelImage`;
7. no resource-name labels or resource-value numerals are introduced;
8. Passives uses the same filter chrome as resource tabs;
9. item templates, focus/tooltip authority, Passives transition serialization, nested return and A/B dispatch are unchanged.

Next runtime proof is limited to the visual comparison of the top filter row. Item quantity does not need to be retested unless it visibly regresses.


### 2026-10-07 — 0.0.73 runtime result / exact HotBar capture gate

0.0.73 runtime:
- item stack quantities remain fixed;
- stray resource numerals remain removed;
- the top row still does not resemble the keyboard/mouse HotBar resource filters.

The previous test contract targeted the wrong native component. `FilterButton / ActiveFilterButton` is the textual deck-tab presentation, not the `ActionResourcesCostPreview` icon filter row the operator is using as the reference.

No further visual candidate is allowed until a fresh read-only capture provides the exact installed Patch 8 `HotBar.xaml`.

The capture milestone must prove:

1. the archive contains `Mods/MainUI/GUI/Pages/HotBar.xaml`;
2. the captured HotBar hash is recorded in the manifest;
3. the same archive contains the relevant shared `DataTemplates.xaml` and related UI resources already targeted by the capture tool;
4. capture is read-only and does not launch BG3 or mutate installation/profile/mod state;
5. the universal VBS can invoke the capture task through the release-controlled `dev-entry.ps1`;
6. the generated status/report identifies the ZIP that must be returned for analysis.

After the ZIP is inspected, the next runtime candidate should change only the top resource-filter presentation and should be tested once against the keyboard/mouse HotBar. Item quantity does not need targeted retesting unless it visibly regresses.


### 2026-10-07 — exact HotBar capture / 0.0.75 proof boundary

The read-only 1.8.910.0 capture contains the exact current `Mods/MainUI/GUI/Pages/HotBar.xaml` with SHA-256 `9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.

The previous 0.0.73 assumption is disproven: `btn_pil_*` belongs to textual deck/category filters, not the icon resource-filter row.

0.0.75 automatic proof must require:

1. a shared resource-strip background using `Assets/BottomBar/bar_resources.png`, height 64, `Slices="104,0"`, min width 208 and width bound to the visible tab row plus 208;
2. resource entries continue to come from `CurrentPlayer.UIData.ActionResourcesCostPreview`;
3. each resource visual is 72px wide and uses the native resource-button geometry: inner margin `4,-10,4,10` and outer presenter/container margin `-4,0,-4,0`;
4. ordinary resource chrome uses `box_resource_empty/d/h/missing`;
5. `LSActionPointResources` uses `ActionResourcesTemplateSelector`, `SmallActionPointSize=24`, `ActionPointGroupSize=56`;
6. SpellSlot and WarlockSpellSlot use `box_resourceNum_*`, the native -8px chrome offset, and `RomanNumeralLevelImage` with the native -10px top offset;
7. zero-value resources show the missing/disabled chrome;
8. controller-selected resources map to the native hover/highlight chrome and that highlight is suppressed while Passives mode is active;
9. the resource numeral is conditional exactly like HotBar — visible only when `ActionResource.Value > ResourcePoints.MaxGroupActionPoints`, never as an unconditional value label;
10. Passives is an explicit CAM exception rendered as a 72px resource-box-style entry inside the same shared strip;
11. `btn_pil_*`, `ActiveModArrow`, and textual-filter marker chrome are absent from the resource tab presentation;
12. item quantity templates, focus/tooltip authority, Passives serialization, nested return and A/B dispatch are unchanged.

One runtime proof is then sufficient:
- compare the complete top strip directly with keyboard/mouse HotBar;
- verify Action, Bonus Action, at least one spell-slot resource and Passives;
- confirm no stray always-on numbers;
- confirm an actually large scalar resource uses the native numeric fallback if present;
- confirm LB/RB still changes one logical tab and the selected grid starts at the first action with the correct tooltip.


### 2026-10-07 — 0.0.75 resource-content result / 0.0.76 proof

0.0.75 still renders resource-tab contents as visually broken/ambiguous compared with the resting keyboard/mouse HotBar.

The exact capture shows why: HotBar's `Cost` highlight is transient and bracketed by mouse enter/leave. CAM's controller focus is persistent, so retaining `HighlightResourcesCommand` makes that transient preview permanent.

0.0.76 automatic proof is split deliberately:
- the existing self-contained runtime test continues to require the exact captured renderer and native `Cost` binding;
- `test-resource-tab-resting-preview.ps1` requires all three CAM action-focus `HighlightResourcesCommand` seams to be disabled;
- the same immediate/delayed/programmatic focus boundaries must invoke `ClearResourceHighlightsCommand`;
- tooltip/Tag identity must remain `LocalFocus.DataContext`;
- conditional native `ResourcesNumeralDisplay` stays intact.

The next in-game check is limited to whether the tab contents now communicate current resource quantity like resting HotBar.


### 2026-10-07 — literal HotBar resource item acceptance

Runtime feedback after the exact-resource-bar work: resource contents still look broken compared with keyboard/mouse HotBar. The next proof is structural rather than asset-based.

For native resource entries:

1. `CAM_ResourceTabs` remains the LB/RB filter owner;
2. its `ListBoxItem` container has no selected-state resource visual;
3. `ItemTemplate` contains native `LSButton Padding="0" Margin="4,-10,4,10"`;
4. the subtree matches captured `ActionResourcesList`: `Root Width=72`, exact resource layers, exact value/max/cost bindings, 24/56 point sizes, numeral fallback, spell-slot chrome and Bardic adjustment;
5. `IsMouseOver`, not `ListBoxItem.IsSelected`, owns `box_resource_h`;
6. zero resource value owns missing-resource chrome;
7. outer presenter keeps `Margin=-4,0,-4,0`;
8. shared `bar_resources.png` strip remains unchanged;
9. 0.0.76 resting resource-preview behavior remains unchanged;
10. Passives remains a synthetic adjacent entry.

In-game acceptance is one direct visual comparison against keyboard/mouse HotBar.


## 2026-10-07 — 0.0.78 coverage-first HotBar proof boundary

The current completion target is no longer "resource tabs render and execute". It is native
HotBar/radial gameplay parity as defined by `docs/action-coverage.md`.

Automatic proof before any new game run must establish:

1. the pinned evidence keeps the unresolved native action classes explicit rather than
   silently treating `FilterActionResourceCommand` as a complete catalog;
2. the portable capture emits `hotbar-coverage-contract.json` and records every current
   `SetCurrentShownDeckCommand`, `FilterCantripsCommand` and
   `FilterActionResourceCommand` element with its command parameter;
3. raw `SpellsAndActions`, `Inventory.Slots` and passive-predicate objects remain
   reference evidence only and are never passed to `UseSlotCommand`;
4. `HotBarList.LocalFocus.DataContext` remains the action identity authority;
5. the action viewport uses the captured controller focus-follow transport
   `ActionRadials.FocusedElement -> LSScrollViewer.ScrollToElement`;
6. resource filtering, Passives, native nested/upcast/container/throw state, native
   tooltip and page-level A/B dispatch remain unchanged.

Do not request an in-game run merely to verify the action-grid scrolling change or one
speculative missing source. The next runtime milestone is justified only after static
source work has reduced the remaining questions to semantic parity that the BG3 VM must
materialize at runtime.

That combined run should cover, in one session where available: free/no-resource action,
Cantrip, normal Action and Bonus Action, leveled/upcast spell, class resource, passive,
metamagic, consumable, Scroll, item charge, temporary action, recast, nested variant,
throw, concentration, dual-wield state and weapon-set shortcut status.


### 2026-10-07 — 0.0.85 native target-position resource scrolling

The next static milestone isolates resource-tab overflow after native provider coverage is complete. It does not change resource filtering, action focus, A/B, or nested execution.

Automatic proof must require:

1. provider mode is stored only in `CAM_ProviderModeMarker.Tag`;
2. the selected resource `ListBoxItem` publishes its concrete UIElement to `CAM_ResourceTabs.Tag` without changing native resource chrome;
3. the resource list owns `CAM_ResourceTabsScroller` with horizontal pixel scrolling and one horizontal `StackPanel` row;
4. `ScrollToElement` binds to the templated list's `Tag`;
5. `TargetPositionChanged` commits `TargetPosition` to `HorizontalScrollOffset`, matching the current captured controller radial seam;
6. `AutoScrollBehavior`, SelectedIndex/SelectedItem scroll targets, wrapping, and `ForceSelect=True` remain absent;
7. special provider tabs are outside the resource scroll owner and stay visible;
8. action-grid focus/tooltip/A/nested contracts are byte-semantically unchanged except for provider-mode marker references.

No standalone game run is requested for this correction. It belongs in the next combined milestone test with provider parity and focus/tooltip verification.


### 2026-10-08 — weapon-set input transport capture contract

The weapon-set shortcut remains intentionally absent. Runtime releases 0.0.51–0.0.54 already reject all known CAM-owned transports, including the hold-threshold variant. No fifth input guess is allowed.

The portable capture now emits schema-v3 `hotbar-coverage-contract.json` with `InputTransportProbes`. In one read-only capture it must search all captured XAML for:

- `SwitchWeaponSetCommand`;
- `ToggleWeaponSet`;
- `UISelectionLeft`;
- `ControllerHoldButtonStyle`;
- `WeaponSetSwitchStyle`;
- `LSInputBinding`;
- `HoldTimeShortcuts`.

Each matching tag records source file, element/name, `BoundEvent`, `EventName`, command/parameter, style/content, hold/tap thresholds, `EatInput`, setter property/value and raw tag. Missing symbols are recorded in `MissingInputTransportSymbols` and do not fail capture.

The next operator capture should therefore answer the weapon-set transport question together with the remaining HotBar/radial parity questions; do not ask for a separate weapon-set-only test.


### 2026-10-08 — 0.0.87 return to combined gameplay proof

Readback of `bg3-controller-action-menu-inputs-20261008-093541.zip` is recorded in `docs/research/schema-v3-capture-2026-10-08.md`. All 22 game-XAML payloads match the previous archive byte-for-byte. No new ActionRadials-safe weapon-set shortcut transport or runtime parity proof was discovered. Do not request another capture of the same Patch 8 files.

The universal VBS now returns to `install`, using the existing self-contained PAK helper. Static release acceptance must prove: exact release version, existing installer delegated in-process, stale LASTEXITCODE ignored, child exception fails closed, status/log/report produced, and no capture/Game.pak scan in normal install. The existing installer fixture remains responsible for PAK application semantics.

Only after published release proof, the operator may use the unchanged VBS **once** to install this milestone. Then perform one combined in-game observation covering tab overflow/cycling, first-cell LocalFocus/tooltip/A, grid scrolling, nested upcast/container/B return, item quantities, native action-category parity and unsupported weapon-set status. This is the first test of combined changes since the capture-only phase, not a claim of runtime verification by CI.


### 2026-10-08 — 0.0.88 resource-tab mode and chrome regression fix

User runtime: resource/special tabs look misaligned compared to native HotBar and LB/RB does not switch tabs.

Code readback identified the exact 0.0.85 break: 22 mode-condition reads still queried `CAM_ResourceTabs.Tag` after the resource-tab scroller repurposed it as a selected concrete UIElement. The correction routes those reads to `CAM_ProviderModeMarker.Tag`. Each of the sixteen LB/RB Click handlers now rejects an input already being processed through `CAM_TabCycleMarker.Tag`, preventing chained mode transitions within a single press.

CI must parse the exact XAML, assert no `{Binding Tag, ElementName=CAM_ResourceTabs}` provider-mode readers remain, verify nine guarded LB transitions and seven guarded RB transitions, preserve the element-based horizontal scroller, and require identical `CAM_ResourceBackgroundMargin` alignment on all five special provider normal/hover frames. The native resource `VMActionResourceCostPreview` template is not modified. Run full installer/runtime/package/capture CI before release. Do not mistake a passing static check for a game-runtime pass.


### 2026-10-08 — 0.0.89 native resource visuals and selection

Reported runtime: LB/RB tab switching works in 0.0.88, but resource tab content is misaligned and no controller selection highlight matches keyboard HotBar. Full original capture inspection found an objective missing key: `HotBar.xaml` has `<Thickness x:Key="ResourceBackgroundMargin">0</Thickness>`, while CAM referenced its own `CAM_ResourceBackgroundMargin` thirteen times without defining it. This also affected the special-tab frame alignment added in 0.0.88.

The current correction declares that missing key with its exact native value and maps selected `ListBoxItem` in resource-provider mode to the same `BoxResourceH` visibility used by original `IsMouseOver`. It does **not** import the entire keyboard HotBar page, replace controller state, add synthetic resource data, or change working LB/RB transitions.

CI must now require zero undeclared CAM local resources, the original zero resource-box margin, a mode-gated controller highlight trigger in the copied native resource template, and precedence of exhausted resource visuals. One combined in-game inspection must still verify actual glyph alignment and highlight for both normal and special tabs; screenshot evidence is useful if further pixel correction is needed.


### 2026-10-08 — 0.0.90 bottom baseline parity

After successful 0.0.89 LB/RB operation, the user still reports visually crooked resource-tab indicators. Static comparison with the already captured original `HotBar.xaml` reveals that four native resource-strip elements are bottom-aligned while CAM has centered their counterparts within an 84-unit row. The five special provider frames were also centered. This correction pins `VerticalAlignment=Bottom` on the corresponding CAM elements, preserving every VM slot/filter/input binding and image resource.

Regression checks assert bottom anchoring of the resource strip, nine-slice chrome, resource StackPanel, resource list/panel, and all five special providers. Resource art and point-size values stay unchanged because the existing screenshot predates the 0.0.89 correction and cannot justify arbitrary scaling. The next in-game screenshot should compare the new 0.0.90 geometry against the native HotBar before selecting any additional image-size changes.

## 2026-10-08 — full BG3 gameplay reachability comparator (#135)

The operator requires **every gameplay capability** of the vanilla
controller action menu to remain accessible. There is no feasible
manual test matrix for every BG3 class, equipment state, mod,
temporary action or recast. The source audit of 36 command names
is therefore only an early regression check.

The full 25-capability policy is now pinned in
`docs/evidence/native-gameplay-capabilities.json`. Every CI
Validate run executes:

```text
python tools/compare-runtime-gameplay.py --self-test
```

The test must reject missing native executable IDs, missing native
global controller capabilities and incomplete observations, while
allowing one executable identity to appear in multiple native
providers. Game-state observations must contain a full variant-
and-resource-aware stable native identity; generic spell labels
alone are insufficient.

A future development-only read-only probe can supply:

```text
python tools/compare-runtime-gameplay.py --observation observation.json --json
```

No real runtime inventory is available in CI or the existing static
capture, so the checker reports `awaiting-runtime-proof`. Its
successful synthetic fixture check does not close gameplay parity,
and the user must **not** be asked to enumerate all actions manually.

## 2026-10-08 — source-backed original radial slot fallback (#138)

A native `ControllerHotBars[*].SlotList` group is already a
`VMHotBarSlot` source. To avoid losing originally configured
radial actions that are missing from CAM resource/keyboard
providers, a read-only Original Radials tab is added as one
optional LB/RB mode, without new input shortcuts.

Structural CI verifies presence, native slot owner,
both directions of the availability guard, root focus/dispatch
and nested restoration. It cannot prove runtime that the
grouped original bars select/execute and restore B correctly;
this belongs in the next combined game milestone with metamagic
and resource filter tests. Global weapon-set/light-source
buttons remain separately blocked and are **not** claimed
restored by this fallback.
