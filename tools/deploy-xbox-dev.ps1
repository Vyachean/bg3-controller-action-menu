param(
    [switch]$Apply,
    [string]$PackageRoot,
    [string]$ModsPath,
    [string]$ModSettingsPath
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Version = (Get-Content -Raw (Join-Path $RepoRoot "VERSION")).Trim()
$Package = Join-Path $RepoRoot ("build\BG3ControllerActionMenu-" + $Version + ".pak")

Write-Host "Building current development package..."
& (Join-Path $RepoRoot "build.ps1") -Configuration $Version
if ($LASTEXITCODE -ne 0) {
    throw "build.ps1 failed with exit code $LASTEXITCODE"
}

$installer = Join-Path $RepoRoot "tools\install-xbox-dev.ps1"
& $installer -Apply:$Apply -PackagePath $Package -PackageRoot $PackageRoot -ModsPath $ModsPath -ModSettingsPath $ModSettingsPath
