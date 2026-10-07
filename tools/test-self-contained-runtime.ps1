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

if ($evidence.runtimeContract.organization.mode -ne "resource-first" -or
    $evidence.runtimeContract.organization.topLevelDimensions -ne 1 -or
    $evidence.runtimeContract.organization.primaryTabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.organization.primarySelectionCommand -ne "FilterActionResourceCommand" -or
    $evidence.runtimeContract.organization.primaryGridSource -ne "SingleHotBar.SlotList" -or
    $evidence.runtimeContract.organization.typeTabsAllowed -ne $false -or
    $evidence.runtimeContract.organization.secondaryResourceLayerAllowed -ne $false) {
    throw "Resource-first organization evidence is incomplete or regressed."
}
if ($evidence.runtimeContract.organization.detailsSurface -ne "native-tooltip-only" -or
    $evidence.runtimeContract.tooltipPresentation.detailsSurface -ne "native-tooltip-only") {
    throw "CAM must use the ordinary native tooltip only; no Live Details panel is allowed."
}
if ($evidence.runtimeContract.controllerPresentation.tabPattern -ne "dynamic-resource-row" -or
    $evidence.runtimeContract.controllerPresentation.tabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.controllerPresentation.genericTabLabel -ne "ActionResource.Name ?? ActionResource.TypeId (null-or-empty)" -or
    $evidence.runtimeContract.controllerPresentation.spellSlotTabLabel -ne "RomanNumeralLevelImage") {
    throw "Dynamic resource-tab presentation evidence is incomplete."
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
if ($evidence.runtimeContract.tooltipPresentation.contentPath -ne "LocalFocus.DataContext.Content" -or
    $evidence.runtimeContract.tooltipPresentation.command -ne "ShowTooltipOnUIElementCommand") {
    throw "Focused native tooltip contract diverged."
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
if ($evidence.runtimeContract.controllerPresentation.resourceViewport.autoScrollBehavior -ne "AutoScrollBehavior" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.scrollIntoView -ne "SelectedIndex" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.bringSelectionIntoView -ne $true -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.scrollTo -ne "Center" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.scrollTargetKind -ne "numeric-index" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.cycleForceSelect -ne $false -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.scrollOwner -ne "AutoScrollBehavior" -or
    $evidence.runtimeContract.controllerPresentation.resourceViewport.hiddenPreviewSelection -ne "collapsed+disabled; ordinary cycle only") {
    throw "Resource-tab viewport contract is incomplete."
}
if ($evidence.runtimeContract.assignmentNavigation.visibleFocusVisualStyle -ne $null -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearSelectedIndex -ne -1 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.filterCommandCount -ne 1 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.settleMilliseconds -ne 70 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.armToken -ne "CAM_ResetFirstFocusToken" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.restoreSelectedIndex -ne 0 -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusTarget -ne "selected concrete ListBoxItem templated parent" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusAction -ne "SetMoveFocusAction(DeferFocusAction=True)" -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearsTokenAfterFocus -ne $true -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.clearLocalFocus -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.invalidateFocus -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.focusesListContainer -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.resourceSelectionRestore.selectedItemMirrorsLocalFocus -ne $false -or
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
    'ScrollIntoView="{Binding SelectedIndex, ElementName=CAM_ResourceTabs}"',
    'BringSelectionIntoView="True"',
    'ScrollTo="Center"',
    'x:Name="CAM_ActionViewport"',
    'CanContentScroll="False"',
    'x:Key="CAM_ResourceTabItemStyle"',
    'Text="{Binding ActionResource.Name}"',
    'Text="{Binding ActionResource.TypeId}"',
    'Style="{StaticResource RomanNumeralLevelImage}"',
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
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"',
    'ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"',
    'ItemsPanel="{StaticResource CAM_ActionGridPanel}"',
    'ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"',
    'ls:MoveFocus.Focusable" Value="True"',
    'Setter Property="FocusVisualStyle" Value="{x:Null}"',
    'x:Key="CAM_ResetFirstFocusToken"',
    'b:DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"',
    'FocusElement="{Binding RelativeSource={RelativeSource Mode=TemplatedParent}}"',
    'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
    'x:Name="CAM_LogicalFocusAnchor"',
    'x:Name="CAM_CellFocusFill"',
    'x:Name="CAM_CellFocusFrame"',
    'Template="{StaticResource SelectorTemplate}"',
    'EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"',
    'Visibility="Visible"',
    'Converter="{StaticResource DivideMultiConverter}" ConverterParameter="Floor"',
    'RelativeSource="{RelativeSource AncestorType={x:Type ScrollContentPresenter}}"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionRightEvent="UIRight"',
    'ActionLeftEvent="UILeft"',
    'PropertyName="SelectedIndex" Value="-1"',
    'Value="{StaticResource CAM_ResetFirstFocusToken}"',
    'PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"',
    'MillisecondsPerTick="70" TotalTicks="1"',
    'CreateFocusedTooltipDataCommand',
    'HighlightResourcesCommand',
    'x:Name="CAM_ActionTooltip"',
    'ShowTooltipOnUIElementCommand',
    'LocalFocus.DataContext.Content',
    'ls:TooltipExtender.Context="Hotbar"',
    'x:Name="UseSlotBinding"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'BoundEvent="UIAccept"',
    'x:Name="CancelButton"',
    'BoundEvent="UICancel"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Binding="{Binding IsShowingAContainerWithVariants}" Value="False"',
    'Binding="{Binding IsSelectingUpcastedSpell}" Value="False"',
    'Binding="{Binding IsShowingItemsToThrow}" Value="False"',
    'Property="Command" Value="{Binding CustomEvent}"',
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
    'PassivesHotBar.SlotList',
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
    'x:Name="CAM_MainSelector"',
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

# One executable controller list owns top-level and nested SingleHotBar state.
$mainList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainList.Success -or
    -not $mainList.Value.Contains('ItemsSource="{Binding SingleHotBar.SlotList}"') -or
    -not $mainList.Value.Contains('ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"') -or
    -not $mainList.Value.Contains('ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"') -or
    -not $mainList.Value.Contains('ItemsPanel="{StaticResource CAM_ActionGridPanel}"')) {
    throw "HotBarList must directly own the executable SingleHotBar.SlotList grid."
}
if ($mainList.Value.Contains('CurrentShownDeck') -or $mainList.Value.Contains('PassivesHotBar')) {
    throw "Main resource-first grid must not fall back to old type/deck sources."
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

# Top-level resource browsing must close on B even though SingleHotBar is populated.
$closeTrigger = [regex]::Match(
    $text,
    '<MultiDataTrigger>[\s\S]*?IsShowingAContainerWithVariants[\s\S]*?IsSelectingUpcastedSpell[\s\S]*?IsShowingItemsToThrow[\s\S]*?CloseWidget[\s\S]*?</MultiDataTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $closeTrigger.Success) {
    throw "Top-level B close trigger must be based on true nested-state flags."
}
if ($closeTrigger.Value.Contains('SingleHotBar.SlotList.Count')) {
    throw "Top-level B must not use SingleHotBar count because resource browsing populates SingleHotBar."
}

Write-Host "Self-contained Patch 8 runtime contract passed: resource tabs are the sole top-level navigation, selection drives native FilterActionResourceCommand, the grid is SingleHotBar.SlotList, ordinary native tooltips remain the only details surface, and top-level B is separated from true nested state."


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
    -not $resourceTabs.Value.Contains('ScrollIntoView="{Binding SelectedIndex, ElementName=CAM_ResourceTabs}"') -or
    -not $resourceTabs.Value.Contains('BringSelectionIntoView="True"') -or
    -not $resourceTabs.Value.Contains('ScrollTo="Center"')) {
    throw "Resource tabs must use the BG3-proven SelectedIndex AutoScroll target and center the selected edge tab."
}

if ($resourceTabs.Value.Contains('ForceSelect="True"') -or
    [regex]::Matches($resourceTabs.Value, 'ForceMode="Cycle"').Count -ne 2) {
    throw "Shoulder cycling must remain cyclic without forcibly selecting collapsed resource previews."
}

$resourceSelectionTrigger = [regex]::Match(
    $resourceTabs.Value,
    '<b:EventTrigger EventName="SelectionChanged">[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceSelectionTrigger.Success -or
    -not $resourceSelectionTrigger.Value.Contains('TargetName="HotBarList" PropertyName="SelectedIndex" Value="-1"') -or
    [regex]::Matches($resourceSelectionTrigger.Value, 'FilterActionResourceCommand').Count -ne 1 -or
    $resourceSelectionTrigger.Value.Contains('PropertyName="LocalFocus"') -or
    $resourceSelectionTrigger.Value.Contains('PropertyName="SelectedItem"') -or
    $resourceSelectionTrigger.Value.Contains('InvalidateFocus="True"') -or
    $resourceSelectionTrigger.Value.Contains('FocusElement="{Binding ElementName=HotBarList}"')) {
    throw "Resource switching must clear the entry selection, filter exactly once, and leave live LocalFocus untouched until the concrete-item handoff."
}
$resourceRestoreTimer = [regex]::Match(
    $resourceTabs.Value,
    '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceRestoreTimer.Success -or
    -not $resourceRestoreTimer.Value.Contains('PropertyName="Tag"') -or
    -not $resourceRestoreTimer.Value.Contains('Value="{StaticResource CAM_ResetFirstFocusToken}"') -or
    -not $resourceRestoreTimer.Value.Contains('PropertyName="SelectedIndex"') -or
    -not $resourceRestoreTimer.Value.Contains('Value="0"') -or
    $resourceRestoreTimer.Value.Contains('FilterActionResourceCommand') -or
    $resourceRestoreTimer.Value.Contains('FocusElement="{Binding ElementName=HotBarList}"')) {
    throw "After the native settle window, resource switching must arm the one-shot first-focus token before selecting index 0."
}

$resourceTabStyle = [regex]::Match(
    $text,
    '<Style\b[^>]*x:Key="CAM_ResourceTabItemStyle"[\s\S]*?</Style>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabStyle.Success -or
    $resourceTabStyle.Value.Contains('Property="MaxWidth"') -or
    $resourceTabStyle.Value.Contains('MaxWidth="') -or
    $resourceTabStyle.Value.Contains('TextTrimming=') -or
    -not $resourceTabStyle.Value.Contains('<Image x:Name="SpellLevel"') -or
    -not $resourceTabStyle.Value.Contains('Style="{StaticResource RomanNumeralLevelImage}"') -or
    $resourceTabStyle.Value.Contains('SpellSlotNumberStyle')) {
    throw "Resource items must allow natural text width and use the native RomanNumeralLevelImage spell-slot renderer."
}

if ([regex]::Matches($resourceTabStyle.Value, 'Binding="{Binding ActionResource.MaxValue}" Value="0"').Count -ne 1 -or
    [regex]::Matches($resourceTabStyle.Value, 'Setter Property="IsEnabled" Value="False"').Count -lt 2) {
    throw "Null/MaxValue=0 resource previews must be collapsed and disabled so shoulder cycling cannot enter invisible tabs."
}

if (-not $text.Contains('x:Name="ResourceFallback"') -or
    -not $text.Contains('Text="{Binding ActionResource.TypeId}"') -or
    -not $text.Contains('Binding="{Binding ActionResource.Name}" Value="{x:Null}"') -or
    -not $text.Contains('Binding="{Binding ActionResource.Name}" Value=""')) {
    throw "Null or empty native resource names must have a TypeId text fallback."
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

if (-not $hotBarList.Value.Contains('EventName="LocalFocusChanged"') -or
    $hotBarList.Value.Contains('PropertyName="SelectedItem"') -or
    -not $hotBarList.Value.Contains('Value="{Binding LocalFocus.DataContext.Content, ElementName=HotBarList}"') -or
    -not $hotBarList.Value.Contains('PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"')) {
    throw "LocalFocus must remain the sole live navigation/tooltip/A owner; SelectedItem is reserved for entry selection only."
}
