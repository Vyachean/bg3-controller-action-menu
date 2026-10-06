# Self-contained runtime migration

## Goal

Move the proven controller-grid behavior out of install-time derivation and into project-owned runtime resources that are packaged by CI.

Normal installation must receive one already-built PAK. It must not inspect `Game.pak`, download LSLib, generate XAML, or repack CAM.

## Evidence flow

The development-only flow is:

```text
Capture-BG3ControllerArtifacts.vbs
  -> bg3-controller-action-menu-inputs-*.zip
  -> prepare-self-contained-reference.ps1
  -> build/self-contained-reference/
       evidence.json
       Lib_Controller.reference.xaml
  -> author/review project-owned runtime XAML
  -> CI/package verification
```

The capture and generated reference are **development evidence**. Raw captured game XAML and the generated reference are not copied verbatim into release source.

## Exact evidence required

The migration tool fails closed unless the capture contains:

- `Public/Game/GUI/Library/PreloadedActionRadials_c.xaml`;
- `Mods/MainUI/GUI/Pages/HotBar.xaml`.

The broader capture also collects current ActionRadials, DataTemplates and controller/library XAML so structural dependencies can be checked without another operator run.

The reference preparation records:

- game package version;
- source packaged paths and SHA-256 hashes;
- current cantrip filter parameter when present;
- SHA-256 of the development reference library.

## Release boundary

`tools/assert-self-contained-release.ps1` blocks publication until:

- project-owned `Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml` exists;
- normal installers contain no game-PAK/local-build seams;
- the project-owned XAML parses.

Package verification then requires the same library to be embedded in the PAK.

This intentionally allows the migration branch to run CI while preventing an incomplete metadata-only PAK from being published as a new release.
