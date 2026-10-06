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

      <!-- Native radial customization holder: generation must disable it. -->
      <Control x:Name="SlotAssignHolder" Visibility="Collapsed"/>

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
    'SelectedIndex="{Binding SelectedIndex, ElementName=CAM_TabList, Mode=OneWay}"',
    '<ls:SetMoveFocusAction TargetName="ActionRadials"',
    'FocusElement="{Binding ElementName=HotBarList}"',
    '<ls:LSListBox x:Name="HotBarList"',
    'LocalFocusSelector="{Binding ElementName=CAM_AutoCatalogSelector,Mode=OneWay}"',
    'x:Name="CAM_AutoCatalogSelector"',
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

# Main focus uses the same shared list+selector coordinate model already proven in-game.
$catalogRootPattern = '<Grid\b[^>]*x:Name="CAM_AutoCatalogFocusRoot"[^>]*>[\s\S]*?<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?<Control\b[^>]*x:Name="CAM_AutoCatalogSelector"'
if (-not [regex]::IsMatch($text, $catalogRootPattern)) {
    throw "Automatic catalog list and selector must share one centered focus root."
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

Write-Host "Automatic action-tab fixture passed: native sources populate controller tabs, tab focus returns to the grid, empty filtered tabs can collapse, radial customization is unreachable, nested SingleHotBar and native A/B dispatch remain intact."
