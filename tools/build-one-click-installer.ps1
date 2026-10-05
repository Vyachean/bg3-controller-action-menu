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
$bootstrap = Join-Path $Root "tools\bootstrap-latest.ps1"

foreach ($path in @($launcher, $bootstrap)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing one-click installer component: $path"
    }
}

Copy-Item -LiteralPath $launcher -Destination (Join-Path $Stage "Install-BG3ControllerActionMenu.vbs") -Force
Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $Stage "bootstrap-latest.ps1") -Force

@"
BG3 Controller Action Menu - One-click installer

1. Extract this ZIP once.
2. Double-click Install-BG3ControllerActionMenu.vbs.
3. The bundled bootstrap only downloads the newest release's install-latest.ps1 and runs it.
4. The current installer downloads the files required by that release, builds the local BG3-derived PAK, and installs it.
5. Validation belongs to CI/release publication, not to the user's installation run.

Logs:
%LOCALAPPDATA%\BG3ControllerActionMenu\install-latest.log
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
