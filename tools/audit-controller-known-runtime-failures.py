#!/usr/bin/env python3
"""Source-only report of known *in-game rejected* v0.0.113 controller contracts.

This is NOT a gameplay test. Absence of a previously observed XAML marker
only means its implementation changed; it never means the bug was fixed.
Use --release-gate to return a nonzero status while known runtime defects
are unresolved. A future accepted fix needs actual native-semantic proof
and one combined operator in-game result, not just a changed string.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
PINNED = ROOT / "docs/evidence/patch8-1.8.910.0-runtime-contract.json"

CASES = (
    ("lb-feedback", 160, "LB/RB native feedback parity"),
    ("metamagic-terminal-focus", 155, "last-item focus remains in live sidebar"),
    ("metamagic-executable-filter", 158, "native compatible-only executable slots"),
    ("metamagic-b-back", 158, "native B returns with concrete focus"),
    ("metamagic-close-cancel", 158, "closing unspent metamagic rolls back BG3 state"),
    ("upcast-selected-level", 172, "selected resource level carries to executable slot"),
    ("native-footer-alignment", 167, "native complete right-hand hint layout"),
)

def inspect(source: str, pinned: dict) -> dict:
    # These probes identify KNOWN SOURCE PATHS, never claim what compiled
    # VM methods do or that Noesis actually raises a controller event.
    probes = {
        "lb-feedback": (
            'RightOperand="MoveToEnd"' in source
            and 'CAM_AllModeToken' in source
        ),
        "metamagic-terminal-focus": (
            'x:Key="CAM_FixedSideBarPanel"' in source
            and 'ActionDownEvent="UIDown"' in source
            and 'ActionNextEvent="UIDown"' in source
            and 'KeyboardNavigation.DirectionalNavigation="Cycle"' in source
        ),
        "metamagic-executable-filter": (
            'Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"' in source
            and 'FilterActionResourceCommand' in source
            and 'Content.IsModified' in source
        ),
        "metamagic-b-back": (
            'x:Name="CancelButton"' in source
            and 'CAM_MetamagicSpellPhaseToken' in source
            and '<Setter TargetName="CancelButton" Property="Command" Value="{x:Null}"/>' in source
            and 'EventName="LSButtonReleased"' in source
        ),
        "metamagic-close-cancel": (
            (
                'CommandParameter="CloseWidget"' in source
                or 'Property="CommandParameter" Value="CloseWidget"' in source
            )
            and 'PlayerCharacterProperties.MetamagicActive' in source
            and 'CAM_MetamagicSpellPhaseMarker' in source
        ),
        "upcast-selected-level": (
            'FilterActionResourceCommand' in source
            and 'Command="{Binding UseSlotCommand}"' in source
            and 'CommandParameter="{Binding Tag, ElementName=ActionRadials}"' in source
            and 'IsSelectingUpcastedSpell' in source
        ),
        "native-footer-alignment": (
            'x:Name="ButtonHintsContainer"' in source
            and 'MaxWidth="600"' in source
            and 'FlowDirection="RightToLeft"' in source
            and pinned.get("runtimeContract", {}).get("buttonHintsContainer", {}).get("width") == 1000
        ),
    }
    return {
        "purpose": "source observations for already rejected runtime behaviors; not acceptance",
        "gamePackageVersion": pinned.get("gamePackageVersion"),
        "testBuild": "v0.0.113-metamagic-focus-visibility",
        "sourceIndicators": [
            {
                "id": identifier,
                "issue": issue,
                "contract": title,
                "operatorStatus": "FAILED_OR_DIFFERENT_IN_GAME",
                "currentSourcePathStillDetected": probes[identifier],
                "interpretation": (
                    "matches source shape of the rejected candidate"
                    if probes[identifier]
                    else "source changed; requires renewed source review AND game proof"
                ),
                "runtimeAccepted": False,
            }
            for identifier, issue, title in CASES
        ],
        "observedWorking": [
            "original action-cost preview",
            "metamagic region-to-spell-grid transition",
            "LB extra/double opening sound removed",
        ],
        "warning": (
            "A changed source indicator never proves the bug fixed. "
            "Static XAML/build tests do not implement or simulate BG3 ViewModels, "
            "controller vibration, LSGrid boundary semantics or spell cost dispatch."
        ),
    }


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _attr(element: ET.Element, name: str) -> str | None:
    return next(
        (value for key, value in element.attrib.items() if _local(key) == name),
        None,
    )


def _nodes(parent: ET.Element, name: str) -> list[ET.Element]:
    return [node for node in parent.iter() if _local(node.tag) == name]


def audit_cancel_route(source: str) -> dict:
    """Read-only, exact-XAML audit of CAM B behavior; no VM semantics guessed."""
    errors: list[str] = []
    try:
        root = ET.fromstring(source)
    except ET.ParseError as exc:
        return {"errors": [f"Invalid XAML: {exc}"], "runtimeAccepted": False}

    cancel = [
        node for node in _nodes(root, "LSButton")
        if _attr(node, "Name") == "CancelButton"
    ]
    if len(cancel) != 1:
        return {"errors": ["Expected exactly one native CancelButton"], "runtimeAccepted": False}
    button = cancel[0]
    if _attr(button, "BoundEvent") != "UICancel":
        errors.append("UICancel must remain the native controller cancel event")
    if _attr(button, "Command") != "{Binding ClearSingleHotbarCommand}":
        errors.append("Native nested ClearSingleHotbarCommand was changed")

    routes: list[dict] = []
    for trigger in _nodes(button, "EventTrigger"):
        if _attr(trigger, "EventName") != "LSButtonReleased":
            continue
        conditions = [
            {
                "left": _attr(c, "LeftOperand"),
                "operator": _attr(c, "Operator"),
                "right": _attr(c, "RightOperand"),
            }
            for c in _nodes(trigger, "ComparisonCondition")
        ]
        native_cancel = [
            action for action in _nodes(trigger, "InvokeCommandAction")
            if "ActionCancelCommand" in (_attr(action, "Command") or "")
        ]
        switches_phase = [
            action for action in _nodes(trigger, "ChangePropertyAction")
            if _attr(action, "TargetName") == "CAM_MetamagicSpellPhaseMarker"
            and _attr(action, "PropertyName") == "Tag"
            and _attr(action, "Value") == "{x:Null}"
        ]
        # The sidebar LSListBox is Focusable=False, so a direct
        # SetMoveFocusAction to it cannot establish a native slot focus.
        # The proven CAM_ActionGridSlotContainer uses the armed parent
        # Tag + SelectedIndex transition to focus the actual ListBoxItem.
        side_focus_to_container = [
            action for action in _nodes(trigger, "SetMoveFocusAction")
            if "CAM_FixedSideBarList" in (_attr(action, "FocusElement") or "")
        ]
        side_reset = any(
            _attr(action, "TargetName") == "CAM_FixedSideBarList"
            and _attr(action, "PropertyName") == "Tag"
            and _attr(action, "Value") == "{StaticResource CAM_ResetFirstFocusToken}"
            for action in _nodes(trigger, "ChangePropertyAction")
        )
        side_select = any(
            _attr(action, "TargetName") == "CAM_FixedSideBarList"
            and _attr(action, "PropertyName") == "SelectedIndex"
            and _attr(action, "Value") == "0"
            for action in _nodes(trigger, "ChangePropertyAction")
        )
        nested = any(
            any(flag in (condition["left"] or "") and condition["right"] == "True"
                for condition in conditions)
            for flag in (
                "IsShowingAContainerWithVariants",
                "IsSelectingUpcastedSpell",
                "IsShowingItemsToThrow",
            )
        )
        meta = any("CAM_MetamagicSpellPhaseMarker" in (x["left"] or "")
                   and "CAM_MetamagicSpellPhaseToken" in (x["right"] or "")
                   and x["operator"] == "Equal" for x in conditions)
        provider = any("CAM_ProviderModeMarker" in (x["left"] or "")
                       and "CAM_MetamagicModeToken" in (x["right"] or "")
                       for x in conditions)
        routes.append({
            "metamagicSpellPhase": meta,
            "metamagicProvider": provider,
            "nested": nested,
            "nativeActionCancel": bool(native_cancel),
            "presentationPhaseReset": bool(switches_phase),
            "sidebarFocusRequest": side_reset and side_select and not side_focus_to_container,
            "invalidContainerFocusRequest": bool(side_focus_to_container),
            "conditionCount": len(conditions),
        })

    parent = [route for route in routes
              if route["metamagicSpellPhase"] and route["metamagicProvider"]
              and not route["nested"]]
    if len(routes) != 5 or len(parent) != 1:
        errors.append("Native B event-route topology changed; re-audit source")
    elif (parent[0]["nativeActionCancel"]
          or not parent[0]["presentationPhaseReset"]
          or not parent[0]["sidebarFocusRequest"]):
        errors.append("Known v0.0.113 metamagic parent B shape changed; re-audit required")
    if any(route["invalidContainerFocusRequest"] for route in routes):
        errors.append("Cancelled state must not target non-focusable sidebar LSListBox")
    if sum(route["nativeActionCancel"] for route in routes) != 4:
        errors.append("Nested/ordinary native ActionCancelCommand routes changed")

    suppressed = [
        setter for setter in _nodes(root, "Setter")
        if _attr(setter, "TargetName") == "CancelButton"
        and _attr(setter, "Property") == "Command"
        and _attr(setter, "Value") == "{x:Null}"
    ]
    if len(suppressed) != 1:
        errors.append("Known commandless metamagic B source changed; re-audit required")
    closes = [
        setter for setter in _nodes(root, "Setter")
        if _attr(setter, "TargetName") == "CancelButton"
        and _attr(setter, "Property") == "CommandParameter"
        and _attr(setter, "Value") == "CloseWidget"
    ]
    if not closes:
        errors.append("Native top-level CloseWidget path disappeared")

    return {
        "purpose": "exact controller source routes only; NOT gameplay verification",
        "gamePackageVersion": "1.8.910.0",
        "cancelButton": {
            "boundEvent": _attr(button, "BoundEvent"),
            "defaultCommand": _attr(button, "Command"),
            "sourceRoutes": routes,
            "metamagicParentOverridesCommandWithNull": len(suppressed) == 1,
            "topLevelCloseWidgetSetters": len(closes),
        },
        "blockers": {
            "metamagicParentBUsesPresentationResetNotNativeCancel": True,
            "metamagicCloseRollsBackGameOwnedState": "UNPROVEN",
            "nativeActionCancelCancelsPendingMetamagic": "UNPROVEN",
            "compatibleOnlyExecutableSpellProvider": "UNPROVEN",
        },
        "runtimeAccepted": False,
        "errors": errors,
    }


def assert_cancel_route_source(source: str) -> None:
    report = audit_cancel_route(source)
    if report["errors"]:
        raise AssertionError("; ".join(report["errors"]))
    # Prove the audit rejects silently lost native gameplay commands and
    # falsely restored phase/side state. A passing baseline is NOT acceptance.
    mutations = (
        ('Command="{Binding ClearSingleHotbarCommand}"',
         'Command="{x:Null}"'),
        ('Command="{Binding ActionCancelCommand}"',
         'Command="{Binding ClearSingleHotbarCommand}"'),
        ('<Setter TargetName="CancelButton" Property="Command" Value="{x:Null}"/>',
         '<Setter TargetName="CancelButton" Property="Command" Value="{Binding CustomEvent}"/>'),
        ('CommandParameter" Value="CloseWidget"',
         'CommandParameter" Value="UnknownCustomEvent"'),
        ('TargetName="CAM_FixedSideBarList" PropertyName="Tag" Value="{StaticResource CAM_ResetFirstFocusToken}"',
         'TargetName="CAM_FixedSideBarList" PropertyName="Tag" Value="{x:Null}"'),
    )
    for original, replacement in mutations:
        if original not in source:
            raise AssertionError(f"Native cancel mutation anchor missing: {original}")
        changed = source.replace(original, replacement)
        if not audit_cancel_route(changed)["errors"]:
            raise AssertionError(f"Native cancel regression not detected: {original}")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--release-gate", action="store_true",
                   help="fail closed because known runtime defects are unresolved")
    p.add_argument("--assert-cancel-source", action="store_true",
                   help="audit native B command and metamagic phase routes (not runtime proof)")
    p.add_argument("--assert-original-shape", action="store_true",
                   help="verify captured v0.0.113 source markers have not silently changed")
    args = p.parse_args()
    data = inspect(RUNTIME.read_text(encoding="utf-8"),
                   json.loads(PINNED.read_text(encoding="utf-8")))
    print(json.dumps(data, indent=2, ensure_ascii=False))
    if args.assert_cancel_source:
        assert_cancel_route_source(RUNTIME.read_text(encoding="utf-8"))
        print(json.dumps(audit_cancel_route(RUNTIME.read_text(encoding="utf-8")),
                         indent=2, ensure_ascii=False))
    if args.assert_original_shape and not all(
        x["currentSourcePathStillDetected"] for x in data["sourceIndicators"]
    ):
        print("Baseline changed: re-audit rather than claiming semantic acceptance.", file=sys.stderr)
        return 1
    if args.release_gate and any(
        not x["runtimeAccepted"] for x in data["sourceIndicators"]
    ):
        print("RELEASE GATE: native gameplay contracts unresolved.", file=sys.stderr)
        return 2
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
