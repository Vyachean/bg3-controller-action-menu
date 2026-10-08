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
    problems: list[str] = []
    missing: list[dict] = []
    capabilities = {c["id"] for c in matrix["capabilities"]}
    if observation.get("schemaVersion") != 1:
        problems.append("unsupported observation schema")
    if observation.get("gamePackageVersion") != matrix.get("gamePackageVersion"):
        problems.append("game version mismatch: regenerate native and CAM inventories")
    if not observation.get("states"):
        problems.append("no captured game states")
    for state in observation.get("states", []):
        sid = state.get("id", "<unnamed>")
        if state.get("complete") is not True:
            problems.append(f"{sid}: native/CAM inventories were not collected completely")
        for key in ("nativeExecutable", "camExecutable"):
            if not isinstance(state.get(key), list):
                problems.append(f"{sid}: missing {key} action array")
        native = state.get("nativeExecutable", [])
        cam = state.get("camExecutable", [])
        if not isinstance(native, list) or not isinstance(cam, list):
            continue
        seen_native: set[str] = set()
        seen_cam: set[str] = set()
        for label, items, seen in (("native", native, seen_native), ("cam", cam, seen_cam)):
            for a in items:
                ident = a.get("identity") if isinstance(a, dict) else None
                if not isinstance(ident, str) or not ident.strip():
                    problems.append(f"{sid}: {label} has a slot without stable native identity")
                    continue
                if ident in seen:
                    # Duplicate *source locations* can be harmless; exact execution
                    # identity must not be silently deduplicated by the comparison.
                    problems.append(f"{sid}: duplicate {label} action identity {ident}")
                seen.add(ident)
                if a.get("capability") not in capabilities:
                    problems.append(f"{sid}: {label} action {ident} has no known capability")
                if label == "native" and a.get("editingOnly") is not True and a.get("executable") is not True:
                    problems.append(f"{sid}: native action {ident} has unverified executable status")
        for a in native:
            if not isinstance(a, dict) or a.get("editingOnly") is True:
                continue
            ident = a.get("identity")
            if isinstance(ident, str) and ident not in seen_cam:
                missing.append({"state": sid, "identity": ident, "capability": a.get("capability")})
        observed = state.get("nativeGlobalCapabilities")
        verified = state.get("preservedGlobalCapabilities")
        if not isinstance(observed, list) or not isinstance(verified, list):
            problems.append(f"{sid}: missing native/global controller capability evidence")
            continue
        for capability in observed:
            if capability not in capabilities:
                problems.append(f"{sid}: unknown global controller capability {capability}")
            elif capability not in verified:
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
    duplicate["states"][0]["camExecutable"].append(duplicate["states"][0]["camExecutable"][0])
    if not any("duplicate" in p for p in compare(duplicate, matrix)["problems"]):
        fails.append("duplicate action identity silently deduplicated")
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
