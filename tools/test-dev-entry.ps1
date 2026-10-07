$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Entry = Join-Path $Root "tools\dev-entry.ps1"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-dev-entry-test-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

try {
    $assetRoot = Join-Path $TestRoot "assets"
    $cacheRoot = Join-Path $TestRoot "cache"
    $launcherRoot = Join-Path $TestRoot "launcher"
    $status = Join-Path $TestRoot "status.txt"
    $report = Join-Path $TestRoot "report.json"
    $log = Join-Path $TestRoot "task.log"
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null

    $capture = Join-Path $assetRoot "capture-self-contained-inputs.ps1"
@'
param(
    [string]$PortableRoot = ""
)
$ErrorActionPreference = "Stop"
if (-not $PortableRoot) {
    throw "PortableRoot is required by the capture fixture."
}
New-Item -ItemType Directory -Force -Path $PortableRoot | Out-Null
$archive = Join-Path $PortableRoot "bg3-controller-action-menu-inputs-fixture.zip"
$captureLog = Join-Path $PortableRoot "capture.log"
Set-Content -LiteralPath $archive -Value "fixture archive" -Encoding UTF8
Set-Content -LiteralPath $captureLog -Value "fixture capture completed" -Encoding UTF8
@(
    "SUCCESS",
    "Capture completed.",
    $archive,
    $captureLog
) | Set-Content -LiteralPath (Join-Path $PortableRoot "capture-status.txt") -Encoding Unicode
exit 0
'@ | Set-Content -LiteralPath $capture -Encoding UTF8

    $metadata = Join-Path $TestRoot "release.json"
    @(
        [ordered]@{
            tag_name = "v10.0.0-draft"
            draft = $true
            published_at = "2030-01-03T00:00:00Z"
            assets = @()
        },
        [ordered]@{
            tag_name = "v9.9.9-fixture"
            draft = $false
            published_at = "2030-01-02T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "capture-self-contained-inputs.ps1"
                    browser_download_url = $capture
                }
            )
        },
        [ordered]@{
            tag_name = "v9.9.8-older"
            draft = $false
            published_at = "2030-01-01T00:00:00Z"
            assets = @()
        }
    ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadata -Encoding UTF8

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Entry `
        -ReleaseMetadataPath $metadata `
        -CacheRoot $cacheRoot `
        -LauncherRoot $launcherRoot `
        -LogPath $log `
        -StatusPath $status `
        -ReportPath $report

    if ($LASTEXITCODE -ne 0) {
        throw "Universal development entry fixture failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $report -PathType Leaf)) {
        throw "Release-controlled capture task did not write its report."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if ($result.Task -ne "capture-hotbar-resource-filter") {
        throw "Development entry selected the wrong task: $($result.Task)"
    }
    if ($result.LauncherRoot -ne $launcherRoot) {
        throw "Development entry did not preserve the operator's launcher root."
    }

    $expectedArchive = Join-Path $launcherRoot "bg3-controller-action-menu-inputs-fixture.zip"
    if ($result.Archive -ne $expectedArchive -or -not (Test-Path -LiteralPath $expectedArchive -PathType Leaf)) {
        throw "Development entry did not preserve the capture archive path."
    }
    if ($result.CaptureStatusPath -ne (Join-Path $launcherRoot "capture-status.txt")) {
        throw "Development entry did not use the portable capture status path."
    }

    $cachedCapture = Join-Path (Join-Path $cacheRoot "v9.9.9-fixture") "capture-self-contained-inputs.ps1"
    if (-not (Test-Path -LiteralPath $cachedCapture -PathType Leaf)) {
        throw "Development entry did not cache the release-controlled capture helper."
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines.Count -lt 3 -or
        $statusLines[0] -ne "SUCCESS" -or
        $statusLines[1] -ne "9.9.9-fixture" -or
        -not $statusLines[2].Contains("bg3-controller-action-menu-inputs-fixture.zip")) {
        throw "Development entry did not expose the capture result through the standard launcher status contract."
    }

    $resolveStatus = Join-Path $TestRoot "resolve-status.txt"
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Entry `
        -ReleaseMetadataPath $metadata `
        -CacheRoot $cacheRoot `
        -StatusPath $resolveStatus `
        -ReportPath (Join-Path $TestRoot "resolve-report.json") `
        -ResolveOnly
    if ($LASTEXITCODE -ne 0) {
        throw "ResolveOnly fixture failed with exit code $LASTEXITCODE."
    }
    $resolveLines = @(Get-Content -LiteralPath $resolveStatus -Encoding Unicode)
    if ($resolveLines[0] -ne "SUCCESS" -or $resolveLines[1] -ne "9.9.9-fixture") {
        throw "ResolveOnly no longer preserves the launcher resolution contract."
    }

    Write-Host "Universal release-controlled HotBar capture entry fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
