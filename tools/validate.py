#!/usr/bin/env python3
"""Repository-level static validation for the self-contained no-SE package."""

from __future__ import annotations

import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "BG3ControllerActionMenu"
MOD_ROOT = PACKAGE_ROOT / "Mods/BG3ControllerActionMenu"
VERSION = ROOT / "VERSION"

XBOX_INSTALLER = ROOT / "tools/install-xbox-dev.ps1"
DEV_ENTRY = ROOT / "tools/dev-entry.ps1"
DEV_ENTRY_TEST = ROOT / "tools/test-dev-entry.ps1"
STANDALONE_VBS_TEST = ROOT / "tools/test-standalone-vbs.ps1"
LATEST_INSTALLER = ROOT / "tools/install-latest.ps1"
LATEST_INSTALLER_TEST = ROOT / "tools/test-install-latest.ps1"
ONE_CLICK_LAUNCHER = ROOT / "tools/Install-BG3ControllerActionMenu.vbs"
ONE_CLICK_BUILDER = ROOT / "tools/build-one-click-installer.ps1"
SELF_CONTAINED_RUNTIME = MOD_ROOT / "GUI/Library/Lib_Controller.xaml"
SELF_CONTAINED_RUNTIME_TEST = ROOT / "tools/test-self-contained-runtime.ps1"
PATCH8_RUNTIME_EVIDENCE = ROOT / "docs/evidence/patch8-1.8.910.0-runtime-contract.json"
NATIVE_CAPTURE = ROOT / "tools/capture-native-radials.ps1"
DEV_CAPTURE = ROOT / "tools/capture-self-contained-inputs.ps1"
DEV_CAPTURE_TEST = ROOT / "tools/test-dev-capture.ps1"
DEVELOPMENT_VBS_DOC = ROOT / "docs/development-vbs.md"
SELF_CONTAINED_RELEASE_GUARD = ROOT / "tools/assert-self-contained-release.ps1"
BUILD_WORKFLOW = ROOT / ".github/workflows/build.yml"
RELEASE_WORKFLOW = ROOT / ".github/workflows/release.yml"

FORBIDDEN_STATIC_RUNTIME_PATHS = [
    # Never publish copied game-owned resource paths. Self-contained CAM runtime
    # resources must live under Mods/BG3ControllerActionMenu.
    PACKAGE_ROOT / "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml",
    PACKAGE_ROOT / "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml",
]

IGNORED_DIRS = {".git", ".local", "build", "dist", "artifacts", "extracted", "game-data", "toolkit-data"}
XML_SUFFIXES = {".xaml", ".xml", ".lsx"}


def iter_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRS for part in path.relative_to(ROOT).parts):
            continue
        yield path


def validate_xml(path: Path) -> list[str]:
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        return [f"{path.relative_to(ROOT)}: XML parse error: {exc}"]
    return []


def require_text(path: Path, required: list[str]) -> list[str]:
    if not path.exists():
        return [f"{path.relative_to(ROOT)}: required file is missing"]

    text = path.read_text(encoding="utf-8")
    return [
        f"{path.relative_to(ROOT)}: missing required integration seam: {needle}"
        for needle in required
        if needle not in text
    ]


def validate_semantics() -> list[str]:
    errors: list[str] = []

    if not (MOD_ROOT / "meta.lsx").exists():
        errors.append("BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/meta.lsx: required file is missing")

    script_extender = MOD_ROOT / "ScriptExtender"
    if script_extender.exists():
        errors.append(
            f"{script_extender.relative_to(ROOT)}: runtime package must not contain Script Extender files"
        )

    # Raw copied game resources are forbidden. Project-owned self-contained
    # runtime XAML belongs under Mods/BG3ControllerActionMenu and is expected
    # once the migration is completed.
    for forbidden_path in FORBIDDEN_STATIC_RUNTIME_PATHS:
        if forbidden_path.exists():
            errors.append(
                f"{forbidden_path.relative_to(ROOT)}: copied game-owned runtime XAML path is forbidden"
            )

    errors.extend(
        require_text(
            SELF_CONTAINED_RUNTIME,
            [
                'x:Key="ActionRadialWidgetTemplate_P8"',
                'x:Name="CAM_ResourceTabs"',
                'CurrentPlayer.UIData.ActionResourcesCostPreview',
                'x:Name="CAM_ActionViewport"',
                'CanContentScroll="False"',
                'Text="{Binding ActionResource.TypeId}"',
                'Property="ls:MoveFocus.Focusable" Value="True"',
                'Setter Property="FocusVisualStyle" Value="{x:Null}"',
                'x:Key="CAM_ResetFirstFocusToken"',
                'x:Key="CAM_NestedEnteredToken"',
                'x:Key="CAM_NestedRestoringToken"',
                'x:Name="CAM_NestedReturnMarker"',
                'ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"',
                'b:DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"',
                'RightOperand="{StaticResource CAM_ResetFirstFocusToken}"',
                'FocusElement="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"',
                'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
                    'Template="{StaticResource SelectorTemplate}"',
                'EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"',
                'Binding="{Binding ActionResource.Name}" Value=""',
                'Converter="{StaticResource DivideMultiConverter}" ConverterParameter="Floor"',
                'AncestorType={x:Type ScrollContentPresenter}',
                'PropertyName="SelectedIndex" Value="-1"',
                'Value="{StaticResource CAM_ResetFirstFocusToken}"',
                'FilterActionResourceCommand',
                'SingleHotBar.SlotList',
                'ActionResource.Name',
                'RomanNumeralLevelImage',
                'x:Name="HotBarList"',
                'ItemsSource="{Binding SingleHotBar.SlotList}"',
                'ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"',
                'ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"',
                'ItemsPanel="{StaticResource CAM_ActionGridPanel}"',
                'KeyboardNavigation.DirectionalNavigation="Contained"',
                'ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"',
                'LocalFocus.DataContext',
                'MillisecondsPerTick="70"',
                'CreateFocusedTooltipDataCommand',
                'HighlightResourcesCommand',
                'ShowTooltipOnUIElementCommand',
                'Command="{Binding UseSlotCommand}"',
                'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
                'Command="{Binding ClearSingleHotbarCommand}"',
                'x:Name="ButtonHintsContainer"',
                'ActionLeftEvent="UILeft"',
                'x:Name="ShowContextMenu"',
                'Command="{x:Null}"',
            ],
        )
    )

    errors.extend(
        require_text(
            SELF_CONTAINED_RUNTIME_TEST,
            [
                "1.8.910.0",
                "LocalFocus.DataContext",
                "LocalFocus.Tag",
                "PlayerCharacterProperties.ControllerHotBars",
                "ShowContextMenuCommand",
                "Self-contained Patch 8 runtime contract passed",
            ],
        )
    )

    errors.extend(
        require_text(
            PATCH8_RUNTIME_EVIDENCE,
            [
                '"gamePackageVersion": "1.8.910.0"',
                '"focusValuePath": "LocalFocus.DataContext"',
                '"selectorHasFixedGeometry": false',
                '"mode": "resource-first"',
                '"primaryTabSource": "CurrentPlayer.UIData.ActionResourcesCostPreview"',
                '"detailsSurface": "native-tooltip-only"',
                '"executableList": "HotBarList"',
                '"itemsSource": "SingleHotBar.SlotList"',
                '"nestedStateUsesSameList": true',
                '"focusPresentation": "native-selector:LocalFocusSelector; live-owner:LocalFocus.DataContext"',
                '"visibleFocusSource": "HotBarList.LocalFocus via SelectorTemplate"',
                '"visibleFocusSyncEvent": null',
                '"visibleFocusSyncValue": null',
                '"source": "ScrollContentPresenter.ActualWidth"',
                '"converter": "DivideMultiConverter"',
                '"rounding": "Floor"',
                '"directGridDisableScrolling": false',
                '"scrollViewerCanContentScroll": false',
                '"gridUseWidgetNavigation": false',
                '"gridAlwaysSelectFirst": false',
                '"gridExtendedRows": null',
                '"emptyCellTemplate": "DynamicResource EmptyCellTemplate"',
                '"gridInternalFocusable": false',
                '"autoScrollBehavior": null',
                '"bringSelectionIntoView": null',
                '"scrollIntoView": "CAM_ResourceTabs.Tag"',
                '"scrollTo": null',
                '"scrollTargetKind": "selected ListBoxItem UIElement"',
                '"selectedContainerPublishesTag": true',
                '"scrollBindingSource": "templated-parent.Tag"',
                '"crossTemplateElementName": false',
                '"cycleForceSelect": false',
                '"scrollOwner": "LSScrollViewer.ScrollToElement"',
                '"hiddenPreviewSelection": "collapsed+disabled; ordinary cycle only"',
                '"visibleFocusVisualStyle": null',
                '"clearSelectedIndex": -1',
                '"filterCommandCount": 1',
                '"settleMilliseconds": 70',
                '"armToken": "CAM_ResetFirstFocusToken"',
                '"restoreSelectedIndex": 0',
                '"focusTarget": "selected concrete ListBoxItem templated parent"',
                '"focusAction": "SetMoveFocusAction(DeferFocusAction=True)"',
                '"clearsTokenAfterFocus": true',
                '"clearLocalFocus": true',
                '"invalidateFocus": false',
                '"focusesListContainer": false',
                '"selectedItemMirrorsLocalFocus": false',
                '"entryStateSource": "PropertyChangedTrigger(LocalFocus.DataContext) after LocalFocus reset + concrete-item handoff"',
                '"selectedItemEntryStateWrites": false',
                '"selector": "CAM_MainSelector"',
                '"selectorTemplate": "SelectorTemplate"',
                '"selectorVisibleChrome": true',
                '"selectorOpacity": 1',
                '"marker": "CAM_NestedReturnMarker"',
                '"enterToken": "CAM_NestedEnteredToken"',
                '"restoringToken": "CAM_NestedRestoringToken"',
                '"restoreCommand": "FilterActionResourceCommand"',
                '"restoreParameter": "CAM_ResourceTabs.SelectedItem"',
                '"repopulationSignal": "SingleHotBar.SlotList.Count > 0"',
                '"topLevelCloseRestoresFilter": false',
                '"presentationSignal": "PropertyChangedTrigger(LocalFocus.DataContext)"',
                '"localFocusChangedRole": "hover-sound-only"',
                '"delayedLocalFocusPresentationTimer": false',
                '"Public/Game/GUI/Library/PreloadedActionRadials_c.xaml": "4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b"',
                '"Mods/MainUI/GUI/Pages/HotBar.xaml": "9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728"',
            ],
        )
    )

    if SELF_CONTAINED_RUNTIME.exists():
        runtime_text = SELF_CONTAINED_RUNTIME.read_text(encoding="utf-8")
        for forbidden in (
            "LocalFocus.Tag",
            "CAM_FilterTabs",
            "CAM_CommonFilterTab",
            "CAM_ClassFilterTab",
            "CAM_CantripsFilterTab",
            "CAM_ItemsFilterTab",
            "CAM_PassivesFilterTab",
            "SetCurrentShownDeckCommand",
            "FilterCantripsCommand",
            "CurrentShownDeck.SlotList",
            "PassivesHotBar.SlotList",
            "CAM_ResourceFilterHolder",
            "ResourceFilterBinding",
            "LiveDetails",
            'x:Name="CAM_FilteredSlotList"',
            'x:Name="CAM_FilteredSlotHolder"',
            'x:Name="SingleBar"',
            'x:Name="singleBarHolder"',
            'x:Name="CAM_SingleSelector"',
            'x:Name="CAM_SingleActionTooltip"',
            "PlayerCharacterProperties.ControllerHotBars",
            "PlayerCharacterProperties.SpellsAndActions",
            "CurrentPlayer.SelectedCharacter.Inventory.Slots",
            "CurrentPlayer.SelectedCharacter.Stats.Passives",
            "ShowContextMenuCommand",
            "AssignSlotCommand",
            "SwapSlotCommand",
            "AddRadialCommand",
            "RemoveRadialCommand",
            'x:Key="CAM_SelectorTemplate"',
            'x:Name="ToggleWeaponSet"',
            'x:Name="WeaponSetShortcutBinding"',
            'SwitchWeaponSetCommand',
            'HoldTime="{StaticResource HoldTimeShortcuts}"',
            'SpellSlotNumberStyle',
            'Trigger Property="ls:MoveFocus.IsFocused" Value="True"',
            'Value="{StaticResource Style.FocusVisualStyle}"',
            'ForceSelect="True"',
            'x:Name="CAM_LogicalFocusAnchor"',
            'x:Name="CAM_CellFocusFill"',
            'x:Name="CAM_CellFocusFrame"',
            'AlwaysSelectFirst="True"',
            'ExtendedRows="False"',
            'InvalidateFocus="True"',
            '<ls:AutoScrollBehavior',
            'ls:LSScrollViewer.ScrollToElement="{Binding Tag, ElementName=CAM_ResourceTabs}"',
            '<b:TimerTrigger EventName="LocalFocusChanged"',
            'TextTrimming="CharacterEllipsis"',
            'Columns="5"',
            'Width="632"',
            'CanContentScroll="True"',
            'DisableScrolling="True"',
            "Public/Game/GUI/",
            "ScriptExtender",
        ):
            if forbidden in runtime_text:
                errors.append(
                    f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: forbidden obsolete/native-copy seam: {forbidden}"
                )

    for obsolete in (
        ROOT / "tools/native-overlay.ps1",
        ROOT / "tools/test-native-overlay.ps1",
        ROOT / "tools/prepare-self-contained-reference.ps1",
        ROOT / "tools/test-self-contained-reference.ps1",
        ROOT / "tools/bootstrap-latest.ps1",
        ROOT / "tools/test-bootstrap-latest.ps1",
        ROOT / "tools/Capture-BG3ControllerArtifacts.vbs",
        ROOT / "tools/build-dev-capture.ps1",
    ):
        if obsolete.exists():
            errors.append(
                f"{obsolete.relative_to(ROOT)}: obsolete install-time derivation/reference tool must be removed"
            )

    errors.extend(
        require_text(
            XBOX_INSTALLER,
            [
                "[switch]$Apply",
                "Get-AppxPackage",
                "LocalCache\\Local",
                "ExistingPakFound",
                "ReusableModSettingsSchemaFound",
                "WriteSchemaReady",
                "SelectedModSettings",
                "PlayerProfiles",
                "ReadyForApply",
                "Refusing to modify Xbox data",
                "BG3ControllerActionMenu-backups",
                "The release PAK is self-contained",
                "Copy-Item -LiteralPath $PackagePath -Destination $destPak -Force",
            ],
        )
    )

    if XBOX_INSTALLER.exists():
        xbox_text = XBOX_INSTALLER.read_text(encoding="utf-8")
        for forbidden in (
            "NativeOverlayPath",
            "native-overlay.ps1",
            "Game.pak",
            "divine.exe",
            "--action extract-single-file",
            "--action create-package",
            "BG3ControllerActionMenu-native-derived.pak",
        ):
            if forbidden in xbox_text:
                errors.append(
                    f"{XBOX_INSTALLER.relative_to(ROOT)}: normal installer must install the self-contained PAK directly: {forbidden}"
                )

    errors.extend(
        require_text(
            DEV_ENTRY,
            [
                "releases?per_page=20",
                'install-latest.ps1',
                "ReleaseMetadataPath",
                "foreach ($release in @($payload))",
                "Save-Asset",
                "LauncherRoot",
                'Task = "install"',
                "Current release task: install/update the self-contained PAK.",
                "& $installer @installerArgs",
                "failures propagate as terminating exceptions",
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_ENTRY_TEST,
            [
                "Universal release-controlled development entry fixture passed.",
                "Release-controlled helper was not executed.",
                'cmd.exe /c "exit 23"',
                "must use exception semantics instead",
            ],
        )
    )

    errors.extend(
        require_text(
            STANDALONE_VBS_TEST,
            [
                "one VBS in an otherwise empty",
                "--resolve-only",
                "--no-ui",
                "launcher-bootstrap.log",
                "Standalone one-file VBS bootstrap fixture passed",
            ],
        )
    )

    errors.extend(
        require_text(
            LATEST_INSTALLER,
            [
                "releases?per_page=20",
                "Sort-Object { [DateTimeOffset]$_.published_at } -Descending",
                'BG3ControllerActionMenu-$version.pak',
                'install-xbox-dev.ps1',
                "browser_download_url",
                "Save-Asset",
                "& $xboxPath -Apply -PackagePath $pakPath -ReportPath $ReportPath",
                "Update-DevelopmentLauncher",
                '"Install-BG3ControllerActionMenu.vbs"',
                'success contract is "returned without a terminating',
                "$global:LASTEXITCODE = 0",
                "Compatibility only: obsolete bootstrap-latest.ps1 callers",
                "install-status.txt",
                "xbox-dev-environment.json",
            ],
        )
    )

    errors.extend(
        require_text(
            LATEST_INSTALLER_TEST,
            [
                'cmd.exe /c "exit 37"',
                "return normally without calling exit",
                "mistake that value for",
            ],
        )
    )

    if DEV_ENTRY.exists() and "exit $LASTEXITCODE" in DEV_ENTRY.read_text(encoding="utf-8"):
        errors.append(
            f"{DEV_ENTRY.relative_to(ROOT)}: in-process PowerShell helper result must not be taken from LASTEXITCODE"
        )

    if LATEST_INSTALLER.exists():
        latest_text = LATEST_INSTALLER.read_text(encoding="utf-8")
        if 'if ($LASTEXITCODE -ne 0)' in latest_text:
            errors.append(
                f"{LATEST_INSTALLER.relative_to(ROOT)}: in-process PowerShell helper result must use exception semantics"
            )
        for forbidden in (
            "native-overlay.ps1",
            "NativeOverlayPath",
            "Game.pak",
            "divine.exe",
            "--action extract-single-file",
            "--action create-package",
        ):
            if forbidden in latest_text:
                errors.append(
                    f"{LATEST_INSTALLER.relative_to(ROOT)}: canonical installer must not rebuild the release PAK: {forbidden}"
                )

    for runtime_installer in (LATEST_INSTALLER,):
        if runtime_installer.exists():
            runtime_text = runtime_installer.read_text(encoding="utf-8")
            for forbidden in (
                "Get-FileHash",
                "Assert-AssetDigest",
                "Save-VerifiedReleaseAsset",
                "Assert-CurrentHotBarFilterContract",
                "missing required filter seam",
                "Packed controller library is missing required seam",
                "Generated controller library is missing required seam",
            ):
                if forbidden in runtime_text:
                    errors.append(
                        f"{runtime_installer.relative_to(ROOT)}: install-time validation is forbidden: {forbidden}"
                    )

    errors.extend(
        require_text(
            ONE_CLICK_LAUNCHER,
            [
                "dev-entry.ps1",
                "releases?per_page=20",
                "Invoke-RestMethod",
                "foreach($candidate in @($payload))",
                "Invoke-WebRequest",
                "launcher-bootstrap.log",
                "BOOTSTRAP ERROR:",
                "Running the current BG3 Controller Action Menu development task",
                "shell.Run(command, 0, True)",
                "dev-task.log",
                "dev-status.txt",
                "Development task completed.",
                'stateRoot = fso.BuildPath(baseDir, "installer-work")',
                "--self-test",
                "--resolve-only",
                "--no-ui",
            ],
        )
    )

    errors.extend(
        require_text(
            DEVELOPMENT_VBS_DOC,
            [
                "universal development shortcut",
                "one operator-facing VBS",
                "dev-entry.ps1",
                "No manual replacement or update of the VBS is required",
                "A change that would require the operator to download a newer VBS manually is a development-launcher architecture regression.",
                "normal install/update",
                "read-only capture",
                "diagnostics",
                "official delivery path",
            ],
        )
    )

    if ONE_CLICK_LAUNCHER.exists():
        launcher_text = ONE_CLICK_LAUNCHER.read_text(encoding="utf-8")
        for forbidden in (
            "native-overlay.ps1",
            "Game.pak",
            "divine.exe",
            "BG3ControllerActionMenu-0.",
        ):
            if forbidden in launcher_text:
                errors.append(
                    f"{ONE_CLICK_LAUNCHER.relative_to(ROOT)}: stable development VBS must not contain version/build-specific behavior: {forbidden}"
                )

    errors.extend(
        require_text(
            ONE_CLICK_BUILDER,
            [
                "Install-BG3ControllerActionMenu.vbs",
                "BG3ControllerActionMenu-OneClickInstaller.zip",
                "single-file universal development launcher bundle",
                "Compress-Archive",
            ],
        )
    )

    builder_text = ONE_CLICK_BUILDER.read_text(encoding="utf-8") if ONE_CLICK_BUILDER.exists() else ""
    for forbidden_bundle_seam in (
        'Join-Path $Stage "install-latest.ps1"',
        'Join-Path $Stage "dev-entry.ps1"',
        'Join-Path $Stage "bootstrap-latest.ps1"',
    ):
        if forbidden_bundle_seam in builder_text:
            errors.append(
                f"{ONE_CLICK_BUILDER.relative_to(ROOT)}: reusable one-click ZIP must contain only the universal VBS: {forbidden_bundle_seam}"
            )

    for workflow in (BUILD_WORKFLOW, RELEASE_WORKFLOW):
        errors.extend(
            require_text(
                workflow,
                [
                    "Test universal development entry",
                    "test-dev-entry.ps1",
                    "Test standalone one-file VBS",
                    "test-standalone-vbs.ps1",
                    "Test self-contained Patch 8 runtime",
                    "test-self-contained-runtime.ps1",
                ],
            )
        )

    errors.extend(
        require_text(
            BUILD_WORKFLOW,
            [
                "Test release boundary",
                "assert-self-contained-release.ps1",
            ],
        )
    )

    errors.extend(
        require_text(
            RELEASE_WORKFLOW,
            [
                '"tools/dev-entry.ps1"',
                '"tools/install-latest.ps1"',
                '"tools/capture-self-contained-inputs.ps1"',
                '$devEntry = "tools/dev-entry.ps1"',
                '$latestInstaller = "tools/install-latest.ps1"',
                '$launcher = "tools/Install-BG3ControllerActionMenu.vbs"',
                '"release", "create", $env:TAG, $pak, $installer, $oneClick, $launcher, $devEntry, $latestInstaller, $capture',
                './tools/dev-entry.ps1 -ResolveOnly',
                './tools/test-standalone-vbs.ps1',
                '$deadline = (Get-Date).ToUniversalTime().AddMinutes(5)',
                '$delaySeconds = [Math]::Min(15, $delaySeconds * 2)',
                'within the five-minute publication propagation window',
            ],
        )
    )

    if RELEASE_WORKFLOW.exists():
        release_text = RELEASE_WORKFLOW.read_text(encoding="utf-8")
        if '"native-overlay.ps1"' in release_text or '$overlay = "tools/native-overlay.ps1"' in release_text:
            errors.append(
                f"{RELEASE_WORKFLOW.relative_to(ROOT)}: native overlay builder must not be a normal release/install asset"
            )

    errors.extend(
        require_text(
            SELF_CONTAINED_RELEASE_GUARD,
            [
                "Release blocked: the self-contained controller runtime is not present.",
                "Lib_Controller.xaml",
                "native-overlay.ps1",
                "Game.pak",
                "Self-contained release boundary passed.",
            ],
        )
    )

    errors.extend(
        require_text(
            RELEASE_WORKFLOW,
            [
                "Require self-contained runtime",
                "./tools/assert-self-contained-release.ps1",
            ],
        )
    )

    errors.extend(
        require_text(
            NATIVE_CAPTURE,
            [
                'Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3"',
                '$LslibVersion = "v1.20.4"',
                '$TargetExpression = "*ActionRadials*.xaml"',
                "--action extract-single-file",
                "native-contract-analysis.json",
                "ImplementationGate",
                "No game, profile or mod files were modified.",
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE,
            [
                '$PortableRoot = Split-Path -Parent $MyInvocation.MyCommand.Path',
                '$WorkRoot = Join-Path $PortableRoot "capture-work"',
                '*PreloadedActionRadials*.xaml',
                '*ActionRadials*.xaml',
                '*HotBar*.xaml',
                '*DataTemplates.xaml',
                '*Controller.xaml',
                '*Lib_Controller.xaml',
                'bg3-controller-action-menu-inputs-$stamp',
                'No BG3 files, saves, profiles, or mods were modified.',
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_CAPTURE_TEST,
            [
                'Portable developer capture helper fixture passed.',
                '%LOCALAPPDATA%',
                'No BG3 files, saves, profiles, or mods were modified.',
            ],
        )
    )

    for portable_path in (ONE_CLICK_LAUNCHER, DEV_ENTRY, LATEST_INSTALLER, DEV_CAPTURE):
        if portable_path.exists() and "%LOCALAPPDATA%" in portable_path.read_text(encoding="utf-8"):
            errors.append(
                f"{portable_path.relative_to(ROOT)}: portable launcher path must not use %LOCALAPPDATA%"
            )

    if not VERSION.exists():
        errors.append("VERSION: required file is missing")
    else:
        version = VERSION.read_text(encoding="utf-8").strip()
        if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
            errors.append(f"VERSION: invalid SemVer-like value: {version!r}")

    return errors


def main() -> int:
    errors: list[str] = []
    checked_xml = 0

    for path in iter_files():
        if path.suffix.lower() in XML_SUFFIXES:
            checked_xml += 1
            errors.extend(validate_xml(path))

    errors.extend(validate_semantics())

    if errors:
        print("Static validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"Static validation passed ({checked_xml} XML/XAML/LSX files checked; "
        "pinned Patch 8 self-contained runtime contract present; normal installer is direct/self-contained; "
        "runtime remains Script-Extender-free)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
