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

$task = "capture-hotbar-resource-filter"

if ($ResolveOnly) {
    @(
        "SUCCESS",
        $version,
        "Universal development entry resolved."
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

    [pscustomobject]@{
        Tag = $tag
        Version = $version
        Task = $task
    } | ConvertTo-Json
    exit 0
}

# Current development task: capture the exact installed Patch 8 HotBar/UI inputs
# read-only. The permanent VBS remains unchanged; only this release-controlled
# task changes. After the capture is consumed, a later release can restore the
# normal install task without replacing the operator shortcut.
$releaseDir = Join-Path $CacheRoot $tag
$captureAsset = Get-Asset -Release $release -Name "capture-self-contained-inputs.ps1"
$captureScript = Join-Path $releaseDir "capture-self-contained-inputs.ps1"
Save-Asset -Asset $captureAsset -Destination $captureScript

$captureRoot = if ($LauncherRoot) {
    $LauncherRoot
} else {
    Join-Path $PortableStateRoot "capture-output"
}
New-Item -ItemType Directory -Force -Path $captureRoot | Out-Null

$captureStatus = Join-Path $captureRoot "capture-status.txt"
Remove-Item -LiteralPath $captureStatus -Force -ErrorAction SilentlyContinue

try {
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $captureScript -PortableRoot $captureRoot
    $captureExitCode = $LASTEXITCODE

    $captureLines = if (Test-Path -LiteralPath $captureStatus -PathType Leaf) {
        @(Get-Content -LiteralPath $captureStatus -Encoding Unicode)
    } else {
        @()
    }

    $captureState = if ($captureLines.Count -ge 1) { [string]$captureLines[0] } else { "" }
    $captureMessage = if ($captureLines.Count -ge 2) { [string]$captureLines[1] } else { "" }
    $archive = if ($captureLines.Count -ge 3) { [string]$captureLines[2] } else { "" }
    $captureLog = if ($captureLines.Count -ge 4) { [string]$captureLines[3] } else { "" }

    if ($captureExitCode -ne 0 -or $captureState -ne "SUCCESS") {
        if (-not $captureMessage) {
            $captureMessage = "Read-only HotBar capture failed with exit code $captureExitCode."
        }
        throw $captureMessage
    }
    if (-not $archive -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw "Capture reported success but did not produce the expected ZIP archive."
    }

    $message = "HotBar resource-filter capture completed. Upload this ZIP back to the development chat: $archive"
    @(
        "SUCCESS",
        $version,
        $message
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

    @(
        "BG3 Controller Action Menu development task",
        "Task: $task",
        "Release: $tag",
        "Capture archive: $archive",
        "Capture log: $captureLog"
    ) | Set-Content -LiteralPath $LogPath -Encoding UTF8

    [pscustomobject]@{
        Tag = $tag
        Version = $version
        Task = $task
        Archive = $archive
        CaptureStatusPath = $captureStatus
        CaptureLogPath = $captureLog
        LauncherRoot = $LauncherRoot
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

    exit 0
} catch {
    $failure = $_.Exception.Message
    @(
        "ERROR",
        $version,
        $failure
    ) | Set-Content -LiteralPath $StatusPath -Encoding Unicode

    [pscustomobject]@{
        Tag = $tag
        Version = $version
        Task = $task
        Error = $failure
        CaptureStatusPath = $captureStatus
        LauncherRoot = $LauncherRoot
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

    throw
}
