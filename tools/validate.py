#!/usr/bin/env python3
"""Cheap repository/package preflight, NOT BG3/Noesis gameplay validation.

Only assert objectively checkable inputs for building a standalone .pak.
The Windows Build package job performs the real Divine package round-trip.
"""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "BG3ControllerActionMenu"
MOD = PACKAGE / "Mods/BG3ControllerActionMenu"
XML_EXTENSIONS = {".xaml", ".xml", ".lsx"}
EXCLUDED_DIRS = {".git", ".tools", "build", "dist", ".local", "artifacts"}
NATIVE_BINARY_EXTENSIONS = {".dll", ".exe", ".asi", ".so", ".dylib"}


def run() -> int:
    failures: list[str] = []
    required = (
        ROOT / "VERSION",
        MOD / "meta.lsx",
        MOD / "GUI/Library/Lib_Controller.xaml",
        ROOT / "build.ps1",
        ROOT / "tools/verify-package.ps1",
        ROOT / "tools/install-xbox-dev.ps1",
        ROOT / "tools/install-latest.ps1",
        ROOT / "tools/Install-BG3ControllerActionMenu.vbs",
        ROOT / "tools/dev-entry.ps1",
    )
    for path in required:
        if not path.is_file():
            failures.append(f"missing required input: {path.relative_to(ROOT)}")
    if (ROOT / "VERSION").is_file():
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", version):
            failures.append(f"invalid VERSION: {version!r}")

    forbidden_dirs = [
        MOD / "ScriptExtender",
        PACKAGE / "Public/Game/GUI/Library",
        PACKAGE / "Public/Game/GUI/Override",
    ]
    for path in forbidden_dirs:
        if path.exists():
            failures.append(f"game-owned/loader path in runtime package: {path.relative_to(ROOT)}")

    xml_count = 0
    if PACKAGE.is_dir():
        for path in PACKAGE.rglob("*"):
            if not path.is_file() or any(part in EXCLUDED_DIRS for part in path.parts):
                continue
            if path.suffix.lower() in NATIVE_BINARY_EXTENSIONS:
                failures.append(f"native executable in shipping PAK input: {path.relative_to(ROOT)}")
            if path.suffix.lower() in XML_EXTENSIONS:
                xml_count += 1
                try:
                    ET.parse(path)
                except ET.ParseError as exc:
                    failures.append(f"invalid XML {path.relative_to(ROOT)}: {exc}")
    else:
        failures.append("missing BG3ControllerActionMenu package directory")

    if xml_count == 0:
        failures.append("no XML/XAML/LSX package inputs found")
    if failures:
        for failure in failures:
            print("FAIL:", failure, file=sys.stderr)
        return 1

    print(f"Package preflight passed: {xml_count} XML/XAML/LSX inputs parse; "
          "mandatory files exist; no forbidden game-owned or native-loader files. "
          "No BG3 runtime behavior was tested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
