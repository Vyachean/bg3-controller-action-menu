# Current native radial capture

## Purpose

Before another in-game candidate is requested, capture the controller radial XAML from the **installed current BG3 build**.

This replaces speculative runtime iteration with direct evidence.

The tool searches only for files matching:

`*ActionRadials*.xaml`

That should include the source/state-facing `ActionRadials.xaml` and the current runtime/preloaded `PreloadedActionRadials_c.xaml` when present.

## Safety

`tools/capture-native-radials.ps1` is read-only with respect to BG3.

It:

- detects the installed Xbox/App package unless `-GameInstallRoot` is supplied;
- scans existing game PAKs;
- extracts matching XAML into a separate output directory;
- writes a manifest, a compact summary and a ZIP next to that output.

It does **not**:

- modify game PAKs;
- modify `modsettings.lsx`;
- modify saves or profiles;
- install or enable a mod;
- launch BG3.

The bundled LSLib acquisition is pinned to v1.20.4 and its release ZIP SHA-256 is verified before extraction.

## Output

A successful capture produces:

- `capture-manifest.json`
- `capture-summary.txt`
- `native-contract.json`
- `native-contract-analysis.json`
- `native-contract-analysis.txt`
- `files/.../*.xaml`
- `<capture-directory>.zip`

The manifest records the BG3 package version, every scanned PAK (path, size, timestamp, match count/error), packaged path, SHA-256 and parsed contract of each extracted XAML. If the same radial path exists in both a base and patch PAK, **all copies are preserved and reported separately** instead of silently choosing one.

`native-contract.json` is the machine-readable contract used for implementation review. For every matching native page it records:

- root element/name, `ContextName` and `ls` namespace;
- counts of `ListBox`, `LSListBox`, `ItemsControl`, `PagedList`, `PageView`, `LSGrid`, `Radial`, `LSScrollViewer`, `LSInputBinding` and `LSButton`;
- every `ItemsSource` binding;
- every controller `BoundEvent` together with `Command`, `CommandParameter` and `EatInput`;
- every `ScrollToElement` binding;
- DataContext and other binding-bearing attributes.

The capture also analyzes the contract automatically. `native-contract-analysis.json` and its readable `.txt` companion report:

- candidate main controller collection bindings;
- per-bar `SlotList` bindings separately as slot-materialization evidence, so they cannot be mistaken for competing root controller collections;
- `KeyboardHotBars` bindings separately, explicitly marked as invalid controller substitutes;
- nested `SingleHotBar` / variant-state evidence;
- all `UIAccept` and `UICancel` command paths;
- focus/`ScrollToElement` bindings;
- per-file list/paging/grid/radial materialization counts;
- conflicting copies of the same packaged radial path;
- a fail-closed implementation gate with explicit blockers.

The gate does not claim the mod works in-game. It only answers whether the captured native evidence is internally complete and unambiguous enough to rebuild the next candidate without guessing.

The text summary renders the important parts of that structured contract and also selects source lines relevant to:

- `ContextName`
- `ItemsSource`
- `HotBars`
- `SlotList`
- `SingleHotBar`
- `PagedList` / `PageView`
- `ScrollToElement`
- `UIAccept` / `UICancel`
- `UseSlotCommand`
- `ClearSingleHotbarCommand`
- `CustomEvent` / `CloseRequestCommand`

## Development fixture

`tools/test-capture-native-radials.ps1` creates a fake BG3 PAK containing both radial filenames, runs the capture tool against it, verifies both files and hashes, and verifies the parsed ItemsSource/UIAccept/UICancel/ScrollToElement contract. The fixture deliberately nests a per-bar `SlotList` under the root hotbar collection and proves that the analyzer records it as materialization rather than a second controller source. It also verifies keyboard-only source classification, fail-closed ambiguity handling, and that the source PAK is byte-identical before and after capture.

The Windows build CI must pass that fixture before the capture tool is considered ready for use against a real install. The fixture also simulates a patched game by placing a second `ActionRadials.xaml` at the same packaged path in a patch PAK; the report must retain both copies and flag the duplicate path.
