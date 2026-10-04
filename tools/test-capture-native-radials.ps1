$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Temp = Join-Path $Root "build\native-radial-capture-test"
$FixtureSource = Join-Path $Temp "fixture-src"
$FakeInstall = Join-Path $Temp "fake-install"
$DataDir = Join-Path $FakeInstall "Data"
$FixturePak = Join-Path $DataDir "Game.pak"
$CaptureDir = Join-Path $Temp "capture"

if (Test-Path -LiteralPath $Temp) {
    Remove-Item -LiteralPath $Temp -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $FixtureSource | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

$divine = Get-ChildItem -LiteralPath (Join-Path $Root ".tools") -Filter "divine.exe" -File -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $divine) {
    throw "divine.exe not found under .tools; run build.ps1 before this fixture test."
}

$actionPath = Join-Path $FixtureSource "Mods\MainUI\GUI\Pages\ActionRadials.xaml"
$preloadedPath = Join-Path $FixtureSource "Mods\MainUI\GUI\Pages\PreloadedActionRadials_c.xaml"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $actionPath) | Out-Null

@'
<ls:UIWidget x:Name="ActionRadials"
             ls:UIWidget.ContextName="HotBar"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:ls="clr-namespace:ls;assembly=Code">
  <ListBox ItemsSource="{Binding CurrentPlayer.SelectedCharacter.HotBars}"/>
  <ls:LSInputBinding BoundEvent="UIAccept" Command="{Binding UseSlotCommand}"/>
  <ls:LSButton BoundEvent="UICancel" Command="{Binding ClearSingleHotbarCommand}"/>
</ls:UIWidget>
'@ | Set-Content -LiteralPath $actionPath -Encoding UTF8

@'
<ls:UIWidget x:Name="PreloadedActionRadials"
             ls:UIWidget.ContextName="HotBar"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:ls="clr-namespace:ls;assembly=Code">
  <ls:LSScrollViewer ls:LSScrollViewer.ScrollToElement="{Binding FocusedElement}">
    <ItemsControl ItemsSource="{Binding SingleHotBar.SlotList}"/>
  </ls:LSScrollViewer>
  <ls:LSButton BoundEvent="UICancel" Command="{Binding CustomEvent}" CommandParameter="CloseWidget"/>
</ls:UIWidget>
'@ | Set-Content -LiteralPath $preloadedPath -Encoding UTF8

& $divine.FullName --game bg3 --action create-package --source $FixtureSource --destination $FixturePak --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $FixturePak)) {
    throw "Failed to create native radial fixture PAK."
}

$pakHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $FixturePak).Hash

$captureArgs = @{
    GameInstallRoot = $FakeInstall
    DivinePath = $divine.FullName
    OutputDirectory = $CaptureDir
    NoDownload = $true
}
& (Join-Path $Root "tools\capture-native-radials.ps1") @captureArgs

$pakHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $FixturePak).Hash
if ($pakHashBefore -ne $pakHashAfter) {
    throw "Capture tool modified the source game PAK."
}

$manifestPath = Join-Path $CaptureDir "capture-manifest.json"
$summaryPath = Join-Path $CaptureDir "capture-summary.txt"
$zipPath = "$CaptureDir.zip"

foreach ($required in @($manifestPath, $summaryPath, $zipPath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Capture output missing: $required"
    }
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.ScannedPakCount -ne 1) {
    throw "Expected exactly one fixture PAK to be scanned."
}
if ($manifest.Matches.Count -ne 2) {
    throw "Expected exactly two radial XAML matches, got $($manifest.Matches.Count)."
}
if (@($manifest.ScanErrors).Count -ne 0) {
    throw "Fixture capture unexpectedly reported package scan errors."
}

$names = @($manifest.Matches | ForEach-Object { [System.IO.Path]::GetFileName($_.PackagedPath) })
if ($names -notcontains "ActionRadials.xaml" -or $names -notcontains "PreloadedActionRadials_c.xaml") {
    throw "Capture did not extract both expected radial files."
}

foreach ($match in $manifest.Matches) {
    if (-not (Test-Path -LiteralPath $match.ExtractedPath)) {
        throw "Manifest points to a missing extracted file: $($match.ExtractedPath)"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $match.ExtractedPath).Hash.ToLowerInvariant()
    if ($hash -ne $match.Sha256) {
        throw "Manifest SHA256 does not match extracted file: $($match.ExtractedPath)"
    }
}

$summary = Get-Content -Raw -LiteralPath $summaryPath
foreach ($needle in @(
    "CurrentPlayer.SelectedCharacter.HotBars",
    "UseSlotCommand",
    "ClearSingleHotbarCommand",
    "ScrollToElement",
    "SingleHotBar.SlotList",
    "CustomEvent"
)) {
    if (-not $summary.Contains($needle)) {
        throw "Capture summary is missing expected native seam: $needle"
    }
}

Write-Host "Native radial capture fixture test passed."
