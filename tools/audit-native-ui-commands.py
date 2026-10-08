#!/usr/bin/env python3
"""Fail-closed BG3 source-coverage audit. Never infer gameplay parity from XAML."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/evidence/native-ui-command-audit-1.8.910.0.json"
RUNTIME = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
PINNED = ROOT / "docs/evidence/patch8-1.8.910.0-runtime-contract.json"
COMMAND_BINDING = re.compile(
    r'\b(?:Command|Value)\s*=\s*"\{Binding\s+(?:DataContext\.)?([A-Za-z_]\w*Command)\b'
)
GROUPS = (
    "presentInCam",
    "presentButBehaviorIntentionallyRestricted",
    "missingGameplayOrUtilityTransport",
    "nativeEditorOrLayoutNotPartOfCam",
)
REQUIRED_ROUTES = {
    "resource-filter": ("FilterActionResourceCommand", "ActionResourcesCostPreview", "SingleHotBar.SlotList"),
    "cantrips": ("FilterCantripsCommand", "SingleHotBar.SlotList"),
    "inventory-deck": ("SetCurrentShownDeckCommand", "ItemHotBar", "CurrentShownDeck.SlotList"),
    "metamagic-sidebar": ("CAM_FixedSideBarList", "FixedSideBar.SlotList", "UseSlotCommand"),
    "passives": ("CAM_PassivesModeToken", "PassivesHotBar.SlotList"),
    "keyboard-fallback": ("CAM_AllModeToken", "KeyboardHotBars", "CAM_AllGroupSlots"),
    "native-nested": (
        "SingleHotBar.SlotList",
        "IsShowingAContainerWithVariants",
        "IsSelectingUpcastedSpell",
        "IsShowingItemsToThrow",
    ),
    "native-A-dispatch": ('BoundEvent="UIAccept"', "UseSlotCommand", "ActionRadials"),
}
# Configured vanilla radial slots are comparison evidence, not a CAM provider.
# Reject accidental reintroduction of the canceled #140 Original Radials UI.
FORBIDDEN_RADIAL_FALLBACK = ("CAM_OriginalRadialsModeToken", "CAM_OriginalRadialsTab", "ControllerHotBars")
REQUIRED_NATIVE_REFERENCE = {
    "keyboard": ("KeyboardHotBars", "FixedSideBar", "FilterCantripsCommand", "FilterActionResourceCommand"),
    "controller": ("SpellsAndActions", "Inventory.Slots", "TogglableMetaMagicPassivePredicate", "UseSlotCommand"),
}


def extract_commands(source: str) -> set[str]:
    """Only exact BG3 XAML command bindings, not documentation/comments."""
    return set(COMMAND_BINDING.findall(re.sub(r"<!--.*?-->", "", source, flags=re.S)))


def evaluate(manifest: dict, runtime: str, capture: dict[str, str] | None, pinned: dict) -> dict:
    errors: list[str] = []
    groups = manifest.get("classification", {})
    native = manifest.get("nativeCommands", {})
    expected = set().union(*(set(v) for v in native.values()))
    classified: dict[str, str] = {}
    for group in GROUPS:
        for command in groups.get(group, []):
            if command in classified:
                errors.append(f"duplicate classification: {command}")
            classified[command] = group
    if set(classified) != expected:
        errors.append(
            "command inventory mismatch; unclassified="
            + repr(sorted(expected - set(classified)))
            + "; extra=" + repr(sorted(set(classified) - expected))
        )
    if manifest.get("gamePackageVersion") != pinned.get("gamePackageVersion"):
        errors.append("manifest gamePackageVersion differs from pinned installed-game evidence")
    if not manifest.get("runtimeParityUnresolved"):
        errors.append("cannot claim complete parity: unresolved dynamic reference sets must remain explicit")

    commands_present = {name: name in runtime for name in sorted(expected)}
    for command in groups.get("presentInCam", []) + groups.get("presentButBehaviorIntentionallyRestricted", []):
        if not commands_present.get(command, False):
            errors.append(f"shipping native UI command disappeared: {command}")
    for command in groups.get("missingGameplayOrUtilityTransport", []):
        if commands_present.get(command, False):
            errors.append(f"new UI transport {command} requires explicit reclassification/review")

    for identifier in FORBIDDEN_RADIAL_FALLBACK:
        if identifier in runtime:
            errors.append(f"configured-radial fallback is forbidden in CAM runtime: {identifier}")

    route_status = {}
    for route, needles in REQUIRED_ROUTES.items():
        absent = [name for name in needles if name not in runtime]
        route_status[route] = {"nativeSourceSeamsPresent": not absent, "missing": absent, "runtimeParityProven": False}
        if absent:
            errors.append(f"CAM provider route regressed: {route}: {', '.join(absent)}")

    captured = None
    if capture is not None:
        captured = {"sourceHashes": {}, "commandDifferences": {}, "nativeReferenceSeams": {}}
        for surface, path in manifest["sources"].items():
            raw = capture.get(path)
            if raw is None:
                errors.append(f"capture missing required native XAML: {path}")
                continue
            digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
            captured["sourceHashes"][path] = digest
            # Hashes are evidence that the captured game is the pinned Patch 8 build.
            expected_hash = pinned.get("sourceHashes", {}).get(path)
            if expected_hash and digest != expected_hash:
                errors.append(f"installed-game XAML changed: {path} ({digest})")
            found = extract_commands(raw)
            want = set(native[surface])
            captured["commandDifferences"][surface] = {
                "new": sorted(found - want),
                "missing": sorted(want - found),
            }
            if found != want:
                errors.append(
                    f"native {surface} command inventory changed: "
                    + repr(captured["commandDifferences"][surface])
                )
            missing_seams = [needle for needle in REQUIRED_NATIVE_REFERENCE[surface] if needle not in raw]
            captured["nativeReferenceSeams"][surface] = {
                "present": not missing_seams,
                "missing": missing_seams,
            }
            if missing_seams:
                errors.append(f"native {surface} reference catalog seams missing: {missing_seams}")

    return {
        "proof": "static-source-only; dynamic action reachability and game execution unverified",
        "gamePackageVersion": manifest.get("gamePackageVersion"),
        "routes": route_status,
        "commandClassification": {g: groups.get(g, []) for g in GROUPS},
        "unresolvedActionClasses": manifest.get("runtimeParityUnresolved", []),
        "capturedNative": captured,
        "errors": errors,
    }


def load_capture(path: Path, manifest: dict) -> dict[str, str]:
    sources: dict[str, str] = {}
    with zipfile.ZipFile(path) as archive:
        for native_path in manifest["sources"].values():
            matches = [
                filename for filename in archive.namelist()
                if filename.replace("\\", "/").endswith("files/" + native_path)
            ]
            if len(matches) != 1:
                raise ValueError(f"expected one captured {native_path}, found {len(matches)}")
            sources[native_path] = archive.read(matches[0]).decode("utf-8-sig")
    return sources


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--capture", type=Path, help="optional raw, read-only Xbox App BG3 capture ZIP")
    p.add_argument("--json", action="store_true", help="emit machine-readable audit report")
    p.add_argument("--self-test", action="store_true", help="ensure removing a critical command fails closed")
    args = p.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    pinned = json.loads(PINNED.read_text(encoding="utf-8"))
    runtime = RUNTIME.read_text(encoding="utf-8")
    capture = load_capture(args.capture, manifest) if args.capture else None
    report = evaluate(manifest, runtime, capture, pinned)

    if args.self_test:
        changed = runtime.replace("UseSlotCommand", "RegressedSlotCommand")
        failed = evaluate(manifest, changed, None, pinned)["errors"]
        if not any("UseSlotCommand" in error for error in failed):
            report["errors"].append("self-test failed: missing UseSlotCommand was not rejected")
        injected = runtime + '\n<!-- CAM_OriginalRadialsModeToken -->\n'
        rejected = evaluate(manifest, injected, None, pinned)["errors"]
        if not any("configured-radial fallback is forbidden" in error for error in rejected):
            report["errors"].append("self-test failed: configured original radial tab not rejected")
        if extract_commands('<ls:LSButton Command="{Binding UseSlotCommand}"/>') != {"UseSlotCommand"}:
            report["errors"].append("self-test failed: native exact command binding was not recognized")

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        for name, result in report["routes"].items():
            print(f"{name}: {'source-present' if result['nativeSourceSeamsPresent'] else 'MISSING'}; runtime parity unverified")
        print("Known missing UI transports:", ", ".join(report["commandClassification"]["missingGameplayOrUtilityTransport"]))
        print("Unresolved action classes:", ", ".join(report["unresolvedActionClasses"]))
        for error in report["errors"]:
            print("AUDIT FAILURE:", error)
        print("Native UI audit", "FAILED" if report["errors"] else "PASSED (static source only)")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
