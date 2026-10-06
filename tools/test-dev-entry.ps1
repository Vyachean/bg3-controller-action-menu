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

    $installer = Join-Path $assetRoot "install-latest.ps1"
@'
param(
    [string]$Repository,
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LauncherRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath
)
@(
    "SUCCESS",
    "9.9.9-fixture",
    "Release-controlled task executed."
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
@{
    Executed = $true
    ReleaseMetadataPath = $ReleaseMetadataPath
    CacheRoot = $CacheRoot
    LauncherRoot = $LauncherRoot
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
exit 0
'@ | Set-Content -LiteralPath $installer -Encoding UTF8

    $metadata = Join-Path $TestRoot "release.json"
    [ordered]@{
        tag_name = "v9.9.9-fixture"
        draft = $false
        published_at = "2030-01-02T00:00:00Z"
        assets = @(
            [ordered]@{
                name = "install-latest.ps1"
                browser_download_url = $installer
            }
        )
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadata -Encoding UTF8

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
    if (-not (Test-Path -LiteralPath $report)) {
        throw "Release-controlled helper was not executed."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if (-not $result.Executed) {
        throw "Development entry execution marker is missing."
    }
    if ($result.LauncherRoot -ne $launcherRoot) {
        throw "Development entry did not preserve the operator's launcher root."
    }
    if ($result.CacheRoot -ne (Join-Path (Join-Path $cacheRoot "v9.9.9-fixture") "install-cache")) {
        throw "Development entry did not keep helper state under its portable release cache."
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines[0] -ne "SUCCESS" -or $statusLines[1] -ne "9.9.9-fixture") {
        throw "Development entry did not preserve the helper status contract."
    }

    Write-Host "Universal release-controlled development entry fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
