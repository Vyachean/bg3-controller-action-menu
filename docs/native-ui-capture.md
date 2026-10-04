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
- `files/.../*.xaml`
- `<capture-directory>.zip`

The manifest records the BG3 package version, scanned PAK count, packaged path, SHA-256 and parsed contract of each extracted XAML.

`native-contract.json` is the machine-readable contract used for implementation review. For every matching native page it records:

- root element/name, `ContextName` and `ls` namespace;
- counts of `ListBox`, `LSListBox`, `ItemsControl`, `PagedList`, `PageView`, `LSGrid`, `Radial`, `LSScrollViewer`, `LSInputBinding` and `LSButton`;
- every `ItemsSource` binding;
- every controller `BoundEvent` together with `Command`, `CommandParameter` and `EatInput`;
- every `ScrollToElement` binding;
- DataContext and other binding-bearing attributes.

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

`tools/test-capture-native-radials.ps1` creates a fake BG3 PAK containing both radial filenames, runs the capture tool against it, verifies both files and hashes, verifies the parsed ItemsSource/UIAccept/UICancel/ScrollToElement contract, and verifies that the source PAK is byte-identical before and after capture.

The Windows build CI must pass that fixture before the capture tool is considered ready for use against a real install.
