$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Library = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
$EvidencePath = Join-Path $Root "docs\evidence\patch8-1.8.910.0-runtime-contract.json"

if (-not (Test-Path -LiteralPath $Library -PathType Leaf)) {
    throw "Self-contained runtime library is missing: $Library"
}
if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    throw "Patch 8 capture evidence is missing: $EvidencePath"
}

[xml]$xml = Get-Content -Raw -LiteralPath $Library
$text = Get-Content -Raw -LiteralPath $Library
$evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json

if ($evidence.gamePackageVersion -ne "1.8.910.0") {
    throw "Runtime evidence must be pinned to Xbox Patch 8 capture 1.8.910.0."
}
if ($evidence.captureMatchCount -ne 22 -or $evidence.captureScanErrorCount -ne 0) {
    throw "Runtime evidence must preserve the complete 22-file capture with zero scan errors."
}
if ($evidence.sourceHashes.'Public/Game/GUI/Library/PreloadedActionRadials_c.xaml' -ne "4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b") {
    throw "Unexpected PreloadedActionRadials capture hash."
}
if ($evidence.sourceHashes.'Mods/MainUI/GUI/Pages/HotBar.xaml' -ne "9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728") {
    throw "Unexpected HotBar capture hash."
}
if ($evidence.sourceHashes.'Mods/MainUI/GUI/Pages/SpellBook_c.xaml' -ne "52095cb915375f8cf403dd8398a11c98f5808b2c50c826db1fe3ed43df573542") {
    throw "Unexpected SpellBook capture hash."
}

if ($evidence.runtimeContract.coverageContract.status -ne "incomplete-until-native-parity-proven" -or
    $evidence.runtimeContract.coverageContract.dispatchType -ne "VMHotBarSlot" -or
    $evidence.runtimeContract.coverageContract.documentation -ne "docs/action-coverage.md" -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.report -ne "hotbar-coverage-contract.json" -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.schemaVersion -ne 3 -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.searchScope -ne "all captured XAML" -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.missingProbePolicy -ne "record-missing-do-not-fail" -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.recordsSourceFile -ne $true -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.recordsInputTransportAttributes -ne $true -or
    $evidence.runtimeContract.coverageContract.captureDiagnostics.missingInputTransportPolicy -ne "record-missing-do-not-fail") {
    throw "Runtime evidence must carry the controller HotBar parity contract."
}
$weaponCapture = $evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.captureProbe
$requiredWeaponSymbols = @(
    "SwitchWeaponSetCommand",
    "ToggleWeaponSet",
    "UISelectionLeft",
    "ControllerHoldButtonStyle",
    "WeaponSetSwitchStyle",
    "LSInputBinding",
    "HoldTimeShortcuts"
)
if ($evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.status -ne "removed-pending-proven-actionradials-transport" -or
    $evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.camBinding -ne $false -or
    $evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.camHint -ne $false -or
    $weaponCapture.report -ne "hotbar-coverage-contract.json" -or
    $weaponCapture.probeGroup -ne "InputTransportProbes" -or
    $weaponCapture.policy -ne "record-missing-do-not-fail") {
    throw "Weapon-set shortcut must remain absent while structured native input transport evidence is collected."
}
foreach ($symbol in $requiredWeaponSymbols) {
    if (@($weaponCapture.symbols) -notcontains $symbol -or
        @($evidence.runtimeContract.coverageContract.captureDiagnostics.inputTransportSymbols) -notcontains $symbol) {
        throw "Weapon input capture evidence is missing required symbol: $symbol"
    }
}
foreach ($attribute in @("SourceFile","Element","ElementName","BoundEvent","Command","HoldTime","TapTime","EatInput","Property","Value","RawTag")) {
    if (@($weaponCapture.recordedAttributes) -notcontains $attribute) {
        throw "Weapon input capture evidence is missing required attribute: $attribute"
    }
}

if (@($evidence.runtimeContract.coverageContract.knownMissingSourceClasses).Count -ne 0) {
    throw "Native keyboard-HotBar source coverage should no longer carry known missing-source classes once KeyboardHotBars fallback ships."
}
$requiredParityGaps = @(
    "free/no-resource actions",
    "inventory/consumables vs radial Inventory.Slots",
    "scrolls",
    "item-charge actions",
    "temporary actions",
    "recasts",
    "mod-added radial-only candidates"
)
foreach ($gap in $requiredParityGaps) {
    if (@($evidence.runtimeContract.coverageContract.parityUnresolvedClasses) -notcontains $gap) {
        throw "Coverage evidence must keep unresolved radial parity explicit: $gap"
    }
}
if ($evidence.runtimeContract.coverageContract.keyboardSourceCoverage.status -ne "complete-by-native-provider-construction" -or
    $evidence.runtimeContract.coverageContract.keyboardSourceCoverage.fallback -ne "KeyboardHotBars[*].SlotList") {
    throw "Keyboard source coverage must be closed only by the native KeyboardHotBars VMHotBar collection."
}
if ($evidence.runtimeContract.coverageContract.itemDeckParity.provenKeyboardSource -ne "ItemHotBar -> CurrentShownDeck.SlotList" -or
    $evidence.runtimeContract.coverageContract.itemDeckParity.radialReference -ne "Inventory.Slots" -or
    $evidence.runtimeContract.coverageContract.itemDeckParity.status -ne "runtime-parity-not-yet-proven") {
    throw "ItemHotBar may ship as a native executable provider, but radial Inventory.Slots parity must remain explicitly unproven."
}
if ($evidence.runtimeContract.assignmentNavigation.gridScrolling.focusFollow.source -ne "ActionRadials.FocusedElement" -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.focusFollow.transport -ne "LSScrollViewer.ScrollToElement") {
    throw "Action-grid evidence must use the captured controller focus-follow scroll seam."
}

if ($evidence.runtimeContract.organization.mode -ne "resource-first-plus-cantrips-plus-items-plus-metamagic-plus-passives-plus-all-fallback" -or
    $evidence.runtimeContract.organization.topLevelDimensions -ne 1 -or
    $evidence.runtimeContract.organization.primaryTabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.organization.primarySelectionCommand -ne "FilterActionResourceCommand" -or
    $evidence.runtimeContract.organization.primaryGridSource -ne "SingleHotBar.SlotList | CurrentShownDeck.SlotList | PassivesHotBar.SlotList | KeyboardHotBars[*].SlotList" -or
    $evidence.runtimeContract.organization.parallelSidebarSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList" -or
    $evidence.runtimeContract.organization.parallelSidebarFocus -ne "CAM_FixedSideBarList.LocalFocus.DataContext -> ActionRadials.Tag -> UseSlotCommand" -or
    $evidence.runtimeContract.organization.focusOwnership -ne "exclusive: LB/RB provider marker enables metamagic side rail vs HotBarList; native nested temporarily enables HotBarList; passive LocalFocusChanged cannot write provider mode" -or
    $evidence.runtimeContract.organization.cantripsTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.cantripsVisibility -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasCantrips" -or
    $evidence.runtimeContract.organization.cantripsCommand -ne "FilterCantripsCommand" -or
    $evidence.runtimeContract.organization.cantripsCommandParameter -ne "h7d02199dg44ecg4a1egbcacg9cc1cec197b3" -or
    $evidence.runtimeContract.organization.cantripsModeToken -ne "CAM_CantripsModeToken" -or
    $evidence.runtimeContract.organization.itemsTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.itemsCommand -ne "SetCurrentShownDeckCommand" -or
    $evidence.runtimeContract.organization.itemsCommandParameter -ne "ItemHotBar" -or
    $evidence.runtimeContract.organization.itemsSource -ne "CurrentShownDeck.SlotList" -or
    $evidence.runtimeContract.organization.itemsModeToken -ne "CAM_ItemsModeToken" -or
    $evidence.runtimeContract.organization.metamagicTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.metamagicVisibility -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList.Count" -or
    $evidence.runtimeContract.organization.metamagicSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList" -or
    $evidence.runtimeContract.organization.metamagicModeToken -ne "CAM_MetamagicModeToken" -or
    $evidence.runtimeContract.organization.allTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.allSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList" -or
    $evidence.runtimeContract.organization.allModeToken -ne "CAM_AllModeToken" -or
    $evidence.runtimeContract.organization.passivesTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.passivesSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList" -or
    $evidence.runtimeContract.organization.passivesModeStorage -ne "CAM_ProviderModeMarker.Tag" -or
    $evidence.runtimeContract.organization.passivesModeToken -ne "CAM_PassivesModeToken" -or
    $evidence.runtimeContract.organization.passivesModeOwnership -ne "CAM presentation-only" -or
    $evidence.runtimeContract.organization.providerModeStorage -ne "CAM_ProviderModeMarker.Tag" -or
    $evidence.runtimeContract.organization.resourceScrollTargetStorage -ne "CAM_ResourceTabs.Tag" -or
    $evidence.runtimeContract.organization.typeTabsAllowed -ne $false -or
    $evidence.runtimeContract.organization.secondaryResourceLayerAllowed -ne $false) {
    throw "Resource-first native Cantrips/Items/Metamagic/Passives/All organization evidence is incomplete or regressed."
}
if ($evidence.runtimeContract.organization.detailsSurface -ne "native-tooltip-only" -or
    $evidence.runtimeContract.tooltipPresentation.detailsSurface -ne "native-tooltip-only") {
    throw "CAM must use the ordinary native tooltip only; no Live Details panel is allowed."
}
if ($evidence.runtimeContract.controllerPresentation.tabPattern -ne "exact-hotbar-action-resources-plus-cantrips-plus-items-plus-metamagic-plus-passives-plus-all-fallback" -or
    $evidence.runtimeContract.controllerPresentation.tabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.controllerPresentation.genericTabLabel -ne $null -or
    $evidence.runtimeContract.controllerPresentation.spellSlotTabLabel -ne "RomanNumeralLevelImage" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.control -ne "LSActionPointResources" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.style -ne "ActionResourcesTemplateSelector" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.max -ne "MaxValue" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.available -ne "Value" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.highlighted -ne "Cost" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.smallActionPointSize -ne 24 -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.actionPointGroupSize -ne 56 -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.normalBoxAssets.background -ne "box_resource_empty.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.normalBoxAssets.normal -ne "box_resource_d.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.normalBoxAssets.highlight -ne "box_resource_h.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.normalBoxAssets.missing -ne "box_resource_missing.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotBoxAssets.background -ne "box_resourceNum_empty.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotBoxAssets.normal -ne "box_resourceNum_d.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotBoxAssets.highlight -ne "box_resourceNum_h.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotBoxAssets.missing -ne "box_resourceNum_missing.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotBoxAssets.chromeMargin -ne "0,-8,0,0" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.spellSlotOverlayMargin -ne "0,-10,0,0" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.countOverlay -ne "ResourcesNumeralDisplay" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.countOverlayRule -ne "visible only when ActionResource.Value > ResourcePoints.MaxGroupActionPoints" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.countOverlayDefaultVisibility -ne "Hidden" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.resourceBarChromeAllowed -ne $true -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.resourceIdentity -ne "LSActionPointResources(ActionResourcesTemplateSelector)" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.rejectedRenderer -ne "SectionImageStyle" -or
    $evidence.runtimeContract.controllerPresentation.resourceRenderer.rejectedTextFilterChrome -ne "btn_pil_*" -or
    $evidence.runtimeContract.controllerPresentation.cantripsTab.source -ne "FilterCantripsCommand -> SingleHotBar.SlotList" -or
    $evidence.runtimeContract.controllerPresentation.cantripsTab.visibility -ne "PlayerCharacterProperties.HasCantrips" -or
    $evidence.runtimeContract.controllerPresentation.cantripsTab.parameter -ne "h7d02199dg44ecg4a1egbcacg9cc1cec197b3" -or
    $evidence.runtimeContract.controllerPresentation.cantripsTab.modeToken -ne "CAM_CantripsModeToken" -or
    $evidence.runtimeContract.controllerPresentation.cantripsTab.icon -ne "IconMiniCantrip" -or
    $evidence.runtimeContract.controllerPresentation.itemsTab.source -ne "SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList" -or
    $evidence.runtimeContract.controllerPresentation.itemsTab.modeToken -ne "CAM_ItemsModeToken" -or
    $evidence.runtimeContract.controllerPresentation.itemsTab.icon -ne "Core/Assets/Shared/ico_container_more_d.png" -or
    $evidence.runtimeContract.controllerPresentation.metamagicTab.source -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList" -or
    $evidence.runtimeContract.controllerPresentation.metamagicTab.modeToken -ne "CAM_MetamagicModeToken" -or
    $evidence.runtimeContract.controllerPresentation.metamagicTab.icon -ne "FixedSideBar.SlotList[0].Content.Icon" -or
    $evidence.runtimeContract.controllerPresentation.allTab.source -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[*].SlotList" -or
    $evidence.runtimeContract.controllerPresentation.allTab.modeToken -ne "CAM_AllModeToken" -or
    $evidence.runtimeContract.controllerPresentation.allTab.icon -ne "GustavNoesisGUI/Assets/Shared/ico_tab_all.png" -or
    $evidence.runtimeContract.controllerPresentation.passivesTab.sameExecutableList -ne "HotBarList" -or
    $evidence.runtimeContract.controllerPresentation.passivesTab.sameFilterChrome -ne $false -or
    $evidence.runtimeContract.controllerPresentation.passivesTab.resourceBoxChromeAllowed -ne $true) {
    throw "Top tabs must mirror the exact Patch 8 Action Resources strip while preserving controller selection semantics."
}
if ($evidence.runtimeContract.tooltipPresentation.contentPath -ne "LocalFocus.DataContext.Content" -or
    $evidence.runtimeContract.tooltipPresentation.command -ne "ShowTooltipOnUIElementCommand" -or
    $evidence.runtimeContract.tooltipPresentation.stateAuthority -ne "HotBarList.LocalFocus.DataContext" -or
    $evidence.runtimeContract.tooltipPresentation.entryStateSource -ne "HotBarList.LocalFocus.DataContext after concrete focus handoff" -or
    $evidence.runtimeContract.tooltipPresentation.localFocusChangedRole -ne "normal-navigation-presentation" -or
    $evidence.runtimeContract.tooltipPresentation.delayedLocalFocusPresentationTimer -ne $true -or
    @($evidence.runtimeContract.tooltipPresentation.presentationSignals).Count -ne 2) {
    throw "Tooltip contract must keep both programmatic entry and live navigation on LocalFocus.DataContext."
}

if ($evidence.runtimeContract.assignmentNavigation.focusPresentation -ne "native-selector:LocalFocusSelector; live-owner:LocalFocus.DataContext" -or
    $evidence.runtimeContract.assignmentNavigation.selector -ne "CAM_MainSelector" -or
    $evidence.runtimeContract.assignmentNavigation.selectorTemplate -ne "SelectorTemplate" -or
    $evidence.runtimeContract.assignmentNavigation.selectorVisibleChrome -ne $true -or
    $evidence.runtimeContract.assignmentNavigation.selectorOpacity -ne 1 -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusSource -ne "HotBarList.LocalFocus via SelectorTemplate" -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusSyncEvent -ne $null -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusSyncValue -ne $null) {
    throw "ActionRadials visible focus must use the runtime-proven native LocalFocusSelector/SelectorTemplate path."
}
if ($evidence.runtimeContract.assignmentNavigation.adaptiveColumns.source -ne "ScrollContentPresenter.ActualWidth" -or
    $evidence.runtimeContract.assignmentNavigation.adaptiveColumns.divisor -ne 120 -or
    $evidence.runtimeContract.assignmentNavigation.adaptiveColumns.converter -ne "DivideMultiConverter" -or
    $evidence.runtimeContract.assignmentNavigation.adaptiveColumns.rounding -ne "Floor" -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.directGridDisableScrolling -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.scrollViewerCanContentScroll -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.gridUseWidgetNavigation -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.gridAlwaysSelectFirst -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.gridExtendedRows -ne $null -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.emptyCellTemplate -ne "DynamicResource EmptyCellTemplate" -or
    $evidence.runtimeContract.assignmentNavigation.gridScrolling.gridInternalFocusable -ne $false) {
    throw "Adaptive ActionRadials grid contract is incomplete."
}
$resourceViewport = $evidence.runtimeContract.controllerPresentation.resourceViewport
if ($resourceViewport.mode -ne "single-row-exact-hotbar-action-resources" -or
    $resourceViewport.layoutPanel -ne "StackPanel" -or
    $resourceViewport.orientation -ne "Horizontal" -or
    $resourceViewport.oneLogicalSequence -ne $true -or
    $resourceViewport.includesPassives -ne $true -or
    $resourceViewport.sharedBackground -ne "bar_resources.png" -or
    $resourceViewport.sharedBackgroundHeight -ne 64 -or
    $resourceViewport.sharedBackgroundSlices -ne "104,0" -or
    $resourceViewport.sharedBackgroundMinWidth -ne 208 -or
    $resourceViewport.sharedBackgroundWidthRule -ne "visible tab row ActualWidth + 208" -or
    $resourceViewport.resourceVisualSize -ne 72 -or
    $resourceViewport.resourceButtonMargin -ne "4,-10,4,10" -or
    $resourceViewport.itemContainerMargin -ne "-4,0,-4,0" -or
    $resourceViewport.horizontalScrollState -ne $true -or
    $resourceViewport.wrappedRows -ne $false -or
    $resourceViewport.scrollOwner -ne "CAM_ResourceTabsScroller" -or
    $resourceViewport.resourceViewportMaxWidth -ne 720 -or
    $resourceViewport.scrollTargetStorage -ne "CAM_ResourceTabs.Tag" -or
    $resourceViewport.scrollTargetType -ne "selected concrete resource ListBoxItem UIElement" -or
    $resourceViewport.scrollTransport -ne "LSScrollViewer.ScrollToElement" -or
    $resourceViewport.targetPositionCommit -ne "TargetPositionChanged -> HorizontalScrollOffset = TargetPosition" -or
    $resourceViewport.autoScrollBehaviorAllowed -ne $false -or
    $resourceViewport.selectedIndexScrollTargetAllowed -ne $false -or
    $resourceViewport.selectedItemScrollTargetAllowed -ne $false -or
    $resourceViewport.specialProviderTabsOutsideScrollOwner -ne $true -or
    $resourceViewport.actionViewportHeight -ne 850 -or
    $resourceViewport.cycleForceSelect -ne $false) {
    throw "Top tabs must keep one row while dynamic resources use the captured target-position horizontal scroll seam."
}
if ($evidence.runtimeContract.nativeEvidence.resourceTabHorizontalScroll.commitEvent -ne "TargetPositionChanged" -or
    $evidence.runtimeContract.nativeEvidence.resourceTabHorizontalScroll.commitAction -ne "HorizontalScrollOffset = TargetPosition") {
    throw "Resource-tab scroll evidence must include the native TargetPosition commit missing from older rejected CAM attempts."
}
if ($evidence.runtimeContract.controllerPresentation.itemQuantity.slotType -ne "Item" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.slotContentType -ne "VMItem" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.slotContentPath -ne "VMHotBarSlot.Content" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.normalTemplate -ne "Template.Item" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.equipmentTemplate -ne "Template.ItemEquipment" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.containerTemplate -ne "Template.ItemContainer" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.property -ne "Count" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.visibilityConverter -ne "CountToVisibilityConverter" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.converter -ne "AbbreviateNumberConverter" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.style -ne "ItemAmountTextStyle" -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.camOverlayAllowed -ne $false -or
    $evidence.runtimeContract.controllerPresentation.itemQuantity.rejectedPath -ne "VMHotBarSlot.GameObject.Count") {
    throw "Item quantity must be delegated to native VMItem templates."
}
$sourceSwitch = $evidence.runtimeContract.assignmentNavigation.sourceSwitch
if ($sourceSwitch.modeStorage -ne "CAM_ProviderModeMarker.Tag" -or
    @($sourceSwitch.modeTokens).Count -ne 5 -or
    @($sourceSwitch.modeTokens) -notcontains "CAM_CantripsModeToken" -or
    @($sourceSwitch.modeTokens) -notcontains "CAM_ItemsModeToken" -or
    @($sourceSwitch.modeTokens) -notcontains "CAM_MetamagicModeToken" -or
    @($sourceSwitch.modeTokens) -notcontains "CAM_PassivesModeToken" -or
    @($sourceSwitch.modeTokens) -notcontains "CAM_AllModeToken" -or
    $sourceSwitch.ownership -ne "CAM presentation-only" -or
    $sourceSwitch.resourceSource -ne "SingleHotBar.SlotList" -or
    $sourceSwitch.cantripsSource -ne "FilterCantripsCommand -> SingleHotBar.SlotList" -or
    $sourceSwitch.cantripsParameter -ne "h7d02199dg44ecg4a1egbcacg9cc1cec197b3" -or
    $sourceSwitch.itemsSource -ne "SetCurrentShownDeckCommand(ItemHotBar) -> CurrentShownDeck.SlotList" -or
    $sourceSwitch.itemsNestedBehavior -ne "nested flags -> SingleHotBar.SlotList; CurrentShownDeck remains ItemHotBar" -or
    $sourceSwitch.itemsRestore -ne "CAM_NestedRestoringToken -> CurrentShownDeck.SlotList + first-item focus" -or
    $sourceSwitch.allSource -ne "KeyboardHotBars[*].SlotList grouped through CAM_AllGroupTemplate" -or
    $sourceSwitch.allNestedBehavior -ne "nested flags -> SingleHotBar.SlotList" -or
    $sourceSwitch.allRestore -ne "CAM_NestedRestoringToken -> first non-empty KeyboardHotBars group -> first VMHotBarSlot" -or
    $sourceSwitch.metamagicSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList" -or
    $sourceSwitch.metamagicNestedRestore -ne "FilterActionResourceCommand(selected resource) + CAM_NestedRestoringToken -> first CAM_FixedSideBarList VMHotBarSlot" -or
    $sourceSwitch.directProviderNestedOverride -ne "nested flags -> SingleHotBar.SlotList" -or
    $sourceSwitch.passivesSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList" -or
    $sourceSwitch.providerRestoreDispatcher -ne "CAM_ProviderRestoreCommand" -or
    $sourceSwitch.executableList -ne "HotBarList + CAM_FixedSideBarList" -or
    $sourceSwitch.duplicateExecutableLists -ne $false -or
    $sourceSwitch.unprovenGameplayModeCommandsAllowed -ne $false) {
    throw "Native executable slot providers and the parallel FixedSideBar must preserve the BG3 focus/execution contract."
}

$passiveReturn = $evidence.runtimeContract.assignmentNavigation.passivesReturn
if ($passiveReturn.modeAuthority -ne "CAM_ProviderModeMarker.Tag serializes one shoulder-button transition" -or
    $passiveReturn.rightFromPassives -ne "CAM_TabEnterSpecialToken -> CAM_AllModeToken" -or
    $passiveReturn.rightFromAll -ne "CAM_TabReturnFirstToken -> FilterActionResourceCommand(selected resource)" -or
    $passiveReturn.leftFromAll -ne "CAM_TabEnterSpecialToken -> CAM_PassivesModeToken" -or
    $passiveReturn.leftFromPassivesWhenMetamagicAvailable -ne "CAM_TabEnterSpecialToken -> CAM_MetamagicModeToken" -or
    $passiveReturn.leftFromPassivesWhenMetamagicUnavailable -ne "CAM_TabEnterSpecialToken -> CAM_ItemsModeToken -> SetCurrentShownDeckCommand(ItemHotBar)" -or
    $passiveReturn.resourceReturnMilliseconds -ne 70 -or
    $passiveReturn.specialModeSwitchMilliseconds -ne 70 -or
    $passiveReturn.leftFallbackModeSwitchMilliseconds -ne 90 -or
    $passiveReturn.ordinaryResourceClickHandlersEligibleDuringReturn -ne $false -or
    $passiveReturn.singleShoulderPressSingleLogicalTransition -ne $true) {
    throw "All/Passives/Metamagic/Items/Cantrips/resource navigation must remain one serialized provider transition per shoulder press."
}
if ($evidence.runtimeContract.assignmentNavigation.visibleFocusVisualStyle -ne $null -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearSelectedIndex -ne -1 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.filterCommandCount -ne 1 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.settleMilliseconds -ne 70 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.armToken -ne "CAM_ResetFirstFocusToken" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.restoreSelectedIndex -ne 0 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusTarget -ne "selected concrete ListBoxItem templated parent" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusAction -ne "SetMoveFocusAction(DeferFocusAction=True)" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusPublishesEntryCommit -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearsTokenAfterEntryCommit -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearLocalFocus -ne $true -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.invalidateFocus -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusesListContainer -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.selectedItemMirrorsLocalFocus -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.entryStateSource -ne "LocalFocus.DataContext after concrete-item SetMoveFocusAction handoff" -or
    $null -ne $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.entryCommitToken -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.programmaticWakeSignal -ne "HotBarList.SelectionChanged delayed LocalFocus wake" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.programmaticStateSource -ne "HotBarList.LocalFocus.DataContext after deferred focus" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.selectedItemEntryStateWrites -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.resetTokenClearedBySelectedContainer -ne $true -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusChrome.selector -ne "CAM_MainSelector" -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusChrome.template -ne "SelectorTemplate" -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusChrome.sharedCoordinateRoot -ne "CAM_ActionViewport" -or
    $evidence.runtimeContract.assignmentNavigation.visibleFocusChrome.emptyCellPresentation -ne "DynamicResource EmptyCellTemplate") {
    throw "0.0.64 concrete-first-item/native-selector evidence is incomplete."
}

$required = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_ResourceTabs"',
    'ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"',
    '<RowDefinition Height="84"/>',
    '<RowDefinition Height="850"/>',
    'x:Name="CAM_ResourceStrip"',
    'x:Name="CAM_HotbarBodyResourcesBg"',
    'x:Key="CAM_BarResources"',
    'bar_resources.png',
    'MinWidth="208"',
    'Converter={StaticResource AddConverter}, ConverterParameter=208',
    'Slices="104,0"',
    'x:Name="CAM_TopTabs"',
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
    '<ls:LSActionPointResources x:Name="ResourcePoints"',
    'SmallActionPointSize="24"',
    'ActionPointGroupSize="56"',
    'Style="{StaticResource ActionResourcesTemplateSelector}"',
    'x:Key="ActionResources.ActionGroup.ActionPointGroup"',
    'x:Key="ActionResources.ActionGroup.DefaultActionPointGroup"',
    'x:Key="ActionResources.ActionGroup.SpellSlot"',
    'ContentTemplate="{StaticResource ActionResources.ActionGroup.ActionPoint}"',
    '<System:Double x:Key="ActionResources.ActionPointGroupSize">56</System:Double>',
    '<System:Double x:Key="ActionResources.ActionPointSize">48</System:Double>',
    '<System:Double x:Key="ActionResources.ActionPointSmallSize">24</System:Double>',
    'Style="{StaticResource RomanNumeralLevelImage}"',
    'x:Name="ResourcesNumeralDisplay"',
    'Converter="{StaticResource LessThanOrEqualMultiConverter}"',
    'ElementName="ResourcePoints" Path="MaxGroupActionPoints"',
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
    'ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"',
    'EventName="TargetPositionChanged"',
    'PropertyName="HorizontalScrollOffset"',
    'Value="{Binding TargetPosition, ElementName=CAM_ResourceTabsScroller}"',
    'h7d02199dg44ecg4a1egbcacg9cc1cec197b3',
    'x:Name="CAM_PassivesTab"',
    'x:Key="CAM_PassivesModeToken"',
    'x:Key="CAM_TabReturnLastToken"',
    'Tag="{x:Null}"',
    'PlayerCharacterProperties.PassivesHotBar.SlotList',
    'Binding="{Binding SlotType}" Value="Item"',
    'Content="{Binding Content}"',
    'ContentTemplate="{StaticResource Template.Item}"',
    'Value="{StaticResource Template.ItemEquipment}"',
    'Value="{StaticResource Template.ItemContainer}"',
    'x:Name="CAM_ActionViewport"',
    'CanContentScroll="False"',
    'x:Key="CAM_ResourceTabItemStyle"',
    'Binding="{Binding ActionResource.TypeId}" Value="SpellSlot"',
    'Binding="{Binding ActionResource.TypeId}" Value="WarlockSpellSlot"',
    'Binding="{Binding ActionResource.MaxValue}" Value="0"',
    'BoundEvent="UITabPrev"',
    'BoundEvent="UITabNext"',
    'SelectNextListBoxItem',
    'EventName="SelectionChanged"',
    'Command="{Binding FilterActionResourceCommand}"',
    'CommandParameter="{Binding SelectedItem, ElementName=CAM_ResourceTabs}"',
    'x:Name="HotBarList"',
    '<Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>',
    'Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"',
    'ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"',
    'ItemsPanel="{StaticResource CAM_ActionGridPanel}"',
    'ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"',
    'ls:MoveFocus.Focusable" Value="True"',
    'Setter Property="FocusVisualStyle" Value="{x:Null}"',
    'x:Key="CAM_ResetFirstFocusToken"',
    'x:Key="CAM_NestedEnteredToken"',
    'x:Key="CAM_NestedRestoringToken"',
    'x:Name="CAM_NestedReturnMarker"',
    'Property="CommandParameter" Value="CloseWidget"',
    'x:Name="ButtonHintsContainer"',
    'ActionLeftEvent="UILeft"',
    'x:Name="ShowContextMenu"',
    'Visibility="Collapsed"',
    'Command="{x:Null}"'
)
foreach ($needle in $required) {
    if (-not $text.Contains($needle)) {
        throw "Self-contained resource-first runtime is missing required seam: $needle"
    }
}

foreach ($forbidden in @(
    'x:Name="CAM_FilterTabs"',
    'CAM_CommonFilterTab',
    'CAM_ClassFilterTab',
    'CAM_CantripsFilterTab',
    'CAM_ItemsFilterTab',
    'CAM_PassivesFilterTab',
    'IsShowingPassivesDeck',
    'SetIsShowingPassivesDeckCommand',
    'CAM_ResourceFilterHolder',
    'CAM_ResourceFilterList',
    'CAM_ResourceFilterTemplate',
    'ResourceFilterBinding',
    'CAM_TabDotOn',
    'CAM_TabDotOff',
    'CAM_FilterTabItemStyle',
    'CAM_LiveDetails',
    'LiveDetails',
    'x:Name="CAM_FilteredSlotList"',
    'x:Name="CAM_FilteredSlotHolder"',
    'x:Name="SingleBar"',
    'x:Name="singleBarHolder"',
    'x:Name="CAM_SingleSelector"',
    'x:Name="CAM_SingleActionTooltip"',
    'PlayerCharacterProperties.ControllerHotBars',
    'PlayerCharacterProperties.SpellsAndActions',
    'CurrentPlayer.SelectedCharacter.Inventory.Slots',
    'CurrentPlayer.SelectedCharacter.Stats.Passives',
    'LocalFocus.Tag',
    'ShowContextMenuCommand',
    'AssignSlotCommand',
    'SwapSlotCommand',
    'AddRadialCommand',
    'RemoveRadialCommand',
    'HotBarSlotStyle',
    'HotKey',
    'SlotIconStyle',
    'x:Key="CAM_SelectorTemplate"',
    'x:Name="ToggleWeaponSet"',
    'x:Name="WeaponSetShortcutBinding"',
    'SwitchWeaponSetCommand',
    'HoldTime="{StaticResource HoldTimeShortcuts}"',
    'Columns="5"',
    'Width="632"',
    'CanContentScroll="True"',
    'DisableScrolling="True"',
    'Public/Game/GUI/',
    'ScriptExtender'
)) {
    if ($text.Contains($forbidden)) {
        throw "Forbidden obsolete/non-resource-first seam is present: $forbidden"
    }
}

# Resource tabs are the only tab/filter layer.
if ([regex]::Matches($text, 'ItemsSource="\{Binding CurrentPlayer\.UIData\.ActionResourcesCostPreview\}"').Count -ne 1) {
    throw "ActionResourcesCostPreview must feed exactly one top-level resource-tab list."
}
if ($text.Contains('CAM_ResourceFilter')) {
    throw "A secondary resource-filter layer must not return."
}

# The central HotBarList owns resource/Passives/nested VMHotBarSlot state.
# FixedSideBar is a second, simultaneously visible native VMHotBarSlot list.
$mainList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainList.Success -or
    -not $mainList.Value.Contains('<Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>') -or
    -not $mainList.Value.Contains('Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}" Value="{StaticResource CAM_ItemsModeToken}"') -or
    -not $mainList.Value.Contains('Value="{Binding CurrentShownDeck.SlotList}"') -or
    $mainList.Value.Contains('Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList}"') -or
    -not $mainList.Value.Contains('Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}" Value="{StaticResource CAM_PassivesModeToken}"') -or
    -not $mainList.Value.Contains('Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"') -or
    -not $mainList.Value.Contains('Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars}"') -or
    -not $mainList.Value.Contains('Value="{StaticResource CAM_AllGroupContainerStyle}"') -or
    -not $mainList.Value.Contains('Value="{StaticResource CAM_AllGroupTemplate}"') -or
    -not $mainList.Value.Contains('Value="{StaticResource CAM_AllGroupsPanel}"') -or
    -not $mainList.Value.Contains('<Setter Property="ItemContainerStyle" Value="{StaticResource CAM_ActionGridSlotContainer}"/>') -or
    -not $mainList.Value.Contains('<Setter Property="ItemTemplate" Value="{StaticResource CAM_ActionGridSlotTemplate}"/>') -or
    -not $mainList.Value.Contains('<Setter Property="ItemsPanel" Value="{StaticResource CAM_ActionGridPanel}"/>') -or
    -not $mainList.Value.Contains('<ls:LSScrollViewer') -or
    -not $mainList.Value.Contains('ls:LSScrollViewer.ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"')) {
    throw "The main HotBarList must retain native SingleHotBar/ItemHotBar/PassivesHotBar/KeyboardHotBars providers and must never substitute FixedSideBar for spells."
}
# Original installed HotBar 1.8.910.0 renders FixedSideBar alongside the
# spell deck; this must be a separate, controller-focusable VMHotBarSlot list.
$sidebar = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="CAM_FixedSideBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $sidebar.Success -or
    -not $sidebar.Value.Contains('ItemsSource="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.FixedSideBar.SlotList}"') -or
    -not $sidebar.Value.Contains('ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"') -or
    -not $sidebar.Value.Contains('ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"') -or
    -not $sidebar.Value.Contains('ItemsPanel="{StaticResource CAM_FixedSideBarPanel}"') -or
    -not $sidebar.Value.Contains('ActionNextEvent="UIDown"') -or
    -not $sidebar.Value.Contains('ActionPrevEvent="UIUp"') -or
    -not $sidebar.Value.Contains('LocalFocusSelector="{Binding ElementName=CAM_FixedSideBarSelector,Mode=OneWay}"') -or
    -not $sidebar.Value.Contains('<Setter Property="IsEnabled" Value="False"/>') -or
    -not $sidebar.Value.Contains('<Setter Property="IsEnabled" Value="True"/>') -or
    -not $sidebar.Value.Contains('KeyboardNavigation.DirectionalNavigation="Contained"') -or
    -not $sidebar.Value.Contains('CAM_MetamagicModeToken') -or
    $sidebar.Value.Contains('TargetName="CAM_ProviderModeMarker" PropertyName="Tag"') -or
    $mainList.Value.Contains('TargetName="CAM_ProviderModeMarker" PropertyName="Tag"') -or
    -not $sidebar.Value.Contains('EventName="LocalFocusChanged"') -or
    -not $sidebar.Value.Contains('Value="{Binding LocalFocus.DataContext, ElementName=CAM_FixedSideBarList}"')) {
    throw "The fixed sidebar must remain a native, independently focused executable VMHotBarSlot list."
}
$gridTemplate = [regex]::Match(
    $text,
    '<DataTemplate x:Key="CAM_ActionGridSlotTemplate">[\s\S]*?</DataTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $gridTemplate.Success -or
    -not $gridTemplate.Value.Contains('Content.IsModified') -or
    -not $gridTemplate.Value.Contains('HotbarSlotGlow') -or
    -not $gridTemplate.Value.Contains('Content.IsMetaMagic') -or
    -not $gridTemplate.Value.Contains('HotBarActiveSlotIndicatorMetamagic') -or
    -not $gridTemplate.Value.Contains('IsActive') -or
    -not $gridTemplate.Value.Contains('CanUse')) {
    throw "Controller cells must consume original game-owned active/modified metamagic state and retain CanUse."
}
# The installed 1.8.910.0 controller radial dims unmodified spells when
# BG3-owned MetamagicActive is true. The 0.0.101 overlay-only UI omitted
# that negative-compatibility signal, so even an active metamagic selection
# left all main spell cells at similar intensity.
$nativeIncompatibleSpell = [regex]::Match(
    $gridTemplate.Value,
    '<MultiDataTrigger>\s*<MultiDataTrigger.Conditions>\s*<Condition Binding="\{Binding SlotType\}" Value="Spell"/>\s*<Condition Binding="\{Binding Content.IsModified\}" Value="False"/>\s*<Condition Binding="\{Binding DataContext.CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.MetamagicActive, RelativeSource=\{RelativeSource AncestorType=\{x:Type ls:UIWidget\}\}\}" Value="True"/>\s*</MultiDataTrigger.Conditions>\s*<Setter TargetName="CAM_MetamagicIncompatibleOverlay" Property="Visibility" Value="Visible"/>\s*<Setter TargetName="GenericIcon" Property="Opacity" Value="0.7"/>\s*</MultiDataTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $nativeIncompatibleSpell.Success -or
    -not $gridTemplate.Value.Contains('x:Name="CAM_MetamagicIncompatibleOverlay"') -or
    -not $gridTemplate.Value.Contains('Opacity="0.2"') -or
    -not $gridTemplate.Value.Contains('Visibility="Collapsed"') -or
    -not $gridTemplate.Value.Contains('Content.IsModified') -or
    -not $gridTemplate.Value.Contains('HotbarSlotGlow')) {
    throw "Metamagic must distinguish nonmodified native Spell slots only while BG3 MetamagicActive is true, preserving native modified-slot glow."
}
if ($gridTemplate.Value.Contains('PropertyName="IsActive"') -or
    $gridTemplate.Value.Contains('PropertyName="MetamagicActive"') -or
    $gridTemplate.Value.Contains('Command="{Binding ToggleMetamagic') -or
    $gridTemplate.Value.Contains('MetamagicCompatibilityConverter')) {
    throw "CAM must not mutate game-owned metamagic toggles or invent compatibility classification."
}

if ([regex]::Matches($text, 'Meta shoulder entry focuses its parallel native-slot region').Count -ne 2 -or
    [regex]::Matches($text, 'CommandParameter="{Binding SelectedItem, ElementName=CAM_ResourceTabs}"').Count -lt 3) {
    throw "Both LB/RB transitions to metamagic must preserve a resource-filtered spell grid while focusing the parallel sidebar."
}

if ([regex]::Matches($text, 'SetCurrentShownDeckCommand').Count -lt 3 -or
    [regex]::Matches($text, 'CommandParameter="ItemHotBar"').Count -lt 3 -or
    $text.Contains('CommandParameter="CommonHotBar"') -or
    $text.Contains('CommandParameter="ClassHotBar"') -or
    $text.Contains('CommandParameter="InvalidHotBar"')) {
    throw "CurrentShownDeck is allowed only through the proven ItemHotBar provider; Common/Class/Invalid deck runtime paths must stay absent."
}
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="HotBarList"').Count -ne 1) {
    throw "CAM must have exactly one executable HotBarList."
}
foreach ($obsoleteList in @('CAM_FilteredSlotList','CAM_FilteredSlotHolder','SingleBar','singleBarHolder','CAM_SingleSelector','CAM_SingleActionTooltip')) {
    if ($text.Contains($obsoleteList)) {
        throw "Duplicate executable/focus surface must not return: $obsoleteList"
    }
}

# No custom details surface: the sole executable list owns the sole native tooltip.
if (-not $text.Contains('x:Name="CAM_ActionTooltip"')) {
    throw "HotBarList must own the native focused-action tooltip."
}
if (-not $text.Contains('Value="{Binding LocalFocus.DataContext.Content, ElementName=HotBarList}"')) {
    throw "Main tooltip must consume focused VMHotBarSlot.Content."
}

# Top-level browsing (resource or Passives) must close on B only when native nested state is absent.
$closeTrigger = [regex]::Match(
    $text,
    '<MultiDataTrigger>\s*<MultiDataTrigger\.Conditions>\s*' +
    '<Condition Binding="\{Binding IsShowingAContainerWithVariants\}" Value="False"/>\s*' +
    '<Condition Binding="\{Binding IsSelectingUpcastedSpell\}" Value="False"/>\s*' +
    '<Condition Binding="\{Binding IsShowingItemsToThrow\}" Value="False"/>\s*' +
    '</MultiDataTrigger\.Conditions>\s*' +
    '<Setter TargetName="CancelButton" Property="Command" Value="\{Binding CustomEvent\}"/>\s*' +
    '<Setter TargetName="CancelButton" Property="CommandParameter" Value="CloseWidget"/>[\s\S]*?' +
    '</MultiDataTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $closeTrigger.Success) {
    throw "Top-level B close trigger must be the exact three-native-nested-flags -> CloseWidget contract."
}

Write-Host "Self-contained Patch 8 runtime contract passed: resource/special providers plus grouped KeyboardHotBars fallback remain native-slot-driven, nested return restores the active provider, and focus/tooltip remain LocalFocus-driven."


# Weapon-set switching is deliberately absent from CAM after repeated runtime failures.
foreach ($forbiddenWeaponSeam in @('x:Name="ToggleWeaponSet"','x:Name="WeaponSetShortcutBinding"','SwitchWeaponSetCommand','HoldTime="{StaticResource HoldTimeShortcuts}"')) {
    if ($text.Contains($forbiddenWeaponSeam)) {
        throw "Broken CAM-owned weapon-set input must remain absent: $forbiddenWeaponSeam"
    }
}
if (-not $text.Contains('ActionLeftEvent="UILeft"')) {
    throw "Ordinary grid-left navigation must remain UILeft."
}


# The native LocalFocusSelector controls are siblings of their ScrollViewer,
# not children of its clipping surface. The UI's own fixed-height action
# regions therefore need explicit clipping so scroll-boundary selection
# cannot render into the LB/RB resource-tab header. This is a render-only
# invariant, NOT proof of one-row-at-a-time navigation.
$actionViewport = [regex]::Match(
    $text,
    '<Grid\s+x:Name="CAM_ActionViewport"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$fixedSidebarRegion = [regex]::Match(
    $text,
    '<Grid\s+x:Name="CAM_FixedSideBarRegion"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $actionViewport.Success -or
    -not $actionViewport.Value.Contains('ClipToBounds="True"') -or
    -not $actionViewport.Value.Contains('Grid.Row="1"') -or
    -not $fixedSidebarRegion.Success -or
    -not $fixedSidebarRegion.Value.Contains('ClipToBounds="True"') -or
    -not $fixedSidebarRegion.Value.Contains('Grid.Row="1"')) {
    throw "Both native scroll-focus selectors must be clipped by their action-row viewports, not paint across the resource-tab header."
}

# The direct executable list is also the sole scroll owner.
$hotBarList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $hotBarList.Success -or
    -not $hotBarList.Value.Contains('ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"')) {
    throw "Direct HotBarList must own controller scroll-follow behavior."
}
if ($hotBarList.Value.Contains('x:Name="CAM_FilteredSlotList"') -or $hotBarList.Value.Contains('KeyboardNavigation.DirectionalNavigation="Continue"')) {
    throw "HotBarList must not wrap a second executable controller list."
}


# Nested-state focus triggers, when present, must target the same executable list.
foreach ($flag in @('IsShowingAContainerWithVariants','IsSelectingUpcastedSpell','IsShowingItemsToThrow')) {
    $pattern = '<b:DataTrigger Binding="\{Binding ' + $flag + '\}" Value="True">[\s\S]*?FocusElement="\{Binding ElementName=HotBarList\}"[\s\S]*?</b:DataTrigger>'
    if (-not [regex]::IsMatch($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Nested-state focus must remain on HotBarList: $flag"
    }
}


# Adaptive presentation: ActionRadials LocalFocusSelector owns logical navigation,
# grid columns derive from actual viewport width, and scrolling stays pixel-based.
$actionGridPanel = [regex]::Match(
    $text,
    '<ItemsPanelTemplate\b[^>]*x:Key="CAM_ActionGridPanel"[\s\S]*?</ItemsPanelTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $actionGridPanel.Success -or
    $actionGridPanel.Value.Contains('Columns="5"') -or
    $actionGridPanel.Value.Contains('Width="632"') -or
    $actionGridPanel.Value.Contains('UseWidgetNavigation="True"') -or
    $actionGridPanel.Value.Contains('ls:MoveFocus.InternalFocusable="True"') -or
    $actionGridPanel.Value.Contains('AlwaysSelectFirst=') -or
    $actionGridPanel.Value.Contains('ExtendedRows=') -or
    -not $actionGridPanel.Value.Contains('EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"') -or
    -not $actionGridPanel.Value.Contains('Converter="{StaticResource DivideMultiConverter}" ConverterParameter="Floor"') -or
    -not $actionGridPanel.Value.Contains('AncestorType={x:Type ScrollContentPresenter}')) {
    throw "CAM_ActionGridPanel must keep adaptive columns while restoring the 0.0.29-proven native EmptyCellTemplate focus surface."
}

$slotContainer = [regex]::Match(
    $text,
    '<Style\b[^>]*x:Key="CAM_ActionGridSlotContainer"[\s\S]*?</Style>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $slotContainer.Success -or
    -not $slotContainer.Value.Contains('Property="ls:MoveFocus.Focusable" Value="True"') -or
    -not $slotContainer.Value.Contains('Setter Property="FocusVisualStyle" Value="{x:Null}"') -or
    -not $slotContainer.Value.Contains('b:DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"') -or
    -not $slotContainer.Value.Contains('RightOperand="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $slotContainer.Value.Contains('FocusElement="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"') -or
    -not $slotContainer.Value.Contains('DeferFocusAction="True"') -or
    -not $slotContainer.Value.Contains('PropertyName="Tag"') -or
    -not $slotContainer.Value.Contains('Value="{x:Null}"') -or
    $slotContainer.Value.Contains('CAM_EntryFocusCommittedToken') -or
    $slotContainer.Value.Contains('CAM_CellFocusFill') -or
    $slotContainer.Value.Contains('CAM_CellFocusFrame') -or
    $slotContainer.Value.Contains('Trigger Property="ls:MoveFocus.IsFocused" Value="True"') -or
    $slotContainer.Value.Contains('Style.FocusVisualStyle')) {
    throw "SelectedIndex may hand off only once to the concrete selected ListBoxItem; visible focus must belong to the native selector."
}

if (-not $hotBarList.Value.Contains('CanContentScroll="False"') -or
    -not $hotBarList.Value.Contains('VerticalScrollBarVisibility="Auto"') -or
    -not $hotBarList.Value.Contains('ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"')) {
    throw "HotBarList must use pixel scrolling with the native vertical focus margin."
}

$resourceTabs = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="CAM_ResourceTabs"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabs.Success -or
    -not $resourceTabs.Value.Contains('MaxWidth="720"') -or
    -not $resourceTabs.Value.Contains('HorizontalContentAlignment="Center"') -or
    -not $resourceTabs.Value.Contains('<ls:LSScrollViewer x:Name="CAM_ResourceTabsScroller"') -or
    -not $resourceTabs.Value.Contains('HorizontalScrollBarVisibility="Hidden"') -or
    -not $resourceTabs.Value.Contains('VerticalScrollBarVisibility="Disabled"') -or
    -not $resourceTabs.Value.Contains('CanContentScroll="False"') -or
    -not $resourceTabs.Value.Contains('ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"') -or
    -not $resourceTabs.Value.Contains('EventName="TargetPositionChanged"') -or
    -not $resourceTabs.Value.Contains('PropertyName="HorizontalScrollOffset"') -or
    -not $resourceTabs.Value.Contains('Value="{Binding TargetPosition, ElementName=CAM_ResourceTabsScroller}"') -or
    $resourceTabs.Value.Contains('AutoScrollBehavior') -or
    $resourceTabs.Value.Contains('BringSelectionIntoView=') -or
    $resourceTabs.Value.Contains('ScrollIntoView=') -or
    $resourceTabs.Value.Contains('ScrollTo=')) {
    throw "Dynamic resource tabs must use the captured LSScrollViewer target-position commit seam and no selection/index autoscroll path."
}

$resourceTabsPanel = [regex]::Match(
    $text,
    '<ItemsPanelTemplate\b[^>]*x:Key="CAM_ResourceTabsPanel"[\s\S]*?</ItemsPanelTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabsPanel.Success -or
    -not $resourceTabsPanel.Value.Contains('<StackPanel Orientation="Horizontal"') -or
    $resourceTabsPanel.Value.Contains('AlignableWrapPanel')) {
    throw "Resource previews must remain a single horizontal row."
}

# The captured native HotBar resource row is consistently bottom-anchored:
# ActionResourcesContainer, HotbarBodyResourcesBg, ActionResources and ActionResourcesList.
# CAM previously used centered alignment against a fixed-height 84-unit row,
# moving glyphs/frames away from the original baseline.
foreach ($expectation in @(
    '<Grid x:Name="CAM_ResourceStrip"',
    '<ls:LSNineSliceImage x:Name="CAM_HotbarBodyResourcesBg"',
    '<StackPanel x:Name="CAM_TopTabs"',
    '<ls:LSListBox x:Name="CAM_ResourceTabs"'
)) {
    $start = $text.IndexOf($expectation)
    if ($start -lt 0) { throw "Missing native resource baseline element: $expectation" }
    $end = $text.IndexOf('>', $start)
    $opening = $text.Substring($start, $end - $start + 1)
    if (-not $opening.Contains('VerticalAlignment="Bottom"')) {
        throw "Resource baseline must be bottom-anchored like the captured HotBar: $expectation"
    }
}
if (-not $resourceTabsPanel.Value.Contains('VerticalAlignment="Bottom"')) {
    throw "The resource items panel must use the same bottom baseline as native ActionResources."
}
foreach ($provider in @("Cantrips", "Items", "Metamagic", "Passives", "All")) {
    $pattern = '<Grid x:Name="CAM_' + $provider + 'Tab"[\s\S]*?>\s*<Grid Margin="4,-10,4,10"[\s\S]*?>'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success -or [regex]::Matches($match.Value, 'VerticalAlignment="Bottom"').Count -ne 2) {
        throw "Special provider $provider must share the same bottom resource baseline."
    }
}

if (-not $text.Contains('<RowDefinition Height="84"/>') -or
    -not $text.Contains('<RowDefinition Height="850"/>') -or
    -not $text.Contains('x:Name="CAM_ActionViewport"') -or
    -not $text.Contains('Height="850"')) {
    throw "Compact tab header must preserve the full 850px action viewport."
}

$tabLeft = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="CAM_TabLeft"[\s\S]*?</ls:LSButton>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$tabRight = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="CAM_TabRight"[\s\S]*?</ls:LSButton>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $tabLeft.Success -or -not $tabRight.Success -or
    -not $tabLeft.Value.Contains('CAM_TabEnterSpecialToken') -or
    -not $tabLeft.Value.Contains('CAM_TabReturnLastToken') -or
    -not $tabLeft.Value.Contains('CAM_CantripsModeToken') -or
    -not $tabLeft.Value.Contains('CAM_ItemsModeToken') -or
    -not $tabLeft.Value.Contains('CAM_MetamagicModeToken') -or
    -not $tabLeft.Value.Contains('CAM_PassivesModeToken') -or
    -not $tabLeft.Value.Contains('CAM_AllModeToken') -or
    -not $tabLeft.Value.Contains('FilterCantripsCommand') -or
    -not $tabLeft.Value.Contains('MillisecondsPerTick="90"') -or
    -not $tabLeft.Value.Contains('Reversed="True"') -or
    -not $tabRight.Value.Contains('CAM_TabReturnFirstToken') -or
    -not $tabLeft.Value.Contains('CommandParameter="ItemHotBar"') -or
    -not $tabRight.Value.Contains('CommandParameter="ItemHotBar"') -or
    -not $tabRight.Value.Contains('CAM_TabEnterSpecialToken') -or
    -not $tabRight.Value.Contains('CAM_CantripsModeToken') -or
    -not $tabRight.Value.Contains('CAM_ItemsModeToken') -or
    -not $tabRight.Value.Contains('CAM_MetamagicModeToken') -or
    -not $tabRight.Value.Contains('CAM_PassivesModeToken') -or
    -not $tabRight.Value.Contains('CAM_AllModeToken') -or
    -not $tabRight.Value.Contains('MillisecondsPerTick="70"') -or
    -not $tabRight.Value.Contains('CAM_TabCycleRightToken') -or
    $tabLeft.Value.Contains('ForceSelect="True"') -or
    $tabRight.Value.Contains('ForceSelect="True"')) {
    throw "LB/RB must form one resource-plus-Cantrips-plus-Items-plus-Metamagic-plus-Passives-plus-All cycle without ForceSelect."
}

# Regression 0.0.85: CAM_ResourceTabs.Tag was repurposed for the selected
# concrete UIElement scroll target, but numerous shoulder/nested mode checks
# still compared that UIElement with string mode tokens. That disables LB/RB.
if ([regex]::IsMatch($text, '\{Binding Tag,\s*ElementName=CAM_ResourceTabs\}')) {
    throw "Resource list Tag is the scroll target, never the provider mode; all mode readers must bind CAM_ProviderModeMarker."
}
$modeRead = '{Binding Tag, ElementName=CAM_ProviderModeMarker}'
$clickGuard = '<b:ComparisonCondition LeftOperand="{Binding Tag, ElementName=CAM_TabCycleMarker}" Operator="Equal" RightOperand="{x:Null}"/>'
foreach ($shoulderCase in @(
    @{ Name = "LB"; Button = $tabLeft; Expected = 9 },
    @{ Name = "RB"; Button = $tabRight; Expected = 7 }
)) {
    $shoulder = $shoulderCase.Button
    $clicks = @([regex]::Matches($shoulder.Value, '<b:EventTrigger EventName="Click">[\s\S]*?</b:EventTrigger>', [System.Text.RegularExpressions.RegexOptions]::Singleline))
    if ($clicks.Count -ne $shoulderCase.Expected) {
        throw "$($shoulderCase.Name) must have $($shoulderCase.Expected) guarded transitions; got $($clicks.Count)."
    }
    foreach ($click in $clicks) {
        if (-not $click.Value.Contains($modeRead) -or
            -not $click.Value.Contains($clickGuard) -or
            -not $click.Value.Contains('CAM_TabCycleMarker')) {
            throw "Each shoulder transition must read the provider marker and consume one Click before a later handler evaluates."
        }
    }
}
if ($text.Contains('TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="{StaticResource CAM_') -or
    -not $text.Contains('ls:LSScrollViewer.ScrollToElement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"')) {
    throw "Provider-mode refactor must leave concrete selected ListBoxItem scrolling intact."
}

# Special providers have no native VMActionResourceCostPreview; their frames
# must still use the *same* captured HotBar resource-box chrome and margins.
$specialStart = $text.IndexOf('<Grid x:Name="CAM_CantripsTab"')
$specialEnd = if ($specialStart -ge 0) { $text.IndexOf('</StackPanel>', $specialStart) } else { -1 }
if ($specialStart -lt 0 -or $specialEnd -le $specialStart) {
    throw "Cannot find the special-provider strip."
}
$specialTabs = $text.Substring($specialStart, $specialEnd - $specialStart)
if ([regex]::Matches($specialTabs, 'Margin="\{StaticResource CAM_ResourceBackgroundMargin\}"').Count -ne 10 -or
    [regex]::Matches($specialTabs, 'Width="72"').Count -lt 5 -or
    -not $specialTabs.Contains('Source="{StaticResource IconMiniCantrip}"') -or
    -not [regex]::IsMatch($specialTabs, 'Source="\{StaticResource IconMiniCantrip\}"\s+Width="72"\s+Height="72"')) {
    throw "Special resource-box tabs must align chrome with the captured HotBar and preserve the native Cantrips glyph scale."
}

if ([regex]::Matches($resourceTabs.Value, '<b:EventTrigger EventName="SelectionChanged">').Count -ne 5 -or
    -not $resourceTabs.Value.Contains('CAM_TabCycleRightToken') -or
    -not $resourceTabs.Value.Contains('CAM_TabCycleLeftToken') -or
    -not $resourceTabs.Value.Contains('CAM_TabReturnLastToken') -or
    -not $resourceTabs.Value.Contains('TargetName="CAM_ProviderModeMarker" PropertyName="Tag" Value="{StaticResource CAM_CantripsModeToken}"') -or
    -not $resourceTabs.Value.Contains('TargetName="CAM_ProviderModeMarker" PropertyName="Tag" Value="{StaticResource CAM_ItemsModeToken}"') -or
    -not $resourceTabs.Value.Contains('SetCurrentShownDeckCommand') -or
    -not $resourceTabs.Value.Contains('CommandParameter="ItemHotBar"') -or
    -not $resourceTabs.Value.Contains('FilterCantripsCommand') -or
    -not $resourceTabs.Value.Contains('CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasCantrips') -or
    [regex]::Matches($resourceTabs.Value, 'FilterActionResourceCommand').Count -lt 2 -or
    [regex]::Matches($resourceTabs.Value, 'TargetName="HotBarList" PropertyName="LocalFocus" Value="{x:Null}"').Count -lt 4) {
    throw "Resource selection must route right-wrap through Cantrips when available and otherwise native ItemHotBar."
}

$resourceRestoreTimer = [regex]::Match(
    $resourceTabs.Value,
    '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceRestoreTimer.Success -or
    -not $resourceRestoreTimer.Value.Contains('CAM_TabReturnLastToken') -or
    -not $resourceRestoreTimer.Value.Contains('Operator="NotEqual"') -or
    -not $resourceRestoreTimer.Value.Contains('Value="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $resourceRestoreTimer.Value.Contains('PropertyName="SelectedIndex"') -or
    -not $resourceRestoreTimer.Value.Contains('Value="0"') -or
    $resourceRestoreTimer.Value.Contains('SelectedItem.Content') -or
    $resourceRestoreTimer.Value.Contains('ShowTooltipOnUIElementCommand') -or
    $resourceRestoreTimer.Value.Contains('CreateFocusedTooltipDataCommand') -or
    $resourceRestoreTimer.Value.Contains('HighlightResourcesCommand')) {
    throw "Tab-settle timer may only arm concrete first-item focus; presentation waits for authoritative LocalFocus."
}

$resourceTabStyle = [regex]::Match(
    $text,
    '<Style\b[^>]*x:Key="CAM_ResourceTabItemStyle"[\s\S]*?</Style>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabStyle.Success -or
    -not $resourceTabStyle.Value.Contains('Property="Margin" Value="-4,0,-4,0"') -or
    -not $resourceTabStyle.Value.Contains('<ContentPresenter HorizontalAlignment="Center"') -or
    -not $resourceTabStyle.Value.Contains('Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"') -or
    -not $resourceTabStyle.Value.Contains('TargetObject="{Binding RelativeSource={RelativeSource AncestorType={x:Type ls:LSListBox}}}"') -or
    -not $resourceTabStyle.Value.Contains('PropertyName="Tag"') -or
    -not $resourceTabStyle.Value.Contains('Value="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"') -or
    $resourceTabStyle.Value.Contains('CAM_BoxResource') -or
    $resourceTabStyle.Value.Contains('ResourcePoints')) {
    throw "Resource ListBoxItem may use IsSelected only as transport to publish its concrete UIElement scroll target; native resource visuals stay item-template-owned."
}
if ([regex]::Matches($resourceTabStyle.Value, 'Binding="{Binding ActionResource.MaxValue}" Value="0"').Count -ne 1 -or
    [regex]::Matches($resourceTabStyle.Value, 'Setter Property="IsEnabled" Value="False"').Count -lt 2) {
    throw "Null/MaxValue=0 resource previews must remain collapsed and disabled at the outer container."
}

# Native Patch 8 HotBar declares the resource-box image margin locally:
# <Thickness x:Key="ResourceBackgroundMargin">0</Thickness>.
# The controller library has a different scope and must declare its own
# literal alias rather than hoping the keyboard page's dictionary is loaded.
if (-not $text.Contains('<Thickness x:Key="CAM_ResourceBackgroundMargin">0</Thickness>')) {
    throw "Controller resource-box content references an undeclared or non-native margin."
}
$localKeys = @{}
foreach ($match in [regex]::Matches($text, 'x:Key="(CAM_[A-Za-z0-9_.]+)"')) {
    $localKeys[$match.Groups[1].Value] = $true
}
foreach ($match in [regex]::Matches($text, '\{(?:StaticResource|DynamicResource) (CAM_[A-Za-z0-9_.]+)\}')) {
    $key = $match.Groups[1].Value
    if (-not $localKeys.ContainsKey($key)) {
        throw "CAM template refers to an undefined local visual resource: $key"
    }
}

# A native point DataTemplate is now nested inside CAM_ResourceTabTemplate.
# Match the complete outer DataTemplate, not its first inner closing tag.
$resourceTabHeader = [regex]::Match(
    $text,
    '<DataTemplate\b[^>]*x:Key="CAM_ResourceTabTemplate"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$resourceTabTemplate = [pscustomobject]@{ Success = $false; Value = "" }
if ($resourceTabHeader.Success) {
    $resourceTabEndOffset = $resourceTabHeader.Index + $resourceTabHeader.Length
    $resourceTabTail = $text.Substring($resourceTabEndOffset)
    $templateDepth = 1
    foreach ($tag in [regex]::Matches($resourceTabTail, '</?DataTemplate\b[^>]*>')) {
        if ($tag.Value.StartsWith('</DataTemplate')) {
            $templateDepth--
        } elseif (-not $tag.Value.EndsWith('/>')) {
            $templateDepth++
        }
        if ($templateDepth -eq 0) {
            $resourceTabTemplate = [pscustomobject]@{
                Success = $true
                Value = $text.Substring(
                    $resourceTabHeader.Index,
                    $resourceTabHeader.Length + $tag.Index + $tag.Length
                )
            }
            break
        }
    }
}


if (-not $resourceTabTemplate.Success -or
    -not $resourceTabTemplate.Value.Contains('<ls:LSButton Padding="0"') -or
    -not $resourceTabTemplate.Value.Contains('Margin="4,-10,4,10"') -or
    -not $resourceTabTemplate.Value.Contains('x:Name="Root" Width="72"') -or
    -not $resourceTabTemplate.Value.Contains('Source="{StaticResource CAM_BoxResourceBg}"') -or
    -not $resourceTabTemplate.Value.Contains('Source="{StaticResource CAM_BoxResource}"') -or
    -not $resourceTabTemplate.Value.Contains('Source="{StaticResource CAM_BoxResourceH}"') -or
    -not $resourceTabTemplate.Value.Contains('Source="{StaticResource CAM_BoxResourceDisabled}"') -or
    -not $resourceTabTemplate.Value.Contains('<ls:LSActionPointResources x:Name="ResourcePoints"') -or
    -not $resourceTabTemplate.Value.Contains('MaxActionPoints="{Binding MaxValue}"') -or
    -not $resourceTabTemplate.Value.Contains('AvailableActionPoints="{Binding Value}"') -or
    -not $resourceTabTemplate.Value.Contains('HighlightedActionPoints="{Binding DataContext.Cost, ElementName=Root}"') -or
    -not $resourceTabTemplate.Value.Contains('DataContext="{Binding ActionResource}"') -or
    -not $resourceTabTemplate.Value.Contains('MaxActionPointGroups="0"') -or
    -not $resourceTabTemplate.Value.Contains('<System:Double x:Key="ActionResources.ActionPointGroupSize">56</System:Double>') -or
    -not $resourceTabTemplate.Value.Contains('<System:Double x:Key="ActionResources.ActionPointSize">48</System:Double>') -or
    -not $resourceTabTemplate.Value.Contains('<System:Double x:Key="ActionResources.ActionPointSmallSize">24</System:Double>') -or
    -not $resourceTabTemplate.Value.Contains('x:Key="ActionResources.ActionGroup.ActionPointGroup"') -or
    -not $resourceTabTemplate.Value.Contains('x:Key="ActionResources.ActionGroup.SpellSlot"') -or
    $resourceTabTemplate.Value.Contains('ActionPointTemplate="{StaticResource CAM_') -or
    -not $resourceTabTemplate.Value.Contains('SmallActionPointSize="24"') -or
    -not $resourceTabTemplate.Value.Contains('ActionPointGroupSize="56"') -or
    -not $resourceTabTemplate.Value.Contains('Style="{StaticResource ActionResourcesTemplateSelector}"') -or
    -not $resourceTabTemplate.Value.Contains('x:Name="ResourcesNumeralDisplay"') -or
    -not $resourceTabTemplate.Value.Contains('Converter="{StaticResource LessThanOrEqualMultiConverter}"') -or
    -not $resourceTabTemplate.Value.Contains('ElementName="ResourcePoints" Path="MaxGroupActionPoints"') -or
    -not $resourceTabTemplate.Value.Contains('Binding="{Binding Path=Tag, ElementName=Root}" Value="SpellSlot"') -or
    -not $resourceTabTemplate.Value.Contains('Binding="{Binding ActionResource.TypeId}" Value="SpellSlot"') -or
    -not $resourceTabTemplate.Value.Contains('Binding="{Binding ActionResource.TypeId}" Value="WarlockSpellSlot"') -or
    -not $resourceTabTemplate.Value.Contains('<Trigger Property="IsMouseOver" Value="True">') -or
    -not $resourceTabTemplate.Value.Contains('Binding="{Binding ActionResource.Value}" Value="0"') -or
    -not $resourceTabTemplate.Value.Contains('Binding="{Binding ActionResource.TypeId}" Value="BardicInspiration"') -or
    $resourceTabTemplate.Value.Contains('CAM_ResourceTabs.Tag') -or
    $resourceTabTemplate.Value.Contains('CAM_FilterButtonBackground') -or
    $resourceTabTemplate.Value.Contains('btn_pil_') -or
    $resourceTabTemplate.Value.Contains('Style="{StaticResource SectionImageStyle}"')) {
    throw "Native resource contents must be owned by the literal Patch 8 ActionResourcesList item template."
}


# Keyboard group templates alone still resolve controller StaticResource
# icon paths in the globally defined ActionPoint DataTemplate. Capture
# v0.0.97 proved keyboard DefaultTheme.Styles.xaml uses Shared/Resources,
# whereas controller DefaultTheme_c.Styles.xaml uses ActionResources_c.
$keyboardPointPaths = @(
    @("ActionResourcePointIconsPath", "Assets/Shared/Resources/"),
    @("ActionResourcePointHighlightIconsPath", "Assets/Shared/Resources/Highlight/"),
    @("ActionResourcePointMissingIconsPath", "Assets/Shared/Resources/Missing/"),
    @("ActionResourcePointUsedIconsPath", "Assets/Shared/Resources/Used/")
)
foreach ($pair in $keyboardPointPaths) {
    $resourceDefinition = '<System:String x:Key="' + $pair[0] + '">' + $pair[1] + '</System:String>'
    if ($resourceTabTemplate.Value.Split([string[]]@($resourceDefinition), [System.StringSplitOptions]::None).Count -ne 2) {
        throw "The keyboard resource item must define its own source path: $($pair[0])"
    }
}
$keyboardPointTemplate = [regex]::Match(
    $resourceTabTemplate.Value,
    '(?s)<DataTemplate x:Key="ActionResources.ActionGroup.ActionPoint">.*?</DataTemplate>'
)
if (-not $keyboardPointTemplate.Success) {
    throw "Keyboard point artwork must reuse the exact native ActionPoint DataTemplate."
}
foreach ($pair in $keyboardPointPaths) {
    $sourceBinding = '<Binding Source="{StaticResource ' + $pair[0] + '}"/>'
    if (-not $keyboardPointTemplate.Value.Contains($sourceBinding)) {
        throw "Native point artwork must resolve the local keyboard source: $($pair[0])"
    }
}
if ($resourceTabTemplate.Value.IndexOf('x:Key="ActionResourcePointIconsPath"') -gt
    $resourceTabTemplate.Value.IndexOf('x:Key="ActionResources.ActionGroup.ActionPoint"') -or
    $resourceTabTemplate.Value.IndexOf('x:Key="ActionResources.ActionGroup.ActionPoint"') -gt
    $resourceTabTemplate.Value.IndexOf('x:Key="ActionResources.ActionGroup.ActionPointGroup"') -or
    $resourceTabTemplate.Value.Contains('<System:String x:Key="ActionResourcePointIconsPath">Assets/ActionResources_c/Icons/Resources/')) {
    throw "Keyboard point image resolution must precede group templates without controller art."
}

# The original installed keyboard DataTemplates_k.xaml exports 24 point-
# group templates. They must be placed under the resource item root,
# not declared globally or selected through a CAM-specific point override.
# Python validate.py additionally checks the exact 6186-byte source
# against the captured keyboard template block's SHA-256 digest.
$keyboardGroupKeys = @(
    "ActionPointGroup", "DefaultActionPointGroup", "BonusActionPointGroup",
    "ReactionActionPointGroup", "SorceryPointGroup", "KiActionGroup",
    "LayOnHandsChargeActionGroup", "RageActionGroup", "DivinityActionGroup",
    "OathActionGroup", "SuperiorityDieActionGroup", "ArcaneRecoveryActionGroup",
    "InspirationActionGroup", "SpellSlot", "WarlockSpellSlot",
    "RitualPointActionGroup", "NaturalRecoveryPointActionGroup",
    "WildShapeActionGroup", "TidesOfChaosActionGroup",
    "WarPriestActionPointGroup", "FungalInfestationChargeGroup",
    "LuckPointGroup", "ShadowSpellSlotGroup", "ArcaneShotGroup"
)
foreach ($suffix in $keyboardGroupKeys) {
    $key = 'x:Key="ActionResources.ActionGroup.' + $suffix + '"'
    if ($resourceTabTemplate.Value.Split([string[]]@($key), [System.StringSplitOptions]::None).Count -ne 2) {
        throw "Native keyboard resource group must exist exactly once inside CAM resource item: $key"
    }
}
if ($text.Contains('CAM_KeyboardHotBarPointGlyph') -or
    $text.Contains('CAM_KeyboardHotBarPointGroup') -or
    $text.Contains('CAM_DiagnosticDirectPointFrame') -or
    $text.Contains('CAM_DiagnosticTemplateFingerprint') -or
    $resourceTabTemplate.Value.Contains('ActionPointTemplate="{StaticResource CAM_')) {
    throw "No CAM-improvised per-point glyph/forced template may replace native keyboard resource grouping."
}

$resourceTabsItemTemplate = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="CAM_ResourceTabs"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabsItemTemplate.Success -or
    -not $resourceTabsItemTemplate.Value.Contains('ItemContainerStyle="{StaticResource CAM_ResourceTabItemStyle}"') -or
    -not $resourceTabsItemTemplate.Value.Contains('ItemTemplate="{StaticResource CAM_ResourceTabTemplate}"')) {
    throw "CAM_ResourceTabs must separate controller container behavior from native resource item presentation."
}

if ($text.Contains('Binding="{Binding Tag, ElementName=CAM_ResourceTabs}"') -or
    [regex]::IsMatch($text, 'TargetName="CAM_ResourceTabs"\s+PropertyName="Tag"')) {
    throw "CAM_ResourceTabs.Tag is scroll-target state only; provider modes must live on CAM_ProviderModeMarker.Tag."
}
if (-not $text.Contains('Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}"')) {
    throw "Provider mode consumers must bind to CAM_ProviderModeMarker.Tag."
}

# Native keyboard HotBar highlights a resource with box_resource_h on
# IsMouseOver. Controller LB/RB changes ListBoxItem.IsSelected instead;
# require the *same* two image layers for that state and preserve the
# explicit zero-resource disabled trigger after it.
$resourceNativePreview = $resourceTabTemplate.Value
$selectedHighlight = '<Condition Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType={x:Type ListBoxItem}}}" Value="True"/>'
$normalMode = '<Condition Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}" Value="{x:Null}"/>'
$posSelected = $resourceNativePreview.IndexOf($selectedHighlight)
$posDisabled = $resourceNativePreview.IndexOf('<DataTrigger Binding="{Binding ActionResource.Value}" Value="0">')
if ($posSelected -lt 0 -or
    -not $resourceNativePreview.Contains($normalMode) -or
    $posDisabled -le $posSelected -or
    -not $resourceNativePreview.Contains('Source="{StaticResource CAM_BoxResourceH}"') -or
    -not $resourceNativePreview.Contains('Margin="{StaticResource CAM_ResourceBackgroundMargin}"')) {
    throw "Native HotBar resource body must retain its original chrome, with controller selection mapped to native hover and exhausted resource state taking precedence."
}

$cantripTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_CantripsTab"[\s\S]*?(?=<Grid\b[^>]*x:Name="CAM_ItemsTab")',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $cantripTab.Success -or
    -not $cantripTab.Value.Contains('PlayerCharacterProperties.HasCantrips') -or
    -not $cantripTab.Value.Contains('IconMiniCantrip') -or
    -not $cantripTab.Value.Contains('CAM_CantripsModeToken') -or
    -not $cantripTab.Value.Contains('CAM_BoxResourceBg') -or
    -not $cantripTab.Value.Contains('CAM_BoxResourceH')) {
    throw "Cantrips must be a native resource-box-style provider tab gated by HasCantrips."
}

$itemsTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_ItemsTab"[\s\S]*?(?=<Grid\b[^>]*x:Name="CAM_MetamagicTab")',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $itemsTab.Success -or
    -not $itemsTab.Value.Contains('CAM_ItemsModeToken') -or
    -not $itemsTab.Value.Contains('CAM_ItemsProviderIcon') -or
    -not $itemsTab.Value.Contains('CAM_BoxResourceBg') -or
    -not $itemsTab.Value.Contains('CAM_BoxResourceH')) {
    throw "Items must be a resource-box-style provider backed by BG3's native ItemHotBar deck."
}

$metamagicTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_MetamagicTab"[\s\S]*?(?=<Grid\b[^>]*x:Name="CAM_PassivesTab")',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $metamagicTab.Success -or
    -not $metamagicTab.Value.Contains('FixedSideBar.SlotList.Count') -or
    -not $metamagicTab.Value.Contains('FixedSideBar.SlotList[0].Content.Icon') -or
    -not $metamagicTab.Value.Contains('CAM_MetamagicModeToken') -or
    -not $metamagicTab.Value.Contains('CAM_BoxResourceBg') -or
    -not $metamagicTab.Value.Contains('CAM_BoxResourceH')) {
    throw "Metamagic must use the captured FixedSideBar VMHotBar source and resource-box-style provider tab."
}

if ([regex]::Matches($tabLeft.Value, 'CAM_CantripsModeToken').Count -lt 2 -or
    -not $tabLeft.Value.Contains('CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.HasCantrips') -or
    -not $tabLeft.Value.Contains('CAM_TabReturnLastToken') -or
    -not $tabLeft.Value.Contains('CAM_ItemsModeToken') -or
    -not $tabLeft.Value.Contains('CAM_MetamagicModeToken') -or
    -not $tabRight.Value.Contains('CAM_CantripsModeToken') -or
    -not $tabRight.Value.Contains('CAM_ItemsModeToken') -or
    -not $tabRight.Value.Contains('CAM_MetamagicModeToken') -or
    -not $tabLeft.Value.Contains('CAM_AllModeToken') -or
    -not $tabRight.Value.Contains('CAM_AllModeToken') -or
    -not $tabRight.Value.Contains('CAM_TabReturnFirstToken')) {
    throw "Shoulder navigation must serialize resource <-> Cantrips <-> Items <-> Metamagic <-> Passives <-> All transitions and preserve resource wrap."
}

$providerRestore = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="CAM_ProviderRestoreCommand"[\s\S]*?</ls:LSButton>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $providerRestore.Success -or
    -not $providerRestore.Value.Contains('FilterActionResourceCommand') -or
    -not $providerRestore.Value.Contains('CAM_CantripsModeToken') -or
    -not $providerRestore.Value.Contains('FilterCantripsCommand') -or
    -not $providerRestore.Value.Contains('CAM_CantripFilterParameter') -or
    -not $providerRestore.Value.Contains('CAM_ItemsModeToken') -or
    -not $providerRestore.Value.Contains('CAM_AllModeToken') -or
    $providerRestore.Value.Contains('CAM_MetamagicModeToken') -or
    -not $providerRestore.Value.Contains('CAM_PassivesModeToken')) {
    throw "Nested return must restore the active native provider through one provider dispatcher."
}

$passivesTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_PassivesTab"[\s\S]*?(?=<Grid\b[^>]*x:Name="CAM_AllTab")',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $passivesTab.Success -or
    -not $passivesTab.Value.Contains('PassivesHotBar.SlotList.Count') -or
    -not $passivesTab.Value.Contains('PassiveFeature_Generic.png') -or
    -not $passivesTab.Value.Contains('CAM_PassivesModeToken') -or
    -not $passivesTab.Value.Contains('Width="80"') -or
    -not $passivesTab.Value.Contains('Height="72"') -or
    -not $passivesTab.Value.Contains('Margin="-4,0,-4,0"') -or
    -not $passivesTab.Value.Contains('Margin="4,-10,4,10"') -or
    -not $passivesTab.Value.Contains('Width="72"') -or
    -not $passivesTab.Value.Contains('CAM_BoxResourceBg') -or
    -not $passivesTab.Value.Contains('CAM_BoxResource') -or
    -not $passivesTab.Value.Contains('CAM_BoxResourceH') -or
    $passivesTab.Value.Contains('CAM_FilterButtonBackground') -or
    $passivesTab.Value.Contains('btn_pil_') -or
    $passivesTab.Value.Contains('ActiveModArrow')) {
    throw "Passives must be a resource-box-style CAM exception inside the exact HotBar resource strip."
}

$allTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_AllTab"[\s\S]*?(?=</StackPanel>)',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $allTab.Success -or
    -not $allTab.Value.Contains('CAM_AllModeToken') -or
    -not $allTab.Value.Contains('CAM_AllProviderIcon') -or
    -not $allTab.Value.Contains('CAM_BoxResourceBg') -or
    -not $allTab.Value.Contains('CAM_BoxResourceH')) {
    throw "All fallback must be a resource-box-style special provider using the native all-tab glyph."
}

$allGroupTemplate = [regex]::Match(
    $text,
    '<DataTemplate\b[^>]*x:Key="CAM_AllGroupTemplate"[\s\S]*?</DataTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $allGroupTemplate.Success -or
    -not $allGroupTemplate.Value.Contains('DataType="ls:VMHotBar"') -or
    -not $allGroupTemplate.Value.Contains('ItemsSource="{Binding SlotList}"') -or
    -not $allGroupTemplate.Value.Contains('x:Name="CAM_AllGroupSlots"') -or
    -not $allGroupTemplate.Value.Contains('ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"') -or
    -not $allGroupTemplate.Value.Contains('ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"') -or
    -not $allGroupTemplate.Value.Contains('CAM_ResetFirstFocusToken')) {
    throw "All fallback must keep VMHotBar only as a grouping object and execute only child VMHotBarSlot values."
}

$itemTemplate = [regex]::Match(
    $text,
    '<DataTemplate\b[^>]*x:Key="CAM_ActionGridSlotTemplate"[\s\S]*?</DataTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $itemTemplate.Success -or
    -not $itemTemplate.Value.Contains('x:Name="GenericIcon"') -or
    -not $itemTemplate.Value.Contains('Content="{Binding Content}"') -or
    -not $itemTemplate.Value.Contains('ContentTemplate="{StaticResource Template.Item}"') -or
    -not $itemTemplate.Value.Contains('Binding="{Binding SlotType}" Value="Item"') -or
    -not $itemTemplate.Value.Contains('Value="{StaticResource Template.ItemEquipment}"') -or
    -not $itemTemplate.Value.Contains('Value="{StaticResource Template.ItemContainer}"') -or
    $itemTemplate.Value.Contains('GameObject.Count') -or
    $itemTemplate.Value.Contains('ItemCountHolder')) {
    throw "Item-backed action cells must delegate presentation and quantity to native VMItem templates."
}

$directProviderNestedOverrides = @(
    'IsShowingAContainerWithVariants',
    'IsSelectingUpcastedSpell',
    'IsShowingItemsToThrow'
)
foreach ($flag in $directProviderNestedOverrides) {
    $pattern = '<DataTrigger Binding="\{Binding ' + $flag + '\}" Value="True">[\s\S]*?ItemsSource"[\s\S]*?SingleHotBar\.SlotList[\s\S]*?</DataTrigger>'
    if (-not [regex]::IsMatch($mainList.Value, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Direct providers must yield the executable list to SingleHotBar during native nested state: $flag"
    }
}
if ([regex]::Matches($text, '<b:DataTrigger Binding="\{Binding Tag, ElementName=CAM_NestedReturnMarker\}" Value="\{StaticResource CAM_NestedRestoringToken\}">').Count -lt 4 -or
    -not $text.Contains('RightOperand="{StaticResource CAM_ItemsModeToken}"') -or
    -not $text.Contains('RightOperand="{StaticResource CAM_AllModeToken}"') -or
    -not $text.Contains('RightOperand="{StaticResource CAM_MetamagicModeToken}"') -or
    -not $text.Contains('RightOperand="{StaticResource CAM_PassivesModeToken}"')) {
    throw "Direct/deck/grouped providers must restore concrete focus when native nested state returns."
}

# FixedSideBar is a parallel executable list, not the main grid's
# ItemsSource. The former direct-provider metamagic restore and no-op
# filter command must never return: nested states require a BG3 resource
# refilter plus an independent side-rail focus restoration.
$metamagicRestore = @(
    [regex]::Matches(
        $text,
        '<b:DataTrigger Binding="\{Binding Tag, ElementName=CAM_NestedReturnMarker\}" Value="\{StaticResource CAM_NestedRestoringToken\}">[\s\S]*?</b:DataTrigger>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    ) | Where-Object { $_.Value.Contains('RightOperand="{StaticResource CAM_MetamagicModeToken}"') }
) | Select-Object -First 1
if (-not $metamagicRestore -or
    -not $metamagicRestore.Value.Contains('TargetName="CAM_FixedSideBarList"') -or
    -not $metamagicRestore.Value.Contains('PropertyName="Tag" Value="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $metamagicRestore.Value.Contains('PropertyName="SelectedIndex" Value="-1"') -or
    -not $metamagicRestore.Value.Contains('PropertyName="SelectedIndex" Value="0"') -or
    -not $metamagicRestore.Value.Contains('TargetName="CAM_NestedReturnMarker" PropertyName="Tag" Value="{x:Null}"') -or
    $metamagicRestore.Value.Contains('TargetName="HotBarList"')) {
    throw "Metamagic nested exit must refocus the native fixed sidebar, never the main spell list."
}
# Regression in 0.0.99/0.0.100: passive LocalFocusChanged handlers wrote
# CAM_ProviderModeMarker.Tag, which raced with LB/RB and caused tab wrap.
# Mode changes now belong only to explicit shoulder/resource-tab handlers.
if ($sidebar.Value.Contains('PropertyName="Tag" Value="{StaticResource CAM_MetamagicModeToken}"') -or
    $mainList.Value.Contains('PropertyName="Tag" Value="{x:Null}"') -and
    $mainList.Value.Contains('TargetName="CAM_ProviderModeMarker"')) {
    throw "Background LocalFocusChanged must not mutate the active provider mode."
}
foreach ($region in @($sidebar.Value, $mainList.Value)) {
    if ($region -notmatch 'IsEnabled, ElementName=(?:CAM_FixedSideBarList|HotBarList)' -or
        $region -notmatch 'NullToBoolFalseConverter') {
        throw "Only the currently enabled list may own A/tooltip/focus presentation."
    }
}

$nestedMarker = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="CAM_NestedReturnMarker"[\s\S]*?/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $nestedMarker.Success -or
    -not $nestedMarker.Value.Contains('Visibility="Collapsed"') -or
    -not $nestedMarker.Value.Contains('Tag="{x:Null}"')) {
    throw "Nested-return marker must exist as non-interactive CAM lifecycle state."
}
foreach ($flag in @('IsShowingAContainerWithVariants','IsSelectingUpcastedSpell','IsShowingItemsToThrow')) {
    $enterPattern = '<b:DataTrigger Binding="\{Binding ' + $flag + '\}" Value="True">[\s\S]*?CAM_NestedEnteredToken[\s\S]*?FocusElement="\{Binding ElementName=HotBarList\}"[\s\S]*?</b:DataTrigger>'
    if (-not [regex]::IsMatch($text, $enterPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Entering native nested state must arm CAM nested-return restoration: $flag"
    }
    $exitPattern = '<b:PropertyChangedTrigger Binding="\{Binding ' + $flag + '\}">[\s\S]*?CAM_NestedEnteredToken[\s\S]*?IsShowingAContainerWithVariants[\s\S]*?IsSelectingUpcastedSpell[\s\S]*?IsShowingItemsToThrow[\s\S]*?CAM_NestedRestoringToken[\s\S]*?CAM_ProviderRestoreCommand[\s\S]*?</b:PropertyChangedTrigger>'
    if (-not [regex]::IsMatch($text, $exitPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Exiting native nested state must restore the active provider only after all nested flags clear: $flag"
    }
}
$nestedRepopulation = [regex]::Match(
    $text,
    '<b:PropertyChangedTrigger Binding="\{Binding SingleHotBar\.SlotList\.Count\}">[\s\S]*?</b:PropertyChangedTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $nestedRepopulation.Success -or
    -not $nestedRepopulation.Value.Contains('CAM_NestedRestoringToken') -or
    -not $nestedRepopulation.Value.Contains('Operator="GreaterThan"') -or
    -not $nestedRepopulation.Value.Contains('RightOperand="{StaticResource CAM_MetamagicModeToken}"') -or
    -not $nestedRepopulation.Value.Contains('Operator="NotEqual"') -or
    -not $nestedRepopulation.Value.Contains('Value="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $nestedRepopulation.Value.Contains('PropertyName="SelectedIndex"') -or
    -not $nestedRepopulation.Value.Contains('Value="0"')) {
    throw "Repopulated nested return must reuse the concrete-first-item focus handoff."
}

if ($text.Contains('CAM_LogicalFocusAnchor') -or
    $text.Contains('CAM_CellFocusFill') -or
    $text.Contains('CAM_CellFocusFrame') -or
    $text.Contains('x:Key="CAM_SelectorTemplate"')) {
    throw "The rejected invisible-anchor/item-selection focus presentation must not return."
}

$mainSelector = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="CAM_MainSelector"[\s\S]*?</Control>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainSelector.Success -or
    -not $mainSelector.Value.Contains('Template="{StaticResource SelectorTemplate}"') -or
    -not $mainSelector.Value.Contains('<Setter Property="Visibility" Value="Visible"/>') -or
    -not $mainSelector.Value.Contains('<Setter Property="Visibility" Value="Collapsed"/>') -or
    -not $mainSelector.Value.Contains('CAM_MetamagicModeToken') -or
    -not $mainSelector.Value.Contains('Focusable="False"') -or
    -not $hotBarList.Value.Contains('LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"')) {
    throw "HotBarList must use the 0.0.29-proven visible native SelectorTemplate in the same action viewport."
}

# Both selectors are bound to one mutually exclusive visual ownership state.
# Visibility of the list is not evidence that the list has controller focus.
$sideSelector = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="CAM_FixedSideBarSelector"[\s\S]*?</Control>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $sideSelector.Success -or
    -not $sideSelector.Value.Contains('<Setter Property="Visibility" Value="Collapsed"/>') -or
    -not $sideSelector.Value.Contains('<Setter Property="Visibility" Value="Visible"/>') -or
    -not $sideSelector.Value.Contains('CAM_MetamagicModeToken') -or
    -not $sideSelector.Value.Contains('LocalFocus.DataContext, ElementName=CAM_FixedSideBarList') -or
    $sideSelector.Value.Contains('Visibility="{Binding Visibility, ElementName=CAM_FixedSideBarList}"') -or
    -not $mainList.Value.Contains('<Setter Property="IsEnabled" Value="False"/>') -or
    -not $mainList.Value.Contains('CAM_MetamagicModeToken') -or
    -not $mainList.Value.Contains('IsShowingAContainerWithVariants') -or
    -not $mainList.Value.Contains('IsSelectingUpcastedSpell') -or
    -not $mainList.Value.Contains('IsShowingItemsToThrow')) {
    throw "The resource grid and sidebar must have mutually exclusive visible native focus selectors, except during BG3 nested state."
}

if ($hotBarList.Value.Contains('<b:PropertyChangedTrigger Binding="{Binding LocalFocus.DataContext, ElementName=HotBarList}">')) {
    throw "The 0.0.67 nested LocalFocus.DataContext property trigger is runtime-rejected and must not return."
}

$localFocusEvent = @(
    [regex]::Matches(
        $hotBarList.Value,
        '<b:EventTrigger EventName="LocalFocusChanged">[\s\S]*?</b:EventTrigger>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    ) | Where-Object { $_.Value.Contains('ShowTooltipOnUIElementCommand') }
) | Select-Object -First 1
if (-not $localFocusEvent.Success -or
    -not $localFocusEvent.Value.Contains('Value="{Binding LocalFocus.DataContext.Content, ElementName=HotBarList}"') -or
    -not $localFocusEvent.Value.Contains('ShowTooltipOnUIElementCommand') -or
    -not $localFocusEvent.Value.Contains('CommandParameter="{x:Null}"') -or
    -not $localFocusEvent.Value.Contains('LSPlaySound') -or
    $localFocusEvent.Value.Contains('SelectedItem') -or
    $localFocusEvent.Value.Contains('FocusedElement.DataContext')) {
    throw "Normal D-pad presentation must return to the proven LocalFocusChanged -> LocalFocus.DataContext lifecycle."
}

$localFocusTimer = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $localFocusTimer.Success -or
    -not $localFocusTimer.Value.Contains('PropertyName="Tag"') -or
    -not $localFocusTimer.Value.Contains('Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"') -or
    -not $localFocusTimer.Value.Contains('CreateFocusedTooltipDataCommand') -or
    -not $localFocusTimer.Value.Contains('HighlightResourcesCommand') -or
    $localFocusTimer.Value.Contains('SelectedItem') -or
    $localFocusTimer.Value.Contains('FocusedElement.DataContext')) {
    throw "Delayed ActionRadials.Tag/resource state must remain sourced only from LocalFocus.DataContext."
}

$entryFocusWake = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $entryFocusWake.Success -or
    -not $entryFocusWake.Value.Contains('LocalFocus.DataContext') -or
    -not $entryFocusWake.Value.Contains('ShowTooltipOnUIElementCommand') -or
    -not $entryFocusWake.Value.Contains('CreateFocusedTooltipDataCommand') -or
    -not $entryFocusWake.Value.Contains('HighlightResourcesCommand') -or
    $entryFocusWake.Value.Contains('SelectedItem')) {
    throw "Programmatic entry presentation must source identity only from LocalFocus.DataContext."
}
if ($text.Contains('GameObject.Count') -or
    $text.Contains('ItemCountHolder') -or
    $text.Contains('CAM_FilterButtonBackground') -or
    $text.Contains('CAM_ActiveFilterButtonBackground') -or
    $text.Contains('CAM_DisabledFilterButtonBackground') -or
    $text.Contains('CAM_FilterMarkerBackground') -or
    $text.Contains('btn_pil_') -or
    $text.Contains('ActiveModArrow')) {
    throw "0.0.75 requires exact resource-bar chrome and still forbids slot-level item quantity overlays."
}
if ($text.Contains('CAM_EntryFocusCommittedToken') -or
    $text.Contains('Value="{Binding SelectedItem.Content, ElementName=HotBarList}"') -or
    $text.Contains('CommandParameter="{Binding SelectedItem, ElementName=HotBarList}"')) {
    throw "0.0.70 forbids SelectedItem-derived entry presentation."
}
if ($text.Contains('<b:PropertyChangedTrigger Binding="{Binding FocusedElement, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}">')) {
    throw "The runtime-rejected 0.0.68 FocusedElement tooltip wake-up must not return."
}

$slotContainer = [regex]::Match(
    $text,
    '<Style\b[^>]*x:Key="CAM_ActionGridSlotContainer"[\s\S]*?</Style>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $slotContainer.Success -or
    -not $slotContainer.Value.Contains('RightOperand="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $slotContainer.Value.Contains('FocusElement="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"') -or
    -not $slotContainer.Value.Contains('Value="{x:Null}"') -or
    $slotContainer.Value.Contains('CAM_EntryFocusCommittedToken')) {
    throw "Selected index 0 must hand concrete focus to its ListBoxItem and clear the reset token."
}
