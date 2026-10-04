param(
    [string]$Configuration = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root "BG3ControllerActionMenu"
$Build = Join-Path $Root "build"
$Tools = Join-Path $Root ".tools"
$LslibVersion = "v1.20.4"
$LslibDir = Join-Path $Tools "lslib-$LslibVersion"

if ([string]::IsNullOrWhiteSpace($Configuration)) {
    $Configuration = (Get-Content -Raw (Join-Path $Root "VERSION")).Trim()
}

if ([string]::IsNullOrWhiteSpace($Configuration)) {
    throw "Build configuration/version is empty."
}

$Pak = Join-Path $Build "BG3ControllerActionMenu-$Configuration.pak"

New-Item -ItemType Directory -Force -Path $Build | Out-Null
New-Item -ItemType Directory -Force -Path $Tools | Out-Null

$divine = Get-ChildItem -Path $LslibDir -Filter "divine.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $divine) {
    $asset = "ExportTool-$LslibVersion.zip"
    $zip = Join-Path $Tools $asset
    $url = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$asset"

    Write-Host "Downloading LSLib $LslibVersion..."
    Invoke-WebRequest -Uri $url -OutFile $zip

    if (Test-Path $LslibDir) {
        Remove-Item -Recurse -Force $LslibDir
    }
    New-Item -ItemType Directory -Force -Path $LslibDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $LslibDir -Force
    Remove-Item $zip -Force

    $divine = Get-ChildItem -Path $LslibDir -Filter "divine.exe" -Recurse | Select-Object -First 1
}

if (-not $divine) {
    throw "divine.exe not found after installing LSLib."
}

if (Test-Path $Pak) {
    Remove-Item -Force $Pak
}

Write-Host "Packing $Pak"
& $divine.FullName --game bg3 --action create-package --source $Source --destination $Pak --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "divine.exe failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $Pak)) {
    throw "Package was not created: $Pak"
}

$size = (Get-Item $Pak).Length
if ($size -le 0) {
    throw "Package is empty: $Pak"
}

Write-Host "Built $Pak ($size bytes)"
