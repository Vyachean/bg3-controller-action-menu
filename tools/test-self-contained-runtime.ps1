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
    throw "Runtime evidence must be pinned to the consumed Xbox Patch 8 capture (1.8.910.0)."
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
if ($evidence.sourceHashes.'Mods/MainUI/GUI/StateMachines/Controller.xaml' -ne "53389126eb75eaa275609fce981b15339ea8cacab58df3af0d97c370658a573c") {
    throw "Unexpected MainUI controller state-machine capture hash."
}
if ($evidence.runtimeContract.controllerPresentation.assignmentIconBinding -ne "Icon" -or
    $evidence.runtimeContract.controllerPresentation.camIconBinding -ne "Content.Icon" -or
    $evidence.runtimeContract.controllerPresentation.actionCellSize -ne 104 -or
    $evidence.runtimeContract.controllerPresentation.actionGridCellSize -ne 120) {
    throw "Controller action presentation must remain pinned to the captured 104px assignment icon inside a 120px LSGrid cell."
}
if ($evidence.runtimeContract.controllerPresentation.slotIconStyleRejectedBecauseInternalIconSize -ne 120) {
    throw "SlotIconStyle's captured 120px internal icon regression guard is missing."
}
if ($evidence.runtimeContract.controllerPresentation.resourceButtonSize -ne 72 -or $evidence.runtimeContract.controllerPresentation.resourceNameTextVisible -ne $false) {
    throw "Resource filters must remain pinned to the captured compact 72px HotBar presentation without resource-name text."
}
if ($evidence.runtimeContract.controllerPresentation.filterTabFontResource -ne "SmallFontSize" -or $evidence.runtimeContract.controllerPresentation.filterTabTextStyle -ne "BtnTextGlow") {
    throw "Filter-tab presentation must remain pinned to the current HotBar FilterButton typography."
}
if ($evidence.runtimeContract.controllerPresentation.keyboardStyleRejected -ne "HotBarSlotStyle" -or $evidence.runtimeContract.controllerPresentation.keyboardOverlayRejected -ne "HotKey") {
    throw "Keyboard HotBarSlotStyle/HotKey presentation regression guard is missing from capture evidence."
}
if ($evidence.runtimeContract.controllerPresentation.nativeSelectorVisualExpansion -ne 12 -or $evidence.runtimeContract.controllerPresentation.camSelectorVisualExpansion -ne 0) {
    throw "Selector presentation must record the captured native 12px expansion and CAM's zero-expansion visual contract."
}
if ($evidence.runtimeContract.tooltipDisplay.command -ne "ShowTooltipOnUIElementCommand" -or $evidence.runtimeContract.tooltipDisplay.contentPath -ne "LocalFocus.DataContext.Content") {
    throw "Focused action tooltip display contract is missing from evidence."
}
if ($evidence.runtimeContract.informationArchitecture.cantripsArePrimaryTab -ne $false -or
    $evidence.runtimeContract.informationArchitecture.semanticSorterOwnedByCam -ne $false -or
    $evidence.runtimeContract.informationArchitecture.secondaryFilterLocation -ne "beforeActions") {
    throw "Hierarchical native-filter information architecture is missing from evidence."
}

$required = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_FilterTabs"',
    'ActionPrevEvent="UITabPrev"',
    'ActionNextEvent="UITabNext"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"',
    'x:Name="CAM_CantripResourceButton"',
    'x:Key="CAM_CantripFilterTemplate"',
    'Command="{Binding FilterCantripsCommand}"',
    ('CommandParameter="' + $evidence.runtimeContract.cantripFilterParameter + '"'),
    'IconMiniCantrip',
    'ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"',
    'Command="{Binding FilterActionResourceCommand}"',
    'x:Name="ResourceFilterBinding"',
    'CommandParameter="{Binding LocalFocus.DataContext, ElementName=HotBarList}"',
    'Value="{Binding CurrentShownDeck.SlotList}"',
    'Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"',
    'Value="{Binding SingleHotBar.SlotList}"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'x:Name="HotBarList"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'x:Name="CAM_FilteredSlotList"',
    'KeyboardNavigation.DirectionalNavigation="Continue"',
    'x:Name="CAM_MainSelector"',
    'x:Key="CAM_ActionSelectorTemplate"',
    'Template="{StaticResource CAM_ActionSelectorTemplate}"',
    'Core;component/Assets/Shared_c/c_itemSelector.png',
    'Margin="0"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionRightEvent="UIRight"',
    'ActionLeftEvent="UILeft"',
    'PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=CAM_FilteredSlotList}"',
    'MillisecondsPerTick="70" TotalTicks="1"',
    'CreateFocusedTooltipDataCommand',
    'HighlightResourcesCommand',
    'UI_HUD_Controller_RadialMenu_SlotHover',
    'x:Name="CAM_ActionTooltip"',
    'x:Name="CAM_SingleActionTooltip"',
    'ShowTooltipOnUIElementCommand',
    'PropertyName="Content" Value="{Binding LocalFocus.DataContext.Content, ElementName=CAM_FilteredSlotList}"',
    'ToolTipService.Placement="Right"',
    'ToolTipService.HorizontalOffset="40"',
    'ToolTipService.VerticalOffset="-40"',
    'x:Name="UseSlotBinding"',
    'Fill="{Binding Content.Icon}"',
    '<Setter Property="Width" Value="104"/>',
    '<Setter Property="Height" Value="104"/>',
    'CellWidth="120"',
    'CellHeight="120"',
    'x:Key="CAM_FilterTabItemStyle"',
    'FontSize" Value="{StaticResource SmallFontSize}"',
    'Style="{StaticResource BtnTextGlow}"',
    'btn_pil_d.png',
    'btn_pil_active_d.png',
    'bar_bottom.png',
    'btn_pil_activemod_d.png',
    'btn_pil_activemod_arrowRed.png',
    'x:Key="CAM_ResourceFilterTemplate"',
    'RomanNumeralLevelImage',
    'box_resourceNum_d.png',
    'Width="72"',
    'Height="72"',
    'Columns="10"',
    'CellWidth="80"',
    'CellHeight="80"',
    'SelectedIndex="0"',
    'SelectedIndex="1"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'BoundEvent="UIAccept"',
    'x:Name="CancelButton"',
    'BoundEvent="UICancel"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'ActionCancelCommand',
    'Property="Command" Value="{Binding CustomEvent}"',
    'Property="CommandParameter" Value="CloseWidget"',
    'x:Name="ButtonHintsContainer"',
    'Style="{StaticResource ButtonHint.Container.CenterWrap}"',
    'HorizontalAlignment="Right"',
    'HorizontalContentAlignment="Right"',
    'FlowDirection="RightToLeft"',
    'x:Name="ShowContextMenu"',
    'Visibility="Collapsed"',
    'Command="{x:Null}"',
    '<Setter Property="Tag" Value="{Binding .}"/>'
)
foreach ($needle in $required) {
    if (-not $text.Contains($needle)) {
        throw "Self-contained runtime is missing required Patch 8 seam: $needle"
    }
}

# Current 1.8.910.0 SelectorAssign intentionally has no hard-coded geometry.
$selector = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="CAM_MainSelector"[^>]*/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $selector.Success) {
    throw "CAM_MainSelector was not found."
}
foreach ($stale in @('Width=', 'Height=', 'Margin=')) {
    if ($selector.Value.Contains($stale)) {
        throw "Stale pre-capture SelectorAssign geometry returned: $stale"
    }
}

# The fresh native radial contract uses LocalFocus.DataContext, not the older fixture's LocalFocus.Tag.
if ($text.Contains('LocalFocus.Tag')) {
    throw "Runtime must use the captured 1.8.910.0 LocalFocus.DataContext handoff, not stale LocalFocus.Tag."
}

# The CAM main execution path may only consume native slot collections.
foreach ($forbidden in @(
    'PlayerCharacterProperties.ControllerHotBars',
    'PlayerCharacterProperties.SpellsAndActions',
    'CurrentPlayer.SelectedCharacter.Inventory.Slots',
    'CurrentPlayer.SelectedCharacter.Stats.Passives',
    'CAM_ActionsFocusRoot',
    'CAM_ItemsFocusRoot',
    'CAM_PassivesFocusRoot',
    'CAM_MetamagicFocusRoot',
    'CAM_TabPrevHint',
    'CAM_TabNextHint',
    'ShowContextMenuCommand',
    'RequestAssignSlotCommand',
    'AssignSlotCommand',
    'SwapSlotCommand',
    'ClearSlotCommand',
    'AddRadialCommand',
    'RemoveRadialCommand',
    'Height="376"',
    'HotBarSlotStyle',
    'HotKey',
    'SlotIconStyle',
    'CAM_FilterTabTextStyle',
    'FontSize="32"',
    'Width="150"',
    'Height="64"',
    'Text="{Binding ActionResource.Name}"',
    'x:Name="CAM_CantripsFilterTab"',
    'Margin="-12"',
    'Public/Game/GUI/',
    'ScriptExtender'
)) {
    if ($text.Contains($forbidden)) {
        throw "Forbidden obsolete/native-copy seam is present in project-owned runtime: $forbidden"
    }
}

# Secondary native filters are one compact row above the action catalog.
# HotBarList starts at outer index 1 so opening CAM still focuses actions, not filters.
$actionHolderIndex = $text.IndexOf('x:Name="CAM_FilteredSlotHolder"')
$resourceHolderIndex = $text.IndexOf('x:Name="CAM_ResourceFilterHolder"')
if ($actionHolderIndex -lt 0 -or $resourceHolderIndex -lt 0 -or $resourceHolderIndex -ge $actionHolderIndex) {
    throw "The compact cantrip/resource filter row must precede the action catalog."
}
if (-not [regex]::IsMatch($text, 'x:Name="HotBarList"[\s\S]*?SelectedIndex="1"', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
    throw "HotBarList must initially focus the action catalog (outer index 1), not the secondary-filter row."
}

# Cantrips are a secondary native filter, not a fifth primary category.
if ($text.Contains('x:Name="CAM_CantripsFilterTab"')) {
    throw "Cantrips must not return as a top-level primary tab."
}
foreach ($primaryTab in @('CAM_CommonFilterTab', 'CAM_ClassFilterTab', 'CAM_ItemsFilterTab', 'CAM_PassivesFilterTab')) {
    if (-not $text.Contains(('x:Name="' + $primaryTab + '"'))) {
        throw "Missing primary CAM category: $primaryTab"
    }
}

# Resource filtering follows the native click/accept model: focus alone must not mutate the filter.
$resourceList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="CAM_ResourceFilterList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceList.Success) {
    throw "CAM_ResourceFilterList was not found."
}
if ($resourceList.Value.Contains('FilterActionResourceCommand')) {
    throw "Resource focus must not filter immediately; filtering belongs to ResourceFilterBinding on UIAccept."
}

# Resource display uses the exact current VMActionResourceCostPreview shape.
foreach ($needle in @(
    'MaxActionPoints="{Binding MaxValue}"',
    'AvailableActionPoints="{Binding Value}"',
    'HighlightedActionPoints="{Binding DataContext.Cost, ElementName=Root}"',
    'DataContext="{Binding ActionResource}"'
)) {
    if (-not $text.Contains($needle)) {
        throw "Resource filter renderer diverged from captured HotBar contract: $needle"
    }
}

Write-Host "Self-contained Patch 8 runtime contract passed: capture 1.8.910.0 is pinned, VMHotBarSlot dispatch/native B remain authoritative, selector chrome is zero-expansion over the 104px action cell, focused actions explicitly display native Hotbar tooltips, and the UI uses four primary native categories plus compact cantrip/resource secondary filters while preserving native slot order."
