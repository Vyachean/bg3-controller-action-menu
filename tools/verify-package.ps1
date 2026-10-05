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
    "Mods/BG3ControllerActionMenu/GUI/Pages/ActionRadials.xaml",
    "Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml"
)

foreach ($relative in $required) {
    $path = Join-Path $Extract $relative
    if (-not (Test-Path $path)) {
        throw "Packaged file missing: $relative"
    }
    Write-Host "OK packaged file: $relative"
}

$scriptExtender = Join-Path $Extract "Mods/BG3ControllerActionMenu/ScriptExtender"
if (Test-Path $scriptExtender) {
    throw "Xbox/App-compatible package unexpectedly contains ScriptExtender files."
}

$page = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Pages/ActionRadials.xaml")
$state = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml")
$version = (Get-Content -Raw (Join-Path $Root "VERSION")).Trim()

$requiredPageSeams = @(
    'x:Name="ActionRadials"',
    'ls:UIWidget.ContextName="HotBar"',
    'FocusLeft="UITabPrev"',
    'FocusRight="UITabNext"',
    'CanCacheFocusSurroundingElements="True"',
    'Template="{StaticResource CAM_ActionRadialWidgetTemplate}"',
    'EventName="GotKeyboardFocus"',
    'EventName="WidgetClosing"',
    'Binding="{Binding Layout}"',
    'x:Key="CAM_ActionRadialWidgetTemplate"',
    'CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars',
    'x:Name="HotBarList"',
    'SelectedIndex="0"',
    'ActionNextEvent="UIDown"',
    'ActionPrevEvent="UIUp"',
    'KeyboardNavigation.DirectionalNavigation="Contained"',
    'LocalFocusSelector="{Binding ElementName=GridSelector, Mode=OneWay}"',
    'x:Name="GridSelector"',
    'Template="{StaticResource SelectorTemplate}"',
    'x:Key="CAM_SlotContainer"',
    'TargetType="{x:Type ListBoxItem}"',
    '<ls:LSListBox x:Name="SlotList"',
    'ItemsSource="{Binding SlotList}"',
    'ItemContainerStyle="{StaticResource CAM_SlotContainer}"',
    'ItemsPanel="{StaticResource CAM_NativeGrid}"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionLeftEvent="UILeft"',
    'ActionRightEvent="UIRight"',
    'ContainerData="{Binding}"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    '<ls:LSButton x:Name="UseSlotBinding"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=ActionRadials}"',
    'BoundEvent="UIAccept"',
    '<ls:LSButton x:Name="CancelButton"',
    'BoundEvent="UICancel"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Property="CommandParameter" Value="CloseWidget"',
    'ScrollToElement="{Binding FocusedElement, ElementName=ActionRadials}"',
    'x:Name="CAM_DiagnosticPanel"',
    'Background="Transparent"'
)

foreach ($needle in $requiredPageSeams) {
    if (-not $page.Contains($needle)) {
        throw "Packaged action page is missing structural/safety seam: $needle"
    }
}

$diagnosticBuild = "CAM $version Xbox diagnostic"
if (-not $page.Contains($diagnosticBuild)) {
    throw "Packaged diagnostic build marker does not match VERSION: $diagnosticBuild"
}

$requiredStateSeams = @(
    'Name="ActionRadials"',
    'ModType="Override"',
    'Filename="ActionRadials.xaml"'
)

foreach ($needle in $requiredStateSeams) {
    if (-not $state.Contains($needle)) {
        throw "Packaged controller state is missing integration seam: $needle"
    }
}

$oldActionPage = Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml"
if (Test-Path $oldActionPage) {
    throw "Superseded CAM_ActionMenu_c.xaml unexpectedly shipped; native-named ActionRadials.xaml is required."
}

if ($page.Contains("<ls:UIWidget.ContentTemplate>")) {
    throw "Packaged controller page regressed to the rejected ContentTemplate shell."
}
if ($page.Contains("CurrentPlayer.SelectedCharacter.HotBars")) {
    throw "Packaged controller page regressed to the obsolete pre-capture HotBars source."
}
if ($page.Contains('Command="ls:UIWidget.CloseRequestCommand"') -or
    $page.Contains('x:Name="CancelNestedButton"') -or
    $page.Contains('x:Name="CAM_ActionMenu"') -or
    $page.Contains('<ls:LSInputBinding x:Name="UseSlotBinding"') -or
    $page.Contains('<ls:LSInputBinding x:Name="CancelBinding"') -or
    $page.Contains('UseWidgetNavigation="True"') -or
    $page.Contains('WidgetChainedNavigation="True"') -or
    $page.Contains('ls:MoveFocus.InternalFocusable="True"') -or
    $page.Contains('AlwaysSelectFirst="True"') -or
    $page.Contains('ls:MoveFocus.IsMoveFocusScope="True"')) {
    throw "Packaged controller page regressed from the native ActionRadials shell/focus contract."
}
if ($page.Contains("opaqueBG.png") -or $page.Contains('Background="{DynamicResource LS_tint00}"')) {
    throw "Packaged controller page regressed to a full-screen opaque/dimmed background."
}

Write-Host "Package verification passed: native ActionRadials shell, AssignList-style focus root, ControllerHotBars and native LSButton A/B seams present; no Script Extender dependency or full-screen dim regression."
