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
$hotBarSource = Join-Path $FixtureRoot "native-hotbar.xaml"
$generated = Join-Path $FixtureRoot "Lib_Controller.xaml"

@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:ls="clr-namespace:ls;assembly=Code"
                    xmlns:b="http://schemas.microsoft.com/xaml/behaviors">

  <!-- Exact current-style radial focus lifecycle used as the gameplay seam. -->
  <ControlTemplate x:Key="NativeMainRadialFocusFixture">
    <ls:Radial x:Name="HotBarRadial">
      <b:Interaction.Triggers>
        <b:EventTrigger EventName="LocalFocusChanged">
          <b:ChangePropertyAction TargetName="ActionRadials"
                                  PropertyName="Tag"
                                  Value="{Binding LocalFocus.Tag, ElementName=HotBarRadial}"/>
          <b:InvokeCommandAction Command="{Binding DataContext.ShowTooltipOnUIElement, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                 CommandParameter="{Binding ., RelativeSource={RelativeSource Mode=TemplatedParent}}"/>
          <b:InvokeCommandAction Command="{Binding DataContext.CreateFocusedTooltipDataCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                 CommandParameter="{Binding LocalFocus.Tag, ElementName=HotBarRadial}"/>
          <b:InvokeCommandAction Command="{Binding DataContext.HighlightResourcesCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                 CommandParameter="{Binding LocalFocus.Tag, ElementName=HotBarRadial}"/>
          <ls:LSPlaySound Sound="UI_HUD_Controller_RadialMenu_SlotHover"/>
        </b:EventTrigger>
      </b:Interaction.Triggers>
    </ls:Radial>
  </ControlTemplate>

  <Style x:Key="SingleBarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="ls:MoveFocus.Focusable" Value="True"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Grid x:Name="radialRoot" Width="1560" Height="1560">
            <Ellipse Margin="0,36,0,0" Opacity="0.9" Height="1260" Width="1260"/>
            <ls:Radial x:Name="SingleBar"
                       ItemsSource="{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}"
                       IsEnabled="False">
              <b:Interaction.Triggers>
                <b:EventTrigger EventName="LocalFocusChanged">
                  <b:ChangePropertyAction TargetName="ActionRadials"
                                          PropertyName="Tag"
                                          Value="{Binding LocalFocus.Tag, ElementName=SingleBar}"/>
                  <b:InvokeCommandAction Command="{Binding DataContext.CreateFocusedTooltipDataCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                         CommandParameter="{Binding LocalFocus.Tag, ElementName=SingleBar}"/>
                  <b:InvokeCommandAction Command="{Binding DataContext.HighlightResourcesCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                         CommandParameter="{Binding LocalFocus.Tag, ElementName=SingleBar}"/>
                </b:EventTrigger>
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

      <!-- Production must leave this native right-stacked composition intact. -->
      <ls:AlignableWrapPanel x:Name="ButtonHintsContainer"
                             HorizontalAlignment="Right"
                             VerticalAlignment="Bottom"
                             Width="913"
                             Tag="NativeHintLayoutSentinel">
        <ls:LSButton x:Name="SelectButtonVisual"
                     BoundEvent="UIAccept"/>
        <ls:LSButton x:Name="ShowContextMenu"
                     Command="{Binding ShowContextMenuCommand}"
                     CommandParameter="{Binding FocusedElement, ElementName=ActionRadials}"
                     BoundEvent="ContextMenu"/>
        <ls:LSButton x:Name="CancelConcentrationButton"
                     BoundEvent="UIEndTurn"/>
        <ls:LSInputBinding x:Name="UseSlotBinding"
                           BoundEvent="UIAccept"
                           Command="{Binding UseSlotCommand}"
                           CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>
        <ls:LSButton x:Name="CancelButton"
                     BoundEvent="UICancel"
                     Command="{Binding ClearSingleHotbarCommand}"/>
      </ls:AlignableWrapPanel>

      <StackPanel x:Name="LegacyRadialCustomization">
        <ls:ContextMenuItem Command="{Binding RequestAssignSlotCommand}"/>
        <ls:ContextMenuItem Command="{Binding AssignSlotCommand}"/>
        <ls:ContextMenuItem Command="{Binding SwapSlotCommand}"/>
        <ls:ContextMenuItem Command="{Binding ClearSlotCommand}"/>
        <ls:ContextMenuItem Command="{Binding AddRadialCommand}"/>
        <ls:ContextMenuItem Command="{Binding RemoveRadialCommand}"/>
      </StackPanel>

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
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:ls="clr-namespace:ls;assembly=Code">
  <ItemsControl ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"/>
  <ls:LSButton Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"/>
  <ls:LSButton Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"/>
  <ls:LSButton Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"/>
  <ls:LSButton Command="{Binding FilterActionResourceCommand}" CommandParameter="{Binding}"/>
  <ls:LSButton Command="{Binding FilterCantripsCommand}" CommandParameter="hfixturecantrips"/>
  <ls:LSButton Command="{Binding ClearSingleHotbarCommand}"/>
  <ItemsControl ItemsSource="{Binding CurrentShownDeck.SlotList}"/>
  <ItemsControl ItemsSource="{Binding SingleHotBar.SlotList}"/>
  <ItemsControl ItemsSource="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"/>
</Grid>
'@ | Set-Content -LiteralPath $hotBarSource -Encoding UTF8

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
$hotBarHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $hotBarSource).Hash

& $Script -PatchOnlySourceXaml $source -PatchOnlyHotBarSourceXaml $hotBarSource -PatchOnlyDestinationXaml $generated
if ($LASTEXITCODE -ne 0) {
    throw "native-overlay.ps1 patch-only mode failed."
}

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $sourceHash) {
    throw "Patch-only mode modified the radial source XAML."
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $hotBarSource).Hash -ne $hotBarHash) {
    throw "Patch-only mode modified the hotbar source XAML."
}

[xml]$xml = Get-Content -Raw -LiteralPath $generated
$text = Get-Content -Raw -LiteralPath $generated

# Main execution candidates must be VMHotBarSlot collections, never raw
# assignment-catalog objects.
foreach ($forbiddenSource in @(
    "ControllerHotBars",
    "PlayerCharacterProperties.SpellsAndActions",
    "CurrentPlayer.SelectedCharacter.Inventory.Slots",
    "CurrentPlayer.SelectedCharacter.Stats.Passives",
    "CAM_ActionsFocusRoot",
    "CAM_ItemsFocusRoot",
    "CAM_PassivesFocusRoot",
    "CAM_MetamagicFocusRoot",
    "CAM_TabPrevHint",
    "CAM_TabNextHint"
)) {
    if ($text.Contains($forbiddenSource)) {
        throw "Obsolete/raw main source leaked into generated controller library: $forbiddenSource"
    }
}

foreach ($needle in @(
    'x:Name="CAM_AutoCatalogFocusRoot"',
    'x:Name="CAM_FilterTabs"',
    'ActionPrevEvent="UITabPrev"',
    'ActionNextEvent="UITabNext"',
    'x:Name="CAM_CommonFilterTab"',
    'x:Name="CAM_ClassFilterTab"',
    'x:Name="CAM_ItemsFilterTab"',
    'x:Name="CAM_PassivesFilterTab"',
    'x:Name="CAM_CantripsFilterTab"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"',
    'Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"',
    'CurrentPlayer.UIData.ActionResourcesCostPreview',
    'x:Name="CAM_ResourceFilterList"',
    'Command="{Binding FilterActionResourceCommand}"',
    'CommandParameter="{Binding LocalFocus.DataContext, ElementName=CAM_ResourceFilterList}"',
    'x:Name="CAM_FilteredSlotList"',
    'Value="{Binding CurrentShownDeck.SlotList}"',
    'Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"',
    'Binding="{Binding CurrentSingleHotbarFilter, Converter={StaticResource NullToBoolFalseConverter}}" Value="True"',
    'Value="{Binding SingleHotBar.SlotList}"',
    'Command="{Binding FilterCantripsCommand}" CommandParameter="hfixturecantrips"',
    'Condition Binding="{Binding IsShowingAContainerWithVariants}" Value="False"',
    'Condition Binding="{Binding IsSelectingUpcastedSpell}" Value="False"',
    'Setter TargetName="singleBarHolder" Property="Visibility" Value="Collapsed"',
    'Setter TargetName="MainHotbarListHolder" Property="Visibility" Value="Visible"',
    'Setter TargetName="CancelButton" Property="Command" Value="{Binding CustomEvent}"',
    'KeyboardNavigation.DirectionalNavigation="Continue"',
    'x:Name="CAM_MainSelector"',
    'LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}"',
    'x:Key="CAM_ActionGridSlotContainer"',
    '<Setter Property="Tag" Value="{Binding .}"/>',
    'x:Key="CAM_ActionGridPanel"',
    'x:Key="CAM_ResourceFilterContainer"',
    'x:Key="CAM_ResourceFilterPanel"',
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
        throw "Generated native filter grid is missing: $needle"
    }
}

# The main focus trigger is taken from the native radial lifecycle and retargeted
# to the VMHotBarSlot list. It must update Tag and resource preview with the slot.
$mainFocus = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="CAM_FilteredSlotList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $mainFocus.Success) {
    throw "CAM_FilteredSlotList block was not generated."
}
foreach ($needle in @(
    'EventName="LocalFocusChanged"',
    'Value="{Binding LocalFocus.Tag, ElementName=CAM_FilteredSlotList}"',
    'CreateFocusedTooltipDataCommand',
    'HighlightResourcesCommand',
    'CommandParameter="{Binding LocalFocus.Tag, ElementName=CAM_FilteredSlotList}"',
    'UI_HUD_Controller_RadialMenu_SlotHover'
)) {
    if (-not $mainFocus.Value.Contains($needle)) {
        throw "Main slot focus lifecycle lost native radial seam: $needle"
    }
}
if ($mainFocus.Value.Contains("ShowTooltipOnUIElement")) {
    throw "PageView-specific radial tooltip target leaked into main grid focus trigger."
}

# One exact installed SelectorAssign clone owns the whole main shell.
$selectorMatch = [regex]::Match(
    $text,
    '<Control\b[^>]*x:Name="CAM_MainSelector"[^>]*/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $selectorMatch.Success -or
    -not $selectorMatch.Value.Contains('Width="118"') -or
    -not $selectorMatch.Value.Contains('Height="118"') -or
    -not $selectorMatch.Value.Contains('Margin="1,2,0,0"') -or
    -not $selectorMatch.Value.Contains('ElementName=HotBarList')) {
    throw "Main selector did not preserve current native SelectorAssign geometry/binding."
}
if ([regex]::Matches($text, 'x:Name="CAM_MainSelector"').Count -ne 1) {
    throw "Exactly one main selector must own the main navigation shell."
}

# Long action sets must not be clipped to the old hard-coded three-row height.
$actionPanel = [regex]::Match(
    $text,
    '<ItemsPanelTemplate\b[^>]*x:Key="CAM_ActionGridPanel"[\s\S]*?</ItemsPanelTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $actionPanel.Success -or $actionPanel.Value.Contains('Height="376"')) {
    throw "Main action grid must not keep the old fixed three-row height."
}

# Preserve the installed native hint-container opening tag byte-for-byte.
# CAM may remove the X child, but must not restyle the container itself.
$sourceText = Get-Content -Raw -LiteralPath $source
$sourceHintMatch = [regex]::Match(
    $sourceText,
    '<(?<tag>[A-Za-z_][A-Za-z0-9_.:-]*)\b[^>]*x:Name="ButtonHintsContainer"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$hintMatch = [regex]::Match(
    $text,
    '<(?<tag>[A-Za-z_][A-Za-z0-9_.:-]*)\b[^>]*x:Name="ButtonHintsContainer"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $sourceHintMatch.Success -or -not $hintMatch.Success -or
    $sourceHintMatch.Value -ne $hintMatch.Value) {
    throw "Installed native ButtonHintsContainer layout was not preserved exactly."
}
if ($text.Contains("CAM_TabPrevHint") -or $text.Contains("CAM_TabNextHint")) {
    throw "0.0.36 duplicate tab-hint chrome must not return."
}

# Radial customization remains unreachable.
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
foreach ($forbidden in @(
    "ShowContextMenuCommand",
    "RequestAssignSlotCommand",
    "AssignSlotCommand",
    "SwapSlotCommand",
    "ClearSlotCommand",
    "AddRadialCommand",
    "RemoveRadialCommand"
)) {
    if ($text.Contains($forbidden)) {
        throw "Radial customization command leaked into automatic filter grid: $forbidden"
    }
}

# The runtime installer remains operational/minimal; compatibility extraction is
# allowed, duplicated semantic post-pack verification is not.
$overlaySource = Get-Content -Raw -LiteralPath $Script
foreach ($forbiddenRuntimeVerifier in @(
    "Packed controller library is missing required seam",
    "Assert-GridChromeContract",
    "Assert-CurrentHotBarFilterContract",
    "missing required filter seam",
    '$verifiedText',
    '$verifiedLibrary'
)) {
    if ($overlaySource.Contains($forbiddenRuntimeVerifier)) {
        throw "Install-time native overlay must not contain duplicated semantic post-pack verification: $forbiddenRuntimeVerifier"
    }
}

Write-Host "Native hotbar-filter grid fixture passed: gameplay candidates are VMHotBarSlot collections, one assignment-style navigation shell owns vertical continuation, current radial focus drives Tag/resource preview, native button hints are preserved, radial customization is unreachable, and install-time semantic contract assertions are absent."
