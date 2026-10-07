param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath,
    [string]$LauncherRoot,
    [switch]$ResolveOnly
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PortableStateRoot = if ($LauncherRoot) {
    Join-Path $LauncherRoot "installer-work"
} else {
    Join-Path $ScriptRoot "installer-work"
}

if (-not $ReleaseApiUrl) {
    $ReleaseApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $PortableStateRoot "release-cache"
}
if (-not $LogPath) {
    $LogPath = Join-Path $PortableStateRoot "dev-task.log"
}
if (-not $StatusPath) {
    $StatusPath = Join-Path $PortableStateRoot "dev-status.txt"
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $PortableStateRoot "dev-report.json"
}

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

$headers = @{
    "User-Agent" = "BG3ControllerActionMenu-DevLauncher"
    "Accept" = "application/vnd.github+json"
}
$token = $env:GH_TOKEN
if (-not $token) {
    $token = $env:GITHUB_TOKEN
}
if ($token) {
    $headers["Authorization"] = "Bearer $token"
}

function Get-Releases {
    $payload = if ($ReleaseMetadataPath) {
        Get-Content -Raw -LiteralPath $ReleaseMetadataPath | ConvertFrom-Json
    } else {
        Invoke-RestMethod -Uri $ReleaseApiUrl -Headers $headers
    }

    # Invoke-RestMethod may surface a top-level JSON array as one Object[] in
    # the pipeline. Enumerate explicitly so callers always receive one release
    # object at a time, matching the single-object fixture contract as well.
    foreach ($release in @($payload)) {
        Write-Output $release
    }
}

function Get-LatestRelease {
    $published = @(
        Get-Releases |
            Where-Object { -not $_.draft -and $_.published_at -and $_.tag_name } |
            Sort-Object { [DateTimeOffset]$_.published_at } -Descending
    )
    if ($published.Count -eq 0) {
        throw "No published development release found."
    }
    return $published[0]
}

function Get-Asset {
    param($Release, [string]$Name)

    $asset = @($Release.assets | Where-Object { $_.name -eq $Name })[0]
    if (-not $asset) {
        throw "Development release asset is missing: $Name"
    }
    return $asset
}

function Save-Asset {
    param($Asset, [string]$Destination)

    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    if ($ReleaseMetadataPath -and (Test-Path -LiteralPath ([string]$Asset.browser_download_url))) {
        Copy-Item -LiteralPath ([string]$Asset.browser_download_url) -Destination $Destination -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri ([string]$Asset.browser_download_url) -OutFile $Destination
    }
}

$release = Get-LatestRelease
$tag = [string]$release.tag_name
$version = if ($tag.StartsWith("v")) { $tag.Substring(1) } else { $tag }

if ($ResolveOnly) {
    @(
        "SUCCESS",
        $version,
        "Universal development entry resolved."
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

    [pscustomobject]@{
        Tag = $tag
        Version = $version
        Task = "install"
    } | ConvertTo-Json
    exit 0
}

# Current release task: install/update the self-contained PAK.
# This is deliberately the only release-specific decision in the universal
# development entry. A later release may replace this body with capture,
# diagnostics, install+capture, or another development operation without
# changing the operator's VBS shortcut.
$installerAsset = Get-Asset -Release $release -Name "install-latest.ps1"
$releaseDir = Join-Path $CacheRoot $tag
$installer = Join-Path $releaseDir "install-latest.ps1"
Save-Asset -Asset $installerAsset -Destination $installer

$installerArgs = @{
    Repository = $Repository
    ReleaseApiUrl = $ReleaseApiUrl
    ReleaseMetadataPath = $ReleaseMetadataPath
    CacheRoot = Join-Path $releaseDir "install-cache"
    LogPath = $LogPath
    StatusPath = $StatusPath
    ReportPath = $ReportPath
    LauncherRoot = $LauncherRoot
}

# install-latest.ps1 is an in-process PowerShell helper. If it returns,
# the task succeeded; failures propagate as terminating exceptions. Never use
# $LASTEXITCODE as the status of a script invoked with & because it may be null
# or left over from an unrelated native command.
& $installer @installerArgs
exit 0
