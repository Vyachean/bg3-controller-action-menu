#!/usr/bin/env python3
"""Repository-level static validation.

This intentionally uses only the Python standard library so it can run locally
and in GitHub Actions without a dependency bootstrap.
"""

from __future__ import annotations

import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
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


def main() -> int:
    errors: list[str] = []
    checked_xml = 0

    for path in iter_files():
        if path.suffix.lower() in XML_SUFFIXES:
            checked_xml += 1
            errors.extend(validate_xml(path))

    if errors:
        print("Static validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Static validation passed ({checked_xml} XML/XAML/LSX files checked).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
