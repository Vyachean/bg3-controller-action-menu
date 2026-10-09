#!/usr/bin/env python3
"""Source-only native controller focus/dispatch ownership diagnostic.

This is NOT a BG3/Noesis emulator and cannot certify runtime focus, A or B.
The --require-single-owner mode is for a future architectural correction:
it is expected to FAIL on the user-rejected v0.0.115 XAML.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
EVIDENCE = ROOT / "docs/evidence/patch8-1.8.910.0-runtime-contract.json"
NATIVE_FILE = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"


def local(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def attr(node: ET.Element, name: str) -> str:
    for key, value in node.attrib.items():
        if local(key) == name:
            return value
    return ""


def named(root: ET.Element, name: str) -> ET.Element | None:
    return next((n for n in root.iter() if attr(n, "Name") == name), None)


def owners_for_list(node: ET.Element) -> list[dict]:
    routes = []
    for trigger in node.iter():
        tag = local(trigger.tag)
        if tag not in {"EventTrigger", "TimerTrigger"}:
            continue
        event = attr(trigger, "EventName")
        if event not in {"LocalFocusChanged", "SelectionChanged"}:
            continue
        # Only direct actions in the trigger: avoid mistaking another nested
        # focus owner for this list's own publication.
        writes = [
            {"value": attr(action, "Value"), "source": local(action.tag)}
            for action in trigger.iter()
            if local(action.tag) == "ChangePropertyAction"
            and attr(action, "TargetName") == "ActionRadials"
            and attr(action, "PropertyName") == "Tag"
        ]
        if writes:
            routes.append({
                "event": event,
                "trigger": tag,
                "delayMs": int(attr(trigger, "MillisecondsPerTick") or "0")
                if tag == "TimerTrigger" else 0,
                "writes": writes,
            })
    return routes


def inspect(source: str) -> dict:
    root = ET.fromstring(source)
    lists: dict[str, dict] = {}
    for name in ["HotBarList", "CAM_FixedSideBarList"]:
        node = named(root, name)
        if node is None:
            lists[name] = {"present": False, "routes": []}
            continue
        routes = owners_for_list(node)
        lists[name] = {"present": True, "routes": routes,
                       "focusable": attr(node, "Focusable"),
                       "localFocusSelector": attr(node, "LocalFocusSelector"),
                       "selectedIndex": attr(node, "SelectedIndex")}

    accept = named(root, "UseSlotBinding")
    current = {
        "present": accept is not None,
        "boundEvent": attr(accept, "BoundEvent") if accept is not None else "",
        "command": attr(accept, "Command") if accept is not None else "",
        "commandParameter": attr(accept, "CommandParameter") if accept is not None else "",
    }
    selected_focus_requests = [
        {"binding": attr(n, "Binding"), "target": attr(a, "TargetName"),
         "focusElement": attr(a, "FocusElement")}
        for n in root.iter()
        if local(n.tag) == "DataTrigger"
        and "IsSelected" in attr(n, "Binding")
        for a in n.iter()
        if local(a.tag) == "SetMoveFocusAction"
    ]
    all_routes = [(name, route) for name, info in lists.items()
                  for route in info["routes"]]
    immediate_null = [
        name for name, route in all_routes
        if route["delayMs"] == 0
        and any(w["value"] == "{x:Null}" for w in route["writes"])
    ]
    deferred_slot = [
        name for name, route in all_routes
        if route["delayMs"] > 0
        and any("LocalFocus.DataContext" in w["value"] for w in route["writes"])
    ]
    # BG3's captured 1.8.910.0 focus lifecycle is documented as a
    # synchronous clear followed by a 70 ms LocalFocusChanged re-publication.
    # That pair is one *event source*, not two competing owners. Preserve
    # it in the inventory without falsely declaring it a gameplay bug.
    native_like_clear_then_delay = [
        name for name, info in lists.items()
        if any(route["event"] == "LocalFocusChanged" and route["delayMs"] == 0
               and any(w["value"] == "{x:Null}" for w in route["writes"])
               for route in info["routes"])
        and any(route["event"] == "LocalFocusChanged" and route["delayMs"] == 70
                and any("LocalFocus.DataContext" in w["value"]
                        for w in route["writes"])
                for route in info["routes"])
    ]
    nonnull_sources = sorted({
        (name, route["event"])
        for name, info in lists.items()
        for route in info["routes"]
        if any(w["value"] != "{x:Null}" for w in route["writes"])
    })
    selection_publishers = [
        name for name, event in nonnull_sources if event == "SelectionChanged"
    ]
    publishing_lists = sorted({name for name, _event in nonnull_sources})
    problems = []
    if accept is None or current["boundEvent"] != "UIAccept" or (
        "UseSlotCommand" not in current["command"]
        or "Tag, ElementName=ActionRadials" not in current["commandParameter"]
    ):
        problems.append("page-level UIAccept -> UseSlotCommand(ActionRadials.Tag) missing")
    if selection_publishers:
        problems.append("SelectionChanged independently publishes execution Tag beyond LocalFocusChanged")
    if len(publishing_lists) > 1:
        problems.append("multiple lists publish execution Tag; exclusive active focus is not statically proven")
    if selected_focus_requests:
        problems.append("selection-triggered SetMoveFocusAction is only a focus request, not observed LocalFocus")
    return {
        "sourceOnly": True,
        "runtimeAccepted": False,
        "nativeRuntimeCommandImplementationVisible": False,
        "legacyProvenance": {
            "tag": "v0.0.29-focus-origin-fix",
            "sourceFile": "tools/native-overlay.ps1",
            "method": "Get-FirstInteractionTriggers copied unmodified native radial focus handlers",
            "runtimeClaim": "focus frame aligned with grid; not proof of resource-first tabs",
        },
        "accept": current,
        "lists": lists,
        "selectedItemTriggeredFocusRequests": selected_focus_requests,
        "observedImmediateNullPublishers": immediate_null,
        "observedDelayedSlotPublishers": deferred_slot,
        "observedNativeLikeClearThenDelay": native_like_clear_then_delay,
        "nonnullTagEventSources": [
            {"list": name, "event": event} for name, event in nonnull_sources
        ],
        "sourceRisks": problems,
        "candidateSourceOwnershipShape": not problems,  # DOES NOT PROVE native focus/exclusivity
    }


def inspect_native_capture(path: Path) -> dict:
    """Only inspect an exact byte-matched 1.8.910.0 capture; never guess a game version."""
    data = path.read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    contract = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    expected = contract["sourceHashes"][NATIVE_FILE]
    if actual != expected:
        raise ValueError(
            f"Wrong native capture SHA-256 {actual}, required {expected} ({NATIVE_FILE})"
        )
    root = ET.fromstring(data)
    owners = {}
    for name in ("HotBarRadial", "SingleBar"):
        node = named(root, name)
        if node is None or local(node.tag) != "Radial":
            raise ValueError(f"Pinned native radial missing: {name}")
        # Include the native TimerTrigger as well as EventTrigger; the old
        # audit silently discarded the delayed half of the focus transaction.
        owners[name] = owners_for_list(node)
    return {
        "sourceFile": NATIVE_FILE,
        "sha256Verified": actual,
        "gamePackageVersion": contract["gamePackageVersion"],
        "nativeTagRoutes": owners,
        "sourceOnly": True,
        "runtimeAccepted": False,
    }


def self_test() -> None:
    ns = ('xmlns:ls="urn:ls" xmlns:b="urn:b" '
          'xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"')
    sample = (
        f'<ResourceDictionary {ns}>'
        '<Style x:Key="items"><DataTrigger Binding="{Binding IsSelected}">'
        '<ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding .}"/>'
        '</DataTrigger></Style>'
        '<ls:LSListBox x:Name="HotBarList" Focusable="False">'
        '<b:EventTrigger EventName="LocalFocusChanged">'
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>'
        '</b:EventTrigger>'
        '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70">'
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" '
        'Value="{Binding LocalFocus.DataContext}"/>'
        '</b:TimerTrigger></ls:LSListBox>'
        '<ls:LSButton x:Name="UseSlotBinding" BoundEvent="UIAccept" '
        'Command="{Binding UseSlotCommand}" '
        'CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>'
        '</ResourceDictionary>'
    )
    report = inspect(sample)
    assert len(report["lists"]["HotBarList"]["routes"]) == 2
    assert report["observedImmediateNullPublishers"] == ["HotBarList"]
    assert report["observedDelayedSlotPublishers"] == ["HotBarList"]
    assert len(report["selectedItemTriggeredFocusRequests"]) == 1
    assert report["observedNativeLikeClearThenDelay"] == ["HotBarList"]
    assert not report["candidateSourceOwnershipShape"] and not report["runtimeAccepted"]
    # A native-like clear+delay sequence alone must NOT fail the static gate:
    # v0.0.29 copied BG3 triggers and worked; this is not a gameplay test.
    native_like = sample.replace(
        '<Style x:Key="items"><DataTrigger Binding="{Binding IsSelected}">'
        '<ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding .}"/>'
        '</DataTrigger></Style>', '',
    )
    native_report = inspect(native_like)
    assert native_report["candidateSourceOwnershipShape"], native_report["sourceRisks"]
    assert native_report["observedNativeLikeClearThenDelay"] == ["HotBarList"]
    assert native_report["runtimeAccepted"] is False
    # An *additional event source* writing the execution parameter remains
    # a risk even when the canonical clear+delay pair is preserved.
    duplicate = native_like.replace(
        '</b:TimerTrigger></ls:LSListBox>',
        '</b:TimerTrigger><b:TimerTrigger EventName="SelectionChanged" '
        'MillisecondsPerTick="70">'
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" '
        'Value="{Binding LocalFocus.DataContext}"/>'
        '</b:TimerTrigger></ls:LSListBox>',
    )
    duplicate_report = inspect(duplicate)
    assert any("SelectionChanged independently" in risk
               for risk in duplicate_report["sourceRisks"])
    assert not duplicate_report["candidateSourceOwnershipShape"]
    atomic = sample.replace(
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>',
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" '
        'Value="{Binding LocalFocus.DataContext}"/>',
    ).replace(
        '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70">'
        '<b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" '
        'Value="{Binding LocalFocus.DataContext}"/>'
        '</b:TimerTrigger>',
        '',
    ).replace(
        '<Style x:Key="items"><DataTrigger Binding="{Binding IsSelected}">'
        '<ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding .}"/>'
        '</DataTrigger></Style>',
        '',
    )
    result = inspect(atomic)
    assert not result["sourceRisks"], result["sourceRisks"]
    assert result["candidateSourceOwnershipShape"]
    assert result["runtimeAccepted"] is False  # source-only clean is not gameplay proof
    lost_accept = atomic.replace('BoundEvent="UIAccept"', 'BoundEvent="Unknown"')
    assert "page-level UIAccept" in inspect(lost_accept)["sourceRisks"][0]
    print("Focus-owner source analyzer self-test: PASS (fixture only, not BG3 runtime)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--require-single-owner", action="store_true",
                        help="future architecture gate; known to fail on rejected 0.0.115")
    parser.add_argument("--source", type=Path, default=RUNTIME)
    parser.add_argument("--native-capture", type=Path,
                        help="exact original game XAML; SHA-256 MUST match captured Xbox App 1.8.910.0")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.source.is_file():
        print(f"XAML does not exist: {args.source}", file=sys.stderr)
        return 1
    report = inspect(args.source.read_text(encoding="utf-8"))
    if args.native_capture:
        try:
            report["nativePinnedEvidence"] = inspect_native_capture(args.native_capture)
        except (OSError, ET.ParseError, ValueError) as exc:
            print(f"Native source proof FAILED: {exc}", file=sys.stderr)
            return 1
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if args.require_single_owner and not report["candidateSourceOwnershipShape"]:
        print("SOURCE ownership risks present; compiled BG3 behavior still unknown",
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
