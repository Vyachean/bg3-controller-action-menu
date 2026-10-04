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
ACTION_PAGE = MOD_ROOT / "GUI/Pages/CAM_ActionMenu_c.xaml"
CONTROLLER_STATE = MOD_ROOT / "GUI/StateMachines/Controller.xaml"
VERSION = ROOT / "VERSION"
XBOX_INSTALLER = ROOT / "tools/install-xbox-dev.ps1"
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
            ACTION_PAGE,
            [
                'ls:UIWidget.ContextName="HotBar"',
                "<ls:UIWidget.Template>",
                "<ControlTemplate>",
                "AreRadialsOpen",
                'x:Name="CAM_DiagnosticPanel"',
                'BoundEvent="UICancel"',
                'Background="Transparent"',
            ],
        )
    )

    errors.extend(
        require_text(
            CONTROLLER_STATE,
            [
                'Name="ActionRadials"',
                'ModType="Override"',
                'Filename="CAM_ActionMenu_c.xaml"',
                'Name="CloseWidget"',
                'Name="ToggleShortcutMenu"',
            ],
        )
    )

    script_extender = MOD_ROOT / "ScriptExtender"
    if script_extender.exists():
        errors.append(
            f"{script_extender.relative_to(ROOT)}: runtime package must not contain Script Extender files"
        )

    if ACTION_PAGE.exists():
        page_text = ACTION_PAGE.read_text(encoding="utf-8")
        forbidden = [
            "opaqueBG.png",
            'Background="{DynamicResource LS_tint00}"',
            "<ls:UIWidget.ContentTemplate>",
        ]
        for needle in forbidden:
            if needle in page_text:
                errors.append(
                    f"{ACTION_PAGE.relative_to(ROOT)}: controller page safety regression: {needle}"
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
        elif ACTION_PAGE.exists():
            expected_diagnostic = f"CAM {version} Xbox diagnostic"
            if expected_diagnostic not in ACTION_PAGE.read_text(encoding="utf-8"):
                errors.append(
                    f"{ACTION_PAGE.relative_to(ROOT)}: diagnostic build marker must match VERSION: "
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
