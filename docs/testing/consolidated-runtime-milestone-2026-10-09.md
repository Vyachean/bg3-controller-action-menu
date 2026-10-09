# Consolidated BG3 controller-runtime milestone (candidate, not release)

Date: 2026-10-09. Tracking: #176, #172, #158, #155, #154, #167.
Implementation: **draft PR #193** on `fix/native-sidebar-focus-minimal`.
Installed baseline: Xbox App BG3 1.8.910.0, **v0.0.115 rejected**.

## Objective

Use **one** informative game session to distinguish (a) engine source/
upcast selection, (b) controller actual native focus and executable slot,
(c) nested task/cancel transitions and (d) unrelated HUD/hold controls.
Do not make the operator test each XAML guess or publish a new release
before this gate. No Script Extender, DLL, installer-time extraction
or ad-hoc action/spell calculation.

## What automated verification can and cannot prove

1. Validate: shipping package inputs parse, required files exist, no
   injected loader or forbidden game-owned paths.
2. Build package: Windows Divine packaging, PAK round-trip and installer
   mock testing. Artifacts can be built from PR without publishing a release.
3. `tools/trace-upcast-parity.py --self-test`: verifies the diagnostic
   XML source-site extractor on synthetic fixtures only; no real game
   behavior or exact implementation-shape assertions.
4. Optional source investigation with an **existing, locally retained**
   read-only developer capture:

   ```powershell
   python tools/trace-upcast-parity.py --capture .\bg3-controller-action-menu-inputs-20261008-132651.zip --output .\upcast-parity-source.json
   ```

   The analyzer hashes the *actual original bytes* of three native
   Patch 8 files against `docs/evidence/patch8-1.8.910.0-runtime-contract.json`:
   `HotBar.xaml`, `PreloadedActionRadials_c.xaml`,
   `DataTemplates.xaml`. Duplicates, missing originals, malformed
   XAML, mismatched hashes or different reported game version
   invalidate the original-source comparison. Only binding metadata,
   named element paths and hashes appear in the report; original
   proprietary XAML is not committed, shipped or pasted in the report.
   If the archive is unavailable, CAM-only binding sites can still be
   reported, explicitly **without** claiming native source equivalence.

5. Even a fully verified original XAML does **not** contain the compiled
   `DCHotBar` implementation, current `SingleHotBar.SlotList` values
   or the controller's live `LocalFocus.DataContext`. Proven
   executable `VMUpcast` identity requires native ViewModel evidence
   or the consolidated runtime observation below.

## Artifact identity gate

Use the **Build package GitHub Actions artifact from the exact
PR commit**; never mistake the latest published release for PR code.
Before the session, record PR SHA, workflow run ID, PAK SHA-256, Xbox App
build version, installed mod version, and whether conflicting ActionRadials
UI overrides are active. Do not modify the game files to instrument
Noesis. The current one-click VBS fetches **published latest**, not
necessarily a draft PR artifact; it is NOT evidence that PR #193 is
running. The game test must not start until the exact candidate PAK can
be installed and identified by an approved development path.

## One-session observation matrix

Evidence can be a single short recording plus the on-screen
tooltips and the installed-asset identity. No debug overlay is required
in the shipping package. Mark **PASS / FAIL / UNKNOWN** per scenario;
do not infer PASS merely because the action menu opens.

| Stage | Exact procedure | Required observable result | Diagnoses on failure |
| --- | --- | --- | --- |
| 1. Controller focus and tabs | Open menu; switch two resource tabs with LB/RB; navigate to last cell and back; return to the prior tab | Visible native selector, selected item, tooltip and intended A all follow the same first/last concrete cell; no blank-grid navigation or delayed second-cell jump | #155/#176 main LSGrid vs LSListBox owner, first-cell focus and source refresh |
| 2. Resource IV | With a character having an upcastable spell and an IV slot, use keyboard original HotBar IV filter as reference, then CAM IV tab → same spell | Same **IV-level** spell tooltip, scaling/damage/cost and engine action without selecting IV again; native targeting preserved | #172 filter-created slot vs VMUpcast identity, Tag dispatch, provider/source instance |
| 3. Metamagic nested phase | Select one metamagic option then review spell choices; choose an allowed spell, B back; repeat switch away/back | Only actually compatible executable spells can be navigated; B returns visible first-cell focus; no surviving metamagic selection after close/reopen | #158 game-owned MetamagicActive/compatibility source vs CAM presentation state |
| 4. Nested B and cancel | Open a true nested variant/upcast/throw choice; press B; reopen and choose again | Exactly one native level of back navigation; focus, tooltip and A restored; old parent slot never dispatched after the native nested source switch | #176 nested enter/return ordering; stale Tag vs actual LocalFocus |
| 5. Weapon switch hold | Compare native controller behavior outside CAM with the same input held inside CAM; observe on-screen hint/progress | Hold input, progress and set change match native behavior | #154 command/button owner and hold style/input scope |
| 6. Right-hand footer | Compare same-size game screen with original ActionRadials UI and CAM | Hint sequence, right alignment and HUD spacing match; no overlapping normal game HUD | #167 layout owner, not another speculative fixed width |
| 7. Optional modded action | Repeat resource tab with one mod-added skill if already present in the character | An available native action remains reachable and executable with proper resources/tooltip | Dynamic action provider coverage; never hard-code class/action names |

## Diagnostic decision tree

- Original keyboard tooltip IV, CAM tooltip **base level**: inspect
  `FilterActionResourceCommand` output and focused
  `VMHotBarSlot.Content` in controller context before editing A.
- Both tooltips IV but A opens an **extra level selector**: inspect
  the *engine-produced* executable `VMUpcast` vs
  `ActionRadials.Tag` at UIAccept, then native nested task state.
  Do not suppress the native state merely because it is redundant.
- Tooltip/focus ring diverge or A does nothing: investigate list
  `LocalFocus`, first-selection token, `IsEnabled` and 70-ms
  native commit, not spell damage or resource calculations.
- After B, marker/focus returns but `MetamagicActive` persists:
  native cancel transaction not proved, **not** a visual focus fix.
- Incorrect footer or weapon hold: diagnose independently from
  upcast and metamagic; neither should block unaffected actions.

## Go/no-go

**No-go now:** #172, #158, #176, #154, #167 are still
runtime-unverified, and no complete game capture can prove compiled
ViewModel semantics. Draft PR #193 and CI-green source candidates are
NOT gameplay accepted. Do not close issues or publish a normal release
until the milestone provides positive observed proof for the target
interactions, or a documented technical limitation forces a revised
product scope.

The single-session matrix is a **future acceptance protocol**, not an
instruction for the operator to test immediately. Source inspection
and a verifiable candidate artifact identity are preconditions.
