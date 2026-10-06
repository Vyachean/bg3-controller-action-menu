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
if ($evidence.runtimeContract.controllerPresentation.nativeSelectorOutset -ne 12 -or
    $evidence.runtimeContract.controllerPresentation.camSelectorTemplate -ne "CAM_SelectorTemplate" -or
    $evidence.runtimeContract.controllerPresentation.camSelectorOutset -ne 0) {
    throw "CAM focus chrome must explicitly neutralize the native SelectorTemplate 12px visual outset."
}
if ($evidence.runtimeContract.controllerPresentation.spellSlotLevelStyle -ne "RomanNumeralLevelImage") {
    throw "Spell-slot secondary filters must retain the current HotBar Roman-numeral level presentation."
}
if ($evidence.runtimeContract.tooltipPresentation.contentPath -ne "LocalFocus.DataContext.Content" -or
    $evidence.runtimeContract.tooltipPresentation.command -ne "ShowTooltipOnUIElementCommand" -or
    $evidence.runtimeContract.tooltipPresentation.context -ne "Hotbar") {
    throw "Focused action tooltip contract diverged from the captured controller/HotBar pattern."
}
if (($evidence.runtimeContract.organization.primaryTabs -join ",") -ne "CommonHotBar,ClassHotBar,Cantrips,ItemHotBar,PassivesHotBar" -or
    $evidence.runtimeContract.organization.secondaryFilterSource -ne "CurrentPlayer.UIData.ActionResourcesCostPreview" -or
    $evidence.runtimeContract.organization.initialOuterListIndex -ne 1 -or
    $evidence.runtimeContract.organization.slotOrdering -ne "BG3-native") {
    throw "Controller UX organization contract must remain type -> resource/level -> BG3-native slot order."
}
if ($evidence.runtimeContract.controllerPresentation.keyboardStyleRejected -ne "HotBarSlotStyle" -or $evidence.runtimeContract.controllerPresentation.keyboardOverlayRejected -ne "HotKey") {
    throw "Keyboard HotBarSlotStyle/HotKey presentation regression guard is missing from capture evidence."
}

$required = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_FilterTabs"',
    'ActionPrevEvent="UITabPrev"',
    'ActionNextEvent="UITabNext"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"',
    ('Command="{Binding FilterCantripsCommand}" CommandParameter="' + $evidence.runtimeContract.cantripFilterParameter + '"'),
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
    'x:Key="CAM_SelectorTemplate"',
    'Template="{StaticResource CAM_SelectorTemplate}"',
    'c_itemSelector.png',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionRightEvent="UIRight"',
    'ActionLeftEvent="UILeft"',
    'PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=CAM_FilteredSlotList}"',
    'MillisecondsPerTick="70" TotalTicks="1"',
    'CreateFocusedTooltipDataCommand',
    'HighlightResourcesCommand',
    'UI_HUD_Controller_RadialMenu_SlotHover',
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
    'btn_pil_inactivemod_d.png',
    'ActiveModArrow',
    'x:Name="Marker"',
    'x:Key="CAM_ResourceFilterTemplate"',
    'Style="{StaticResource RomanNumeralLevelImage}"',
    'x:Name="SpellSlotLevels"',
    'Width="72"',
    'Height="72"',
    'Columns="10"',
    'CellWidth="80"',
    'CellHeight="80"',
    'SelectedIndex="1"',
    'x:Name="CAM_ActionTooltip"',
    'x:Name="CAM_SingleActionTooltip"',
    'ShowTooltipOnUIElementCommand',
    'LocalFocus.DataContext.Content',
    'ls:TooltipExtender.Context="Hotbar"',
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

$selectorTemplate = [regex]::Match(
    $text,
    '<ControlTemplate\b[^>]*x:Key="CAM_SelectorTemplate"[\s\S]*?</ControlTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $selectorTemplate.Success) {
    throw "CAM_SelectorTemplate was not found."
}
if ($selectorTemplate.Value.Contains('Margin="-12"')) {
    throw "CAM selector must not retain the native 12px outward focus-frame expansion."
}
if (-not $selectorTemplate.Value.Contains('Margin="0"')) {
    throw "CAM selector must keep the native focus texture inside the focused element bounds."
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
    'Template="{StaticResource SelectorTemplate}"',
    'Margin="-12"',
    'HotBarSlotStyle',
    'HotKey',
    'SlotIconStyle',
    'CAM_FilterTabTextStyle',
    'FontSize="32"',
    'Width="150"',
    'Height="64"',
    'Text="{Binding ActionResource.Name}"',
    'Public/Game/GUI/',
    'ScriptExtender'
)) {
    if ($text.Contains($forbidden)) {
        throw "Forbidden obsolete/native-copy seam is present in project-owned runtime: $forbidden"
    }
}

# Resource/level filters are a compact secondary navigation layer above the action catalog.
# Initial outer-list focus stays on the action catalog (SelectedIndex=1).
$actionHolderIndex = $text.IndexOf('x:Name="CAM_FilteredSlotHolder"')
$resourceHolderIndex = $text.IndexOf('x:Name="CAM_ResourceFilterHolder"')
if ($actionHolderIndex -lt 0 -or $resourceHolderIndex -lt 0 -or $resourceHolderIndex -ge $actionHolderIndex) {
    throw "The compact resource/level strip must precede the action catalog."
}
if (-not $text.Contains('SelectedIndex="1"')) {
    throw "The outer controller list must start on the action catalog while keeping secondary filters above it."
}

# Primary type tabs are intentionally ordered: common -> class -> cantrips -> items -> passives.
$commonTabIndex = $text.IndexOf('x:Name="CAM_CommonFilterTab"')
$classTabIndex = $text.IndexOf('x:Name="CAM_ClassFilterTab"')
$cantripTabIndex = $text.IndexOf('x:Name="CAM_CantripsFilterTab"')
$itemsTabIndex = $text.IndexOf('x:Name="CAM_ItemsFilterTab"')
$passivesTabIndex = $text.IndexOf('x:Name="CAM_PassivesFilterTab"')
if (@($commonTabIndex,$classTabIndex,$cantripTabIndex,$itemsTabIndex,$passivesTabIndex) | Where-Object { $_ -lt 0 }) {
    throw "One or more primary controller filter tabs are missing."
}
if (-not ($commonTabIndex -lt $classTabIndex -and $classTabIndex -lt $cantripTabIndex -and $cantripTabIndex -lt $itemsTabIndex -and $itemsTabIndex -lt $passivesTabIndex)) {
    throw "Primary controller filter tab order regressed."
}

# Focused action descriptions use the captured assignment-list tooltip/show-command pattern.
foreach ($tooltipName in @('CAM_ActionTooltip','CAM_SingleActionTooltip')) {
    if (-not $text.Contains('x:Name="' + $tooltipName + '"')) {
        throw "Missing focused action tooltip: $tooltipName"
    }
}
if (-not $text.Contains('Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"')) {
    throw "Focused action tooltip must be shown through the native ShowTooltipOnUIElementCommand."
}
if (-not $text.Contains('Value="{Binding LocalFocus.DataContext.Content, ElementName=HotBarList}"')) {
    throw "Main action tooltip must consume the focused VMHotBarSlot.Content object."
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

Write-Host "Self-contained Patch 8 runtime contract passed: capture 1.8.910.0 is pinned, VMHotBarSlot dispatch/focus/native B are retained, CAM focus chrome matches focused cell bounds, focused action tooltips use the native show-command path, type -> resource/level -> native slot ordering is enforced, and keyboard/radial presentation regressions are rejected."
