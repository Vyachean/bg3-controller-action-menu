param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BuildRoot = Join-Path $Root "build"
$Stage = Join-Path $BuildRoot "one-click-installer"

if (-not $OutputPath) {
    $OutputPath = Join-Path $BuildRoot "BG3ControllerActionMenu-OneClickInstaller.zip"
}

if (Test-Path -LiteralPath $Stage) {
    Remove-Item -LiteralPath $Stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

$launcher = Join-Path $Root "tools\Install-BG3ControllerActionMenu.vbs"
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Missing universal development VBS: $launcher"
}

# The operator-facing development bundle deliberately contains one executable
# shortcut only. On every launch the VBS resolves the newest published release,
# downloads dev-entry.ps1, and lets that release choose the current task.
Copy-Item -LiteralPath $launcher -Destination (Join-Path $Stage "Install-BG3ControllerActionMenu.vbs") -Force

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent) {
    New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}
if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

Compress-Archive -Path (Join-Path $Stage "Install-BG3ControllerActionMenu.vbs") -DestinationPath $OutputPath -CompressionLevel Optimal
Write-Host "Created single-file universal development launcher bundle: $OutputPath"
