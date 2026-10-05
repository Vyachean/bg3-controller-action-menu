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

if (-not $ReleaseApiUrl) {
    $ReleaseApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\installer-cache"
}
$stateRoot = Split-Path -Parent $CacheRoot
if (-not $stateRoot) {
    $stateRoot = $CacheRoot
}
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

if (-not $LogPath) {
    $LogPath = Join-Path $stateRoot "install-latest.log"
}
if (-not $StatusPath) {
    $StatusPath = Join-Path $stateRoot "install-status.txt"
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $stateRoot "xbox-dev-environment.json"
}

$headers = @{
    "User-Agent" = "BG3ControllerActionMenu-OneClickInstaller"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    # Windows PowerShell versions that already negotiate modern TLS do not need this.
}

function Write-InstallStatus {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [string]$Version = "",
        [string]$Message = ""
    )

    $parent = Split-Path -Parent $StatusPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    @(
        $State,
        $Version,
        $Message,
        $LogPath,
        $ReportPath
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
}

function Get-ReleaseList {
    if ($ReleaseMetadataPath) {
        if (-not (Test-Path -LiteralPath $ReleaseMetadataPath)) {
            throw "Release metadata fixture does not exist: $ReleaseMetadataPath"
        }
        return @(Get-Content -Raw -LiteralPath $ReleaseMetadataPath | ConvertFrom-Json)
    }

    return @(Invoke-RestMethod -Uri $ReleaseApiUrl -Headers $headers)
}

function Resolve-LatestCamRelease {
    param([Parameter(Mandatory = $true)][object[]]$Releases)

    $published = @(
        $Releases |
            Where-Object { -not $_.draft -and $_.published_at -and $_.tag_name } |
            Sort-Object { [DateTimeOffset]$_.published_at } -Descending
    )

    if ($published.Count -eq 0) {
        throw "No published BG3 Controller Action Menu release was found."
    }

    # Never silently fall back to an older release. If the newest published release
    # is malformed, fail closed so the user cannot unknowingly install stale code.
    $release = $published[0]
    $tag = [string]$release.tag_name
    $version = if ($tag.StartsWith("v")) { $tag.Substring(1) } else { $tag }
    $expectedPakName = "BG3ControllerActionMenu-$version.pak"

    $pakAssets = @($release.assets | Where-Object { $_.name -eq $expectedPakName })
    $installerAssets = @($release.assets | Where-Object { $_.name -eq "install-xbox-dev.ps1" })

    if ($pakAssets.Count -ne 1) {
        throw "Latest release '$tag' must contain exactly one '$expectedPakName' asset; found $($pakAssets.Count)."
    }
    if ($installerAssets.Count -ne 1) {
        throw "Latest release '$tag' must contain exactly one 'install-xbox-dev.ps1' asset; found $($installerAssets.Count)."
    }

    return [pscustomobject]@{
        Release = $release
        Tag = $tag
        Version = $version
        Pak = $pakAssets[0]
        Installer = $installerAssets[0]
    }
}

function Assert-AssetDigest {
    param([Parameter(Mandatory = $true)]$Asset)

    $match = [regex]::Match([string]$Asset.digest, '^sha256:([0-9a-fA-F]{64})$')
    if (-not $match.Success) {
        throw "Release asset '$($Asset.name)' has no usable GitHub SHA-256 digest."
    }
    return $match.Groups[1].Value.ToLowerInvariant()
}

function Save-VerifiedReleaseAsset {
    param(
        [Parameter(Mandatory = $true)]$Asset,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $expected = Assert-AssetDigest -Asset $Asset
    $source = [string]$Asset.browser_download_url
    if (-not $source) {
        throw "Release asset '$($Asset.name)' has no download URL."
    }

    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $temp = "$Destination.download"
    try {
        if ($ReleaseMetadataPath -and (Test-Path -LiteralPath $source)) {
            Copy-Item -LiteralPath $source -Destination $temp -Force
        } else {
            $uri = [Uri]$source
            $expectedPrefix = "/$Repository/releases/download/"
            if ($uri.Scheme -ne "https" -or
                $uri.Host -ne "github.com" -or
                -not $uri.AbsolutePath.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing unexpected release asset URL: $source"
            }

            Invoke-WebRequest -UseBasicParsing -Uri $source -Headers $headers -OutFile $temp
        }

        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $temp).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "SHA-256 mismatch for '$($Asset.name)'. Expected $expected, got $actual."
        }

        Move-Item -LiteralPath $temp -Destination $Destination -Force
    } finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

$transcriptStarted = $false
$resolvedVersion = ""

try {
    $logParent = Split-Path -Parent $LogPath
    if ($logParent) {
        New-Item -ItemType Directory -Force -Path $logParent | Out-Null
    }
    try {
        Start-Transcript -LiteralPath $LogPath -Force | Out-Null
        $transcriptStarted = $true
    } catch {
        # Installation remains usable even when transcript creation is unavailable.
    }

    Write-Host "BG3 Controller Action Menu - installing latest published release"
    Write-Host "Checking GitHub Releases..."

    $selection = Resolve-LatestCamRelease -Releases (Get-ReleaseList)
    $resolvedVersion = $selection.Version

    Write-Host ("Latest release: {0}" -f $selection.Tag)
    Write-Host ("Published:      {0}" -f $selection.Release.published_at)

    if ($ResolveOnly) {
        Write-InstallStatus -State "SUCCESS" -Version $resolvedVersion -Message "Latest release resolved successfully."
        [pscustomobject]@{
            Tag = $selection.Tag
            Version = $selection.Version
            Pak = $selection.Pak.name
            Installer = $selection.Installer.name
        } | ConvertTo-Json -Depth 4
        exit 0
    }

    $releaseDir = Join-Path $CacheRoot $selection.Tag
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

    $pakPath = Join-Path $releaseDir ([string]$selection.Pak.name)
    $installerPath = Join-Path $releaseDir "install-xbox-dev.ps1"

    Write-Host ("Cache:          {0}" -f $releaseDir)
    Write-Host "Downloading and verifying current release assets..."

    Save-VerifiedReleaseAsset -Asset $selection.Pak -Destination $pakPath
    Save-VerifiedReleaseAsset -Asset $selection.Installer -Destination $installerPath

    Write-Host "SHA-256 verification passed for:"
    Write-Host ("  {0}" -f $selection.Pak.name)
    Write-Host "  install-xbox-dev.ps1"
    Write-Host ""
    Write-Host "Running the fail-closed Xbox installer..."

    & $installerPath -Apply -PackagePath $pakPath -ReportPath $ReportPath

    Write-Host ""
    Write-Host ("Installed release: {0}" -f $selection.Tag)
    Write-Host ("Diagnostic report: {0}" -f $ReportPath)

    Write-InstallStatus -State "SUCCESS" -Version $resolvedVersion -Message "Latest release installed successfully."
    exit 0
} catch {
    $message = $_.Exception.Message
    Write-InstallStatus -State "ERROR" -Version $resolvedVersion -Message $message
    Write-Error $message
    exit 1
} finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
