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
$bootstrap = Join-Path $Root "tools\install-latest.ps1"

foreach ($path in @($launcher, $bootstrap)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing one-click installer component: $path"
    }
}

Copy-Item -LiteralPath $launcher -Destination (Join-Path $Stage "Install-BG3ControllerActionMenu.vbs") -Force
Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $Stage "install-latest.ps1") -Force

@"
BG3 Controller Action Menu - One-click installer

1. Extract this ZIP once.
2. Double-click Install-BG3ControllerActionMenu.vbs.
3. No PowerShell/console window is shown.
4. The launcher always selects the newest published GitHub release, including prereleases.
5. It downloads the current base PAK, fail-closed Xbox installer, and native-overlay builder and verifies all GitHub SHA-256 digests.
6. On your PC it reads the exact installed BG3 Game.pak, patches only the radial presentation locally, and builds the installable PAK. Native game XAML is never shipped in the GitHub release.

One-time prerequisite:
BG3's built-in Mod Manager must already have at least one enabled mod so the installer can prove the Xbox Mods cache and reuse the real modsettings.lsx schema.

Logs and diagnostics:
%LOCALAPPDATA%\BG3ControllerActionMenu\install-latest.log
%LOCALAPPDATA%\BG3ControllerActionMenu\xbox-dev-environment.json
"@ | Set-Content -LiteralPath (Join-Path $Stage "README.txt") -Encoding UTF8

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent) {
    New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}
if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $OutputPath -CompressionLevel Optimal
Write-Host "Created one-click installer: $OutputPath"
