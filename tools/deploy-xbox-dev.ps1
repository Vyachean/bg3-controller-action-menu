param(
    [switch]$SkipBuild,
    [switch]$DryRun,
    [string]$CacheRoot,
    [string]$ModSettingsPath,
    [string]$PackagePath
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ModSourceRoot = Join-Path $RepoRoot "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu"
$MetaPath = Join-Path $ModSourceRoot "meta.lsx"
$VersionPath = Join-Path $RepoRoot "VERSION"

function Get-LsxAttributeValue {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $attr = $Node.SelectSingleNode("attribute[@id='$Id']")
    if (-not $attr) {
        throw "Missing LSX attribute '$Id'."
    }
    return $attr.GetAttribute("value")
}

function Get-XboxPackageRoots {
    $packageName = "LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw"
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $found = New-Object System.Collections.Generic.List[string]

    $local = Join-Path $env:LOCALAPPDATA ("Packages\" + $packageName)
    if (Test-Path $local) {
        $found.Add((Resolve-Path $local).Path)
    }

    foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
        $packages = Join-Path $drive.Root ("WpSystem\" + $sid + "\AppData\Local\Packages")
        if (-not (Test-Path $packages)) {
            continue
        }

        Get-ChildItem -Path $packages -Directory -Filter "LarianStudiosGamesLtd.baldurssgate3_*" -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                $found.Add($_.FullName)
            }
    }

    return @($found | Sort-Object -Unique)
}

function Get-CandidateModSettings {
    param([Parameter(Mandatory = $true)][string]$Root)

    $local = Join-Path $Root "LocalCache\Local"
    if (-not (Test-Path $local)) {
        return @()
    }

    return @(
        Get-ChildItem -Path $local -Recurse -Filter "modsettings.lsx" -File -Force -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    )
}

function Ensure-ChildrenNode {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)]$Parent
    )

    $children = $Parent.SelectSingleNode("children")
    if (-not $children) {
        $children = $Document.CreateElement("children")
        [void]$Parent.AppendChild($children)
    }
    return $children
}

function New-LsxAttribute {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Type,
        [AllowEmptyString()][string]$Value
    )

    $element = $Document.CreateElement("attribute")
    $element.SetAttribute("id", $Id)
    $element.SetAttribute("type", $Type)
    $element.SetAttribute("value", $Value)
    return $element
}

function Remove-ModEntriesByUuid {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)]$Container,
        [Parameter(Mandatory = $true)][string]$ChildNodeId,
        [Parameter(Mandatory = $true)][string]$Uuid
    )

    $children = Ensure-ChildrenNode -Document $Document -Parent $Container
    $toRemove = @()

    foreach ($node in @($children.SelectNodes("node[@id='$ChildNodeId']"))) {
        $uuidNode = $node.SelectSingleNode("attribute[@id='UUID']")
        if ($uuidNode -and $uuidNode.GetAttribute("value") -eq $Uuid) {
            $toRemove += $node
        }
    }

    foreach ($node in $toRemove) {
        [void]$children.RemoveChild($node)
    }

    return $children
}

function Save-XmlUtf8 {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.IndentChars = "  "
    $settings.NewLineChars = [Environment]::NewLine
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    } finally {
        $writer.Dispose()
    }
}

if (-not (Test-Path $MetaPath)) {
    throw "Mod metadata not found: $MetaPath"
}

[xml]$meta = Get-Content -Raw $MetaPath
$moduleInfo = $meta.SelectSingleNode("//node[@id='ModuleInfo']")
if (-not $moduleInfo) {
    throw "ModuleInfo was not found in meta.lsx."
}

$mod = @{
    Folder = Get-LsxAttributeValue -Node $moduleInfo -Id "Folder"
    Name = Get-LsxAttributeValue -Node $moduleInfo -Id "Name"
    UUID = Get-LsxAttributeValue -Node $moduleInfo -Id "UUID"
    Version64 = Get-LsxAttributeValue -Node $moduleInfo -Id "Version64"
}

if (-not $PackagePath) {
    $version = (Get-Content -Raw $VersionPath).Trim()
    $PackagePath = Join-Path $RepoRoot ("build\BG3ControllerActionMenu-" + $version + ".pak")
}

if (-not $SkipBuild) {
    Write-Host "Building current package..."
    & (Join-Path $RepoRoot "build.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "build.ps1 failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path $PackagePath)) {
    throw "Package was not found: $PackagePath"
}
$PackagePath = (Resolve-Path $PackagePath).Path

if (-not $CacheRoot) {
    $roots = @(Get-XboxPackageRoots)
    if ($roots.Count -eq 0) {
        throw @"
Xbox BG3 package cache was not found.

Do this once:
1. Launch Baldur's Gate 3 from Xbox App.
2. Open the in-game Mod Manager.
3. Exit the game normally.
4. Run this command again.

If the cache is on a protected WpSystem drive, run PowerShell as Administrator.
"@
    }

    if ($roots.Count -gt 1) {
        Write-Host "Multiple Xbox BG3 package roots were found:"
        $roots | ForEach-Object { Write-Host "  $_" }
        throw "Pass the intended path with -CacheRoot to avoid modifying the wrong package cache."
    }

    $CacheRoot = $roots[0]
}

if (-not (Test-Path $CacheRoot)) {
    throw "Xbox cache root does not exist: $CacheRoot"
}
$CacheRoot = (Resolve-Path $CacheRoot).Path

$modsDir = Join-Path $CacheRoot "LocalCache\Local\Mods"

if (-not $ModSettingsPath) {
    $settingsCandidates = @(Get-CandidateModSettings -Root $CacheRoot)

    if ($settingsCandidates.Count -eq 0) {
        throw @"
No modsettings.lsx was found under:
  $(Join-Path $CacheRoot "LocalCache\Local")

Open the in-game Mod Manager once, exit BG3 normally, and rerun.
No files were changed.
"@
    }

    if ($settingsCandidates.Count -gt 1) {
        Write-Host "Found multiple modsettings.lsx files:"
        for ($i = 0; $i -lt $settingsCandidates.Count; $i++) {
            $candidate = $settingsCandidates[$i]
            Write-Host ("  [{0}] {1}  ({2})" -f $i, $candidate.FullName, $candidate.LastWriteTime)
        }
        Write-Host ""
        Write-Host "Using the most recently modified profile:"
    }

    $ModSettingsPath = $settingsCandidates[0].FullName
}

if (-not (Test-Path $ModSettingsPath)) {
    throw "modsettings.lsx does not exist: $ModSettingsPath"
}
$ModSettingsPath = (Resolve-Path $ModSettingsPath).Path

[xml]$settingsXml = Get-Content -Raw $ModSettingsPath
$settingsRoot = $settingsXml.SelectSingleNode("//region[@id='ModuleSettings']/node[@id='root']")
if (-not $settingsRoot) {
    throw "Unsupported modsettings.lsx: ModuleSettings/root was not found. No files were changed."
}

$rootChildren = Ensure-ChildrenNode -Document $settingsXml -Parent $settingsRoot
$modOrder = $settingsRoot.SelectSingleNode("children/node[@id='ModOrder']")
$modsNode = $settingsRoot.SelectSingleNode("children/node[@id='Mods']")

if (-not $modOrder -or -not $modsNode) {
    throw "Unsupported modsettings.lsx: ModOrder and/or Mods node was not found. No files were changed."
}

$modOrderChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modOrder -ChildNodeId "Module" -Uuid $mod.UUID
$modsChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modsNode -ChildNodeId "ModuleShortDesc" -Uuid $mod.UUID

$orderEntry = $settingsXml.CreateElement("node")
$orderEntry.SetAttribute("id", "Module")
[void]$orderEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type "FixedString" -Value $mod.UUID))
[void]$modOrderChildren.AppendChild($orderEntry)

$descEntry = $settingsXml.CreateElement("node")
$descEntry.SetAttribute("id", "ModuleShortDesc")
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Folder" -Type "LSString" -Value $mod.Folder))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "MD5" -Type "LSString" -Value ""))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Name" -Type "LSString" -Value $mod.Name))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type "FixedString" -Value $mod.UUID))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Version64" -Type "int64" -Value $mod.Version64))
[void]$modsChildren.AppendChild($descEntry)

$destPak = Join-Path $modsDir "BG3ControllerActionMenu.pak"

Write-Host ""
Write-Host "Xbox BG3 dev deploy"
Write-Host "  Cache root:   $CacheRoot"
Write-Host "  Mods folder:  $modsDir"
Write-Host "  Load order:   $ModSettingsPath"
Write-Host "  Source pak:   $PackagePath"
Write-Host "  Destination:  $destPak"
Write-Host "  Mod UUID:     $($mod.UUID)"

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN: no files were changed."
    exit 0
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path (Split-Path -Parent $ModSettingsPath) "BG3ControllerActionMenu-backups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$settingsBackup = Join-Path $backupDir ("modsettings." + $stamp + ".lsx")
Copy-Item -LiteralPath $ModSettingsPath -Destination $settingsBackup -Force

if (Test-Path $destPak) {
    $pakBackup = Join-Path $backupDir ("BG3ControllerActionMenu." + $stamp + ".pak")
    Copy-Item -LiteralPath $destPak -Destination $pakBackup -Force
}

New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
Copy-Item -LiteralPath $PackagePath -Destination $destPak -Force
Save-XmlUtf8 -Document $settingsXml -Path $ModSettingsPath

# Re-open the file and verify both load-order entries survived serialization.
[xml]$verify = Get-Content -Raw $ModSettingsPath
$orderUuid = $verify.SelectNodes("//node[@id='ModOrder']/children/node[@id='Module']/attribute[@id='UUID']") |
    Where-Object { $_.GetAttribute("value") -eq $mod.UUID }
$descUuid = $verify.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
    Where-Object { $_.GetAttribute("value") -eq $mod.UUID }

if (@($orderUuid).Count -ne 1 -or @($descUuid).Count -ne 1) {
    Copy-Item -LiteralPath $settingsBackup -Destination $ModSettingsPath -Force
    throw "Load-order verification failed; original modsettings.lsx was restored from backup."
}

Write-Host ""
Write-Host "Deploy complete."
Write-Host "Backup:"
Write-Host "  $settingsBackup"
Write-Host ""
Write-Host "Now launch Baldur's Gate 3 from Xbox App and open the controller action menu."
Write-Host "For development testing, do not save over an important campaign save."
