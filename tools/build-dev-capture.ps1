param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BuildRoot = Join-Path $Root "build"
$Stage = Join-Path $BuildRoot "dev-capture"

if (-not $OutputPath) {
    $OutputPath = Join-Path $BuildRoot "BG3ControllerActionMenu-DevCapture.zip"
}

if (Test-Path -LiteralPath $Stage) {
    Remove-Item -LiteralPath $Stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

$launcher = Join-Path $Root "tools\Capture-BG3ControllerArtifacts.vbs"
$capture = Join-Path $Root "tools\capture-self-contained-inputs.ps1"

foreach ($path in @($launcher, $capture)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing developer capture component: $path"
    }
}

Copy-Item -LiteralPath $launcher -Destination (Join-Path $Stage "Capture-BG3ControllerArtifacts.vbs") -Force
Copy-Item -LiteralPath $capture -Destination (Join-Path $Stage "capture-self-contained-inputs.ps1") -Force

@"
BG3 Controller Action Menu - developer UI capture

1. Extract this ZIP to any writable folder.
2. Double-click Capture-BG3ControllerArtifacts.vbs.
3. The game installation is inspected read-only.
4. All downloaded tools, logs and extracted artifacts are created beside this launcher.
5. When the capture succeeds, upload bg3-controller-action-menu-inputs-*.zip to the development chat.

This is a development evidence tool, not the mod installer.
"@ | Set-Content -LiteralPath (Join-Path $Stage "README.txt") -Encoding UTF8

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent) {
    New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}
if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $OutputPath -CompressionLevel Optimal
Write-Host "Created developer capture bundle: $OutputPath"
