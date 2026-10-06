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
    $launcherAsset = Join-Path $assetRoot "Install-BG3ControllerActionMenu.vbs"
    Set-Content -LiteralPath $launcherAsset -Value "' new launcher fixture" -Encoding ASCII
    Set-Content -LiteralPath $pak -Value "fake-pak" -NoNewline

@'
param(
    [switch]$Apply,
    [string]$PackagePath,
    [string]$ReportPath
)
if (-not $Apply) { throw "Expected -Apply." }
@{
    Applied = $true
    Package = (Split-Path -Leaf $PackagePath)
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8

# Simulate the real helper contract: return normally without calling exit.
# Also leave a stale native-process exit code behind; install-latest must not
# mistake that value for the result of this PowerShell script.
& cmd.exe /c "exit 37"
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
                    name = "Install-BG3ControllerActionMenu.vbs"
                    browser_download_url = $launcherAsset
                }
            )
        }
    ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadata -Encoding UTF8

    $caseRoot = Join-Path $TestRoot "case"
    $cache = Join-Path $caseRoot "cache"
    $log = Join-Path $caseRoot "install.log"
    $status = Join-Path $caseRoot "status.txt"
    $report = Join-Path $caseRoot "report.json"
    $launcherRoot = Join-Path $caseRoot "launcher"
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $launcherRoot "Install-BG3ControllerActionMenu.vbs") -Value "' old launcher fixture" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $launcherRoot "bootstrap-latest.ps1") -Value "# old bootstrap fixture" -Encoding UTF8

    $args = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $Installer,
        "-ReleaseMetadataPath", $metadata,
        "-CacheRoot", $cache,
        "-LogPath", $log,
        "-StatusPath", $status,
        "-ReportPath", $report,
        "-LauncherRoot", $launcherRoot
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
        $result.Package -ne "BG3ControllerActionMenu-$version.pak") {
        throw "Installer did not pass the self-contained release PAK to the Xbox installer."
    }

    if ((Get-Content -Raw -LiteralPath (Join-Path $launcherRoot "Install-BG3ControllerActionMenu.vbs")).Trim() -ne "' new launcher fixture") {
        throw "Canonical installer did not refresh the existing development VBS automatically."
    }
    if (Test-Path -LiteralPath (Join-Path $launcherRoot "bootstrap-latest.ps1")) {
        throw "Canonical installer did not retire the obsolete local bootstrap."
    }

    # Legacy extracted launchers do not know the newer -LauncherRoot parameter.
    # Prove that install-latest can recover the caller bootstrap directory from
    # MyInvocation.ScriptName and upgrade that already-extracted folder anyway.
    $legacyRoot = Join-Path $caseRoot "legacy-launcher"
    $legacyCache = Join-Path $caseRoot "legacy-cache"
    $legacyLog = Join-Path $caseRoot "legacy-install.log"
    $legacyStatus = Join-Path $caseRoot "legacy-status.txt"
    $legacyReport = Join-Path $caseRoot "legacy-report.json"
    New-Item -ItemType Directory -Force -Path $legacyRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $legacyRoot "Install-BG3ControllerActionMenu.vbs") -Value "' legacy launcher fixture" -Encoding ASCII

    $legacyBootstrap = Join-Path $legacyRoot "bootstrap-latest.ps1"
@"
param()
& '$Installer' -ReleaseMetadataPath '$metadata' -CacheRoot '$legacyCache' -LogPath '$legacyLog' -StatusPath '$legacyStatus' -ReportPath '$legacyReport'
exit `$LASTEXITCODE
"@ | Set-Content -LiteralPath $legacyBootstrap -Encoding UTF8

    & $legacyBootstrap
    if ($LASTEXITCODE -ne 0) {
        throw "Legacy launcher compatibility fixture failed with exit code $LASTEXITCODE."
    }
    if ((Get-Content -Raw -LiteralPath (Join-Path $legacyRoot "Install-BG3ControllerActionMenu.vbs")).Trim() -ne "' new launcher fixture") {
        throw "Installer could not auto-refresh a legacy VBS without an explicit LauncherRoot."
    }
    if (Test-Path -LiteralPath $legacyBootstrap) {
        throw "Installer did not retire the running legacy bootstrap after migrating the VBS."
    }

    $launcherOutput = & cscript.exe //nologo $Launcher --self-test
    if ($LASTEXITCODE -ne 0 -or ($launcherOutput -join [Environment]::NewLine) -notmatch "syntax OK") {
        throw "VBScript launcher self-test failed."
    }

    Write-Host "Minimal latest-release installer fixture passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
