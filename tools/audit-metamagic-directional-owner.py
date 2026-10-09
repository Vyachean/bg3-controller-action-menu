#!/usr/bin/env python3
"""Source-only native-direction ownership guard for #155.

BG3 Patch 8 radial assignment uses focusable items and LSGrid-owned
directional events. This candidate gives the outer sidebar a native
focusable LSListBox handoff, following the game-tested v0.0.29 CAM grid.
The captured assignment control's non-focusable container is a distinct
pattern; the transition is NOT yet runtime proven in metamagic. This
audit prevents duplicate UIDown/UIUp and rejected terminal timers.
It cannot simulate LSGrid bounds or certify game behavior.
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
    if attribute(side, "Focusable") != "True" or not any(
        key.endswith("}MoveFocus.Focusable") and value == "True"
        for key, value in side.attrib.items()
    ):
        errors.append("Sidebar list must accept native list-level MoveFocus handoff")
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

    # Five B/tab/provider handoffs must defer focus to the now-focusable
    # native LSListBox, not to a stale selected-item-token owner.
    focus_handoffs = [
        node for node in root.iter()
        if local(node.tag) == "SetMoveFocusAction"
        and attribute(node, "FocusElement")
           == "{Binding ElementName=CAM_FixedSideBarList}"
        and attribute(node, "DeferFocusAction") == "True"
    ]
    if len(focus_handoffs) != 5:
        errors.append("Exactly five sidebar list-level focus handoffs required")
    if any(local(node.tag) == "ChangePropertyAction"
           and attribute(node, "TargetName") == "CAM_FixedSideBarList"
           and attribute(node, "PropertyName") == "Tag"
           and "CAM_ResetFirstFocusToken" in (attribute(node, "Value") or "")
           for node in root.iter()):
        errors.append("Retired sidebar selected-item token handoff returned")

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
        ('Focusable="True"\n                                      ls:MoveFocus.Focusable="True"\n                                      Width="120"',
         'Focusable="False"\n                                      ls:MoveFocus.Focusable="True"\n                                      Width="120"'),
        ('ItemsPanel="{StaticResource CAM_FixedSideBarPanel}"',
         'ItemsPanel="{StaticResource CAM_FixedSideBarPanel}" ActionNextEvent="UIDown"'),
        ('ActionDownEvent="UIDown"', 'ActionDownEvent="UILeft"'),
        ('ItemsPanel="{StaticResource CAM_FixedSideBarPanel}"',
         'ItemsPanel="{StaticResource CAM_ActionGridPanel}"'),
        ('CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
         'CommandParameter="{Binding SelectedItem}"'),
        ('FocusElement="{Binding ElementName=CAM_FixedSideBarList}"',
         'FocusElement="{Binding ElementName=HotBarList}"'),
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
            elif before == 'FocusElement="{Binding ElementName=CAM_FixedSideBarList}"':
                # Several independent return paths must target the sidebar.
                # Mutate one and prove the five-route invariant fails.
                changed = source.replace(before, after, 1)
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
