param(
    [string]$GameInstallRoot = "",
    [string]$OutputDirectory = "",
    [string]$DivinePath = "",
    [switch]$NoDownload
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LslibVersion = "v1.20.4"
$LslibAsset = "ExportTool-$LslibVersion.zip"
$LslibSha256 = "5e02368fb8acafda9b45acba37a3f3bf507fc3d65a083a159abbeab06337190e"
$LslibUrl = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$LslibAsset"
$TargetExpression = "*ActionRadials*.xaml"

function Get-Bg3PackageInfo {
    $packages = @(
        Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3" -ErrorAction SilentlyContinue
    )

    if ($packages.Count -eq 0) {
        $packages = @(
            Get-AppxPackage -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -like "*baldur*gate*3*" -or
                    $_.PackageFamilyName -like "LarianStudiosGamesLtd.baldurssgate3_*"
                }
        )
    }

    if ($packages.Count -ne 1) {
        throw "Expected exactly one installed Xbox/App BG3 package, found $($packages.Count). Use -GameInstallRoot to override."
    }

    return $packages[0]
}

function Resolve-Divine {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "divine.exe does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $cacheBase = if ($env:LOCALAPPDATA) {
        Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\tools"
    } else {
        Join-Path $env:TEMP "BG3ControllerActionMenu\tools"
    }
    $toolDir = Join-Path $cacheBase "lslib-$LslibVersion"
    $cached = Get-ChildItem -LiteralPath $toolDir -Filter "divine.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cached) {
        return $cached.FullName
    }

    if ($NoDownload) {
        throw "LSLib $LslibVersion is not cached and -NoDownload was specified."
    }

    New-Item -ItemType Directory -Force -Path $cacheBase | Out-Null
    $zip = Join-Path $cacheBase $LslibAsset

    Write-Host "Downloading pinned LSLib $LslibVersion..."
    Invoke-WebRequest -Uri $LslibUrl -OutFile $zip

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    if ($actualHash -ne $LslibSha256) {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        throw "LSLib download hash mismatch. Expected $LslibSha256, got $actualHash."
    }

    if (Test-Path -LiteralPath $toolDir) {
        Remove-Item -LiteralPath $toolDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $toolDir -Force
    Remove-Item -LiteralPath $zip -Force

    $divine = Get-ChildItem -LiteralPath $toolDir -Filter "divine.exe" -File -Recurse |
        Select-Object -First 1
    if (-not $divine) {
        throw "divine.exe was not found after extracting pinned LSLib."
    }

    return $divine.FullName
}

function Get-PakSearchRoot {
    param([Parameter(Mandatory = $true)][string]$Root)

    foreach ($candidate in @(
        (Join-Path $Root "Data"),
        (Join-Path $Root "Content\Data"),
        $Root
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $paks = @(
                Get-ChildItem -LiteralPath $candidate -Filter "*.pak" -File -Recurse -Force -ErrorAction SilentlyContinue
            )
            if ($paks.Count -gt 0) {
                return [pscustomobject]@{
                    Root = $candidate
                    Packages = $paks
                }
            }
        }
    }

    throw "No BG3 .pak files were found under $Root."
}

function Get-PackageMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Divine,
        [Parameter(Mandatory = $true)][string]$Package
    )

    $output = @(
        & $Divine --game bg3 --action list-package --source $Package --expression $TargetExpression --loglevel error 2>&1 |
            ForEach-Object { "$_" }
    )
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        return [pscustomobject]@{
            Matches = @()
            Error = "list-package exited with code $exitCode"
        }
    }

    $matches = @()
    foreach ($line in $output) {
        if ($line -notmatch "\.xaml\t") { continue }
        $parts = $line -split "\t"
        if ($parts.Count -lt 1) { continue }

        $packagedPath = $parts[0].Trim()
        if (-not $packagedPath) { continue }

        $matches += $packagedPath
    }

    return [pscustomobject]@{
        Matches = @($matches | Sort-Object -Unique)
        Error = $null
    }
}

$packageInfo = $null
if (-not $GameInstallRoot) {
    $packageInfo = Get-Bg3PackageInfo
    $GameInstallRoot = $packageInfo.InstallLocation
}
if (-not (Test-Path -LiteralPath $GameInstallRoot -PathType Container)) {
    throw "BG3 install root does not exist: $GameInstallRoot"
}
$GameInstallRoot = (Resolve-Path -LiteralPath $GameInstallRoot).Path

if (-not $OutputDirectory) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path (Get-Location).Path "bg3-native-radial-capture-$stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path

$divine = Resolve-Divine -ExplicitPath $DivinePath
$search = Get-PakSearchRoot -Root $GameInstallRoot
$filesDir = Join-Path $OutputDirectory "files"
New-Item -ItemType Directory -Force -Path $filesDir | Out-Null

Write-Host "BG3 native radial capture"
Write-Host "Install root: $GameInstallRoot"
Write-Host "PAK root:     $($search.Root)"
Write-Host "PAKs:         $($search.Packages.Count)"
Write-Host "Mode:         read-only game inspection"
Write-Host ""

$manifestMatches = @()
$scanErrors = @()

# Capture loose files too, if the package happens to expose them outside PAKs.
$loose = @(
    Get-ChildItem -LiteralPath $search.Root -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*ActionRadials*.xaml" }
)
foreach ($file in $loose) {
    $destDir = Join-Path $filesDir "loose"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $dest = Join-Path $destDir $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $dest -Force

    $manifestMatches += [pscustomobject]@{
        SourceType = "LooseFile"
        SourcePackage = $null
        PackagedPath = $file.FullName
        ExtractedPath = $dest
        Size = (Get-Item -LiteralPath $dest).Length
        Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash.ToLowerInvariant()
    }
}

foreach ($pak in $search.Packages) {
    $result = Get-PackageMatches -Divine $divine -Package $pak.FullName
    if ($result.Error) {
        $scanErrors += [pscustomobject]@{
            Package = $pak.FullName
            Error = $result.Error
        }
        continue
    }

    foreach ($packagedPath in $result.Matches) {
        $pakDir = Join-Path $filesDir ([System.IO.Path]::GetFileNameWithoutExtension($pak.Name))
        $relative = $packagedPath -replace "/", "\"
        $dest = Join-Path $pakDir $relative
        $destParent = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $destParent | Out-Null

        & $divine --game bg3 --action extract-single-file --source $pak.FullName --destination $dest --packaged-path $packagedPath --loglevel error
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            throw "Failed to extract '$packagedPath' from '$($pak.FullName)'."
        }

        $manifestMatches += [pscustomobject]@{
            SourceType = "Pak"
            SourcePackage = $pak.FullName
            PackagedPath = $packagedPath
            ExtractedPath = $dest
            Size = (Get-Item -LiteralPath $dest).Length
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash.ToLowerInvariant()
        }
    }
}

$manifest = [ordered]@{
    SchemaVersion = 1
    CreatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    GameInstallRoot = $GameInstallRoot
    PackageName = if ($packageInfo) { $packageInfo.Name } else { $null }
    PackageFamilyName = if ($packageInfo) { $packageInfo.PackageFamilyName } else { $null }
    PackageVersion = if ($packageInfo) { "$($packageInfo.Version)" } else { $null }
    PakSearchRoot = $search.Root
    ScannedPakCount = $search.Packages.Count
    TargetExpression = $TargetExpression
    LslibVersion = $LslibVersion
    Matches = $manifestMatches
    ScanErrors = $scanErrors
}

$manifestPath = Join-Path $OutputDirectory "capture-manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$summaryPath = Join-Path $OutputDirectory "capture-summary.txt"
$summary = @()
$summary += "BG3 native radial capture"
$summary += "Install root: $GameInstallRoot"
$summary += "Package version: $(if ($packageInfo) { $packageInfo.Version } else { 'explicit fixture/root' })"
$summary += "Scanned PAKs: $($search.Packages.Count)"
$summary += "Matches: $($manifestMatches.Count)"
$summary += ""

$tokens = @(
    "ContextName",
    "ItemsSource",
    "HotBars",
    "SlotList",
    "SingleHotBar",
    "SpellsAndActions",
    "PagedList",
    "PageView",
    "ScrollToElement",
    "UIAccept",
    "UICancel",
    "UseSlotCommand",
    "ClearSingleHotbarCommand",
    "CustomEvent",
    "CloseRequestCommand"
)

foreach ($match in $manifestMatches) {
    $summary += "=== $($match.SourceType): $($match.PackagedPath) ==="
    $summary += "SHA256: $($match.Sha256)"
    $summary += "Source PAK: $($match.SourcePackage)"

    $lines = @(Get-Content -LiteralPath $match.ExtractedPath -ErrorAction SilentlyContinue)
    $interesting = @(
        $lines | Where-Object {
            $line = $_
            @($tokens | Where-Object { $line -like "*$_*" }).Count -gt 0
        } | Select-Object -First 250
    )
    if ($interesting.Count -gt 0) {
        $summary += $interesting
    } else {
        $summary += "(no selected binding/input tokens found)"
    }
    $summary += ""
}

$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$zipPath = "$OutputDirectory.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $OutputDirectory "*") -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Capture complete."
Write-Host "Matches:  $($manifestMatches.Count)"
Write-Host "Manifest: $manifestPath"
Write-Host "Summary:  $summaryPath"
Write-Host "Archive:  $zipPath"
Write-Host ""
Write-Host "No game, profile or mod files were modified."

if ($manifestMatches.Count -eq 0) {
    throw "No *ActionRadials*.xaml files were found. The capture report was still written for diagnosis."
}
