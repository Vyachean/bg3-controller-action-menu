$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Temp = Join-Path $Root "build\native-radial-capture-test"
$FixtureSource = Join-Path $Temp "fixture-src"
$FakeInstall = Join-Path $Temp "fake-install"
$DataDir = Join-Path $FakeInstall "Data"
$FixturePak = Join-Path $DataDir "Game.pak"
$PatchSource = Join-Path $Temp "patch-src"
$PatchPak = Join-Path $DataDir "Patch0_Hotfix1.pak"
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

$patchActionPath = Join-Path $PatchSource "Mods\MainUI\GUI\Pages\ActionRadials.xaml"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $patchActionPath) | Out-Null
@'
<ls:UIWidget x:Name="ActionRadials"
             ls:UIWidget.ContextName="HotBar"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:ls="clr-namespace:ls;assembly=Code">
  <ListBox ItemsSource="{Binding PatchedControllerBars}"/>
  <ls:LSInputBinding BoundEvent="UIAccept" Command="{Binding PatchedUseCommand}"/>
  <ls:LSButton BoundEvent="UICancel" Command="{Binding CustomEvent}" CommandParameter="CloseWidget"/>
</ls:UIWidget>
'@ | Set-Content -LiteralPath $patchActionPath -Encoding UTF8

& $divine.FullName --game bg3 --action create-package --source $PatchSource --destination $PatchPak --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $PatchPak)) {
    throw "Failed to create native radial patch fixture PAK."
}

$pakHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $FixturePak).Hash
$patchHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $PatchPak).Hash

$captureArgs = @{
    GameInstallRoot = $FakeInstall
    DivinePath = $divine.FullName
    OutputDirectory = $CaptureDir
    NoDownload = $true
}
& (Join-Path $Root "tools\capture-native-radials.ps1") @captureArgs

$pakHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $FixturePak).Hash
$patchHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $PatchPak).Hash
if ($pakHashBefore -ne $pakHashAfter -or $patchHashBefore -ne $patchHashAfter) {
    throw "Capture tool modified a source game PAK."
}

$manifestPath = Join-Path $CaptureDir "capture-manifest.json"
$summaryPath = Join-Path $CaptureDir "capture-summary.txt"
$contractPath = Join-Path $CaptureDir "native-contract.json"
$zipPath = "$CaptureDir.zip"

foreach ($required in @($manifestPath, $summaryPath, $contractPath, $zipPath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Capture output missing: $required"
    }
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.ScannedPakCount -ne 2 -or $manifest.PackageScan.Count -ne 2) {
    throw "Expected exactly two fixture PAKs to be scanned."
}
if ($manifest.Matches.Count -ne 3) {
    throw "Expected exactly three radial XAML matches, got $($manifest.Matches.Count)."
}
if ($manifest.DuplicatePackagedPaths.Count -ne 1) {
    throw "Expected one duplicate packaged radial path across base/patch PAKs."
}
if ($manifest.DuplicatePackagedPaths[0].Copies.Count -ne 2) {
    throw "Expected both base and patch copies of ActionRadials.xaml in duplicate evidence."
}
if (@($manifest.ScanErrors).Count -ne 0) {
    throw "Fixture capture unexpectedly reported package scan errors."
}

$names = @($manifest.Matches | ForEach-Object { [System.IO.Path]::GetFileName($_.PackagedPath) })
if (@($names | Where-Object { $_ -eq "ActionRadials.xaml" }).Count -ne 2 -or
    @($names | Where-Object { $_ -eq "PreloadedActionRadials_c.xaml" }).Count -ne 1) {
    throw "Capture did not preserve both duplicate ActionRadials copies plus PreloadedActionRadials."
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

$contractReport = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
if ($contractReport.Files.Count -ne 3) {
    throw "Expected three files in native-contract.json."
}

$actionContract = @(
    $contractReport.Files |
        Where-Object {
            [System.IO.Path]::GetFileName($_.PackagedPath) -eq "ActionRadials.xaml" -and
            [System.IO.Path]::GetFileName($_.SourcePackage) -eq "Game.pak"
        }
)
if ($actionContract.Count -ne 1) {
    throw "Base ActionRadials contract entry is missing or ambiguous."
}

$patchedContract = @(
    $contractReport.Files |
        Where-Object {
            [System.IO.Path]::GetFileName($_.PackagedPath) -eq "ActionRadials.xaml" -and
            [System.IO.Path]::GetFileName($_.SourcePackage) -eq "Patch0_Hotfix1.pak"
        }
)
if ($patchedContract.Count -ne 1 -or
    @($patchedContract[0].Contract.ItemsSources | Where-Object { $_.Value -eq "{Binding PatchedControllerBars}" }).Count -ne 1) {
    throw "Patched duplicate ActionRadials contract was not preserved independently."
}
if ($actionContract[0].Contract.ContextName -ne "HotBar") {
    throw "ActionRadials ContextName was not captured."
}
if ($actionContract[0].Contract.Structure.LSInputBinding -ne 1) {
    throw "ActionRadials LSInputBinding structure count was not captured."
}
if (@($actionContract[0].Contract.ItemsSources | Where-Object { $_.Value -eq "{Binding CurrentPlayer.SelectedCharacter.HotBars}" }).Count -ne 1) {
    throw "ActionRadials ItemsSource contract was not captured."
}
if (@($actionContract[0].Contract.ControllerBindings | Where-Object {
    $_.BoundEvent -eq "UIAccept" -and $_.Command -eq "{Binding UseSlotCommand}"
}).Count -ne 1) {
    throw "ActionRadials UIAccept dispatch contract was not captured."
}
if (@($actionContract[0].Contract.ControllerBindings | Where-Object {
    $_.BoundEvent -eq "UICancel" -and $_.Command -eq "{Binding ClearSingleHotbarCommand}"
}).Count -ne 1) {
    throw "ActionRadials UICancel contract was not captured."
}

$preloadedContract = @(
    $contractReport.Files |
        Where-Object { [System.IO.Path]::GetFileName($_.PackagedPath) -eq "PreloadedActionRadials_c.xaml" }
)
if ($preloadedContract.Count -ne 1) {
    throw "PreloadedActionRadials contract entry is missing or ambiguous."
}
if (@($preloadedContract[0].Contract.ScrollBindings | Where-Object {
    $_.Value -eq "{Binding FocusedElement}"
}).Count -ne 1) {
    throw "PreloadedActionRadials ScrollToElement contract was not captured."
}
if (@($preloadedContract[0].Contract.ControllerBindings | Where-Object {
    $_.BoundEvent -eq "UICancel" -and $_.Command -eq "{Binding CustomEvent}" -and $_.CommandParameter -eq "CloseWidget"
}).Count -ne 1) {
    throw "PreloadedActionRadials close binding contract was not captured."
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
