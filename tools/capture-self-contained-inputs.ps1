param(
    [string]$PortableRoot = "",
    [string]$GameInstallRoot = "",
    [string]$DivinePath = "",
    [switch]$NoDownload
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LslibVersion = "v1.20.4"
$LslibAsset = "ExportTool-$LslibVersion.zip"
$LslibUrl = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$LslibAsset"

$TargetExpressions = @(
    "*PreloadedActionRadials*.xaml",
    "*ActionRadials*.xaml",
    "*HotBar*.xaml",
    "*DataTemplates.xaml",
    "*FocusableControls*.xaml",
    "*Tooltips*.xaml",
    "*SpellBook*.xaml",
    "*Controller.xaml",
    "*Lib_Controller.xaml"
)

if (-not $PortableRoot) {
    $PortableRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
New-Item -ItemType Directory -Force -Path $PortableRoot | Out-Null
$PortableRoot = (Resolve-Path -LiteralPath $PortableRoot).Path

$WorkRoot = Join-Path $PortableRoot "capture-work"
$ToolsRoot = Join-Path $WorkRoot "tools"
$LogPath = Join-Path $PortableRoot "capture.log"
$StatusPath = Join-Path $PortableRoot "capture-status.txt"
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ToolsRoot | Out-Null

function Write-CaptureStatus {
    param([string]$State, [string]$Message, [string]$Archive = "")
    @($State, $Message, $Archive, $LogPath) | Set-Content -LiteralPath $StatusPath -Encoding Unicode
}

function Resolve-Divine {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "divine.exe does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $toolDir = Join-Path $ToolsRoot "lslib-$LslibVersion"
    $cached = Get-ChildItem -LiteralPath $toolDir -Filter "divine.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cached) {
        return $cached.FullName
    }

    if ($NoDownload) {
        throw "LSLib $LslibVersion is not present beside the capture tool and -NoDownload was specified."
    }

    $zip = Join-Path $ToolsRoot $LslibAsset
    Invoke-WebRequest -UseBasicParsing -Uri $LslibUrl -OutFile $zip

    if (Test-Path -LiteralPath $toolDir) {
        Remove-Item -LiteralPath $toolDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $toolDir -Force
    Remove-Item -LiteralPath $zip -Force

    $divine = Get-ChildItem -LiteralPath $toolDir -Filter "divine.exe" -File -Recurse |
        Select-Object -First 1
    if (-not $divine) {
        throw "divine.exe was not found after extracting LSLib."
    }
    return $divine.FullName
}

function Get-Bg3InstallRoot {
    if ($GameInstallRoot) {
        if (-not (Test-Path -LiteralPath $GameInstallRoot -PathType Container)) {
            throw "BG3 install root does not exist: $GameInstallRoot"
        }
        return (Resolve-Path -LiteralPath $GameInstallRoot).Path
    }

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
        throw "Expected exactly one installed Xbox/App BG3 package, found $($packages.Count)."
    }
    if (-not $packages[0].InstallLocation -or -not (Test-Path -LiteralPath $packages[0].InstallLocation -PathType Container)) {
        throw "BG3 package install location is unavailable."
    }
    return (Resolve-Path -LiteralPath $packages[0].InstallLocation).Path
}

function Get-GamePak {
    param([string]$Root)

    $matches = @(
        Get-ChildItem -LiteralPath $Root -Filter "Game.pak" -File -Recurse -Force -ErrorAction SilentlyContinue
    )
    if ($matches.Count -ne 1) {
        throw "Expected exactly one Game.pak under '$Root', found $($matches.Count)."
    }
    return $matches[0]
}

function Find-PackagedPaths {
    param(
        [string]$Divine,
        [string]$Package,
        [string]$Expression
    )

    $output = @(
        & $Divine --game bg3 --action list-package --source $Package --expression $Expression --loglevel error 2>&1 |
            ForEach-Object { "$_" }
    )
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    $paths = @()
    foreach ($line in $output) {
        if ($line -notmatch "\.xaml\t") { continue }
        $parts = $line -split "\t"
        if ($parts.Count -lt 1) { continue }
        $path = $parts[0].Trim()
        if ($path) { $paths += $path }
    }
    return @($paths | Sort-Object -Unique)
}

$transcript = $false
try {
    try {
        Start-Transcript -Path $LogPath -Force | Out-Null
        $transcript = $true
    } catch {}

    Write-CaptureStatus -State "RUNNING" -Message "Inspecting BG3 read-only."

    $gameRoot = Get-Bg3InstallRoot
    $divine = Resolve-Divine -ExplicitPath $DivinePath
    $gamePak = Get-GamePak -Root $gameRoot

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outputDir = Join-Path $PortableRoot "bg3-controller-action-menu-inputs-$stamp"
    $filesDir = Join-Path $outputDir "files"
    New-Item -ItemType Directory -Force -Path $filesDir | Out-Null

    $manifest = @()
    $scanErrors = @()

    Write-Host "Inspecting Game.pak only: $($gamePak.FullName)"
    Write-Host "This avoids rescanning unrelated content PAKs."

    $matches = @()
    foreach ($expression in $TargetExpressions) {
        try {
            $matches += Find-PackagedPaths -Divine $divine -Package $gamePak.FullName -Expression $expression
        } catch {
            $scanErrors += [pscustomobject]@{
                Package = $gamePak.FullName
                Expression = $expression
                Error = $_.Exception.Message
            }
        }
    }
    $matches = @($matches | Sort-Object -Unique)

    foreach ($packagedPath in $matches) {
        $relative = $packagedPath -replace "/", "\"
        $dest = Join-Path $filesDir $relative
        $parent = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $parent | Out-Null

        & $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $dest --packaged-path $packagedPath --loglevel error
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            throw "Failed to extract '$packagedPath' from '$($gamePak.FullName)'."
        }

        $manifest += [pscustomobject]@{
            SourcePackage = $gamePak.FullName
            PackagedPath = $packagedPath
            RelativeCapturedPath = $dest.Substring($outputDir.Length).TrimStart("\")
            Size = (Get-Item -LiteralPath $dest).Length
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash.ToLowerInvariant()
        }
    }

    $essentialGroups = [ordered]@{
        PreloadedActionRadials = @($manifest | Where-Object { $_.PackagedPath -like "*PreloadedActionRadials*.xaml" })
        ActionRadials = @($manifest | Where-Object { $_.PackagedPath -like "*ActionRadials.xaml" -and $_.PackagedPath -notlike "*Preloaded*" })
        HotBar = @($manifest | Where-Object { $_.PackagedPath -like "*HotBar*.xaml" })
        DataTemplates = @($manifest | Where-Object { $_.PackagedPath -like "*DataTemplates.xaml" })
        Controller = @($manifest | Where-Object { $_.PackagedPath -like "*Controller.xaml" })
    }

    $missingEssential = @(
        foreach ($property in $essentialGroups.GetEnumerator()) {
            if (@($property.Value).Count -eq 0) { $property.Key }
        }
    )

    $package = @(Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3" -ErrorAction SilentlyContinue)[0]
    [ordered]@{
        SchemaVersion = 1
        CreatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        GameInstallRoot = $gameRoot
        GamePackageVersion = if ($package) { "$($package.Version)" } else { $null }
        GamePak = $gamePak.FullName
        ScannedPakCount = 1
        TargetExpressions = $TargetExpressions
        MatchCount = $manifest.Count
        Matches = $manifest
        ScanErrors = $scanErrors
        Note = "Read-only developer capture for building a self-contained CAM package. No game files are modified."
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDir "manifest.json") -Encoding UTF8

    @(
        "BG3 Controller Action Menu - self-contained package development capture"
        "Game install root: $gameRoot"
        "Scanned PAKs: 1 (Game.pak only)"
        "Captured XAML files: $($manifest.Count)"
        "Scan errors: $($scanErrors.Count)"
        "Missing essential groups: $(if ($missingEssential.Count) { $missingEssential -join ', ' } else { '(none)' })"
        ""
        "This capture is read-only. No BG3 files, saves, profiles, or mods were modified."
        "Upload the ZIP back to the development chat."
    ) | Set-Content -LiteralPath (Join-Path $outputDir "README.txt") -Encoding UTF8

    $summary = @(
        "BG3 Controller Action Menu - captured self-contained inputs"
        "Game package version: $(if ($package) { $package.Version } else { '(unknown)' })"
        "Game.pak: $($gamePak.FullName)"
        "Files captured: $($manifest.Count)"
        ""
        "=== Essential groups ==="
    )
    foreach ($entry in $essentialGroups.GetEnumerator()) {
        $summary += "$($entry.Key): $(@($entry.Value).Count)"
        foreach ($match in @($entry.Value)) {
            $summary += "  $($match.PackagedPath)"
            $summary += "    SHA256 $($match.Sha256)"
        }
    }
    if ($missingEssential.Count) {
        $summary += ""
        $summary += "MISSING: $($missingEssential -join ', ')"
    }
    $summary | Set-Content -LiteralPath (Join-Path $outputDir "capture-summary.txt") -Encoding UTF8

    $archive = "$outputDir.zip"
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    Compress-Archive -Path (Join-Path $outputDir "*") -DestinationPath $archive -CompressionLevel Optimal

    if ($scanErrors.Count -gt 0) {
        throw "Capture archive was created, but one or more Game.pak scans failed. Archive: $archive"
    }
    if ($missingEssential.Count -gt 0) {
        throw "Capture archive was created but is missing required UI groups: $($missingEssential -join ', '). Archive: $archive"
    }

    Write-CaptureStatus -State "SUCCESS" -Message "Capture completed." -Archive $archive
    Write-Host "Capture archive: $archive"
    exit 0
} catch {
    Write-CaptureStatus -State "ERROR" -Message $_.Exception.Message
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if ($transcript) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
