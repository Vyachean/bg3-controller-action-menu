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
$patched = Join-Path $FixtureRoot "patched.xaml"

@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:ls="clr-namespace:ls;assembly=Code"
                    xmlns:b="http://schemas.microsoft.com/xaml/behaviors">
  <Style x:Key="SingleBarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Grid>
            <ls:Radial x:Name="SingleBar" ItemsSource="{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}">
              <b:Interaction.Triggers>
                <b:EventTrigger EventName="LocalFocusChanged"/>
              </b:Interaction.Triggers>
            </ls:Radial>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="BarPageViewStyle" TargetType="{x:Type ls:PageView}">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ls:PageView}">
          <Grid>
            <ls:Radial x:Name="HotBarRadial" ItemsSource="{TemplateBinding ItemsSource}">
              <b:Interaction.Triggers>
                <b:EventTrigger EventName="LocalFocusChanged"/>
              </b:Interaction.Triggers>
            </ls:Radial>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <ControlTemplate x:Key="ActionRadialWidgetTemplate_P8">
    <Grid>
      <ls:LSButton x:Name="UseSlotBinding" BoundEvent="UIAccept" Command="{Binding UseSlotCommand}"/>
      <ls:LSButton x:Name="CancelButton" BoundEvent="UICancel" Command="{Binding ClearSingleHotbarCommand}"/>
    </Grid>
  </ControlTemplate>
</ResourceDictionary>
'@ | Set-Content -LiteralPath $source -Encoding UTF8

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash

& $Script -PatchOnlySourceXaml $source -PatchOnlyDestinationXaml $patched
if ($LASTEXITCODE -ne 0) {
    throw "native-overlay.ps1 patch-only mode failed."
}

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $sourceHash) {
    throw "Patch-only mode modified the source XAML."
}

[xml]$xml = Get-Content -Raw -LiteralPath $patched
$text = Get-Content -Raw -LiteralPath $patched

foreach ($needle in @(
    'CAM_HotBarRadialGrid',
    'CAM_SingleBarGrid',
    'SelectedIndex="{Binding LocalFocus.Index, ElementName=HotBarRadial, Mode=OneWay}"',
    'SelectedIndex="{Binding LocalFocus.Index, ElementName=SingleBar, Mode=OneWay}"',
    'x:Name="UseSlotBinding"',
    'x:Name="CancelButton"',
    'Command="{Binding UseSlotCommand}"',
    'Command="{Binding ClearSingleHotbarCommand}"'
)) {
    if (-not $text.Contains($needle)) {
        throw "Patched fixture is missing: $needle"
    }
}

if ([regex]::Matches($text, '<ls:Radial\b').Count -ne 2) {
    throw "Native Radial controls must remain present as the input/focus engine."
}
if ([regex]::Matches($text, '<ls:LSListBox\b[^>]*x:Name="CAM_(HotBarRadial|SingleBar)Grid"').Count -ne 2) {
    throw "Expected exactly two named CAM visual mirror grids."
}
if ([regex]::Matches($text, '<ls:Radial\b[^>]*x:Name="(HotBarRadial|SingleBar)"[^>]*Opacity="0"').Count -ne 2) {
    throw "Native Radial controls must be hidden visually, not removed."
}

Write-Host "Native overlay fixture passed: native radials preserved, visual mirrors inserted, A/B seams unchanged."
