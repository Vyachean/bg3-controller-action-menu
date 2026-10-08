#!/usr/bin/env python3
"""Fail-closed BG3 source-coverage audit. Never infer gameplay parity from XAML."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
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



def _attribute(attributes: dict[str, str], name: str) -> str | None:
    """Resolve plain or XML-namespace-qualified XAML attribute names."""
    if name in attributes:
        return attributes[name]
    for key, value in attributes.items():
        if key.endswith("}" + name):
            return value
    return None


def extract_native_action_sites(source: str, source_path: str) -> dict:
    """Inventory native UseSlotCommand call sites and collection bindings.

    This is *source provenance*, not a conversion from radial candidates into
    executable VMHotBarSlot instances. Inspect full XML elements so command
    parameters outside the small manually curated command-name table count.
    """
    root = ET.fromstring(source)
    dispatches: list[dict] = []
    collections: list[dict] = []

    def visit(node: ET.Element, owners: tuple[str, ...]) -> None:
        tag = node.tag.rsplit("}", 1)[-1]
        attributes = node.attrib
        name = _attribute(attributes, "Name") or _attribute(attributes, "Key")
        description = tag + (f"#{name}" if name else "")
        path = owners + (description,)
        items_source = _attribute(attributes, "ItemsSource")
        # Native styles may bind via Setter Property/Value instead of
        # direct control attributes. Do not infer style application.
        if not items_source and tag == "Setter" and _attribute(attributes, "Property") == "ItemsSource":
            items_source = _attribute(attributes, "Value")
        if items_source:
            collections.append({
                "source": source_path,
                "element": "/".join(path),
                "itemsSource": items_source,
                "dataType": _attribute(attributes, "DataType"),
            })
        command = _attribute(attributes, "Command")
        if not command and tag == "Setter" and _attribute(attributes, "Property") == "Command":
            command = _attribute(attributes, "Value")
        # Exact command binding token; never treat styling text, notes, or
        # other command names as executable call sites.
        if command and re.search(r"\bUseSlotCommand\b", command):
            dispatches.append({
                "source": source_path,
                "element": "/".join(path),
                "command": command,
                "commandParameter": _attribute(attributes, "CommandParameter"),
                "boundEvent": _attribute(attributes, "BoundEvent"),
                "isEnabled": _attribute(attributes, "IsEnabled"),
                "visibility": _attribute(attributes, "Visibility"),
                "ancestorItemSources": [
                    source for source in (
                        _attribute(ancestor.attrib, "ItemsSource")
                        for ancestor in ancestor_nodes
                    ) if source
                ],
            })
        ancestor_nodes.append(node)
        for child in node:
            visit(child, path)
        ancestor_nodes.pop()

    ancestor_nodes: list[ET.Element] = []
    visit(root, ())
    return {"dispatches": dispatches, "collections": collections}


def compare_native_action_sites(capture: dict[str, str], runtime: str) -> dict:
    """Enumerate ALL captured UI executable sites without an allowlist.

    Generic CAM ActionRadials.Tag dispatch is not considered proof that a
    separately bound vanilla keyboard/controller action is reachable. The
    report is intentionally incomplete until each source chain is proven.
    """
    vanilla: list[dict] = []
    native_collections: list[dict] = []
    failures: list[str] = []
    for path, source in sorted(capture.items()):
        if not path.endswith(".xaml"):
            continue
        try:
            sites = extract_native_action_sites(source, path)
        except ET.ParseError as exc:
            failures.append(f"could not parse captured native {path}: {exc}")
            continue
        vanilla.extend(sites["dispatches"])
        native_collections.extend(sites["collections"])
    try:
        cam = extract_native_action_sites(runtime, "CAM/Lib_Controller.xaml")
    except ET.ParseError as exc:
        failures.append(f"could not parse CAM XAML: {exc}")
        cam = {"dispatches": [], "collections": []}
    cam_parameters = {site["commandParameter"] for site in cam["dispatches"]}
    not_identical = [
        site for site in vanilla
        if not site["commandParameter"]
        or site["commandParameter"] not in cam_parameters
    ]
    return {
        "scope": "all XAML in provided archive; native engine ViewModel implementations not included",
        "staticFullParityProven": False,
        "nativeUseSlotCallSites": vanilla,
        "camUseSlotCallSites": cam["dispatches"],
        "nativeCollectionBindings": native_collections,
        "camCollectionBindings": cam["collections"],
        "nativeCallSitesWithoutIdenticalCamParameter": not_identical,
        "warning": (
            "A different parameter expression is NOT proof of a gameplay omission; "
            "matching UseSlotCommand names or params are NOT proof of provider "
            "identity equivalence. Trace every native producer to an executable "
            "CAM route; configured ControllerHotBars are not a valid fallback."
        ),
        "errors": failures,
    }


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
    native_action_sites = None
    if capture is not None:
        native_action_sites = compare_native_action_sites(capture, runtime)
        errors.extend(native_action_sites["errors"])
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
        "nativeExecutableSourceSites": native_action_sites,
        "errors": errors,
    }


def load_capture(path: Path, manifest: dict) -> dict[str, str]:
    """Load every already captured original XAML, not just two command files."""
    sources: dict[str, str] = {}
    with zipfile.ZipFile(path) as archive:
        for filename in archive.namelist():
            normalized = filename.replace("\\", "/")
            if "/files/" in normalized:
                native_path = normalized.split("/files/", 1)[1]
            elif normalized.startswith("files/"):
                native_path = normalized[len("files/"):]
            else:
                continue
            if not native_path.endswith(".xaml"):
                continue
            if native_path in sources:
                raise ValueError(f"duplicate captured native source: {native_path}")
            sources[native_path] = archive.read(filename).decode("utf-8-sig")
    for required_path in manifest["sources"].values():
        if required_path not in sources:
            raise ValueError(f"required captured game XAML missing: {required_path}")
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
        # An additional native direct parameter must not be hidden merely
        # because both widgets invoke a command named UseSlotCommand.
        fixture = (
            '<Root xmlns:ls="clr-namespace:ls;assembly=SharedGUI" '
            'xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">'
            '<!-- <ls:LSButton Command="{Binding UseSlotCommand}" '
            'CommandParameter="{Binding FakeCommentSlot}"/> -->'
            '<ls:LSButton x:Name="CallAlliesBtn" Command="{Binding UseSlotCommand}" '
            'CommandParameter="{Binding CurrentPlayer.SelectedCharacter.CallAllies}"/>'
            '<ls:LSListBox ItemsSource="{Binding SummonHotBar.SlotList}">'
            '<ls:LSButton Command="{Binding UseSlotCommand}" '
            'CommandParameter="{Binding NativeSlot}" BoundEvent="UIAccept"/>'
            '</ls:LSListBox></Root>'
        )
        sites = extract_native_action_sites(fixture, "synthetic/HotBar.xaml")
        if (len(sites["dispatches"]) != 2
                or len(sites["collections"]) != 1
                or "SummonHotBar.SlotList" not in sites["collections"][0]["itemsSource"]
                or "CallAllies" not in sites["dispatches"][0]["commandParameter"]
                or sites["dispatches"][1]["ancestorItemSources"] != [
                    "{Binding SummonHotBar.SlotList}"
                ]):
            report["errors"].append("self-test failed: missed direct action or native collection provenance")
        comparison = compare_native_action_sites(
            {"synthetic/HotBar.xaml": fixture},
            '<Root><LSButton Command="{Binding UseSlotCommand}" '
            'CommandParameter="{Binding Tag, ElementName=ActionRadials}"/></Root>',
        )
        if (len(comparison["nativeCallSitesWithoutIdenticalCamParameter"]) != 2
                or comparison["staticFullParityProven"] is not False
                or comparison["errors"]):
            report["errors"].append("self-test failed: generic CAM dispatch masked native sources")
        setter_fixture = (
            '<Root xmlns:ls="clr-namespace:ls;assembly=SharedGUI">'
            '<Style><Setter Property="Command" Value="{Binding UseSlotCommand}"/>'
            '<Setter Property="ItemsSource" Value="{Binding AnotherHotBar.SlotList}"/>'
            '</Style></Root>'
        )
        setters = extract_native_action_sites(setter_fixture, "synthetic/Setters.xaml")
        if (len(setters["dispatches"]) != 1 or len(setters["collections"]) != 1):
            report["errors"].append("self-test failed: style Setter bindings were omitted")
        parameterless = compare_native_action_sites(
            {"synthetic/Setters.xaml": setter_fixture},
            setter_fixture,
        )
        if len(parameterless["nativeCallSitesWithoutIdenticalCamParameter"]) != 1:
            report["errors"].append("self-test failed: missing native parameter was treated as proven")
        malformed = compare_native_action_sites(
            {"synthetic/Bad.xaml": "<Root><Unclosed></Root>"},
            '<Root/>',
        )
        if not any("could not parse" in e for e in malformed["errors"]):
            report["errors"].append("self-test failed: malformed native XAML did not fail closed")


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
