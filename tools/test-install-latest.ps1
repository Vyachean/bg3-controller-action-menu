$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Installer = Join-Path $Root "tools\install-latest.ps1"
$Launcher = Join-Path $Root "tools\Install-BG3ControllerActionMenu.vbs"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-install-latest-test-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

try {
    $assetRoot = Join-Path $TestRoot "assets"
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null

    $version = "9.9.9-fixture"
    $pak = Join-Path $assetRoot "BG3ControllerActionMenu-$version.pak"
    $xbox = Join-Path $assetRoot "install-xbox-dev.ps1"
    $overlay = Join-Path $assetRoot "native-overlay.ps1"

    Set-Content -LiteralPath $pak -Value "fake-pak" -NoNewline
    Set-Content -LiteralPath $overlay -Value "param() Write-Output overlay-fixture" -Encoding UTF8

@'
param(
    [switch]$Apply,
    [string]$PackagePath,
    [string]$NativeOverlayPath,
    [string]$ReportPath
)
if (-not $Apply) { throw "Expected -Apply." }
@{
    Applied = $true
    Package = (Split-Path -Leaf $PackagePath)
    Overlay = (Split-Path -Leaf $NativeOverlayPath)
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
exit 0
'@ | Set-Content -LiteralPath $xbox -Encoding UTF8

    $metadata = Join-Path $TestRoot "releases.json"
    @(
        [ordered]@{
            tag_name = "v10.0.0-draft"
            draft = $true
            published_at = "2030-01-03T00:00:00Z"
            assets = @()
        },
        [ordered]@{
            tag_name = "v$version"
            draft = $false
            published_at = "2030-01-02T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "BG3ControllerActionMenu-$version.pak"
                    browser_download_url = $pak
                },
                [ordered]@{
                    name = "install-xbox-dev.ps1"
                    browser_download_url = $xbox
                },
                [ordered]@{
                    name = "native-overlay.ps1"
                    browser_download_url = $overlay
                }
            )
        }
    ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadata -Encoding UTF8

    $caseRoot = Join-Path $TestRoot "case"
    $cache = Join-Path $caseRoot "cache"
    $log = Join-Path $caseRoot "install.log"
    $status = Join-Path $caseRoot "status.txt"
    $report = Join-Path $caseRoot "report.json"
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null

    $args = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $Installer,
        "-ReleaseMetadataPath", $metadata,
        "-CacheRoot", $cache,
        "-LogPath", $log,
        "-StatusPath", $status,
        "-ReportPath", $report
    )
    & powershell.exe @args

    if ($LASTEXITCODE -ne 0) {
        throw "Installer fixture failed with exit code $LASTEXITCODE."
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines[0] -ne "SUCCESS" -or $statusLines[1] -ne $version) {
        throw "Installer did not record the selected latest release."
    }

    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    if (-not $result.Applied -or
        $result.Package -ne "BG3ControllerActionMenu-$version.pak" -or
        $result.Overlay -ne "native-overlay.ps1") {
        throw "Installer did not pass the latest release assets to the Xbox installer."
    }

    $launcherOutput = & cscript.exe //nologo $Launcher --self-test
    if ($LASTEXITCODE -ne 0 -or ($launcherOutput -join [Environment]::NewLine) -notmatch "syntax OK") {
        throw "VBScript launcher self-test failed."
    }

    Write-Host "Minimal latest-release installer fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
