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
                '$LslibSha256 = "5e02368fb8acafda9b45acba37a3f3bf507fc3d65a083a159abbeab06337190e"',
                '"Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"',
                '"Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"',
                '"Game.pak"',
                "New-ControllerLibraryFromNative",
                "Convert-PageStyleToGrid",
                "Hide-RadialBackdrop",
                "Convert-WidgetChromeForGrid",
                'x:Key="SlotAssignHolderStyle"',
                'x:Name="AssignList"',
                'LocalFocusSelector="{Binding ElementName=SelectorAssign,Mode=OneWay}"',
                'x:Key="CAM_ActionGridSlotContainer"',
                'x:Key="CAM_ActionGridSlotTemplate"',
                'x:Key="CAM_ActionGridPanel"',
                'KeyboardNavigation.DirectionalNavigation="Contained"',
                'ActionUpEvent="UIUp"',
                'ActionDownEvent="UIDown"',
                'ActionRightEvent="UIRight"',
                'ActionLeftEvent="UILeft"',
                'LocalFocusSelector="{Binding ElementName=$selectorName,Mode=OneWay}"',
                'x:Name="CAM_HotBarRadialFocusRoot"',
                'x:Name="CAM_SingleBarFocusRoot"',
                'HorizontalAlignment="Center"',
                'VerticalAlignment="Center"',
                'Width="640"',
                'Height="400"',
                'x:Name="ButtonHintsContainer"',
                'x:Name="ShowContextMenu"',
                'Tag="Customize"',
                'x:Key="ActionRadialWidgetTemplate_P8"',
                'x:Key="RadialHotBarListItemContainer"',
                'Command="{Binding UseSlotCommand}"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                'Mods\\BG3ControllerActionMenu\\GUI\\Library\\Lib_Controller.xaml',
                "--action extract-single-file",
                "--action create-package",
                "-PatchOnlySourceXaml",
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

    errors.extend(
        require_text(
            NATIVE_OVERLAY_TEST,
            [
                "PatchOnlySourceXaml",
                'x:Key="CAM_ActionGridPanel"',
                '<ls:LSListBox x:Name="HotBarRadial"',
                '<ls:LSListBox x:Name="SingleBar"',
                'LocalFocusSelector="{Binding ElementName=CAM_HotBarRadialSelector,Mode=OneWay}"',
                'LocalFocusSelector="{Binding ElementName=CAM_SingleBarSelector,Mode=OneWay}"',
                'x:Name="UseSlotBinding"',
                'x:Name="CancelButton"',
                'Command="{Binding UseSlotCommand}"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                "Action grid must not execute slot-assignment commands.",
                "Both native radial shadow/backdrop ellipses must be collapsed.",
                "Focus selector and grid list must share the centered focus-root coordinate space",
                "Context-menu hint must remain active and be labeled Customize.",
                "Native assignment-grid focus-origin fixture passed",
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
                "Never silently fall back to an older release",
                'bootstrap-latest.ps1',
                'install-latest.ps1',
                "BootstrapUpdated",
                "Save-VerifiedReleaseAsset",
                "^sha256:([0-9a-fA-F]{64})$",
                "Refusing unexpected release asset URL",
                "Get-FileHash -Algorithm SHA256",
                "& $cachedBootstrap @forward",
                "& $cachedInstaller @installerArgs",
            ],
        )
    )

    errors.extend(
        require_text(
            BOOTSTRAP_TEST,
            [
                "Self-updating installer bootstrap fixture tests passed.",
                "Updated bootstrap was not invoked with -BootstrapUpdated.",
                "Canonical installer was not invoked.",
                "Malformed newest release silently fell back to an older release.",
            ],
        )
    )

    errors.extend(
        require_text(
            LATEST_INSTALLER,
            [
                "releases?per_page=20",
                "Sort-Object { [DateTimeOffset]$_.published_at } -Descending",
                "Never silently fall back to an older release",
                'BG3ControllerActionMenu-$version.pak',
                'install-xbox-dev.ps1',
                'native-overlay.ps1',
                "browser_download_url",
                "^sha256:([0-9a-fA-F]{64})$",
                "Refusing unexpected release asset URL",
                "Save-VerifiedReleaseAsset",
                "NativeOverlayPath $overlayPath",
                "install-status.txt",
                "xbox-dev-environment.json",
            ],
        )
    )

    errors.extend(
        require_text(
            ONE_CLICK_LAUNCHER,
            [
                "bootstrap-latest.ps1",
                "Checking for installer updates and installing the newest release",
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

    launcher_text = ONE_CLICK_LAUNCHER.read_text(encoding="utf-8") if ONE_CLICK_LAUNCHER.exists() else ""
    builder_text = ONE_CLICK_BUILDER.read_text(encoding="utf-8") if ONE_CLICK_BUILDER.exists() else ""
    for path, text_value in ((ONE_CLICK_LAUNCHER, launcher_text), (ONE_CLICK_BUILDER, builder_text)):
        if "install-latest.ps1" in text_value:
            errors.append(
                f"{path.relative_to(ROOT)}: reusable one-click bundle must not pin install-latest.ps1"
            )

    for workflow in (BUILD_WORKFLOW, RELEASE_WORKFLOW):
        errors.extend(
            require_text(
                workflow,
                [
                    "Test self-updating bootstrap",
                    "test-bootstrap-latest.ps1",
                    "Test native slot-assignment grid presentation",
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
        "native-derived centered slot-assignment grid contract present; published package contains no proprietary native XAML; "
        "runtime remains Script-Extender-free)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
