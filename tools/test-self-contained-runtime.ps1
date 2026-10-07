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

if ($evidence.runtimeContract.organization.mode -ne "resource-first-plus-passives" -or
    $evidence.runtimeContract.organization.topLevelDimensions -ne 1 -or
    $evidence.runtimeContract.organization.primaryTabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.organization.primarySelectionCommand -ne "FilterActionResourceCommand" -or
    $evidence.runtimeContract.organization.primaryGridSource -ne "SingleHotBar.SlotList | PassivesHotBar.SlotList" -or
    $evidence.runtimeContract.organization.passivesTabAllowed -ne $true -or
    $evidence.runtimeContract.organization.passivesSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList" -or
    $evidence.runtimeContract.organization.passivesModeStorage -ne "CAM_ResourceTabs.Tag" -or
    $evidence.runtimeContract.organization.passivesModeToken -ne "CAM_PassivesModeToken" -or
    $evidence.runtimeContract.organization.passivesModeOwnership -ne "CAM presentation-only" -or
    $evidence.runtimeContract.organization.typeTabsAllowed -ne $false -or
    $evidence.runtimeContract.organization.secondaryResourceLayerAllowed -ne $false) {
    throw "Resource-first plus Passives organization evidence is incomplete or regressed."
}
if ($evidence.runtimeContract.organization.detailsSurface -ne "native-tooltip-only" -or
    $evidence.runtimeContract.tooltipPresentation.detailsSurface -ne "native-tooltip-only") {
    throw "CAM must use the ordinary native tooltip only; no Live Details panel is allowed."
}
if ($evidence.runtimeContract.controllerPresentation.tabPattern -ne "exact-hotbar-action-resources-plus-passives" -or
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
if ($evidence.runtimeContract.controllerPresentation.resourceViewport.mode -ne "single-row-exact-hotbar-action-resources" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.layoutPanel -ne "StackPanel" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.orientation -ne "Horizontal" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.oneLogicalSequence -ne $true -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.includesPassives -ne $true -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.sharedBackground -ne "bar_resources.png" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.sharedBackgroundHeight -ne 64 -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.sharedBackgroundSlices -ne "104,0" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.sharedBackgroundMinWidth -ne 208 -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.sharedBackgroundWidthRule -ne "visible tab row ActualWidth + 208" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.resourceVisualSize -ne 72 -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.resourceButtonMargin -ne "4,-10,4,10" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.itemContainerMargin -ne "-4,0,-4,0" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.horizontalScrollState -ne $false -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.wrappedRows -ne $false -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.scrollOwner -ne $null -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.actionViewportHeight -ne 850 -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.cycleForceSelect -ne $false) {
    throw "Top tabs must be one exact HotBar Action Resources strip with Passives and no scroll/wrap state."
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
if ($evidence.runtimeContract.assignmentNavigation.sourceSwitch.modeStorage -ne "CAM_ResourceTabs.Tag" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.modeToken -ne "CAM_PassivesModeToken" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.ownership -ne "CAM presentation-only" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.resourceSource -ne "SingleHotBar.SlotList" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.passivesSource -ne "CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.executableList -ne "HotBarList" -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.duplicateExecutableLists -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.sourceSwitch.unprovenGameplayModeCommandsAllowed -ne $false) {
    throw "Passives must switch the sole HotBarList through CAM presentation state over the proven native PassivesHotBar source."
}

$passiveReturn = $evidence.runtimeContract.assignmentNavigation.passivesReturn
if ($passiveReturn.modeAuthority -ne "CAM_ResourceTabs.Tag = CAM_PassivesModeToken for the entire originating shoulder-button Click" -or
    $passiveReturn.rightToken -ne "CAM_TabReturnFirstToken" -or
    $passiveReturn.leftToken -ne "CAM_TabReturnLastToken" -or
    $passiveReturn.rightModeSwitchMilliseconds -ne 70 -or
    $passiveReturn.leftModeSwitchMilliseconds -ne 90 -or
    $passiveReturn.ordinaryResourceClickHandlersEligibleDuringReturn -ne $false -or
    $passiveReturn.singleShoulderPressSingleLogicalTransition -ne $true) {
    throw "Passives return must remain a serialized transition outside the ordinary resource-cycle click path."
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
    'Style="{StaticResource RomanNumeralLevelImage}"',
    'x:Name="ResourcesNumeralDisplay"',
    'Converter="{StaticResource LessThanOrEqualMultiConverter}"',
    'ElementName="ResourcePoints" Path="MaxGroupActionPoints"',
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
    'SetCurrentShownDeckCommand',
    'FilterCantripsCommand',
    'CurrentShownDeck.SlotList',
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

# One executable controller list owns resource, Passives, and nested VMHotBarSlot state.
$mainList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainList.Success -or
    -not $mainList.Value.Contains('<Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>') -or
    -not $mainList.Value.Contains('Binding="{Binding Tag, ElementName=CAM_ResourceTabs}" Value="{StaticResource CAM_PassivesModeToken}"') -or
    -not $mainList.Value.Contains('Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"') -or
    -not $mainList.Value.Contains('ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"') -or
    -not $mainList.Value.Contains('ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"') -or
    -not $mainList.Value.Contains('ItemsPanel="{StaticResource CAM_ActionGridPanel}"')) {
    throw "The sole HotBarList must switch only between resource/nested SingleHotBar slots and executable PassivesHotBar slots."
}
if ($mainList.Value.Contains('CurrentShownDeck')) {
    throw "The action grid must not fall back to the old deck architecture."
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

Write-Host "Self-contained Patch 8 runtime contract passed: resource tabs use captured HotBar chrome, item slots delegate to native VMItem templates, Passives is serialized, entry focus is concrete-first, and top-level B remains separated from true nested state."


# Weapon-set switching is deliberately absent from CAM after repeated runtime failures.
foreach ($forbiddenWeaponSeam in @('x:Name="ToggleWeaponSet"','x:Name="WeaponSetShortcutBinding"','SwitchWeaponSetCommand','HoldTime="{StaticResource HoldTimeShortcuts}"')) {
    if ($text.Contains($forbiddenWeaponSeam)) {
        throw "Broken CAM-owned weapon-set input must remain absent: $forbiddenWeaponSeam"
    }
}
if (-not $text.Contains('ActionLeftEvent="UILeft"')) {
    throw "Ordinary grid-left navigation must remain UILeft."
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
    -not $resourceTabs.Value.Contains('MaxWidth="1160"') -or
    -not $resourceTabs.Value.Contains('HorizontalContentAlignment="Center"') -or
    $resourceTabs.Value.Contains('<ls:LSScrollViewer') -or
    $resourceTabs.Value.Contains('<ScrollViewer') -or
    $resourceTabs.Value.Contains('AutoScrollBehavior') -or
    $resourceTabs.Value.Contains('BringSelectionIntoView=') -or
    $resourceTabs.Value.Contains('ScrollIntoView=') -or
    $resourceTabs.Value.Contains('ScrollToElement=') -or
    $resourceTabs.Value.Contains('ScrollTo=')) {
    throw "Compact resource icons must have no horizontal scroll state."
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
    -not $tabLeft.Value.Contains('CAM_TabEnterPassivesToken') -or
    -not $tabLeft.Value.Contains('CAM_TabReturnLastToken') -or
    -not $tabLeft.Value.Contains('CAM_PassivesModeToken') -or
    -not $tabLeft.Value.Contains('MillisecondsPerTick="90"') -or
    -not $tabLeft.Value.Contains('Reversed="True"') -or
    -not $tabRight.Value.Contains('CAM_TabReturnFirstToken') -or
    -not $tabRight.Value.Contains('CAM_PassivesModeToken') -or
    -not $tabRight.Value.Contains('MillisecondsPerTick="70"') -or
    -not $tabRight.Value.Contains('CAM_TabCycleRightToken') -or
    $tabLeft.Value.Contains('ForceSelect="True"') -or
    $tabRight.Value.Contains('ForceSelect="True"')) {
    throw "LB/RB must form one resource-plus-Passives cycle without ForceSelect."
}

if ([regex]::Matches($resourceTabs.Value, '<b:EventTrigger EventName="SelectionChanged">').Count -ne 4 -or
    -not $resourceTabs.Value.Contains('CAM_TabCycleRightToken') -or
    -not $resourceTabs.Value.Contains('CAM_TabCycleLeftToken') -or
    -not $resourceTabs.Value.Contains('CAM_TabReturnLastToken') -or
    -not $resourceTabs.Value.Contains('TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="{StaticResource CAM_PassivesModeToken}"') -or
    [regex]::Matches($resourceTabs.Value, 'FilterActionResourceCommand').Count -lt 2 -or
    [regex]::Matches($resourceTabs.Value, 'TargetName="HotBarList" PropertyName="LocalFocus" Value="{x:Null}"').Count -lt 3) {
    throw "Resource selection must distinguish right-wrap Passives entry from ordinary native resource filtering and clear stale LocalFocus."
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
    '<Style\b[^>]*x:Key="CAM_ResourceTabItemStyle"[\s\S]*?(?=<ItemsPanelTemplate\b[^>]*x:Key="CAM_ResourceTabsPanel")',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabStyle.Success -or
    -not $resourceTabStyle.Value.Contains('Property="Margin" Value="-4,0,-4,0"') -or
    -not $resourceTabStyle.Value.Contains('Property="Width" Value="80"') -or
    -not $resourceTabStyle.Value.Contains('Property="Height" Value="72"') -or
    -not $resourceTabStyle.Value.Contains('Margin="4,-10,4,10"') -or
    -not $resourceTabStyle.Value.Contains('x:Name="Root" Width="72"') -or
    -not $resourceTabStyle.Value.Contains('Source="{StaticResource CAM_BoxResourceBg}"') -or
    -not $resourceTabStyle.Value.Contains('Source="{StaticResource CAM_BoxResource}"') -or
    -not $resourceTabStyle.Value.Contains('Source="{StaticResource CAM_BoxResourceH}"') -or
    -not $resourceTabStyle.Value.Contains('Source="{StaticResource CAM_BoxResourceDisabled}"') -or
    -not $resourceTabStyle.Value.Contains('<ls:LSActionPointResources x:Name="ResourcePoints"') -or
    -not $resourceTabStyle.Value.Contains('MaxActionPoints="{Binding MaxValue}"') -or
    -not $resourceTabStyle.Value.Contains('AvailableActionPoints="{Binding Value}"') -or
    -not $resourceTabStyle.Value.Contains('HighlightedActionPoints="{Binding DataContext.Cost, ElementName=Root}"') -or
    -not $resourceTabStyle.Value.Contains('DataContext="{Binding ActionResource}"') -or
    -not $resourceTabStyle.Value.Contains('SmallActionPointSize="24"') -or
    -not $resourceTabStyle.Value.Contains('ActionPointGroupSize="56"') -or
    -not $resourceTabStyle.Value.Contains('Style="{StaticResource ActionResourcesTemplateSelector}"') -or
    -not $resourceTabStyle.Value.Contains('Style="{StaticResource RomanNumeralLevelImage}"') -or
    -not $resourceTabStyle.Value.Contains('Margin="0,-10,0,0"') -or
    -not $resourceTabStyle.Value.Contains('Value="{StaticResource CAM_BoxResourceNumBg}"') -or
    -not $resourceTabStyle.Value.Contains('Value="{StaticResource CAM_BoxResourceNum}"') -or
    -not $resourceTabStyle.Value.Contains('Value="{StaticResource CAM_BoxResourceNumH}"') -or
    -not $resourceTabStyle.Value.Contains('Value="{StaticResource CAM_BoxResourceNumDisabled}"') -or
    -not $resourceTabStyle.Value.Contains('Property="Margin" Value="0,-8,0,0"') -or
    -not $resourceTabStyle.Value.Contains('x:Name="ResourcesNumeralDisplay"') -or
    -not $resourceTabStyle.Value.Contains('Setter Property="Visibility" Value="Hidden"') -or
    -not $resourceTabStyle.Value.Contains('Converter="{StaticResource LessThanOrEqualMultiConverter}"') -or
    -not $resourceTabStyle.Value.Contains('ElementName="ResourcePoints" Path="MaxGroupActionPoints"') -or
    -not $resourceTabStyle.Value.Contains('Binding="{Binding ActionResource.TypeId}" Value="BardicInspiration"') -or
    -not $resourceTabStyle.Value.Contains('Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"') -or
    -not $resourceTabStyle.Value.Contains('RightOperand="{x:Null}"') -or
    -not $resourceTabStyle.Value.Contains('Binding="{Binding ActionResource.Value}" Value="0"') -or
    $resourceTabStyle.Value.Contains('CAM_FilterButtonBackground') -or
    $resourceTabStyle.Value.Contains('btn_pil_') -or
    $resourceTabStyle.Value.Contains('ActiveModArrow') -or
    $resourceTabStyle.Value.Contains('Style="{StaticResource SectionImageStyle}"') -or
    $resourceTabStyle.Value.Contains('Text="{Binding ActionResource.Name}"') -or
    $resourceTabStyle.Value.Contains('Text="{Binding ActionResource.TypeId}"') -or
    $resourceTabStyle.Value.Contains('AlignableWrapPanel')) {
    throw "Resource tabs must mirror the captured Patch 8 ActionResourcesList resource-button presentation."
}
if ([regex]::Matches($resourceTabStyle.Value, 'Binding="{Binding ActionResource.MaxValue}" Value="0"').Count -ne 1 -or
    [regex]::Matches($resourceTabStyle.Value, 'Setter Property="IsEnabled" Value="False"').Count -lt 2) {
    throw "Null/MaxValue=0 resource previews must remain collapsed and disabled."
}

$passivesLeftReturn = [regex]::Match(
    $tabLeft.Value,
    '<b:EventTrigger EventName="Click">[\s\S]*?CAM_PassivesModeToken[\s\S]*?CAM_TabReturnLastToken[\s\S]*?SelectNextListBoxItem[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$passivesLeftTimer = [regex]::Match(
    $tabLeft.Value,
    '<b:TimerTrigger EventName="Click" MillisecondsPerTick="90" TotalTicks="1">[\s\S]*?CAM_TabReturnLastToken[\s\S]*?TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="\{x:Null\}"[\s\S]*?CAM_ResetFirstFocusToken[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$passivesRightReturn = [regex]::Match(
    $tabRight.Value,
    '<b:EventTrigger EventName="Click">[\s\S]*?CAM_PassivesModeToken[\s\S]*?CAM_TabReturnFirstToken[\s\S]*?FilterActionResourceCommand[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$passivesRightTimer = [regex]::Match(
    $tabRight.Value,
    '<b:TimerTrigger EventName="Click" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?CAM_TabReturnFirstToken[\s\S]*?TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="\{x:Null\}"[\s\S]*?CAM_ResetFirstFocusToken[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$returnLastPrepare = [regex]::Match(
    $resourceTabs.Value,
    '<b:EventTrigger EventName="SelectionChanged">[\s\S]*?CAM_TabReturnLastToken[\s\S]*?FilterActionResourceCommand[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $passivesLeftReturn.Success -or -not $passivesLeftTimer.Success -or
    -not $passivesRightReturn.Success -or -not $passivesRightTimer.Success -or
    -not $returnLastPrepare.Success) {
    throw "Passives return must prepare a resource while passive mode is still active, then switch sources only at the delayed boundary."
}
if ($passivesLeftReturn.Value.Contains('TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="{x:Null}"') -or
    $passivesRightReturn.Value.Contains('TargetName="CAM_ResourceTabs" PropertyName="Tag" Value="{x:Null}"')) {
    throw "A Passives-return Click must not clear passive mode before the originating shoulder event completes."
}

$passivesTab = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_PassivesTab"[\s\S]*?(?=</StackPanel>)',
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
    $exitPattern = '<b:PropertyChangedTrigger Binding="\{Binding ' + $flag + '\}">[\s\S]*?CAM_NestedEnteredToken[\s\S]*?IsShowingAContainerWithVariants[\s\S]*?IsSelectingUpcastedSpell[\s\S]*?IsShowingItemsToThrow[\s\S]*?CAM_NestedRestoringToken[\s\S]*?FilterActionResourceCommand[\s\S]*?CommandParameter="\{Binding SelectedItem, ElementName=CAM_ResourceTabs\}"[\s\S]*?</b:PropertyChangedTrigger>'
    if (-not [regex]::IsMatch($text, $exitPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Exiting native nested state must restore the selected resource only after all nested flags clear: $flag"
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
    '<Control\b[^>]*x:Name="CAM_MainSelector"[\s\S]*?/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainSelector.Success -or
    -not $mainSelector.Value.Contains('Template="{StaticResource SelectorTemplate}"') -or
    -not $mainSelector.Value.Contains('Visibility="{Binding Visibility, ElementName=HotBarList}"') -or
    -not $mainSelector.Value.Contains('Focusable="False"') -or
    -not $hotBarList.Value.Contains('LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"')) {
    throw "HotBarList must use the 0.0.29-proven visible native SelectorTemplate in the same action viewport."
}

if ($hotBarList.Value.Contains('<b:PropertyChangedTrigger Binding="{Binding LocalFocus.DataContext, ElementName=HotBarList}">')) {
    throw "The 0.0.67 nested LocalFocus.DataContext property trigger is runtime-rejected and must not return."
}

$localFocusEvent = [regex]::Match(
    $hotBarList.Value,
    '<b:EventTrigger EventName="LocalFocusChanged">[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
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
