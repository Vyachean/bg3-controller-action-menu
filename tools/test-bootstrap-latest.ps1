$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Bootstrap = Join-Path $Root "tools\bootstrap-latest.ps1"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-bootstrap-test-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

try {
    $assetRoot = Join-Path $TestRoot "assets"
    $cacheRoot = Join-Path $TestRoot "cache"
    $status = Join-Path $TestRoot "status.txt"
    $report = Join-Path $TestRoot "report.json"
    $log = Join-Path $TestRoot "install.log"
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null

    $installer = Join-Path $assetRoot "install-latest.ps1"
@'
param(
    [string]$Repository,
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath
)
@(
    "SUCCESS",
    "9.9.9-fixture",
    "Latest installer executed.",
    $LogPath,
    $ReportPath
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
@{
    Executed = $true
    ReleaseMetadataPath = $ReleaseMetadataPath
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
exit 0
'@ | Set-Content -LiteralPath $installer -Encoding UTF8

    $metadata = Join-Path $TestRoot "releases.json"
    @(
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
        }
    ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadata -Encoding UTF8

    $args = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $Bootstrap,
        "-ReleaseMetadataPath", $metadata,
        "-CacheRoot", $cacheRoot,
        "-LogPath", $log,
        "-StatusPath", $status,
        "-ReportPath", $report
    )
    & powershell.exe @args

    if ($LASTEXITCODE -ne 0) {
        throw "Bootstrap fixture failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $report)) {
        throw "Downloaded latest installer was not executed."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if (-not $result.Executed) {
        throw "Latest installer execution marker is missing."
    }

    Write-Host "Minimal latest-installer bootstrap fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
