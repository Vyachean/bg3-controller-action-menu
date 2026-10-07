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
        Task = "capture"
    } | ConvertTo-Json
    exit 0
}

# Current release task: collect one read-only native HotBar/radial evidence archive.
# The universal VBS remains unchanged. This temporary milestone deliberately does
# not install/update the CAM PAK and does not launch BG3.
$captureAsset = Get-Asset -Release $release -Name "capture-self-contained-inputs.ps1"
$releaseDir = Join-Path $CacheRoot $tag
$capture = Join-Path $releaseDir "capture-self-contained-inputs.ps1"
Save-Asset -Asset $captureAsset -Destination $capture

$captureRoot = if ($LauncherRoot) { $LauncherRoot } else { $PortableStateRoot }
New-Item -ItemType Directory -Force -Path $captureRoot | Out-Null

$captureStatus = Join-Path $captureRoot "capture-status.txt"
$captureLog = Join-Path $captureRoot "capture.log"
Remove-Item -LiteralPath $captureStatus -Force -ErrorAction SilentlyContinue

$captureArgs = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $capture,
    "-PortableRoot", $captureRoot
)

& powershell.exe @captureArgs
$captureExitCode = $LASTEXITCODE
$global:LASTEXITCODE = 0

if (Test-Path -LiteralPath $captureLog -PathType Leaf) {
    $resolvedTaskLog = [System.IO.Path]::GetFullPath($LogPath)
    $resolvedCaptureLog = [System.IO.Path]::GetFullPath($captureLog)
    if ($resolvedTaskLog -ne $resolvedCaptureLog) {
        Copy-Item -LiteralPath $captureLog -Destination $LogPath -Force
    }
}

$captureState = ""
$captureMessage = ""
$archive = ""
if (Test-Path -LiteralPath $captureStatus -PathType Leaf) {
    $captureLines = @(Get-Content -LiteralPath $captureStatus -Encoding Unicode)
    if ($captureLines.Count -ge 1) { $captureState = [string]$captureLines[0] }
    if ($captureLines.Count -ge 2) { $captureMessage = [string]$captureLines[1] }
    if ($captureLines.Count -ge 3) { $archive = [string]$captureLines[2] }
}

$report = [ordered]@{
    Task = "capture"
    Release = $version
    State = $captureState
    Archive = $archive
    CaptureStatus = $captureStatus
    CaptureLog = $captureLog
    ReadOnly = $true
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($captureExitCode -ne 0 -or $captureState -ne "SUCCESS" -or -not $archive -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    $failure = if ($captureMessage) {
        $captureMessage
    } elseif ($captureExitCode -ne 0) {
        "Read-only native capture failed with exit code $captureExitCode."
    } else {
        "Read-only native capture did not produce the expected archive."
    }

    @(
        "ERROR",
        $version,
        $failure
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
    throw $failure
}

@(
    "SUCCESS",
    $version,
    "Read-only HotBar coverage capture completed. ZIP: $archive"
) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

Write-Host "Read-only HotBar coverage capture completed: $archive"
exit 0
