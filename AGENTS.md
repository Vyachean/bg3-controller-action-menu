# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The primary runtime target includes the **Xbox App / Microsoft Store PC build**, so the shipping mod must work as a normal BG3 `.pak` without third-party runtime injection.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI composition.**
   Reuse BG3-owned view models, templates, styles and commands wherever possible. The `ActionRadials` state/page and outer native template semantics are BG3-owned. The main CAM surface is an automatically populated action catalog derived from the same current native collections used by radial slot assignment; the user must not have to maintain radial slots for CAM. `SingleHotBar` remains BG3-owned for nested/upcast/variant choices.

3. **No Script Extender dependency in the shipping package.**
   `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu` must not contain a `ScriptExtender` directory. Script Extender experiments may live under `dev/`, but they are not part of the runtime package or required workflow.

4. **Xbox App / PC compatibility is a release gate.**
   Do not introduce DLL/native-loader/Script-Extender requirements into the primary build.

5. **Controller-first.**
   Every interactive element must have deterministic controller focus/navigation. Mouse support is secondary.

6. **Do not optimize around unverified assumptions.**
   If an engine binding, data shape, page/state name, or dispatch mechanism is not proven against the current game/toolkit/open Patch 8 resources, document it and isolate it.

7. **Minimize manual testing.**
   Add static validation, package round-trip verification and visible in-game diagnostics for everything that does not require a running game.

8. **Milestone game tests only.**
   In-game testing should be requested only when a build crosses a runtime proof boundary that cannot be established statically. Do not ask the user to validate one speculative binding/layout hypothesis per build. First exhaust current game-file inspection, public Patch 8 resources, deterministic fixtures and package checks; then combine remaining runtime-only questions into one high-information run.

## Pending #166 source-level cost-feedback candidate (2026-10-09)

The operator reports that CAM no longer highlights the predicted cost of the focused action in BG3's ordinary resource bar. The historical 0.0.75/0.0.76 rule below correctly rejects *permanent action-hover cost highlights in CAM's upper navigation tabs*. It must not be interpreted as permission to disable the original game's controller resource-cost feedback altogether. For this draft candidate only, CAM's upper resource navigation glyphs retain native available/max/identity artwork with `HighlightedActionPoints=0`, while the original BG3 `HighlightResourcesCommand` is delivered a proven focused `VMHotBarSlot` **after** focus stabilizes. A focus/provider transition first clears stale highlights, not the newly established one. This alters one aspect of the exact-keyboard tab renderer intentionally and requires a combined game milestone before merge/release. Do not report it as runtime proven from CI alone. See `docs/research/resting-resource-preview-2026-10-07.md` and issue #166.

## Draft selected-tab title layout #165 (2026-10-09)

The reported v0.0.110-style `CAM_SelectedResourceName` inside the native 84px strip with a negative top margin overlaps tabs and hides all special-provider captions. A draft correction moves the title to an explicit 32px root row while preserving the 84px original resource artwork and 850px action viewport at their previous screen coordinates. Resource text must continue to bind the original `CAM_ResourceTabs.SelectedItem.ActionResource.Name`; never classify resources from single-letter icons. The five special modes have temporary readable English labels pending **verified native BG3 localization handles**. Do not declare these temporary strings localized or final. Do not change resource button art, filtering, LB/RB selection, slot focus or execution while fixing labels. Validation is source-only until one combined published-Release gameplay test.

## 2026-10-09 footer safe-area correction (#167)

The operator's latest in-game run reproduces a historical 0.0.35 defect: horizontal **centering** of `ButtonHintsContainer` overlaps the original center-bottom action-resource HUD. This overrides the old generic instruction below to preserve the centered variant unchanged. Retain all original native controller button styles, commands, input glyphs, visibility rules and `Width=Auto` compact variant, but place the panel back in the **game-owned right-side hint lane** (`HorizontalAlignment=Right`, `HorizontalContentAlignment=Right`, `FlowDirection=RightToLeft`) with a bounded `MaxWidth`, not a giant 1000px child or centered 1320px row. The width cap is a source-level proposal, not in-game proof at all UI scales. Never rebind `UISelectionLeft`, remap D-pad, or introduce another input shortcut to fix overlapping hints. One combined game run after an actual published Release is the only runtime acceptance route. See #167.

## Partial native LB entry hover sound candidate (#160; 2026-10-09)

The `ActionRadials.Metadata=MoveToEnd` entry is the only controller-opening branch that selects grouped All instead of a direct resource filter. Runtime user report: RB entry has sound and rumble, LB entry has neither. The native `UI_HUD_Controller_RadialMenu_SlotHover` sound identifier is already proven in CAM's normal `HotBarList.LocalFocusChanged`. A source-only candidate plays it exactly once on the **existing LB/MoveToEnd Loaded branch**, not on LB/RB ordinary tab navigation, not on RB entry and not on inner group focus. It must preserve the source-owned opening direction, selected provider, 70ms slot handoff, A/tooltip identity and native input. This fixes **only the audio path in theory**. There is no proven native haptic API in the captured UI contract. Never fabricate a vibration binding, infer that sound causes rumble, or claim complete #160 acceptance from green CI. Test the sound and haptic separately in the combined published-Release milestone.



## 2026-10-09 runtime correction after published v0.0.111

Operator's actual test disproved three visual/audio assumptions in the preceding milestone:

- LB/MoveToEnd **double-played** its menu opening sound and still did not vibrate. The additional `LSPlaySound(UI_HUD_Controller_RadialMenu_SlotHover)` at `CAM_ResourceTabs.Loaded` was a duplicate; remove it. Opening audio/haptics must ultimately come from a **single proven native lifecycle**. Do not claim this source rollback fixes missing LB vibration.
- A 32px title row did **not** prevent selected resource/provider text from overlapping original tab art. New bounded visual candidate uses a **64px** reserved title lane, a top-aligned 44px clipped text box and 20px gutter. The center-offset is adjusted from -16 to -32 so native 84px tab row and 850px grid retain their prior positions. Actual scaled Noesis rendering is not proven by static geometry.
- Right-hand hint panel `MaxWidth=380` **clipped** original controller hints. Increase the bound to **600px** while keeping right-side placement and compact `Width=Auto` children; native center HUD non-overlap must be checked in game, not asserted from maximum width alone.

The same operator explicitly **confirmed resource-cost highlighting works**; preserve its native `HighlightResourcesCommand` paths, including focused metamagic slots, and do not disable them while repairing focus UI.

Other uncorrected v0.0.111 issues: in-menu weapon hold/progress, metamagic focus-frame divergence, selected metamagic not handing focus to compatible spell grid, duplicated IV-level upcast choice (#172), and LB haptics. Do not advertise any of these as fixed by the local audio/layout rollback. Prepare a combined source/CI-reviewed candidate and one published-Release gameplay check, never one release per tweak.



## Draft game-owned metamagic spell-focus phase — 2026-10-09 (#155, #158)

User's v0.0.111 observation: activating a native metamagic `VMHotBarSlot` correctly highlights compatible spells, but controller focus stays trapped in `CAM_FixedSideBarList` because the original implementation disables `HotBarList` unconditionally in `CAM_MetamagicModeToken`. Native input cannot reach the spells grid, and the sidebar selection/focus frame can diverge.

A source-only draft introduces one presentation marker `CAM_MetamagicSpellPhaseMarker` (not a game-action or input binding) to distinguish two phases *within the existing Metamagic top-level tab*. After native `PlayerCharacterProperties.MetamagicActive=True` is observed, with no native nested/upcast/throw state, it invalidates old sidebar `LocalFocus`/tooltip/`ActionRadials.Tag`, switches the list owners **sidebar enabled only while phase=null; main HotBarList enabled when phase=spell**, and invokes the already-proven `SetMoveFocusAction(DeferFocusAction=True)` onto the existing filtered real `VMHotBarSlot` grid. `UseSlotCommand`, BG3-owned resource costs, tooltip, `Content.IsModified` visuals and native selection/casting semantics remain unchanged. `CAM_FixedSideBarList.SelectedItem` mirrors its actual `LocalFocus.DataContext` during sidebar navigation to keep selected frame/action identity coherent.

The marker resets when native `MetamagicActive=False` or the provider changes. On native nested/back return, the exact currently active metamagic phase selects either sidebar or spell grid; no hardcoded spell predicates and no second input binding. The **top-level B from the spell-choice phase** still follows the old general controller close-widget contract until a separately proven safe back-one-level transport is found; therefore do **not** mark full #158 acceptance or promise B returns to the selector from the new phase. Also do not claim the grid has been filtered to compatible spells (only BG3-owned visual compatibility feedback is proven). The target is a small, source/CI-reviewed *runtime candidate* to be tested together with #173 in one later published-Release run, not a new per-change release.

## Functional parity is not original radial layout parity (2026-10-08)

The operator requires full gameplay-capability parity with BG3, not preservation of the player-configured original radial layout. An **Original Radials** tab or runtime dependence on manually configured `ControllerHotBars` is rejected. Inspect `ControllerHotBars` as independent reference evidence only. CAM must discover available actions automatically from verified BG3-owned executable slot providers and retain native global controller functions, rather than relying on assigned original radial slots.

Keep a single resource/special-category tab row. Native resource variants may legitimately appear in several tabs. Never compute gameplay costs, create synthetic actions from raw catalogs, or replace `VMHotBarSlot -> UseSlotCommand`. A missing capability is a blocker for #135, not justification for a configured-radial fallback. #134 and #135 require executable identity proof; source command audits alone cannot close them.

## Metamagic functional parity — source-gated 0.0.99 candidate

The operator confirmed that 0.0.98 finally matches the original
keyboard resource glyphs; **do not touch that visual implementation**.
A separate gap #125 is metamagic: the keyboard HotBar renders native
`FixedSideBar` concurrently with spells, while old CAM replaced the
entire grid with that list. Original installed 1.8.910.0
`HotBar.xaml` and `DataTemplates.xaml` were inspected in
`bg3-controller-action-menu-inputs-20261008-132651.zip`; pinned
SHA-256 and binding/trigger evidence are in
`docs/research/metamagic-parity-2026-10-08.md`.

The candidate adds a **parallel VMHotBarSlot** sidebar and restores
the original native `Content.IsModified` and `IsActive` visual
indicators. Side actions still dispatch through the existing
`ActionRadials.Tag -> UseSlotCommand`; spell compatibility and
metamagic effects remain BG3-owned. Do not reintroduce a tab
substitution or a raw passive/SpellBook object as an execution slot.
The original keyboard `HotBarSlotStyle` must not replace the
controller grid's 104×104 item geometry.

Focus handoff and live casting are pending one combined runtime
sorcerer proof; static success does **not** close #125.

## Metamagic v0.0.100 runtime failure and exclusive owner recovery

The operator rejected v0.0.100 in-game: shoulder navigation to
Metamagic failed, tab selection wrapped/reset unexpectedly, and the
separate visible metamagic column displayed a constantly moving
duplicate selector. Investigation proved the source-level feedback
loop: `CAM_FixedSideBarList.LocalFocusChanged` was changing
`CAM_ProviderModeMarker.Tag`, while both lists and their selectors
remained simultaneously interactive. The earlier v0.0.99/v0.0.100
CI did not assert exclusive focus ownership.

All provider mode transitions must be driven by explicit LB/RB/tab
handlers **only**, never passive LocalFocusChanged. Keep the native
FixedSideBar visually present at all times its collection is nonempty,
but enable its list and focus selector only when its Metamagic provider
mode owns the input, excluding BG3-owned nested states. Conversely,
disable central HotBarList input while Metamagic owns the slot, except
when BG3's nested flags are active. Both focus/tooltip/tag paths must
be gated by their own active list. Avoid claiming cross-list spatial
navigation without actual engine proof. Do not alter the accepted
0.0.98 glyph paths or the native VMHotBarSlot execution command.

## Runtime findings 0.0.103: focus chrome and native metamagic command

The operator confirmed that 0.0.103 stopped the scrolling
selector-frame jump, and the logical Items grid focus had always
been correct. However the oversized native focus frame is clipped
by the two independently clipped selector/list regions. The
updated candidate must use one shared clipped action-body row
`CAM_ActionRowClip` spanning both columns and vertical
16px chrome clearance (850px row; inner 818px lists/regions).
Do not delete the row-level clip, revert to unbounded tab
overpainting, replace the native selector with item-local
highlight, or change `LSGrid` navigation, 120px scroll
offset-margin or command focus identity.

The operator also confirmed that Metamagic's first cell shows
the selector but has **no tooltip or actionable A command**
after LB/RB. The main list's programmatic `SelectionChanged`
70ms presentation wake is proven, while the side list formerly
had only `LocalFocusChanged`. Reuse that same main-list wake
contract for the native FixedSideBar and require a current
`LocalFocus.DataContext`, enabled sidebar and explicit
Metamagic mode. Set `ActionRadials.Tag`, side tooltip,
ShowTooltip and CreateFocusedTooltipData from **this native
VMHotBarSlot**, not from `SelectedItem` or handcrafted data.
Only LB/RB handlers change provider mode. Static checks cannot
substitute for runtime proof of actual controller focus and A.

## Controller command parity and source-derived selector geometry

Current captured `Public/Game/GUI/Library/DataTemplates.xaml` has
`SelectorTemplate` native `LSNineSliceImage Margin="-12"`. A
104px square slot in a 120px cell gives 8px side inset; the source
therefore proves why a flush-left FixedSideBar selector is clipped
even after the 0.0.104 shared 850px row clip. Shift the
**entire FixedSideBar region (list + sibling selector)** inward by
12px within `CAM_ActionRowClip`. Do not add separate selector
offsets, change cell geometry, remove the row clip, or alter
focus/scroll. Treat adaptive-grid column change at narrow viewport
widths as a potential runtime consequence.

The user cannot test every BG3 class/inventory/status/mod combination.
The normal Validate workflow must run
`tools/audit-native-ui-commands.py`, pin the two installed Patch 8
native UI command inventories, flag deleted real CAM command/provider
routes, and keep missing native UI transports / unresolved action
catalog categories explicit. The audit is **source-only**, not
proof of dynamic VMHotBarSlot reachability or execution. The full
command-risk inventory is documented in
`docs/research/native-ui-command-parity-2026-10-08.md`.
Do not close action coverage merely because all captured native
command *names* are classified; they are not action instances.

## Full gameplay capability parity is a blocking acceptance gate (#135)

User explicitly requires no lost native BG3 gameplay capability.
The game ships keyboard and controller action sources with differing
command/menu structures. Do **not** add all native command names
blindly: `SetCursorCommand` is mouse-resize UI, radial slot
editing is intentionally excluded, and blindly rebinding input
previously broke normal UILeft/held weapon switching.

The [25-capability matrix](docs/evidence/native-gameplay-capabilities.json)
lists required action classes including Jump/Shove/Throw/Hide,
weapons and light source, spell resources and variants, items,
charges, recasts, metamagic, targeting, cancellation and mod-added
actions. Any `blocked` or `unverified` item is still **unfinished**,
even when native XAML command audit and build CI pass.

The source audit `tools/audit-native-ui-commands.py` checks
provider/command names only. A separate strict runtime identity
comparator `tools/compare-runtime-gameplay.py` must reject missing
actual playable native action identities and lost native global
controller controls. Its synthetic CI self-test is **not**
runtime BG3 proof. It needs data from a future development-only,
read-only state probe. Do not put a Script Extender, native loader,
or manual mock action identity into the shipping package. Do not
call the mod functionally complete until this gate is satisfied.

## Optional developer-only gameplay inventory: source counts first

The original `dev/script-extender/Lua/Client/RadialProbe.lua`
has `MAX_COLLECTION_PREVIEW=10` and cannot prove complete
action coverage for any substantial character.
`dev/script-extender/Lua/Client/GameplayInventoryProbe.lua`
is a **separate**, bounded, read-only, dev-only Noesis snapshot
collector: native keyboard/controller hotbars and radial
catalogs, passives, inventory, resource/nested lists, CAM
visible collection and actual `LocalFocus`. It is registered
only in `dev/script-extender/Lua/BootstrapClient.lua`.

`tools/analyze-gameplay-inventory.py` checks source/list counts,
report completeness and action-ID evidence without claiming
a `VMCharacterAction` is an executable `VMHotBarSlot`.
It never emits a 'complete action parity' claim based on a
display name, icon, or one spell ID; spell resource/upcast
variants require a verified shared native identity.
Official [Norbyte/bg3se #593](https://github.com/Norbyte/bg3se/issues/593)
remains **open for Xbox Play Anywhere / Microsoft Store BG3**.
The unofficial SE compatibility build targeting Microsoft package
`1.8.907.0` is not evidence it supports our Xbox App `1.8.910.0`.
The optional Script Extender Noesis inventory **cannot be treated
as the primary Xbox App execution path** and must NOT be installed
with the shipping PAK, recommended as a prerequisite or imposed
on normal users. Issue #138 pursues BG3-owned ControllerHotBars
native slot fallback without SE; it is not yet implemented.
Do not claim playable parity from an optional dev-only probe.
Do not ask the operator to enumerate dozens of spells or
manually compare radial tiles. The next gate is a validated
native executable identity adapter and missing-function
remediation, not more static keyword checks.

## Current evidence boundary

Proven directly from the installed Xbox App build 1.8.910.0 plus current Patch 8 resources:

- controller state `ActionRadials` still uses the `HotBar` context;
- historical runtime builds proved CAM can replace the state/page, but those replacements left controller focus/input dead and are now rejected;
- the native page uses `ActionRadialWidgetTemplate_P8` from `PreloadedActionRadials_c.xaml`;
- official BG3 UI documentation confirms `Lib_Controller.xaml` is loaded in controller mode before mod StateMachines, making a controller resource-library override the preferred hook;
- the vanilla radial still exposes `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars`, but that persisted user layout is **not** CAM's automatic main catalog;
- executable CAM cells come from current native hotbar-slot collections such as `CurrentShownDeck.SlotList`, `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList`, and `SingleHotBar.SlotList`;
- nested variants/upcasts/containers use `SingleHotBar.SlotList`;
- `CurrentSingleHotbarFilter`, `IsShowingAContainerWithVariants` and `IsSelectingUpcastedSpell` are current;
- focus-driven scrolling is `LSScrollViewer.ScrollToElement <- FocusedElement`;
- the captured preloaded radial contains a current working 2D controller-grid pattern: `LSListBox -> focusable ListBoxItem -> LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- the root radial page does not intercept the four `UI*` directional events; its root left/right mappings are `UITabPrev` / `UITabNext`;
- normal controller A dispatch is page-level: `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- default B dispatch is `ClearSingleHotbarCommand`; when `SingleHotBar.SlotList.Count == 0` and items-to-throw is false, native triggers switch B to `CustomEvent("CloseWidget")`;
- swap-slot mode switches B to `UseSlotCommand(null)`;
- current `HotBarSlotStyle` still proves the keyboard-hotbar execution boundary because its command parameter is the surrounding `VMHotBarSlot`, but it is **not** CAM's controller-grid renderer: it is an 88px keyboard presentation and includes the `HotKey` overlay. `SlotIconStyle` is also rejected for CAM's action cells because its captured inner icon is 120×120. CAM uses the exact assignment-cell presentation seam instead: `VMHotBarSlot.Content.Icon` at 104×104 inside a 120×120 `LSGrid` cell; raw `VMCharacterAction` / `VMUpcast` / `VMItem` / `VMPassive` content objects still do not become valid `UseSlotCommand` parameters;
- `KeyboardHotBars` remains a separate keyboard/mouse collection and must never be substituted for `ControllerHotBars`.

Do not reconstruct the visible grid from `HotbarContainer` component memory. Component data is useful corroborating/storage evidence, but the presentation source is the captured native controller UI/view-model contract.

The public `ActionRadials.xaml` dump from 2023-09-06 is Patch 2 Hotfix 1 and is historical evidence only.

The fresh Xbox App 1.8.910.0 capture now confirms that current `SpellBook_c.xaml` still uses `CantripGroupPredicate`, `SpellLevelsGroupPredicate` and `AllActionsGroupPredicate`. That does **not** make them valid CAM execution filters: the captured predicates consume SpellBook `SelectedItem.ActionGroups`, not executable `VMHotBarSlot` objects. Do not route those raw ActionGroups into `UseSlotCommand` or recreate spell-level classification in CAM. Spell-slot/resource filtering must stay on the proven HotBar/resource model unless a future current-game contract proves a VMHotBarSlot-compatible level filter.

Runtime evidence additionally proves:

- `0.0.18` had the correct controller data/rendering path but dead navigation/B;
- `0.0.19` regressed the page by changing input transport;
- `0.0.20` restored rendering but controller focus/input was still dead;
- `0.0.23` failed at startup because a CAM-local secondary XAML URI was treated as a literal missing path;
- `0.0.24` proved the native page and controller-library override load, but a hand-written full `ActionRadialWidgetTemplate_P8` still had dead interaction;
- `0.0.25` attempted to override `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml` from the mod PAK and produced no visible runtime change, so that resource-path strategy is rejected;
- `0.0.27` proves the native slot-assignment grid focus model works inside ActionRadials: grids render and replace radial slot layouts;
- `0.0.28` centers the visible grids and removes the radial backdrop, but runtime proves the `LocalFocusSelector` visual stayed at the old upper-left coordinate origin because the list was centered independently from its selector;
- `0.0.29` fixes the focus-selector coordinate origin in-game. The remaining architectural mismatch is now explicit: the main grid still mirrors user-configured `ControllerHotBars[*].SlotList`, so it cannot satisfy CAM's original “all available actions automatically” goal. X/ContextMenu radial customization also behaves poorly against the grid and is no longer part of the product.
- `0.0.35` proves the native-source tabs render and switch, but rejects the "one shared outer `HotBarList.LocalFocus` for all tabs" composition: runtime showed the first tab could retain focus/tooltip ownership after a visual tab switch, A did not execute the selected action, the generic selector frame no longer matched the assignment cells, and centered footer hints collided with the action-resource display.
- `0.0.36` rejects the source-tab/assignment-candidate architecture itself: navigation breaks when reaching lower rows and cannot reliably return upward, A still does not execute actions or open containers, the native bottom resource bar does not preview the focused action cost, button hints are not in the original vertical stack, and custom LB/RB hint presentation produces extra symbols. The user also clarified that tabs are semantic filters like the keyboard hotbar, not source pages.

The current Patch 8 native XAML also proves a working controller grid inside radial slot assignment:

- outer `AssignList` uses `LocalFocusSelector`, `KeyboardNavigation.DirectionalNavigation="Contained"`, `ActionNextEvent="UIDown"` and `ActionPrevEvent="UIUp"`;
- child lists use `LSGrid(ActionUp/Down/Left/Right = UIUp/UIDown/UILeft/UIRight)`;
- `AvailableSlotContainer` uses focusable `ListBoxItem` cells;
- A in assignment mode consumes `AssignList.LocalFocus.DataContext`.

Current mandatory architecture:

- the **shipping PAK is self-contained**. Normal installation must not read, extract, patch, or rebuild from BG3 game PAKs;
- do not override `Public/Game/GUI/...` from the CAM PAK;
- runtime UI resources required by CAM live inside `BG3ControllerActionMenu/Mods/BG3ControllerActionMenu` and are built into the release PAK by CI;
- raw captured Larian XAML is development evidence only and must not be committed as runtime source. Project-owned XAML may be authored from the proven contract and shipped normally;
- the end-user installer only resolves/downloads the prebuilt release PAK, locates the Xbox mod/profile target, copies the PAK, and updates `modsettings.lsx`;
- normal installation must never invoke LSLib, `native-overlay.ps1`, `Game.pak` extraction, or local PAK creation;
- if new native evidence is needed, use the separate portable `Capture-BG3ControllerArtifacts.vbs` developer tool. It is read-only against the game and writes its tools/logs/captured artifacts beside the launcher;
- main gameplay candidates passed to `UseSlotCommand` must be native hotbar slot VMs (`VMHotBarSlot`), not raw radial-assignment catalog objects;
- `PlayerCharacterProperties.SpellsAndActions`, `Inventory.Slots`, and raw/passive assignment collections may be research/presentation evidence but must not be used as the main `ActionRadials.Tag -> UseSlotCommand` candidate path;
- **resource-first UX remains the preferred presentation, but completeness is mandatory.** `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList` is the primary provider for Action/Bonus/spell-slot/class-resource variants; it is not assumed to be a complete catalog. CAM must satisfy the parity contract in `docs/action-coverage.md`: native keyboard HotBar plus radial-assignment gameplay actions, excluding radial-editing-only operations, must all have a reachable CAM route before the mod is called a complete HotBar replacement;
- the top-level LB/RB row is one cost/source sequence, not a return to the rejected raw Actions/Items/Passives source-tab design. Proven special providers such as Cantrips and ItemHotBar may join that row when they preserve native executable `VMHotBarSlot` semantics. A final `All` fallback may render the native `KeyboardHotBars` VMHotBar collection only as grouping; it must never dispatch VMHotBar itself. Non-ActionResource entries such as FREE, SCROLLS, item charges, Cantrips, Items or Metamagic may be added only through a current BG3-owned filter/provider that materializes executable `VMHotBarSlot` values. Raw `SpellsAndActions`, `Inventory.Slots`, passive objects, names, icons, class names and resource-name heuristics remain forbidden as dispatch/classification paths;
- resource tabs are dynamic and generic: hide null/MaxValue=0 previews, preserve BG3 order, render SpellSlot/WarlockSpellSlot with the native `Image + RomanNumeralLevelImage` presentation over `ActionResource`, and use native resource names for generic/mod resources. Individual tabs have no arbitrary maximum width; overflow must remain controller-reachable rather than silently clipping categories;
- current resource overflow uses a bounded **resource-only** horizontal viewport. Provider mode lives on `CAM_ProviderModeMarker.Tag`; `CAM_ResourceTabs.Tag` is reserved for the selected concrete resource `ListBoxItem` UIElement. The resource `LSScrollViewer` binds `ScrollToElement` to that UIElement and must commit the captured native `TargetPositionChanged -> HorizontalScrollOffset = TargetPosition` lifecycle. Special provider tabs stay outside this scroll owner. Do not replace this with `AutoScrollBehavior`, SelectedIndex/SelectedItem scroll targets, wrapping, or manual numeric offsets;
- static keyboard-HotBar source coverage is closed only through current native providers: resource filters, Cantrips, ItemHotBar, FixedSideBar, PassivesHotBar, and a final grouped `KeyboardHotBars[*].SlotList` fallback. The fallback may group `VMHotBar` values for presentation, but execution must still be child `VMHotBarSlot` values. Radial-assignment parity remains runtime-unverified for free/no-resource, scroll/charge, temporary, recast and mod-added radial-only candidates. Do not remove a gap from the coverage contract until a current native executable provider or one combined runtime parity proof establishes it;
- release XAML must not depend on install-time discovery of HotBar command parameters or binding names. Any required current values must be captured during development and represented explicitly in project-owned runtime resources/tests;
- LB/RB owns top-level cost/source selection; D-pad/left-stick focus stays in the action grid. The main executable grid uses an adaptive `LSGrid(UIUp/UIDown/UILeft/UIRight)` whose column count is derived from the current scroll-content width. `HotBarList.LocalFocus.DataContext` is the logical focus authority; visible focus, tooltip, `ActionRadials.Tag`, A dispatch and scrolling must agree on that same slot;
- action-grid scrolling reuses the captured Patch 8 controller seam: `ActionRadials.FocusedElement -> LSScrollViewer.ScrollToElement`. Do not rely on an ordinary ScrollViewer to infer gamepad focus or add a separate CAM scroll-position state machine;
- do not hard-code a short/fixed action-grid height that truncates the navigation space;
- action cells are native `VMHotBarSlot` objects. Presentation must use the captured assignment geometry directly: a 104×104 `Content.Icon` surface in a 120×120 `LSGrid` cell, with the focused `ListBoxItem` itself kept at 104×104. Do not use keyboard `HotBarSlotStyle` (keyboard `HotKey` overlay) or radial `SlotIconStyle` (captured 120×120 inner icon) as CAM's action-cell renderer. On every `LocalFocusChanged`, synchronize `HotBarList.SelectedItem` to `HotBarList.LocalFocus.DataContext`; item `IsSelected` owns the visible focus chrome, so tooltip, A dispatch and the visible frame all identify the same `VMHotBarSlot`. The container may retain `Tag="{Binding .}"` for presentation compatibility;
- main slot focus must reproduce the captured current radial `LocalFocusChanged` lifecycle: clear stale focus state immediately, then after the native 70 ms delay copy `LocalFocus.DataContext` to `ActionRadials.Tag` and invoke `CreateFocusedTooltipDataCommand` / `HighlightResourcesCommand` with that same slot. The ordinary native `LSTooltip` over `VMHotBarSlot.Content` is the **only** details surface; do not add a CAM Live Details panel or author description/cost text;
- A remains the existing page-level `UIAccept -> UseSlotCommand(ActionRadials.Tag)` path;
- `SingleHotBar.SlotList` is both the top-level resource-filter result and BG3's nested/upcast/variant/container collection. A populated resource filter must **not** by itself make B a nested-back action: top-level B closes CAM when no `IsShowingAContainerWithVariants`, `IsSelectingUpcastedSpell`, or `IsShowingItemsToThrow` state is active; real nested states retain BG3 cancellation;
- preserve the captured current `ButtonHintsContainer` layout/behavior contract. Do not restyle it horizontally and do not add duplicate LB/RB hint presenters;
- X/`ShowContextMenu` and radial Assign/Swap/Clear/Add/Remove customization must remain unreachable from CAM;
- historical SpellBook predicates and CAM-owned spell/resource classifiers remain forbidden without current installed-game proof. In particular, do not fix ACTION/BONUS over-inclusion with spell-name/class tables; only a proven current native executable-slot property/predicate may refine primary-resource membership;
- there is no install-time XAML generation. Semantic/contract assertions and package construction are CI/development responsibilities.

Do not revive the hidden-radial visual-mirror design from 0.0.25.

The end-user installer is not a verifier or build pipeline. `0.0.29` and `0.0.37` proved that install-time derivation/contract logic creates avoidable failures. Detailed XAML semantics, presentation literals, focus/A/B contracts, package round-trip checks and release-integrity assertions belong in CI/release workflows only. The runtime installer installs an already-built self-contained PAK.

The next in-game test is justified only after CI proves the old Common/Class/Cantrips/Items/Passives runtime is absent, the sole tab source is `ActionResourcesCostPreview`, selection drives `FilterActionResourceCommand`, the grid is `SingleHotBar.SlotList`, ordinary native tooltip/A are retained, and top-level B is separated from true nested BG3 state. One milestone run should verify several resource tabs (including a spell-slot level), Action/Bonus contents, one upcastable spell, one generic/class resource if available, tooltip, A, top-level B, and one real nested variant/upcast back path.

## Development VBS contract

`Install-BG3ControllerActionMenu.vbs` is a temporary development delivery bridge, not the final public distribution mechanism.

Until CAM is available through the intended official delivery path:

- the tester must be able to keep one extracted folder and double-click the **same VBS** for every install/update;
- normal development iteration must never require manually downloading or replacing that VBS;
- the VBS must stay tiny and stable: stable bootstrap + portable status/log paths only;
- version-specific assets, migration logic and installer behavior belong in bootstrap-downloaded helper scripts, not in VBS;
- the VBS/bootstrap compatibility contract is backward-compatible. Requiring an already-installed development launcher to be refreshed manually is an architecture regression;
- helper scripts may be added for read-only game inspection, resource extraction or preparing an archive to return to the developer, but those are development evidence tools and must not become runtime dependencies of the final mod;
- installer/capture-owned artifacts belong beside the launcher. Do not scatter development state through machine-global directories.

The VBS workflow is expected to be retired once the official delivery path is in place. Do not optimize the permanent mod architecture around the temporary VBS.

See [docs/development-vbs.md](docs/development-vbs.md).

## Installer boundary

The stable operator bootstrap contract must remain tiny: newest published release -> download `dev-entry.ps1` -> execute the release-controlled task. The VBS must not understand version-specific assets. Normal installation remains a release-controlled `dev-entry.ps1 -> install-latest.ps1` task, while an explicit development milestone may temporarily select a read-only capture task.

The VBS installer is portable: caches, downloaded release assets, logs, status and diagnostics belong under a directory beside the VBS launcher. The only writes outside that portable directory are the intentional BG3 mod PAK/profile changes and their safety backups.

Do not add LSLib, game-PAK reads, XAML derivation, SHA/digest policy gates, semantic assertions, expected UI literals, or package round-trip verification to the normal install path. Those belong in CI/development capture before publication.

Development capture must distinguish **technical evidence failure** from **research absence**. Failure to locate/extract required game inputs may fail the task; absence or movement of an investigated command/binding such as `FilterCantripsCommand` must be recorded in the derived report and must not abort an otherwise valid capture. Search research seams across the whole captured XAML set before marking them missing.

## Release readiness contract

A CI artifact is not a release. The reusable installer consumes **published GitHub Releases**, not pull-request or workflow artifacts.

Before describing a version as released, ready to install, or available through the one-click installer, all of these must be proven:

- the implementation PR is merged to `main`;
- `VERSION` on `main` is the intended version;
- the **Release** workflow for that merge completed successfully;
- the exact `v<VERSION>` GitHub Release is published and non-draft;
- every installer-required release asset exists;
- that tag is the newest published release under the same ordering used by `install-latest.ps1`;
- the canonical `install-latest.ps1 -ResolveOnly` path resolves that exact version against live GitHub metadata.

Never treat a green **Build package** workflow or an Actions artifact as proof that the one-click installer can see the version.

If the installer resolves an older version, verify publication first. Do not change installer selection logic to compensate for a release that was never published.

The complete release procedure and recovery checklist are in [docs/release-process.md](docs/release-process.md).

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether the shipping `.pak` remains Script-Extender-free;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.


## Rejected runtime experiment — 0.0.49

Version `0.0.49-resource-runtime-fix` is rejected by in-game proof.

Observed regression:
- resource tabs opened/switched unpredictably;
- input/navigation became delayed;
- the resource-first surface felt globally broken compared with 0.0.48.

Therefore do **not** reintroduce the 0.0.49 combination of:
- per-cell `Content.SpellUpcast` / `VMUpcast` overlay controls with additional `UIAccept` bindings;
- automatic `SingleHotBar.SlotList.Count == 0 -> FilterActionResourceCommand` recovery triggers;
- focusable resource-tab items added only to force BringIntoView behavior;
- simultaneous focus-tree, scrolling, selector, upcast-dispatch and shortcut rewrites in one runtime milestone.

The 0.0.48 in-game observations remain valid evidence of defects, but fixes must be isolated and proven one architectural seam at a time. Stability of resource-tab switching is the first invariant.


## Isolated correction after 0.0.50

The first post-rollback runtime correction is intentionally limited to the preserved native weapon-set shortcut.

- runtime proof rejects putting `BoundEvent="UISelectionLeft"` directly on the visual `ToggleWeaponSet` hold button: it executes once but does not reliably re-arm for the next hold.
- preserve the captured vanilla visual button shape: `ToggleWeaponSet` uses `ControllerHoldButtonStyle`, displays the `UISelectionLeft` input hint, and owns `SwitchWeaponSetCommand`, but has **no BoundEvent**.
- input transport is a separate invisible `LSInputBinding`: `WeaponSetShortcutBinding`, `BoundEvent="UISelectionLeft"`, `Command="{Binding SwitchWeaponSetCommand}"`, `EatInput="False"`.
- The action grid keeps `ActionLeftEvent="UILeft"`; do not remap ordinary grid-left navigation.
- The action grid keeps `ActionLeftEvent="UILeft"`; do not remap ordinary grid-left navigation.
- This correction must not change resource-tab selection, filtering, upcast behavior, focus hierarchy, scrolling, selector geometry, or B handling.

Do not combine another runtime fix into the same release.


Runtime proof for 0.0.51: hold D-pad Left switched weapon set once, but the same hold shortcut did not fire a second time. Treat direct BoundEvent on the visual ControllerHoldButtonStyle control as rejected for this command.


## Isolated correction after 0.0.52 — action-grid scrolling

The next core-functionality correction is deliberately limited to viewport scrolling.

Fresh Patch 8 controller UI evidence uses `ls:ScrollViewerHelper.VerticalScrollOffsetMargin` on existing vertical ScrollViewer surfaces to keep controller-focused descendants inside the viewport. CAM therefore adds only:

`ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"`

to the existing `HotBarList` ScrollViewer.

This correction must not change:
- the outer/nested focus hierarchy;
- resource tabs or LB/RB;
- `SingleHotBar` filtering;
- selector geometry;
- tooltip/A/B/upcast behavior;
- action-grid dimensions.

Do not combine focus-tree cleanup with this scrolling proof.


## Runtime proof — 0.0.52 weapon-set shortcut

0.0.52 is rejected for this shortcut:
- using an `LSInputBinding` on raw `UISelectionLeft` made the first ordinary left press switch weapon set immediately;
- subsequent holds fell through to normal grid navigation.

Patch 8 HotBar proves a separate semantic event: `WeaponSetSwitchStyle` binds `BoundEvent="ToggleWeaponSet"`. Therefore the input transport must use `ToggleWeaponSet`, while `UISelectionLeft` remains only the controller hint/physical hold gesture shown by the vanilla `ToggleWeaponSet` visual.


## Architecture simplification — single action list

This decision supersedes the current outer-list + filtered-child-list + separate SingleBar composition.

The resource-first runtime must use exactly one controller action list:
- `HotBarList.ItemsSource = SingleHotBar.SlotList`;
- `HotBarList` directly owns `CAM_ActionGridPanel`, `CAM_ActionGridSlotContainer`, `CAM_ActionGridSlotTemplate`, item-local focus chrome, scrolling, tooltip, and the 70 ms native focus handoff;
- there is no `CAM_FilteredSlotList`, `CAM_FilteredSlotHolder`, `SingleBar`, `singleBarHolder`, `CAM_SingleSelector`, or `CAM_SingleActionTooltip`;
- BG3 nested container/upcast/throw state continues to replace `SingleHotBar.SlotList`; the same `HotBarList` renders that collection rather than swapping to a second list;
- when nested flags become true, any native focus-restoration trigger targets `HotBarList` itself;
- resource tabs still invoke `FilterActionResourceCommand(CAM_ResourceTabs.SelectedItem)`;
- A remains page-level `UseSlotCommand(ActionRadials.Tag)`;
- B remains native `ClearSingleHotbarCommand` for nested state and `CustomEvent("CloseWidget")` at top level.

This refactor is specifically intended to remove duplicate focus owners, invisible wrapper transitions, selector coordinate divergence, and scroll ownership ambiguity. Do not add a second executable action list back into the template.


## Weapon-set shortcut proof boundary

All CAM-owned weapon-set input transports tried so far are rejected by in-game proof:

- visual `BoundEvent="UISelectionLeft"`: fires once and does not reliably re-arm;
- `LSInputBinding UISelectionLeft` without a hold threshold: short press fires immediately;
- `LSInputBinding ToggleWeaponSet`: also fires on ordinary short press in ActionRadials;
- `LSInputBinding UISelectionLeft + HoldTimeShortcuts`: still does not provide a repeatable ActionRadials-safe transport.

Therefore the shortcut stays absent from shipping CAM. Grid-left remains `UILeft`, and no broken shortcut may consume that input.

The portable developer capture must search **all captured XAML** for the exact symbols `SwitchWeaponSetCommand`, `ToggleWeaponSet`, `UISelectionLeft`, `ControllerHoldButtonStyle`, `WeaponSetSwitchStyle`, `LSInputBinding`, and `HoldTimeShortcuts`. For every matching tag it records source file, element/name, BoundEvent/EventName, Command/CommandParameter, Style/Content, HoldTime/TapTime, EatInput, Setter Property/Value, and the raw tag. Missing symbols are evidence and must not fail capture.

Do not restore weapon switching until that evidence proves a **different, repeatable ActionRadials-compatible native transport**.


## Source-backed controller weapon-set button restoration (2026-10-08)

**Supersedes only the earlier conclusion that the weapon shortcut must
remain absent from CAM.** The earlier *input failures* are historical
runtime facts and must not be discarded.

The installed 1.8.910.0 controller
`PreloadedActionRadials_c.xaml:1925–1928` has an actual
`ToggleWeaponSet` **LSButton**, using
`ControllerHoldButtonStyle`, game-owned
`SwitchWeaponSetCommand`, a **visual** `UISelectionLeft` hint, and
`EatInput=False`. Crucially the native button declares **no
`BoundEvent`**. `HasRangedAttack=False` collapses it in the native
template. This is a functional controller control, not a radial-editing
UI or a manually configured ability.

CAM may restore this **exact** existing native button/command and
visibility contract. Do not introduce *any* separate input transport:
previous explicit BoundEvent and LSInputBinding variants consumed
ordinary D-pad left or did not re-arm. Keep the action grid
`ActionLeftEvent=UILeft` unchanged.

This restoration is source-backed, but static CI **cannot prove**
repeatable hold handling by the game's runtime. The original
no-BoundEvent LSButton variant still needs one combined milestone
gameplay test. Treat command presence as source wiring, not finished
runtime parity; #135 stays open until that proof.

See `docs/action-coverage.md` and
`docs/evidence/patch8-1.8.910.0-runtime-contract.json`.

## Historical post-single-list viewport correction (superseded by selectorless grid)

Runtime proof after the single-list refactor shows four presentation defects without evidence of gameplay-state regression:
- resource-tab changes reset navigation to the first action, but the selector can remain painted at the previous tab's old coordinates until the next directional input;
- lower action rows are focusable but remain clipped;
- the selector is offset from the action cell;
- the resource row is too narrow and does not follow off-screen LB/RB selection.

These were presentation/navigation ownership issues, not reasons to restore duplicate executable lists. The selector/800×850 correction below was an intermediate 0.0.56–0.0.57 step and is superseded by the selectorless adaptive architecture in the next section.

Required corrections:
- the direct `HotBarList` and `CAM_MainSelector` must share the exact same 800x850 coordinate viewport;
- `CAM_ActionGridPanel` must not keep the old assignment-only `DisableScrolling="True"` now that it is the direct items panel of the scroll-owning list;
- the direct list ScrollViewer must enable content scrolling;
- changing resource selection hides stale selector chrome until the new `HotBarList.LocalFocus` handoff completes;
- the resource list uses the captured BG3 `AutoScrollBehavior(ScrollIntoView=SelectedIndex, BringSelectionIntoView=True)`;
- the resource viewport may be wider than the action grid, but must not alter action focus geometry.

Do not change FilterActionResourceCommand, UseSlotCommand, ClearSingleHotbarCommand, nested-state flags, upcast semantics, or weapon-set input as part of this correction.


## Selectorless adaptive controller grid

Runtime proof from 0.0.55-0.0.57 rejects the remaining detached selector/viewport composition:
- the logical focus is already on the first item after resource changes while detached selector chrome remains at old coordinates;
- direct `LSGrid` navigation reaches clipped rows but the current ListBox content-scrolling path does not move the viewport;
- fixed `Columns=5` / `Width=632` is not adaptive;
- text-only resource tabs expose blank labels for native resources whose controller presentation is icon/level driven.

Current installed Patch 8 capture provides a simpler controller presentation pattern:
- `SpellBook_c.xaml` computes `LSGrid.Columns` from the actual scroll-content width using `DivideMultiConverter`;
- that grid uses `UseWidgetNavigation=True`, `AlwaysSelectFirst=True`, `ls:MoveFocus.InternalFocusable=True`, and focusable descendants;
- focused cells use `ls:MoveFocus.IsFocused` / native focus visual behavior instead of an independently positioned selector control;
- SpellBook wraps the grid in ordinary pixel scrolling rather than forcing `CanContentScroll=True`;
- current `HotBar.xaml` confirms `ActionResourcesCostPreview` is itself a native clickable `FilterActionResourceCommand` source and hides only `MaxValue=0` items. Therefore CAM must not invent a second semantic resource classifier merely to hide entries.
- no current native per-preview executable-count/has-actions property is proven. Do not hide an apparently empty tab by reacting to `SingleHotBar.SlotList.Count == 0`, auto-cycling selection, or re-invoking filters from filter results; 0.0.49 already proved that re-entrant filter recovery makes tab interaction unstable.

Required CAM presentation after 0.0.58 runtime proof:
- 0.0.58 proves that transplanting the SpellBook selectorless focus tree wholesale into ActionRadials is invalid: grid navigation stops and page-level A cannot execute because `HotBarList.LocalFocus` no longer advances;
- keep the adaptive SpellBook geometry and item-local focus chrome, but restore the captured ActionRadials/assignment `LSListBox.LocalFocusSelector` seam as an **invisible logical focus anchor**. It must remain laid out (`Visibility=Visible`) but render with `Opacity=0`; it exists only so `HotBarList.LocalFocus.DataContext` continues to drive navigation, tooltip/highlight and `ActionRadials.Tag`;
- do not restore a visible detached selector or its old compensated selector template;
- `CAM_ActionGridPanel.Columns` is calculated from actual `ScrollContentPresenter.ActualWidth / 120`, never hard-coded;
- use pixel scrolling (`CanContentScroll=False`) with the existing vertical offset helper;
- resource tabs stay in a bounded horizontal viewport with SelectedIndex auto-scroll; individual tab width may grow enough to show native resource names rather than truncating common names;
- generic resource fallback must also handle an empty displayed resource name, not only a null object. Spell-slot tabs keep native level presentation;
- the experimental `Toggle weapon set` shortcut is removed from CAM until a repeatable ActionRadials-specific native transport is proven. A broken shortcut must not consume controller input needed by the primary grid.

No additional runtime dependency is allowed for these fixes. ImpUI and other mods are research evidence only, not CAM dependencies.


## Runtime correction — 0.0.59 -> 0.0.60

0.0.59 proves the hybrid ActionRadials focus architecture is functionally correct: controller navigation changes the native tooltip target and A executes the logically focused action. The remaining focus defect is presentation-only: `ls:MoveFocus.IsFocused` remains true on the first cell and therefore cannot be used as CAM's visible focus source in this composition.

Required correction:
- keep `HotBarList.LocalFocus.DataContext`, `CAM_LogicalFocusAnchor`, tooltip/highlight lifecycle and A dispatch unchanged;
- on `HotBarList.LocalFocusChanged`, copy `LocalFocus.DataContext` into `HotBarList.SelectedItem`;
- render `CAM_CellFocus` from `ListBoxItem.IsSelected`, not `ls:MoveFocus.IsFocused`;
- remove per-tab `MaxWidth` and text trimming limits; the outer resource viewport remains bounded and auto-scrolls the selected tab;
- spell-slot tabs must use the current native HotBar level renderer: `Image Style="{StaticResource RomanNumeralLevelImage}" DataContext="{Binding ActionResource}"`. Do not emulate the level with a TextBlock style.


## Runtime correction — 0.0.60 -> 0.0.61

0.0.60 proves that `HotBarList.SelectedItem` can follow logical navigation and provide moving selection highlight, but two presentation/lifecycle defects remain:
- the inherited/native `FocusVisualStyle` still renders an independent focus rectangle on the physically focused first cell;
- after a resource filter change, the new list can have an implied first logical focus before `SelectedItem` is re-established, leaving no visible CAM selection until navigation occurs.

Required correction:
- action items keep controller focusability but set `FocusVisualStyle={x:Null}`; CAM's `IsSelected` chrome is the sole visible action focus;
- after resource `SelectionChanged` and `FilterActionResourceCommand`, re-establish `HotBarList.SelectedIndex=0` after the list has settled, then defer focus back to `HotBarList`; do not duplicate gameplay dispatch or resource filtering;
- resource-tab shoulder cycling uses `SelectNextListBoxItem ForceSelect=True ForceMode=Cycle` so a wrap from the last tab to the first produces a full selection transition for the existing `AutoScrollBehavior`;
- keep the bounded tab viewport and native `AutoScrollBehavior`; do not add a second custom scrolling model.


## Runtime correction — 0.0.61 -> 0.0.62

0.0.61 runtime proof rejects the SelectedIndex/ForceSelect correction:
- `ForceSelect=True` makes shoulder cycling enter native resource-preview items that CAM intentionally hides when `ActionResource.MaxValue == 0`, producing invisible empty tabs;
- forcing `HotBarList.SelectedIndex=0` only changes presentation. The actual `HotBarList.LocalFocus` remains at the previous tab's coordinates, so navigation and A can still target the old slot while the first cell is highlighted;
- one-item tabs expose the same divergence because no directional move occurs to generate a new `LocalFocusChanged`;
- the first resource tab still fails to scroll back into view when the strip has moved right.

The corrected contract is:
- resource changes clear `ActionRadials.Tag`, `HotBarList.SelectedItem`, and, critically, `HotBarList.LocalFocus` before invoking `FilterActionResourceCommand`. Clearing `LocalFocus` is a native ActionRadials pattern and is the only reset that owns controller navigation/dispatch state;
- immediately after filtering, use `SetMoveFocusAction(..., DeferFocusAction=True)` on the same `HotBarList`; do **not** synthesize `SelectedIndex=0` or add a second resource-switch timer. The ensuing native `LocalFocusChanged` must repopulate selection, tooltip, resource highlighting and `ActionRadials.Tag` from one slot;
- remove `ForceSelect=True` from resource shoulder cycling so collapsed MaxValue=0 previews are not forcibly selectable;
- keep `ForceMode=Cycle` only;
- bind resource-strip `AutoScrollBehavior.ScrollIntoView` to `CAM_ResourceTabs.SelectedItem`, not numeric `SelectedIndex`, so the first item is represented by a real object rather than index 0;
- visible action focus remains CAM-owned and derived from `IsSelected`, but it must include both a translucent selection fill and a fully opaque border frame so focus remains visible on cells whose icon/content is visually empty.


## Runtime correction — 0.0.62 -> 0.0.63

0.0.62 runtime proof narrows the remaining defects:
- hidden resource previews are gone and real-slot focus chrome now moves correctly;
- clearing `HotBarList.LocalFocus` is not sufficient to reset the controller focus graph: after a resource change, re-entering `HotBarList` still resumes the previous tab's geometric position;
- CAM's adaptive `LSGrid` still exposes navigation coordinates beyond real executable cells;
- the selected resource tab can remain outside the left edge of the bounded viewport while cycling left.

The correction must stay inside native focus/navigation primitives:
- after `FilterActionResourceCommand`, call `SetMoveFocusAction TargetName="ActionRadials" InvalidateFocus="True"` before returning focus to `HotBarList`. Native ActionRadials uses `InvalidateFocus=True` when focusable radial contents are created/removed;
- keep the existing ActionRadials `LocalFocusSelector` contract, but set only `AlwaysSelectFirst=True` on `CAM_ActionGridPanel` so a freshly invalidated grid entry starts from the first real cell. Do not restore the rejected SpellBook combination of `UseWidgetNavigation=True` or `ls:MoveFocus.InternalFocusable=True`;
- set `ExtendedRows=False` on the action `LSGrid`. CAM has no semantic empty actions, so controller navigation must not continue into generated empty coordinates;
- do not add `EmptyCellTemplate` to CAM merely to visualize non-actions;
- keep resource-strip `AutoScrollBehavior` bound to `SelectedItem` and add native `ScrollTo="Center"` so a selected edge tab is fully visible rather than merely intersecting the viewport.


## Runtime correction — 0.0.63 -> 0.0.64

0.0.63 produced no observable change from 0.0.62. Treat its three focus/grid assumptions as rejected for this composition:
- `SetMoveFocusAction InvalidateFocus=True` on the widget does not reset `HotBarList` to the first slot after a resource filter;
- `LSGrid.AlwaysSelectFirst=True` does not establish the required `LSListBox.LocalFocus`;
- `ExtendedRows=False` does not remove navigation through the unoccupied coordinates of a partially filled adaptive row.

The stronger runtime evidence is older and already proven in-game:
- 0.0.29 used the native `SelectorTemplate` as the `LocalFocusSelector`, with the selector and list in the same coordinate root;
- 0.0.29 retained `EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"` on the controller grid;
- 0.0.61 proved that, after the filter settles, `SelectedIndex=0` reliably identifies/realizes the new first action cell, but selection alone does not move controller focus.

0.0.64 therefore separates *entry selection* from *live focus*:
- resource change clears the action tag, sets `HotBarList.SelectedIndex=-1`, and invokes `FilterActionResourceCommand` exactly once;
- after the existing 70 ms settle window, CAM arms a one-shot reset token and sets `SelectedIndex=0`;
- the selected `ListBoxItem` template consumes that token and calls `SetMoveFocusAction` on its own concrete templated parent, then clears the token;
- normal D-pad navigation does not mirror `LocalFocus` into `SelectedItem`; `LocalFocus` remains the sole live controller-navigation/dispatch state;
- visible focus is again the native `SelectorTemplate` bound through `LocalFocusSelector`, not item-local `IsSelected` chrome;
- restore the 0.0.29-proven native `EmptyCellTemplate` so focus geometry has a native presentation on unoccupied LSGrid coordinates;
- resource-strip AutoScroll returns to the BG3-proven `SelectedIndex` input and combines it with native `ScrollTo="Center"`; `SelectedItem` is a VM and is not a valid element/index scroll target.

Do not restore `ForceSelect=True`, install-time native derivation, or duplicate executable lists.


## Runtime correction — 0.0.64 -> 0.0.65

0.0.64 is the first build in this sequence that materially improves resource-switch focus/navigation. Keep its concrete-item handoff and native `SelectorTemplate` ownership.

Remaining runtime defects are now narrower:
- after a resource switch, the first action is focused, but the ordinary action tooltip does not appear until the user moves with D-pad;
- while cycling resource tabs left, the selected edge tab can still remain outside the visible strip.

0.0.65 must not change focus ownership again. Instead:
- the existing 70 ms resource-entry timer may use `HotBarList.SelectedItem` as the one-shot first-slot source to complete the same native tooltip/tag/resource-highlight state that D-pad navigation establishes from `LocalFocus.DataContext`;
- this one-shot synchronization is allowed only during resource entry. Normal navigation remains `LocalFocusChanged`-owned;
- resource-tab scrolling must use the native selection-driven `AutoScrollBehavior BringSelectionIntoView=True` mode without an explicit `ScrollIntoView` target. Current runtime evidence rejects both explicit `SelectedItem` and `SelectedIndex` targets for this horizontal strip;
- do not introduce manual horizontal offsets, tab virtualization, `ForceSelect=True`, or another tab/focus state machine.


## Runtime correction — 0.0.65 -> 0.0.66

0.0.65 proves that `HotBarList.SelectedItem` is not the live controller-focus authority. After a resource switch, its index-0 entry can diverge from the visible/native `HotBarList.LocalFocus`, causing tooltip/A state to point at a different slot from the selector.

0.0.66 must keep `LocalFocus.DataContext` as the sole live focus/tooltip/A authority:
- on resource selection change, clear stale `HotBarList.LocalFocus` before refiltering;
- retain the 0.0.64 concrete-item handoff after the 70 ms settle window so the newly selected concrete item establishes a fresh LocalFocus event;
- remove every 0.0.65 resource-entry tooltip/Tag/highlight write sourced from `HotBarList.SelectedItem`;
- tooltip, `ActionRadials.Tag`, resource highlighting and A execution return exclusively to the existing `LocalFocusChanged -> LocalFocus.DataContext` lifecycle.

Resource-tab scrolling must use the current Patch 8-native element scroll seam:
- selected resource `ListBoxItem` writes its concrete templated-parent UIElement to `CAM_ResourceTabs.Tag`;
- the resource list template uses `ls:LSScrollViewer`;
- `ls:LSScrollViewer.ScrollToElement` binds to `CAM_ResourceTabs.Tag`;
- do not use `AutoScrollBehavior`, explicit SelectedIndex/SelectedItem scroll targets, or manual horizontal offsets for this strip.

Because CAM reuses `SingleHotBar.SlotList` both for resource-filter results and real nested/upcast/container state, native `ClearSingleHotbarCommand` can legitimately leave the CAM top-level resource list empty after B. CAM must therefore restore the selected resource filter only after a **real nested state** was entered and then all native nested flags returned to false. Top-level B must still close the widget and must not trigger resource restoration.


## Runtime correction — 0.0.66 -> 0.0.67

0.0.66 confirms that the nested-return restoration lifecycle is correct and must remain unchanged.

Two remaining defects are presentation/scroll seams:
- after resource switching or nested return, controller focus is valid but the tooltip may remain absent until the next D-pad move;
- selected resource tabs still do not scroll into the visible strip.

0.0.67 rules:
- keep `LocalFocus.DataContext` as the sole action identity for tooltip, highlight, `ActionRadials.Tag`, and A dispatch;
- do not reintroduce any `SelectedItem`-derived action presentation state;
- presentation synchronization must observe `HotBarList.LocalFocus.DataContext` with a property-change trigger, not rely solely on the `LocalFocusChanged` event. A filter/nested-return can reuse a focus container while changing the VM beneath it;
- `LocalFocusChanged` may remain only for navigation sound;
- remove the delayed `LocalFocusChanged` presentation timer once the property-change trigger owns presentation state.

For resource-strip scrolling:
- keep the selected resource `ListBoxItem` publishing its concrete container UIElement into `CAM_ResourceTabs.Tag`;
- inside the resource `ControlTemplate`, bind `LSScrollViewer.ScrollToElement` to `Tag` through `RelativeSource TemplatedParent`;
- do not use `ElementName=CAM_ResourceTabs` from inside that template because the template has its own namescope;
- do not return to `AutoScrollBehavior`, integer/VM scroll targets, or manual offsets.


## Runtime correction — 0.0.67 -> 0.0.68

0.0.67 produced no observable runtime change. Treat both attempted seams as rejected for CAM:
- `PropertyChangedTrigger(LocalFocus.DataContext)` is not a reliable wake-up signal for programmatic ActionRadials re-entry;
- resource-strip `LSScrollViewer.ScrollToElement` does not move this non-focused shoulder-selection strip, regardless of cross-template binding form.

Keep the proven 0.0.66 nested-return restoration unchanged.

### Programmatic action-entry synchronization

`HotBarList.LocalFocus.DataContext` remains the only action identity used for tooltip, resource highlighting and A dispatch. The correction changes only the **wake-up signal**:

- ordinary D-pad movement returns to the runtime-proven `LocalFocusChanged` lifecycle;
- programmatic focus entry/re-entry observes the widget's `FocusedElement`, matching BG3 controller UI patterns that refresh tooltip presentation when widget focus changes;
- the `FocusedElement` trigger must still read action state from `HotBarList.LocalFocus.DataContext`, never from `SelectedItem` or `FocusedElement.DataContext`;
- no extra delay is introduced for this synchronization.

### Resource-tab layout

Stop treating resource tabs as a scrollable carousel. Multiple runtime releases have rejected every available declarative selection-follow scroll seam.

BG3 already presents action-resource collections with `ls:AlignableWrapPanel`. CAM must use the same layout family:
- `CAM_ResourceTabsPanel` becomes an `ls:AlignableWrapPanel`;
- the resource `LSListBox` template contains an `ItemsPresenter` without a horizontal ScrollViewer;
- the resource header row is auto-sized while the action viewport keeps its existing 850px height;
- LB/RB remains a one-dimensional `SelectNextListBoxItem ForceMode=Cycle` selection model;
- collapsed/disabled null or MaxValue=0 previews remain skipped;
- no `AutoScrollBehavior`, `LSScrollViewer.ScrollToElement`, manual horizontal offset, or second-level tabs.

This remains one level of resource tabs; wrapping changes only presentation and removes scroll state entirely.


## Runtime correction — 0.0.68 -> 0.0.69

0.0.68 proves two points:
- the resource-strip scroll problem is better removed than repaired, but multi-row tabs are not an acceptable controller presentation;
- observing `ActionRadials.FocusedElement` still does not make the native action tooltip appear after programmatic tab entry.

0.0.69 changes product presentation and reuses stronger native data seams.

### Compact native resource tabs
- resource tabs must visually follow current keyboard `HotBar.xaml`: 72px resource boxes using `LSActionPointResources` with `ActionResourcesTemplateSelector`;
- spell-slot / warlock-slot tabs retain `RomanNumeralLevelImage`;
- text labels, horizontal scroll state, and wrapped rows are removed;
- the row is a single horizontal sequence and should fit ordinary resource sets because each preview is compact.

### Passives tab
- add one top-level Passives tab backed by the current executable `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList`;
- do not introduce a second action grid: the existing `HotBarList` switches its `ItemsSource` between `SingleHotBar.SlotList` and `PassivesHotBar.SlotList`;
- Passives mode is CAM presentation state only: `CAM_ResourceTabs.Tag = CAM_PassivesModeToken`; do not invent a BG3 gameplay command/property for switching it;
- LB/RB remains one logical cycle: resource previews plus Passives;
- top-level B still closes because passive mode is not native nested/upcast/container state.

### Item counts
- current Patch 8 `HotBarSlotStyle` proves `SlotType=Item` content is a `VMItem`;
- keyboard HotBar delegates that content to native `Template.Item`, whose quantity binding is direct `VMItem.Count`;
- CAM item cells must therefore render `VMHotBarSlot.Content` through `Template.Item` (or the native equipment/container variants) and let that template own `CountToVisibilityConverter`, `AbbreviateNumberConverter`, and `ItemAmountTextStyle`;
- do not bind stack quantity through `VMHotBarSlot.GameObject` or maintain a separate CAM count overlay.

### Resource/passive entry focus
The 0.0.65 split-brain was caused by one-shot `SelectedItem` presentation while stale `LocalFocus` still survived. 0.0.66 later added the missing `LocalFocus = null` boundary.

0.0.69 intentionally combines those proven halves:
- before any top-level tab transition, clear `HotBarList.LocalFocus`, `SelectedIndex`, tooltip, Tag, and resource highlights;
- after the target list settles, set `SelectedIndex=0` and use the existing concrete-item `SetMoveFocusAction` handoff;
- at that entry-only boundary, populate tooltip/Tag/highlight from the same first `SelectedItem`;
- normal D-pad navigation remains exclusively `LocalFocusChanged -> LocalFocus.DataContext`;
- remove the ineffective 0.0.68 widget-`FocusedElement` presentation trigger.

The one-shot `SelectedItem` path is allowed only because stale `LocalFocus` is cleared first and the exact same selected container is handed to `SetMoveFocusAction`.


## Runtime correction — 0.0.69 -> 0.0.70

0.0.69 runtime disproves two assumptions from the previous iteration:

- `LSActionPointResources + ActionResourcesTemplateSelector` is the native resource **point/charge renderer**, not the HotBar resource icon presentation the player expects for tabs;
- publishing entry state from `HotBarList.SelectedItem` immediately after a deferred `SetMoveFocusAction` can make tooltip/A state advance to index 0 while the authoritative controller `LocalFocus` has not advanced with it.

0.0.70 restores one authority for action identity and uses the native action-resource icon seam:

### Resource tab icons
- each resource tab keeps the compact 72x72 HotBar resource box;
- the icon inside the box is an `Image` with `DataContext={Binding ActionResource}` and native `SectionImageStyle`, which resolves `VMActionResource.TypeId` through BG3's action-resource icon paths (including the missing-resource variant);
- `RomanNumeralLevelImage` remains the level overlay for SpellSlot / WarlockSpellSlot;
- `LSActionPointResources` is not used as the tab icon renderer.

### Tab-entry focus and tooltip
- keep the runtime-proven concrete first-`ListBoxItem` focus handoff from 0.0.64;
- the selected container consumes `CAM_ResetFirstFocusToken`, invokes deferred `SetMoveFocusAction`, then clears the reset token directly;
- remove `CAM_EntryFocusCommittedToken` and all entry-only `SelectedItem` tooltip/Tag/highlight writes;
- after programmatic `HotBarList.SelectionChanged`, a delayed wake-up may refresh tooltip/Tag/highlights **only** from `HotBarList.LocalFocus.DataContext`;
- if `LocalFocus` has not actually moved, no first-cell tooltip/A target may be synthesized;
- normal D-pad navigation remains `LocalFocusChanged -> LocalFocus.DataContext`.

This makes the visible selector, tooltip, resource highlights, and A dispatch converge on the same authoritative `LocalFocus` instead of treating selection as proof that focus moved.


## Runtime correction — 0.0.70 -> 0.0.71

0.0.70 runtime proves two remaining defects:

- the `SectionImageStyle` substitution is not the keyboard HotBar resource-button presentation;
- Passives is a synthetic CAM top-level mode, and returning from it currently mutates `CAM_ResourceTabs.Tag` during the same shoulder-button `Click` that also owns ordinary resource cycling. Later handlers in that same click can therefore observe the new mode and run again.

### Resource button presentation
The accepted keyboard HotBar resource-button seam is the compact 72px template already captured earlier in this project:
- `LSActionPointResources`;
- `ActionResourcesTemplateSelector`;
- `MaxActionPoints = MaxValue`;
- `AvailableActionPoints = Value`;
- `HighlightedActionPoints = preview Cost`;
- `DataContext = ActionResource`;
- native resource box chrome;
- `RomanNumeralLevelImage` for spell slots;
- the resource-value numeral overlay used when the native point renderer collapses a larger resource count.

Do not replace this with `SectionImageStyle`: that style is valid for other resource-icon surfaces (for example tooltip/upcast cost presentation), but it is not the HotBar resource-button renderer.

### Passives transition state
Passives remains the single explicit non-resource top-level mode, but entering/leaving it must be non-reentrant:
- while leaving Passives, keep `CAM_ResourceTabs.Tag = CAM_PassivesModeToken` for the entire originating shoulder-button click;
- prepare/filter the target native resource while Passives still owns `HotBarList`;
- only after that click has completed may a timer clear passive mode and hand focus to the first action;
- left return uses a dedicated `CAM_TabReturnLastToken`; right return keeps `CAM_TabReturnFirstToken`;
- ordinary resource-click handlers remain disabled for the whole Passives-return click;
- no second resource selection/filter transition may occur from one LB/RB press.

The action-focus authority remains `HotBarList.LocalFocus.DataContext`.


## Runtime correction — 0.0.71 -> 0.0.72

0.0.71 runtime disproves two remaining presentation assumptions:

- the CAM-added `ResourcesNumeralDisplay` is not acceptable for top-level tabs; it produces stray-looking resource numbers in the tab row;
- item quantity cannot be read from `VMHotBarSlot.GameObject.Count` in CAM's direct slot template. Current Patch 8 `HotBarSlotStyle` renders item slots by passing `VMHotBarSlot.Content` (a `VMItem`) into the native `Template.Item`, where quantity is bound directly to `VMItem.Count`.

0.0.72 therefore uses the native presentation seams instead of re-implementing them.

### Resource tabs
- remove the CAM-authored `ResourcesNumeralDisplay` entirely;
- keep `LSActionPointResources + ActionResourcesTemplateSelector` for the resource glyph itself;
- restore the captured Patch 8 `box_resourceNum_*` chrome for `SpellSlot` / `WarlockSpellSlot`;
- retain `RomanNumeralLevelImage` for slot level;
- normal resources keep the captured `box_resource_*` chrome;
- selected CAM tabs may map the native HotBar hover/highlight asset to persistent selected state, but must not invent labels or numeric overlays.

### Item cells
- a `VMHotBarSlot` remains the focus/dispatch unit;
- for `SlotType=Item`, presentation switches from the generic `Content.Icon` rectangle to a `ContentPresenter` over `VMHotBarSlot.Content`;
- ordinary items use native `Template.Item`, which owns `VMItem.Count -> CountToVisibilityConverter -> AbbreviateNumberConverter -> ItemAmountTextStyle`;
- equipment and item containers use native `Template.ItemEquipment` / `Template.ItemContainer` respectively;
- CAM must not maintain a separate quantity overlay or bind quantity through `VMHotBarSlot.GameObject`.

Focus, tooltip, Passives transition serialization, and gameplay dispatch are unchanged.


## Runtime correction — 0.0.72 -> 0.0.73

0.0.72 runtime confirms native item quantity is fixed and the stray resource numerals are gone, but the top-level tabs still do not look like keyboard/mouse HotBar filters.

The cause is a presentation-boundary error: 0.0.69–0.0.72 used the HotBar **action-resource bar** chrome (`box_resource_*`) as the tab chrome. The keyboard HotBar's **filter controls** are a different native component: `FilterButton` / `ActiveFilterButton` using the `btn_pil_*` family and the active top marker.

### 0.0.73 visual contract

- top-level resource semantics remain unchanged: `ActionResourcesCostPreview -> FilterActionResourceCommand -> SingleHotBar.SlotList`;
- each resource tab keeps native resource identity rendered by `LSActionPointResources + ActionResourcesTemplateSelector`;
- `SpellSlot` / `WarlockSpellSlot` keep `RomanNumeralLevelImage`;
- the outer tab chrome must follow the current HotBar filter-button contract:
  - normal: `btn_pil_d.png`;
  - active/selected: `btn_pil_active_d.png`;
  - disabled: `btn_pil_disabled.png`;
  - selected marker: `btn_pil_inactivemod_d.png + ActiveModArrow`;
  - nine-slice `Slices=36`, `Padding=10`, outer item `Margin=-4,0`;
- do not put `box_resource_*` or `box_resourceNum_*` behind the top-level tabs;
- do not restore text labels or resource-value numerals;
- Passives uses the same filter chrome so it is one visual sequence with resource tabs.

Item templates, focus/tooltip authority, Passives transition serialization, nested return, and A/B dispatch stay unchanged.


## Evidence correction — 0.0.73 -> exact current HotBar resource-filter capture

0.0.73 runtime disproves the assumption that CAM's requested icon tabs correspond to the keyboard HotBar `FilterButton / ActiveFilterButton` component.

There are two distinct native HotBar surfaces:

- textual deck/filter buttons such as Common/Class/Items/Passives use the `FilterButton / ActiveFilterButton` pill presentation;
- the icon row the operator is referring to is the **action-resource filter bar**, sourced from `CurrentPlayer.UIData.ActionResourcesCostPreview` and invoking `FilterActionResourceCommand`.

Do not make another visual runtime candidate from historical/public HotBar markup or from reconstructed assets. Before changing the tab presentation again, capture the exact installed Xbox App 1.8.910.0 `Mods/MainUI/GUI/Pages/HotBar.xaml` with the existing read-only self-contained capture tool and derive the resource-filter presentation from that file.

Historical 0.0.80–0.0.86 development releases were capture-only:
- the permanent operator VBS stayed unchanged;
- release-controlled `dev-entry.ps1` ran `capture-self-contained-inputs.ps1`;
- captures read `Game.pak` without modifying BG3 files.

The 2026-10-08 schema-v3 capture is now fully inspected in
`docs/research/schema-v3-capture-2026-10-08.md`. Beginning with 0.0.87,
the **current** development task is normal self-contained PAK installation:
- the same VBS downloads the new `dev-entry.ps1`;
- it delegates to the proven `install-latest.ps1` helper with the exact release metadata and portable launcher root;
- child exceptions, install status, and version equality are validated fail-closed;
- read-only capture remains published as an optional tool, not the current VBS task;
- there is no XAML/runtime/gameplay behavior change in this milestone.
The next operator game run is one combined runtime proof of focus, scroll,
category cycling and action coverage, not a repeated capture.

Already confirmed runtime behavior must remain untouched: native VMItem quantity rendering, LocalFocus authority, tooltip behavior, resource-first filtering, Passives serialization, nested return and native action dispatch.


## Runtime correction — exact 1.8.910.0 HotBar capture -> 0.0.75

The operator-provided read-only capture `bg3-controller-action-menu-inputs-20261007-201234.zip` contains the exact installed Xbox App `Mods/MainUI/GUI/Pages/HotBar.xaml` for package `1.8.910.0`, SHA-256 `9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728`.

It proves that the icon row the operator wants CAM to resemble is the native **Action Resources** strip, not the textual `FilterButton / ActiveFilterButton` family.

Authoritative native presentation:

- container: `ActionResourcesContainer`;
- shared background: `bar_resources.png`, height 64, `Slices="104,0"`, min width 208, width = resource-row width + 208;
- list: `ActionResourcesList`, source `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- native item type: `VMActionResourceCostPreview`;
- per-resource button: `Padding="0"`, `Margin="4,-10,4,10"`;
- per-resource root width: 72;
- item presenter margin: `-4,0,-4,0`;
- ordinary chrome: `box_resource_empty.png`, `box_resource_d.png`, `box_resource_h.png`, `box_resource_missing.png`;
- resource renderer: `LSActionPointResources + ActionResourcesTemplateSelector`, `SmallActionPointSize=24`, `ActionPointGroupSize=56`;
- spell/warlock slots: `box_resourceNum_*` chrome, `Margin="0,-8,0,0"`, plus `RomanNumeralLevelImage` at `Margin="0,-10,0,0"`;
- zero-value resources use the missing/disabled chrome;
- native `ResourcesNumeralDisplay` is **conditional**, not always visible: it appears only when `ActionResource.Value > ResourcePoints.MaxGroupActionPoints`; Bardic Inspiration adjusts its margin/font;
- native mouse hover maps normal chrome to `box_resource_h.png`.

Controller adaptation allowed for CAM:
- retain `LSListBox` selection because LB/RB requires a persistent controller selection model;
- map selected resource to the native hover/highlight chrome `box_resource_h.png`;
- suppress that resource selection highlight while Passives mode is active;
- render Passives as one additional 72px resource-box-style entry inside the same shared `bar_resources.png` strip because BG3 has no native action-resource preview object for passives.

Do not use `btn_pil_*` for CAM resource tabs again. Do not omit the shared `bar_resources.png` strip. Do not restore an unconditional resource-value number.

Native item quantity, LocalFocus authority, tooltip behavior, Passives transition serialization, nested return, and action dispatch remain unchanged.


## Runtime correction — 0.0.75 -> 0.0.76 resting resource preview

0.0.75 proves that copying the exact Patch 8 `ActionResourcesContainer` visual tree is not sufficient when CAM keeps the native hover-preview transport active under persistent controller focus.

Patch 8 HotBar behavior:
- action slot `MouseEnter -> HighlightResourcesCommand(slot)`;
- action slot `MouseLeave -> ClearResourceHighlightsCommand(slot)`;
- the resource renderer itself retains `HighlightedActionPoints=VMActionResourceCostPreview.Cost`.

CAM must keep that renderer/binding exactly, but persistent grid focus must not emulate an endless mouse hover. In CAM action-focus triggers, preserve the proven `HighlightResourcesCommand` seam only as a disabled action and immediately clear preview state with `ClearResourceHighlightsCommand`. Tooltip data, `ActionRadials.Tag`, and A dispatch remain sourced from `HotBarList.LocalFocus.DataContext`.

Do not replace the native renderer, alter resource quantities, or change filtering/Passives/nested/A/B semantics for this correction.


## Runtime correction — 0.0.76 -> literal native ActionResourcesList item template

0.0.76 fixes persistent controller resource-cost preview state, but the resource item itself is still CAM-owned through `ListBoxItem.ControlTemplate`. Runtime feedback requires the tabs to look exactly like keyboard/mouse HotBar.

For every native `VMActionResourceCostPreview`, CAM must use a dedicated `DataTemplate` whose visual subtree matches current Patch 8 `ActionResourcesList`:
- `LSButton Padding=0 Margin=4,-10,4,10`;
- inner `Root Width=72`;
- exact `box_resource_*` / `box_resourceNum_*` layers;
- exact `LSActionPointResources` bindings, including `HighlightedActionPoints = Cost`;
- exact `ResourcesNumeralDisplay` fallback and Bardic Inspiration adjustment;
- exact SpellSlot/WarlockSpellSlot Root.Tag -> spell-slot chrome transition;
- exact `IsMouseOver` highlight trigger;
- exact zero-value missing-resource trigger.

The outer `LSListBox` is controller transport only. Its item container may own the native presenter margin and suppress default ListBox chrome, but `ListBoxItem.IsSelected` must not alter any resource visual. LB/RB changes filtering only.

Do not replace native `LSButton` with a Grid. Do not map `IsSelected -> box_resource_h`. Do not zero `HighlightedActionPoints`: the exact HotBar template binds it to preview `Cost`.

The 0.0.76 resting-preview correction remains in force: controller action focus must not permanently drive HotBar resource-hover preview state.

Passives remains the sole synthetic CAM entry. Item quantities, action-grid focus/tooltip authority, nested return, Passives serialization and A/B dispatch are out of scope.


## Runtime correction — 0.0.84 -> 0.0.85

Older 0.0.66–0.0.67 resource-strip attempts proved that assigning `LSScrollViewer.ScrollToElement` alone did not move the non-focused shoulder strip. Fresh Patch 8 capture exposes the missing native commit step in `PreloadedActionRadials_c.xaml`: after `ScrollToElement` computes `TargetPosition`, `TargetPositionChanged` explicitly writes that value to `HorizontalScrollOffset`.

0.0.85 may therefore retry concrete-UIElement scrolling only as this full native lifecycle. Provider mode must be separated into `CAM_ProviderModeMarker.Tag`; `CAM_ResourceTabs.Tag` stores only the selected concrete resource container. The dynamic resource viewport is bounded while Cantrips / Items / Metamagic / Passives / All remain fixed and visible. This is not equivalent to the previously rejected ScrollToElement-only, AutoScrollBehavior, index/item-target, or wrapped-row experiments.


## Runtime correction — 0.0.87 -> 0.0.88 tab controls

The combined in-game milestone reported that LB/RB no longer switched tabs and the resource strip looked less aligned than native HotBar. Static readback found a concrete 0.0.85 regression: 22 XAML mode checks still used `{Binding Tag, ElementName=CAM_ResourceTabs}` **after** that list's `Tag` changed to a concrete selected `ListBoxItem` scroll target. Comparisons against `CAM_*ModeToken` or `{x:Null}` are then invalid. Every mode reader in the main runtime must bind `CAM_ProviderModeMarker.Tag`, while `CAM_ResourceTabs.Tag` must be used ONLY for scrolling.

LB has nine and RB has seven mutually exclusive `Click` transitions (sixteen total). Every transition now guards `CAM_TabCycleMarker.Tag == null` and marks its turn before changing provider mode. Do not let a later Click trigger act on an already changed provider during the same input event. Preserve delayed first-cell focus, resource selection, native `UseSlotCommand` and `TargetPositionChanged` scrolling; do not add another input binding or timer.

Special provider frames reuse exactly the native `CAM_ResourceBackgroundMargin` used by original Patch 8 resource chrome. Cantrips uses the native 72x72 `IconMiniCantrip` presentation. Items/Passives/All use consistently sized icons. These extra groups are CAM-only and cannot be claimed to have a literal equivalent in vanilla ActionResourcesList. This is a static correction; only a future single combined game test can establish controller runtime behavior.


## Native HotBar visual reuse — 0.0.89

The resource-strip renderer is based on the captured Patch 8 inline `HotBar.xaml` `ActionResourcesList.ItemsControl.ItemTemplate` for `VMActionResourceCostPreview`. This is a **page-local inline template**, not a globally importable controller dictionary resource, so a shared `StaticResource` reference to that inline node is impossible without changing game files. CAM instead hosts the equivalent captured visual subtree in the controller library and adapts only the resource-controller selection transport. Do not independently draw resource symbols or recompute BG3 action/resource overlays.

The capture contains `<Thickness x:Key="ResourceBackgroundMargin">0</Thickness>`. Prior CAM releases referenced `CAM_ResourceBackgroundMargin` without defining it, including in all five special provider tabs. 0.0.89 declares the exact original value locally. Static tests must reject any CAM_* resource reference lacking a corresponding local `x:Key`.

The native resource preview uses `IsMouseOver=True` to show the `box_resource_h` chrome; moving LB/RB does not generate mouse hover. To preserve native appearance under the controller, the resource `DataTemplate` additionally maps *selected ListBoxItem AND no special provider mode* to the same `Bg/BgHL/BgDisabled` visibility setters, with `ActionResource.Value=0` still enforcing disabled chrome. When special tabs are active, the remembered resource selection must not appear highlighted. Never make controller selection a native action-model property.

Actual resources reuse the native `LSActionPointResources`/RomanNumeralLevelImage selectors. Special tabs are CAM-only and cannot be imported as native `VMActionResourceCostPreview` objects; they reuse the same native background assets and geometry while their content icons remain provider-specific. Static/CI parity cannot prove in-game Noesis visual evaluation.


## 0.0.90 native resource baseline correction

The Patch 8 keyboard `HotBar.xaml` attaches the resource-strip container, nine-slice background, horizontal `ActionResources` row, and `ActionResourcesList` to **VerticalAlignment=Bottom**. CAM previously centered the corresponding pieces inside a fixed 84-unit controller row and also centered each hand-composed special-provider frame. This is an objective geometrical difference independent of icon textures and a possible cause of the reported crooked indicator alignment. Keep the 84-unit header, functional LB/RB transitions, selected resource scroller and exact resource preview template, but align the resource row, background and all provider frames to the same bottom baseline. Never introduce a guessed per-icon scale factor to conceal this geometry issue. The completed CI proves markup shape only, not Noesis rendering parity.


## 0.0.91 resource-point glyph isolation

Screenshots of keyboard HotBar vs CAM on 2026-10-08 show a different
**glyph source** (star/clover/flame/square groups versus enlarged
primitive bars), not merely a coordinate or background mismatch.
The resource preview already uses native VMActionResourceCostPreview,
LSActionPointResources and ActionResourcesTemplateSelector; 0.0.90
corrected the bottom alignment, but that does not select the keyboard
resource-point image template while running in the controller library.

The next *single-seam* runtime candidate sets a local, project-authored
LSActionPointResources.ActionPointTemplate that uses the native Patch 8
IconIdToSourceConverter and ActionResourcePoint*IconsPath with the live
ActionResource.TypeId. It must handle normal/highlight/used/missing images,
retain the native LSActionPointResources quantity/group/style model, and
not create hard-coded icons, class mappings, or gameplay filters.

Do not change controller navigation, resource tab selection, provider modes,
grid focus, tooltip, A/B, nested return or item quantities together with
this visual fix. It remains static-proof-only until verified in game.


## 0.0.91 runtime rejection; 0.0.92 mode-resource proof gate

Operator observed **no visual change** from the 0.0.91
`CAM_KeyboardHotBarPointGlyph` / `ActionPointTemplate` override.
Do not claim this fixes resource icon parity or keep layering resource
image/size guesses on it.

The 1.8.910.0 archive examined on 2026-10-08 proves the controller's
`Libs_Controller.xaml` imports mode-specific `DataTemplates_c.xaml`
and `ActionResourceTemplates_c.xaml`. The 22-file capture did not
include either dictionary nor `DataTemplates_k.xaml`. Before changing
resource visuals again, inspect the exact installed copies of all three
and compare them to the pinned `DataTemplates.xaml` / `HotBar.xaml`.
Historical public copies show controller/keyboard icon/size differences
but do not authorize unverified changes against the installed game.

0.0.92 is read-only capture **only**. Its universal VBS does not install
or alter CAM/game data. Preserve the mod execution model, tab navigation,
resource/filter semantics, focus/tooltip, item counts and nested A/B.
Do not ask for another in-game screenshot until a proven renderer fix
passes static/package checks. See
`docs/research/keyboard-controller-resource-glyph-investigation-2026-10-08.md`.


## 0.0.93 exact 1.8.910.0 keyboard resource template proof

The `bg3-controller-action-menu-inputs-20261008-114231.zip`
provides all missing native dictionaries. `DataTemplates_k.xaml`
defines ActionResources group/point/small sizes **56/48/24**, whereas
`DataTemplates_c.xaml` defines **80/80/36** and sends
ActionPoint/BonusActionPoint to the background-backed
`ActionResources.ActionGroup.ActionPointWithBG`. Keyboard point groups
use shared `ActionResources.ActionGroup.ActionPoint`.

The previous 0.0.91 manually cloned per-state point glyph was
runtime-rejected; never restore it as the solution. The 0.0.93
controller template locally adopts the exact keyboard point-group
ContentPresenter and locally scopes keyboard sizing resources inside
`CAM_ResourceTabTemplate`'s Root; the native game's selector retains
resource TypeId, costs, value/group logic and other per-type overrides.
Keep these scoped, not global: do not copy/import all `DataTemplates_k`
or replace controller library dictionaries.

0.0.93 restores the universal VBS's normal release-controlled
self-contained **install** task; capture remains optional. The first
in-game proof is limited to visible HotBar resource glyph/spacing
parity, with a quick check of LB/RB and tooltip; do not ask for
separate repeated experiments. If unchanged, return to the specific
resource-lookup reason, not speculative new image or scale overrides.


## 0.0.94 isolated resource-glyph runtime proof

Operator has rejected 0.0.91 and 0.0.93 visual changes as ineffective.
The green build, successful v0.0.93 install and captured keyboard/controller
resource dictionaries do NOT prove the effective in-game point image.

0.0.94 is an intentionally temporary **diagnostic** release, not a
visual correction or user acceptance. Inside the existing
`CAM_ResourceTabTemplate`, show:

- yellow `94` on each resource: proves this exact resource-item template is
  loaded and displayed, independent of the successful installer log;
- a magenta-labelled `B` image, directly resolved via
  `IconIdToSourceConverter(ActionResourcePointIconsPath, ActionResource.TypeId)`,
  bypassing `LSActionPointResources` grouping and point-template selection;
- native point renderer `LSActionPointResources` unchanged at tile center
  (the `A` visual baseline).

One **combined in-game screenshot** with at least ActionPoint,
BonusActionPoint and SpellSlot tabs has discriminating outcomes:
missing `94` => installed runtime XAML/template not active;
present `94` and correct B glyph => point/group renderer path to fix;
present `94` with equally wrong B glyph => shared image path/asset/fallback;
present `94`, empty B => direct binding/path not resolving.
No inference of confirmed pixel parity without this proof.

Keep all gameplay/provider/tooltip/focus/LB/RB logic untouched; remove
diagnostic overlays after the decision. Do not promote 0.0.94 as fixed.


## 0.0.94 result → 0.0.95 point bitmap constraint

Operator screenshot `image(8).png` shows the yellow/magenta
diagnostic markers on the resource tiles: the CAM 0.0.94 resource item
XAML is active, so another installer/PAK-load attempt is not the fix.
The original `LSActionPointResources` draws large and partly clipped
resource glyphs (notably spell squares, flame and clover); a separate
explicitly bounded `IconIdToSourceConverter` image on the *same*
`VMActionResourceCostPreview.ActionResource.TypeId` renders compactly.
This does not prove that all bitmap shapes exactly match the original.

0.0.95 moves the proven image-measurement boundary into the actual
per-point `CAM_KeyboardHotBarPointGlyph` DataTemplate:
`Width=24 Height=24 Stretch=Uniform`. The `24` is the captured native
keyboard `SmallActionPointSize`; not another invented UI offset.
The native `LSActionPointResources`, `ActionResourcesTemplateSelector`,
`VMActionResourceCostPreview`, per-TypeId cost/count grouping and
state-specific native image converter remain. The temporary diagnostic
`94` and independent `B` are deleted. No new per-resource icon
mapping is introduced. This is a bounded-image **runtime candidate**,
not accepted visual parity until a game screenshot verifies it.

Do not touch LB/RB, source/provider routing, focus, tooltip, nested
execution, available/used resource logic or item counts. If still
wrong, prove source bitmap identity/intrinsic size, not random scale.


## 0.0.96 source-exact keyboard HotBar point-groups

0.0.95 screenshot showed that the per-point 24×24 Uniform Image
workaround made resource symbols too tiny and did not restore parity.
Do not restore it or tune arbitrary icon measurements.

The authoritative installed keyboard `DataTemplates_k.xaml` exports
24 `ActionResources.ActionGroup.*` ControlTemplates, all of which
are pinned byte-for-byte in `CAM_ResourceTabTemplate`'s `Grid.Resources`.
The captured block SHA-256 is
`9e017778ec41ef2e03f192392ca944640f7d8ad3c227f69d9742aefbdaff4651`.
Using the original native `ActionResourcesTemplateSelector` means its
DynamicResource group lookup can select these keyboard templates in
the item control's own visual scope, without changing the game's
global controller library. The original `DataTemplates.xaml`
`ActionResources.ActionGroup.ActionPoint` is used unchanged.

Do not add any CAM-specific point Image, forced `ActionPointTemplate`,
hand-maintained TypeId->bitmap map, or global `DataTemplates_k.xaml`
merge. LB/RB, resource filtering, native used/missing/highlight states,
spell numerals, tooltip, focus, native nested A/B and item quantities
are outside this change. CI guards the copied block digest, not live
Noesis layout. Only a screenshot can accept visual parity.


## 0.0.96 glyph rejection and 0.0.97 theme-input evidence gate

The operator reports that 0.0.96 still renders wrong resource symbols.
Do not mark #119 fixed or assume matching keyboard
`DataTemplates_k.xaml` proves visual parity. The native shared
`ActionResources.ActionGroup.ActionPoint` glyph resolves its bitmap
through `StaticResource ActionResourcePointIconsPath` and TypeId,
which can depend on the loaded input-mode theme. The 0.0.96
keyboard templates did not replace the controller's
`DefaultTheme_c.Styles.xaml` with keyboard theme definitions.

0.0.97 is a **read-only theme capture milestone** through the same
unchanged universal VBS. Target and require current installed-game
keyboard and controller `DefaultTheme_*.Styles.xaml` and
`DefaultShared.Styles.xaml`; record their exact origin/hashes.
No mod/XAML runtime correction in this milestone. Resolve the
image-source provenance before another fix; no artistic guessing,
hardcoded TypeId mapping, or repeated ineffective install tests.


## 0.0.98 fix: source-exact keyboard point DataTemplate and theme paths

The failed 0.0.97 capture ZIP contains the decisive theme evidence:
keyboard theme style file is `DefaultTheme.Styles.xaml`, **not**
the nonexistent `DefaultTheme_k.Styles.xaml`; controller uses
`DefaultTheme_c.Styles.xaml`. Their
`ActionResourcePoint[Highlight|Missing|Used]IconsPath` values
point to fundamentally different asset folders:
keyboard `Assets/Shared/Resources/`, controller
`Assets/ActionResources_c/Icons/Resources/`.

The source-exact, shared `ActionResources.ActionGroup.ActionPoint`
DataTemplate uses `StaticResource` to bind these directory keys;
previous source-identical group templates retained controller image
path resolution. v0.0.98 provides four original keyboard path
strings, followed by the unchanged 8,143-character point DataTemplate
(SHA-256 `eee27b44205de8d3fbacac302c9427b8c33f785fea0f39b9b4dfda51cba22d84`)
and all 24 unchanged original keyboard group templates
(SHA-256 `9e017778ec41ef2e03f192392ca944640f7d8ad3c227f69d9742aefbdaff4651`)
in the CAM resource-item local Grid.Resources.
No controller global resource mutation, 24x24 manually authored icon,
hardcoded TypeId tables, or new game input modifications.

Capture's required keyboard theme path is fixed to
`DefaultTheme.Styles.xaml` and the permanent universal VBS
returns to the normal install task. #119 remains open until the
operator sees genuine native HotBar glyph parity in BG3.
