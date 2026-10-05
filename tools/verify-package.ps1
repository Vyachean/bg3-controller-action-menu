param(
    [Parameter(Mandatory = $true)]
    [string]$Package
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Tools = Join-Path $Root ".tools"
$Extract = Join-Path $Root "build/verify-extracted"

if (-not (Test-Path $Package)) {
    throw "Package does not exist: $Package"
}
$Package = (Resolve-Path $Package).Path

$divine = Get-ChildItem -Path $Tools -Filter "divine.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $divine) {
    throw "divine.exe not found under $Tools; run build.ps1 first."
}

if (Test-Path $Extract) {
    Remove-Item -Recurse -Force $Extract
}
New-Item -ItemType Directory -Force -Path $Extract | Out-Null

Write-Host "Extracting $Package for package verification..."
& $divine.FullName --game bg3 --action extract-package --source $Package --destination $Extract --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Package extraction failed with exit code $LASTEXITCODE"
}

$meta = Join-Path $Extract "Mods/BG3ControllerActionMenu/meta.lsx"
if (-not (Test-Path $meta)) {
    throw "Packaged metadata missing: Mods/BG3ControllerActionMenu/meta.lsx"
}

$forbidden = @(
    "Mods/BG3ControllerActionMenu/GUI/Pages/CAM_ActionMenu_c.xaml",
    "Mods/BG3ControllerActionMenu/GUI/StateMachines/Controller.xaml",
    "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml",
    "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Keyboard.xaml",
    "Mods/BG3ControllerActionMenu/GUI/Library/CAM_ActionRadials.xaml",
    "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml",
    "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml",
    "Mods/BG3ControllerActionMenu/ScriptExtender"
)

foreach ($relative in $forbidden) {
    if (Test-Path (Join-Path $Extract $relative)) {
        throw "Published base package must not contain runtime/native XAML or Script Extender files: $relative"
    }
}

$unexpectedXaml = @(
    Get-ChildItem -LiteralPath $Extract -File -Recurse -Filter "*.xaml" -ErrorAction SilentlyContinue
)
if ($unexpectedXaml.Count -gt 0) {
    throw "Published base package unexpectedly contains XAML: $($unexpectedXaml[0].FullName)"
}

Write-Host "Package verification passed: release PAK is metadata/bootstrap only; no CAM replacement XAML, proprietary native XAML, or Script Extender files are embedded."
