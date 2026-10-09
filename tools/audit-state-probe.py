#!/usr/bin/env python3
"""Fail-closed, source-only verification of the temporary #176 BG3 state panel.

This checks *read-only XAML wiring*, never engine semantics or gameplay correctness.
No external libraries, game files, Script Extender or runtime instrumentation.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
XAML = ROOT / "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
VERSION = ROOT / "VERSION"
PROBE_NAME = "CAM_StateProbePanel"
EXPECTED = {
    "Tag, ElementName=CAM_ProviderModeMarker",
    "Tag, ElementName=CAM_MetamagicSpellPhaseMarker",
    "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.MetamagicActive",
    "SelectedItem.ActionResource.Name, ElementName=CAM_ResourceTabs",
    "CurrentSingleHotbarFilter",
    "IsSelectingUpcastedSpell",
    "IsShowingAContainerWithVariants",
    "IsShowingItemsToThrow",
    "SingleHotBar.SlotList.Count",
    "IsEnabled, ElementName=CAM_FixedSideBarList",
    "IsEnabled, ElementName=HotBarList",
    "LocalFocus.DataContext.SlotType, ElementName=CAM_FixedSideBarList",
    "LocalFocus.DataContext.SlotType, ElementName=HotBarList",
    "Tag.SlotType, ElementName=ActionRadials",
    "Tag.CanUse, ElementName=ActionRadials",
    "Tag.Content.IsModified, ElementName=ActionRadials",
    "CurrentPlayer.SelectedCharacter.CurrentSpellTask.TargetingType",
}


def local(value: str) -> str:
    return value.rsplit("}", 1)[-1]


def attr(node: ET.Element, name: str) -> str | None:
    return next((v for k, v in node.attrib.items() if local(k) == name), None)


def audit(source: str, version: str) -> list[str]:
    errors: list[str] = []
    try:
        root = ET.fromstring(source)
    except ET.ParseError as exc:
        return [f"Invalid shipping XAML: {exc}"]

    matches = [n for n in root.iter() if attr(n, "Name") == PROBE_NAME]
    is_probing = version == "0.0.114-native-state-probe"
    if len(matches) != int(is_probing):
        errors.append(
            "Only the exact v0.0.114-native-state-probe may contain one read-only "
            "CAM_StateProbePanel. Remove it for every non-diagnostic release."
        )
        return errors
    if not is_probing:
        return errors

    panel = matches[0]
    if local(panel.tag) != "Border":
        errors.append("State panel must be a non-interactive Border")
    if attr(panel, "IsHitTestVisible") != "False" or attr(panel, "Focusable") != "False":
        errors.append("State panel must not capture focus or controller/mouse input")
    if attr(panel, "HorizontalAlignment") != "Right" or attr(panel, "VerticalAlignment") != "Top":
        errors.append("State panel must remain outside the central action grid")
    try:
        if float(attr(panel, "Width") or "9999") > 340:
            errors.append("State probe may not become a full-screen overlay")
    except ValueError:
        errors.append("State probe width must be statically bounded")

    paths: list[str] = []
    for node in panel.iter():
        tag = local(node.tag)
        if tag not in {"Border", "StackPanel", "TextBlock"}:
            errors.append(f"State panel contains non-presentation element: {tag}")
        if tag == "TextBlock" and attr(node, "Focusable") != "False":
            errors.append("State readout must not accept keyboard/controller focus")
        for key, value in node.attrib.items():
            name = local(key)
            if (name.startswith("BoundEvent") or name in
                    {"Command", "CommandParameter", "Tag", "ActionUpEvent", "ActionDownEvent",
                     "ActionPrevEvent", "ActionNextEvent"}):
                errors.append(f"Impermissible input/action/state attribute in probe: {name}")
            if "{Binding " in value:
                if name != "Text" or not value.startswith("{Binding ") or not value.endswith("}"):
                    errors.append(f"Non-text or computed diagnostic binding: {name}")
                else:
                    paths.append(value[len("{Binding "):-1])
    if len(paths) != len(EXPECTED) or set(paths) != EXPECTED:
        errors.append(
            f"Probe must bind exactly {len(EXPECTED)} original read-only properties "
            "once each; no unverified VM property or state mutation"
        )
    if attr(panel, "IsEnabled") == "True":
        errors.append("Avoid an enabled-looking interactive probe")
    return errors


def test_mutations(source: str, version: str) -> None:
    if audit(source, version):
        raise AssertionError("; ".join(audit(source, version)))
    replacements = [
        ('x:Name="CAM_StateProbePanel"', 'x:Name="CAM_RemovedPanel"'),
        ('Width="316"', 'Width="1920"'),
        ('Tag.CanUse, ElementName=ActionRadials', 'Tag.UnknownRuntimeCommand, ElementName=ActionRadials'),
        ('CurrentSingleHotbarFilter', 'CurrentSingleHotbarFilterUnknown'),
        ('<Border x:Name="CAM_StateProbePanel"', '<ls:LSButton x:Name="CAM_StateProbePanel"'),
        ('IsHitTestVisible="False"\n                    Focusable="False"', 'IsHitTestVisible="True"\n                    Focusable="False"'),
        ('</StackPanel>\n            </Border>\n\n            <Control x:Name="SlotAssignHolder"',
         '<ls:LSButton BoundEvent="UIAccept"/>\n                </StackPanel>\n            </Border>\n\n            <Control x:Name="SlotAssignHolder"'),
    ]
    for before, after in replacements:
        if before not in source:
            raise AssertionError(f"Mutant anchor missing: {before[:80]}")
        mutated = source.replace(before, after, 1)
        if not audit(mutated, version):
            raise AssertionError(f"Mutation not detected: {before[:80]}")
    if not audit(source, "0.0.115"):
        raise AssertionError("Release cleanup gate missing")
    if audit(source.replace('            <!-- #176 / v0.0.114 read-only game-state observation milestone.', '            <!-- #176 / v0.0.114 read-only game-state observation milestone.'), version):
        raise AssertionError("Unexpected source audit mutation")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    source = XAML.read_text(encoding="utf-8")
    version = VERSION.read_text(encoding="utf-8").strip()
    errors = audit(source, version)
    if errors:
        print("State probe source audit failed:\n- " + "\n- ".join(errors))
        return 1
    if args.self_test:
        test_mutations(source, version)
    print(
        f"State probe source contract OK: version {version}; "
        "17 native read-only bindings; no input, gameplay mutation or gameplay pass claimed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
