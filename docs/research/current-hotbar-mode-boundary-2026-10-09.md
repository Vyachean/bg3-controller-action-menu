# Current keyboard/controller hotbar state boundary — 2026-10-09

Scope: architecture evidence for #172/#176 and draft PR #193. This note
answers a narrower question raised while reviewing Better Hotbar: **can CAM
safely treat current keyboard HotBar state as the controller ActionRadials
state?** Current evidence says **no**.

## Evidence ladder

### 1. Current engine hotbar storage explicitly distinguishes controller state

Current BG3 Script Extender source at
[Norbyte/bg3se commit `fece8b27375b5cd39b2f868d6a22f20a0ff85d98`](https://github.com/Norbyte/bg3se/blob/fece8b27375b5cd39b2f868d6a22f20a0ff85d98/BG3Extender/GameDefinitions/Components/Hotbar.h)
exposes the game hotbar container model:

- `hotbar::Bar.Controller`;
- `AddSlotEntryData.HotBarController`;
- `SlotEventData.IsController`;
- `ContainerComponent.Containers` and `ActiveContainer`.

This is engine-data evidence that keyboard and controller hotbar/radial
persistence are not merely two renderers over one undifferentiated saved bar.
It does **not** expose Larian's proprietary `DCHotBar` ViewModel or prove how
`FilterActionResourceCommand` constructs `SingleHotBar.SlotList`.

### 2. A September 2026 production mod confirms current keyboard live-VM seams

[`belakarkache/bg3-shared-actions` commit `2459fa91fb95a4795659840cb5930c695bfa0dab`](https://github.com/belakarkache/bg3-shared-actions/blob/2459fa91fb95a4795659840cb5930c695bfa0dab/src/Mods/SharedActions/ScriptExtender/Lua/Client/VariantMenu.lua)
reads the **live** top-level keyboard `HotBar.DataContext` through Script
Extender and uses:

- `CurrentSingleHotbarFilter`;
- `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList`;
- `slot.Content.PrototypeID`;
- `context.UseSlotCommand:Execute(slot)`.

This independently confirms that `CurrentSingleHotbarFilter`,
`KeyboardHotBars`, native slot VMs and `UseSlotCommand(slot)` remain active
modern contracts in 2026. It is **keyboard-only runtime evidence** and Script
Extender is not a shipping dependency or implementation route for CAM.

#### Xbox App limitation of the development-only live probe

The repository's `dev/script-extender/` probes are useful only as
**surrogate research tooling** on a Script-Extender-supported installation.
They are not a diagnostic path for the target Xbox App / Play Anywhere build.

As of 2026-10-10, Norbyte/bg3se issue
[#593](https://github.com/Norbyte/bg3se/issues/593) remains open for the Xbox
Game Pass / Play Anywhere PC package. That package uses a different
installation/executable layout (not the normal Steam/GOG `bin/bg3_dx11.exe`
shape), and the reporter documents that Script-Extender-dependent mods do not
work there. Current BG3SE release instructions likewise install through
`Baldurs Gate 3/bin`.

Therefore:

- `GameplayInventoryProbe.lua` must never become a prerequisite for the Xbox
  App user or the production mod;
- a Steam/GOG probe can reveal **possible ViewModel property/identity seams**,
  but it cannot certify Xbox App 1.8.910.0 equality;
- the authoritative Xbox path remains read-only original-XAML capture plus
  actual no-SE PAK runtime observation;
- any conclusion learned through the surrogate probe must be re-grounded in a
  game-owned source seam before shipping.

### 3. Patch-8 Radial Hotbar Customization source directly separates modes

Radial Hotbar Customization v0.8.0.0 is marked Patch 8 compatible. Its
Apache-2.0 source tag `v0.8.0.0` points at GitLab commit `83950d75`:
https://gitlab.com/saghm/RadialHotbarCustomization/-/tags

The immutable tag archive was downloaded in a one-shot GitHub Actions research
job without executing its code. The relevant source is explicit:

- `src/entity.d.tl`: `Entity.HotbarContainer -> Containers.DefaultBarContainer`;
- each `Bar` exposes `Elements`, `Index`, and `field_1`; the source comment
  records observed `field_1=0` for keyboard/mouse hotbars and `field_1=1`
  for controller radials;
- `src/tl/Server/Player.tl`: `Player:Containers()` returns
  `entity.HotbarContainer.Containers`; `ClearHotbars()` iterates
  `DefaultBarContainer` and branches on `bar.field_1 == 0`;
- `GetSerializedHotbars()` serializes the **whole**
  `DefaultBarContainer`; restore unserializes it back and calls
  `entity:Replicate("HotbarContainer")`;
- `src/tl/Server/PersistentTypes.tl` maps numeric marker `0 -> "Hotbar"`,
  `1 -> "Radial"`.

This independently corroborates current BG3SE's controller marker and proves
that the mod treats keyboard/mouse bars and controller radials as distinct
**persisted hotbar-container state**. It also clarifies what this evidence is
*not*: the source never exposes Larian's live `DCHotBar`,
`FilterActionResourceCommand`, `SingleHotBar.SlotList` or the runtime
`VMHotBarSlot` materialized after a resource filter. Therefore this source
cannot justify using persisted `ControllerHotBars`/radial assignments as
CAM's automatic catalog and cannot solve direct resource-IV upcast parity.

The mod README also documents trouble with three-level radial selections when
bars are locked. That corroborates that nested variant/upcast state interacts
with radial persistence, but it is not an execution contract for CAM.

### 4. Auto-Sorting Hotbar independently added controller-radial support in 2026

Auto-Sorting Hotbar v1.1.0.0 added explicit radial-wheel/controller-hotbar
support in August 2026, after earlier releases were keyboard-focused:
https://www.nexusmods.com/baldursgate3/mods/24369

Its distribution requires Script Extender/MCM and its source was not located in
an inspectable public repository in this audit. It is therefore corroborating
product evidence, not an implementation source for CAM.

## What the exact Xbox App 1.8.910.0 capture already proves

The repository's SHA-pinned installed-game evidence remains the authority for
CAM source design:

- resource preview: `CurrentPlayer.UIData.ActionResourcesCostPreview`;
- filter: `FilterActionResourceCommand(VMActionResourceCostPreview)`;
- filtered/nested executable source: `SingleHotBar.SlotList`;
- executable unit: outer `VMHotBarSlot`;
- slot content may be `VMCharacterAction`, `VMUpcast`, `VMItem` or
  `VMPassive`;
- controller A: `UIAccept -> UseSlotCommand(ActionRadials.Tag)`;
- `ActionRadials.Tag` is populated from actual `LocalFocus.DataContext`.

The exact installed capture identifies the original files by SHA but does not
contain the compiled producer implementation. A shared `ContextName=HotBar`
or matching property names **does not prove that keyboard HotBar and controller
ActionRadials have the same DCHotBar instance, mode, or filtered-slot
materialization**.

## Patch 8 slot style rules out a separate upcast dispatch command

An independent public Patch 8 `DataTemplates.xaml` copy at
[Coyote-31 commit `71fe9015ac3b848fa11fbba53c6286872f140e3e`](https://github.com/Coyote-31/bg3-advanced-character-sheet/blob/71fe9015ac3b848fa11fbba53c6286872f140e3e/Sources/BG3/Patch8/Game/Public/Game/GUI/Library/DataTemplates.xaml)
corroborates the execution boundary already recorded from CAM's exact installed
capture:

- `HotBarSlotStyle` defaults to
  `UseSlotCommand` + `CommandParameter={Binding}`;
- its visual root is explicitly designed around `VMHotBarSlot`;
- the tooltip consumes `VMHotBarSlot.Content`;
- `VMCharacterAction` and `VMUpcast` are **Content** templates;
- command overrides shown by the style are for melee/ranged weapon handling and
  disabled/active slots, not a separate “execute upcast” path.

Therefore the keyboard resource-IV behavior cannot be explained by a hidden
XAML command that CAM forgot to call. The decisive difference must be the
**outer VMHotBarSlot produced/selected and the DCHotBar state around it** (or
compiled command behavior conditioned on that state). A CAM fix must preserve
the outer slot identity rather than dispatching `slot.Content`.

This public file is supporting evidence, not a replacement for the SHA-pinned
Xbox App 1.8.910.0 original; the installed capture-derived runtime contract
remains authoritative.

## Consequence for resource-IV parity (#172)

The operator's first-hand current keyboard behavior remains the product target:

```text
keyboard IV resource filter
  -> select an upcastable spell
  -> IV-level tooltip
  -> IV-level executable action
  -> no second IV level choice
```

CAM currently supplies the same *family* of resource preview/filter command but
executes through controller `ActionRadials`. Given the verified keyboard /
controller state separation, the following inference is now explicitly
forbidden:

```text
same binding/property names
  => same DCHotBar instance
  => same filtered VMHotBarSlot contents
```

That equality is exactly what must be proved or disproved.

## Why “auto-select nested item by level” is not approved yet

Public Patch 8 `DataTemplates.xaml` confirms:

- resource-preview `ActionResource` exposes `Level` to the native
  `RomanNumeralLevelImage`;
- `VMUpcast` exposes `SpellSlotLevel` to native slot presentation.

That makes a *level comparison* technically conceivable. It is still
insufficient for a safe automatic cast:

1. level IV can be backed by distinct resource families (for example normal
   spell slots vs Warlock spell slots);
2. current open `VMUpcast` presentation does not prove a resource-type
   identity that can be matched to the selected
   `VMActionResourceCostPreview.ActionResource.TypeId`;
3. presentation bindings do not prove uniqueness or the exact executable
   `VMHotBarSlot` containing that `VMUpcast`;
4. an automatic second `UseSlotCommand` would cross a game-owned nested task
   boundary and must not run on an ambiguous or not-yet-materialized list.

Therefore #172 must stay fail-closed: **if exact game-owned variant identity is
not uniquely proven, retain BG3's native chooser rather than select by index or
level alone.**

`tools/trace-upcast-parity.py` now records whether the SHA-verified
`VMUpcast` DataTemplate exposes `SpellSlotLevel` and any resource-identity
binding to XAML. Even if both are visible, it deliberately keeps
`safeAutomaticVariantSelectionProven=false`; uniqueness and live object
identity remain runtime/ViewModel questions.

## Next source target

Before another gameplay build, the remaining high-value question is:

> After `FilterActionResourceCommand(IV preview)`, does the controller
> DCHotBar's `SingleHotBar.SlotList` contain the same level-specific
> `VMHotBarSlot` that the keyboard HotBar executes, or a base slot that enters
> `IsSelectingUpcastedSpell`?

If the former is proved, CAM should execute that exact slot unchanged. If the
latter is proved, a direct-IV shortcut requires an unambiguous **engine-created**
nested slot identity; otherwise the native picker is the correct fail-closed
behavior.

No shipping XAML, Script Extender dependency, spell-cost computation, synthetic
`VMUpcast`, index heuristic or new UIAccept receiver is authorized by this
research.
