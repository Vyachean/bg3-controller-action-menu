#!/usr/bin/env python3
"""Compare *runtime executable action identities*, not XAML command names.

The input must be a read-only observation from a game-side probe. No BG3
binary, profile, save or mod is changed. An incomplete observation fails closed.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "docs/evidence/native-gameplay-capabilities.json"


def compare(observation: dict, matrix: dict) -> dict:
    """Check native action and capability parity for *observed* states only.

    Identity creation remains an unproven, external, BG3-owned runtime-adapter
    contract. This comparator must not accept empty/contradictory inventories
    as evidence of playable parity.
    """
    problems: list[str] = []
    missing: list[dict] = []
    capabilities = {c["id"] for c in matrix["capabilities"]}
    if not isinstance(observation, dict):
        return {
            "result": "incomplete-or-failed",
            "scope": "observed runtime states only; never implies universal BG3/mod parity",
            "missing": [],
            "problems": ["observation is not an object"],
        }
    if observation.get("schemaVersion") != 1:
        problems.append("unsupported observation schema")
    if observation.get("gamePackageVersion") != matrix.get("gamePackageVersion"):
        problems.append("game version mismatch: regenerate native and CAM inventories")

    states = observation.get("states")
    if not isinstance(states, list) or not states:
        problems.append("no captured game states")
        states = []
    for index, state in enumerate(states):
        if not isinstance(state, dict):
            problems.append(f"state {index}: not a state object")
            continue
        sid = state.get("id")
        if not isinstance(sid, str) or not sid.strip():
            problems.append(f"state {index}: missing state identity")
            sid = f"<unnamed-{index}>"
        if state.get("complete") is not True:
            problems.append(f"{sid}: native/CAM inventories were not collected completely")
        for key in ("nativeExecutable", "camExecutable"):
            if not isinstance(state.get(key), list):
                problems.append(f"{sid}: missing {key} action array")
        native = state.get("nativeExecutable")
        cam = state.get("camExecutable")
        if not isinstance(native, list) or not isinstance(cam, list):
            continue

        native_by_identity: dict[str, str] = {}
        cam_by_identity: dict[str, str] = {}
        for label, items, identities in (
            ("native", native, native_by_identity),
            ("cam", cam, cam_by_identity),
        ):
            for item in items:
                if not isinstance(item, dict):
                    problems.append(f"{sid}: {label} has a non-object action")
                    continue
                ident = item.get("identity")
                if not isinstance(ident, str) or not ident.strip():
                    problems.append(f"{sid}: {label} has a slot without stable native identity")
                    continue
                capability = item.get("capability")
                if capability not in capabilities:
                    problems.append(f"{sid}: {label} action {ident} has no known capability")
                    continue
                if label == "native" and item.get("editingOnly") is True:
                    # Deliberately excluded radial-layout operations may be
                    # present in the independent reference inventory.
                    continue
                if label == "cam" and item.get("editingOnly") is True:
                    problems.append(f"{sid}: CAM action {ident} is editing-only")
                    continue
                if item.get("executable") is not True:
                    problems.append(f"{sid}: {label} action {ident} has unverified executable status")
                if ident in identities and identities[ident] != capability:
                    problems.append(
                        f"{sid}: {label} identity {ident} contradicts another "
                        f"record's capability ({identities[ident]} vs {capability})"
                    )
                else:
                    # Multiple *consistent* native records are legitimate
                    # when the same executable action appears in several
                    # game-owned keyboard/radial sources.
                    identities[ident] = capability

        if not native_by_identity:
            problems.append(f"{sid}: no playable native reference identities captured")
        for ident, capability in native_by_identity.items():
            if ident not in cam_by_identity:
                missing.append({"state": sid, "identity": ident, "capability": capability})
            elif cam_by_identity[ident] != capability:
                # Equal textual identity alone cannot establish that the
                # CAM slot has the same gameplay capability.
                missing.append({
                    "state": sid, "identity": ident, "capability": capability,
                    "camCapability": cam_by_identity[ident],
                })
                problems.append(f"{sid}: native/CAM capability mismatch for identity {ident}")

        observed = state.get("nativeGlobalCapabilities")
        verified = state.get("preservedGlobalCapabilities")
        if not isinstance(observed, list) or not isinstance(verified, list):
            problems.append(f"{sid}: missing native/global controller capability evidence")
            continue
        for capability in observed + verified:
            if capability not in capabilities:
                problems.append(f"{sid}: unknown global controller capability {capability}")
        for capability in set(observed):
            if capability in capabilities and capability not in verified:
                missing.append({"state": sid, "capability": capability, "nativeGlobal": True})
    if missing:
        problems.append(f"{len(missing)} native gameplay action/global capability identities unreachable")
    return {
        "result": "passed" if not problems else "incomplete-or-failed",
        "scope": "observed runtime states only; never implies universal BG3/mod parity",
        "missing": missing,
        "problems": problems,
    }


def self_test(matrix: dict) -> list[str]:
    fails = []
    good = {
        "schemaVersion": 1,
        "gamePackageVersion": matrix["gamePackageVersion"],
        "states": [{
            "id": "synthetic-character",
            "complete": True,
            "nativeExecutable": [
                {"identity": "BG3-native/spell:damage:slot2", "capability": "spell-level-upcast", "executable": True},
                {"identity": "BG3-native/radial:layout", "capability": "free-no-resource", "editingOnly": True}
            ],
            "camExecutable": [
                {"identity": "BG3-native/spell:damage:slot2", "capability": "spell-level-upcast"}
            ],
            "nativeGlobalCapabilities": ["switch-weapon-sets"],
            "preservedGlobalCapabilities": ["switch-weapon-sets"]
        }]
    }
    if compare(good, matrix)["problems"]:
        fails.append("synthetic complete matching action inventory rejected")
    missing_slot = json.loads(json.dumps(good))
    missing_slot["states"][0]["camExecutable"] = []
    if not compare(missing_slot, matrix)["missing"]:
        fails.append("native action missing from CAM was silently accepted")
    missing_global = json.loads(json.dumps(good))
    missing_global["states"][0]["preservedGlobalCapabilities"] = []
    if not compare(missing_global, matrix)["missing"]:
        fails.append("native global controller capability loss was silently accepted")
    incomplete = json.loads(json.dumps(good))
    incomplete["states"][0]["complete"] = False
    if not compare(incomplete, matrix)["problems"]:
        fails.append("incomplete capture was silently accepted")
    duplicate = json.loads(json.dumps(good))
    duplicate["states"][0]["nativeExecutable"].append(duplicate["states"][0]["nativeExecutable"][0])
    if compare(duplicate, matrix)["problems"]:
        fails.append("two native providers with one executable identity were incorrectly rejected")
    return fails


def main() -> int:
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument("--observation", type=Path, help="read-only observed native + CAM runtime JSON")
    a.add_argument("--self-test", action="store_true")
    a.add_argument("--json", action="store_true")
    args = a.parse_args()
    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    failures = self_test(matrix) if args.self_test else []
    if args.observation:
        result = compare(json.loads(args.observation.read_text(encoding="utf-8")), matrix)
        failures += result["problems"]
    else:
        result = {
            "result": "awaiting-runtime-proof",
            "scope": "static code alone cannot enumerate dynamic BG3/other-mod actions",
            "unverifiedCapabilities": [c["id"] for c in matrix["capabilities"] if c["status"] != "source-present"],
            "problems": failures,
        }
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Gameplay parity audit: {result['result']}")
        for e in failures:
            print("UNPROVEN:", e)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
