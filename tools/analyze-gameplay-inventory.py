#!/usr/bin/env python3
"""Analyze read-only BG3 native/Noesis provider snapshots, without claiming parity.

This can detect missing or truncated native collections, CAM provider mismatch,
and stale controller focus. It cannot certify that distinct VMCharacterAction
and VMHotBarSlot objects describe one executable action.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROVEN_KEYS = ("ActionId", "SpellId", "PrototypeID", "StatId", "PassiveName")
MODE_TO_REFERENCE = {
    "CAM_MetamagicMode": ("FixedSideBar.SlotList", "CAM_FixedSideBarList"),
    "CAM_ItemsMode": ("CurrentShownDeck.SlotList", "HotBarList"),
    "CAM_PassivesMode": ("PassivesHotBar.SlotList", "HotBarList"),
    "CAM_AllMode": ("KeyboardHotBars", "HotBarList"),
    "CAM_CantripsMode": ("SingleHotBar.SlotList", "HotBarList"),
}


def possible_key(entry: dict | None) -> tuple | None:
    """Display names and icons can never establish a stable executable ID."""
    if not isinstance(entry, dict):
        return None
    identity = entry.get("Content") or entry.get("Value") or entry
    parts = []
    for name in PROVEN_KEYS:
        if isinstance(identity.get(name), (int, str)) and str(identity[name]):
            parts.append((name, str(identity[name])))
    if not parts:
        return None
    # Include resource, slot, upcast variant; a match is only a *candidate*.
    value = entry.get("Value", {})
    for name in ("SlotType", "SpellSlotLevel", "Resource"):
        raw = identity.get(name, value.get(name))
        if raw is not None:
            parts.append((name, str(raw)))
    return tuple(parts)


def analyze(report: dict) -> dict:
    errors = []
    snapshots = report.get("Snapshots")
    if report.get("SchemaVersion") not in (1, 2) or not isinstance(snapshots, list) or not snapshots:
        return {
            "status": "invalid-or-empty",
            "errors": ["missing schema-1/2 gameplay inventory snapshots"],
            "snapshots": [],
            "realExecutableIdentityParityProven": False,
        }
    if report.get("RequiresNativeExecutableIdentityAdapter") is not True:
        errors.append("raw snapshots must not claim directly comparable executable IDs")
    summaries = []
    for snapshot in snapshots:
        id_ = snapshot.get("Id")
        native = snapshot.get("NativeSourceCollections") or {}
        visible = snapshot.get("CamVisibleLists") or {}
        mode = snapshot.get("CamModeMarker") or ""
        observed = {key: {"count": col.get("Count"), "observed": col.get("Observed"),
                          "complete": col.get("Complete"), "reason": col.get("Reason")}
                    for key, col in native.items()}
        missing = [name for name in (
            "KeyboardHotBars", "ControllerHotBars", "PassivesHotBar.SlotList",
            "FixedSideBar.SlotList", "SpellsAndActions", "Inventory.Slots",
            "CurrentShownDeck.SlotList", "SingleHotBar.SlotList",
        ) if name not in native]
        if missing:
            errors.append(f"snapshot {id_}: missing expected sources: {', '.join(missing)}")
        caveats = []
        if not snapshot.get("SourceCatalogComplete"):
            caveats.append("not all native source collections could be enumerated completely")
        if not snapshot.get("ReadyForExecutableIdentityComparison") is False:
            caveats.append("invalid raw capture claimed executable identity comparison was ready")
            errors.append(f"snapshot {id_}: unsafe identity parity claim")
        focus = {}
        for name in ("HotBarList", "CAM_FixedSideBarList"):
            info = visible.get(name) or {}
            value = info.get("LocalFocus")
            focus[name] = {
                "found": info.get("Found", False),
                "enabled": info.get("IsEnabled"),
                "focusedNativeVmEvidence": possible_key(value),
                "itemsCount": (info.get("Items") or {}).get("Count"),
            }
        selected_resource = snapshot.get("CamSelectedResource") or {}
        selected_action_resource = selected_resource.get("ActionResource") or {}
        selected_type = selected_action_resource.get("TypeId")
        selected_level = selected_action_resource.get("Level")
        upcast_trace = snapshot.get("NativeFilterAndUpcast") or {}
        current_filter = upcast_trace.get("CurrentSingleHotbarFilter")
        current_active_slot = upcast_trace.get("CurrentActiveSlot") or {}
        current_active_content = upcast_trace.get("CurrentActiveSlotContent") or {}
        native_variants = upcast_trace.get("NativeSpellUpcastVariants") or {}
        variant_items = native_variants.get("Items") or []
        variant_levels = []
        for item in variant_items:
            level = (item.get("Value") or {}).get("SpellSlotLevel")
            if level is None:
                level = (item.get("Content") or {}).get("SpellSlotLevel")
            if level is not None:
                variant_levels.append(str(level))
        filtered_slots = native.get("SingleHotBar.SlotList") or {}
        filtered_level_candidates = []
        for item in filtered_slots.get("Items") or []:
            content = item.get("Content") or {}
            level = content.get("SpellSlotLevel")
            if level is not None:
                filtered_level_candidates.append({
                    "sourceIndex": item.get("SourceIndex"),
                    "spellSlotLevel": str(level),
                    "identity": possible_key(item),
                })
        level_match_count = (
            sum(1 for item in filtered_level_candidates if item["spellSlotLevel"] == str(selected_level))
            if selected_level is not None else None
        )
        upcast_observation = {
            "selectedResourceTypeId": selected_type,
            "selectedResourceLevel": selected_level,
            "currentSingleHotbarFilter": current_filter,
            "currentActiveSlotIdentity": possible_key({"Value": current_active_slot, "Content": current_active_content}),
            "currentActiveContentSpellSlotLevel": current_active_content.get("SpellSlotLevel"),
            "nativeUpcastVariantLevels": variant_levels,
            "filteredSlotsWithSpellSlotLevel": filtered_level_candidates,
            "filteredSelectedLevelMatchCount": level_match_count,
            "safeAutomaticVariantSelectionProven": False,
        }
        if selected_level is not None and level_match_count == 0:
            caveats.append("selected resource level has no visible level-specific filtered slot in this snapshot")
        if selected_level is not None and level_match_count and level_match_count > 1:
            caveats.append("selected resource level maps to multiple filtered slots; level alone is non-unique")
        if selected_type and variant_levels and selected_level is not None:
            caveats.append("native upcast levels observed, but resource-family identity of variants remains unproven")

        source_route = MODE_TO_REFERENCE.get(mode)
        mismatch = None
        if source_route and not snapshot.get("NestedFlags", {}).get("IsShowingAContainerWithVariants") and not snapshot.get("NestedFlags", {}).get("IsSelectingUpcastedSpell") and not snapshot.get("NestedFlags", {}).get("IsShowingItemsToThrow"):
            expected = native.get(source_route[0]) or {}
            actual = (visible.get(source_route[1]) or {}).get("Items") or {}
            ec, ac = expected.get("Count"), actual.get("Count")
            if isinstance(ec, int) and isinstance(ac, int) and ec != ac:
                mismatch = {"nativeSource": source_route[0], "nativeCount": ec, "camList": source_route[1], "camCount": ac}
                # A source-vs-UI count mismatch is actionable even without IDs.
                errors.append(f"snapshot {id_}: source/list count mismatch: {mismatch}")
            elif not isinstance(ec, int) or not isinstance(ac, int):
                caveats.append("selected CAM mode cannot be compared to its native provider count")
        if mode == "CAM_MetamagicMode" and focus["CAM_FixedSideBarList"]["enabled"] is True:
            if focus["CAM_FixedSideBarList"]["focusedNativeVmEvidence"] is None:
                caveats.append("metamagic sidebar enabled but no stable action id in LocalFocus")
        samples = {}
        for n in ("ControllerHotBars", "KeyboardHotBars", "SpellsAndActions", "Inventory.Slots"):
            col = native.get(n) or {}
            entries = col.get("Items") or []
            if col.get("Count", 0) and not entries:
                caveats.append(f"{n} nonempty but snapshot has no entries")
            samples[n] = sum(possible_key(item) is not None for item in entries)
        summaries.append({
            "id": id_, "mode": mode, "nativeSourceCounts": observed,
            "selectedProviderCountMismatch": mismatch, "focus": focus,
            "rawItemsWithPotentialNativeIds": samples,
            "upcastObservation": upcast_observation,
            "caveats": caveats,
        })
    return {
        "status": "source-observation-only" if not errors else "incomplete-or-mismatched",
        "snapshots": summaries,
        "errors": errors,
        "realExecutableIdentityParityProven": False,
        "nextProof": "Compare the exact level/resource-specific executable VMHotBarSlot produced by keyboard versus controller DCHotBar. Never infer automatic variant choice from name/icon or SpellSlotLevel alone.",
    }


def fixtures() -> list[str]:
    base = {
        "SchemaVersion": 2, "RequiresNativeExecutableIdentityAdapter": True,
        "Snapshots": [{
            "Id": 1, "CamModeMarker": "CAM_ItemsMode",
            "SourceCatalogComplete": True,
            "ReadyForExecutableIdentityComparison": False,
            "NativeSourceCollections": {
                key: {"Count": 2 if key == "CurrentShownDeck.SlotList" else 0, "Observed": 0, "Complete": True, "Items": []}
                for key in ("KeyboardHotBars", "ControllerHotBars", "PassivesHotBar.SlotList", "FixedSideBar.SlotList", "SpellsAndActions",
                            "Inventory.Slots", "CurrentShownDeck.SlotList", "SingleHotBar.SlotList")
            },
            "CamVisibleLists": {
                "HotBarList": {"Found": True, "IsEnabled": True, "LocalFocus": {"ActionId": "attack"},
                               "Items": {"Count": 2}},
                "CAM_FixedSideBarList": {"Found": True, "IsEnabled": False, "Items": {"Count": 0}}
            },
            "CamSelectedResource": {"ActionResource": {"TypeId": "SpellSlot", "Level": 4}},
            "NativeFilterAndUpcast": {
                "CurrentSingleHotbarFilter": "Spell Slot IV",
                "CurrentActiveSlot": {"SlotType": "Spell"},
                "CurrentActiveSlotContent": {"SpellId": "Fireball", "SpellSlotLevel": 4},
                "NativeSpellUpcastVariants": {
                    "Items": [{"Value": {"SpellSlotLevel": 4}}],
                    "Count": 1, "Observed": 1, "Complete": True
                }
            },
            "NestedFlags": {},
        }]
    }
    problems = []
    result = analyze(base)
    if result["errors"] or result["realExecutableIdentityParityProven"]:
        problems.append("valid counted provider source rejected or incorrectly claimed game parity")
    wrong = json.loads(json.dumps(base))
    wrong["Snapshots"][0]["CamVisibleLists"]["HotBarList"]["Items"]["Count"] = 1
    if not analyze(wrong)["errors"]:
        problems.append("one missing CAM item was not detected")
    unsafe = json.loads(json.dumps(base))
    unsafe["Snapshots"][0]["ReadyForExecutableIdentityComparison"] = True
    if not analyze(unsafe)["errors"]:
        problems.append("unproven identity comparison was accepted")
    if possible_key({"Value": {"DisplayName": "Fireball"}}) is not None:
        problems.append("unsafe action-name-only identity was accepted")
    if possible_key({"Content": {"SpellId": "Fireball", "SpellSlotLevel": 2}}) == possible_key({"Content": {"SpellId": "Fireball", "SpellSlotLevel": 3}}):
        problems.append("resource-distinct spell variants were merged")
    observed = analyze(base)["snapshots"][0]["upcastObservation"]
    if observed["selectedResourceLevel"] != 4 or observed["safeAutomaticVariantSelectionProven"] is not False:
        problems.append("upcast observation lost selected level or incorrectly proved automatic variant selection")
    return problems


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--report", type=Path, help="gameplay-inventory-raw.json from dev-only probe")
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    failed = fixtures() if args.self_test else []
    if args.report:
        outcome = analyze(json.loads(args.report.read_text(encoding="utf-8")))
    else:
        outcome = {"status": "awaiting-read-only-native-observation", "realExecutableIdentityParityProven": False, "errors": []}
    outcome["errors"] += failed
    if args.json:
        print(json.dumps(outcome, indent=2, ensure_ascii=False))
    else:
        print("Gameplay source inventory:", outcome["status"])
        for error in outcome["errors"]:
            print("FAIL:", error)
        print("Actual game action parity: NOT PROVEN")
    return 1 if outcome["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
