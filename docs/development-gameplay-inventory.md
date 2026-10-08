# Read-only runtime gameplay inventory — development-only

This is **not** part of CAM's normal Xbox App/PC installation and **not**
a dependency of the shipping PAK.

## Why the previous proof is insufficient

The shipping UI command audit enumerates 36 native keyboard/controller
`ICommand` names. The strict `tools/compare-runtime-gameplay.py` expects
a complete *runtime* comparison of playable BG3 identities across native
keyboard/radial and CAM. Neither can prove the live action membership of
multiclass characters, equipped items, upcasts, passive/metamagic toggles,
temporary/recast actions or other mods from static XAML.

The older, optional development module `RadialProbe.lua` previews only
the first **10** elements of a native collection. That is inherently
insufficient for a large BG3 action catalog and must never be passed to
`compare-runtime-gameplay.py` as a complete observation.

## New optional probe

`dev/script-extender/Lua/Client/GameplayInventoryProbe.lua` uses the
existing *development-only* `Ext.UI.GetRoot()` Noesis interface and
inspects the native `ActionRadials` page, its `DCHotBar` context
and BG3-owned collections:

- `KeyboardHotBars[*].SlotList`
- `ControllerHotBars[*].SlotList` (the preserved original radial layouts)
- `PassivesHotBar.SlotList`, `FixedSideBar.SlotList`
- `SpellsAndActions[*].Actions`
- `Inventory.Slots`, `Stats.Passives`
- `CurrentShownDeck.SlotList`, `SingleHotBar.SlotList`
- CAM's currently rendered `HotBarList`, `CAM_FixedSideBarList`,
  `CAM_ResourceTabs`, native `LocalFocus` and `ActionRadials.Tag`

It records full available collection counts, explicitly detected
indexing bases (0- or 1-based), observed item indices, source type,
known potential identity fields, content, current CAM provider mode,
nested/upcast/throw flags, errors and **completeness reasons**.

To limit runtime overhead, at most 8 snapshots are emitted, with
at most 512 entries per collection and 2600 items per snapshot.
Truncation, inaccessible properties and missing collections remain
visible in the report. The auto observer does not consume or remap
controller input and records only while `ActionRadials` is present.
The dev console command `!cam_gameplay_inventory` allows a manual
snapshot when the runtime supports it.

Output is via `Ext.IO.SaveFile` to
`BG3ControllerActionMenu/gameplay-inventory-raw.json` under the
development Script Extender output location. It does **not** modify
the game, characters, input bindings, saves, native PAKs or the CAM
shipping package.

**Important:** this uses the old Script Extender Noesis API as a
source-backed development hypothesis. Xbox App/Windows runtime
compatibility and actual data availability have **not** yet been
confirmed. Do not require end users to install it. The normal
one-click installer never invokes, installs or depends on this probe.
Only if a separate developer environment already supports this API
can it supply the data. No repeated game tests or operator action
are requested in this stage.

## Analysis

The source-only fixture run:

```shell
python tools/analyze-gameplay-inventory.py --self-test
```

Analyze one real raw report, when available:

```shell
python tools/analyze-gameplay-inventory.py --report gameplay-inventory-raw.json --json
```

This analyzer tests active CAM provider/source **counts**, native
`LocalFocus` presence and whether all expected sources are available
without truncation. It intentionally returns
`realExecutableIdentityParityProven: false`. Different game VM types
may share a name, icon or `SpellId`, and different upcast/resources
may share a spell identifier; these are not equivalent gameplay
identities. Source-count equality does not establish full action parity.

**Do not feed this raw file directly to**
`tools/compare-runtime-gameplay.py --observation`. The latter
requires a versioned, *complete*, BG3-source-proven action identity
adapter spanning raw radial candidates and executable `VMHotBarSlot`
with resource-aware variant IDs. That adapter is an explicit future
implementation task, not something to fabricate from names.

## Gate

- Source-only CI verifies the analyzer's negative fixtures and
  the dev probe's bounded, read-only contract.
- No new gameplay keys, utility buttons or action dispatch are wired.
- The old `0.0.51–0.0.54` weapon switching failures remain rejected.
- #134 and #135 remain **unresolved** until native runtime identities
  can be compared and all missing gameplay capabilities are restored
  or genuinely preserved by BG3 global input.
