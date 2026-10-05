#!/usr/bin/env python3
"""Repository-level static validation for the no-Script-Extender runtime package."""

from __future__ import annotations

import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "BG3ControllerActionMenu"
MOD_ROOT = PACKAGE_ROOT / "Mods/BG3ControllerActionMenu"
CONTROLLER_LIBRARY = MOD_ROOT / "GUI/Library/Lib_Controller.xaml"
KEYBOARD_LIBRARY = MOD_ROOT / "GUI/Library/Lib_Keyboard.xaml"
ACTION_TEMPLATE = MOD_ROOT / "GUI/Library/CAM_ActionRadials.xaml"
LEGACY_ACTION_PAGE = MOD_ROOT / "GUI/Pages/CAM_ActionMenu_c.xaml"
LEGACY_CONTROLLER_STATE = MOD_ROOT / "GUI/StateMachines/Controller.xaml"
VERSION = ROOT / "VERSION"
XBOX_INSTALLER = ROOT / "tools/install-xbox-dev.ps1"
LATEST_INSTALLER = ROOT / "tools/install-latest.ps1"
ONE_CLICK_LAUNCHER = ROOT / "tools/Install-BG3ControllerActionMenu.vbs"
ONE_CLICK_BUILDER = ROOT / "tools/build-one-click-installer.ps1"
RELEASE_WORKFLOW = ROOT / ".github/workflows/release.yml"
NATIVE_CAPTURE = ROOT / "tools/capture-native-radials.ps1"

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

    errors.extend(
        require_text(
            CONTROLLER_LIBRARY,
            [
                "ResourceDictionary",
                "CAM_ActionRadials.xaml",
            ],
        )
    )

    errors.extend(
        require_text(
            KEYBOARD_LIBRARY,
            [
                "ResourceDictionary",
                "CAM is controller-only",
            ],
        )
    )

    errors.extend(
        require_text(
            ACTION_TEMPLATE,
            [
                'x:Key="ActionRadialWidgetTemplate_P8"',
                'x:Name="CAM_DiagnosticPanel"',
                "native ActionRadials page + Lib_Controller template override",
                "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars",
                'ItemsSource="{Binding SlotList}"',
                'ItemsSource="{Binding SingleHotBar.SlotList}"',
                'x:Key="CAM_SlotContainer"',
                'TargetType="{x:Type ListBoxItem}"',
                'ItemContainerStyle="{StaticResource CAM_SlotContainer}"',
                'ItemsPanel="{StaticResource CAM_NativeGrid}"',
                'ActionUpEvent="UIUp"',
                'ActionDownEvent="UIDown"',
                'ActionLeftEvent="UILeft"',
                'ActionRightEvent="UIRight"',
                'TargetName="ActionRadials"',
                'PropertyName="Tag"',
                'Value="{Binding LocalFocus.DataContext, ElementName=SectionSlots}"',
                'TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1"',
                'TargetName="HotBarList"',
                'FocusElement="{Binding ElementName=HotBarList, Path=Tag}"',
                '<ls:LSButton x:Name="UseSlotBinding"',
                'Command="{Binding UseSlotCommand}"',
                'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
                'BoundEvent="UIAccept"',
                '<ls:LSButton x:Name="CancelButton"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                'Property="CommandParameter" Value="CloseWidget"',
                'ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"',
                'x:Name="NativeSlotButton"',
                'Command="{x:Null}"',
                'EatInput="False"',
                'BoundEvent="UICancel"',
                'Background="Transparent"',
            ],
        )
    )

    script_extender = MOD_ROOT / "ScriptExtender"
    if script_extender.exists():
        errors.append(
            f"{script_extender.relative_to(ROOT)}: runtime package must not contain Script Extender files"
        )

    # Runtime ownership must stay with the base game. Reintroducing either file
    # recreates the dead-input architecture proven by 0.0.18-0.0.20.
    for legacy in (LEGACY_ACTION_PAGE, LEGACY_CONTROLLER_STATE):
        if legacy.exists():
            errors.append(
                f"{legacy.relative_to(ROOT)}: native ActionRadials state/page must not be overridden"
            )

    if ACTION_TEMPLATE.exists():
        template_text = ACTION_TEMPLATE.read_text(encoding="utf-8")
        forbidden = [
            "opaqueBG.png",
            'Background="{DynamicResource LS_tint00}"',
            "CurrentPlayer.SelectedCharacter.HotBars",
            'Command="ls:UIWidget.CloseRequestCommand"',
            'x:Name="CancelNestedButton"',
            '<ls:LSInputBinding x:Name="UseSlotBinding"',
            '<ls:LSInputBinding x:Name="CancelBinding"',
            'UseWidgetNavigation="True"',
            'WidgetChainedNavigation="True"',
            'ls:MoveFocus.InternalFocusable="True"',
            'AlwaysSelectFirst="True"',
            'ls:MoveFocus.IsMoveFocusScope="True"',
            'ElementName=CAM_ActionMenu',
        ]
        for needle in forbidden:
            if needle in template_text:
                errors.append(
                    f"{ACTION_TEMPLATE.relative_to(ROOT)}: controller template safety regression: {needle}"
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
                "Get-ChildItem -LiteralPath $root",
                "Get-XmlShapeSummary",
                "ShapeSummary",
                "ModsOnly",
                "PlayerProfiles",
                "ValidProfileModSettingsFound",
                "PublishHandle",
                "ReadyForApply",
                "Refusing to modify Xbox data",
                "BG3ControllerActionMenu-backups",
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
                "browser_download_url",
                "^sha256:([0-9a-fA-F]{64})$",
                "Refusing unexpected release asset URL",
                "Save-VerifiedReleaseAsset",
                "& $installerPath -Apply -PackagePath $pakPath",
                "install-status.txt",
                "xbox-dev-environment.json",
            ],
        )
    )

    errors.extend(
        require_text(
            ONE_CLICK_LAUNCHER,
            [
                "install-latest.ps1",
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
                "install-latest.ps1",
                "BG3ControllerActionMenu-OneClickInstaller.zip",
                "Compress-Archive",
            ],
        )
    )

    errors.extend(
        require_text(
            RELEASE_WORKFLOW,
            [
                "Test hidden one-click installer",
                "build-one-click-installer.ps1",
                "BG3ControllerActionMenu-OneClickInstaller.zip",
            ],
        )
    )

    errors.extend(
        require_text(
            NATIVE_CAPTURE,
            [
                'Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3"',
                '$LslibVersion = "v1.20.4"',
                '$LslibSha256 = "5e02368fb8acafda9b45acba37a3f3bf507fc3d65a083a159abbeab06337190e"',
                '$TargetExpression = "*ActionRadials*.xaml"',
                "--action list-package",
                "--action extract-single-file",
                "capture-manifest.json",
                "capture-summary.txt",
                "native-contract.json",
                "native-contract-analysis.json",
                "native-contract-analysis.txt",
                "KeyboardOnlySources",
                "MainControllerSourceCandidates",
                "SlotMaterializationSources",
                "AuxiliaryItemsSources",
                "ImplementationGate",
                "controller-source-ambiguous",
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
        elif ACTION_TEMPLATE.exists():
            expected_diagnostic = f"CAM {version} Xbox diagnostic"
            if expected_diagnostic not in ACTION_TEMPLATE.read_text(encoding="utf-8"):
                errors.append(
                    f"{ACTION_TEMPLATE.relative_to(ROOT)}: diagnostic build marker must match VERSION: "
                    f"{expected_diagnostic!r}"
                )

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
        "structural/safety seams present; runtime package is Script-Extender-free)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
