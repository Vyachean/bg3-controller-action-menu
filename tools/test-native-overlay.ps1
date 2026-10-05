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
  <Style x:Key="AvailableSlotContainer" TargetType="ListBoxItem">
    <Setter Property="Focusable" Value="True"/>
  </Style>
  <ItemsPanelTemplate x:Key="AvailableSlotsListPanelTemplate">
    <ls:LSGrid ActionUpEvent="UIUp" ActionDownEvent="UIDown" ActionRightEvent="UIRight" ActionLeftEvent="UILeft" AutoIndex="True"/>
  </ItemsPanelTemplate>
  <Style x:Key="SlotAssignHolderStyle" TargetType="Control">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate>
          <Grid>
            <ls:LSListBox x:Name="AssignList"
                          LocalFocusSelector="{Binding ElementName=SelectorAssign,Mode=OneWay}"
                          KeyboardNavigation.DirectionalNavigation="Contained"
                          ActionNextEvent="UIDown"
                          ActionPrevEvent="UIUp"/>
            <Control x:Name="SelectorAssign"/>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="SingleBarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="ls:MoveFocus.Focusable" Value="True"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Grid>
            <ls:Radial x:Name="SingleBar"
                       ItemsSource="{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}"
                       Visibility="Collapsed"
                       IsEnabled="False">
              <b:Interaction.Triggers>
                <b:EventTrigger EventName="LocalFocusChanged">
                  <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                </b:EventTrigger>
                <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                  <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=SingleBar}"/>
                </b:TimerTrigger>
              </b:Interaction.Triggers>
            </ls:Radial>
            <b:Interaction.Triggers>
              <b:DataTrigger Binding="{Binding Path=(ls:MoveFocus.IsFocused), RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="False">
                <b:ChangePropertyAction PropertyName="LocalFocus" TargetName="SingleBar" Value="{x:Null}"/>
              </b:DataTrigger>
            </b:Interaction.Triggers>
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

  <Style x:Key="BarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="ls:MoveFocus.Focusable" Value="True"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Border>
            <Grid>
              <ls:Radial x:Name="HotBarRadial"
                         ItemsSource="{TemplateBinding ItemsSource}"
                         IsEnabled="{Binding Path=(ls:MoveFocus.IsFocused), RelativeSource={RelativeSource Mode=TemplatedParent}}"
                         Visibility="Collapsed">
                <b:Interaction.Triggers>
                  <b:EventTrigger EventName="LocalFocusChanged">
                    <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                  </b:EventTrigger>
                  <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                    <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{Binding LocalFocus.DataContext, ElementName=HotBarRadial}"/>
                  </b:TimerTrigger>
                  <b:DataTrigger Binding="{Binding Path=(ls:MoveFocus.IsFocused), RelativeSource={RelativeSource Mode=TemplatedParent}}" Value="True"/>
                </b:Interaction.Triggers>
              </ls:Radial>
              <ls:LSInputBinding x:Name="swapSlotBinding" BoundEvent="UIAccept">
                <ls:LSInputBinding.CommandParameter>
                  <MultiBinding>
                    <Binding Path="LocalFocus.Index" ElementName="HotBarRadial"/>
                    <Binding Path="LocalFocus.DataContext" ElementName="HotBarRadial"/>
                  </MultiBinding>
                </ls:LSInputBinding.CommandParameter>
              </ls:LSInputBinding>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <DataTrigger Binding="{Binding LocalFocus, ElementName=HotBarRadial}" Value="{x:Null}">
              <Setter TargetName="swapSlotBinding" Property="IsEnabled" Value="False"/>
            </DataTrigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <ControlTemplate x:Key="RadialHotBarListItemContainer" TargetType="{x:Type ListBoxItem}">
    <ls:PagedList ItemsSource="{Binding SlotList}" PageStyle="{StaticResource BarPageViewStyle}"/>
  </ControlTemplate>

  <ControlTemplate x:Key="ActionRadialWidgetTemplate_P8">
    <Grid>
      <Control x:Name="singleBarHolder">
        <Control.Template>
          <ControlTemplate>
            <ls:PagedList ItemsSource="{Binding SingleHotBar.SlotList}" PageStyle="{StaticResource SingleBarPageViewStyle}"/>
          </ControlTemplate>
        </Control.Template>
      </Control>
      <ListBox x:Name="HotBarList">
        <ListBox.ItemContainerStyle>
          <Style TargetType="{x:Type ListBoxItem}">
            <Setter Property="Template" Value="{StaticResource RadialHotBarListItemContainer}"/>
          </Style>
        </ListBox.ItemContainerStyle>
      </ListBox>
      <ls:LSButton x:Name="UseSlotBinding"
                   BoundEvent="UIAccept"
                   Command="{Binding UseSlotCommand}"
                   CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>
      <ls:LSButton x:Name="CancelButton"
                   BoundEvent="UICancel"
                   Command="{Binding ClearSingleHotbarCommand}"/>
      <ControlTemplate.Triggers>
        <MultiDataTrigger>
          <MultiDataTrigger.Conditions>
            <Condition Binding="{Binding SingleHotBar.SlotList.Count}" Value="0"/>
            <Condition Binding="{Binding IsShowingItemsToThrow}" Value="False"/>
          </MultiDataTrigger.Conditions>
          <Setter TargetName="CancelButton" Property="CommandParameter" Value="CloseWidget"/>
        </MultiDataTrigger>
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

foreach ($needle in @(
    'x:Key="CAM_ActionGridPanel"',
    '<ls:LSListBox x:Name="HotBarRadial"',
    '<ls:LSListBox x:Name="SingleBar"',
    'LocalFocusSelector="{Binding ElementName=CAM_HotBarRadialSelector,Mode=OneWay}"',
    'LocalFocusSelector="{Binding ElementName=CAM_SingleBarSelector,Mode=OneWay}"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionRightEvent="UIRight"',
    'ActionLeftEvent="UILeft"',
    'x:Key="RadialHotBarListItemContainer"',
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="UseSlotBinding"',
    'x:Name="CancelButton"',
    'Command="{Binding UseSlotCommand}"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'Property="CommandParameter" Value="CloseWidget"',
    'Binding Path="LocalFocus.Index" ElementName="HotBarRadial"',
    'Binding Path="LocalFocus.DataContext" ElementName="HotBarRadial"'
)) {
    if (-not $text.Contains($needle)) {
        throw "Generated controller library is missing: $needle"
    }
}

if ($text.Contains("<ls:Radial ")) {
    throw "Generated controller library still contains a radial slot renderer."
}
if ($text.Contains("AssignSlotCommand")) {
    throw "Action grid must not execute slot-assignment commands."
}
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="(HotBarRadial|SingleBar)"').Count -ne 2) {
    throw "Expected exactly two assignment-style action grids."
}

Write-Host "Native slot-assignment grid fixture passed: outer native template/A/B/swap seams preserved; only the two radial slot renderers became LSListBox+LSGrid."
