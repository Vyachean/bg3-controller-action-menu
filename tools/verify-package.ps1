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

$sourceLibrary = Join-Path $Root "BG3ControllerActionMenu/Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"
$packedLibrary = Join-Path $Extract "Mods/BG3ControllerActionMenu/GUI/Library/Lib_Controller.xaml"

# Copied game-owned Public paths and runtime injectors are never valid. Project-
# owned XAML under Mods/BG3ControllerActionMenu is allowed and is required once
# the self-contained migration lands.
$forbidden = @(
    "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml",
    "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml",
    "Mods/BG3ControllerActionMenu/ScriptExtender"
)

foreach ($relative in $forbidden) {
    if (Test-Path (Join-Path $Extract $relative)) {
        throw "Published package contains forbidden copied/native-loader content: $relative"
    }
}

if (-not (Test-Path -LiteralPath $sourceLibrary -PathType Leaf)) {
    throw "Self-contained controller library is missing from source."
}
if (-not (Test-Path -LiteralPath $packedLibrary -PathType Leaf)) {
    throw "Self-contained controller library is missing from the PAK."
}

[xml]$packedLibraryXml = Get-Content -Raw -LiteralPath $packedLibrary
if (-not $packedLibraryXml.DocumentElement) {
    throw "Packaged self-contained Lib_Controller.xaml has no XML document element."
}

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceLibrary).Hash
$packedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $packedLibrary).Hash
if ($sourceHash -ne $packedHash) {
    throw "Packaged self-contained Lib_Controller.xaml does not match the project-owned source."
}

$nativePayloads = @(
    Get-ChildItem -LiteralPath $Extract -File -Recurse |
        Where-Object { $_.Extension.ToLowerInvariant() -in @(".dll", ".exe", ".asi", ".so", ".dylib") }
)
if ($nativePayloads.Count -gt 0) {
    $names = ($nativePayloads | ForEach-Object { $_.FullName.Substring($Extract.Length + 1) }) -join ", "
    throw "Published package contains forbidden native executable payloads: $names"
}

Write-Host "Package verification passed: project-owned controller runtime is embedded byte-for-byte; copied Public native XAML, Script Extender and native executable payloads are absent."
