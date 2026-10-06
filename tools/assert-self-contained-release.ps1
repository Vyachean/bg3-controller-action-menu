param()

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Library = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
$Launcher = Join-Path $Root "tools\Install-BG3ControllerActionMenu.vbs"
$BootstrapInstaller = Join-Path $Root "tools\bootstrap-latest.ps1"
$LatestInstaller = Join-Path $Root "tools\install-latest.ps1"
$XboxInstaller = Join-Path $Root "tools\install-xbox-dev.ps1"
$RuntimeTest = Join-Path $Root "tools\test-self-contained-runtime.ps1"

if (-not (Test-Path -LiteralPath $Library -PathType Leaf)) {
    throw @"
Release blocked: the self-contained controller runtime is not present.

Expected:
$Library

Normal installation no longer derives this file from Game.pak. Complete the
self-contained runtime migration before publishing a release.
"@
}

foreach ($path in @($Launcher, $BootstrapInstaller, $LatestInstaller, $XboxInstaller)) {
    $text = Get-Content -Raw -LiteralPath $path
    foreach ($forbidden in @(
        "native-overlay.ps1",
        "NativeOverlayPath",
        "Game.pak",
        "divine.exe",
        "LSLib",
        "--action extract-single-file",
        "--action extract-package",
        "--action create-package",
        "PatchOnlySourceXaml",
        "BG3ControllerActionMenu-native-derived.pak"
    )) {
        if ($text.Contains($forbidden)) {
            throw "Release blocked: normal installer '$path' still contains install-time build seam '$forbidden'."
        }
    }
}

[xml]$libraryXml = Get-Content -Raw -LiteralPath $Library
if (-not $libraryXml.DocumentElement) {
    throw "Release blocked: self-contained Lib_Controller.xaml has no XML document element."
}

if (-not (Test-Path -LiteralPath $RuntimeTest -PathType Leaf)) {
    throw "Release blocked: self-contained runtime contract test is missing."
}
& $RuntimeTest
if ($LASTEXITCODE -ne 0) {
    throw "Release blocked: self-contained runtime contract test failed."
}

Write-Host "Self-contained release boundary passed."
