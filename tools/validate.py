#!/usr/bin/env python3
"""Repository-level static validation.

Uses only the Python standard library so CI and local validation do not need a
dependency bootstrap. XML validity alone is insufficient for this project:
the semantic checks below protect the native BG3 integration seams that must
remain intact until an in-game run proves them.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRS = {".git", ".local", "build", "dist", "artifacts", "extracted", "game-data", "toolkit-data"}
XML_SUFFIXES = {".xaml", ".xml", ".lsx"}

ACTION_PAGE = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml"
CONTROLLER_STATE = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml"
BOOTSTRAP = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/ScriptExtender/Lua/BootstrapClient.lua"
VERSION = ROOT / "VERSION"


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
    errors: list[str] = []
    for needle in required:
        if needle not in text:
            errors.append(f"{path.relative_to(ROOT)}: missing required integration seam: {needle}")
    return errors


def validate_semantics() -> list[str]:
    errors: list[str] = []

    errors.extend(
        require_text(
            ACTION_PAGE,
            [
                'ls:UIWidget.ContextName="HotBar"',
                "CurrentPlayer.SelectedCharacter.SpellsAndActions",
                "CurrentPlayer.SelectedCharacter.HotBars",
                "VMCharacterAction",
                "HotBarSlotStyle",
                "GustavNoesisGUI;component/Library/DataTemplates.xaml",
                "UseSlotCommand",
                "SingleHotBar.SlotList",
                "ClearSingleHotbarCommand",
                "AreRadialsOpen",
                "CallAllies",
                "IsSelectingUpcastedSpell",
                "IsShowingAContainerWithVariants",
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

    errors.extend(require_text(BOOTSTRAP, ["Probe.Register({ Auto = false })"]))

    if ACTION_PAGE.exists():
        page_text = ACTION_PAGE.read_text(encoding="utf-8")
        forbidden = [
            'x:Key="CAM_ActionTemplate"',
            'x:Name="FocusFrame"',
            'BorderBrush="#FFF3D68A"',
        ]
        for needle in forbidden:
            if needle in page_text:
                errors.append(
                    f"{ACTION_PAGE.relative_to(ROOT)}: custom slot visual remains; "
                    f"native BG3 resources must own cell rendering: {needle}"
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
        "native integration seams present)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
