param(
    [string]$Repository = "Vyachean/bg3-controller-action-menu",
    [string]$ReleaseApiUrl,
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

$releases = @(Invoke-RestMethod -Uri $ReleaseApiUrl -Headers $headers)
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
Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $installer

& $installer -Repository $Repository -ReleaseApiUrl $ReleaseApiUrl -LogPath $LogPath -StatusPath $StatusPath -ReportPath $ReportPath
exit $LASTEXITCODE
