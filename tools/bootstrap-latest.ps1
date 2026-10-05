param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
    [string]$ReleaseApiUrl,
    [string]$ReleaseMetadataPath,
    [string]$CacheRoot,
    [string]$LogPath,
    [string]$StatusPath,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not $ReleaseApiUrl) {
    $ReleaseApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\bootstrap"
}
if (-not $LogPath) {
    $LogPath = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\install-latest.log"
}
if (-not $StatusPath) {
    $StatusPath = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\install-status.txt"
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\xbox-dev-environment.json"
}

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

$headers = @{
    "User-Agent" = "BG3ControllerActionMenu-Installer"
    "Accept" = "application/vnd.github+json"
}

$releases = if ($ReleaseMetadataPath) {
    @(Get-Content -Raw -LiteralPath $ReleaseMetadataPath | ConvertFrom-Json)
} else {
    @(Invoke-RestMethod -Uri $ReleaseApiUrl -Headers $headers)
}
$release = @(
    $releases |
        Where-Object { -not $_.draft -and $_.published_at } |
        Sort-Object { [DateTimeOffset]$_.published_at } -Descending
)[0]

if (-not $release) {
    throw "No published release found."
}

$asset = @($release.assets | Where-Object { $_.name -eq "install-latest.ps1" })[0]
if (-not $asset) {
    throw "Latest release does not contain install-latest.ps1."
}

$installer = Join-Path $CacheRoot "install-latest.ps1"
if ($ReleaseMetadataPath -and (Test-Path -LiteralPath ([string]$asset.browser_download_url))) {
    Copy-Item -LiteralPath ([string]$asset.browser_download_url) -Destination $installer -Force
} else {
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $installer
}

$installerArgs = @{
    Repository = $Repository
    ReleaseApiUrl = $ReleaseApiUrl
    LogPath = $LogPath
    StatusPath = $StatusPath
    ReportPath = $ReportPath
}
if ($ReleaseMetadataPath) {
    $installerArgs.ReleaseMetadataPath = $ReleaseMetadataPath
}
& $installer @installerArgs
exit $LASTEXITCODE
