$ErrorActionPreference = "SilentlyContinue"

$packagePattern = "LarianStudiosGamesLtd.baldurssgate3_*"
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

$roots = New-Object System.Collections.Generic.List[string]

$localPackages = Join-Path $env:LOCALAPPDATA "Packages"
if (Test-Path $localPackages) {
    Get-ChildItem $localPackages -Directory -Filter $packagePattern -Force |
        ForEach-Object { $roots.Add($_.FullName) }
}

Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $base = Join-Path $_.Root ("WpSystem\" + $sid + "\AppData\Local\Packages")
    if (Test-Path $base) {
        Get-ChildItem $base -Directory -Filter $packagePattern -Force |
            ForEach-Object { $roots.Add($_.FullName) }
    }
}

$roots = $roots | Sort-Object -Unique

if (-not $roots) {
    Write-Host "No Baldur's Gate 3 Xbox package cache was found."
    Write-Host "Launch the Xbox App version, open its Mod Manager once, exit normally, then run this script again."
    exit 1
}

foreach ($root in $roots) {
    Write-Host ""
    Write-Host "Package root:"
    Write-Host "  $root"

    $local = Join-Path $root "LocalCache\Local"
    Write-Host "Local cache:"
    Write-Host "  $local"

    $mods = Join-Path $local "Mods"
    Write-Host "Mods candidate:"
    Write-Host "  $mods"
    Write-Host ("  Exists: " + (Test-Path $mods))

    Write-Host "modsettings.lsx candidates:"
    $settings = Get-ChildItem $local -Recurse -Filter "modsettings.lsx" -File -Force -ErrorAction SilentlyContinue
    if ($settings) {
        $settings | ForEach-Object { Write-Host ("  " + $_.FullName) }
    } else {
        Write-Host "  none found"
    }
}

Write-Host ""
Write-Host "Read-only scan complete. No files were modified."
