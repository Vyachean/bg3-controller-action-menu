# 0.0.115 rejected: native focus, cancel and upcast evidence

Date: 2026-10-09. Target: Xbox App BG3 Patch 8, installed
1.8.910.0. This is **research only**. v0.0.115 was tested by the
operator and **all previously reported problems remain**; green CI is
NOT gameplay acceptance. No XAML/packaging/release change follows
from these findings.

## Independent checked sources

1. **Noesis official controls**:
   https://www.noesisengine.com/docs/Gui.Core.ControlsTutorial.html
   Selector.SelectedIndex / SelectedItem represent selection,
   while IsSelectionActive separately reports focus. A selection
   change does not establish actual controller focus.
2. **Noesis issue #1641**:
   https://www.noesisengine.com/bugs/view.php?id=1641
   An IsSelected=True ListBoxItem style trigger calling a focus
   action caused an internal selection-in-selection assertion in
   Noesis **2.2.6**. BG3 officially uses Noesis **3.1.6**
   (https://docs.baldursgate3.game/index.php?title=UI).
   **Version mismatch:** this is a risk to examine, NOT evidence
   that the old Noesis bug reproduces inside BG3.
3. **Published historical BG3 ActionRadials source**:
   https://github.com/akintos/bg3-data/blob/31f3e066e90d4d5ce2b43b4a32d5917547765750/Public/Game/GUI/Widgets/ActionRadials.xaml
   Original SingleBar.LocalFocusChanged writes LocalFocus.Tag into
   ActionRadials.Tag and executes tooltip/HighlightResources from the
   same object; the visible radial pointer requires both the parent
   focused state and non-null LocalFocus. Focus is placed on a real
   templated control on Loaded. **This source is older than Patch 8,
   assembly SharedGUI, and cannot be copied verbatim.**
4. **Independent BG3 Patch8 archive**:
   https://github.com/Coyote-31/bg3-advanced-character-sheet/tree/71fe9015ac3b848fa11fbba53c6286872f140e3e/Sources/BG3/Patch8/Game
   DataTemplates.xaml around lines 1480–1500 declares a native
   VMUpcast *visual* DataTemplate; HotBarSlotStyle around 1545–1550
   dispatches UseSlotCommand with the current bound slot.
   Controller StateMachines/Controller.xaml around 689–710 defines
   ActionRadials as a modal state and CloseWidget as RemoveState.
   These archive files are **NOT byte-identical** to CAM's pinned
   Xbox App 1.8.910.0 originals: SHA-256 comparison of the retrieved
   DataTemplates and Controller file contents with
   docs/evidence/patch8-1.8.910.0-runtime-contract.json returned
   mismatches. Confirming VMUpcast as a type or RemoveState as an
   event does NOT prove a chosen resource-IV executable or
   metamagic rollback.
5. **Independent Patch8 runtime UI test**:
   https://github.com/Norbyte/bg3se/issues/584
   A developer found that Noesis ScrollViewer.VerticalOffset and
   LSScrollViewer.ScrollToElement accepted writes but did not
   visually scroll a keyboard character-creation list. This does
   NOT establish the same defect in controller ActionRadials.
6. **No-SE working controller menu**:
   https://github.com/Luiznunes12/bg3-nmcm/blob/3f14c694e30d0c96c7de391e8bafa97e1cb062a1/docs/gamepad.md
   Uses two focusable flags on concrete controls, gamepad-specific
   StateMachine, and direct SetMoveFocusAction. Does NOT demonstrate
   stable focus in CAM's dynamically rebound LSGrid/LSListBox.

## Exact ownership conflict in current CAM

File:
BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml
at v0.0.115 main 33570653dbb3722b1800f38834478992cb1f9981.

- CAM_ActionGridSlotContainer has a DataTrigger on
  `ListBoxItem.IsSelected=True`; only if the ancestor list Tag equals
  `CAM_ResetFirstFocusToken` does it *request* deferred
  `SetMoveFocusAction(FocusElement=TemplatedParent)`.
  This tests selected state, not achieved native controller focus.
- CAM_FixedSideBarList is Focusable=False and its *children* are
  focusable. Its selector's visibility, tooltip, and native command
  parameter are driven by `LocalFocus.DataContext`. B/LB/RB reset
  `LocalFocus` and `SelectedIndex=-1 -> 0`, but cannot prove a
  corresponding `LocalFocus` transition.
- The sidebar's LocalFocusChanged trigger explicitly assigns
  `ActionRadials.Tag=null`. A separate **70ms** timer later
  republishes `LocalFocus.DataContext`; an independent delayed
  SelectionChanged timer can also republish it. Yet the live A button
  uses `UseSlotCommand(ActionRadials.Tag)`. The source therefore
  has multiple publishers and a real intermediate null value.
  This is a structural fact; exact BG3 scheduler timing is unknown.
- CancelButton has native UICancel/ClearSingleHotbarCommand,
  command override and additional LSButtonReleased handlers. The
  #186 extra native ActionCancelCommand executed in source
  before CAM phase reset but the operator saw no fix. Do NOT infer
  which compiled command executed or that it cancels MetamagicActive.
- A successful Release and installer path do not identify the exact
  XAML revision resolved by the running game if UI overrides
  compete. A CAM grid appearing only proves a CAM UI is present,
  not which immutable asset revision won.

## Engineering decision and next gates

1. Prove a single native focus/dispatch owner directly from **the
   pinned 1.8.910.0** PreloadedActionRadials_c.xaml and
   FocusableControls_c.xaml. A deterministic source check must
   distinguish actual focus from SelectedIndex, and no delayed
   publisher may silently leave ActionRadials.Tag null/stale when A
   is accepted.
2. Prove game-owned metamagic rollback. Neither a command name,
   CloseWidget/RemoveState nor a custom presentation marker
   constitutes evidence.
3. Prove the level-specific engine `VMUpcast` executable identity
   derived from resource IV. The independent visual template and
   native nested chooser are insufficient; never switch to Osiris
   UseSpell, which bypasses normal costs and availability.
4. For weapon switch and footer, reconstruct the *complete*
   native hold control/input scope and active layout, not another
   fixed width or extra BoundEvent.
5. Establish loaded PAK/template identity and possible competing
   controller UI overrides from evidence. Treat collision as a
   hypothesis until verified.

**No new build and no operator request.** Source-only tests, even
with this evidence, cannot close #155, #158, #167, #172, or #154.
Only a coherent source-backed mechanism with a consolidated
acceptance milestone can justify another in-game test.
