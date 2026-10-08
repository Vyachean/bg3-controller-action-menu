param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath,
    [string]$LauncherRoot,
    [ValidateSet("install", "capture")]
    [string]$TaskMode = "capture",
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

New-Item -ItemType Directory -Force -Path $PortableStateRoot | Out-Null
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
        Task = $TaskMode
    } | ConvertTo-Json
    exit 0
}

# The visual proof capture is a separate read-only release task. The operator
# keeps the same universal VBS; capture never mutates the installed .pak, saves,
# or modsettings. The install workflow below stays tested for future releases.
if ($TaskMode -eq "capture") {
    $captureStatus = Join-Path $LauncherRoot "capture-status.txt"
    $captureLog = Join-Path $LauncherRoot "capture.log"
    $captureArchive = $null
    try {
        if (-not $LauncherRoot) {
            throw "Capture mode requires the reusable launcher folder."
        }
        $releaseDir = Join-Path $CacheRoot $tag
        New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
        $captureAsset = Get-Asset -Release $release -Name "capture-self-contained-inputs.ps1"
        $capture = Join-Path $releaseDir "capture-self-contained-inputs.ps1"
        Save-Asset -Asset $captureAsset -Destination $capture

        Remove-Item -LiteralPath $captureStatus -Force -ErrorAction SilentlyContinue
        & $capture -PortableRoot $LauncherRoot

        if (-not (Test-Path -LiteralPath $captureStatus -PathType Leaf)) {
            throw "Read-only capture did not write capture-status.txt."
        }
        $captureLines = @(Get-Content -LiteralPath $captureStatus -Encoding Unicode)
        if ($captureLines.Count -lt 3 -or $captureLines[0] -ne "SUCCESS") {
            throw "Read-only capture did not report success."
        }
        $captureArchive = [string]$captureLines[2]
        if (-not $captureArchive -or -not (Test-Path -LiteralPath $captureArchive -PathType Leaf)) {
            throw "Read-only capture reported a missing ZIP archive."
        }
        # Trust the portable root, not stale helper state or an external path.
        $expectedRoot = [System.IO.Path]::GetFullPath($LauncherRoot).TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
        if (-not [System.IO.Path]::GetFullPath($captureArchive).StartsWith($expectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Capture archive path is outside the operator launcher folder."
        }

        if (Test-Path -LiteralPath $captureLog -PathType Leaf) {
            Copy-Item -LiteralPath $captureLog -Destination $LogPath -Force
        }
        [ordered]@{
            Task = "capture"
            Release = $version
            State = "SUCCESS"
            ReadOnly = $true
            Archive = $captureArchive
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
        @("SUCCESS", $version, "Read-only resource-template capture completed. ZIP: $captureArchive") |
            Set-Content -LiteralPath $StatusPath -Encoding Unicode
        $global:LASTEXITCODE = 0
        Write-Host "Read-only native resource template capture: $captureArchive"
        exit 0
    } catch {
        $failure = $_.Exception.Message
        if (Test-Path -LiteralPath $captureLog -PathType Leaf) {
            Copy-Item -LiteralPath $captureLog -Destination $LogPath -Force -ErrorAction SilentlyContinue
        }
        [ordered]@{
            Task = "capture"
            Release = $version
            State = "ERROR"
            ReadOnly = $true
            Message = $failure
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
        @("ERROR", $version, $failure) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
        "Capture entry failed: $failure" | Add-Content -LiteralPath $LogPath -Encoding UTF8
        throw
    }
}

# This milestone restores normal self-contained PAK install/update after the
# completed schema-v3 read-only capture. The operator keeps the same VBS.
# Installation is delegated to the already-tested release installer; capture
# stays available as a separate read-only development helper in each release.
$installStatus = Join-Path $PortableStateRoot "install-status.txt"
$installLog = Join-Path $PortableStateRoot "install-latest.log"
$installReport = Join-Path $PortableStateRoot "xbox-dev-environment.json"

function Write-DevStatus {
    param([string]$State, [string]$Message)
    @($State, $version, $Message) |
        Set-Content -LiteralPath $StatusPath -Encoding Unicode
}

function Write-DevReport {
    param([string]$State, [string]$Message)
    [ordered]@{
        Task = "install"
        Release = $version
        State = $State
        Message = $Message
        InstallStatus = $installStatus
        InstallLog = $installLog
        EnvironmentReport = $installReport
        ReadOnly = $false
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

try {
    $releaseDir = Join-Path $CacheRoot $tag
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
    $installerAsset = Get-Asset -Release $release -Name "install-latest.ps1"
    $installer = Join-Path $releaseDir "install-latest.ps1"
    Save-Asset -Asset $installerAsset -Destination $installer

    Remove-Item -LiteralPath $installStatus -Force -ErrorAction SilentlyContinue

    $installArgs = @{
        CacheRoot = $CacheRoot
        LogPath = $installLog
        StatusPath = $installStatus
        ReportPath = $installReport
    }
    if ($LauncherRoot) {
        $installArgs.LauncherRoot = $LauncherRoot
    }
    if ($ReleaseMetadataPath) {
        $installArgs.ReleaseMetadataPath = $ReleaseMetadataPath
    } else {
        $installArgs.ReleaseApiUrl = $ReleaseApiUrl
    }

    # .ps1 helpers run in-process. Their terminating exception and explicit
    # status are authoritative, never a stale $LASTEXITCODE.
    & $installer @installArgs

    if (-not (Test-Path -LiteralPath $installStatus -PathType Leaf)) {
        throw "The install helper did not write install-status.txt."
    }
    $installLines = @(Get-Content -LiteralPath $installStatus -Encoding Unicode)
    if ($installLines.Count -lt 2 -or $installLines[0] -ne "SUCCESS") {
        throw "The install helper did not report success."
    }
    if ($installLines[1] -ne $version) {
        throw "The install helper selected $($installLines[1]) instead of the resolved release $version."
    }

    if (Test-Path -LiteralPath $installLog -PathType Leaf) {
        $resolvedTaskLog = [System.IO.Path]::GetFullPath($LogPath)
        $resolvedInstallLog = [System.IO.Path]::GetFullPath($installLog)
        if ($resolvedTaskLog -ne $resolvedInstallLog) {
            Copy-Item -LiteralPath $installLog -Destination $LogPath -Force
        }
    }

    Write-DevReport -State "SUCCESS" -Message "Self-contained CAM PAK installation completed."
    Write-DevStatus -State "SUCCESS" -Message "CAM installed: $version"
    $global:LASTEXITCODE = 0
    Write-Host "Self-contained CAM PAK installed: $version"
    exit 0
} catch {
    $failure = $_.Exception.Message
    Write-DevReport -State "ERROR" -Message $failure
    Write-DevStatus -State "ERROR" -Message $failure
    if (Test-Path -LiteralPath $installLog -PathType Leaf) {
        $resolvedTaskLog = [System.IO.Path]::GetFullPath($LogPath)
        $resolvedInstallLog = [System.IO.Path]::GetFullPath($installLog)
        if ($resolvedTaskLog -ne $resolvedInstallLog) {
            Copy-Item -LiteralPath $installLog -Destination $LogPath -Force -ErrorAction SilentlyContinue
        }
    }
    # An early failure must not leave a stale success log from a prior run.
    "Install entry failed: $failure" | Add-Content -LiteralPath $LogPath -Encoding UTF8
    throw
}
