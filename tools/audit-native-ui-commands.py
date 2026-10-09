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
    "native-summon-overlay": ("SummonHotBar.SlotList.Count", "SummonHotBar.SlotList", "CAM_ActionGridSlotTemplate"),
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
    content_providers: list[dict] = []

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
                "predicate": _attribute(attributes, "Predicate"),
            })
        # Original keyboard HotBar mounts independently executable native
        # VMHotBar objects with Content + HotBarTemplate, not ItemsSource.
        # Without this pass SummonHotBar/CustomHotBar disappear from the audit.
        content = _attribute(attributes, "Content")
        content_template = _attribute(attributes, "ContentTemplate")
        if content and content_template and "HotBarTemplate" in content_template:
            content_providers.append({
                "source": source_path,
                "element": "/".join(path),
                "content": content,
                "contentTemplate": content_template,
                "visibility": _attribute(attributes, "Visibility"),
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
    return {"dispatches": dispatches, "collections": collections, "contentProviders": content_providers}


def compare_native_action_sites(capture: dict[str, str], runtime: str) -> dict:
    """Enumerate ALL captured UI executable sites without an allowlist.

    Generic CAM ActionRadials.Tag dispatch is not considered proof that a
    separately bound vanilla keyboard/controller action is reachable. The
    report is intentionally incomplete until each source chain is proven.
    """
    vanilla: list[dict] = []
    native_collections: list[dict] = []
    native_content_providers: list[dict] = []
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
        native_content_providers.extend(sites["contentProviders"])
    try:
        cam = extract_native_action_sites(runtime, "CAM/Lib_Controller.xaml")
    except ET.ParseError as exc:
        failures.append(f"could not parse CAM XAML: {exc}")
        cam = {"dispatches": [], "collections": [], "contentProviders": []}
    cam_parameters = {site["commandParameter"] for site in cam["dispatches"]}
    cam_content_sources = {site["content"] for site in cam["contentProviders"]}
    unmirrored_content = [
        site for site in native_content_providers
        if site["content"] not in cam_content_sources
    ]
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
        "nativeContentProviders": native_content_providers,
        "camContentProviders": cam["contentProviders"],
        "nativeContentProvidersWithoutSameCamBinding": unmirrored_content,
        "nativeCallSitesWithoutIdenticalCamParameter": not_identical,
        "warning": (
            "A different parameter expression is NOT proof of a gameplay omission; "
            "matching UseSlotCommand names or params are NOT proof of provider "
            "identity equivalence. Trace every native producer to an executable "
            "CAM route; configured ControllerHotBars are not a valid fallback."
        ),
        "errors": failures,
    }


def validate_summon_source_route(runtime: str) -> list[str]:
    """Source-owner and precedence gate for the native summon overlay.

    The captured keyboard HotBar and controller ActionRadials both use DCHotBar.
    A native VMHotBar.SlotList may override the main LSListBox directly; it
    must not be converted to an ad hoc action or mask nested SingleHotBar.
    """
    errors: list[str] = []
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"CAM summon source cannot be checked: invalid XAML: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    def named(name: str) -> ET.Element | None:
        return next((n for n in root.iter() if _attribute(n.attrib, "Name") == name), None)

    def style_triggers(control: ET.Element | None) -> list[ET.Element]:
        if control is None:
            return []
        for child in control:
            if local(child) != "LSListBox.Style":
                continue
            for style in child:
                for trigger_section in style:
                    if local(trigger_section) == "Style.Triggers":
                        return list(trigger_section)
        return []

    def setters(trigger: ET.Element) -> dict[str, str | None]:
        return {
            _attribute(child.attrib, "Property"): _attribute(child.attrib, "Value")
            for child in trigger if local(child) == "Setter"
        }

    main = named("HotBarList")
    side = named("CAM_FixedSideBarList")
    if main is None or side is None:
        return ["CAM summon route missing main or metamagic input-owner LSListBox"]
    main_triggers = style_triggers(main)
    summoner_indices = [
        i for i, t in enumerate(main_triggers)
        if local(t) == "DataTrigger"
        and "SummonHotBar.SlotList.Count" in (_attribute(t.attrib, "Binding") or "")
        and "GreaterThanConverter" in (_attribute(t.attrib, "Binding") or "")
        and _attribute(t.attrib, "Value") == "True"
    ]
    if len(summoner_indices) != 1:
        errors.append("CAM main slot source must have exactly one native nonempty summon override")
    else:
        i = summoner_indices[0]
        expected = {
            "ItemsSource": "{Binding SummonHotBar.SlotList}",
            "ItemContainerStyle": "{StaticResource CAM_ActionGridSlotContainer}",
            "ItemTemplate": "{StaticResource CAM_ActionGridSlotTemplate}",
            "ItemsPanel": "{StaticResource CAM_ActionGridPanel}",
            "IsEnabled": "True",
        }
        values = setters(main_triggers[i])
        if any(values.get(prop) != value for prop, value in expected.items()):
            errors.append("CAM summon override must use native direct-slot grid and own main focus")
        for flag in (
            "IsShowingAContainerWithVariants",
            "IsSelectingUpcastedSpell",
            "IsShowingItemsToThrow",
        ):
            later = [
                t for t in main_triggers[i+1:]
                if local(t) == "DataTrigger"
                and flag in (_attribute(t.attrib, "Binding") or "")
                and setters(t).get("ItemsSource") == "{Binding SingleHotBar.SlotList}"
            ]
            if not later:
                errors.append(f"native {flag} must override summoned slots as final grid source")

    sidebar = style_triggers(side)
    side_gate = [
        i for i, t in enumerate(sidebar)
        if local(t) == "DataTrigger"
        and "SummonHotBar.SlotList.Count" in (_attribute(t.attrib, "Binding") or "")
        and setters(t).get("IsEnabled") == "False"
    ]
    active_side = [
        i for i, t in enumerate(sidebar)
        if local(t) == "MultiDataTrigger"
        and any("CAM_MetamagicModeToken" in str(c.attrib)
                for child in t for c in child.iter())
    ]
    if len(side_gate) != 1 or (active_side and side_gate[0] <= max(active_side)):
        errors.append("Summon override must disable fixed-sidebar input after Metamagic activation")

    # A change of native source invalidates prior focus/tag/tooltip data.
    reset_triggers = [
        t for t in root.iter()
        if local(t) == "DataTrigger"
        and _attribute(t.attrib, "Value") == "True"
        and "SummonHotBar.SlotList.Count" in (_attribute(t.attrib, "Binding") or "")
        and any(local(action) == "SetMoveFocusAction" and
                _attribute(action.attrib, "TargetName") == "ActionRadials"
                for action in t)
    ]
    if len(reset_triggers) != 1 or not all(
        any(_attribute(a.attrib, "TargetName") == target and
            _attribute(a.attrib, "PropertyName") == prop
            for a in reset_triggers[0])
        for target, prop in (
            ("ActionRadials", "Tag"),
            ("CAM_ActionTooltip", "Content"),
            ("HotBarList", "SelectedIndex"),
        )
    ):
        errors.append("Native summon population must clear stale tooltip/tag and restore first-slot focus")

    exit_triggers = [
        t for t in root.iter()
        if local(t) == "DataTrigger"
        and _attribute(t.attrib, "Value") == "False"
        and "SummonHotBar.SlotList.Count" in (_attribute(t.attrib, "Binding") or "")
    ]
    cleanup = [
        t for t in exit_triggers
        if all(any(_attribute(a.attrib, "TargetName") == target
                   and _attribute(a.attrib, "PropertyName") == prop
                   for a in t)
               for target, prop in (
                   ("ActionRadials", "Tag"),
                   ("CAM_ActionTooltip", "Content"),
                   ("HotBarList", "SelectedIndex"),
               ))
    ]
    fallback_focus = [
        a for t in exit_triggers for a in t.iter()
        if local(a) == "SetMoveFocusAction"
    ]
    if len(cleanup) != 1 or not all(
        any(_attribute(a.attrib, "FocusElement") == f"{{Binding ElementName={owner}}}"
            for a in fallback_focus)
        for owner in ("HotBarList", "CAM_FixedSideBarList")
    ):
        errors.append("Native summon exit must clear stale dispatch and restore the prior grid or sidebar focus")
    return errors



def validate_controller_refusal_feedback(runtime: str) -> list[str]:
    """Keep the original ActionRadials UIAccept denial feedback.

    Native execution still belongs to UseSlotBinding. This auxiliary
    UIAccept hint only plays the BG3 error sound when the original
    Tag.CanUse + nonempty Tag.ThothError conditions both hold.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"cannot inspect controller refusal feedback in invalid CAM XAML: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    buttons = [
        node for node in root.iter()
        if local(node) == "LSButton"
        and _attribute(node.attrib, "Name") == "SelectButtonVisual"
    ]
    if len(buttons) != 1:
        return ["original controller refusal hint SelectButtonVisual missing or duplicated"]

    select = buttons[0]
    if (_attribute(select.attrib, "BoundEvent") != "UIAccept"
            or _attribute(select.attrib, "EatInput") != "False"):
        return ["original controller refusal hint must not consume or remap UIAccept"]

    feedback_triggers = []
    for trigger in select.iter():
        if local(trigger) != "EventTrigger" or _attribute(trigger.attrib, "EventName") != "Click":
            continue
        if any(local(child) == "LSPlaySound"
               and _attribute(child.attrib, "Sound") == "UI_Shared_Error"
               for child in trigger):
            feedback_triggers.append(trigger)
    if len(feedback_triggers) != 1:
        return ["original controller refused-action error sound missing or duplicated"]

    conditions = [
        (_attribute(c.attrib, "LeftOperand"), _attribute(c.attrib, "Operator"),
         _attribute(c.attrib, "RightOperand"))
        for c in feedback_triggers[0].iter()
        if local(c) == "ComparisonCondition"
    ]
    required = {
        ("{Binding Tag.CanUse, ElementName=ActionRadials}", "Equal", "False"),
        ("{Binding Tag.ThothError, ElementName=ActionRadials, Converter={StaticResource NullToBoolFalseConverter}, ConverterParameter='EmptyString'}", "Equal", "True"),
    }
    if set(conditions) != required:
        return ["original controller refusal feedback must be conditional on native CanUse and ThothError"]
    return []



def validate_native_weapon_switch(runtime: str) -> list[str]:
    """Preserve the original Patch 8 controller hold-button contract.

    Previous custom input bindings caused ordinary grid-left presses to
    switch weapons or stopped firing after the first hold. Do not allow
    those regressions back into the shipping template.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"cannot inspect weapon-set control in invalid XAML: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    buttons = [
        node for node in root.iter()
        if local(node) == "LSButton"
        and _attribute(node.attrib, "Name") == "ToggleWeaponSet"
    ]
    if len(buttons) != 1:
        return ["native weapon-set switch button missing or duplicated"]
    button = buttons[0]
    expected = {
        "Style": "{StaticResource ControllerHoldButtonStyle}",
        "Command": "{Binding SwitchWeaponSetCommand}",
        "Content": "{Binding CurrentPlayer.UIData.InputEvents, Converter={StaticResource FindInputEventConverter}, ConverterParameter='UISelectionLeft'}",
        "EatInput": "False",
    }
    errors: list[str] = []
    if any(_attribute(button.attrib, key) != value
           for key, value in expected.items()):
        errors.append("native weapon-set switch must use original hold-button style and command")
    if _attribute(button.attrib, "BoundEvent") is not None:
        errors.append("native weapon-set switch button must not bind a direct input event")

    bad_input_bindings = [
        node for node in root.iter()
        if local(node) == "LSInputBinding"
        and (
            "SwitchWeaponSetCommand" in (_attribute(node.attrib, "Command") or "")
            or _attribute(node.attrib, "BoundEvent") in ("UISelectionLeft", "ToggleWeaponSet")
        )
    ]
    if bad_input_bindings:
        errors.append("native weapon-set switch must not add an input shortcut binding")

    ranged_triggers = [
        trigger for trigger in root.iter()
        if local(trigger) == "DataTrigger"
        and _attribute(trigger.attrib, "Binding")
            == "{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasRangedAttack}"
        and _attribute(trigger.attrib, "Value") == "False"
        and any(local(setter) == "Setter"
                and _attribute(setter.attrib, "TargetName") == "ToggleWeaponSet"
                and _attribute(setter.attrib, "Property") == "Visibility"
                and _attribute(setter.attrib, "Value") == "Collapsed"
                for setter in trigger)
    ]
    if len(ranged_triggers) != 1:
        errors.append("native weapon-set switch must hide when HasRangedAttack is False")

    if not any(local(node) == "LSGrid"
               and _attribute(node.attrib, "ActionLeftEvent") == "UILeft"
               for node in root.iter()):
        errors.append("native weapon-set shortcut must not replace grid-left navigation")
    return errors




def validate_native_compact_footer(runtime: str) -> list[str]:
    """Original radial has a Width=Auto controller hint layout variant.

    The 1000px-per-button radial geometry stacks hold affordances offscreen
    below CAM's 934px action grid. Keep original hold controls/input intact;
    change visual geometry only, as BG3's own Layout=Left/Right source does.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"invalid CAM XAML for controller hint layout: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    panels = [
        n for n in root.iter()
        if local(n) == "AlignableWrapPanel"
        and _attribute(n.attrib, "Name") == "ButtonHintsContainer"
    ]
    if len(panels) != 1:
        return ["compact controller hint panel missing or duplicated"]
    panel = panels[0]
    expected = {
        "Width": "Auto",
        "HorizontalAlignment": "Center",
        "HorizontalContentAlignment": "Center",
        "VerticalAlignment": "Bottom",
        "FlowDirection": "LeftToRight",
    }
    if any(_attribute(panel.attrib, k) != v for k, v in expected.items()):
        return ["controller hints must use native compact centered layout"]

    visible_hint_names = {
        "SelectButtonVisual",
        "ToWorldButton",
        "CancelConcentrationButton",
        "ToggleWeaponSet",
        "ToggleDualWield",
        "CancelButton",
    }
    controls = {
        _attribute(n.attrib, "Name"): n
        for n in panel
        if local(n) == "LSButton"
    }
    if any(name not in controls or _attribute(controls[name].attrib, "Width") != "Auto"
           for name in visible_hint_names):
        return ["all visible controller hints must use native auto width"]

    stub = controls.get("ShowContextMenu")
    if stub is None or _attribute(stub.attrib, "Visibility") != "Collapsed" or (
        _attribute(stub.attrib, "Width") != "0"
    ):
        return ["radial context-editor hint must remain hidden in CAM"]
    return []


def validate_native_throw_world_exit(runtime: str) -> list[str]:
    """Keep the original Throw item-picker world exit, not a radial editor."""
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"invalid CAM XAML for native Throw world exit: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    matches = [
        node for node in root.iter()
        if local(node) == "LSButton"
        and _attribute(node.attrib, "Name") == "ToWorldButton"
    ]
    if len(matches) != 1:
        return ["native Throw to-world button missing or duplicated"]
    button = matches[0]
    expected = {
        "BoundEvent": "UIDelete",
        "Command": "{Binding CustomEvent}",
        "CommandParameter": "CloseRadials",
        "ContentTemplate": "{StaticResource ControllerButtonHint}",
        "Content": "{Binding CurrentPlayer.UIData.InputEvents, ConverterParameter=UIDelete, Converter={StaticResource FindInputEventConverter}}",
        "Visibility": "Collapsed",
    }
    errors: list[str] = []
    if any(_attribute(button.attrib, k) != v for k, v in expected.items()):
        errors.append("native Throw to-world button must preserve UIDelete and CloseRadials")
    if any(local(node) == "EventTrigger" for node in button.iter()):
        errors.append("native Throw to-world button cannot invent a secondary input handler")
    visible_triggers = [
        trigger for trigger in root.iter()
        if local(trigger) == "DataTrigger"
        and _attribute(trigger.attrib, "Binding") == "{Binding IsShowingItemsToThrow}"
        and _attribute(trigger.attrib, "Value") == "True"
        and any(local(setter) == "Setter"
                and _attribute(setter.attrib, "TargetName") == "ToWorldButton"
                and _attribute(setter.attrib, "Property") == "Visibility"
                and _attribute(setter.attrib, "Value") == "Visible"
                for setter in trigger)
    ]
    if len(visible_triggers) != 1:
        errors.append("native Throw to-world hint must appear only in the item picker")
    return errors



def validate_native_toggle_notifications(runtime: str) -> list[str]:
    """Protect exact original game-owned state notifications, never CAM input.

    Source: installed 1.8.910.0 PreloadedActionRadials_c.xaml:22,32-53,
    1830-1886. The animation and UI layer remain controller-only visuals.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"native controller state notification XAML invalid: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    def named(name: str) -> list[ET.Element]:
        return [node for node in root.iter() if _attribute(node.attrib, "Name") == name]

    notices = named("CAM_ControlNotifications")
    if len(notices) != 1 or local(notices[0]) != "LSNineSliceImage":
        return ["native controller toggle notification overlay missing or duplicated"]
    notice = notices[0]
    props = {
        "IsHitTestVisible": "False",
        "Focusable": "False",
        "Visibility": "Collapsed",
        "Opacity": "0",
        "Style": "{StaticResource CAM_NotificationBG9Slice}",
    }
    if any(_attribute(notice.attrib, key) != value for key, value in props.items()):
        return ["native toggle notification must be noninteractive and hidden at rest"]

    style = [node for node in root if local(node) == "Style"
             and _attribute(node.attrib, "Key") == "CAM_NotificationBG9Slice"]
    image = [node for node in root if local(node) == "ImageSource"
             and _attribute(node.attrib, "Key") == "CAM_NotificationBg"]
    if len(style) != 1 or len(image) != 1 or not (
        image[0].text and "Core;component/Assets/Notification/smallNotice_bg.png" in image[0].text
    ):
        return ["native toggle notification must reuse BG3's original background asset"]

    animations = [node for node in root if local(node) == "Storyboard"
                  and _attribute(node.attrib, "Key") == "CAM_FadeInNotification"]
    if len(animations) != 1:
        return ["native toggle notification must retain original fade storyboard"]
    sequence = [
        (_attribute(frame.attrib, "KeyTime"), _attribute(frame.attrib, "Value"))
        for frame in animations[0].iter()
        if local(frame) == "LinearDoubleKeyFrame"
    ]
    if sequence != [("0:0:0.0", "0"), ("0:0:0.3", "1"),
                    ("0:0:1.2", "1"), ("0:0:1.5", "0")]:
        return ["native toggle notification fade-in/out timing must match BG3"]

    all_triggers = [node for node in notice.iter()
                    if local(node) == "PropertyChangedTrigger"]
    if len(all_triggers) != 4:
        return ["native controller toggle feedback requires exactly four state transitions"]

    expected = {
        ("HasRangedSetActive", "ToggleWeaponSet", "HasRangedSetActive", "True"):
            "h6e99c201gc607g4da9gba50gb83f93d8a6e6",
        ("HasRangedSetActive", "ToggleWeaponSet", "HasMeleeSetActive", "True"):
            "hfaac6c41gc244g45d5g952agb45eb21ee282",
        ("IsDualWieldingToggledOn", "ToggleDualWield", "IsDualWieldingToggledOn", "True"):
            "hee8cf049gc819g4cd4g8b3ag7a0acc1f2f1b",
        ("IsDualWieldingToggledOn", "ToggleDualWield", "IsDualWieldingToggledOn", "False"):
            "h69107c78gd9efg4fd2ga137g427cc0280604",
    }
    errors: list[str] = []
    seen = {}
    for trigger in all_triggers:
        bound = _attribute(trigger.attrib, "Binding") or ""
        watched = next((part for part in
                        ("HasRangedSetActive", "IsDualWieldingToggledOn")
                        if bound == "{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties." + part + "}"), None)
        clauses = [node for node in trigger.iter()
                   if local(node) == "ComparisonCondition"]
        if len(clauses) != 2:
            errors.append("native toggle notification predicates must retain press and game state")
            continue
        presses = [
            (_attribute(n.attrib, "LeftOperand"), _attribute(n.attrib, "Operator"),
             _attribute(n.attrib, "RightOperand"))
            for n in clauses
        ]
        pressed = next((p for p in ("ToggleWeaponSet", "ToggleDualWield")
                        if ("{Binding ElementName=" + p + ", Path=IsPressed}", "Equal", "True") in presses), None)
        state = next(((prop, value)
                      for prop in ("HasRangedSetActive", "HasMeleeSetActive", "IsDualWieldingToggledOn")
                      for value in ("True", "False")
                      if ("{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties." + prop + "}",
                          "Equal", value) in presses), None)
        if watched is None or pressed is None or state is None:
            errors.append("native toggle notification lost native pressed/state predicate")
            continue
        key = (watched, pressed, state[0], state[1])
        changed = [node for node in trigger.iter()
                   if local(node) == "ChangePropertyAction"
                   and _attribute(node.attrib, "TargetName") == "CAM_NotificationText"
                   and _attribute(node.attrib, "PropertyName") == "Text"]
        storyboard = [node for node in trigger.iter()
                      if local(node) == "ControlStoryboardAction"
                      and _attribute(node.attrib, "Storyboard") == "{StaticResource CAM_FadeInNotification}"]
        if len(changed) != 1 or len(storyboard) != 1:
            errors.append("native toggle notification must update text and play BG3 fade")
            continue
        seen[key] = _attribute(changed[0].attrib, "Value")

    if set(seen) != set(expected) or any(
        seen.get(k) != ("{Binding Source='" + val + "', Converter={StaticResource TranslatedStringConverter}}")
        for k, val in expected.items()
    ):
        errors.append("native controller toggle feedback source states/labels changed")
    return errors


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

    errors.extend(validate_summon_source_route(runtime))
    errors.extend(validate_controller_refusal_feedback(runtime))
    errors.extend(validate_native_weapon_switch(runtime))
    errors.extend(validate_native_compact_footer(runtime))
    errors.extend(validate_native_throw_world_exit(runtime))
    errors.extend(validate_native_toggle_notifications(runtime))

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
        removed_denial_sound = runtime.replace('Sound="UI_Shared_Error"', 'Sound="UI_ErrorRegression"')
        if not any("refused-action error sound" in error
                   for error in validate_controller_refusal_feedback(removed_denial_sound)):
            report["errors"].append("self-test failed: removal of native refusal sound not rejected")
        disabled_denial_guard = runtime.replace(
            'LeftOperand="{Binding Tag.CanUse, ElementName=ActionRadials}" Operator="Equal" RightOperand="False"/>',
            'LeftOperand="{Binding Tag.CanUse, ElementName=ActionRadials}" Operator="Equal" RightOperand="True"/>',
            1,
        )
        if not any("conditional on native CanUse" in error
                   for error in validate_controller_refusal_feedback(disabled_denial_guard)):
            report["errors"].append("self-test failed: reversed original denial guard not rejected")
        removed_switch = runtime.replace(
            'Command="{Binding SwitchWeaponSetCommand}"',
            'Command="{Binding MissingWeaponSetCommand}"',
            1,
        )
        if not any("original hold-button style and command" in err
                   for err in validate_native_weapon_switch(removed_switch)):
            report["errors"].append("self-test failed: weapon-set command loss undetected")
        added_shortcut = runtime.replace(
            'x:Name="ToggleWeaponSet"',
            'x:Name="ToggleWeaponSet" BoundEvent="UISelectionLeft"',
            1,
        )
        if not any("must not bind a direct input event" in err
                   for err in validate_native_weapon_switch(added_shortcut)):
            report["errors"].append("self-test failed: unsafe weapon button input not rejected")
        removed_ranged_guard = runtime.replace(
            'Binding="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasRangedAttack}" Value="False"',
            'Binding="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasRangedAttack}" Value="True"',
            1,
        )
        if not any("hide when HasRangedAttack" in err
                   for err in validate_native_weapon_switch(removed_ranged_guard)):
            report["errors"].append("self-test failed: weapon-set visibility guard loss undetected")
        throw_bad_command = runtime.replace(
            'CommandParameter="CloseRadials"',
            'CommandParameter="OpenRadialEditor"',
            1,
        )
        if not any("preserve UIDelete and CloseRadials" in err
                   for err in validate_native_throw_world_exit(throw_bad_command)):
            report["errors"].append("self-test failed: wrong Throw world exit not rejected")
        throw_bad_visibility = runtime.replace(
            '<Setter TargetName="ToWorldButton" Property="Visibility" Value="Visible"/>',
            '<Setter TargetName="ToWorldButton" Property="Visibility" Value="Collapsed"/>',
            1,
        )
        if not any("appear only in the item picker" in err
                   for err in validate_native_throw_world_exit(throw_bad_visibility)):
            report["errors"].append("self-test failed: missing Throw world hint not rejected")
        suppressed_feedback = runtime.replace(
            'x:Name="CAM_ControlNotifications"\n                                 Opacity="0"',
            'x:Name="CAM_ControlNotifications"\n                                 Opacity="1"',
            1,
        )
        if not any("noninteractive and hidden at rest" in err
                   for err in validate_native_toggle_notifications(suppressed_feedback)):
            report["errors"].append("self-test failed: always-visible toggle feedback not rejected")
        wrong_weapon_feedback = runtime.replace(
            "Source='h6e99c201gc607g4da9gba50gb83f93d8a6e6'",
            "Source='hINVALIDranged'",
            1,
        )
        if not any("source states/labels changed" in err
                   for err in validate_native_toggle_notifications(wrong_weapon_feedback)):
            report["errors"].append("self-test failed: incorrect ranged-set label not rejected")
        missing_press_guard = runtime.replace(
            'LeftOperand="{Binding ElementName=ToggleWeaponSet, Path=IsPressed}" Operator="Equal" RightOperand="True"/>',
            'LeftOperand="{Binding ElementName=ToggleWeaponSet, Path=IsPressed}" Operator="Equal" RightOperand="False"/>',
            1,
        )
        if not any("source states/labels changed" in err
                   or "lost native pressed/state predicate" in err
                   for err in validate_native_toggle_notifications(missing_press_guard)):
            report["errors"].append("self-test failed: unguarded weapon change notification not rejected")
        wide_footer = runtime.replace(
            'x:Name="ButtonHintsContainer"\n                                   Style="{StaticResource ButtonHint.Container.CenterWrap}"\n                                   HorizontalAlignment="Center"\n                                   HorizontalContentAlignment="Center"\n                                   VerticalAlignment="Bottom"\n                                   Width="Auto"',
            'x:Name="ButtonHintsContainer"\n                                   Style="{StaticResource ButtonHint.Container.CenterWrap}"\n                                   HorizontalAlignment="Center"\n                                   HorizontalContentAlignment="Center"\n                                   VerticalAlignment="Bottom"\n                                   Width="1000"',
            1,
        )
        if not any("compact centered layout" in err
                   for err in validate_native_compact_footer(wide_footer)):
            report["errors"].append("self-test failed: radial-sized footer width not rejected")
        wide_hold_button = re.sub(
            r'(<ls:LSButton x:Name="ToggleWeaponSet"[\\s\\S]*?\\bWidth=")Auto(")',
            r'\\g<1>1000\\2',
            runtime,
            count=1,
        )
        if not any("visible controller hints" in err
                   for err in validate_native_compact_footer(wide_hold_button)):
            report["errors"].append("self-test failed: overflowed native hold hint not rejected")
        removed_summon_source = runtime.replace(
            'Value="{Binding SummonHotBar.SlotList}"',
            'Value="{Binding SingleHotBar.SlotList}"',
        )
        if not any("native direct-slot" in err or "native summon overlay" in err
                   for err in validate_summon_source_route(removed_summon_source)):
            report["errors"].append("self-test failed: missing native summon slots not rejected")
        removed_sidebar_gate = runtime.replace(
            '<DataTrigger Binding="{Binding SummonHotBar.SlotList.Count, Converter={StaticResource GreaterThanConverter}, ConverterParameter=0}" Value="True">\n                                            <Setter Property="IsEnabled" Value="False"/>',
            '<DataTrigger Binding="{Binding SummonHotBar.SlotList.Count, Converter={StaticResource GreaterThanConverter}, ConverterParameter=0}" Value="True">\n                                            <Setter Property="IsEnabled" Value="True"/>',
        )
        if not any("fixed-sidebar input" in err for err in validate_summon_source_route(removed_sidebar_gate)):
            report["errors"].append("self-test failed: simultaneous summon/metamagic focus not rejected")
        removed_nested = runtime.replace(
            '<DataTrigger Binding="{Binding IsShowingItemsToThrow}" Value="True">\n                                            <Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>',
            '<DataTrigger Binding="{Binding IsShowingItemsToThrow}" Value="True">\n                                            <Setter Property="ItemsSource" Value="{Binding SummonHotBar.SlotList}"/>',
        )
        if not any("IsShowingItemsToThrow" in err for err in validate_summon_source_route(removed_nested)):
            report["errors"].append("self-test failed: summon override masking nested throw not rejected")
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
        source_ownership = (
            '<Root><ContentControl Name="SummonHotBar" '
            'Content="{Binding SummonHotBar}" '
            'ContentTemplate="{StaticResource HotBarTemplate}" '
            'Visibility="{Binding SummonHotBar.SlotList.Count}"/>'
            '<ContentControl Name="CustomHotBar" '
            'Content="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.CustomHotBar}" '
            'ContentTemplate="{StaticResource HotBarTemplate}"/></Root>'
        )
        producer_report = compare_native_action_sites(
            {"synthetic/HotBar.xaml": source_ownership},
            '<Root><LSListBox ItemsSource="{Binding KeyboardHotBars}"/></Root>',
        )
        if (len(producer_report["nativeContentProviders"]) != 2
                or len(producer_report["nativeContentProvidersWithoutSameCamBinding"]) != 2):
            report["errors"].append("self-test failed: independent native HotBar content providers were missed")
        matching_source_report = compare_native_action_sites(
            {"synthetic/HotBar.xaml": source_ownership},
            '<Root><ContentControl Content="{Binding SummonHotBar}" '
            'ContentTemplate="{StaticResource HotBarTemplate}"/></Root>',
        )
        if len(matching_source_report["nativeContentProvidersWithoutSameCamBinding"]) != 1:
            report["errors"].append("self-test failed: identical native VMHotBar source recognition")
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
