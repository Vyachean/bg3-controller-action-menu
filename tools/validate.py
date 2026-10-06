#!/usr/bin/env python3
"""Repository-level static validation for the self-contained no-SE package."""

from __future__ import annotations

import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "BG3ControllerActionMenu"
MOD_ROOT = PACKAGE_ROOT / "Mods/BG3ControllerActionMenu"
VERSION = ROOT / "VERSION"

XBOX_INSTALLER = ROOT / "tools/install-xbox-dev.ps1"
BOOTSTRAP_INSTALLER = ROOT / "tools/bootstrap-latest.ps1"
BOOTSTRAP_TEST = ROOT / "tools/test-bootstrap-latest.ps1"
LATEST_INSTALLER = ROOT / "tools/install-latest.ps1"
ONE_CLICK_LAUNCHER = ROOT / "tools/Install-BG3ControllerActionMenu.vbs"
ONE_CLICK_BUILDER = ROOT / "tools/build-one-click-installer.ps1"
NATIVE_OVERLAY = ROOT / "tools/native-overlay.ps1"
NATIVE_OVERLAY_TEST = ROOT / "tools/test-native-overlay.ps1"
NATIVE_CAPTURE = ROOT / "tools/capture-native-radials.ps1"
DEV_CAPTURE = ROOT / "tools/capture-self-contained-inputs.ps1"
DEV_CAPTURE_LAUNCHER = ROOT / "tools/Capture-BG3ControllerArtifacts.vbs"
DEV_CAPTURE_TEST = ROOT / "tools/test-dev-capture.ps1"
DEV_CAPTURE_BUILDER = ROOT / "tools/build-dev-capture.ps1"
DEVELOPMENT_VBS_DOC = ROOT / "docs/development-vbs.md"
BUILD_WORKFLOW = ROOT / ".github/workflows/build.yml"
RELEASE_WORKFLOW = ROOT / ".github/workflows/release.yml"

FORBIDDEN_STATIC_RUNTIME_PATHS = [
    # Never publish copied game-owned resource paths. Self-contained CAM runtime
    # resources must live under Mods/BG3ControllerActionMenu.
    PACKAGE_ROOT / "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml",
    PACKAGE_ROOT / "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml",
]

IGNORED_DIRS = {".git", ".local", "build", "dist", "artifacts", "extracted", "game-data", "toolkit-data"}
XML_SUFFIXES = {".xaml", ".xml", ".lsx"}


def iter_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRS for part in path.relative_to(ROOT).parts):
            continue
        yield path


def validate_xml(path: Path) -> list[str]:
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        return [f"{path.relative_to(ROOT)}: XML parse error: {exc}"]
    return []


def require_text(path: Path, required: list[str]) -> list[str]:
    if not path.exists():
        return [f"{path.relative_to(ROOT)}: required file is missing"]

    text = path.read_text(encoding="utf-8")
    return [
        f"{path.relative_to(ROOT)}: missing required integration seam: {needle}"
        for needle in required
        if needle not in text
    ]


def validate_semantics() -> list[str]:
    errors: list[str] = []

    if not (MOD_ROOT / "meta.lsx").exists():
        errors.append("BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/meta.lsx: required file is missing")

    script_extender = MOD_ROOT / "ScriptExtender"
    if script_extender.exists():
        errors.append(
            f"{script_extender.relative_to(ROOT)}: runtime package must not contain Script Extender files"
        )

    # Raw copied game resources are forbidden. Project-owned self-contained
    # runtime XAML belongs under Mods/BG3ControllerActionMenu and is expected
    # once the migration is completed.
    for forbidden_path in FORBIDDEN_STATIC_RUNTIME_PATHS:
        if forbidden_path.exists():
            errors.append(
                f"{forbidden_path.relative_to(ROOT)}: copied game-owned runtime XAML path is forbidden"
            )

    errors.extend(
        require_text(
            NATIVE_OVERLAY,
            [
                '$LslibVersion = "v1.20.4"',
                '"Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"',
                '"Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"',
                '$KeyboardHotBarPath = "Mods/MainUI/GUI/Pages/HotBar.xaml"',
                '"Game.pak"',
                "New-ControllerLibraryFromNative",
                "New-AutomaticActionCatalog",
                "Get-CurrentCantripFilterParameter",
                "Convert-NativeRadialFocusTriggerForGrid",
                "Preserve-MainSurfaceForHotBarFilters",
                "Disable-RadialCustomizationCommands",
                "Convert-WidgetToAutomaticCatalog",
                "Convert-PageStyleToGrid",
                "Hide-RadialBackdrop",
                "CurrentPlayer.UIData.ActionResourcesCostPreview",
                "FilterActionResourceCommand",
                "FilterCantripsCommand",
                "SetCurrentShownDeckCommand",
                "ClearSingleHotbarCommand",
                "CurrentShownDeck.SlotList",
                "CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList",
                'Value="{Binding SingleHotBar.SlotList}"',
                'Condition Binding="{Binding IsShowingAContainerWithVariants}" Value="False"',
                'Condition Binding="{Binding IsSelectingUpcastedSpell}" Value="False"',
                'Setter TargetName="CancelButton" Property="Command" Value="{Binding CustomEvent}"',
                'x:Name="CAM_AutoCatalogFocusRoot"',
                'x:Name="CAM_FilterTabs"',
                'ActionPrevEvent="UITabPrev"',
                'ActionNextEvent="UITabNext"',
                'x:Name="CAM_CommonFilterTab"',
                'x:Name="CAM_ClassFilterTab"',
                'x:Name="CAM_ItemsFilterTab"',
                'x:Name="CAM_PassivesFilterTab"',
                'x:Name="CAM_CantripsFilterTab"',
                'x:Name="CAM_ResourceFilterList"',
                'x:Name="CAM_FilteredSlotList"',
                'KeyboardNavigation.DirectionalNavigation="Continue"',
                'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
                'Property="Tag" Value="{Binding .}"',
                'x:Key="CAM_ActionGridPanel"',
                'x:Key="CAM_ResourceFilterContainer"',
                'x:Key="CAM_ResourceFilterPanel"',
                'x:Name="ShowContextMenu" Visibility="Collapsed" IsEnabled="False" IsHitTestVisible="False" Focusable="False"',
                'Command="{x:Null}"',
                'Mods\\BG3ControllerActionMenu\\GUI\\Library\\Lib_Controller.xaml',
                "--action extract-single-file",
                "--packaged-path $KeyboardHotBarPath",
                "--action create-package",
                "-PatchOnlySourceXaml",
                "-PatchOnlyHotBarSourceXaml",
            ],
        )
    )

    if NATIVE_OVERLAY.exists():
        overlay_text = NATIVE_OVERLAY.read_text(encoding="utf-8")

        for forbidden in (
            "Packed controller library is missing required seam",
            "Assert-GridChromeContract",
            "Assert-CurrentHotBarFilterContract",
            "missing required filter seam",
            "$verifiedText",
            "$verifiedLibrary",
        ):
            if forbidden in overlay_text:
                errors.append(
                    f"{NATIVE_OVERLAY.relative_to(ROOT)}: install-time semantic post-pack verifier is forbidden: {forbidden}"
                )

        # 0.0.35/0.0.36 proved that source tabs and assignment-catalog objects
        # are not a valid gameplay-dispatch architecture.
        for obsolete_main_seam in (
            "CAM_AutoCatalogSelector",
            "CAM_ActionsFocusRoot",
            "CAM_ItemsFocusRoot",
            "CAM_PassivesFocusRoot",
            "CAM_MetamagicFocusRoot",
            "CAM_TabPrevHint",
            "CAM_TabNextHint",
            "PlayerCharacterProperties.SpellsAndActions",
            "CurrentPlayer.SelectedCharacter.Inventory.Slots",
            "CurrentPlayer.SelectedCharacter.Stats.Passives",
            'Height="376"',
        ):
            if obsolete_main_seam in overlay_text:
                errors.append(
                    f"{NATIVE_OVERLAY.relative_to(ROOT)}: obsolete 0.0.35/0.0.36 main-grid seam must not return: {obsolete_main_seam}"
                )

        for unproven_predicate in (
            "CantripGroupPredicate",
            "SpellLevelsGroupPredicate",
            "AllActionsGroupPredicate",
        ):
            if unproven_predicate in overlay_text:
                errors.append(
                    f"{NATIVE_OVERLAY.relative_to(ROOT)}: historical SpellBook predicate must not enter shipping XAML without current Patch 8 proof: {unproven_predicate}"
                )

    errors.extend(
        require_text(
            NATIVE_OVERLAY_TEST,
            [
                "PatchOnlySourceXaml",
                "PatchOnlyHotBarSourceXaml",
                "gameplay candidates are VMHotBarSlot collections",
                'CurrentPlayer.UIData.ActionResourcesCostPreview',
                'x:Name="CAM_FilterTabs"',
                'ActionPrevEvent="UITabPrev"',
                'ActionNextEvent="UITabNext"',
                'x:Name="CAM_ResourceFilterList"',
                'Command="{Binding FilterActionResourceCommand}"',
                'x:Name="CAM_FilteredSlotList"',
                'Value="{Binding CurrentShownDeck.SlotList}"',
                'Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"',
                'Value="{Binding SingleHotBar.SlotList}"',
                'Command="{Binding FilterCantripsCommand}" CommandParameter="hfixturecantrips"',
                'Setter TargetName="singleBarHolder" Property="Visibility" Value="Collapsed"',
                'Setter TargetName="MainHotbarListHolder" Property="Visibility" Value="Visible"',
                'Setter TargetName="CancelButton" Property="Command" Value="{Binding CustomEvent}"',
                'KeyboardNavigation.DirectionalNavigation="Continue"',
                'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
                "Main selector did not preserve current native SelectorAssign geometry/binding.",
                'Value="{Binding LocalFocus.Tag, ElementName=CAM_FilteredSlotList}"',
                "CreateFocusedTooltipDataCommand",
                "HighlightResourcesCommand",
                "Main action grid must not keep the old fixed three-row height.",
                "Installed native ButtonHintsContainer layout was not preserved exactly.",
                "0.0.36 duplicate tab-hint chrome must not return.",
                'ItemsSource="{Binding SingleHotBar.SlotList}"',
                '<ls:LSListBox x:Name="SingleBar"',
                'Command="{Binding UseSlotCommand}"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                "Radial ContextMenu/X must be inert, hidden, and have no input binding.",
                "Native hotbar-filter grid fixture passed",
            ],
        )
    )

    errors.extend(
        require_text(
            XBOX_INSTALLER,
            [
                "[switch]$Apply",
                "Get-AppxPackage",
                "LocalCache\\Local",
                "ExistingPakFound",
                "ReusableModSettingsSchemaFound",
                "WriteSchemaReady",
                "SelectedModSettings",
                "PlayerProfiles",
                "ReadyForApply",
                "Refusing to modify Xbox data",
                "BG3ControllerActionMenu-backups",
                "The release PAK is self-contained",
                "Copy-Item -LiteralPath $PackagePath -Destination $destPak -Force",
            ],
        )
    )

    if XBOX_INSTALLER.exists():
        xbox_text = XBOX_INSTALLER.read_text(encoding="utf-8")
        for forbidden in (
            "NativeOverlayPath",
            "native-overlay.ps1",
            "Game.pak",
            "divine.exe",
            "--action extract-single-file",
            "--action create-package",
            "BG3ControllerActionMenu-native-derived.pak",
        ):
            if forbidden in xbox_text:
                errors.append(
                    f"{XBOX_INSTALLER.relative_to(ROOT)}: normal installer must install the self-contained PAK directly: {forbidden}"
                )

    errors.extend(
        require_text(
            BOOTSTRAP_INSTALLER,
            [
                "releases?per_page=20",
                'install-latest.ps1',
                "Invoke-RestMethod",
                "Invoke-WebRequest",
                "& $installer @installerArgs",
                '$PortableStateRoot = Join-Path $ScriptRoot "installer-work"',
                'CacheRoot = Join-Path (Split-Path -Parent $CacheRoot) "release-cache"',
            ],
        )
    )

    errors.extend(
        require_text(
            BOOTSTRAP_TEST,
            [
                "Minimal latest-installer bootstrap fixture passed.",
                "Downloaded latest installer was not executed.",
            ],
        )
    )

    errors.extend(
        require_text(
            LATEST_INSTALLER,
            [
                "releases?per_page=20",
                "Sort-Object { [DateTimeOffset]$_.published_at } -Descending",
                'BG3ControllerActionMenu-$version.pak',
                'install-xbox-dev.ps1',
                "browser_download_url",
                "Save-Asset",
                "& $xboxPath -Apply -PackagePath $pakPath -ReportPath $ReportPath",
                "install-status.txt",
                "xbox-dev-environment.json",
            ],
        )
    )

    if LATEST_INSTALLER.exists():
        latest_text = LATEST_INSTALLER.read_text(encoding="utf-8")
        for forbidden in (
            "native-overlay.ps1",
            "NativeOverlayPath",
            "Game.pak",
            "divine.exe",
            "--action extract-single-file",
            "--action create-package",
        ):
            if forbidden in latest_text:
                errors.append(
                    f"{LATEST_INSTALLER.relative_to(ROOT)}: canonical installer must not rebuild the release PAK: {forbidden}"
                )

    for runtime_installer in (BOOTSTRAP_INSTALLER, LATEST_INSTALLER):
        if runtime_installer.exists():
            runtime_text = runtime_installer.read_text(encoding="utf-8")
            for forbidden in (
                "Get-FileHash",
                "Assert-AssetDigest",
                "Save-VerifiedReleaseAsset",
                "Assert-CurrentHotBarFilterContract",
                "missing required filter seam",
                "Packed controller library is missing required seam",
                "Generated controller library is missing required seam",
            ):
                if forbidden in runtime_text:
                    errors.append(
                        f"{runtime_installer.relative_to(ROOT)}: install-time validation is forbidden: {forbidden}"
                    )

    errors.extend(
        require_text(
            ONE_CLICK_LAUNCHER,
            [
                "bootstrap-latest.ps1",
                "Installing the newest BG3 Controller Action Menu release",
                "shell.Run(command, 0, True)",
                "install-latest.log",
                "install-status.txt",
                "Installation completed.",
                'stateRoot = fso.BuildPath(baseDir, "installer-work")',
                '" -CacheRoot "',
                "--self-test",
            ],
        )
    )

    errors.extend(
        require_text(
            DEVELOPMENT_VBS_DOC,
            [
                "temporary development delivery tool",
                "no manual replacement or update of the VBS is required",
                "A change that would require the tester to download a newer VBS manually is an installer architecture regression.",
                "official delivery path",
                "development helper scripts",
            ],
        )
    )

    if ONE_CLICK_LAUNCHER.exists():
        launcher_text = ONE_CLICK_LAUNCHER.read_text(encoding="utf-8")
        for forbidden in (
            "native-overlay.ps1",
            "Game.pak",
            "divine.exe",
            "BG3ControllerActionMenu-0.",
        ):
            if forbidden in launcher_text:
                errors.append(
                    f"{ONE_CLICK_LAUNCHER.relative_to(ROOT)}: stable development VBS must not contain version/build-specific behavior: {forbidden}"
                )

    errors.extend(
        require_text(
            ONE_CLICK_BUILDER,
            [
                "Install-BG3ControllerActionMenu.vbs",
                "bootstrap-latest.ps1",
                "BG3ControllerActionMenu-OneClickInstaller.zip",
                "installer-work",
                "Compress-Archive",
            ],
        )
    )

    builder_text = ONE_CLICK_BUILDER.read_text(encoding="utf-8") if ONE_CLICK_BUILDER.exists() else ""
    if 'Copy-Item -LiteralPath $latestInstaller' in builder_text or 'Join-Path $Stage "install-latest.ps1"' in builder_text:
        errors.append(
            f"{ONE_CLICK_BUILDER.relative_to(ROOT)}: reusable one-click ZIP must not embed install-latest.ps1"
        )

    for workflow in (BUILD_WORKFLOW, RELEASE_WORKFLOW):
        errors.extend(
            require_text(
                workflow,
                [
                    "Test minimal installer bootstrap",
                    "test-bootstrap-latest.ps1",
                    "Test native hotbar filter grid",
                    "test-native-overlay.ps1",
                ],
            )
        )

    errors.extend(
        require_text(
            RELEASE_WORKFLOW,
            [
                '"tools/bootstrap-latest.ps1"',
                '"tools/install-latest.ps1"',
                '$bootstrap = "tools/bootstrap-latest.ps1"',
                '$latestInstaller = "tools/install-latest.ps1"',
                '"release", "create", $env:TAG, $pak, $installer, $oneClick, $bootstrap, $latestInstaller',
                '$deadline = (Get-Date).ToUniversalTime().AddMinutes(5)',
                '$delaySeconds = [Math]::Min(15, $delaySeconds * 2)',
                'within the five-minute publication propagation window',
            ],
        )
    )

    if RELEASE_WORKFLOW.exists():
        release_text = RELEASE_WORKFLOW.read_text(encoding="utf-8")
        if '"native-overlay.ps1"' in release_text or '$overlay = "tools/native-overlay.ps1"' in release_text:
            errors.append(
                f"{RELEASE_WORKFLOW.relative_to(ROOT)}: native overlay builder must not be a normal release/install asset"
            )

    errors.extend(
        require_text(
            NATIVE_CAPTURE,
            [
                'Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3"',
                '$LslibVersion = "v1.20.4"',
                '$TargetExpression = "*ActionRadials*.xaml"',
                "--action extract-single-file",
                "native-contract-analysis.json",
                "ImplementationGate",
                "No game, profile or mod files were modified.",
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE,
            [
                '$PortableRoot = Split-Path -Parent $MyInvocation.MyCommand.Path',
                '$WorkRoot = Join-Path $PortableRoot "capture-work"',
                '*PreloadedActionRadials*.xaml',
                '*ActionRadials*.xaml',
                '*HotBar*.xaml',
                '*DataTemplates.xaml',
                '*Controller.xaml',
                '*Lib_Controller.xaml',
                'bg3-controller-action-menu-inputs-$stamp',
                'No BG3 files, saves, profiles, or mods were modified.',
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE_LAUNCHER,
            [
                'capture-self-contained-inputs.ps1',
                'capture.log',
                'capture-status.txt',
                'Upload this ZIP to the development chat.',
                '--self-test',
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE_TEST,
            [
                'Portable developer capture fixture passed.',
                '%LOCALAPPDATA%',
                'No BG3 files, saves, profiles, or mods were modified.',
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE_BUILDER,
            [
                'Capture-BG3ControllerArtifacts.vbs',
                'capture-self-contained-inputs.ps1',
                'BG3ControllerActionMenu-DevCapture.zip',
                'Compress-Archive',
            ],
        )
    )

    for portable_path in (ONE_CLICK_LAUNCHER, BOOTSTRAP_INSTALLER, LATEST_INSTALLER, DEV_CAPTURE, DEV_CAPTURE_LAUNCHER):
        if portable_path.exists() and "%LOCALAPPDATA%" in portable_path.read_text(encoding="utf-8"):
            errors.append(
                f"{portable_path.relative_to(ROOT)}: portable launcher path must not use %LOCALAPPDATA%"
            )

    if not VERSION.exists():
        errors.append("VERSION: required file is missing")
    else:
        version = VERSION.read_text(encoding="utf-8").strip()
        if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
            errors.append(f"VERSION: invalid SemVer-like value: {version!r}")

    return errors


def main() -> int:
    errors: list[str] = []
    checked_xml = 0

    for path in iter_files():
        if path.suffix.lower() in XML_SUFFIXES:
            checked_xml += 1
            errors.extend(validate_xml(path))

    errors.extend(validate_semantics())

    if errors:
        print("Static validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"Static validation passed ({checked_xml} XML/XAML/LSX files checked; "
        "development hotbar/controller contract fixtures present; normal installer is direct/self-contained; "
        "runtime remains Script-Extender-free)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
