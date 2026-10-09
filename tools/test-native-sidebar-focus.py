#!/usr/bin/env python3
"""Source-only CAM metamagic sidebar focus handoff contract.

Checks repository markup and fault-injected negative variants, not the BG3/
Noesis runtime. It cannot establish that LSListBox focuses its child in game.
"""
from __future__ import annotations

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
XAML = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
SIDEBAR = "CAM_FixedSideBarList"
TOKEN = "CAM_ResetFirstFocusToken"


def local(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def attr(node: ET.Element, name: str) -> str:
    return next((v for k, v in node.attrib.items() if local(k) == name), "")


def audit(markup: str) -> list[str]:
    root = ET.fromstring(markup)
    errors: list[str] = []
    matches = [node for node in root.iter() if attr(node, "Name") == SIDEBAR]
    if len(matches) != 1 or local(matches[0].tag) != "LSListBox":
        return ["expected exactly one native LSListBox named CAM_FixedSideBarList"]
    sidebar = matches[0]
    if attr(sidebar, "Focusable") != "True" or attr(sidebar, "Focusable") == "False":
        errors.append("sidebar must accept native list-level focus")
    if not any(local(k) == "Focusable" and k.startswith("{") and v == "True"
               for k, v in sidebar.attrib.items()):
        errors.append("sidebar must explicitly enable MoveFocus.Focusable")
    if "CAM_FixedSideBarSelector" not in attr(sidebar, "LocalFocusSelector"):
        errors.append("sidebar selector must follow the native LocalFocus owner")

    restores = 0
    for parent in root.iter():
        children = list(parent)
        for idx, action in enumerate(children):
            if local(action.tag) != "ChangePropertyAction" or attr(action, "TargetName") != SIDEBAR:
                continue
            if attr(action, "PropertyName") == "Tag" and TOKEN in attr(action, "Value"):
                errors.append("sidebar cannot arm selected-item focus token")
            if attr(action, "PropertyName") != "SelectedIndex" or attr(action, "Value") != "0":
                continue
            restores += 1
            next_action = children[idx + 1] if idx + 1 < len(children) else None
            if (next_action is None
                    or local(next_action.tag) != "SetMoveFocusAction"
                    or attr(next_action, "TargetName") != "ActionRadials"
                    or SIDEBAR not in attr(next_action, "FocusElement")
                    or attr(next_action, "DeferFocusAction") != "True"):
                errors.append("every sidebar return must defer focus to the native LSListBox")
    if restores != 5:
        errors.append(f"expected five sidebar re-entry paths, got {restores}")

    root_triggers = [node for node in sidebar
                     if local(node.tag) == "Interaction.Triggers"]
    if len(root_triggers) != 1:
        errors.append("expected one sidebar interaction trigger collection")
        return errors
    tag_writers = []
    for trigger in root_triggers[0]:
        event = attr(trigger, "EventName")
        typ = local(trigger.tag)
        for action in trigger.iter():
            if (local(action.tag) == "ChangePropertyAction"
                    and attr(action, "TargetName") == "ActionRadials"
                    and attr(action, "PropertyName") == "Tag"):
                tag_writers.append((typ, event, attr(trigger, "MillisecondsPerTick"),
                                    attr(action, "Value")))
    if any(event == "SelectionChanged" for _typ, event, _delay, _value in tag_writers):
        errors.append("selection alone must not write the executable dispatch Tag")
    commit = [x for x in tag_writers if x[1] == "LocalFocusChanged"
              and x[0] == "TimerTrigger" and x[2] == "70"
              and "LocalFocus.DataContext" in x[3]]
    clear = [x for x in tag_writers if x[1] == "LocalFocusChanged"
             and x[0] == "EventTrigger" and x[3] == "{x:Null}"]
    if len(commit) != 1 or len(clear) != 1 or len(tag_writers) != 2:
        errors.append("preserve exactly the native-like LocalFocusChanged clear/delayed commit")
    return errors


def main() -> None:
    markup = XAML.read_text(encoding="utf-8")
    problems = audit(markup)
    assert not problems, problems
    assert any("sidebar must accept" in p for p in audit(markup.replace(
        '<ls:LSListBox x:Name="CAM_FixedSideBarList"\n                                      Focusable="True"',
        '<ls:LSListBox x:Name="CAM_FixedSideBarList"\n                                      Focusable="False"'
    )))
    assert any("every sidebar return" in p for p in audit(markup.replace(
        'FocusElement="{Binding ElementName=CAM_FixedSideBarList}"',
        'FocusElement="{Binding ElementName=HotBarList}"', 1
    )))
    assert any("selection alone" in p for p in audit(markup.replace(
        '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">',
        '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">',
        1
    ))) is False  # first replacement would target main list, not sidebar
    # Validate the exact sidebar timer mutation rather than assuming a
    # global occurrence belongs to it.
    sidebar_start = markup.index('<ls:LSListBox x:Name="CAM_FixedSideBarList"')
    sidebar_end = markup.index('</ls:LSListBox>', sidebar_start)
    bad = markup[:sidebar_start] + markup[sidebar_start:sidebar_end].replace(
        '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">',
        '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">',
        1
    ) + markup[sidebar_end:]
    assert any("selection alone" in p for p in audit(bad))
    print("Native sidebar source focus handoff: PASS (structural; gameplay unproven)")


if __name__ == "__main__":
    main()
