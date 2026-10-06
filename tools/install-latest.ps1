param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath,
    [switch]$ResolveOnly
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PortableStateRoot = Join-Path $ScriptRoot "installer-work"

if (-not $ReleaseApiUrl) {
    $ReleaseApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $PortableStateRoot "release-cache"
}
if (-not $LogPath) {
    $LogPath = Join-Path $PortableStateRoot "install-latest.log"
}
if (-not $StatusPath) {
    $StatusPath = Join-Path $PortableStateRoot "install-status.txt"
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $PortableStateRoot "xbox-dev-environment.json"
}

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

$headers = @{
    "User-Agent" = "BG3ControllerActionMenu-Installer"
    "Accept" = "application/vnd.github+json"
}

function Write-InstallStatus {
    param(
        [string]$State,
        [string]$Version,
        [string]$Message
    )
    @($State, $Version, $Message, $LogPath, $ReportPath) |
        Set-Content -LiteralPath $StatusPath -Encoding Unicode
}

function Get-Releases {
    if ($ReleaseMetadataPath) {
        return (Get-Content -Raw -LiteralPath $ReleaseMetadataPath | ConvertFrom-Json)
    }
    return (Invoke-RestMethod -Uri $ReleaseApiUrl -Headers $headers)
}

function Get-LatestRelease {
    $published = @()
    foreach ($candidate in (Get-Releases)) {
        if (-not $candidate.draft -and $candidate.published_at -and $candidate.tag_name) {
            $published += $candidate
        }
    }
    $published = @($published | Sort-Object { [DateTimeOffset]$_.published_at } -Descending)
    if ($published.Count -eq 0) {
        throw "No published release found."
    }
    return $published[0]
}

function Get-Asset {
    param($Release, [string]$Name)
    $asset = @($Release.assets | Where-Object { $_.name -eq $Name })[0]
    if (-not $asset) {
        throw "Release asset is missing: $Name"
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

$transcriptStarted = $false
$version = ""

try {
    $logParent = Split-Path -Parent $LogPath
    if ($logParent) {
        New-Item -ItemType Directory -Force -Path $logParent | Out-Null
    }
    try {
        Start-Transcript -Path $LogPath -Force | Out-Null
        $transcriptStarted = $true
    } catch {}

    $release = Get-LatestRelease
    $tag = [string]$release.tag_name
    $version = if ($tag.StartsWith("v")) { $tag.Substring(1) } else { $tag }

    $pakName = "BG3ControllerActionMenu-$version.pak"
    $pakAsset = Get-Asset -Release $release -Name $pakName
    $xboxAsset = Get-Asset -Release $release -Name "install-xbox-dev.ps1"
    $overlayAsset = Get-Asset -Release $release -Name "native-overlay.ps1"

    if ($ResolveOnly) {
        Write-InstallStatus -State "SUCCESS" -Version $version -Message "Latest release resolved."
        [pscustomobject]@{
            Tag = $tag
            Version = $version
            Pak = $pakName
        } | ConvertTo-Json
        exit 0
    }

    $releaseDir = Join-Path $CacheRoot $tag
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

    $pakPath = Join-Path $releaseDir $pakName
    $xboxPath = Join-Path $releaseDir "install-xbox-dev.ps1"
    $overlayPath = Join-Path $releaseDir "native-overlay.ps1"

    Write-Host "Installing $tag..."
    Save-Asset -Asset $pakAsset -Destination $pakPath
    Save-Asset -Asset $xboxAsset -Destination $xboxPath
    Save-Asset -Asset $overlayAsset -Destination $overlayPath

    & $xboxPath -Apply -PackagePath $pakPath -NativeOverlayPath $overlayPath -ReportPath $ReportPath
    if ($LASTEXITCODE -ne 0) {
        throw "Installer failed with exit code $LASTEXITCODE."
    }

    Write-InstallStatus -State "SUCCESS" -Version $version -Message "Installation completed."
    exit 0
} catch {
    Write-InstallStatus -State "ERROR" -Version $version -Message $_.Exception.Message
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
