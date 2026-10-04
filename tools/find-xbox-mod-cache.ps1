param(
    [string]$PackageRoot,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Installer = Join-Path $Root "tools\install-xbox-dev.ps1"

Write-Host "Running read-only Xbox BG3 environment discovery..."
& $Installer -PackageRoot $PackageRoot -ReportPath $ReportPath
