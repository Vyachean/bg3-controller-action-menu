$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Bootstrap = Join-Path $Root "tools\install-latest.ps1"
$Launcher = Join-Path $Root "tools\Install-BG3ControllerActionMenu.vbs"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-one-click-test-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

function New-FixtureAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Invoke-Bootstrap {
    param(
        [Parameter(Mandatory = $true)][string]$Metadata,
        [Parameter(Mandatory = $true)][string]$CaseRoot,
        [switch]$ResolveOnly
    )

    New-Item -ItemType Directory -Force -Path $CaseRoot | Out-Null
    $cache = Join-Path $CaseRoot "cache"
    $log = Join-Path $CaseRoot "install.log"
    $status = Join-Path $CaseRoot "status.txt"
    $report = Join-Path $CaseRoot "report.json"

    $args = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $Bootstrap,
        "-ReleaseMetadataPath", $Metadata,
        "-CacheRoot", $cache,
        "-LogPath", $log,
        "-StatusPath", $status,
        "-ReportPath", $report
    )
    if ($ResolveOnly) {
        $args += "-ResolveOnly"
    }

    & powershell.exe @args
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
        ExitCode = $exitCode
        Cache = $cache
        Log = $log
        Status = $status
        Report = $report
    }
}

try {
    if (-not (Test-Path -LiteralPath $Bootstrap)) {
        throw "Missing bootstrap: $Bootstrap"
    }
    if (-not (Test-Path -LiteralPath $Launcher)) {
        throw "Missing launcher: $Launcher"
    }

    $assetRoot = Join-Path $TestRoot "assets"
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null

    $latestVersion = "9.9.9-fixture"
    $pak = Join-Path $assetRoot "BG3ControllerActionMenu-$latestVersion.pak"
    $installer = Join-Path $assetRoot "install-xbox-dev.ps1"
    $overlay = Join-Path $assetRoot "native-overlay.ps1"

    $pakHash = New-FixtureAsset -Path $pak -Content "fake-pak-content"
    $installerHash = New-FixtureAsset -Path $installer -Content @'
param(
    [switch]$Apply,
    [string]$PackagePath,
    [string]$NativeOverlayPath,
    [string]$ReportPath
)
$ErrorActionPreference = "Stop"
if (-not $Apply) { throw "Fixture installer expected -Apply." }
if (-not (Test-Path -LiteralPath $PackagePath)) { throw "Fixture package is missing." }
if (-not (Test-Path -LiteralPath $NativeOverlayPath)) { throw "Fixture native overlay builder is missing." }
@{
    Applied = $true
    Package = (Split-Path -Leaf $PackagePath)
    NativeOverlay = (Split-Path -Leaf $NativeOverlayPath)
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
'@
    $overlayHash = New-FixtureAsset -Path $overlay -Content "param() Write-Output native-overlay-fixture"

    $olderVersion = "9.9.8-fixture"
    $olderPak = Join-Path $assetRoot "BG3ControllerActionMenu-$olderVersion.pak"
    $olderInstaller = Join-Path $assetRoot "install-xbox-dev-older.ps1"
    $olderPakHash = New-FixtureAsset -Path $olderPak -Content "old-pak"
    $olderInstallerHash = New-FixtureAsset -Path $olderInstaller -Content "Write-Output old"

    $releases = @(
        [ordered]@{
            tag_name = "v10.0.0-draft"
            draft = $true
            prerelease = $true
            published_at = "2030-01-03T00:00:00Z"
            assets = @()
        },
        [ordered]@{
            tag_name = "v$latestVersion"
            draft = $false
            prerelease = $true
            published_at = "2030-01-02T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "BG3ControllerActionMenu-$latestVersion.pak"
                    browser_download_url = $pak
                    digest = "sha256:$pakHash"
                },
                [ordered]@{
                    name = "install-xbox-dev.ps1"
                    browser_download_url = $installer
                    digest = "sha256:$installerHash"
                },
                [ordered]@{
                    name = "native-overlay.ps1"
                    browser_download_url = $overlay
                    digest = "sha256:$overlayHash"
                }
            )
        },
        [ordered]@{
            tag_name = "v$olderVersion"
            draft = $false
            prerelease = $true
            published_at = "2030-01-01T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "BG3ControllerActionMenu-$olderVersion.pak"
                    browser_download_url = $olderPak
                    digest = "sha256:$olderPakHash"
                },
                [ordered]@{
                    name = "install-xbox-dev.ps1"
                    browser_download_url = $olderInstaller
                    digest = "sha256:$olderInstallerHash"
                }
            )
        }
    )

    $metadata = Join-Path $TestRoot "releases.json"
    $releases | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadata -Encoding UTF8

    $success = Invoke-Bootstrap -Metadata $metadata -CaseRoot (Join-Path $TestRoot "success")
    if ($success.ExitCode -ne 0) {
        throw "Latest-release bootstrap fixture failed with exit code $($success.ExitCode)."
    }

    $statusLines = @(Get-Content -LiteralPath $success.Status -Encoding Unicode)
    if ($statusLines.Count -lt 2 -or $statusLines[0] -ne "SUCCESS" -or $statusLines[1] -ne $latestVersion) {
        throw "Success status did not record the selected latest version."
    }

    if (-not (Test-Path -LiteralPath $success.Report)) {
        throw "Fixture installer was not invoked; report is missing."
    }
    $report = Get-Content -Raw -LiteralPath $success.Report | ConvertFrom-Json
    if (-not $report.Applied -or
        $report.Package -ne "BG3ControllerActionMenu-$latestVersion.pak" -or
        $report.NativeOverlay -ne "native-overlay.ps1") {
        throw "Fixture installer received the wrong release assets."
    }

    $cachedPak = Join-Path $success.Cache ("v$latestVersion\BG3ControllerActionMenu-$latestVersion.pak")
    $cachedInstaller = Join-Path $success.Cache ("v$latestVersion\install-xbox-dev.ps1")
    $cachedOverlay = Join-Path $success.Cache ("v$latestVersion\native-overlay.ps1")
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $cachedPak).Hash.ToLowerInvariant() -ne $pakHash) {
        throw "Cached PAK digest differs from the release asset."
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $cachedInstaller).Hash.ToLowerInvariant() -ne $installerHash) {
        throw "Cached installer digest differs from the release asset."
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $cachedOverlay).Hash.ToLowerInvariant() -ne $overlayHash) {
        throw "Cached native overlay digest differs from the release asset."
    }

    # Digest mismatch must fail before the downloaded installer can run.
    $badDigest = $releases | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $badDigest[1].assets[0].digest = "sha256:" + ("0" * 64)
    $badMetadata = Join-Path $TestRoot "releases-bad-digest.json"
    $badDigest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badMetadata -Encoding UTF8

    $bad = Invoke-Bootstrap -Metadata $badMetadata -CaseRoot (Join-Path $TestRoot "bad-digest")
    if ($bad.ExitCode -eq 0) {
        throw "Digest mismatch fixture unexpectedly succeeded."
    }
    $badStatus = @(Get-Content -LiteralPath $bad.Status -Encoding Unicode)
    if ($badStatus[0] -ne "ERROR") {
        throw "Digest mismatch did not produce ERROR status."
    }

    # A malformed newest release must not silently fall back to an older version.
    $malformed = $releases | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $malformed[1].assets = @($malformed[1].assets | Where-Object { $_.name -ne "native-overlay.ps1" })
    $malformedMetadata = Join-Path $TestRoot "releases-malformed-latest.json"
    $malformed | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $malformedMetadata -Encoding UTF8

    $noFallback = Invoke-Bootstrap -Metadata $malformedMetadata -CaseRoot (Join-Path $TestRoot "no-fallback") -ResolveOnly
    if ($noFallback.ExitCode -eq 0) {
        throw "Malformed latest release silently fell back to an older release."
    }

    $launcherOutput = & cscript.exe //nologo $Launcher --self-test
    if ($LASTEXITCODE -ne 0 -or ($launcherOutput -join [Environment]::NewLine) -notmatch "syntax OK") {
        throw "VBScript launcher self-test failed."
    }

    Write-Host "One-click latest-release installer fixture tests passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
