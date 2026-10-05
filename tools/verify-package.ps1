param(
    [Parameter(Mandatory = $true)]
    [string]$Package
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Tools = Join-Path $Root ".tools"
$Extract = Join-Path $Root "build/verify-extracted"

if (-not (Test-Path $Package)) {
    throw "Package does not exist: $Package"
}
$Package = (Resolve-Path $Package).Path

$divine = Get-ChildItem -Path $Tools -Filter "divine.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $divine) {
    throw "divine.exe not found under $Tools; run build.ps1 first."
}

if (Test-Path $Extract) {
    Remove-Item -Recurse -Force $Extract
}
New-Item -ItemType Directory -Force -Path $Extract | Out-Null

Write-Host "Extracting $Package for package verification..."
& $divine.FullName --game bg3 --action extract-package --source $Package --destination $Extract --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Package extraction failed with exit code $LASTEXITCODE"
}

$required = @(
    "Mods/BG3ControllerActionMenu/meta.lsx",
    "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml",
    "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Keyboard.xaml",
    "Mods/BG3ControllerActionMenu/GUI/Library/CAM_ActionRadials.xaml"
)

foreach ($relative in $required) {
    $path = Join-Path $Extract $relative
    if (-not (Test-Path $path)) {
        throw "Packaged file missing: $relative"
    }
    Write-Host "OK packaged file: $relative"
}

$forbiddenPaths = @(
    "Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml",
    "Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml",
    "Mods/BG3ControllerActionMenu/ScriptExtender"
)

foreach ($relative in $forbiddenPaths) {
    if (Test-Path (Join-Path $Extract $relative)) {
        throw "Packaged native-ownership regression: $relative must not exist."
    }
}

$controllerLibrary = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml")
$template = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Library/CAM_ActionRadials.xaml")
$version = (Get-Content -Raw (Join-Path $Root "VERSION")).Trim()

$requiredLibrarySeams = @(
    "/BG3ControllerActionMenu;component/Library/CAM_ActionRadials.xaml"
)
foreach ($needle in $requiredLibrarySeams) {
    if (-not $controllerLibrary.Contains($needle)) {
        throw "Packaged controller library is missing integration seam: $needle"
    }
}

$requiredTemplateSeams = @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    'x:Name="CAM_DiagnosticPanel"',
    'native ActionRadials page + Lib_Controller template override',
    'CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars',
    'ItemsSource="{Binding SlotList}"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    'x:Key="CAM_SlotContainer"',
    'TargetType="{x:Type ListBoxItem}"',
    'ItemContainerStyle="{StaticResource CAM_SlotContainer}"',
    'ItemsPanel="{StaticResource CAM_NativeGrid}"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionLeftEvent="UILeft"',
    'ActionRightEvent="UIRight"',
    'TargetName="ActionRadials"',
    'PropertyName="Tag"',
    'Value="{Binding LocalFocus.DataContext, ElementName=SectionSlots}"',
                'TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1"',
                'TargetName="HotBarList"',
                'FocusElement="{Binding ElementName=HotBarList, Path=Tag}"',
    '<ls:LSButton x:Name="UseSlotBinding"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'BoundEvent="UIAccept"',
    '<ls:LSButton x:Name="CancelButton"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Property="CommandParameter" Value="CloseWidget"',
    'ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"',
    'x:Name="NativeSlotButton"',
    'Command="{x:Null}"',
    'EatInput="False"',
    'BoundEvent="UICancel"',
    'Background="Transparent"'
)

foreach ($needle in $requiredTemplateSeams) {
    if (-not $template.Contains($needle)) {
        throw "Packaged radial template is missing structural/safety seam: $needle"
    }
}

$diagnosticBuild = "CAM $version Xbox diagnostic"
if (-not $template.Contains($diagnosticBuild)) {
    throw "Packaged diagnostic build marker does not match VERSION: $diagnosticBuild"
}

$forbiddenTemplateSeams = @(
    "opaqueBG.png",
    'Background="{DynamicResource LS_tint00}"',
    "CurrentPlayer.SelectedCharacter.HotBars",
    'Command="ls:UIWidget.CloseRequestCommand"',
    'x:Name="CancelNestedButton"',
    '<ls:LSInputBinding x:Name="UseSlotBinding"',
    '<ls:LSInputBinding x:Name="CancelBinding"',
    'UseWidgetNavigation="True"',
    'WidgetChainedNavigation="True"',
    'ls:MoveFocus.InternalFocusable="True"',
    'AlwaysSelectFirst="True"',
    'ls:MoveFocus.IsMoveFocusScope="True"',
    'ElementName=CAM_ActionMenu'
)

foreach ($needle in $forbiddenTemplateSeams) {
    if ($template.Contains($needle)) {
        throw "Packaged radial template safety regression: $needle"
    }
}

Write-Host "Package verification passed: native ActionRadials state/page preserved; controller library overrides only ActionRadialWidgetTemplate_P8; captured ControllerHotBars/focus/A/B seams present; no Script Extender dependency."
