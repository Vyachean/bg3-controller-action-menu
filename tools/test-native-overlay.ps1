param()

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script = Join-Path $Root "tools/native-overlay.ps1"
$FixtureRoot = Join-Path $Root "build/native-overlay-fixture"

if (Test-Path -LiteralPath $FixtureRoot) {
    Remove-Item -LiteralPath $FixtureRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $FixtureRoot | Out-Null

$source = Join-Path $FixtureRoot "native.xaml"
$generated = Join-Path $FixtureRoot "Lib_Controller.xaml"

@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:ls="clr-namespace:ls;assembly=Code"
                    xmlns:b="http://schemas.microsoft.com/xaml/behaviors">

  <!-- Current native assignment-grid resources. -->
  <Style x:Key="AvailableSlotContainer" TargetType="ListBoxItem">
    <Setter Property="Focusable" Value="True"/>
    <Setter Property="ContentTemplate">
      <Setter.Value>
        <DataTemplate>
          <Rectangle Fill="{Binding Icon}" Width="104" Height="104"/>
        </DataTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <ItemsPanelTemplate x:Key="AvailableSlotsListPanelTemplate">
    <ls:LSGrid ActionUpEvent="UIUp"
               ActionDownEvent="UIDown"
               ActionRightEvent="UIRight"
               ActionLeftEvent="UILeft"
               AutoIndex="True"
               ContainerData="{Binding}"
               Columns="5"
               CellWidth="120"
               CellHeight="120"
               DisableScrolling="True"/>
  </ItemsPanelTemplate>

  <ControlTemplate x:Key="SpellGroupListTemplate">
    <ls:LSListBox x:Name="ListBox"
                  ItemsSource="{Binding Actions}"
                  Focusable="False"
                  ItemContainerStyle="{StaticResource AvailableSlotContainer}"
                  ItemsPanel="{StaticResource AvailableSlotsListPanelTemplate}">
      <b:Interaction.Triggers>
        <b:PropertyChangedTrigger Binding="{Binding FocusIndex, ElementName=ListBox}">
          <ls:LSPlaySound Sound="UI_Shared_Hover"/>
        </b:PropertyChangedTrigger>
      </b:Interaction.Triggers>
    </ls:LSListBox>
  </ControlTemplate>

  <ControlTemplate x:Key="InventoryCellTemplate">
    <ls:LSEntityObject Context="Inventory" EntityRef="{Binding EntityHandle}" DataContext="{Binding Object}">
      <ContentPresenter Content="{Binding .}"/>
    </ls:LSEntityObject>
  </ControlTemplate>

  <Style TargetType="ListBox" x:Key="InventoryGrid">
    <Setter Property="ItemContainerStyle">
      <Setter.Value>
        <Style TargetType="ListBoxItem">
          <Setter Property="Focusable" Value="True"/>
          <Setter Property="Template" Value="{StaticResource InventoryCellTemplate}"/>
        </Style>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- Only nested SingleHotBar keeps a native radial renderer before conversion. -->
  <Style x:Key="SingleBarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="ls:MoveFocus.Focusable" Value="True"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Grid x:Name="radialRoot" Width="1560" Height="1560">
            <Ellipse Margin="0,36,0,0" Opacity="0.9" Height="1260" Width="1260"/>
            <ls:Radial x:Name="SingleBar"
                       ItemsSource="{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}"
                       Visibility="Collapsed"
                       IsEnabled="False">
              <b:Interaction.Triggers>
                <b:EventTrigger EventName="LocalFocusChanged">
                  <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                </b:EventTrigger>
                <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                  <b:ChangePropertyAction TargetName="ActionRadials"
                                          PropertyName="Tag"
                                          Value="{Binding LocalFocus.DataContext, ElementName=SingleBar}"/>
                </b:TimerTrigger>
              </b:Interaction.Triggers>
            </ls:Radial>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="ls:MoveFocus.IsFocused" Value="True">
              <Setter TargetName="SingleBar" Property="IsEnabled" Value="True"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <ControlTemplate x:Key="ActionRadialWidgetTemplate_P8">
    <Grid>
      <Control x:Name="singleBarHolder" Visibility="Collapsed">
        <Control.Template>
          <ControlTemplate>
            <ls:PagedList ItemsSource="{Binding SingleHotBar.SlotList}"
                          PageStyle="{StaticResource SingleBarPageViewStyle}"/>
          </ControlTemplate>
        </Control.Template>
      </Control>

      <!-- Old main source: generation must remove this completely. -->
      <Grid x:Name="MainHotbarListHolder">
        <ListBox x:Name="HotBarList"
                 ItemsSource="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars}"/>
      </Grid>

      <!-- Current native assignment focus pair. Generator copies the exact
           SelectorAssign geometry before disabling this editor holder. -->
      <Control x:Name="SlotAssignHolder" Visibility="Visible">
        <Grid>
          <ls:LSListBox x:Name="AssignList"
                        SelectedIndex="0"
                        LocalFocusSelector="{Binding ElementName=SelectorAssign,Mode=OneWay}"
                        KeyboardNavigation.DirectionalNavigation="Contained"
                        ActionNextEvent="UIDown"
                        ActionPrevEvent="UIUp"/>
          <Control x:Name="SelectorAssign"
                   Width="118"
                   Height="118"
                   Margin="1,2,0,0"
                   IsHitTestVisible="False"
                   VerticalAlignment="Top"
                   HorizontalAlignment="Left"
                   Template="{StaticResource SelectorTemplate}"
                   Visibility="{Binding Visibility, ElementName=AssignList}"/>
        </Grid>
      </Control>

      <ls:AlignableWrapPanel x:Name="ButtonHintsContainer"
                             HorizontalAlignment="Right"
                             HorizontalContentAlignment="Right"
                             Width="1000"
                             FlowDirection="RightToLeft"
                             Margin="26,0,26,56">
        <ls:LSButton x:Name="SelectButtonVisual"
                     BoundEvent="UIAccept"
                     Width="1000"/>
        <ls:LSButton x:Name="ShowContextMenu"
                     Command="{Binding ShowContextMenuCommand}"
                     CommandParameter="{Binding FocusedElement, ElementName=ActionRadials}"
                     BoundEvent="ContextMenu"
                     Width="1000"/>
        <StackPanel x:Name="LegacyRadialCustomization">
          <ls:ContextMenuItem x:Name="AssignSlotItem"
                              Command="{Binding DataContext.RequestAssignSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem x:Name="DirectAssignSlotItem"
                              Command="{Binding DataContext.AssignSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem x:Name="SwapSlotItem"
                              Command="{Binding DataContext.SwapSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem x:Name="ClearSlotItem"
                              Command="{Binding DataContext.ClearSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem x:Name="AddRadialItem"
                              Command="{Binding DataContext.AddRadialCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem x:Name="RemoveRadialItem"
                              Command="{Binding DataContext.RemoveRadialCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
        </StackPanel>
        <ls:LSButton x:Name="CancelConcentrationButton"
                     BoundEvent="UIEndTurn"
                     Width="1000"/>
        <ls:LSButton x:Name="ToggleWeaponSet"
                     BoundEvent="UISelectionLeft"
                     Width="1000"/>
        <ls:LSButton x:Name="ToggleDualWield"
                     BoundEvent="UISelectionRight"
                     Width="1000"/>
        <ls:LSButton x:Name="UseSlotBinding"
                     BoundEvent="UIAccept"
                     Command="{Binding UseSlotCommand}"
                     CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>
        <ls:LSButton x:Name="CancelButton"
                     BoundEvent="UICancel"
                     Command="{Binding ClearSingleHotbarCommand}"
                     Width="1000"/>
      </ls:AlignableWrapPanel>

      <ControlTemplate.Triggers>
        <MultiDataTrigger>
          <MultiDataTrigger.Conditions>
            <Condition Binding="{Binding SingleHotBar.SlotList.Count}" Value="0"/>
            <Condition Binding="{Binding IsShowingItemsToThrow}" Value="False"/>
          </MultiDataTrigger.Conditions>
          <Setter TargetName="CancelButton" Property="CommandParameter" Value="CloseWidget"/>
        </MultiDataTrigger>
        <DataTrigger Binding="{Binding SingleHotBar.SlotList.Count}" Value="1">
          <Setter TargetName="singleBarHolder" Property="Visibility" Value="Visible"/>
          <Setter TargetName="MainHotbarListHolder" Property="Visibility" Value="Collapsed"/>
        </DataTrigger>
      </ControlTemplate.Triggers>
    </Grid>
  </ControlTemplate>
</ResourceDictionary>
'@ | Set-Content -LiteralPath $source -Encoding UTF8

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash

& $Script -PatchOnlySourceXaml $source -PatchOnlyDestinationXaml $generated
if ($LASTEXITCODE -ne 0) {
    throw "native-overlay.ps1 patch-only mode failed."
}

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $sourceHash) {
    throw "Patch-only mode modified the source XAML."
}

[xml]$xml = Get-Content -Raw -LiteralPath $generated
$text = Get-Content -Raw -LiteralPath $generated

# Main menu must no longer depend on user-configured radial membership.
if ($text.Contains("ControllerHotBars")) {
    throw "Automatic main catalog must not bind ControllerHotBars."
}

foreach ($needle in @(
    'x:Name="CAM_AutoCatalogFocusRoot"',
    'x:Name="CAM_TabList"',
    'ActionPrevEvent="UITabPrev"',
    'ActionNextEvent="UITabNext"',
    '<ContentPresenter x:Name="CAM_TabPrevHint"',
    '<ContentPresenter x:Name="CAM_TabNextHint"',
    'ConverterParameter=UITabPrev',
    'ConverterParameter=UITabNext',
    'x:Name="CAM_ActionsTab"',
    'x:Name="CAM_ItemsTab"',
    'x:Name="CAM_PassivesTab"',
    'x:Name="CAM_MetamagicTab"',
    'Text="Actions / Spells"',
    'Text="Items"',
    'Text="Passives"',
    'Text="Metamagic"',
    'x:Name="CAM_ActionsFocusRoot"',
    'x:Name="CAM_ItemsFocusRoot"',
    'x:Name="CAM_PassivesFocusRoot"',
    'x:Name="CAM_MetamagicFocusRoot"',
    '<ls:SetMoveFocusAction TargetName="ActionRadials"',
    'FocusElement="{Binding ElementName=HotBarList}"',
    'FocusElement="{Binding ElementName=CAM_InventoryListbox}"',
    'FocusElement="{Binding ElementName=CAM_PassivesListbox}"',
    'FocusElement="{Binding ElementName=CAM_MetamagicListbox}"',
    '<ls:LSListBox x:Name="HotBarList"',
    '<ls:LSListBox x:Name="CAM_InventoryListbox"',
    '<ls:LSListBox x:Name="CAM_PassivesListbox"',
    '<ls:LSListBox x:Name="CAM_MetamagicListbox"',
    'LocalFocusSelector="{Binding ElementName=CAM_ActionsSelector,Mode=OneWay}"',
    'LocalFocusSelector="{Binding ElementName=CAM_ItemsSelector,Mode=OneWay}"',
    'LocalFocusSelector="{Binding ElementName=CAM_PassivesSelector,Mode=OneWay}"',
    'LocalFocusSelector="{Binding ElementName=CAM_MetamagicSelector,Mode=OneWay}"',
    'x:Name="CAM_ActionsSelector"',
    'x:Name="CAM_ItemsSelector"',
    'x:Name="CAM_PassivesSelector"',
    'x:Name="CAM_MetamagicSelector"',
    'Width="118"',
    'Height="118"',
    'Margin="1,2,0,0"',
    'CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.SpellsAndActions',
    'CurrentPlayer.SelectedCharacter.Stats.Passives',
    'Data.TogglablePassivePredicate',
    'Data.TogglableMetaMagicPassivePredicate',
    'CurrentPlayer.SelectedCharacter.Inventory.Slots',
    'x:Key="CAM_AvailableSlotContainer"',
    'x:Key="CAM_AvailableSlotsListPanelTemplate"',
    'x:Key="CAM_SpellGroupListTemplate"',
    'ItemsSource="{Binding Actions}"',
    'x:Key="CAM_InventoryCellTemplate"',
    'x:Key="CAM_InventoryGrid"',
    'Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"',
    'Value="{Binding LocalFocus.DataContext.Object, ElementName=CAM_InventoryListbox}"',
    'Value="{Binding LocalFocus.DataContext, ElementName=CAM_PassivesListbox}"',
    'Value="{Binding LocalFocus.DataContext, ElementName=CAM_MetamagicListbox}"',
    'x:Name="CAM_ActionsTooltip"',
    'x:Name="CAM_ItemsTooltip"',
    'x:Name="CAM_PassivesTooltip"',
    'x:Name="CAM_MetamagicTooltip"',
    'x:Name="singleBarHolder"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    '<ls:LSListBox x:Name="SingleBar"',
    'LocalFocusSelector="{Binding ElementName=CAM_SingleBarSelector,Mode=OneWay}"',
    'x:Name="UseSlotBinding"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'x:Name="CancelButton"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Property="CommandParameter" Value="CloseWidget"'
)) {
    if (-not $text.Contains($needle)) {
        throw "Generated automatic catalog is missing: $needle"
    }
}

# Tab hints are visual only; the tab list is the sole UITab event owner.
foreach ($hintName in @('CAM_TabPrevHint', 'CAM_TabNextHint')) {
    $hintMatch = [regex]::Match(
        $text,
        '<ContentPresenter\b[^>]*x:Name="' + $hintName + '"[^>]*/>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $hintMatch.Success -or $hintMatch.Value.Contains('BoundEvent=')) {
        throw "Controller tab hint must be presentation-only: $hintName"
    }
}

# Each visible tab owns a native-style list+selector pair in one coordinate root.
foreach ($focusPair in @(
    @("CAM_ActionsFocusRoot", "HotBarList", "CAM_ActionsSelector"),
    @("CAM_ItemsFocusRoot", "CAM_InventoryListbox", "CAM_ItemsSelector"),
    @("CAM_PassivesFocusRoot", "CAM_PassivesListbox", "CAM_PassivesSelector"),
    @("CAM_MetamagicFocusRoot", "CAM_MetamagicListbox", "CAM_MetamagicSelector")
)) {
    $rootName = $focusPair[0]
    $listName = $focusPair[1]
    $selectorName = $focusPair[2]
    $pattern = '<Grid\b[^>]*x:Name="' + $rootName + '"[\s\S]*?<ls:LSListBox\b[^>]*x:Name="' + $listName + '"[\s\S]*?<Control\b[^>]*x:Name="' + $selectorName + '"'
    if (-not [regex]::IsMatch($text, $pattern)) {
        throw "Tab focus owner must colocate list and native selector: $rootName"
    }
}

if ($text.Contains('CAM_AutoCatalogSelector') -or
    $text.Contains('SelectedIndex="{Binding SelectedIndex, ElementName=CAM_TabList, Mode=OneWay}"')) {
    throw "0.0.35 shared outer focus model must not survive tab-focus repair."
}

# Exact native SelectorAssign geometry must be cloned, not reconstructed.
foreach ($selectorName in @("CAM_ActionsSelector", "CAM_ItemsSelector", "CAM_PassivesSelector", "CAM_MetamagicSelector")) {
    $selectorMatch = [regex]::Match(
        $text,
        '<Control\b[^>]*x:Name="' + $selectorName + '"[^>]*/>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $selectorMatch.Success -or
        -not $selectorMatch.Value.Contains('Width="118"') -or
        -not $selectorMatch.Value.Contains('Height="118"') -or
        -not $selectorMatch.Value.Contains('Margin="1,2,0,0"')) {
        throw "Tab selector did not preserve current native SelectorAssign geometry: $selectorName"
    }
}

# Footer hints stay in the native right-side lane instead of covering the
# center-bottom action resource display.
$footerMatch = [regex]::Match(
    $text,
    '<ls:AlignableWrapPanel\b[^>]*x:Name="ButtonHintsContainer"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $footerMatch.Success -or
    -not $footerMatch.Value.Contains('HorizontalAlignment="Right"') -or
    -not $footerMatch.Value.Contains('HorizontalContentAlignment="Right"') -or
    -not $footerMatch.Value.Contains('FlowDirection="RightToLeft"') -or
    -not $footerMatch.Value.Contains('Margin="26,0,26,56"')) {
    throw "Controller footer hints must remain in the native right-side lane."
}

# Nested/upcast/variant renderer remains the proven SingleHotBar grid.
if ($text.Contains("<ls:Radial ")) {
    throw "Generated controller library still contains a radial renderer."
}
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="SingleBar"').Count -ne 1) {
    throw "Expected exactly one nested SingleHotBar grid renderer."
}

# Radial customization must be completely unreachable from CAM.
$contextMatch = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="ShowContextMenu"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $contextMatch.Success -or
    -not $contextMatch.Value.Contains('IsEnabled="False"') -or
    -not $contextMatch.Value.Contains('IsHitTestVisible="False"') -or
    -not $contextMatch.Value.Contains('Visibility="Collapsed"') -or
    -not $contextMatch.Value.Contains('Width="0"') -or
    -not $contextMatch.Value.Contains('Command="{x:Null}"') -or
    $contextMatch.Value.Contains('BoundEvent=')) {
    throw "Radial ContextMenu/X must be inert, hidden, and have no input binding."
}

foreach ($forbidden in @(
    'ShowContextMenuCommand',
    'RequestAssignSlotCommand',
    'AssignSlotCommand',
    'SwapSlotCommand',
    'ClearSlotCommand',
    'AddRadialCommand',
    'RemoveRadialCommand'
)) {
    if ($text.Contains($forbidden)) {
        throw "Radial customization command leaked into automatic catalog: $forbidden"
    }
}

# Historical SpellBook predicate names are not a current Patch 8 proof.
# Do not silently turn them into shipping classification heuristics.
foreach ($unprovenPredicate in @(
    'CantripGroupPredicate',
    'SpellLevelsGroupPredicate',
    'AllActionsGroupPredicate'
)) {
    if ($text.Contains($unprovenPredicate)) {
        throw "Unproven SpellBook predicate leaked into milestone XAML: $unprovenPredicate"
    }
}
if ($text.Contains('Text="Custom"')) {
    throw "CAM must not expose a Custom tab."
}

$slotAssignMatch = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="SlotAssignHolder"[^>]*/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $slotAssignMatch.Success -or
    -not $slotAssignMatch.Value.Contains('Visibility="Collapsed"') -or
    -not $slotAssignMatch.Value.Contains('IsEnabled="False"')) {
    throw "SlotAssignHolder must be inert in automatic-catalog mode."
}

# The runtime installer stays operational/minimal; semantic proof remains CI-owned.
$overlaySource = Get-Content -Raw -LiteralPath $Script
foreach ($forbiddenRuntimeVerifier in @(
    'Packed controller library is missing required seam',
    'Assert-GridChromeContract',
    '$verifiedText',
    '$verifiedLibrary'
)) {
    if ($overlaySource.Contains($forbiddenRuntimeVerifier)) {
        throw "Install-time native overlay must not contain duplicated semantic post-pack verification: $forbiddenRuntimeVerifier"
    }
}

Write-Host "Automatic action-tab fixture passed: every tab owns its native focus/selector pair and candidate writer, footer hints stay out of the resource lane, radial customization is unreachable, nested SingleHotBar and native A/B dispatch remain intact."
