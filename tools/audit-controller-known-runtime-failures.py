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

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--release-gate", action="store_true",
                   help="fail closed because known runtime defects are unresolved")
    p.add_argument("--assert-original-shape", action="store_true",
                   help="verify captured v0.0.113 source markers have not silently changed")
    args = p.parse_args()
    data = inspect(RUNTIME.read_text(encoding="utf-8"),
                   json.loads(PINNED.read_text(encoding="utf-8")))
    print(json.dumps(data, indent=2, ensure_ascii=False))
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
