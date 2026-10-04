param(
    [string]$PackagePath,
    [switch]$DryRun,
    [string]$CacheRoot,
    [string]$ModSettingsPath
)

$ErrorActionPreference = "Stop"

$Mod = @{
    Folder = "BG3ControllerActionMenu"
    Name = "BG3 Controller Action Menu"
    UUID = "c4be2039-13bf-4413-8d4f-2642f86d4a8e"
    Version64 = "36028797018963968"
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
            ForEach-Object { $found.Add($_.FullName) }
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

if (-not $PackagePath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $packages = @(
        Get-ChildItem -Path $scriptDir -Filter "BG3ControllerActionMenu-*.pak" -File |
            Sort-Object LastWriteTime -Descending
    )

    if ($packages.Count -eq 0) {
        throw "Put this installer in the same folder as BG3ControllerActionMenu-*.pak, or pass -PackagePath."
    }

    if ($packages.Count -gt 1) {
        Write-Host "Multiple CAM packages found; using the newest:"
        $packages | ForEach-Object { Write-Host ("  " + $_.FullName) }
    }

    $PackagePath = $packages[0].FullName
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
4. Run this installer again.

If WpSystem is protected on your machine, run PowerShell as Administrator.
"@
    }

    if ($roots.Count -gt 1) {
        Write-Host "Multiple Xbox BG3 package roots were found:"
        $roots | ForEach-Object { Write-Host "  $_" }
        throw "Rerun with -CacheRoot '<path>' so the installer cannot modify the wrong cache."
    }

    $CacheRoot = $roots[0]
}

if (-not (Test-Path $CacheRoot)) {
    throw "Xbox cache root does not exist: $CacheRoot"
}
$CacheRoot = (Resolve-Path $CacheRoot).Path
$modsDir = Join-Path $CacheRoot "LocalCache\Local\Mods"

if (-not $ModSettingsPath) {
    $candidates = @(Get-CandidateModSettings -Root $CacheRoot)

    if ($candidates.Count -eq 0) {
        throw @"
No modsettings.lsx was found under:
  $(Join-Path $CacheRoot "LocalCache\Local")

Open the in-game Mod Manager once, exit BG3 normally, and run the installer again.
No files were changed.
"@
    }

    if ($candidates.Count -gt 1) {
        Write-Host "Multiple profiles were found. Using the most recently modified modsettings.lsx:"
        $candidates | ForEach-Object {
            Write-Host ("  {0}  ({1})" -f $_.FullName, $_.LastWriteTime)
        }
    }

    $ModSettingsPath = $candidates[0].FullName
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

$modOrder = $settingsRoot.SelectSingleNode("children/node[@id='ModOrder']")
$modsNode = $settingsRoot.SelectSingleNode("children/node[@id='Mods']")
if (-not $modOrder -or -not $modsNode) {
    throw "Unsupported modsettings.lsx: ModOrder and/or Mods node was not found. No files were changed."
}

$modOrderChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modOrder -ChildNodeId "Module" -Uuid $Mod.UUID
$modsChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modsNode -ChildNodeId "ModuleShortDesc" -Uuid $Mod.UUID

$orderEntry = $settingsXml.CreateElement("node")
$orderEntry.SetAttribute("id", "Module")
[void]$orderEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type "FixedString" -Value $Mod.UUID))
[void]$modOrderChildren.AppendChild($orderEntry)

$descEntry = $settingsXml.CreateElement("node")
$descEntry.SetAttribute("id", "ModuleShortDesc")
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Folder" -Type "LSString" -Value $Mod.Folder))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "MD5" -Type "LSString" -Value ""))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Name" -Type "LSString" -Value $Mod.Name))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type "FixedString" -Value $Mod.UUID))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Version64" -Type "int64" -Value $Mod.Version64))
[void]$modsChildren.AppendChild($descEntry)

$destPak = Join-Path $modsDir "BG3ControllerActionMenu.pak"

Write-Host ""
Write-Host "BG3 Controller Action Menu - Xbox App dev installer"
Write-Host "  Cache:       $CacheRoot"
Write-Host "  Mods:        $modsDir"
Write-Host "  Load order:  $ModSettingsPath"
Write-Host "  Source:      $PackagePath"
Write-Host "  Destination: $destPak"

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

[xml]$verify = Get-Content -Raw $ModSettingsPath
$orderUuid = @(
    $verify.SelectNodes("//node[@id='ModOrder']/children/node[@id='Module']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Mod.UUID }
)
$descUuid = @(
    $verify.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Mod.UUID }
)

if ($orderUuid.Count -ne 1 -or $descUuid.Count -ne 1) {
    Copy-Item -LiteralPath $settingsBackup -Destination $ModSettingsPath -Force
    throw "Load-order verification failed; the original modsettings.lsx was restored."
}

Write-Host ""
Write-Host "Installed successfully."
Write-Host "Backup:"
Write-Host "  $settingsBackup"
Write-Host ""
Write-Host "Launch Baldur's Gate 3 from Xbox App and open the controller action menu."
Write-Host "For this experimental external-pak workflow, do not save over an important campaign save."
