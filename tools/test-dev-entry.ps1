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

    $fixtureInstaller = Join-Path $assetRoot "install-latest.ps1"
@'
param(
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LauncherRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath
)
if (-not (Test-Path -LiteralPath $ReleaseMetadataPath -PathType Leaf)) {
    throw "Release-controlled installer did not inherit offline release metadata."
}
if (-not $LauncherRoot -or -not (Test-Path -LiteralPath $LauncherRoot -PathType Container)) {
    throw "Release-controlled installer did not inherit the operator launcher root."
}
if ($env:CAM_FIXTURE_INSTALL_FAIL -eq "1") {
    throw "Fixture install rejected the package."
}
"fixture in-process install log" | Set-Content -LiteralPath $LogPath -Encoding UTF8
[pscustomobject]@{ Package = "fixture"; Apply = $true } |
    ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
@(
    "SUCCESS",
    "9.9.9-fixture",
    "Installation completed.",
    $LogPath,
    $ReportPath
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

# The child is a PowerShell helper: stale native LASTEXITCODE must never
# turn this explicitly successful install into a false failure.
& cmd.exe /c "exit 23"
'@ | Set-Content -LiteralPath $fixtureInstaller -Encoding UTF8

    $fixtureCapture = Join-Path $assetRoot "capture-self-contained-inputs.ps1"
@'
param([string]$PortableRoot)
if (-not $PortableRoot -or -not (Test-Path -LiteralPath $PortableRoot -PathType Container)) {
    throw "Read-only capture did not inherit the portable launcher folder."
}
if ($env:CAM_FIXTURE_CAPTURE_FAIL -eq "1") {
    throw "Fixture read-only capture failed."
}
$archive = Join-Path $PortableRoot "bg3-controller-action-menu-inputs-fixture.zip"
[System.IO.File]::WriteAllBytes($archive, [byte[]](1,2,3,4))
"fixture read-only capture log" | Set-Content -LiteralPath (Join-Path $PortableRoot "capture.log") -Encoding UTF8
@("SUCCESS", "Capture complete.", $archive, (Join-Path $PortableRoot "capture.log")) |
    Set-Content -LiteralPath (Join-Path $PortableRoot "capture-status.txt") -Encoding Unicode
'@ | Set-Content -LiteralPath $fixtureCapture -Encoding UTF8

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
                    name = "install-latest.ps1"
                    browser_download_url = $fixtureInstaller
                },
                [ordered]@{
                    name = "capture-self-contained-inputs.ps1"
                    browser_download_url = $fixtureCapture
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
        -TaskMode install `
        -ReleaseMetadataPath $metadata `
        -CacheRoot $cacheRoot `
        -LauncherRoot $launcherRoot `
        -LogPath $log `
        -StatusPath $status `
        -ReportPath $report

    if ($LASTEXITCODE -ne 0) {
        throw "Universal development install entry fixture failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $report -PathType Leaf)) {
        throw "Release-controlled install helper was not executed."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if ($result.Task -ne "install" -or $result.ReadOnly) {
        throw "Development entry did not report the installation task."
    }
    if ($result.Release -ne "9.9.9-fixture" -or $result.State -ne "SUCCESS") {
        throw "Development entry reported the wrong release/state."
    }
    if (-not (Test-Path -LiteralPath $result.EnvironmentReport -PathType Leaf)) {
        throw "Development entry did not preserve the Xbox environment report."
    }
    if (-not (Test-Path -LiteralPath $log -PathType Leaf) -or
        -not (Get-Content -Raw -LiteralPath $log).Contains("fixture in-process install log")) {
        throw "Development entry did not mirror install diagnostics to the generic task log."
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines.Count -lt 3 -or
        $statusLines[0] -ne "SUCCESS" -or
        $statusLines[1] -ne "9.9.9-fixture" -or
        $statusLines[2] -notlike "*CAM installed*") {
        throw "Development entry did not preserve the universal VBS success contract."
    }

    $env:CAM_FIXTURE_INSTALL_FAIL = "1"
    try {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Entry `
            -TaskMode install `
            -ReleaseMetadataPath $metadata `
            -CacheRoot $cacheRoot `
            -LauncherRoot $launcherRoot `
            -LogPath $log `
            -StatusPath $status `
            -ReportPath $report 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            throw "A failed child install must not be reported as a successful development task."
        }
        $failedStatus = @(Get-Content -LiteralPath $status -Encoding Unicode)
        $failedReport = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
        if ($failedStatus[0] -ne "ERROR" -or
            $failedReport.State -ne "ERROR" -or
            $failedReport.Message -notlike "*Fixture install rejected*") {
            throw "Failed install must report the real helper error in both status and report."
        }
    } finally {
        Remove-Item Env:CAM_FIXTURE_INSTALL_FAIL -ErrorAction SilentlyContinue
    }

    # The published universal VBS calls dev-entry without explicit TaskMode.
    # The temporary visual-evidence release must therefore capture read-only.
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Entry `
        -ReleaseMetadataPath $metadata `
        -CacheRoot $cacheRoot `
        -LauncherRoot $launcherRoot `
        -LogPath $log `
        -StatusPath $status `
        -ReportPath $report
    if ($LASTEXITCODE -ne 0) {
        throw "Read-only resource capture entry fixture failed."
    }
    $captureResult = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    $captureStatus = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($captureResult.Task -ne "capture" -or $captureResult.State -ne "SUCCESS" -or
        -not $captureResult.ReadOnly -or -not (Test-Path -LiteralPath $captureResult.Archive -PathType Leaf) -or
        $captureStatus[0] -ne "SUCCESS" -or $captureStatus[1] -ne "9.9.9-fixture") {
        throw "Universal VBS failed to report a verified read-only ZIP capture."
    }
    if (-not (Get-Content -Raw -LiteralPath $log).Contains("fixture read-only capture log")) {
        throw "Universal read-only capture log was not preserved."
    }

    $env:CAM_FIXTURE_CAPTURE_FAIL = "1"
    try {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Entry `
            -ReleaseMetadataPath $metadata `
            -CacheRoot $cacheRoot `
            -LauncherRoot $launcherRoot `
            -LogPath $log `
            -StatusPath $status `
            -ReportPath $report 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            throw "A failed read-only capture must fail closed."
        }
        $failedCapture = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
        if ($failedCapture.Task -ne "capture" -or $failedCapture.State -ne "ERROR" -or
            $failedCapture.Message -notlike "*Fixture read-only capture failed*") {
            throw "Read-only capture must report the helper failure."
        }
    } finally {
        Remove-Item Env:CAM_FIXTURE_CAPTURE_FAIL -ErrorAction SilentlyContinue
    }
    Write-Host "Universal read-only resource capture entry fixture passed."

    Write-Host "Universal release-controlled install entry fixture passed."
    # The preceding intentionally failed child left a native exit code of 1;
    # the test's actual assertions completed successfully.
    $global:LASTEXITCODE = 0
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
