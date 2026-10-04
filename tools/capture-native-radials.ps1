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

    $foundPaths = @()
    foreach ($line in $output) {
        if ($line -notmatch "\.xaml\t") { continue }
        $parts = $line -split "\t"
        if ($parts.Count -lt 1) { continue }

        $packagedPath = $parts[0].Trim()
        if (-not $packagedPath) { continue }

        $foundPaths += $packagedPath
    }

    return [pscustomobject]@{
        Matches = @($foundPaths | Sort-Object -Unique)
        Error = $null
    }
}

function Get-XamlAttributeValue {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][string]$LocalName
    )

    foreach ($attribute in @($Node.Attributes)) {
        if ($attribute.LocalName -eq $LocalName -or $attribute.LocalName.EndsWith(".$LocalName")) {
            return $attribute.Value
        }
    }

    return $null
}

function Get-NativeRadialContract {
    param([Parameter(Mandatory = $true)][string]$Path)

    [xml]$xml = Get-Content -Raw -LiteralPath $Path
    $root = $xml.DocumentElement
    if (-not $root) {
        throw "XAML has no document element: $Path"
    }

    $allElements = @($xml.SelectNodes("//*"))

    $itemsSources = @(
        foreach ($node in $allElements) {
            $value = Get-XamlAttributeValue -Node $node -LocalName "ItemsSource"
            if ($null -ne $value) {
                [pscustomobject]@{
                    Element = $node.LocalName
                    Name = Get-XamlAttributeValue -Node $node -LocalName "Name"
                    Value = $value
                }
            }
        }
    )

    $controllerBindings = @(
        foreach ($node in $allElements) {
            $boundEvent = Get-XamlAttributeValue -Node $node -LocalName "BoundEvent"
            if (-not $boundEvent) { continue }

            [pscustomobject]@{
                Element = $node.LocalName
                Name = Get-XamlAttributeValue -Node $node -LocalName "Name"
                BoundEvent = $boundEvent
                Command = Get-XamlAttributeValue -Node $node -LocalName "Command"
                CommandParameter = Get-XamlAttributeValue -Node $node -LocalName "CommandParameter"
                EatInput = Get-XamlAttributeValue -Node $node -LocalName "EatInput"
            }
        }
    )

    $scrollBindings = @(
        foreach ($node in $allElements) {
            foreach ($attribute in @($node.Attributes)) {
                if ($attribute.LocalName -eq "ScrollToElement" -or $attribute.LocalName.EndsWith(".ScrollToElement")) {
                    [pscustomobject]@{
                        Element = $node.LocalName
                        Name = Get-XamlAttributeValue -Node $node -LocalName "Name"
                        Attribute = $attribute.Name
                        Value = $attribute.Value
                    }
                }
            }
        }
    )

    $dataContextBindings = @(
        foreach ($node in $allElements) {
            $value = Get-XamlAttributeValue -Node $node -LocalName "DataContext"
            if ($null -ne $value) {
                [pscustomobject]@{
                    Element = $node.LocalName
                    Name = Get-XamlAttributeValue -Node $node -LocalName "Name"
                    Value = $value
                }
            }
        }
    )

    $bindingAttributes = @(
        foreach ($node in $allElements) {
            foreach ($attribute in @($node.Attributes)) {
                if ($attribute.Value -like "*{Binding*") {
                    [pscustomobject]@{
                        Element = $node.LocalName
                        Name = Get-XamlAttributeValue -Node $node -LocalName "Name"
                        Attribute = $attribute.Name
                        Value = $attribute.Value
                    }
                }
            }
        }
    )

    $structureNames = @(
        "ListBox",
        "LSListBox",
        "ItemsControl",
        "PagedList",
        "PageView",
        "LSGrid",
        "Radial",
        "LSScrollViewer",
        "ScrollViewer",
        "LSInputBinding",
        "LSButton",
        "ControlTemplate",
        "DataTemplate"
    )
    $structure = [ordered]@{}
    foreach ($name in $structureNames) {
        $structure[$name] = @($allElements | Where-Object { $_.LocalName -eq $name }).Count
    }

    return [pscustomobject]@{
        FileName = [System.IO.Path]::GetFileName($Path)
        RootElement = $root.LocalName
        RootName = Get-XamlAttributeValue -Node $root -LocalName "Name"
        ContextName = Get-XamlAttributeValue -Node $root -LocalName "ContextName"
        RootDataContext = Get-XamlAttributeValue -Node $root -LocalName "DataContext"
        LsNamespace = $root.GetNamespaceOfPrefix("ls")
        Structure = [pscustomobject]$structure
        ItemsSources = $itemsSources
        ControllerBindings = $controllerBindings
        ScrollBindings = $scrollBindings
        DataContextBindings = $dataContextBindings
        BindingAttributes = $bindingAttributes
    }
}

function Get-NativeContractAnalysis {
    param(
        [Parameter(Mandatory = $true)]$Matches,
        [Parameter(Mandatory = $true)]$DuplicatePackagedPaths,
        [Parameter(Mandatory = $true)]$ScanErrors
    )

    $mainSources = @()
    $keyboardSources = @()
    $nestedSources = @()
    $acceptBindings = @()
    $cancelBindings = @()
    $focusBindings = @()
    $nestedEvidence = @()
    $materialization = @()
    $useSlotEvidence = @()

    foreach ($match in @($Matches)) {
        $contract = $match.Contract
        $sourceIdentity = [ordered]@{
            SourceType = $match.SourceType
            SourcePackage = $match.SourcePackage
            PackagedPath = $match.PackagedPath
            Sha256 = $match.Sha256
        }

        foreach ($source in @($contract.ItemsSources)) {
            $record = [pscustomobject]([ordered]@{
                SourceType = $sourceIdentity.SourceType
                SourcePackage = $sourceIdentity.SourcePackage
                PackagedPath = $sourceIdentity.PackagedPath
                Sha256 = $sourceIdentity.Sha256
                Element = $source.Element
                Name = $source.Name
                Value = $source.Value
            })

            if ($source.Value -match "(?i)KeyboardHotBars") {
                $keyboardSources += $record
            } elseif ($source.Value -match "(?i)SingleHotBar") {
                $nestedSources += $record
            } elseif ($source.Value -match "(?i)(HotBar|Radial|ControllerBar|SlotList)") {
                $mainSources += $record
            }
        }

        foreach ($binding in @($contract.ControllerBindings)) {
            $record = [pscustomobject]([ordered]@{
                SourceType = $sourceIdentity.SourceType
                SourcePackage = $sourceIdentity.SourcePackage
                PackagedPath = $sourceIdentity.PackagedPath
                Sha256 = $sourceIdentity.Sha256
                Element = $binding.Element
                Name = $binding.Name
                BoundEvent = $binding.BoundEvent
                Command = $binding.Command
                CommandParameter = $binding.CommandParameter
                EatInput = $binding.EatInput
            })

            if ($binding.BoundEvent -eq "UIAccept") {
                $acceptBindings += $record
            }
            if ($binding.BoundEvent -eq "UICancel") {
                $cancelBindings += $record
            }
            if (("$($binding.Command) $($binding.CommandParameter)") -match "(?i)UseSlotCommand") {
                $useSlotEvidence += $record
            }
        }

        foreach ($scroll in @($contract.ScrollBindings)) {
            $focusBindings += [pscustomobject]([ordered]@{
                SourceType = $sourceIdentity.SourceType
                SourcePackage = $sourceIdentity.SourcePackage
                PackagedPath = $sourceIdentity.PackagedPath
                Sha256 = $sourceIdentity.Sha256
                Element = $scroll.Element
                Name = $scroll.Name
                Attribute = $scroll.Attribute
                Value = $scroll.Value
            })
        }

        foreach ($binding in @($contract.BindingAttributes)) {
            if ($binding.Value -match "(?i)(SingleHotBar|CurrentSingleHotbarFilter|IsShowingAContainerWithVariants|IsSelectingUpcastedSpell)") {
                $nestedEvidence += [pscustomobject]([ordered]@{
                    SourceType = $sourceIdentity.SourceType
                    SourcePackage = $sourceIdentity.SourcePackage
                    PackagedPath = $sourceIdentity.PackagedPath
                    Sha256 = $sourceIdentity.Sha256
                    Element = $binding.Element
                    Name = $binding.Name
                    Attribute = $binding.Attribute
                    Value = $binding.Value
                })
            }
            if ($binding.Value -match "(?i)UseSlotCommand") {
                $useSlotEvidence += [pscustomobject]([ordered]@{
                    SourceType = $sourceIdentity.SourceType
                    SourcePackage = $sourceIdentity.SourcePackage
                    PackagedPath = $sourceIdentity.PackagedPath
                    Sha256 = $sourceIdentity.Sha256
                    Element = $binding.Element
                    Name = $binding.Name
                    BoundEvent = $null
                    Command = $binding.Value
                    CommandParameter = $null
                    EatInput = $null
                })
            }
        }

        $materialization += [pscustomobject]([ordered]@{
            SourceType = $sourceIdentity.SourceType
            SourcePackage = $sourceIdentity.SourcePackage
            PackagedPath = $sourceIdentity.PackagedPath
            Sha256 = $sourceIdentity.Sha256
            ListBox = $contract.Structure.ListBox
            LSListBox = $contract.Structure.LSListBox
            ItemsControl = $contract.Structure.ItemsControl
            PagedList = $contract.Structure.PagedList
            PageView = $contract.Structure.PageView
            LSGrid = $contract.Structure.LSGrid
            Radial = $contract.Structure.Radial
            LSScrollViewer = $contract.Structure.LSScrollViewer
            ScrollViewer = $contract.Structure.ScrollViewer
            LSInputBinding = $contract.Structure.LSInputBinding
            LSButton = $contract.Structure.LSButton
        })
    }

    $conflictingDuplicates = @(
        foreach ($duplicate in @($DuplicatePackagedPaths)) {
            $distinctHashes = @($duplicate.Copies | Select-Object -ExpandProperty Sha256 -Unique)
            if ($distinctHashes.Count -gt 1) {
                $duplicate
            }
        }
    )

    $distinctMainValues = @($mainSources | Select-Object -ExpandProperty Value -Unique)
    $captureComplete = @($ScanErrors).Count -eq 0 -and @($Matches).Count -gt 0
    $hasMainControllerSource = $mainSources.Count -gt 0
    $hasCancel = $cancelBindings.Count -gt 0
    $hasFocus = $focusBindings.Count -gt 0
    $hasNested = ($nestedSources.Count + $nestedEvidence.Count) -gt 0
    $sourceUnambiguous = $distinctMainValues.Count -eq 1 -and $conflictingDuplicates.Count -eq 0

    $blockers = @()
    if (-not $captureComplete) { $blockers += "capture-incomplete" }
    if (-not $hasMainControllerSource) { $blockers += "controller-source-not-found" }
    if (-not $sourceUnambiguous) { $blockers += "controller-source-ambiguous" }
    if (-not $hasCancel) { $blockers += "radial-cancel-not-found" }
    if (-not $hasFocus) { $blockers += "focus-scroll-not-found" }
    if (-not $hasNested) { $blockers += "nested-state-not-found" }

    return [pscustomobject]([ordered]@{
        SchemaVersion = 1
        CaptureComplete = $captureComplete
        NativeFileCount = @($Matches).Count
        DuplicatePackagedPathCount = @($DuplicatePackagedPaths).Count
        ConflictingDuplicateCount = $conflictingDuplicates.Count
        ConflictingDuplicates = $conflictingDuplicates
        MainControllerSourceCandidates = $mainSources
        KeyboardOnlySources = $keyboardSources
        NestedSources = $nestedSources
        DistinctMainControllerSourceValues = $distinctMainValues
        UIAcceptBindings = $acceptBindings
        UICancelBindings = $cancelBindings
        FocusScrollBindings = $focusBindings
        NestedStateEvidence = $nestedEvidence
        UseSlotEvidence = @($useSlotEvidence | Sort-Object PackagedPath, Element, Name, Command -Unique)
        Materialization = $materialization
        Facts = [pscustomobject]([ordered]@{
            HasMainControllerSourceCandidate = $hasMainControllerSource
            ControllerSourceUnambiguous = $sourceUnambiguous
            HasUIAccept = $acceptBindings.Count -gt 0
            HasUICancel = $hasCancel
            HasFocusScroll = $hasFocus
            HasNestedStateEvidence = $hasNested
            HasUseSlotEvidenceInRadialFiles = $useSlotEvidence.Count -gt 0
            HasKeyboardOnlySourceEvidence = $keyboardSources.Count -gt 0
        })
        ImplementationGate = [pscustomobject]([ordered]@{
            Ready = $blockers.Count -eq 0
            Blockers = $blockers
        })
    })
}

function Format-NativeContractAnalysis {
    param([Parameter(Mandatory = $true)]$Analysis)

    $lines = @()
    $lines += "BG3 native radial contract analysis"
    $lines += "Capture complete: $($Analysis.CaptureComplete)"
    $lines += "Native files: $($Analysis.NativeFileCount)"
    $lines += "Conflicting duplicate paths: $($Analysis.ConflictingDuplicateCount)"
    $lines += "Implementation gate ready: $($Analysis.ImplementationGate.Ready)"
    $lines += "Blockers: $(if (@($Analysis.ImplementationGate.Blockers).Count) { @($Analysis.ImplementationGate.Blockers) -join ', ' } else { '(none)' })"
    $lines += ""

    $lines += "=== Main controller source candidates ==="
    if (@($Analysis.MainControllerSourceCandidates).Count -eq 0) {
        $lines += "(none)"
    } else {
        foreach ($source in @($Analysis.MainControllerSourceCandidates)) {
            $lines += "[$([System.IO.Path]::GetFileName($source.SourcePackage)) :: $($source.PackagedPath) :: $($source.Element) $($source.Name)] $($source.Value)"
        }
    }
    $lines += ""

    $lines += "=== Keyboard-only sources (not valid controller substitutes) ==="
    if (@($Analysis.KeyboardOnlySources).Count -eq 0) {
        $lines += "(none)"
    } else {
        foreach ($source in @($Analysis.KeyboardOnlySources)) {
            $lines += "[$([System.IO.Path]::GetFileName($source.SourcePackage)) :: $($source.PackagedPath)] $($source.Value)"
        }
    }
    $lines += ""

    $lines += "=== Nested sources/state ==="
    foreach ($source in @($Analysis.NestedSources)) {
        $lines += "[ItemsSource :: $($source.PackagedPath)] $($source.Value)"
    }
    foreach ($binding in @($Analysis.NestedStateEvidence)) {
        $lines += "[$($binding.Attribute) :: $($binding.PackagedPath)] $($binding.Value)"
    }
    if (@($Analysis.NestedSources).Count -eq 0 -and @($Analysis.NestedStateEvidence).Count -eq 0) {
        $lines += "(none)"
    }
    $lines += ""

    $lines += "=== UIAccept ==="
    if (@($Analysis.UIAcceptBindings).Count -eq 0) {
        $lines += "(none)"
    } else {
        foreach ($binding in @($Analysis.UIAcceptBindings)) {
            $lines += "[$($binding.PackagedPath) :: $($binding.Element) $($binding.Name)] $($binding.Command) :: $($binding.CommandParameter)"
        }
    }
    $lines += ""

    $lines += "=== UICancel ==="
    if (@($Analysis.UICancelBindings).Count -eq 0) {
        $lines += "(none)"
    } else {
        foreach ($binding in @($Analysis.UICancelBindings)) {
            $lines += "[$($binding.PackagedPath) :: $($binding.Element) $($binding.Name)] $($binding.Command) :: $($binding.CommandParameter)"
        }
    }
    $lines += ""

    $lines += "=== Focus / scroll ==="
    if (@($Analysis.FocusScrollBindings).Count -eq 0) {
        $lines += "(none)"
    } else {
        foreach ($binding in @($Analysis.FocusScrollBindings)) {
            $lines += "[$($binding.PackagedPath) :: $($binding.Element) $($binding.Name)] $($binding.Attribute) = $($binding.Value)"
        }
    }
    $lines += ""

    $lines += "=== Materialization ==="
    foreach ($entry in @($Analysis.Materialization)) {
        $lines += "[$([System.IO.Path]::GetFileName($entry.SourcePackage)) :: $($entry.PackagedPath)] ListBox=$($entry.ListBox), LSListBox=$($entry.LSListBox), ItemsControl=$($entry.ItemsControl), PagedList=$($entry.PagedList), PageView=$($entry.PageView), LSGrid=$($entry.LSGrid), Radial=$($entry.Radial), LSScrollViewer=$($entry.LSScrollViewer)"
    }

    return $lines
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
$packageScan = @()

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
        Contract = Get-NativeRadialContract -Path $dest
    }
}

$pakIndex = 0
foreach ($pak in $search.Packages) {
    $pakIndex += 1
    Write-Host ("Scanning [{0}/{1}] {2}" -f $pakIndex, $search.Packages.Count, $pak.Name)

    $result = Get-PackageMatches -Divine $divine -Package $pak.FullName

    $packageScan += [pscustomobject]@{
        Name = $pak.Name
        Path = $pak.FullName
        Size = $pak.Length
        LastWriteTimeUtc = $pak.LastWriteTimeUtc.ToString("o")
        MatchCount = @($result.Matches).Count
        Matches = @($result.Matches)
        Error = $result.Error
    }

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
            Contract = Get-NativeRadialContract -Path $dest
        }
    }
}

$duplicatePackagedPaths = @(
    $manifestMatches |
        Where-Object { $_.SourceType -eq "Pak" } |
        Group-Object PackagedPath |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                PackagedPath = $_.Name
                Copies = @(
                    $_.Group | ForEach-Object {
                        [pscustomobject]@{
                            SourcePackage = $_.SourcePackage
                            Sha256 = $_.Sha256
                            ExtractedPath = $_.ExtractedPath
                        }
                    }
                )
            }
        }
)

$manifest = [ordered]@{
    SchemaVersion = 2
    CreatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    GameInstallRoot = $GameInstallRoot
    PackageName = if ($packageInfo) { $packageInfo.Name } else { $null }
    PackageFamilyName = if ($packageInfo) { $packageInfo.PackageFamilyName } else { $null }
    PackageVersion = if ($packageInfo) { "$($packageInfo.Version)" } else { $null }
    PakSearchRoot = $search.Root
    ScannedPakCount = $search.Packages.Count
    TargetExpression = $TargetExpression
    LslibVersion = $LslibVersion
    PackageScan = $packageScan
    Matches = $manifestMatches
    DuplicatePackagedPaths = $duplicatePackagedPaths
    ScanErrors = $scanErrors
}

$manifestPath = Join-Path $OutputDirectory "capture-manifest.json"
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$contractPath = Join-Path $OutputDirectory "native-contract.json"
$contractReport = [ordered]@{
    SchemaVersion = 1
    GamePackageVersion = if ($packageInfo) { "$($packageInfo.Version)" } else { $null }
    Files = @(
        $manifestMatches | ForEach-Object {
            [pscustomobject]@{
                SourceType = $_.SourceType
                SourcePackage = $_.SourcePackage
                PackagedPath = $_.PackagedPath
                Sha256 = $_.Sha256
                Contract = $_.Contract
            }
        }
    )
}
$contractReport | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $contractPath -Encoding UTF8

$analysis = Get-NativeContractAnalysis -Matches $manifestMatches -DuplicatePackagedPaths $duplicatePackagedPaths -ScanErrors $scanErrors
$analysisPath = Join-Path $OutputDirectory "native-contract-analysis.json"
$analysis | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $analysisPath -Encoding UTF8

$analysisSummaryPath = Join-Path $OutputDirectory "native-contract-analysis.txt"
Format-NativeContractAnalysis -Analysis $analysis | Set-Content -LiteralPath $analysisSummaryPath -Encoding UTF8

$summaryPath = Join-Path $OutputDirectory "capture-summary.txt"
$summary = @()
$summary += "BG3 native radial capture"
$summary += "Install root: $GameInstallRoot"
$summary += "Package version: $(if ($packageInfo) { $packageInfo.Version } else { 'explicit fixture/root' })"
$summary += "Scanned PAKs: $($search.Packages.Count)"
$summary += "Matches: $($manifestMatches.Count)"
$summary += "Scan errors: $($scanErrors.Count)"
$summary += "Duplicate packaged paths: $($duplicatePackagedPaths.Count)"
$summary += ""

if ($scanErrors.Count -gt 0) {
    $summary += "=== PAK scan errors ==="
    foreach ($errorInfo in $scanErrors) {
        $summary += "  $($errorInfo.Package): $($errorInfo.Error)"
    }
    $summary += ""
}

if ($duplicatePackagedPaths.Count -gt 0) {
    $summary += "=== Duplicate packaged paths ==="
    foreach ($duplicate in $duplicatePackagedPaths) {
        $summary += "  $($duplicate.PackagedPath)"
        foreach ($copy in @($duplicate.Copies)) {
            $summary += "    $($copy.SourcePackage) :: $($copy.Sha256)"
        }
    }
    $summary += ""
}

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
    $summary += "Root: $($match.Contract.RootElement) / $($match.Contract.RootName)"
    $summary += "ContextName: $($match.Contract.ContextName)"
    $summary += "ls namespace: $($match.Contract.LsNamespace)"
    $summary += "Structure: " + (($match.Contract.Structure.psobject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ", ")
    $summary += "ItemsSource bindings:"
    foreach ($source in @($match.Contract.ItemsSources)) {
        $summary += "  [$($source.Element) $($source.Name)] $($source.Value)"
    }
    $summary += "Controller bindings:"
    foreach ($binding in @($match.Contract.ControllerBindings)) {
        $summary += "  [$($binding.Element) $($binding.Name)] $($binding.BoundEvent) -> $($binding.Command) :: $($binding.CommandParameter)"
    }
    $summary += "Scroll/focus bindings:"
    foreach ($scroll in @($match.Contract.ScrollBindings)) {
        $summary += "  [$($scroll.Element) $($scroll.Name)] $($scroll.Attribute) = $($scroll.Value)"
    }
    $summary += ""

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
Write-Host "Scan errors: $($scanErrors.Count)"
Write-Host "Duplicate paths: $($duplicatePackagedPaths.Count)"
Write-Host "Manifest: $manifestPath"
Write-Host "Summary:  $summaryPath"
Write-Host "Contract: $contractPath"
Write-Host "Analysis: $analysisPath"
Write-Host "Gate ready: $($analysis.ImplementationGate.Ready)"
Write-Host "Archive:  $zipPath"
Write-Host ""
Write-Host "No game, profile or mod files were modified."

if ($scanErrors.Count -gt 0) {
    throw "One or more game PAKs could not be inspected. The capture report was written, but the evidence set is incomplete."
}

if ($manifestMatches.Count -eq 0) {
    throw "No *ActionRadials*.xaml files were found. The capture report was still written for diagnosis."
}
