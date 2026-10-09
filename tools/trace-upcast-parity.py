#!/usr/bin/env python3
"""Read-only native upcast provenance report; never claims BG3 runtime parity.

Usage:
  python tools/trace-upcast-parity.py --self-test
  python tools/trace-upcast-parity.py --capture CAPTURE.zip --json
  python tools/trace-upcast-parity.py --capture CAPTURE.zip --output evidence.json

The capture is never installed or modified. Original game XAML is not copied
into the report. Only compact binding sites and their owning XAML paths appear.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PINNED_PATH = ROOT / "docs/evidence/patch8-1.8.910.0-runtime-contract.json"
CAM_PATH = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
KEYBOARD = "Mods/MainUI/GUI/Pages/HotBar.xaml"
CONTROLLER = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"
TEMPLATES = "Public/Game/GUI/Library/DataTemplates.xaml"
SOURCES = (KEYBOARD, CONTROLLER, TEMPLATES)
NEEDLES = {
    "resourcePreview": "ActionResourcesCostPreview",
    "resourceFilter": "FilterActionResourceCommand",
    "activeUpcastVariants": "CurrentActiveSlot.Spell.SpellUpcast",
    "anyUpcastVariants": "SpellUpcast",
    "nestedUpcastFlag": "IsSelectingUpcastedSpell",
    "filteredSlots": "SingleHotBar.SlotList",
    "nativeSlotDispatch": "UseSlotCommand",
    "slotContext": "VMHotBarSlot",
    "upcastContext": "VMUpcast",
    "tooltip": "Tooltip",
}
ATTRIBUTES = (
    "Name", "Key", "DataType", "ItemsSource", "Content", "ContentTemplate",
    "Command", "CommandParameter", "BoundEvent", "Property", "Value",
    "DataContext", "Visibility", "IsEnabled", "EventName", "Binding",
)


def local(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def site_inventory(text: str, source: str) -> dict:
    """Parse actual elements/attributes, ignoring comments and prose.

    These are direct binding sites, NOT proof of object identity or command
    side effects. Report parent *names*, not raw game source or XAML nodes.
    """
    root = ET.fromstring(text)
    groups: dict[str, list[dict]] = {name: [] for name in NEEDLES}

    def visit(node: ET.Element, owners: tuple[str, ...]) -> None:
        attrs = {local(k): v for k, v in node.attrib.items()}
        identity = local(node.tag)
        if "Name" in attrs:
            identity += "#" + attrs["Name"]
        if "Key" in attrs:
            identity += "@" + attrs["Key"]
        owner_path = owners + (identity,)
        # Only attributes in real XML nodes, never comments or tag text.
        values = " ".join(attrs.values())
        if values:
            relevant = {key: attrs[key] for key in ATTRIBUTES if key in attrs}
            for kind, needle in NEEDLES.items():
                if needle not in values:
                    continue
                if len(groups[kind]) < 80:
                    groups[kind].append({
                        "file": source,
                        "owner": "/".join(owner_path[-5:]),
                        "attributes": relevant,
                    })
        for child in node:
            visit(child, owner_path)

    visit(root, ())
    return groups


def read_original_capture(path: Path, pinned: dict) -> tuple[dict[str, str], list[str], dict]:
    """Reject missing, duplicate, corrupt or unpinned source bytes."""
    original: dict[str, str] = {}
    seen: set[str] = set()
    errors: list[str] = []
    provenance: dict = {"archive": path.name, "verifiedSha256": {}, "version": None}
    with zipfile.ZipFile(path) as archive:
        for member in archive.infolist():
            normalized = member.filename.replace("\\", "/")
            if "/files/" in normalized:
                unpacked = normalized.split("/files/", 1)[1]
            elif normalized.startswith("files/"):
                unpacked = normalized[6:]
            else:
                continue
            if unpacked not in SOURCES:
                continue
            if unpacked in seen:
                errors.append("duplicate original XAML: " + unpacked)
                continue
            seen.add(unpacked)
            data = archive.read(member)
            digest = hashlib.sha256(data).hexdigest()
            expected = pinned.get("sourceHashes", {}).get(unpacked)
            if not expected or digest != expected:
                errors.append("original source SHA-256 mismatch or not pinned: " + unpacked)
                continue
            try:
                original[unpacked] = data.decode("utf-8-sig")
            except UnicodeDecodeError:
                errors.append("original XAML is not UTF-8: " + unpacked)
                continue
            provenance["verifiedSha256"][unpacked] = digest
        # Version is a cross-check, not a substitute for source hashes.
        for name in archive.namelist():
            if name.endswith("/manifest.json") or name == "manifest.json":
                try:
                    manifest = json.loads(archive.read(name).decode("utf-8-sig"))
                    version = manifest.get("gamePackageVersion")
                    if version:
                        provenance["version"] = version
                        if version != pinned.get("gamePackageVersion"):
                            errors.append("capture manifest game version differs from pinned original")
                except (UnicodeDecodeError, ValueError):
                    errors.append("unreadable capture manifest")
                break
    for required in SOURCES:
        if required not in original:
            errors.append("pinned native XAML unavailable: " + required)
    return original, errors, provenance


def compact_inventory(source: str, name: str) -> dict:
    return site_inventory(source, name)


def report(cam: str, pinned: dict, capture: Path | None) -> dict:
    errors: list[str] = []
    provenance: dict | None = None
    game: dict[str, dict] = {}
    try:
        cam_sites = compact_inventory(cam, "CAM/Lib_Controller.xaml")
    except ET.ParseError as exc:
        errors.append("CAM XAML XML parsing failed: " + str(exc))
        cam_sites = {key: [] for key in NEEDLES}
    if capture:
        try:
            sources, capture_errors, provenance = read_original_capture(capture, pinned)
            errors.extend(capture_errors)
            for path, xml in sources.items():
                try:
                    game[path] = compact_inventory(xml, path)
                except ET.ParseError as exc:
                    errors.append("original XAML XML parsing failed: " + path + ": " + str(exc))
        except (OSError, zipfile.BadZipFile) as exc:
            errors.append("cannot read original capture: " + str(exc))

    return {
        "purpose": "source-only resource IV/upcast/tooltip/action identity handoff",
        "gameVersionExpected": pinned["gamePackageVersion"],
        "capture": provenance,
        "captureSourceStatus": "sha256-verified" if capture and not errors else "unavailable-or-unverified",
        "camBindings": cam_sites,
        "pinnedNativeBindings": game,
        "proof": {
            "keyboardIVBehavior": "operator observed: IV resource filter selects an IV upcast and tooltip",
            "bindingSourceInventory": "XML-verified only; comments and text excluded",
            "nativeVMConstruction": "UNKNOWN: compiled DCHotBar producer not in XAML",
            "sameHotBarContextInstance": "UNKNOWN: matching binding names do not prove same instance",
            "variantLevelAndIdentity": "UNKNOWN: no runtime VMHotBarSlot/VMUpcast identity sample",
            "gamepadFocusAndA": "UNKNOWN: source cannot execute Noesis or input",
            "spellIVRuntimeParity": False,
        },
        "runtimeSnapshotNeeded": [
            "selected VMActionResourceCostPreview TypeId/level on resource IV",
            "filtered SingleHotBar.SlotList item Content type, upcast level and CanUse",
            "HotBarList.LocalFocus.DataContext identity and ActionRadials.Tag identity at UIAccept",
            "tooltip Content identity, spell damage and resource cost",
            "IsSelectingUpcastedSpell/MetamagicActive flags before/after A and B",
        ],
        "warning": "Do not synthesize VMUpcast, skip the native selector, or equate identical bindings with game behavior.",
        "errors": errors,
    }


def self_test() -> None:
    fixture = """<Root xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
      <!-- FilterActionResourceCommand CurrentActiveSlot.Spell.SpellUpcast -->
      <Control x:Name="Preview" ItemsSource="{Binding ActionResourcesCostPreview}"/>
      <Control x:Name="Filter" Command="{Binding FilterActionResourceCommand}"
          CommandParameter="{Binding SelectedItem, ElementName=CAM_ResourceTabs}"/>
      <Control ItemsSource="{Binding CurrentActiveSlot.Spell.SpellUpcast}"/>
      <Control Command="{Binding UseSlotCommand}" CommandParameter="{Binding .}"/>
    </Root>"""
    x = site_inventory(fixture, "synthetic/HotBar.xaml")
    assert len(x["resourceFilter"]) == 1
    assert len(x["activeUpcastVariants"]) == 1
    assert len(x["nativeSlotDispatch"]) == 1
    assert x["resourceFilter"][0]["attributes"]["CommandParameter"].endswith("CAM_ResourceTabs}")
    assert all("not-real" not in str(v) for v in x.values())
    assert len(site_inventory("<Root><!-- VMUpcast --></Root>", "empty")["upcastContext"]) == 0
    try:
        site_inventory("<Root><Broken></Root>", "invalid")
    except ET.ParseError:
        pass
    else:
        raise AssertionError("malformed native source was accepted")

    # The native capture gate must reject duplicates and altered bytes,
    # not merely the absence of a string fragment in shipping XAML.
    sample = fixture.encode("utf-8")
    pinned = {
        "gamePackageVersion": "1.8.910.0",
        "sourceHashes": {name: hashlib.sha256(sample).hexdigest() for name in SOURCES},
    }
    with tempfile.TemporaryDirectory() as temporary:
        good = Path(temporary) / "good.zip"
        duplicate = Path(temporary) / "duplicate.zip"
        changed = Path(temporary) / "changed.zip"
        for dest in (good, duplicate, changed):
            with zipfile.ZipFile(dest, "w") as writer:
                for name in SOURCES:
                    data = sample + b" " if dest == changed and name == KEYBOARD else sample
                    writer.writestr("snapshot/files/" + name, data)
                if dest == duplicate:
                    writer.writestr("another/files/" + KEYBOARD, sample)
                writer.writestr("snapshot/manifest.json", json.dumps({"gamePackageVersion": "1.8.910.0"}))
        source, errors, info = read_original_capture(good, pinned)
        assert not errors and set(source) == set(SOURCES)
        assert info["version"] == "1.8.910.0"
        _, duplicate_errors, _ = read_original_capture(duplicate, pinned)
        assert any("duplicate original XAML" in error for error in duplicate_errors)
        _, changed_errors, _ = read_original_capture(changed, pinned)
        assert any("SHA-256 mismatch" in error for error in changed_errors)
    # Exercise the real CAM read-only report path without asserting a specific
    # XAML implementation shape or treating it as gameplay verification.
    snapshot = report(
        CAM_PATH.read_text(encoding="utf-8"),
        json.loads(PINNED_PATH.read_text(encoding="utf-8")),
        None,
    )
    assert not snapshot["errors"]
    assert snapshot["captureSourceStatus"] == "unavailable-or-unverified"
    assert snapshot["proof"]["spellIVRuntimeParity"] is False
    print("Self-test passed: XML-site parser, pinned ZIP hashes and duplicate rejection only; no runtime proof")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", type=Path, help="previously captured original Patch 8 XAML ZIP")
    parser.add_argument("--output", type=Path, help="optional JSON report filename")
    parser.add_argument("--json", action="store_true", help="write report to stdout")
    parser.add_argument("--self-test", action="store_true", help="test parser independently of any game")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    pinned = json.loads(PINNED_PATH.read_text(encoding="utf-8"))
    cam = CAM_PATH.read_text(encoding="utf-8")
    result = report(cam, pinned, args.capture)
    rendered = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    if args.json or not args.output:
        print(rendered)
    return 2 if result["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
