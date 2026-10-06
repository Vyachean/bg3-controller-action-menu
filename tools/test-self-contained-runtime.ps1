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
if ($evidence.runtimeContract.controllerPresentation.mainSlotStyle -ne "SlotIconStyle" -or $evidence.runtimeContract.controllerPresentation.mainSlotSize -ne 104) {
    throw "Controller slot presentation must remain pinned to captured SlotIconStyle at 104px."
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
    'CommandParameter="{Binding LocalFocus.DataContext, ElementName=CAM_ResourceFilterList}"',
    'Value="{Binding CurrentShownDeck.SlotList}"',
    'Value="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.PassivesHotBar.SlotList}"',
    'Value="{Binding SingleHotBar.SlotList}"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'x:Name="HotBarList"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'x:Name="CAM_FilteredSlotList"',
    'KeyboardNavigation.DirectionalNavigation="Continue"',
    'x:Name="CAM_MainSelector"',
    'Template="{StaticResource SelectorTemplate}"',
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
    'Style="{StaticResource SlotIconStyle}"',
    'Width="104"',
    'Height="104"',
    'x:Key="CAM_FilterTabTextStyle"',
    '<Setter Property="FontSize" Value="32"/>',
    'btn_pil_d.png',
    'btn_pil_active_d.png',
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
    'ShowTooltipOnUIElement',
    'HotBarSlotStyle',
    'HotKey',
    'Public/Game/GUI/',
    'ScriptExtender'
)) {
    if ($text.Contains($forbidden)) {
        throw "Forbidden obsolete/native-copy seam is present in project-owned runtime: $forbidden"
    }
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

Write-Host "Self-contained Patch 8 runtime contract passed: capture 1.8.910.0 is pinned, VMHotBarSlot dispatch/focus/native B are retained, controller-native 104px slot presentation and styled filter tabs are enforced, keyboard HotBarSlotStyle/HotKey overlays are rejected, and radial customization/raw assignment catalogs are absent."
