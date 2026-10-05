$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Bootstrap = Join-Path $Root "tools\bootstrap-latest.ps1"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-bootstrap-test-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

function New-FixtureAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Invoke-BootstrapFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Metadata,
        [Parameter(Mandatory = $true)][string]$CaseRoot
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
    if (-not (Test-Path -LiteralPath $Bootstrap -PathType Leaf)) {
        throw "Missing bootstrap: $Bootstrap"
    }

    $assetRoot = Join-Path $TestRoot "assets"
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null

    # Normal case: the bundled bootstrap already matches the latest release,
    # so it downloads and executes the latest canonical install-latest.ps1.
    $bootstrapAsset = Join-Path $assetRoot "bootstrap-latest.ps1"
    Copy-Item -LiteralPath $Bootstrap -Destination $bootstrapAsset -Force
    $bootstrapHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $bootstrapAsset).Hash.ToLowerInvariant()

    $installerAsset = Join-Path $assetRoot "install-latest.ps1"
    $installerHash = New-FixtureAsset -Path $installerAsset -Content @'
param(
    [string]$Repository,
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath
)
$ErrorActionPreference = "Stop"
@(
    "SUCCESS",
    "9.9.9-fixture",
    "Canonical installer executed.",
    $LogPath,
    $ReportPath
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
@{
    CanonicalInstaller = $true
    Repository = $Repository
    ReleaseMetadataPath = $ReleaseMetadataPath
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
'@

    $normalRelease = @(
        [ordered]@{
            tag_name = "v9.9.9-fixture"
            draft = $false
            prerelease = $true
            published_at = "2030-01-02T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "bootstrap-latest.ps1"
                    browser_download_url = $bootstrapAsset
                    digest = "sha256:$bootstrapHash"
                },
                [ordered]@{
                    name = "install-latest.ps1"
                    browser_download_url = $installerAsset
                    digest = "sha256:$installerHash"
                }
            )
        }
    )
    $normalMetadata = Join-Path $TestRoot "normal.json"
    $normalRelease | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $normalMetadata -Encoding UTF8

    $normal = Invoke-BootstrapFixture -Metadata $normalMetadata -CaseRoot (Join-Path $TestRoot "normal")
    if ($normal.ExitCode -ne 0) {
        throw "Normal bootstrap fixture failed with exit code $($normal.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $normal.Report -PathType Leaf)) {
        throw "Canonical installer was not invoked."
    }
    $report = Get-Content -Raw -LiteralPath $normal.Report | ConvertFrom-Json
    if (-not $report.CanonicalInstaller) {
        throw "Canonical installer marker is missing."
    }

    $cachedInstaller = Join-Path $normal.Cache "v9.9.9-fixture\install-latest.ps1"
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $cachedInstaller).Hash.ToLowerInvariant() -ne $installerHash) {
        throw "Cached canonical installer digest differs from release metadata."
    }

    # Self-update case: the newest release contains a newer bootstrap. The
    # bundled copy must transfer control to it before using any installer logic.
    $updatedBootstrapAsset = Join-Path $assetRoot "bootstrap-latest-new.ps1"
    $updatedBootstrapHash = New-FixtureAsset -Path $updatedBootstrapAsset -Content @'
param(
    [string]$Repository,
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath,
    [switch]$BootstrapUpdated,
    [switch]$ResolveOnly
)
$ErrorActionPreference = "Stop"
if (-not $BootstrapUpdated) {
    throw "Updated bootstrap was not invoked with -BootstrapUpdated."
}
@(
    "SUCCESS",
    "10.0.0-fixture",
    "Updated bootstrap executed.",
    $LogPath,
    $ReportPath
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
@{
    UpdatedBootstrap = $true
    BootstrapUpdated = [bool]$BootstrapUpdated
} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
exit 0
'@

    $selfUpdateRelease = @(
        [ordered]@{
            tag_name = "v10.0.0-fixture"
            draft = $false
            prerelease = $true
            published_at = "2030-02-02T00:00:00Z"
            assets = @(
                [ordered]@{
                    name = "bootstrap-latest.ps1"
                    browser_download_url = $updatedBootstrapAsset
                    digest = "sha256:$updatedBootstrapHash"
                },
                [ordered]@{
                    name = "install-latest.ps1"
                    browser_download_url = $installerAsset
                    digest = "sha256:$installerHash"
                }
            )
        }
    )
    $selfUpdateMetadata = Join-Path $TestRoot "self-update.json"
    $selfUpdateRelease | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $selfUpdateMetadata -Encoding UTF8

    $selfUpdate = Invoke-BootstrapFixture -Metadata $selfUpdateMetadata -CaseRoot (Join-Path $TestRoot "self-update")
    if ($selfUpdate.ExitCode -ne 0) {
        throw "Self-update bootstrap fixture failed with exit code $($selfUpdate.ExitCode)."
    }
    $selfUpdateReport = Get-Content -Raw -LiteralPath $selfUpdate.Report | ConvertFrom-Json
    if (-not $selfUpdateReport.UpdatedBootstrap -or -not $selfUpdateReport.BootstrapUpdated) {
        throw "Bundled bootstrap did not transfer control to the verified latest bootstrap."
    }

    # A digest mismatch must fail closed.
    $badDigest = $normalRelease | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $badDigest[0].assets[0].digest = "sha256:" + ("0" * 64)
    $badDigestMetadata = Join-Path $TestRoot "bad-digest.json"
    $badDigest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badDigestMetadata -Encoding UTF8

    $bad = Invoke-BootstrapFixture -Metadata $badDigestMetadata -CaseRoot (Join-Path $TestRoot "bad-digest")
    if ($bad.ExitCode -eq 0) {
        throw "Bootstrap digest mismatch unexpectedly succeeded."
    }
    $badStatus = @(Get-Content -LiteralPath $bad.Status -Encoding Unicode)
    if ($badStatus.Count -eq 0 -or $badStatus[0] -ne "ERROR") {
        throw "Bootstrap digest mismatch did not produce ERROR status."
    }

    # Never silently fall back to an older release when the newest one does not
    # satisfy the stable bootstrap contract.
    $older = $normalRelease[0] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $older.tag_name = "v9.9.8-fixture"
    $older.published_at = "2030-01-01T00:00:00Z"

    $malformedNewest = [ordered]@{
        tag_name = "v10.0.1-fixture"
        draft = $false
        prerelease = $true
        published_at = "2030-03-01T00:00:00Z"
        assets = @(
            [ordered]@{
                name = "install-latest.ps1"
                browser_download_url = $installerAsset
                digest = "sha256:$installerHash"
            }
        )
    }
    $noFallbackMetadata = Join-Path $TestRoot "no-fallback.json"
    @($malformedNewest, $older) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $noFallbackMetadata -Encoding UTF8

    $noFallback = Invoke-BootstrapFixture -Metadata $noFallbackMetadata -CaseRoot (Join-Path $TestRoot "no-fallback")
    if ($noFallback.ExitCode -eq 0) {
        throw "Malformed newest release silently fell back to an older release."
    }

    Write-Host "Self-updating installer bootstrap fixture tests passed."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
