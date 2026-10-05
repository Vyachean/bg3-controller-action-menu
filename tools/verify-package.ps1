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
    "Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml",
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

$page = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml")
$state = Get-Content -Raw (Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml")
$version = (Get-Content -Raw (Join-Path $Root "VERSION")).Trim()

$requiredPageSeams = @(
    'ls:UIWidget.ContextName="HotBar"',
    "<ls:UIWidget.Template>",
    "<ControlTemplate>",
    'x:Name="CAM_DiagnosticPanel"',
    'CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ControllerHotBars',
    'ItemsSource="{Binding SlotList}"',
    'ItemsSource="{Binding SingleHotBar.SlotList}"',
    '<ls:LSInputBinding x:Name="UseSlotBinding"',
    'PlayerId="{Binding CurrentPlayer.PlayerId}"',
    'Command="{Binding UseSlotCommand}"',
    'CommandParameter="{Binding Tag, ElementName=CAM_ActionMenu}"',
    'BoundEvent="UIAccept"',
    '<ls:LSInputBinding x:Name="CancelBinding"',
    'Command="{Binding ClearSingleHotbarCommand}"',
    'Property="CommandParameter" Value="CloseWidget"',
    'UseWidgetNavigation="True"',
    'WidgetChainedNavigation="True"',
    'ls:MoveFocus.InternalFocusable="True"',
    'AlwaysSelectFirst="True"',
    'ScrollToElement="{Binding FocusedElement, ElementName=CAM_ActionMenu}"',
    'x:Name="NativeSlotButton"',
    'Command="{x:Null}"',
    'EatInput="False"',
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
    'Filename="CAM_ActionMenu_c.xaml"'
)

foreach ($needle in $requiredStateSeams) {
    if (-not $state.Contains($needle)) {
        throw "Packaged controller state is missing integration seam: $needle"
    }
}

if ($page.Contains("<ls:UIWidget.ContentTemplate>")) {
    throw "Packaged controller page regressed to the rejected ContentTemplate shell."
}
if ($page.Contains("CurrentPlayer.SelectedCharacter.HotBars")) {
    throw "Packaged controller page regressed to the obsolete pre-capture HotBars source."
}
if ($page.Contains('Command="ls:UIWidget.CloseRequestCommand"') -or
    $page.Contains('x:Name="CancelNestedButton"') -or
    $page.Contains('FocusUp="UIUp"') -or
    $page.Contains('FocusDown="UIDown"') -or
    $page.Contains('FocusLeft="UILeft"') -or
    $page.Contains('FocusRight="UIRight"')) {
    throw "Packaged controller page regressed from the captured/native input-routing contract."
}
if ($page.Contains("opaqueBG.png") -or $page.Contains('Background="{DynamicResource LS_tint00}"')) {
    throw "Packaged controller page regressed to a full-screen opaque/dimmed background."
}

Write-Host "Package verification passed: ControllerHotBars plus player-scoped A/B and native grid-navigation seams present; no Script Extender dependency or full-screen dim regression."
