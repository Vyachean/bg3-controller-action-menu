#!/usr/bin/env python3
"""Source-only native-direction ownership guard for #155.

The captured BG3 Patch 8 radial uses non-focusable LSListBox containers
with focusable items and LSGrid-owned directional events. This checks
that CAM does not bind the same UIDown/UIUp a second time on the sidebar
or revive the runtime-rejected timer. It cannot simulate LSGrid bounds
or certify game behavior.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"


def local(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def attribute(node: ET.Element, key: str) -> str | None:
    for name, value in node.attrib.items():
        if local(name) == key:
            return value
    return None


def source_errors(source: str) -> list[str]:
    try:
        root = ET.fromstring(source)
    except ET.ParseError as exc:
        return [f"Invalid controller XAML: {exc}"]

    def find(name: str, typename: str) -> list[ET.Element]:
        return [node for node in root.iter()
                if local(node.tag) == typename and attribute(node, "Name") == name]

    errors = []
    sides = find("CAM_FixedSideBarList", "LSListBox")
    panels = [node for node in root.iter()
              if local(node.tag) == "ItemsPanelTemplate"
              and attribute(node, "Key") == "CAM_FixedSideBarPanel"]

    if len(sides) != 1 or len(panels) != 1:
        return ["Metamagic LSListBox / LSGrid panel must be unique"]

    side, panel = sides[0], panels[0]
    if attribute(side, "Focusable") != "False":
        errors.append("Sidebar container must be non-focusable; slot items own focus")
    if attribute(side, "ItemsSource") != (
        "{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList}"
    ):
        errors.append("Keep native FixedSideBar.SlotList slot identity")
    if attribute(side, "ItemsPanel") != "{StaticResource CAM_FixedSideBarPanel}":
        errors.append("Metamagic slot list must use its dedicated native LSGrid")
    for event in ("ActionNextEvent", "ActionPrevEvent"):
        if attribute(side, event) is not None:
            errors.append(f"Duplicate navigation owner: LSListBox.{event}")

    grids = [node for node in panel.iter() if local(node.tag) == "LSGrid"]
    if len(grids) != 1:
        errors.append("One native metamagic LSGrid is required")
    else:
        grid = grids[0]
        for key, value in (
            ("ActionUpEvent", "UIUp"), ("ActionDownEvent", "UIDown"),
            ("ActionLeftEvent", "UILeft"), ("ActionRightEvent", "UIRight"),
            ("AutoIndex", "True"), ("Columns", "1")
        ):
            if attribute(grid, key) != value:
                errors.append(f"Native LSGrid owner lost {key}={value}")

    # v0.0.114 in-game repro: after B/re-entering metamagic the ring was
    # absent until Down, which selected slot TWO. The list root is
    # Focusable=False; passing that root to SetMoveFocusAction can never
    # prove the native slot-item focus. Reject every such competing
    # focus target, including in Loaded/B/LB/RB.
    for node in root.iter():
        if local(node.tag) == "SetMoveFocusAction" and (
            "CAM_FixedSideBarList" in (attribute(node, "FocusElement") or "")
        ):
            errors.append("Do not move focus to non-focusable CAM_FixedSideBarList root")

    containers = [node for node in root.iter() if local(node.tag) == "Style"
                  and attribute(node, "Key") == "CAM_ActionGridSlotContainer"]
    if len(containers) != 1 or not any(
        local(node.tag) == "SetMoveFocusAction"
        and attribute(node, "FocusElement")
        == "{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"
        and attribute(node, "DeferFocusAction") == "True"
        for node in containers[0].iter()
    ):
        errors.append("Native ListBoxItem must own deferred slot focus")
    if len(containers) == 1 and not any(
        local(node.tag) == "ComparisonCondition"
        and attribute(node, "RightOperand")
        == "{StaticResource CAM_ResetFirstFocusToken}"
        for node in containers[0].iter()
    ):
        errors.append("Missing native item-focus reset token gate")

    for node in side.iter():
        if local(node.tag) != "TimerTrigger" or attribute(node, "EventName") != "LocalFocusChanged":
            continue
        if any(local(a.tag) == "ChangePropertyAction"
               and attribute(a, "TargetName") == "CAM_FixedSideBarList"
               and attribute(a, "PropertyName") == "SelectedIndex"
               for a in node.iter()):
            errors.append("Rejected 70ms terminal-focus reselection timer returned")

    if not find("UseSlotBinding", "LSButton"):
        errors.append("Native UseSlotBinding missing")
    else:
        accept = find("UseSlotBinding", "LSButton")[0]
        if (attribute(accept, "Command") != "{Binding UseSlotCommand}"
                or attribute(accept, "CommandParameter") != "{Binding Tag, ElementName=ActionRadials}"):
            errors.append("Native focused VMHotBarSlot dispatch changed")

    return errors


def self_test(source: str) -> None:
    if source_errors(source):
        raise AssertionError("Current source fails the native-owner baseline")

    mutations = (
        ('Focusable="False"\n                                      Width="120"',
         'Focusable="True"\n                                      Width="120"'),
        ('ItemsPanel="{StaticResource CAM_FixedSideBarPanel}"',
         'ItemsPanel="{StaticResource CAM_FixedSideBarPanel}" ActionNextEvent="UIDown"'),
        ('ActionDownEvent="UIDown"', 'ActionDownEvent="UILeft"'),
        ('ItemsPanel="{StaticResource CAM_FixedSideBarPanel}"',
         'ItemsPanel="{StaticResource CAM_ActionGridPanel}"'),
        ('CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
         'CommandParameter="{Binding SelectedItem}"'),
        ('FocusElement="{Binding ElementName=HotBarList}"',
         'FocusElement="{Binding ElementName=CAM_FixedSideBarList}"'),
    )
    for before, after in mutations:
        if source.count(before) != 1:
            # A general template may repeat a signal; use a source-unique
            # anchor for mutations rather than modifying an unrelated list.
            if before in ('ActionDownEvent="UIDown"',):
                start = source.index('<ItemsPanelTemplate x:Key="CAM_FixedSideBarPanel">')
                end = source.index('</ItemsPanelTemplate>', start)
                original = source[start:end]
                if before not in original:
                    raise AssertionError("Metamagic grid direction missing")
                changed = source[:start] + original.replace(before, after, 1) + source[end:]
            else:
                raise AssertionError(f"Mutation anchor changed: {before}")
        else:
            changed = source.replace(before, after, 1)
        if not source_errors(changed):
            raise AssertionError(f"Invalid mutation escaped the guard: {before}")
    print("Native metamagic ownership: baseline and 6 negative mutations passed (source-only).")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    source = RUNTIME.read_text(encoding="utf-8")
    errors = source_errors(source)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    if args.self_test:
        self_test(source)
    else:
        print("Source-only native LSGrid single directional owner present (not game verification).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
