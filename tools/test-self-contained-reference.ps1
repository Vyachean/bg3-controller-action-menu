$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$NativeFixtureTest = Join-Path $Root "tools\test-native-overlay.ps1"
$Prepare = Join-Path $Root "tools\prepare-self-contained-reference.ps1"
$FixtureRoot = Join-Path $Root "build\self-contained-reference-fixture"
$CaptureRoot = Join-Path $FixtureRoot "capture-input"
$OutputRoot = Join-Path $FixtureRoot "reference-output"
$Archive = Join-Path $FixtureRoot "capture.zip"

if (Test-Path -LiteralPath $FixtureRoot) { Remove-Item -LiteralPath $FixtureRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $FixtureRoot | Out-Null

& $NativeFixtureTest
if ($LASTEXITCODE -ne 0) { throw "Native overlay fixture prerequisite failed." }

$nativeFixture = Join-Path $Root "build\native-overlay-fixture\native-radials.xaml"
$hotBarFixture = Join-Path $Root "build\native-overlay-fixture\native-hotbar.xaml"

$radialRelative = "files\Public\Game\GUI\Library\PreloadedActionRadials_c.xaml"
$hotBarRelative = "files\Mods\MainUI\GUI\Pages\HotBar.xaml"
$radialDest = Join-Path $CaptureRoot $radialRelative
$hotBarDest = Join-Path $CaptureRoot $hotBarRelative
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $radialDest) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $hotBarDest) | Out-Null
Copy-Item -LiteralPath $nativeFixture -Destination $radialDest -Force
Copy-Item -LiteralPath $hotBarFixture -Destination $hotBarDest -Force

$manifest = [ordered]@{
    SchemaVersion = 1
    CreatedAtUtc = "2030-01-01T00:00:00Z"
    GamePackageVersion = "9.9.9.9-fixture"
    Matches = @(
        [ordered]@{
            PackagedPath = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"
            RelativeCapturedPath = $radialRelative
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $radialDest).Hash.ToLowerInvariant()
        },
        [ordered]@{
            PackagedPath = "Mods/MainUI/GUI/Pages/HotBar.xaml"
            RelativeCapturedPath = $hotBarRelative
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hotBarDest).Hash.ToLowerInvariant()
        }
    )
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $CaptureRoot "manifest.json") -Encoding UTF8

Compress-Archive -Path (Join-Path $CaptureRoot "*") -DestinationPath $Archive -CompressionLevel Optimal

& $Prepare -CaptureArchive $Archive -OutputRoot $OutputRoot
if ($LASTEXITCODE -ne 0) { throw "Self-contained reference preparation failed." }

$reference = Join-Path $OutputRoot "Lib_Controller.reference.xaml"
$evidencePath = Join-Path $OutputRoot "evidence.json"
if (-not (Test-Path -LiteralPath $reference -PathType Leaf)) { throw "Reference library was not produced." }
if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { throw "Evidence record was not produced." }

[xml]$referenceXml = Get-Content -Raw -LiteralPath $reference
$evidence = Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json
if ($evidence.GamePackageVersion -ne "9.9.9.9-fixture") { throw "Captured game version was not preserved." }
if ($evidence.CantripFilterParameter -ne "hfixturecantrips") { throw "Concrete cantrip filter parameter was not preserved." }
if (-not $evidence.ReferenceLibrarySha256) { throw "Reference SHA-256 was not recorded." }

Write-Host "Self-contained capture-to-reference fixture passed."
