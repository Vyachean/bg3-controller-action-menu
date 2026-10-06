#!/usr/bin/env python3
"""Repository-level static validation for the native-derived no-SE package."""

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
BUILD_WORKFLOW = ROOT / ".github/workflows/build.yml"
RELEASE_WORKFLOW = ROOT / ".github/workflows/release.yml"

FORBIDDEN_STATIC_RUNTIME_PATHS = [
    MOD_ROOT / "GUI/Pages/CAM_ActionMenu_c.xaml",
    MOD_ROOT / "GUI/StateMachines/Controller.xaml",
    MOD_ROOT / "GUI/Library/Lib_Controller.xaml",
    MOD_ROOT / "GUI/Library/Lib_Keyboard.xaml",
    MOD_ROOT / "GUI/Library/CAM_ActionRadials.xaml",
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

    # Published source package must not contain either a reconstructed CAM page/template
    # or copied proprietary native XAML. The installer derives the two native files
    # locally from the user's exact installed Game.pak.
    for forbidden_path in FORBIDDEN_STATIC_RUNTIME_PATHS:
        if forbidden_path.exists():
            errors.append(
                f"{forbidden_path.relative_to(ROOT)}: static runtime XAML is forbidden; native radial XAML must be derived locally"
            )

    errors.extend(
        require_text(
            NATIVE_OVERLAY,
            [
                '$LslibVersion = "v1.20.4"',
                '"Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"',
                '"Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"',
                '"Public/Game/GUI/Widgets/HotBar.xaml"',
                '"Game.pak"',
                "New-ControllerLibraryFromNative",
                "Assert-NativeHotbarContract",
                "New-NativeHotbarFilterGrid",
                "Convert-WidgetToHotbarFilterGrid",
                "Disable-RadialCustomizationCommands",
                "Convert-PageStyleToGrid",
                "Hide-RadialBackdrop",
                'CurrentShownDeck',
                'SetCurrentShownDeckCommand',
                'CurrentSingleHotbarFilter',
                'SingleHotBar.SlotList',
                'PassivesHotBar',
                'FilterActionResourceCommand',
                'FilterCantripsCommand',
                'ActionResourcesCostPreview',
                'HighlightResourcesCommand',
                'ClearResourceHighlightsCommand',
                'x:Name="CAM_HotbarFocusRoot"',
                'x:Name="CAM_DeckFilters"',
                'ActionPrevEvent="UITabPrev"',
                'ActionNextEvent="UITabNext"',
                'x:Name="CAM_HotbarGrid"',
                'LocalFocusSelector="{Binding ElementName=CAM_HotbarSelector,Mode=OneWay}"',
                '"CAM_HotbarSelector"',
                'x:Key="CAM_HotbarGridPanel"',
                'Value="{Binding CurrentShownDeck.SlotList}"',
                'Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"',
                'Value="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"',
                'Value="{Binding LocalFocus.DataContext.Content, ElementName=CAM_HotbarGrid}"',
                'Command="{Binding HighlightResourcesCommand}"',
                'Command="{Binding ClearResourceHighlightsCommand}"',
                'x:Name="ShowContextMenu" Visibility="Collapsed" IsEnabled="False" IsHitTestVisible="False" Focusable="False"',
                'Command="{x:Null}"',
                'Mods\\BG3ControllerActionMenu\\GUI\\Library\\Lib_Controller.xaml',
                "--action extract-single-file",
                "--action create-package",
                "-PatchOnlySourceXaml",
                "-PatchOnlyHotbarXaml",
            ],
        )
    )

    if NATIVE_OVERLAY.exists():
        overlay_text = NATIVE_OVERLAY.read_text(encoding="utf-8")
        for forbidden in (
            "Packed controller library is missing required seam",
            "Assert-GridChromeContract",
            "$verifiedText",
            "$verifiedLibrary",
        ):
            if forbidden in overlay_text:
                errors.append(
                    f"{NATIVE_OVERLAY.relative_to(ROOT)}: install-time semantic post-pack verifier is forbidden: {forbidden}"
                )

    if NATIVE_OVERLAY.exists():
        overlay_text = NATIVE_OVERLAY.read_text(encoding="utf-8")
        for rejected_assignment_seam in (
            "PlayerCharacterProperties.SpellsAndActions",
            "Data.TogglablePassivePredicate",
            "Data.TogglableMetaMagicPassivePredicate",
            "CurrentPlayer.SelectedCharacter.Inventory.Slots",
            "CAM_AutoCatalogFocusRoot",
            "CAM_ActionsFocusRoot",
            "CAM_ItemsFocusRoot",
            "CAM_PassivesFocusRoot",
            "CAM_MetamagicFocusRoot",
            "CAM_TabPrevHint",
            "CAM_TabNextHint",
        ):
            if rejected_assignment_seam in overlay_text:
                errors.append(
                    f"{NATIVE_OVERLAY.relative_to(ROOT)}: rejected 0.0.34-0.0.36 assignment execution seam must not return: {rejected_assignment_seam}"
                )


    if NATIVE_OVERLAY.exists():
        overlay_text = NATIVE_OVERLAY.read_text(encoding="utf-8")
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
                "PatchOnlyHotbarXaml",
                "VMHotBarSlot",
                'x:Name="CAM_HotbarFocusRoot"',
                'x:Name="CAM_DeckFilters"',
                'ActionPrevEvent="UITabPrev"',
                'ActionNextEvent="UITabNext"',
                'Command="{Binding SetCurrentShownDeckCommand}"',
                'CommandParameter="CommonHotBar"',
                'CommandParameter="ClassHotBar"',
                'CommandParameter="ItemHotBar"',
                'x:Name="CAM_HotbarGrid"',
                'LocalFocusSelector="{Binding ElementName=CAM_HotbarSelector,Mode=OneWay}"',
                'x:Key="CAM_HotbarGridPanel"',
                'DisableScrolling="False"',
                'Value="{Binding SingleHotBar.SlotList}"',
                'Value="{Binding CurrentShownDeck.SlotList}"',
                'Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"',
                'Command="{Binding HighlightResourcesCommand}"',
                'Command="{Binding ClearResourceHighlightsCommand}"',
                'Value="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"',
                'Value="{Binding LocalFocus.DataContext.Content, ElementName=CAM_HotbarGrid}"',
                'ItemsSource="{Binding SingleHotBar.SlotList}"',
                '<ls:LSListBox x:Name="SingleBar"',
                'Command="{Binding UseSlotCommand}"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                "Rejected assignment/source-tab architecture leaked into generated XAML",
                "Top-level list and selector must share one flat coordinate root.",
                "Generator reflowed native ButtonHintsContainer",
                "Radial ContextMenu/X must be inert, hidden, and have no input binding.",
                "SlotAssignHolder must be inert in hotbar-filter mode.",
                "Native hotbar filter-grid fixture passed",
            ],
        )
    )

    errors.extend(
        require_text(
            XBOX_INSTALLER,
            [
                "[switch]$Apply",
                "[string]$NativeOverlayPath",
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
                "Building a native-derived radial overlay",
                "& $NativeOverlayPath @overlayArgs",
                "BG3ControllerActionMenu-native-derived.pak",
            ],
        )
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
                'native-overlay.ps1',
                "browser_download_url",
                "Save-Asset",
                "& $xboxPath -Apply",
                "install-status.txt",
                "xbox-dev-environment.json",
            ],
        )
    )

    for runtime_installer in (BOOTSTRAP_INSTALLER, LATEST_INSTALLER, NATIVE_OVERLAY):
        if runtime_installer.exists():
            runtime_text = runtime_installer.read_text(encoding="utf-8")
            for forbidden in (
                "Get-FileHash",
                "Assert-AssetDigest",
                "Save-VerifiedReleaseAsset",
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
                "--self-test",
            ],
        )
    )

    errors.extend(
        require_text(
            ONE_CLICK_BUILDER,
            [
                "Install-BG3ControllerActionMenu.vbs",
                "bootstrap-latest.ps1",
                "BG3ControllerActionMenu-OneClickInstaller.zip",
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
                '"tools/native-overlay.ps1"',
                '"tools/bootstrap-latest.ps1"',
                '"tools/install-latest.ps1"',
                '$overlay = "tools/native-overlay.ps1"',
                '$bootstrap = "tools/bootstrap-latest.ps1"',
                '$latestInstaller = "tools/install-latest.ps1"',
                '"release", "create", $env:TAG, $pak, $installer, $oneClick, $overlay, $bootstrap, $latestInstaller',
            ],
        )
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
        "automatic native action-tab contract present; published package contains no proprietary native XAML; "
        "runtime remains Script-Extender-free)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
