param()

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script = Join-Path $Root "tools/native-overlay.ps1"
$FixtureRoot = Join-Path $Root "build/native-overlay-fixture"

if (Test-Path -LiteralPath $FixtureRoot) {
    Remove-Item -LiteralPath $FixtureRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $FixtureRoot | Out-Null

$source = Join-Path $FixtureRoot "native-radials.xaml"
$hotbar = Join-Path $FixtureRoot "native-hotbar.xaml"
$generated = Join-Path $FixtureRoot "Lib_Controller.xaml"

@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:ls="clr-namespace:ls;assembly=Code"
                    xmlns:b="http://schemas.microsoft.com/xaml/behaviors">

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

      <Grid x:Name="MainHotbarListHolder">
        <ListBox x:Name="HotBarList"
                 ItemsSource="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars}"/>
      </Grid>

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

      <!-- Deliberately unusual values: generation must preserve installed chrome,
           not normalize/reflow it. -->
      <ls:AlignableWrapPanel x:Name="ButtonHintsContainer"
                             HorizontalAlignment="Right"
                             HorizontalContentAlignment="Right"
                             VerticalAlignment="Center"
                             Width="913"
                             FlowDirection="LeftToRight"
                             Margin="7,8,9,10">
        <ls:LSButton x:Name="SelectButtonVisual"
                     BoundEvent="UIAccept"
                     Width="777"/>
        <ls:LSButton x:Name="ShowContextMenu"
                     Command="{Binding ShowContextMenuCommand}"
                     CommandParameter="{Binding FocusedElement, ElementName=ActionRadials}"
                     BoundEvent="ContextMenu"
                     Width="666"/>
        <StackPanel x:Name="LegacyRadialCustomization">
          <ls:ContextMenuItem Command="{Binding DataContext.RequestAssignSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem Command="{Binding DataContext.AssignSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem Command="{Binding DataContext.SwapSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem Command="{Binding DataContext.ClearSlotCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem Command="{Binding DataContext.AddRadialCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
          <ls:ContextMenuItem Command="{Binding DataContext.RemoveRadialCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"/>
        </StackPanel>
        <ls:LSButton x:Name="UseSlotBinding"
                     BoundEvent="UIAccept"
                     Command="{Binding UseSlotCommand}"
                     CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>
        <ls:LSButton x:Name="CancelButton"
                     BoundEvent="UICancel"
                     Command="{Binding ClearSingleHotbarCommand}"
                     Width="555"/>
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

@'
<ls:UIWidget x:Name="HotBar"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:ls="clr-namespace:ls;assembly=Code"
             xmlns:b="http://schemas.microsoft.com/xaml/behaviors">
  <!-- Minimal current-hotbar contract fixture. The generator consumes these
       DCHotBar seams, never this visual tree. -->
  <Grid>
    <TextBlock Text="{Binding CurrentShownDeck}"/>
    <TextBlock Text="{Binding CurrentSingleHotbarFilter}"/>
    <TextBlock Text="{Binding SingleHotBar.SlotList.Count}"/>
    <TextBlock Text="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList.Count}"/>
    <TextBlock Text="CommonHotBar ClassHotBar ItemHotBar"/>
    <ItemsControl ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"/>
    <ls:LSButton Command="{Binding SetCurrentShownDeckCommand}"/>
    <ls:LSButton Command="{Binding FilterActionResourceCommand}"/>
    <ls:LSButton Command="{Binding FilterCantripsCommand}"/>
    <ls:LSButton Command="{Binding HighlightResourcesCommand}"/>
    <ls:LSButton Command="{Binding ClearResourceHighlightsCommand}"/>
  </Grid>
</ls:UIWidget>
'@ | Set-Content -LiteralPath $hotbar -Encoding UTF8

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
$hotbarHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $hotbar).Hash

& $Script -PatchOnlySourceXaml $source -PatchOnlyHotbarXaml $hotbar -PatchOnlyDestinationXaml $generated
if ($LASTEXITCODE -ne 0) {
    throw "native-overlay.ps1 patch-only mode failed."
}

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $sourceHash) {
    throw "Patch-only mode modified the radial source XAML."
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $hotbar).Hash -ne $hotbarHash) {
    throw "Patch-only mode modified the HotBar source XAML."
}

[xml]$xml = Get-Content -Raw -LiteralPath $generated
$text = Get-Content -Raw -LiteralPath $generated

foreach ($needle in @(
    'x:Name="CAM_HotbarFocusRoot"',
    'x:Name="CAM_DeckFilters"',
    'ActionPrevEvent="UITabPrev"',
    'ActionNextEvent="UITabNext"',
    'Text="Common"',
    'CurrentPlayer.SelectedCharacter.Stats.ClassList[0].ClassDisplayName',
    'Text="Items"',
    'Text="Passives"',
    'Command="{Binding SetCurrentShownDeckCommand}"',
    'CommandParameter="CommonHotBar"',
    'CommandParameter="ClassHotBar"',
    'CommandParameter="ItemHotBar"',
    'x:Name="CAM_HotbarGrid"',
    'LocalFocusSelector="{Binding ElementName=CAM_HotbarSelector,Mode=OneWay}"',
    'x:Name="CAM_HotbarSelector"',
    'x:Key="CAM_HotbarGridPanel"',
    'Columns="6"',
    'DisableScrolling="False"',
    'Value="{Binding SingleHotBar.SlotList}"',
    'Value="{Binding CurrentShownDeck.SlotList}"',
    'Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"',
    'Value="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"',
    'Value="{Binding LocalFocus.DataContext.Content, ElementName=CAM_HotbarGrid}"',
    'Command="{Binding HighlightResourcesCommand}"',
    'Command="{Binding ClearResourceHighlightsCommand}"',
    'CommandParameter="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"',
    'x:Name="singleBarHolder"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    '<ls:LSListBox x:Name="SingleBar"',
    'x:Name="UseSlotBinding"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'x:Name="CancelButton"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Property="CommandParameter" Value="CloseWidget"'
)) {
    if (-not $text.Contains($needle)) {
        throw "Generated hotbar filter grid is missing: $needle"
    }
}

# The broken 0.0.34-0.0.36 assignment-candidate execution architecture must
# not survive in the top-level generated library.
foreach ($forbidden in @(
    'PlayerCharacterProperties.SpellsAndActions',
    'Data.TogglablePassivePredicate',
    'Data.TogglableMetaMagicPassivePredicate',
    'CurrentPlayer.SelectedCharacter.Inventory.Slots',
    'CAM_AutoCatalogFocusRoot',
    'CAM_ActionsFocusRoot',
    'CAM_ItemsFocusRoot',
    'CAM_PassivesFocusRoot',
    'CAM_MetamagicFocusRoot',
    'CAM_TabPrevHint',
    'CAM_TabNextHint',
    'Text="Custom"'
)) {
    if ($text.Contains($forbidden)) {
        throw "Rejected assignment/source-tab architecture leaked into generated XAML: $forbidden"
    }
}

if ($text.Contains("ControllerHotBars")) {
    throw "Main generated surface must not fall back to configured controller radial membership."
}

# One flat top-level focus domain: no nested assignment list hierarchy.
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="CAM_HotbarGrid"').Count -ne 1) {
    throw "Expected exactly one top-level hotbar result grid."
}
$focusRootPattern = '<Grid\b[^>]*x:Name="CAM_HotbarFocusRoot"[\s\S]*?<ls:LSListBox\b[^>]*x:Name="CAM_HotbarGrid"[\s\S]*?<Control\b[^>]*x:Name="CAM_HotbarSelector"'
if (-not [regex]::IsMatch($text, $focusRootPattern)) {
    throw "Top-level list and selector must share one flat coordinate root."
}

# The installed native button-hint geometry/order must survive untouched.
$footerMatch = [regex]::Match(
    $text,
    '<ls:AlignableWrapPanel\b[^>]*x:Name="ButtonHintsContainer"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
foreach ($nativeAttribute in @(
    'HorizontalAlignment="Right"',
    'HorizontalContentAlignment="Right"',
    'VerticalAlignment="Center"',
    'Width="913"',
    'FlowDirection="LeftToRight"',
    'Margin="7,8,9,10"'
)) {
    if (-not $footerMatch.Success -or -not $footerMatch.Value.Contains($nativeAttribute)) {
        throw "Generator reflowed native ButtonHintsContainer: $nativeAttribute"
    }
}
if (-not $text.Contains('x:Name="SelectButtonVisual"') -or -not $text.Contains('Width="777"') -or
    -not $text.Contains('x:Name="CancelButton"') -or -not $text.Contains('Width="555"')) {
    throw "Generator changed surviving native button-hint widths."
}

# Nested/upcast/variant renderer remains the proven SingleHotBar grid.
if ($text.Contains("<ls:Radial ")) {
    throw "Generated controller library still contains a radial renderer."
}
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="SingleBar"').Count -ne 1) {
    throw "Expected exactly one nested SingleHotBar grid renderer."
}

# Radial customization is unreachable.
$contextMatch = [regex]::Match(
    $text,
    '<ls:LSButton\b[^>]*x:Name="ShowContextMenu"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $contextMatch.Success -or
    -not $contextMatch.Value.Contains('IsEnabled="False"') -or
    -not $contextMatch.Value.Contains('IsHitTestVisible="False"') -or
    -not $contextMatch.Value.Contains('Visibility="Collapsed"') -or
    -not $contextMatch.Value.Contains('Command="{x:Null}"') -or
    $contextMatch.Value.Contains('BoundEvent=')) {
    throw "Radial ContextMenu/X must be inert, hidden, and have no input binding."
}

foreach ($forbiddenCommand in @(
    'ShowContextMenuCommand',
    'RequestAssignSlotCommand',
    'AssignSlotCommand',
    'SwapSlotCommand',
    'ClearSlotCommand',
    'AddRadialCommand',
    'RemoveRadialCommand'
)) {
    if ($text.Contains($forbiddenCommand)) {
        throw "Radial customization command leaked into hotbar filter grid: $forbiddenCommand"
    }
}

$slotAssignMatch = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="SlotAssignHolder"[^>]*/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $slotAssignMatch.Success -or
    -not $slotAssignMatch.Value.Contains('Visibility="Collapsed"') -or
    -not $slotAssignMatch.Value.Contains('IsEnabled="False"')) {
    throw "SlotAssignHolder must be inert in hotbar-filter mode."
}

Write-Host "Native hotbar filter-grid fixture passed: flat VMHotBarSlot result grid, native deck/filter seams, resource highlighting, native A/B and untouched controller hint layout are present."
