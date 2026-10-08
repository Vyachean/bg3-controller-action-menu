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
                'Property="ls:MoveFocus.Focusable" Value="True"',
                'Setter Property="FocusVisualStyle" Value="{x:Null}"',
                'x:Key="CAM_ResetFirstFocusToken"',
                'x:Key="CAM_NestedEnteredToken"',
                'x:Key="CAM_NestedRestoringToken"',
                'x:Name="CAM_NestedReturnMarker"',
                '<RowDefinition Height="84"/>',
                '<RowDefinition Height="850"/>',
                'x:Name="CAM_TopTabs"',
                '<ls:LSActionPointResources x:Name="ResourcePoints"',
                'Style="{StaticResource ActionResourcesTemplateSelector}"',
                'x:Key="CAM_KeyboardHotBarPointGroup"',
                'ContentTemplate="{StaticResource ActionResources.ActionGroup.ActionPoint}"',
                'ActionPointTemplate="{StaticResource CAM_KeyboardHotBarPointGroup}"',
                '<System:Double x:Key="ActionResources.ActionPointGroupSize">56</System:Double>',
                '<System:Double x:Key="ActionResources.ActionPointSize">48</System:Double>',
                '<System:Double x:Key="ActionResources.ActionPointSmallSize">24</System:Double>',
                'x:Name="CAM_ResourceStrip"',
                'x:Name="CAM_HotbarBodyResourcesBg"',
                'x:Key="CAM_BarResources"',
                'bar_resources.png',
                'MinWidth="208"',
                'Converter={StaticResource AddConverter}, ConverterParameter=208',
                'Slices="104,0"',
                'x:Key="CAM_BoxResourceBg"',
                'x:Key="CAM_BoxResource"',
                'x:Key="CAM_BoxResourceH"',
                'x:Key="CAM_BoxResourceDisabled"',
                'x:Key="CAM_BoxResourceNumBg"',
                'x:Key="CAM_BoxResourceNum"',
                'x:Key="CAM_BoxResourceNumH"',
                'x:Key="CAM_BoxResourceNumDisabled"',
                'box_resource_empty.png',
                'box_resource_d.png',
                'box_resource_h.png',
                'box_resource_missing.png',
                'box_resourceNum_empty.png',
                'box_resourceNum_d.png',
                'box_resourceNum_h.png',
                'box_resourceNum_missing.png',
                'SmallActionPointSize="24"',
                'ActionPointGroupSize="56"',
                'x:Name="ResourcesNumeralDisplay"',
                'LessThanOrEqualMultiConverter',
                'MaxGroupActionPoints',
                'x:Key="CAM_ResourceTabTemplate"',
                'ItemTemplate="{StaticResource CAM_ResourceTabTemplate}"',
                '<ls:LSButton Padding="0"',
                'Margin="4,-10,4,10"',
                'HighlightedActionPoints="{Binding DataContext.Cost, ElementName=Root}"',
                '<Trigger Property="IsMouseOver" Value="True">',
                'Binding="{Binding Path=Tag, ElementName=Root}" Value="SpellSlot"',
                'x:Name="CAM_CantripsTab"',
                'x:Key="CAM_CantripsModeToken"',
                'x:Name="CAM_ItemsTab"',
                'x:Key="CAM_ItemsModeToken"',
                'x:Key="CAM_ItemsProviderIcon"',
                'SetCurrentShownDeckCommand',
                'CommandParameter="ItemHotBar"',
                'CurrentShownDeck.SlotList',
                'x:Name="CAM_MetamagicTab"',
                'x:Key="CAM_MetamagicModeToken"',
                'PlayerCharacterProperties.FixedSideBar.SlotList',
                'x:Name="CAM_AllTab"',
                'x:Key="CAM_AllModeToken"',
                'x:Key="CAM_AllProviderIcon"',
                'ico_tab_all.png',
                'PlayerCharacterProperties.KeyboardHotBars',
                'x:Key="CAM_AllGroupsPanel"',
                'x:Key="CAM_AllGroupContainerStyle"',
                'x:Key="CAM_AllGroupTemplate"',
                'x:Name="CAM_AllGroupSlots"',
                'x:Key="CAM_CantripFilterParameter"',
                'x:Name="CAM_ProviderRestoreCommand"',
                'x:Name="CAM_ProviderModeMarker"',
                'x:Name="CAM_ResourceTabsScroller"',
                    'EventName="TargetPositionChanged"',
                'PropertyName="HorizontalScrollOffset"',
                'Value="{Binding TargetPosition, ElementName=CAM_ResourceTabsScroller}"',
                'MaxWidth="720"',
                'FilterCantripsCommand',
                'h7d02199dg44ecg4a1egbcacg9cc1cec197b3',
                'x:Name="CAM_PassivesTab"',
                'x:Key="CAM_PassivesModeToken"',
                'x:Key="CAM_TabReturnLastToken"',
                'Tag="{x:Null}"',
                'PlayerCharacterProperties.PassivesHotBar.SlotList',
                '<Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>',
                'Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"',
                'Binding="{Binding SlotType}" Value="Item"',
                'Content="{Binding Content}"',
                'ContentTemplate="{StaticResource Template.Item}"',
                'Value="{StaticResource Template.ItemEquipment}"',
                'Value="{StaticResource Template.ItemContainer}"',
                'b:DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"',
                'RightOperand="{StaticResource CAM_ResetFirstFocusToken}"',
                'FocusElement="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"',
                'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
                    'Template="{StaticResource SelectorTemplate}"',
                'EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"',
                'Converter="{StaticResource DivideMultiConverter}" ConverterParameter="Floor"',
                'AncestorType={x:Type ScrollContentPresenter}',
                'PropertyName="SelectedIndex" Value="-1"',
                'Value="{StaticResource CAM_ResetFirstFocusToken}"',
                'FilterActionResourceCommand',
                'SingleHotBar.SlotList',
                'RomanNumeralLevelImage',
                'x:Name="HotBarList"',
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
                '"mode": "resource-first-plus-cantrips-plus-items-plus-metamagic-plus-passives-plus-all-fallback"',
                '"primaryTabSource": "CurrentPlayer.UIData.ActionResourcesCostPreview"',
                '"detailsSurface": "native-tooltip-only"',
                '"executableList": "HotBarList"',
                '"itemsSource": "SingleHotBar.SlotList (resources/Cantrips/nested) | CurrentShownDeck.SlotList (Items) | FixedSideBar.SlotList (Metamagic) | PassivesHotBar.SlotList | KeyboardHotBars[*].SlotList (All fallback) via CAM_ProviderModeMarker.Tag"',
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
                '"mode": "single-row-exact-hotbar-action-resources"',
                '"orientation": "Horizontal"',
                '"includesPassives": true',
                '"sharedBackground": "bar_resources.png"',
                '"sharedBackgroundHeight": 64',
                '"sharedBackgroundSlices": "104,0"',
                '"sharedBackgroundMinWidth": 208',
                '"sharedBackgroundWidthRule": "visible tab row ActualWidth + 208"',
                '"resourceVisualSize": 72',
                '"resourceButtonMargin": "4,-10,4,10"',
                '"itemContainerMargin": "-4,0,-4,0"',
                '"wrappedRows": false',
                '"resourceViewportMaxWidth": 720',
                '"scrollTargetStorage": "CAM_ResourceTabs.Tag"',
                '"scrollTargetType": "selected concrete resource ListBoxItem UIElement"',
                '"scrollTransport": "LSScrollViewer.ScrollToElement"',
                '"targetPositionCommit": "TargetPositionChanged -> HorizontalScrollOffset = TargetPosition"',
                '"autoScrollBehaviorAllowed": false',
                '"specialProviderTabsOutsideScrollOwner": true',
                '"control": "LSActionPointResources"',
                '"style": "ActionResourcesTemplateSelector"',
                '"smallActionPointSize": 24',
                '"actionPointGroupSize": 56',
                '"background": "box_resource_empty.png"',
                '"normal": "box_resource_d.png"',
                '"highlight": "box_resource_h.png"',
                '"missing": "box_resource_missing.png"',
                '"background": "box_resourceNum_empty.png"',
                '"normal": "box_resourceNum_d.png"',
                '"highlight": "box_resourceNum_h.png"',
                '"missing": "box_resourceNum_missing.png"',
                '"chromeMargin": "0,-8,0,0"',
                '"spellSlotOverlayMargin": "0,-10,0,0"',
                '"countOverlay": "ResourcesNumeralDisplay"',
                '"countOverlayRule": "visible only when ActionResource.Value > ResourcePoints.MaxGroupActionPoints"',
                '"countOverlayDefaultVisibility": "Hidden"',
                '"resourceBarChromeAllowed": true',
                '"resourceIdentity": "LSActionPointResources(ActionResourcesTemplateSelector)"',
                '"presentationBoundary": "literal ActionResourcesList DataTemplate inside controller-only LSListBox container"',
                '"nativeItemRoot": "LSButton"',
                '"nativeItemRootPadding": "0"',
                '"nativeItemRootMargin": "4,-10,4,10"',
                '"nativeHoverTrigger": "IsMouseOver -> box_resource_h"',
                '"controllerSelectedVisual": null',
                '"controllerSelectionAffectsResourceVisual": false',
                '"spellSlotTrigger": "ActionResource.TypeId -> Root.Tag=SpellSlot -> box_resourceNum_*"',
                '"outerContainerPresentation": "transparent ContentPresenter only"',
                '"outerContainerSelectedVisual": false',
                '"itemTemplateOwnsVisuals": true',
                '"rejectedControllerVisualMapping": "ListBoxItem.IsSelected -> box_resource_h"',
                '"rejectedRenderer": "SectionImageStyle"',
                '"rejectedTextFilterChrome": "btn_pil_*"',
                '"sameFilterChrome": false',
                '"resourceBoxChromeAllowed": true',
                '"passivesTabAllowed": true',
                '"passivesSource": "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList"',
                '"passivesModeStorage": "CAM_ProviderModeMarker.Tag"',
                '"passivesModeToken": "CAM_PassivesModeToken"',
                '"passivesModeOwnership": "CAM presentation-only"',
                '"providerModeStorage": "CAM_ProviderModeMarker.Tag"',
                '"resourceScrollTargetStorage": "CAM_ResourceTabs.Tag"',
                '"cantripsTabAllowed": true',
                '"cantripsCommand": "FilterCantripsCommand"',
                '"cantripsCommandParameter": "h7d02199dg44ecg4a1egbcacg9cc1cec197b3"',
                '"cantripsModeToken": "CAM_CantripsModeToken"',
                '"itemsTabAllowed": true',
                '"itemsCommand": "SetCurrentShownDeckCommand"',
                '"itemsCommandParameter": "ItemHotBar"',
                '"itemsSource": "CurrentShownDeck.SlotList"',
                '"itemsModeToken": "CAM_ItemsModeToken"',
                '"metamagicTabAllowed": true',
                '"metamagicSource": "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList"',
                '"metamagicModeToken": "CAM_MetamagicModeToken"',
                '"allTabAllowed": true',
                '"allSource": "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList"',
                '"allModeToken": "CAM_AllModeToken"',
                '"providerRestoreDispatcher": "CAM_ProviderRestoreCommand"',
                '"rightFromPassives": "CAM_TabEnterSpecialToken -> CAM_AllModeToken"',
                '"rightFromAll": "CAM_TabReturnFirstToken -> FilterActionResourceCommand(selected resource)"',
                '"leftFromAll": "CAM_TabEnterSpecialToken -> CAM_PassivesModeToken"',
                '"leftFromPassivesWhenMetamagicAvailable": "CAM_TabEnterSpecialToken -> CAM_MetamagicModeToken"',
                '"leftFromPassivesWhenMetamagicUnavailable": "CAM_TabEnterSpecialToken -> CAM_ItemsModeToken -> SetCurrentShownDeckCommand(ItemHotBar)"',
                '"resourceReturnMilliseconds": 70',
                '"leftFallbackModeSwitchMilliseconds": 90',
                '"ordinaryResourceClickHandlersEligibleDuringReturn": false',
                '"singleShoulderPressSingleLogicalTransition": true',
                '"slotType": "Item"',
                '"slotContentType": "VMItem"',
                '"slotContentPath": "VMHotBarSlot.Content"',
                '"normalTemplate": "Template.Item"',
                '"equipmentTemplate": "Template.ItemEquipment"',
                '"containerTemplate": "Template.ItemContainer"',
                '"property": "Count"',
                '"visibilityConverter": "CountToVisibilityConverter"',
                '"converter": "AbbreviateNumberConverter"',
                '"camOverlayAllowed": false',
                '"rejectedPath": "VMHotBarSlot.GameObject.Count"',
                '"entryCommitToken": null',
                '"layoutPanel": "StackPanel"',
                '"oneLogicalSequence": true',
                '"horizontalScrollState": true',
                '"scrollOwner": "CAM_ResourceTabsScroller"',
                '"actionViewportHeight": 850',
                '"cycleForceSelect": false',
                '"hiddenPreviewSelection": "collapsed+disabled; ordinary cycle only"',
                '"visibleFocusVisualStyle": null',
                '"clearSelectedIndex": -1',
                '"filterCommandCount": 1',
                '"settleMilliseconds": 70',
                '"armToken": "CAM_ResetFirstFocusToken"',
                '"restoreSelectedIndex": 0',
                '"focusTarget": "selected concrete ListBoxItem templated parent"',
                '"focusAction": "SetMoveFocusAction(DeferFocusAction=True)"',
                '"focusPublishesEntryCommit": false',
                '"clearsTokenAfterEntryCommit": false',
                '"clearLocalFocus": true',
                '"invalidateFocus": false',
                '"focusesListContainer": false',
                '"selectedItemMirrorsLocalFocus": false',
                '"entryStateSource": "LocalFocus.DataContext after concrete-item SetMoveFocusAction handoff"',
                '"programmaticWakeSignal": "HotBarList.SelectionChanged delayed LocalFocus wake"',
                '"programmaticStateSource": "HotBarList.LocalFocus.DataContext after deferred focus"',
                '"selectedItemEntryStateWrites": false',
                '"resetTokenClearedBySelectedContainer": true',
                '"selector": "CAM_MainSelector"',
                '"selectorTemplate": "SelectorTemplate"',
                '"selectorVisibleChrome": true',
                '"selectorOpacity": 1',
                '"marker": "CAM_NestedReturnMarker"',
                '"enterToken": "CAM_NestedEnteredToken"',
                '"restoringToken": "CAM_NestedRestoringToken"',
                '"providerRestoreDispatcher": "CAM_ProviderRestoreCommand"',
                '"repopulationSignal": "SingleHotBar.SlotList.Count > 0"',
                '"topLevelCloseRestoresFilter": false',
                '"stateAuthority": "HotBarList.LocalFocus.DataContext"',
                '"entryStateSource": "HotBarList.LocalFocus.DataContext after concrete focus handoff"',
                '"localFocusChangedRole": "normal-navigation-presentation"',
                '"delayedLocalFocusPresentationTimer": true',
                '"Public/Game/GUI/Library/PreloadedActionRadials_c.xaml": "4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b"',
                '"Mods/MainUI/GUI/Pages/HotBar.xaml": "9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728"',
                '"archive": "bg3-controller-action-menu-inputs-20261007-223832.zip"',
                '"gamePackageVersion": "1.8.910.0"',
                '"hotBarPath": "Mods/MainUI/GUI/Pages/HotBar.xaml"',
                '"hotBarSha256": "9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728"',
                '"actionResourcesContainer": "ActionResourcesContainer"',
                '"actionResourcesList": "ActionResourcesList"',
                '"provenKeyboardSource": "ItemHotBar -> CurrentShownDeck.SlotList"',
                '"radialReference": "Inventory.Slots"',
                '"status": "runtime-parity-not-yet-proven"',
                '"status": "complete-by-native-provider-construction"',
                '"fallback": "KeyboardHotBars[*].SlotList"',
                '"parityUnresolvedClasses": [',
            ],
        )
    )

    if SELF_CONTAINED_RUNTIME.exists():
        runtime_text = SELF_CONTAINED_RUNTIME.read_text(encoding="utf-8")
        for forbidden_presentation in (
            "GameObject.Count",
            "ItemCountHolder",
            "CAM_FilterButtonBackground",
            "CAM_ActiveFilterButtonBackground",
            "CAM_DisabledFilterButtonBackground",
            "CAM_FilterMarkerBackground",
            "btn_pil_",
            "ActiveModArrow",
        ):
            if forbidden_presentation in runtime_text:
                errors.append(
                    f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: rejected presentation seam returned: {forbidden_presentation}"
                )
        for forbidden in (
            "LocalFocus.Tag",
            "CAM_FilterTabs",
            "CAM_CommonFilterTab",
            "CAM_ClassFilterTab",
            "CAM_CantripsFilterTab",
            "CAM_ItemsFilterTab",
            "CAM_PassivesFilterTab",
            "IsShowingPassivesDeck",
            "SetIsShowingPassivesDeckCommand",
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
            '<b:PropertyChangedTrigger Binding="{Binding FocusedElement, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}">',
            'ls:LSScrollViewer.ScrollToElement="{Binding Tag, ElementName=CAM_ResourceTabs}"',
            '<b:PropertyChangedTrigger Binding="{Binding LocalFocus.DataContext, ElementName=HotBarList}"',
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

        if (
            'x:Name="CAM_ProviderModeMarker"' not in runtime_text
            or 'x:Name="CAM_ResourceTabsScroller"' not in runtime_text
            or 'ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"' not in runtime_text
            or 'EventName="TargetPositionChanged"' not in runtime_text
            or 'PropertyName="HorizontalScrollOffset"' not in runtime_text
            or 'Value="{Binding TargetPosition, ElementName=CAM_ResourceTabsScroller}"' not in runtime_text
            or 'Binding="{Binding Tag, ElementName=CAM_ResourceTabs}"' in runtime_text
        ):
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: resource scrolling must use concrete ListBoxItem target + TargetPosition commit, while provider mode stays on CAM_ProviderModeMarker"
            )

        # 0.0.85 moved provider-mode state away from CAM_ResourceTabs.Tag
        # (which now holds a concrete scroll UIElement). Reject every stale
        # Tag reader, including conditions inside shoulder/nested handlers.
        if re.search(r"\{Binding Tag,\s*ElementName=CAM_ResourceTabs\}", runtime_text):
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: provider conditions must read CAM_ProviderModeMarker, not the resource UIElement scroll target"
            )
        guard = '<b:ComparisonCondition LeftOperand="{Binding Tag, ElementName=CAM_TabCycleMarker}" Operator="Equal" RightOperand="{x:Null}"/>'
        for side, expected in (("CAM_TabLeft", 9), ("CAM_TabRight", 7)):
            button = re.search(
                r'<ls:LSButton\b[^>]*x:Name="' + side + r'"[\s\S]*?</ls:LSButton>',
                runtime_text,
            )
            clicks = (
                re.findall(r'<b:EventTrigger EventName="Click">[\s\S]*?</b:EventTrigger>', button.group())
                if button else []
            )
            if len(clicks) != expected or any(
                guard not in click or "{Binding Tag, ElementName=CAM_ProviderModeMarker}" not in click
                for click in clicks
            ):
                errors.append(
                    f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: {side} must serialize all expected mode transitions against the dedicated provider marker"
                )

        # HotBar.xaml defines ResourceBackgroundMargin as zero in its own page
        # dictionary; CAM has a separate controller resource scope. Require a
        # local literal alias, and prohibit all undeclared CAM_* resource refs.
        if '<Thickness x:Key="CAM_ResourceBackgroundMargin">0</Thickness>' not in runtime_text:
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: native HotBar resource-box margin must be locally declared with value 0"
            )
        local_cam_keys = set(re.findall(r'x:Key="(CAM_[\w.]+)"', runtime_text))
        used_cam_keys = set(
            re.findall(r'\{(?:StaticResource|DynamicResource) (CAM_[\w.]+)\}', runtime_text)
        )
        missing_cam_keys = used_cam_keys - local_cam_keys
        if missing_cam_keys:
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: undefined CAM visual resources: {sorted(missing_cam_keys)}"
            )

        preview = re.search(
            r'<DataTemplate\b[^>]*x:Key="CAM_ResourceTabTemplate"[\s\S]*?</DataTemplate>',
            runtime_text,
        )
        preview_text = preview.group() if preview else ""
        active_resource = '<Condition Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType={x:Type ListBoxItem}}}" Value="True"/>'
        normal_mode = '<Condition Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}" Value="{x:Null}"/>'
        disabled_resource = '<DataTrigger Binding="{Binding ActionResource.Value}" Value="0">'
        if (
            active_resource not in preview_text
            or normal_mode not in preview_text
            or disabled_resource not in preview_text
            or preview_text.index(active_resource) >= preview_text.index(disabled_resource)
            or 'Source="{StaticResource CAM_BoxResourceH}"' not in preview_text
        ):
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: controller resource selection must use native HotBar hover chrome, preserving disabled state"
            )

        if (
            "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars" not in runtime_text
            or 'x:Key="CAM_AllGroupTemplate"' not in runtime_text
            or 'ItemsSource="{Binding SlotList}"' not in runtime_text
            or 'x:Key="CAM_AllModeToken"' not in runtime_text
        ):
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: KeyboardHotBars fallback must remain grouped VMHotBar -> VMHotBarSlot, never raw action dispatch"
            )

        if (
            runtime_text.count("SetCurrentShownDeckCommand") < 3
            or runtime_text.count('CommandParameter="ItemHotBar"') < 3
            or 'CommandParameter="CommonHotBar"' in runtime_text
            or 'CommandParameter="ClassHotBar"' in runtime_text
            or 'CommandParameter="InvalidHotBar"' in runtime_text
        ):
            errors.append(
                f"{SELF_CONTAINED_RUNTIME.relative_to(ROOT)}: CurrentShownDeck runtime use must be restricted to ItemHotBar"
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
                "ReleaseMetadataPath",
                "foreach ($release in @($payload))",
                "Save-Asset",
                "LauncherRoot",
                '$token = $env:GH_TOKEN',
                '$token = $env:GITHUB_TOKEN',
                '$headers["Authorization"] = "Bearer $token"',
                'Task = "capture"',
                'capture-self-contained-inputs.ps1',
                'ReadOnly = $true',
                "Read-only keyboard/controller resource-template capture completed.",
                '"-PortableRoot", $captureRoot',
            ],
        )
    )

    errors.extend(
        require_text(
            DEV_ENTRY_TEST,
            [
                "Universal release-controlled read-only capture entry fixture passed.",
                "Release-controlled capture helper was not executed.",
                'cmd.exe /c "exit 23"',
                "Capture archive must be written beside the operator VBS.",
                "fixture read-only capture log",
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
                '*DataTemplates*.xaml',
                '*ActionResourceTemplates*.xaml',
                '*Libs_*.xaml',
                '*Resource*.xaml',
                'KeyboardPointTemplates',
                'ControllerPointTemplates',
                'ControllerActionResourceTemplates',
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
                'Mods/MainUI/GUI/Pages/HotBar.xaml',
                'HotBarPage',
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
