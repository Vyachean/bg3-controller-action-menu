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
    # The main grid is an actual native focus receiver; the metamagic
    # sidebar is *not* (Focusable=False). On return, the existing
    # CAM_ActionGridSlotContainer template focuses a real selected
    # ListBoxItem if its parent Tag holds CAM_ResetFirstFocusToken.
    fallback_main_focus = any(
        local(a) == "SetMoveFocusAction"
        and _attribute(a.attrib, "FocusElement") == "{Binding ElementName=HotBarList}"
        for t in exit_triggers for a in t.iter()
    )
    fallback_sidebar_item = any(
        all(any(
            local(a) == "ChangePropertyAction"
            and _attribute(a.attrib, "TargetName") == "CAM_FixedSideBarList"
            and _attribute(a.attrib, "PropertyName") == prop
            and _attribute(a.attrib, "Value") == value
            for a in t.iter()
        ) for prop, value in (
            ("Tag", "{StaticResource CAM_ResetFirstFocusToken}"),
            ("SelectedIndex", "-1"), ("SelectedIndex", "0")))
        for t in exit_triggers
    )
    invalid_sidebar_focus = any(
        local(a) == "SetMoveFocusAction"
        and "CAM_FixedSideBarList" in (_attribute(a.attrib, "FocusElement") or "")
        for t in exit_triggers for a in t.iter()
    )
    if (len(cleanup) != 1 or not fallback_main_focus
            or not fallback_sidebar_item or invalid_sidebar_focus):
        errors.append(
            "Native summon exit must clear stale dispatch and restore native "
            "focus through main list or concrete sidebar ListBoxItem"
        )
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
    """Guard two independent, captured Patch 8 controller-hint contracts.

    The original controller defines a wide right/right/RTL variant and a
    narrow center/center/LTR auto-width variant. Mixing their internal
    geometry in one AlignableWrapPanel produced the 0.0.114 horizontal
    alignment regression. The *outer* CAM lane stays right-aligned away
    from the bottom resource HUD; the *inner* native compact arrangement
    retains center/center/LTR and auto-width controls. This source
    contract does not certify pixel alignment in Noesis at every scale.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"invalid CAM XAML for controller hint layout: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    lanes = [
        n for n in root.iter()
        if local(n) == "Grid"
        and _attribute(n.attrib, "Name") == "CAM_ControllerHintRightLane"
    ]
    panels = [
        n for n in root.iter()
        if local(n) == "AlignableWrapPanel"
        and _attribute(n.attrib, "Name") == "ButtonHintsContainer"
    ]
    if len(lanes) != 1 or len(panels) != 1:
        return ["exactly one separate right-side hint lane and native compact panel required"]
    lane, panel = lanes[0], panels[0]
    lane_expected = {
        "MaxWidth": "600",
        "HorizontalAlignment": "Right",
        "VerticalAlignment": "Bottom",
        "Margin": "26,0,26,56",
    }
    compact_expected = {
        "Width": "Auto",
        "HorizontalAlignment": "Center",
        "HorizontalContentAlignment": "Center",
        "VerticalAlignment": "Bottom",
        "FlowDirection": "LeftToRight",
        "Margin": "0",
        "Style": "{StaticResource ButtonHint.Container.CenterWrap}",
    }
    if any(_attribute(lane.attrib, key) != value
           for key, value in lane_expected.items()):
        return ["hint outer lane must remain bounded and right-aligned outside center resource HUD"]
    if panel not in list(lane):
        return ["native compact hint panel must be a direct child of the right-side lane"]
    if any(_attribute(panel.attrib, key) != value
           for key, value in compact_expected.items()):
        return ["inner hint layout must preserve the original compact center/center/LTR order"]
    if _attribute(panel.attrib, "MaxWidth") is not None:
        return ["only the outer right lane may constrain compact native hint width"]

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



def validate_native_shoulder_entry_tabs(runtime: str) -> list[str]:
    """Opening direction is provided by ActionRadials.Metadata in Patch 8.

    MoveToEnd is emitted by OpenActionRadialsEnd. This is an entry-time
    choice, not permission to remap the working UITabPrev/UITabNext flow.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"cannot inspect original controller opening direction in invalid XAML: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    def named(name: str) -> list[ET.Element]:
        return [node for node in root.iter()
                if _attribute(node.attrib, "Name") == name]

    tabs = named("CAM_ResourceTabs")
    top_rows = named("CAM_TopTabs")
    if len(tabs) != 1 or len(top_rows) != 1:
        return ["original controller opening direction needs the existing single resource tab row"]

    row = top_rows[0]
    order = [_attribute(n.attrib, "Name") for n in row
             if _attribute(n.attrib, "Name")]
    if not order or order[0] != "CAM_ResourceTabs" or order[-1] != "CAM_AllTab":
        return ["native opening-direction first and last tabs must stay resource and All"]

    triggers = [t for t in tabs[0].iter()
                if local(t) == "EventTrigger"
                and _attribute(t.attrib, "EventName") == "Loaded"]
    if len(triggers) != 2:
        return ["native RB/LB menu opening requires exactly two Loaded branches"]

    branches: dict[str, ET.Element] = {}
    for trigger in triggers:
        conditions = [
            condition for condition in trigger.iter()
            if local(condition) == "ComparisonCondition"
            and _attribute(condition.attrib, "LeftOperand")
                == "{Binding Metadata, ElementName=ActionRadials}"
        ]
        if len(conditions) != 1 or _attribute(conditions[0].attrib, "RightOperand") != "MoveToEnd":
            return ["native RB/LB menu opening must use exact MoveToEnd metadata"]
        direction = _attribute(conditions[0].attrib, "Operator")
        if direction not in ("Equal", "NotEqual") or direction in branches:
            return ["native RB/LB menu opening must keep opposite metadata guards"]
        branches[direction] = trigger

    if set(branches) != {"Equal", "NotEqual"}:
        return ["native RB/LB menu opening must keep opposite metadata guards"]

    def actions(trigger: ET.Element) -> list[ET.Element]:
        return [node for node in trigger
                if local(node) in ("ChangePropertyAction", "InvokeCommandAction")]

    first = actions(branches["NotEqual"])
    last = actions(branches["Equal"])
    def change_to(action: ET.Element, target: str, prop: str, value: str) -> bool:
        return (
            local(action) == "ChangePropertyAction"
            and _attribute(action.attrib, "TargetName") == target
            and _attribute(action.attrib, "PropertyName") == prop
            and _attribute(action.attrib, "Value") == value
        )
    if not any(change_to(a, "CAM_ProviderModeMarker", "Tag", "{x:Null}") for a in first):
        return ["native RB opening must select the first resource provider"]
    if not any(local(a) == "InvokeCommandAction"
               and _attribute(a.attrib, "Command") == "{Binding FilterActionResourceCommand}"
               and _attribute(a.attrib, "CommandParameter") == "{Binding SelectedItem, ElementName=CAM_ResourceTabs}"
               for a in first):
        return ["native RB opening must apply its first resource filter"]
    if not any(change_to(a, "CAM_ProviderModeMarker", "Tag",
                         "{StaticResource CAM_AllModeToken}") for a in last):
        return ["native LB opening must select the final All provider"]
    if not any(change_to(a, "HotBarList", "SelectedIndex", "-1") for a in last):
        return ["native LB opening must clear stale first-resource selection"]
    if any(local(a) == "InvokeCommandAction" for a in last):
        return ["native LB opening must not run the first-resource filter"]

    # Initial playback is already owned by the game/controller focus lifecycle.
    # The added MoveToEnd LSPlaySound in v0.0.111 caused an audible duplicate;
    # do not create standalone sound in either Loaded direction. This check
    # does not claim that LB vibration is repaired.
    for branch in (branches["Equal"], branches["NotEqual"]):
        if any(local(node) == "LSPlaySound" for node in branch):
            return ["native RB/LB Loaded branches must not duplicate game-owned opening sound"]

    timers = [n for n in tabs[0].iter()
              if local(n) == "TimerTrigger"
              and _attribute(n.attrib, "EventName") == "Loaded"]
    if len(timers) != 1 or (
        _attribute(timers[0].attrib, "MillisecondsPerTick") != "70"
        or _attribute(timers[0].attrib, "TotalTicks") != "1"
    ):
        return ["native opening direction must preserve common 70ms first-slot focus handoff"]
    timer_actions = actions(timers[0])
    if not all(any(change_to(a, "HotBarList", prop, value) for a in timer_actions)
               for prop, value in (
                   ("LocalFocus", "{x:Null}"),
                   ("Tag", "{StaticResource CAM_ResetFirstFocusToken}"),
                   ("SelectedIndex", "0"),
               )):
        return ["native RB/LB opening must select a concrete first executable slot"]

    if not named("CAM_TabLeft") or not named("CAM_TabRight"):
        return ["native shoulder opening must not remove ordinary tab navigation"]
    return []



def validate_native_resource_name(runtime: str) -> list[str]:
    """Keep the selected native resource name separate from original tab icons.

    Native Tooltips.xaml:8253 supplies ActionResource.Name. Special providers
    are CAM UI modes; visible English fallback titles are explicit until
    their Patch 8 locale handles have been captured and verified.
    """
    try:
        root = ET.fromstring(runtime)
    except ET.ParseError as exc:
        return [f"cannot inspect native resource label in invalid CAM XAML: {exc}"]

    def local(node: ET.Element) -> str:
        return node.tag.rsplit("}", 1)[-1]

    def named(name: str) -> list[ET.Element]:
        return [node for node in root.iter()
                if _attribute(node.attrib, "Name") == name]

    names = ("CAM_AutoCatalogFocusRoot", "CAM_SelectedTabTitleArea",
             "CAM_SelectedResourceName", "CAM_ResourceHeader",
             "CAM_ResourceStrip", "CAM_ResourceTabs", "CAM_ActionRowClip")
    matches = {name: named(name) for name in names}
    if any(len(items) != 1 for items in matches.values()):
        return ["resource title needs exactly one reserved title row, tab strip and viewport"]
    main, title, caption, header, strip, tabs, viewport = (
        matches[name][0] for name in names
    )
    if title not in list(main) or caption not in list(title) or header not in list(main):
        return ["resource title must use a separate root row, never a visual strip overlay"]
    if local(caption) != "TextBlock" or caption in list(strip):
        return ["resource title must not overlay the native resource tab strip"]

    if (_attribute(main.attrib, "Height") != "998"
            or _attribute(title.attrib, "Grid.Row") != "0"
            or _attribute(title.attrib, "Height") != "64"
            or _attribute(header.attrib, "Grid.Row") != "1"
            or _attribute(header.attrib, "Height") != "84"
            or _attribute(viewport.attrib, "Grid.Row") != "2"
            or _attribute(viewport.attrib, "Height") != "850"
            or _attribute(strip.attrib, "Height") != "84"):
        return ["resource title layout must reserve 64px without resizing 84px tabs or 850px action viewport"]
    rowdefs = [child for x in main if local(x) == "Grid.RowDefinitions"
               for child in x if local(child) == "RowDefinition"]
    if [_attribute(row.attrib, "Height") for row in rowdefs] != ["64", "84", "850"]:
        return ["resource title must occupy a dedicated 64px row above native tabs"]
    transforms = [child for x in main if local(x) == "Grid.RenderTransform"
                  for child in x.iter() if local(child) == "TranslateTransform"]
    if len(transforms) != 1 or _attribute(transforms[0].attrib, "Y") != "-32":
        return ["resource title must retain original screen coordinates of tabs and action grid"]

    if (not all(_attribute(caption.attrib, key) == value for key, value in {
            "IsHitTestVisible": "False",
            "Focusable": "False",
            "TextWrapping": "NoWrap",
            "HorizontalAlignment": "Center",
            "VerticalAlignment": "Top",
            "Margin": "0,4,0,0",
            "FontSize": "{DynamicResource MediumFontSize}",
        }.items())
            or _attribute(caption.attrib, "Text") is not None
            or _attribute(caption.attrib, "Height") is not None
            or _attribute(caption.attrib, "ClipToBounds") == "True"
            or _attribute(title.attrib, "ClipToBounds") != "True"):
        return ["selected tab title must fit dynamic font metrics without a fixed-height descender clip"]

    styles = [x for x in caption if local(x) == "TextBlock.Style"]
    if len(styles) != 1:
        return ["selected tab title needs its native resource binding and provider labels"]
    setters = [x for x in styles[0].iter() if local(x) == "Setter"]
    native_resource_name = "{Binding SelectedItem.ActionResource.Name, ElementName=CAM_ResourceTabs}"
    if not any(_attribute(x.attrib, "Property") == "Text"
               and _attribute(x.attrib, "Value") == native_resource_name for x in setters):
        return ["game-owned ActionResource.Name must be the default selected resource title"]
    expected = {
        "CAM_CantripsModeToken": "Cantrips",
        "CAM_ItemsModeToken": "Items",
        "CAM_MetamagicModeToken": "Metamagic",
        "CAM_PassivesModeToken": "Passives",
        "CAM_AllModeToken": "All",
    }
    seen = {}
    for trig in styles[0].iter():
        if local(trig) != "DataTrigger":
            continue
        mode = _attribute(trig.attrib, "Value")
        prefix = "{StaticResource "
        if not mode or not mode.startswith(prefix) or not mode.endswith("}"):
            continue
        token = mode[len(prefix):-1]
        if token not in expected:
            continue
        if _attribute(trig.attrib, "Binding") != "{Binding Tag, ElementName=CAM_ProviderModeMarker}":
            return ["provider titles must be selected only by current CAM provider state"]
        labels = [_attribute(x.attrib, "Value") for x in trig
                  if local(x) == "Setter" and _attribute(x.attrib, "Property") == "Text"]
        if len(labels) != 1 or token in seen:
            return ["selected tab title requires one caption for every special provider"]
        seen[token] = labels[0]
    if seen != expected:
        return ["selected tab title requires one explicit fallback name for every provider"]
    if not any(_attribute(n.attrib, "Name") == "CAM_HotbarBodyResourcesBg"
               for n in strip):
        return ["selected tab title must preserve original BG3 resource glyphs"]
    return []


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
    errors.extend(validate_native_shoulder_entry_tabs(runtime))
    errors.extend(validate_native_resource_name(runtime))
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
        centered_footer = runtime.replace(
            'x:Name="CAM_ControllerHintRightLane"\n                  HorizontalAlignment="Right"',
            'x:Name="CAM_ControllerHintRightLane"\n                  HorizontalAlignment="Center"',
            1,
        )
        if not any("right-aligned" in err
                   for err in validate_native_compact_footer(centered_footer)):
            report["errors"].append("self-test failed: centered outer footer overlapping HUD not rejected")
        wide_footer = runtime.replace(
            'x:Name="CAM_ControllerHintRightLane"\n                  HorizontalAlignment="Right"\n                  VerticalAlignment="Bottom"\n                  MaxWidth="600"',
            'x:Name="CAM_ControllerHintRightLane"\n                  HorizontalAlignment="Right"\n                  VerticalAlignment="Bottom"\n                  MaxWidth="1320"',
            1,
        )
        if not any("right-aligned" in err
                   for err in validate_native_compact_footer(wide_footer)):
            report["errors"].append("self-test failed: unbounded outer footer not rejected")
        mirrored_hints = runtime.replace(
            'FlowDirection="LeftToRight"\n                                       Margin="0"',
            'FlowDirection="RightToLeft"\n                                       Margin="0"',
            1,
        )
        if not any("original compact" in err
                   for err in validate_native_compact_footer(mirrored_hints)):
            report["errors"].append("self-test failed: RTL compact hint content not rejected")
        wide_hold_button = re.sub(
            r'(<ls:LSButton x:Name="ToggleWeaponSet"[\s\S]*?\bWidth=")Auto(")',
            r'\g<1>1000\2',
            runtime,
            count=1,
        )
        if not any("visible controller hints" in err
                   for err in validate_native_compact_footer(wide_hold_button)):
            report["errors"].append("self-test failed: overflowed native hold hint not rejected")
        wrong_open_direction = runtime.replace(
            'Operator="Equal" RightOperand="MoveToEnd"/>',
            'Operator="NotEqual" RightOperand="MoveToEnd"/>',
            1,
        )
        if not any("opposite metadata guards" in err
                   for err in validate_native_shoulder_entry_tabs(wrong_open_direction)):
            report["errors"].append("self-test failed: matching LB and RB entry guards not rejected")
        duplicate_lb_entry_sound = runtime.replace(
            '                                    <b:ChangePropertyAction TargetName="HotBarList" PropertyName="SelectedIndex" Value="-1"/>\n                                </b:EventTrigger>',
            '                                    <b:ChangePropertyAction TargetName="HotBarList" PropertyName="SelectedIndex" Value="-1"/>\n                                    <ls:LSPlaySound Sound="UI_HUD_Controller_RadialMenu_SlotHover"/>\n                                </b:EventTrigger>',
            1,
        )
        if duplicate_lb_entry_sound == runtime or not any(
            "must not duplicate game-owned opening sound" in err
            for err in validate_native_shoulder_entry_tabs(duplicate_lb_entry_sound)
        ):
            report["errors"].append("self-test failed: duplicate LB opening sound not rejected")

        wrong_last_provider = runtime.replace(
            'TargetName="CAM_ProviderModeMarker" PropertyName="Tag"\n                                                            Value="{StaticResource CAM_AllModeToken}"/>',
            'TargetName="CAM_ProviderModeMarker" PropertyName="Tag"\n                                                            Value="{StaticResource CAM_ItemsModeToken}"/>',
            1,
        )
        if not any("final All provider" in err
                   for err in validate_native_shoulder_entry_tabs(wrong_last_provider)):
            report["errors"].append("self-test failed: LB opening wrong last tab not rejected")
        wrong_open_focus = runtime.replace(
            '<b:TimerTrigger EventName="Loaded" MillisecondsPerTick="70" TotalTicks="1">',
            '<b:TimerTrigger EventName="Loaded" MillisecondsPerTick="0" TotalTicks="1">',
            1,
        )
        if not any("70ms first-slot focus" in err
                   for err in validate_native_shoulder_entry_tabs(wrong_open_focus)):
            report["errors"].append("self-test failed: opening direction focus race not rejected")
        clipped_resource_title = runtime.replace(
            '                                   Margin="0,4,0,0"\n                                   MaxWidth="760"',
            '                                   ClipToBounds="True"\n                                   Height="44"\n                                   MaxWidth="760"',
            1,
        )
        if clipped_resource_title == runtime or not any(
            "descender clip" in err
            for err in validate_native_resource_name(clipped_resource_title)
        ):
            report["errors"].append("self-test failed: clipped resource title text not rejected")
        substituted_resource_name = runtime.replace(
            '<Setter Property="Text" Value="{Binding SelectedItem.ActionResource.Name, ElementName=CAM_ResourceTabs}"/>',
            '<Setter Property="Text" Value="Reaction"/>',
            1,
        )
        if not any("game-owned ActionResource.Name" in err
                   for err in validate_native_resource_name(substituted_resource_name)):
            report["errors"].append("self-test failed: hardcoded resource identity not rejected")
        misplaced_title = runtime.replace(
            'x:Name="CAM_SelectedTabTitleArea"\n                          Grid.Row="0"',
            'x:Name="CAM_SelectedTabTitleArea"\n                          Grid.Row="1"',
            1,
        )
        if not any("reserve 64px" in err for err in validate_native_resource_name(misplaced_title)):
            report["errors"].append("self-test failed: overlapping selected title not rejected")
        missing_provider_title = runtime.replace(
            '<Setter Property="Text" Value="Cantrips"/>',
            '<Setter Property="Text" Value=""/>',
            1,
        )
        if not any("fallback name for every provider" in err
                   for err in validate_native_resource_name(missing_provider_title)):
            report["errors"].append("self-test failed: missing special provider title not rejected")
        title_moved_tab_strip = runtime.replace(
            '<TranslateTransform Y="-32"/>',
            '<TranslateTransform Y="0"/>',
            1,
        )
        if not any("original screen coordinates" in err
                   for err in validate_native_resource_name(title_moved_tab_strip)):
            report["errors"].append("self-test failed: shifted native action viewport not rejected")
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
