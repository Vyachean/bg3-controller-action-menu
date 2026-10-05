param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
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
$ProgressPreference = "SilentlyContinue"

if (-not $ReleaseApiUrl) {
    $ReleaseApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\bootstrap-cache"
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
    "User-Agent" = "BG3ControllerActionMenu-SelfUpdatingBootstrap"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    # Modern Windows PowerShell already negotiates a secure TLS version.
}

function Write-BootstrapStatus {
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
        if (-not (Test-Path -LiteralPath $ReleaseMetadataPath -PathType Leaf)) {
            throw "Release metadata fixture does not exist: $ReleaseMetadataPath"
        }
        return @(Get-Content -Raw -LiteralPath $ReleaseMetadataPath | ConvertFrom-Json)
    }

    return @(Invoke-RestMethod -UseBasicParsing -Uri $ReleaseApiUrl -Headers $headers)
}

function Resolve-LatestInstallerRelease {
    param([Parameter(Mandatory = $true)][object[]]$Releases)

    $published = @(
        $Releases |
            Where-Object { -not $_.draft -and $_.published_at -and $_.tag_name } |
            Sort-Object { [DateTimeOffset]$_.published_at } -Descending
    )
    if ($published.Count -eq 0) {
        throw "No published BG3 Controller Action Menu release was found."
    }

    # Never silently fall back to an older release. The newest published release
    # defines both the updater and the canonical installer contract.
    $release = $published[0]
    $tag = [string]$release.tag_name
    $version = if ($tag.StartsWith("v")) { $tag.Substring(1) } else { $tag }

    $bootstrapAssets = @($release.assets | Where-Object { $_.name -eq "bootstrap-latest.ps1" })
    $installerAssets = @($release.assets | Where-Object { $_.name -eq "install-latest.ps1" })

    if ($bootstrapAssets.Count -ne 1) {
        throw "Latest release '$tag' must contain exactly one 'bootstrap-latest.ps1' asset; found $($bootstrapAssets.Count)."
    }
    if ($installerAssets.Count -ne 1) {
        throw "Latest release '$tag' must contain exactly one 'install-latest.ps1' asset; found $($installerAssets.Count)."
    }

    return [pscustomobject]@{
        Release = $release
        Tag = $tag
        Version = $version
        Bootstrap = $bootstrapAssets[0]
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
        if ($ReleaseMetadataPath -and (Test-Path -LiteralPath $source -PathType Leaf)) {
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

    return $expected
}

$resolvedVersion = ""

try {
    $selection = Resolve-LatestInstallerRelease -Releases (Get-ReleaseList)
    $resolvedVersion = $selection.Version

    $releaseDir = Join-Path $CacheRoot $selection.Tag
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

    $cachedBootstrap = Join-Path $releaseDir "bootstrap-latest.ps1"
    $cachedInstaller = Join-Path $releaseDir "install-latest.ps1"

    $bootstrapDigest = Save-VerifiedReleaseAsset -Asset $selection.Bootstrap -Destination $cachedBootstrap
    $runningBootstrap = (Resolve-Path -LiteralPath $MyInvocation.MyCommand.Path).Path
    $runningDigest = (Get-FileHash -Algorithm SHA256 -LiteralPath $runningBootstrap).Hash.ToLowerInvariant()

    if (-not $BootstrapUpdated -and $runningDigest -ne $bootstrapDigest) {
        $forward = @{
            Repository = $Repository
            CacheRoot = $CacheRoot
            LogPath = $LogPath
            StatusPath = $StatusPath
            ReportPath = $ReportPath
            BootstrapUpdated = $true
        }
        if ($ReleaseApiUrl) { $forward.ReleaseApiUrl = $ReleaseApiUrl }
        if ($ReleaseMetadataPath) { $forward.ReleaseMetadataPath = $ReleaseMetadataPath }
        if ($ResolveOnly) { $forward.ResolveOnly = $true }

        & $cachedBootstrap @forward
        exit $LASTEXITCODE
    }

    Save-VerifiedReleaseAsset -Asset $selection.Installer -Destination $cachedInstaller | Out-Null

    if ($ResolveOnly) {
        Write-BootstrapStatus -State "SUCCESS" -Version $resolvedVersion -Message "Self-updating installer bootstrap resolved successfully."
        [pscustomobject]@{
            Tag = $selection.Tag
            Version = $selection.Version
            Bootstrap = $selection.Bootstrap.name
            Installer = $selection.Installer.name
            BootstrapUpdated = [bool]$BootstrapUpdated
        } | ConvertTo-Json -Depth 4
        exit 0
    }

    $installerArgs = @{
        Repository = $Repository
        CacheRoot = (Join-Path $stateRoot "installer-cache")
        LogPath = $LogPath
        StatusPath = $StatusPath
        ReportPath = $ReportPath
    }
    if ($ReleaseApiUrl) { $installerArgs.ReleaseApiUrl = $ReleaseApiUrl }
    if ($ReleaseMetadataPath) { $installerArgs.ReleaseMetadataPath = $ReleaseMetadataPath }

    & $cachedInstaller @installerArgs
    exit $LASTEXITCODE
} catch {
    $message = $_.Exception.Message
    Write-BootstrapStatus -State "ERROR" -Version $resolvedVersion -Message $message
    Write-Error $message
    exit 1
}
