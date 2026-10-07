$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Library = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
$EvidencePath = Join-Path $Root "docs\evidence\patch8-1.8.910.0-runtime-contract.json"

if (-not (Test-Path -LiteralPath $Library -PathType Leaf)) { throw "Self-contained runtime library is missing: $Library" }
if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) { throw "Patch 8 capture evidence is missing: $EvidencePath" }

[xml]$xml = Get-Content -Raw -LiteralPath $Library
$text = Get-Content -Raw -LiteralPath $Library
$evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json

if ($evidence.gamePackageVersion -ne "1.8.910.0") { throw "Runtime evidence must remain pinned to Xbox Patch 8 1.8.910.0." }
if ($evidence.captureMatchCount -ne 22 -or $evidence.captureScanErrorCount -ne 0) { throw "Complete 22-file capture with zero scan errors is required." }
if ($evidence.sourceHashes.'Public/Game/GUI/Library/PreloadedActionRadials_c.xaml' -ne "4f5cf52e6839debe6d1b247a02d6e60987c26e92586a374892f65ba6b4f19d8b") { throw "Unexpected PreloadedActionRadials capture hash." }
if ($evidence.sourceHashes.'Mods/MainUI/GUI/Pages/HotBar.xaml' -ne "9035014f47b2f47ca90a0bd7604aa9cdd32931ff8f778e10a15ab104373e2728") { throw "Unexpected HotBar capture hash." }

if ($evidence.runtimeContract.organization.mode -ne "resource-first" -or
    $evidence.runtimeContract.organization.primaryTabSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.organization.primarySelectionCommand -ne "FilterActionResourceCommand" -or
    $evidence.runtimeContract.organization.primaryGridSource -ne "SingleHotBar.SlotList" -or
    $evidence.runtimeContract.organization.detailsSurface -ne "native-tooltip-only") {
    throw "Resource-first organization evidence regressed."
}

if ($evidence.runtimeContract.nativeUpcastProjection.source -ne "VMHotBarSlot.Content.SpellUpcast" -or
    $evidence.runtimeContract.nativeUpcastProjection.itemType -ne "VMUpcast" -or
    $evidence.runtimeContract.nativeUpcastProjection.nativeLevelPath -ne "VMUpcast.SlotLevel" -or
    $evidence.runtimeContract.nativeUpcastProjection.dispatchCommand -ne "UseSlotCommand" -or
    $evidence.runtimeContract.nativeUpcastProjection.dispatchParameter -ne "VMUpcast") {
    throw "Native VMUpcast projection evidence is incomplete."
}
if ($evidence.runtimeContract.assignmentNavigation.mainList -ne "HotBarList" -or
    $evidence.runtimeContract.assignmentNavigation.directExecutableList -ne $true -or
    $evidence.runtimeContract.assignmentNavigation.nestedExecutableList -ne $false -or
    $evidence.runtimeContract.assignmentNavigation.selectorSharesListCoordinateRoot -ne $true) {
    throw "Direct main-grid focus architecture is not pinned."
}
if ($evidence.runtimeContract.cancelBehavior.restoreTopLevelFilterAfterNestedExit.command -ne "FilterActionResourceCommand(CAM_ResourceTabs.SelectedItem)") {
    throw "Nested-exit filter restore evidence is missing."
}
if ($evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.boundEvent -ne "UISelectionLeft" -or
    $evidence.runtimeContract.controllerShortcuts.toggleWeaponSet.command -ne "SwitchWeaponSetCommand") {
    throw "Weapon-set shortcut contract is missing."
}

$required = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_ResourceTabs"',
    'ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"',
    'Command="{Binding FilterActionResourceCommand}"',
    'CommandParameter="{Binding SelectedItem, ElementName=CAM_ResourceTabs}"',
    'x:Name="HotBarList"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'ItemsPanel="{StaticResource CAM_ActionGridPanel}"',
    'ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"',
    'ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'ls:ScrollViewerHelper.VerticalScrollOffsetMargin="120"',
    'x:Name="CAM_MainSelector"',
    'Visibility="{Binding Visibility, ElementName=HotBarList}"',
    'PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"',
    'Value="{Binding LocalFocus.DataContext.Content, ElementName=HotBarList}"',
    'MillisecondsPerTick="70" TotalTicks="1"',
    'x:Name="CAM_UpcastVariants"',
    'ItemsSource="{Binding Content.SpellUpcast}"',
    'DataType="{x:Type ls:VMUpcast}"',
    'x:Name="CAM_UpcastVariant"',
    'x:Name="CAM_UpcastAccept"',
    'Binding Path="SlotLevel"',
    'SelectedItem.ActionResource.SpellSlotLevel',
    'LessThanOrEqualMultiConverter',
    'GreaterOrEqualThanMultiConverter',
    'CommandParameter="{Binding .}"',
    'BoundEvent="UIAccept"',
    'ShowTooltipOnUIElementCommand',
    'HighlightResourcesCommand',
    'Binding="{Binding SingleHotBar.SlotList.Count}" Value="0"',
    'Binding="{Binding IsShowingAContainerWithVariants}"',
    'Binding="{Binding IsSelectingUpcastedSpell}"',
    'Binding="{Binding IsShowingItemsToThrow}"',
    'MaxWidth="1450"',
    'Width="1700"',
    'Width="1600"',
    'BoundEvent="UISelectionLeft"',
    'Command="{Binding SwitchWeaponSetCommand}"',
    'BoundEvent="UISelectionRight"',
    'Command="{Binding ToggleDualWieldingCommand}"',
    'x:Name="CAM_ActionTooltip"',
    'x:Name="CAM_SingleActionTooltip"',
    'ls:TooltipExtender.Context="Hotbar"',
    'x:Name="CancelButton"',
    'Property="CommandParameter" Value="CloseWidget"'
)
foreach ($needle in $required) {
    if (-not $text.Contains($needle)) { throw "Self-contained runtime is missing required corrected seam: $needle" }
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
    'CAM_FilteredSlotList',
    'CAM_FilteredSlotHolder',
    'ResourceFilterBinding',
    'CAM_LiveDetails',
    'LiveDetails',
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
    'Public/Game/GUI/',
    'ScriptExtender'
)) {
    if ($text.Contains($forbidden)) { throw "Forbidden obsolete/non-resource-first seam is present: $forbidden" }
}

# The main executable list is direct: no one-item outer wrapper around a nested action list.
$hotBarList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $hotBarList.Success) { throw "Direct HotBarList was not found." }
foreach ($needle in @(
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"',
    'ItemsPanel="{StaticResource CAM_ActionGridPanel}"',
    'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}'
)) {
    if (-not $hotBarList.Value.Contains($needle)) { throw "HotBarList direct-grid contract missing: $needle" }
}

# Native upcast projection must compare native level to selected resource level and dispatch VMUpcast directly.
$upcastTemplate = [regex]::Match(
    $text,
    '<ItemsControl\b[^>]*x:Name="CAM_UpcastVariants"[\s\S]*?</ItemsControl>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $upcastTemplate.Success) { throw "CAM_UpcastVariants projection was not found." }
foreach ($needle in @('Content.SpellUpcast','ls:VMUpcast','SlotLevel','SpellSlotLevel','CAM_UpcastAccept','CommandParameter="{Binding .}"')) {
    if (-not $upcastTemplate.Value.Contains($needle)) { throw "Native upcast projection missing: $needle" }
}
if ($upcastTemplate.Value.Contains('Damage') -or $upcastTemplate.Value.Contains('Dice') -or $upcastTemplate.Value.Contains('SpellName')) {
    throw "CAM must not calculate or classify upcast gameplay semantics."
}

# Nested-state clear must reapply the already-selected resource filter.
$restore = [regex]::Match(
    $text,
    '<b:DataTrigger\s+Binding="\{Binding SingleHotBar\.SlotList\.Count\}"\s+Value="0">[\s\S]*?FilterActionResourceCommand[\s\S]*?SelectedItem, ElementName=CAM_ResourceTabs[\s\S]*?</b:DataTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $restore.Success) { throw "Nested-exit resource-filter restore trigger is missing." }

# No custom details surface: ordinary tooltip is kept; matching VMUpcast updates that tooltip object.
if (-not $text.Contains('TargetObject="{Binding ToolTip, RelativeSource={RelativeSource AncestorType={x:Type ls:LSListBox}}}"')) {
    throw "Matching VMUpcast must update the existing native LSTooltip rather than create Live Details."
}

# Focus selector and direct list share CAM_FilterContent coordinates.
$focusRoot = [regex]::Match(
    $text,
    '<Grid\b[^>]*x:Name="CAM_FilterContent"[\s\S]*?x:Name="HotBarList"[\s\S]*?x:Name="CAM_MainSelector"[\s\S]*?</Grid>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $focusRoot.Success) { throw "HotBarList and CAM_MainSelector must share one coordinate root." }

# Preserve current size compensation while correcting coordinate ownership.
$selectorTemplate = [regex]::Match(
    $text,
    '<ControlTemplate\b[^>]*x:Key="CAM_SelectorTemplate"[\s\S]*?</ControlTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $selectorTemplate.Success -or -not $selectorTemplate.Value.Contains('Margin="-4"') -or -not $selectorTemplate.Value.Contains('Margin="4"')) {
    throw "Current selector size compensation must remain -4/+4 pending runtime proof."
}

Write-Host "Self-contained Patch 8 runtime contract passed: direct focus/scroll grid is restored, nested exit reapplies the selected resource, native VMUpcast variants are projected by SlotLevel without CAM spell math, resource tabs have a wide scrolling viewport, native tooltip remains the only details surface, and UISelectionLeft preserves weapon-set switching."
