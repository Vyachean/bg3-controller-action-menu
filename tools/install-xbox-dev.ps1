param(
    [switch]$Apply,
    [string]$PackagePath,
    [string]$PackageRoot,
    [string]$ModsPath,
    [string]$ModSettingsPath,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"

$Mod = @{
    Folder = "BG3ControllerActionMenu"
    Name = "BG3 Controller Action Menu"
    UUID = "c4be2039-13bf-4413-8d4f-2642f86d4a8e"
    Version64 = "36028797018963968"
}

function Normalize-Path {
    param([string]$Path)
    if (-not $Path) { return $null }
    try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path }
    catch { return [System.IO.Path]::GetFullPath($Path) }
}

function Get-Bg3AppxPackages {
    try {
        return @(
            Get-AppxPackage -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -like "*baldur*" -or
                    $_.PackageFamilyName -like "*baldur*" -or
                    $_.PackageFamilyName -like "LarianStudiosGamesLtd.baldurssgate3_*"
                }
        )
    } catch {
        return @()
    }
}

function Add-CandidateRoot {
    param(
        [Parameter(Mandatory = $true)]$List,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Source,
        $Package = $null
    )

    if (-not (Test-Path -LiteralPath $Root)) { return }

    $resolved = (Resolve-Path -LiteralPath $Root).Path
    if (@($List | Where-Object { $_.Root -eq $resolved }).Count -gt 0) { return }

    $List.Add([pscustomobject]@{
        Root = $resolved
        Source = $Source
        PackageName = if ($Package) { $Package.Name } else { $null }
        PackageFamilyName = if ($Package) { $Package.PackageFamilyName } else { Split-Path -Leaf $resolved }
        Version = if ($Package) { [string]$Package.Version } else { $null }
        InstallLocation = if ($Package) { [string]$Package.InstallLocation } else { $null }
    })
}

function Find-PackageRoots {
    param([string]$ExplicitRoot)

    $roots = New-Object System.Collections.Generic.List[object]

    if ($ExplicitRoot) {
        if (-not (Test-Path -LiteralPath $ExplicitRoot)) {
            throw "Explicit -PackageRoot does not exist: $ExplicitRoot"
        }
        Add-CandidateRoot -List $roots -Root $ExplicitRoot -Source "Explicit"
        return @($roots | ForEach-Object { $_ })
    }

    $packages = @(Get-Bg3AppxPackages)
    foreach ($package in $packages) {
        if ($package.PackageFamilyName) {
            $localRoot = Join-Path $env:LOCALAPPDATA ("Packages\" + $package.PackageFamilyName)
            Add-CandidateRoot -List $roots -Root $localRoot -Source "LocalAppDataPackages" -Package $package
        }
    }

    # Package identity lookup is useful but not required for read-only discovery.
    # Enumerate package-data directories as an independent fallback because GDK /
    # Gaming Services registration can differ between Windows builds.
    $localPackagesRoot = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path -LiteralPath $localPackagesRoot) {
        Get-ChildItem -LiteralPath $localPackagesRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "*baldur*" -or
                $_.Name -like "LarianStudiosGamesLtd.baldurssgate3_*"
            } |
            ForEach-Object {
                Add-CandidateRoot -List $roots -Root $_.FullName -Source "LocalAppDataEnumeration"
            }
    }

    # Some Xbox/Gaming Services configurations expose package data through
    # WpSystem on the selected game drive. This is a fallback, not an assumed path.
    try {
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            $packagesRoot = Join-Path $drive.Root ("WpSystem\" + $sid + "\AppData\Local\Packages")
            if (-not (Test-Path -LiteralPath $packagesRoot)) { continue }

            Get-ChildItem -LiteralPath $packagesRoot -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -like "*baldur*" -or
                    $_.Name -like "LarianStudiosGamesLtd.baldurssgate3_*"
                } |
                ForEach-Object {
                    Add-CandidateRoot -List $roots -Root $_.FullName -Source "WpSystemFallback"
                }
        }
    } catch {
        # Discovery remains useful even when WpSystem is inaccessible.
    }

    return @($roots | ForEach-Object { $_ })
}

function Get-LsxAttributeInfo {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $attribute = $Node.SelectSingleNode("attribute[@id='$Id']")
    if (-not $attribute) { return $null }

    return [pscustomobject]@{
        Type = $attribute.GetAttribute("type")
        Value = $attribute.GetAttribute("value")
    }
}

function Get-XmlShapeSummary {
    param([Parameter(Mandatory = $true)][xml]$Document)

    $documentElement = $Document.DocumentElement
    $regions = @($Document.SelectNodes("//*[local-name()='region']"))
    $nodes = @($Document.SelectNodes("//*[local-name()='node']"))

    return [pscustomobject]@{
        DocumentElement = if ($documentElement) { $documentElement.LocalName } else { $null }
        NamespaceUri = if ($documentElement) { $documentElement.NamespaceURI } else { $null }
        RegionIds = @(
            $regions |
                ForEach-Object { $_.GetAttribute("id") } |
                Where-Object { $_ } |
                Select-Object -Unique -First 20
        )
        NodeIds = @(
            $nodes |
                ForEach-Object { $_.GetAttribute("id") } |
                Where-Object { $_ } |
                Select-Object -Unique -First 40
        )
        RegionCount = $regions.Count
        NodeCount = $nodes.Count
    }
}

function Test-ModSettingsShape {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        [xml]$xml = Get-Content -Raw -LiteralPath $Path
        $shapeSummary = Get-XmlShapeSummary -Document $xml
        $root = $xml.SelectSingleNode("//region[@id='ModuleSettings']/node[@id='root']")
        $order = if ($root) { $root.SelectSingleNode("children/node[@id='ModOrder']") } else { $null }
        $mods = if ($root) { $root.SelectSingleNode("children/node[@id='Mods']") } else { $null }

        # Current BG3 Mod Manager generates ModuleSettings/root/Mods only.
        # Older layouts may also contain ModOrder, so support it when present
        # without requiring it for the Xbox cached profile.
        $validShape = [bool]($root -and $mods)
        $layout = if ($order) { "ModsAndModOrder" } else { "ModsOnly" }

        if (-not $validShape) {
            return [pscustomobject]@{
                Valid = $false
                Layout = $null
                WriteSchemaReady = $false
                WriteSchema = $null
                ShapeSummary = $shapeSummary
                Error = "Missing ModuleSettings/root/Mods structure."
            }
        }

        # Mirror attribute types from an already-active mod in this exact profile.
        # This avoids hard-coding LSX serialization details.
        $schemas = @()
        foreach ($desc in @($mods.SelectNodes("children/node[@id='ModuleShortDesc']"))) {
            $uuid = Get-LsxAttributeInfo -Node $desc -Id "UUID"
            if (-not $uuid -or -not $uuid.Value -or $uuid.Value -eq $Mod.UUID) { continue }

            $folder = Get-LsxAttributeInfo -Node $desc -Id "Folder"
            $md5 = Get-LsxAttributeInfo -Node $desc -Id "MD5"
            $name = Get-LsxAttributeInfo -Node $desc -Id "Name"
            $version64 = Get-LsxAttributeInfo -Node $desc -Id "Version64"
            $publishHandle = Get-LsxAttributeInfo -Node $desc -Id "PublishHandle"
            $orderUuid = $null

            if ($order) {
                $matchingOrder = @()
                foreach ($module in @($order.SelectNodes("children/node[@id='Module']"))) {
                    $candidateUuid = Get-LsxAttributeInfo -Node $module -Id "UUID"
                    if ($candidateUuid -and $candidateUuid.Value -eq $uuid.Value) {
                        $matchingOrder += $module
                    }
                }
                if ($matchingOrder.Count -ne 1) { continue }
                $orderUuid = Get-LsxAttributeInfo -Node $matchingOrder[0] -Id "UUID"
            }

            $required = @($folder, $md5, $name, $uuid, $version64)
            if ($order) { $required += $orderUuid }
            if (@($required | Where-Object { -not $_ -or -not $_.Type }).Count -gt 0) { continue }
            if ($publishHandle -and -not $publishHandle.Type) { continue }

            $schema = [pscustomobject]@{
                Layout = $layout
                ModOrderUuidType = if ($orderUuid) { $orderUuid.Type } else { $null }
                FolderType = $folder.Type
                Md5Type = $md5.Type
                NameType = $name.Type
                ModsUuidType = $uuid.Type
                Version64Type = $version64.Type
                HasPublishHandle = [bool]$publishHandle
                PublishHandleType = if ($publishHandle) { $publishHandle.Type } else { $null }
            }
            $schema | Add-Member -NotePropertyName Signature -NotePropertyValue (
                "{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}" -f
                    $schema.Layout,
                    $schema.ModOrderUuidType,
                    $schema.FolderType,
                    $schema.Md5Type,
                    $schema.NameType,
                    $schema.ModsUuidType,
                    $schema.Version64Type,
                    $schema.HasPublishHandle,
                    $schema.PublishHandleType
            )
            $schemas += $schema
        }

        $schemaGroups = @($schemas | Group-Object Signature)
        if ($schemaGroups.Count -ne 1) {
            return [pscustomobject]@{
                Valid = $true
                Layout = $layout
                WriteSchemaReady = $false
                WriteSchema = $null
                ShapeSummary = $shapeSummary
                Error = if ($schemaGroups.Count -eq 0) {
                    "No active non-CAM mod provides a reusable ModuleShortDesc schema."
                } else {
                    "Active mods use multiple LSX schemas; automatic write is intentionally disabled."
                }
            }
        }

        return [pscustomobject]@{
            Valid = $true
            Layout = $layout
            WriteSchemaReady = $true
            WriteSchema = $schemas[0]
            ShapeSummary = $shapeSummary
            Error = $null
        }
    } catch {
        return [pscustomobject]@{
            Valid = $false
            Layout = $null
            WriteSchemaReady = $false
            WriteSchema = $null
            ShapeSummary = $null
            Error = $_.Exception.Message
        }
    }
}

function Find-Evidence {
    param(
        [Parameter(Mandatory = $true)]$RootInfo,
        [string]$ExplicitModsPath,
        [string]$ExplicitModSettingsPath
    )

    $root = $RootInfo.Root
    $localCacheLocal = Join-Path $root "LocalCache\Local"

    $modsCandidates = @()
    if ($ExplicitModsPath) {
        if (Test-Path -LiteralPath $ExplicitModsPath) {
            $modsCandidates = @((Get-Item -LiteralPath $ExplicitModsPath))
        }
    } elseif (Test-Path -LiteralPath $localCacheLocal) {
        $exact = Join-Path $localCacheLocal "Mods"
        if (Test-Path -LiteralPath $exact) {
            $modsCandidates += Get-Item -LiteralPath $exact
        }

        $modsCandidates += @(
            Get-ChildItem -LiteralPath $localCacheLocal -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq "Mods" }
        )
    }

    $modsCandidates = @(
        $modsCandidates |
            Group-Object FullName |
            ForEach-Object { $_.Group[0] }
    )

    $settingsCandidates = @()
    if ($ExplicitModSettingsPath) {
        if (Test-Path -LiteralPath $ExplicitModSettingsPath) {
            $settingsCandidates = @((Get-Item -LiteralPath $ExplicitModSettingsPath))
        }
    } elseif (Test-Path -LiteralPath $root) {
        # Xbox active profile orders live under a PlayerProfiles directory.
        # Files named modsettings.lsx inside the Mods cache are mod/package data,
        # not the signed-in profile order, even when they have a similar XML shape.
        foreach ($file in @(
            Get-ChildItem -LiteralPath $root -File -Recurse -Force -Filter "modsettings.lsx" -ErrorAction SilentlyContinue
        )) {
            $fullPath = [System.IO.Path]::GetFullPath($file.FullName)
            $underMods = $false
            foreach ($modsDir in $modsCandidates) {
                $modsPrefix = [System.IO.Path]::GetFullPath($modsDir.FullName).TrimEnd("\") + "\"
                if ($fullPath.StartsWith($modsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $underMods = $true
                    break
                }
            }

            if (-not $underMods -and $fullPath -match '[\\/]PlayerProfiles[\\/]') {
                $settingsCandidates += $file
            }
        }
    }

    $modsInfo = @()
    foreach ($dir in $modsCandidates) {
        $paks = @(
            Get-ChildItem -LiteralPath $dir.FullName -File -Filter "*.pak" -Force -ErrorAction SilentlyContinue
        )
        $modsInfo += [pscustomobject]@{
            Path = $dir.FullName
            PakCount = $paks.Count
            PakNames = @($paks | Select-Object -First 20 -ExpandProperty Name)
        }
    }

    $settingsInfo = @()
    foreach ($file in $settingsCandidates) {
        $shape = Test-ModSettingsShape -Path $file.FullName
        $settingsInfo += [pscustomobject]@{
            Path = $file.FullName
            LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString("o")
            ValidShape = $shape.Valid
            Layout = $shape.Layout
            WriteSchemaReady = $shape.WriteSchemaReady
            WriteSchema = $shape.WriteSchema
            ShapeSummary = $shape.ShapeSummary
            Error = $shape.Error
        }
    }

    $validShapeSettings = @($settingsInfo | Where-Object { $_.ValidShape })
    $writableSettings = @($settingsInfo | Where-Object { $_.ValidShape -and $_.WriteSchemaReady })
    $modsWithPak = @($modsInfo | Where-Object { $_.PakCount -gt 0 })

    # Require one real Mods cache and one writable signed-in profile order.
    $ready =
        (Test-Path -LiteralPath $localCacheLocal) -and
        $modsInfo.Count -eq 1 -and
        $modsWithPak.Count -eq 1 -and
        $writableSettings.Count -eq 1

    return [pscustomobject]@{
        Root = $root
        Source = $RootInfo.Source
        PackageName = $RootInfo.PackageName
        PackageFamilyName = $RootInfo.PackageFamilyName
        PackageVersion = $RootInfo.Version
        InstallLocation = $RootInfo.InstallLocation
        LocalCacheLocal = $localCacheLocal
        Mods = $modsInfo
        ModSettings = $settingsInfo
        SelectedModSettings = if ($writableSettings.Count -eq 1) { $writableSettings[0] } else { $null }
        ReadyForApply = $ready
        Evidence = @(
            if (Test-Path -LiteralPath $localCacheLocal) { "LocalCacheLocalExists" }
            if ($modsInfo.Count -gt 0) { "ModsDirectoryFound" }
            if ($modsWithPak.Count -gt 0) { "ExistingPakFound" }
            if ($validShapeSettings.Count -gt 0) { "ValidProfileModSettingsFound" }
            if ($writableSettings.Count -gt 0) { "ReusableModSettingsSchemaFound" }
        )
    }
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
    foreach ($node in @($children.SelectNodes("node[@id='$ChildNodeId']"))) {
        $uuidNode = $node.SelectSingleNode("attribute[@id='UUID']")
        if ($uuidNode -and $uuidNode.GetAttribute("value") -eq $Uuid) {
            [void]$children.RemoveChild($node)
        }
    }
    return $children
}

function Write-XmlAtomically {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $temp = "$Path.cam-new"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($temp, $Document.OuterXml, $encoding)

    # Validate the serialized file before replacing the real load order.
    [xml]$null = Get-Content -Raw -LiteralPath $temp
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ReportPath) {
    $ReportPath = Join-Path $scriptDir "xbox-dev-environment.json"
}

$roots = @(Find-PackageRoots -ExplicitRoot $PackageRoot)
$appx = @(Get-Bg3AppxPackages)

$report = [ordered]@{
    GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
    Mode = if ($Apply) { "ApplyRequested" } else { "DiscoveryOnly" }
    AppxPackages = @(
        $appx | ForEach-Object {
            [ordered]@{
                Name = $_.Name
                PackageFamilyName = $_.PackageFamilyName
                Version = [string]$_.Version
                InstallLocation = [string]$_.InstallLocation
            }
        }
    )
    Roots = @()
    Selected = $null
    ReadyForApply = $false
    Notes = @()
}

foreach ($root in $roots) {
    $report.Roots += Find-Evidence -RootInfo $root -ExplicitModsPath $ModsPath -ExplicitModSettingsPath $ModSettingsPath
}

$readyRoots = @($report.Roots | Where-Object { $_.ReadyForApply })
if ($readyRoots.Count -eq 1) {
    $report.Selected = $readyRoots[0]
    $report.ReadyForApply = $true
} elseif ($readyRoots.Count -gt 1) {
    $report.Notes += "Multiple independently plausible Xbox mod caches were found; automatic write is intentionally disabled."
} elseif ($roots.Count -eq 0) {
    $report.Notes += "No BG3 Xbox package-data root was found."
} else {
    $report.Notes += "No candidate has enough ground-truth evidence for a safe automatic write."
}

$reportDir = Split-Path -Parent $ReportPath
if ($reportDir) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host ""
Write-Host "BG3 Controller Action Menu - Xbox App environment check"
Write-Host "Mode: " $report.Mode
Write-Host "Report: $ReportPath"
Write-Host ""

if ($report.AppxPackages.Count -gt 0) {
    Write-Host "Detected BG3 package identities:"
    foreach ($package in $report.AppxPackages) {
        Write-Host ("  Name: {0}" -f $package.Name)
        Write-Host ("  PFN:  {0}" -f $package.PackageFamilyName)
        Write-Host ("  Ver:  {0}" -f $package.Version)
        Write-Host ("  Game: {0}" -f $package.InstallLocation)
    }
    Write-Host ""
}

if ($report.Roots.Count -eq 0) {
    Write-Host "No Xbox package-data root found."
    Write-Host ""
    Write-Host "When you have access to the PC:"
    Write-Host "1. Launch BG3 from Xbox App."
    Write-Host "2. Install one small mod through BG3's built-in Mod Manager."
    Write-Host "3. Exit BG3 normally."
    Write-Host "4. Run this script again with no parameters."
    return
}

foreach ($candidate in $report.Roots) {
    Write-Host ("Candidate [{0}]" -f $candidate.Source)
    Write-Host ("  Root:        {0}" -f $candidate.Root)
    Write-Host ("  Local cache: {0}" -f $candidate.LocalCacheLocal)
    foreach ($mods in $candidate.Mods) {
        Write-Host ("  Mods:        {0}" -f $mods.Path)
        Write-Host ("    PAKs:      {0}" -f $mods.PakCount)
    }
    foreach ($settings in $candidate.ModSettings) {
        Write-Host ("  Settings candidate: {0}" -f $settings.Path)
        Write-Host ("    Valid order:       {0}" -f $settings.ValidShape)
        Write-Host ("    Writable schema:   {0}" -f $settings.WriteSchemaReady)
        if ($settings.ShapeSummary) {
            Write-Host ("    XML root:          {0}" -f $settings.ShapeSummary.DocumentElement)
            Write-Host ("    Namespace:         {0}" -f $settings.ShapeSummary.NamespaceUri)
            Write-Host ("    Regions:           {0}" -f ($settings.ShapeSummary.RegionIds -join ", "))
            Write-Host ("    Nodes:             {0}" -f ($settings.ShapeSummary.NodeIds -join ", "))
        }
    }
    Write-Host ("  Safe target: {0}" -f $candidate.ReadyForApply)
    Write-Host ""
}

if (-not $Apply) {
    if ($report.ReadyForApply) {
        Write-Host "A unique, evidence-backed Xbox mod target was found."
        Write-Host "Nothing was changed."
        Write-Host ""
        Write-Host "To install the mod, rerun:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\install-xbox-dev.ps1 -Apply"
    } else {
        Write-Host "Nothing was changed."
        Write-Host ""
        if (@($report.Roots | ForEach-Object { $_.Mods } | Where-Object { $_.PakCount -gt 0 }).Count -gt 0) {
            Write-Host "Existing Xbox mods were found, but no unique writable active load order was proven."
            Write-Host "Do not install another mod just for discovery; use xbox-dev-environment.json for diagnosis."
        } else {
            Write-Host "No existing Xbox mod PAKs were found."
            Write-Host "Install one small mod through the in-game Mod Manager, exit BG3, then rerun."
        }
    }
    return
}

if (-not $report.ReadyForApply) {
    throw @"
Refusing to modify Xbox data: no unique evidence-backed target exists.

No files were changed by this run.
Use the discovery report above. If Xbox mods already exist, do not install another one
just for discovery; the report is the evidence needed to diagnose the remaining path/order issue.
"@
}

if (-not $PackagePath) {
    $packages = @(
        Get-ChildItem -LiteralPath $scriptDir -File -Filter "BG3ControllerActionMenu-*.pak" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    )
    if ($packages.Count -ne 1) {
        throw "Apply requires exactly one BG3ControllerActionMenu-*.pak next to the script, or an explicit -PackagePath."
    }
    $PackagePath = $packages[0].FullName
}

if (-not (Test-Path -LiteralPath $PackagePath)) {
    throw "Package does not exist: $PackagePath"
}
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path

$target = $report.Selected
$targetMods = $target.Mods[0].Path
$targetSettings = $target.SelectedModSettings.Path
$schema = $target.SelectedModSettings.WriteSchema
if (-not $schema) {
    throw "Refusing to modify Xbox data: no reusable LSX schema was proven from an existing active mod."
}
$destPak = Join-Path $targetMods "BG3ControllerActionMenu.pak"

[xml]$settingsXml = Get-Content -Raw -LiteralPath $targetSettings
$settingsRoot = $settingsXml.SelectSingleNode("//region[@id='ModuleSettings']/node[@id='root']")
$modOrder = $settingsRoot.SelectSingleNode("children/node[@id='ModOrder']")
$modsNode = $settingsRoot.SelectSingleNode("children/node[@id='Mods']")

$modOrderChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modOrder -ChildNodeId "Module" -Uuid $Mod.UUID
$modsChildren = Remove-ModEntriesByUuid -Document $settingsXml -Container $modsNode -ChildNodeId "ModuleShortDesc" -Uuid $Mod.UUID

$orderEntry = $settingsXml.CreateElement("node")
$orderEntry.SetAttribute("id", "Module")
[void]$orderEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type $schema.ModOrderUuidType -Value $Mod.UUID))
[void]$modOrderChildren.AppendChild($orderEntry)

$descEntry = $settingsXml.CreateElement("node")
$descEntry.SetAttribute("id", "ModuleShortDesc")
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Folder" -Type $schema.FolderType -Value $Mod.Folder))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "MD5" -Type $schema.Md5Type -Value ""))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Name" -Type $schema.NameType -Value $Mod.Name))
if ($schema.HasPublishHandle) {
    [void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "PublishHandle" -Type $schema.PublishHandleType -Value "0"))
}
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "UUID" -Type $schema.ModsUuidType -Value $Mod.UUID))
[void]$descEntry.AppendChild((New-LsxAttribute -Document $settingsXml -Id "Version64" -Type $schema.Version64Type -Value $Mod.Version64))
[void]$modsChildren.AppendChild($descEntry)

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path (Split-Path -Parent $targetSettings) "BG3ControllerActionMenu-backups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$settingsBackup = Join-Path $backupDir ("modsettings." + $stamp + ".lsx")
Copy-Item -LiteralPath $targetSettings -Destination $settingsBackup -Force

if (Test-Path -LiteralPath $destPak) {
    Copy-Item -LiteralPath $destPak -Destination (Join-Path $backupDir ("BG3ControllerActionMenu." + $stamp + ".pak")) -Force
}

try {
    Copy-Item -LiteralPath $PackagePath -Destination $destPak -Force
    Write-XmlAtomically -Document $settingsXml -Path $targetSettings

    [xml]$verify = Get-Content -Raw -LiteralPath $targetSettings
    $orderUuid = @(
        $verify.SelectNodes("//node[@id='ModOrder']/children/node[@id='Module']/attribute[@id='UUID']") |
            Where-Object { $_.GetAttribute("value") -eq $Mod.UUID }
    )
    $descUuid = @(
        $verify.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
            Where-Object { $_.GetAttribute("value") -eq $Mod.UUID }
    )

    if ($orderUuid.Count -ne 1 -or $descUuid.Count -ne 1) {
        throw "Written load order does not contain exactly one CAM entry in both required sections."
    }
} catch {
    Copy-Item -LiteralPath $settingsBackup -Destination $targetSettings -Force
    throw "Install verification failed and modsettings.lsx was restored: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Installed successfully into the evidence-backed Xbox mod cache."
Write-Host "  PAK:        $destPak"
Write-Host "  Load order: $targetSettings"
Write-Host "  Backup:     $settingsBackup"
Write-Host ""
Write-Host "Launch BG3 normally from Xbox App and test on a disposable/pre-mod save first."
