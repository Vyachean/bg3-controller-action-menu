@echo off
setlocal
title BG3 Controller Action Menu Installer

echo BG3 Controller Action Menu - install latest release
echo.
echo This launcher downloads the newest published GitHub release,
echo verifies its SHA-256 digests, and installs it into the proven Xbox App mod cache.
echo.

set "CAM_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$lines = Get-Content -LiteralPath $env:CAM_SELF; $marker = [Array]::IndexOf($lines, '#__POWERSHELL__'); if ($marker -lt 0) { throw 'PowerShell payload marker not found.' }; & ([ScriptBlock]::Create(($lines[($marker + 1)..($lines.Length - 1)] -join [Environment]::NewLine))"

set "CAM_EXIT=%ERRORLEVEL%"
echo.
if "%CAM_EXIT%"=="0" (
  echo Finished successfully.
) else (
  echo Installation failed with exit code %CAM_EXIT%.
  echo The installer is fail-closed: if the Xbox mod cache or load order was ambiguous,
  echo no BG3 files were modified.
)
echo.
if not "%CAM_ONE_CLICK_VALIDATE_ONLY%"=="1" pause
exit /b %CAM_EXIT%

#__POWERSHELL__
$ErrorActionPreference = "Stop"

if ($env:CAM_ONE_CLICK_VALIDATE_ONLY -eq "1") {
    Write-Host "One-click launcher PowerShell payload parsed successfully."
    return
}

$Repository = "Vyachean/bg3-controller-action-menu"
$ApiUrl = "https://api.github.com/repos/$Repository/releases?per_page=20"
$Headers = @{
    "User-Agent" = "BG3ControllerActionMenu-OneClickInstaller"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

function Get-SingleReleaseAsset {
    param(
        [Parameter(Mandatory = $true)]$Release,
        [Parameter(Mandatory = $true)][scriptblock]$Predicate,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $matches = @($Release.assets | Where-Object $Predicate)
    if ($matches.Count -ne 1) {
        throw "Latest release '$($Release.tag_name)' must contain exactly one $Description asset; found $($matches.Count)."
    }
    return $matches[0]
}

function Save-VerifiedReleaseAsset {
    param(
        [Parameter(Mandatory = $true)]$Asset,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not $Asset.browser_download_url) {
        throw "Release asset '$($Asset.name)' has no download URL."
    }
    $digestMatch = [regex]::Match([string]$Asset.digest, '^sha256:([0-9a-fA-F]{64})
    $temp = "$Destination.download"

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Asset.browser_download_url -Headers $Headers -OutFile $temp
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

Write-Host "Checking GitHub Releases..."
$releases = @(Invoke-RestMethod -UseBasicParsing -Uri $ApiUrl -Headers $Headers)
$release = @(
    $releases |
        Where-Object { -not $_.draft -and $_.published_at } |
        Sort-Object { [DateTimeOffset]$_.published_at } -Descending
) | Select-Object -First 1

if (-not $release) {
    throw "No published BG3 Controller Action Menu release was found."
}

$pakAsset = Get-SingleReleaseAsset -Release $release -Description "BG3ControllerActionMenu-*.pak" -Predicate {
    $_.name -like "BG3ControllerActionMenu-*.pak"
}
$installerAsset = Get-SingleReleaseAsset -Release $release -Description "install-xbox-dev.ps1" -Predicate {
    $_.name -eq "install-xbox-dev.ps1"
}

$cacheRoot = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\installer-cache"
$releaseDir = Join-Path $cacheRoot ([string]$release.tag_name)
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$pakPath = Join-Path $releaseDir ([string]$pakAsset.name)
$installerPath = Join-Path $releaseDir "install-xbox-dev.ps1"
$reportPath = Join-Path $releaseDir "xbox-dev-environment.json"

Write-Host ("Latest release: {0}" -f $release.tag_name)
Write-Host ("Published:      {0}" -f $release.published_at)
Write-Host ("Cache:          {0}" -f $releaseDir)
Write-Host ""
Write-Host "Downloading and verifying release assets..."

Save-VerifiedReleaseAsset -Asset $pakAsset -Destination $pakPath
Save-VerifiedReleaseAsset -Asset $installerAsset -Destination $installerPath

Write-Host "Verified:"
Write-Host ("  {0}" -f $pakAsset.name)
Write-Host "  install-xbox-dev.ps1"
Write-Host ""
Write-Host "Running fail-closed Xbox installer..."

& $installerPath -Apply -PackagePath $pakPath -ReportPath $reportPath

Write-Host ""
Write-Host ("Installed release: {0}" -f $release.tag_name)
Write-Host ("Diagnostic report: {0}" -f $reportPath)
)
    if (-not $digestMatch.Success) {
        throw "Release asset '$($Asset.name)' has no usable GitHub SHA-256 digest."
    }

    $expected = $digestMatch.Groups[1].Value.ToLowerInvariant()
    $temp = "$Destination.download"

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Asset.browser_download_url -Headers $Headers -OutFile $temp
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

Write-Host "Checking GitHub Releases..."
$releases = @(Invoke-RestMethod -UseBasicParsing -Uri $ApiUrl -Headers $Headers)
$release = @(
    $releases |
        Where-Object { -not $_.draft -and $_.published_at } |
        Sort-Object { [DateTimeOffset]$_.published_at } -Descending
) | Select-Object -First 1

if (-not $release) {
    throw "No published BG3 Controller Action Menu release was found."
}

$pakAsset = Get-SingleReleaseAsset -Release $release -Description "BG3ControllerActionMenu-*.pak" -Predicate {
    $_.name -like "BG3ControllerActionMenu-*.pak"
}
$installerAsset = Get-SingleReleaseAsset -Release $release -Description "install-xbox-dev.ps1" -Predicate {
    $_.name -eq "install-xbox-dev.ps1"
}

$cacheRoot = Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\installer-cache"
$releaseDir = Join-Path $cacheRoot ([string]$release.tag_name)
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$pakPath = Join-Path $releaseDir ([string]$pakAsset.name)
$installerPath = Join-Path $releaseDir "install-xbox-dev.ps1"
$reportPath = Join-Path $releaseDir "xbox-dev-environment.json"

Write-Host ("Latest release: {0}" -f $release.tag_name)
Write-Host ("Published:      {0}" -f $release.published_at)
Write-Host ("Cache:          {0}" -f $releaseDir)
Write-Host ""
Write-Host "Downloading and verifying release assets..."

Save-VerifiedReleaseAsset -Asset $pakAsset -Destination $pakPath
Save-VerifiedReleaseAsset -Asset $installerAsset -Destination $installerPath

Write-Host "Verified:"
Write-Host ("  {0}" -f $pakAsset.name)
Write-Host "  install-xbox-dev.ps1"
Write-Host ""
Write-Host "Running fail-closed Xbox installer..."

& $installerPath -Apply -PackagePath $pakPath -ReportPath $reportPath

Write-Host ""
Write-Host ("Installed release: {0}" -f $release.tag_name)
Write-Host ("Diagnostic report: {0}" -f $reportPath)
