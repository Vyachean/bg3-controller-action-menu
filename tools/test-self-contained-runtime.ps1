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
    $evidence.runtimeContract.controllerPresentation.genericTabLabel -ne "ActionResource.Name" -or
    $evidence.runtimeContract.controllerPresentation.spellSlotTabLabel -ne "SpellSlotNumberStyle") {
    throw "Dynamic resource-tab presentation evidence is incomplete."
}
if ($evidence.runtimeContract.controllerPresentation.nativeSelectorOutset -ne 12 -or
    $evidence.runtimeContract.controllerPresentation.camSelectorOutset -ne 4 -or
    $evidence.runtimeContract.controllerPresentation.selectorDerivation -ne "12-(120-104)/2") {
    throw "Current selector compensation evidence changed unexpectedly."
}
if ($evidence.runtimeContract.tooltipPresentation.contentPath -ne "LocalFocus.DataContext.Content" -or
    $evidence.runtimeContract.tooltipPresentation.command -ne "ShowTooltipOnUIElementCommand") {
    throw "Focused native tooltip contract diverged."
}

$required = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_ResourceTabs"',
    'ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"',
    'x:Key="CAM_ResourceTabItemStyle"',
    'Text="{Binding ActionResource.Name}"',
    'Style="{StaticResource SpellSlotNumberStyle}"',
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
    'x:Name="CAM_MainSelector"',
    'x:Key="CAM_SelectorTemplate"',
    'Template="{StaticResource CAM_SelectorTemplate}"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionRightEvent="UIRight"',
    'ActionLeftEvent="UILeft"',
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
    'x:Name="ToggleWeaponSet"',
    'x:Name="WeaponSetShortcutBinding"',
    'BoundEvent="ToggleWeaponSet"',
    'Command="{Binding SwitchWeaponSetCommand}"',
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

# Preserve current focus geometry guard until the next runtime proof.
$selectorTemplate = [regex]::Match(
    $text,
    '<ControlTemplate\b[^>]*x:Key="CAM_SelectorTemplate"[\s\S]*?</ControlTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $selectorTemplate.Success -or
    -not $selectorTemplate.Value.Contains('Margin="-4"') -or
    -not $selectorTemplate.Value.Contains('Margin="4"')) {
    throw "Current CAM selector compensation must remain -4/+4 pending runtime proof."
}

Write-Host "Self-contained Patch 8 runtime contract passed: resource tabs are the sole top-level navigation, selection drives native FilterActionResourceCommand, the grid is SingleHotBar.SlotList, ordinary native tooltips remain the only details surface, and top-level B is separated from true nested state."


# Repeatable weapon-set shortcut: preserve vanilla visual hold button and keep input transport separate.
$weaponSet = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="ToggleWeaponSet"[\s\S]*?/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $weaponSet.Success -or
    -not $weaponSet.Value.Contains('Style="{StaticResource ControllerHoldButtonStyle}"') -or
    -not $weaponSet.Value.Contains("ConverterParameter='UISelectionLeft'") -or
    -not $weaponSet.Value.Contains('Command="{Binding SwitchWeaponSetCommand}"')) {
    throw "ToggleWeaponSet visual must preserve the captured vanilla hold-button contract."
}
if ($weaponSet.Value.Contains('BoundEvent=')) {
    throw "ToggleWeaponSet visual must not own BoundEvent; 0.0.51 proved that direct binding is one-shot."
}
$weaponBinding = [regex]::Match(
    $text,
    '<ls:LSInputBinding\b[^>]*x:Name="WeaponSetShortcutBinding"[\s\S]*?/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $weaponBinding.Success -or
    -not $weaponBinding.Value.Contains('BoundEvent="ToggleWeaponSet"') -or
    -not $weaponBinding.Value.Contains('Command="{Binding SwitchWeaponSetCommand}"') -or
    -not $weaponBinding.Value.Contains('EatInput="False"')) {
    throw "WeaponSetShortcutBinding must own native ToggleWeaponSet transport."
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
