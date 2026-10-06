param()

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Library = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
$LatestInstaller = Join-Path $Root "tools\install-latest.ps1"
$XboxInstaller = Join-Path $Root "tools\install-xbox-dev.ps1"

if (-not (Test-Path -LiteralPath $Library -PathType Leaf)) {
    throw @"
Release blocked: the self-contained controller runtime is not present.

Expected:
$Library

Normal installation no longer derives this file from Game.pak. Complete the
self-contained runtime migration before publishing a release.
"@
}

foreach ($path in @($LatestInstaller, $XboxInstaller)) {
    $text = Get-Content -Raw -LiteralPath $path
    foreach ($forbidden in @(
        "native-overlay.ps1",
        "NativeOverlayPath",
        "Game.pak",
        "divine.exe",
        "--action extract-single-file",
        "--action create-package",
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

Write-Host "Self-contained release boundary passed."
