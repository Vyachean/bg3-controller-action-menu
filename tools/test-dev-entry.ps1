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
    [string]$PortableRoot
)
$archive = Join-Path $PortableRoot "bg3-controller-action-menu-inputs-fixture.zip"
$captureLog = Join-Path $PortableRoot "capture.log"
"fixture archive" | Set-Content -LiteralPath $archive -Encoding UTF8
"fixture read-only capture log" | Set-Content -LiteralPath $captureLog -Encoding UTF8
@(
    "SUCCESS",
    "Capture completed.",
    $archive,
    $captureLog
) | Set-Content -LiteralPath (Join-Path $PortableRoot "capture-status.txt") -Encoding Unicode

# Prove that dev-entry trusts this child process's explicit exit status and not
# a stale native LASTEXITCODE value produced earlier inside the helper.
& cmd.exe /c "exit 23"
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
        throw "Universal development capture entry fixture failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $report -PathType Leaf)) {
        throw "Release-controlled capture helper was not executed."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if ($result.Task -ne "capture" -or -not $result.ReadOnly) {
        throw "Development entry did not report the read-only capture task."
    }
    if ($result.Release -ne "9.9.9-fixture") {
        throw "Development entry reported the wrong release."
    }
    if (-not $result.Archive -or -not (Test-Path -LiteralPath $result.Archive -PathType Leaf)) {
        throw "Development entry did not preserve the capture archive."
    }
    if ((Split-Path -Parent $result.Archive) -ne $launcherRoot) {
        throw "Capture archive must be written beside the operator VBS."
    }
    if (-not (Test-Path -LiteralPath $log -PathType Leaf) -or
        -not (Get-Content -Raw -LiteralPath $log).Contains("fixture read-only capture log")) {
        throw "Development entry did not mirror capture diagnostics to the normal task log."
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines.Count -lt 3 -or
        $statusLines[0] -ne "SUCCESS" -or
        $statusLines[1] -ne "9.9.9-fixture" -or
        $statusLines[2] -notlike "*Read-only keyboard/controller resource-template capture completed*") {
        throw "Development entry did not preserve the universal VBS success contract."
    }

    Write-Host "Universal release-controlled read-only capture entry fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
