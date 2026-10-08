param(
    [string]$PortableRoot = "",
    [string]$GameInstallRoot = "",
    [string]$DivinePath = "",
    [switch]$NoDownload,
    [switch]$CoverageSelfTest
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
    # Keyboard/controller dictionaries were missing from schema-v3 (0.0.91) proof.
    # Capture both mode-specific styles and the resource template dictionary.
    "*DataTemplates*.xaml",
    "*ActionResourceTemplates*.xaml",
    "*Libs_*.xaml",
    "*Resource*.xaml",
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


function Get-XamlAttributeFromTag {
    param(
        [string]$Tag,
        [string]$AttributeName
    )

    $pattern = [regex]::Escape($AttributeName) + '="([^"]*)"'
    $match = [regex]::Match($Tag, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Get-XamlElementNameFromTag {
    param([string]$Tag)

    $match = [regex]::Match($Tag, '^<\s*([^\s>/]+)')
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Get-HotBarCoverageReport {
    param(
        [object[]]$Documents,
        [string]$HotBarPath
    )

    $loadedDocuments = @(
        foreach ($document in @($Documents)) {
            if (-not $document.CapturedPath -or -not (Test-Path -LiteralPath $document.CapturedPath -PathType Leaf)) {
                continue
            }

            [pscustomobject]@{
                PackagedPath = [string]$document.PackagedPath
                CapturedPath = [string]$document.CapturedPath
                Text = Get-Content -Raw -LiteralPath $document.CapturedPath
            }
        }
    )

    $commandNames = @(
        "SetCurrentShownDeckCommand",
        "FilterCantripsCommand",
        "FilterActionResourceCommand"
    )
    $commandProbes = @(
        foreach ($commandName in $commandNames) {
            $matches = @(
                foreach ($document in $loadedDocuments) {
                    $pattern = '<[^>]*Command="\{Binding [^"]*' + [regex]::Escape($commandName) + '[^"]*\}"[^>]*>'
                    foreach ($match in [regex]::Matches(
                        $document.Text,
                        $pattern,
                        [System.Text.RegularExpressions.RegexOptions]::Singleline
                    )) {
                        $tag = $match.Value
                        [pscustomobject]@{
                            SourceFile = $document.PackagedPath
                            ElementName = @(
                                Get-XamlAttributeFromTag -Tag $tag -AttributeName "x:Name"
                                Get-XamlAttributeFromTag -Tag $tag -AttributeName "Name"
                            ) | Where-Object { $_ } | Select-Object -First 1
                            CommandParameter = Get-XamlAttributeFromTag -Tag $tag -AttributeName "CommandParameter"
                            Content = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Content"
                            Tag = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Tag"
                        }
                    }
                }
            )

            [pscustomobject]@{
                Command = $commandName
                Present = ($matches.Count -gt 0)
                MatchCount = $matches.Count
                Matches = $matches
            }
        }
    )

    $collectionBindings = @(
        "CurrentShownDeck.SlotList",
        "CurrentPlayer.UIData.ActionResourcesCostPreview",
        "SingleHotBar.SlotList",
        "PassivesHotBar.SlotList"
    )
    $collections = @(
        foreach ($binding in $collectionBindings) {
            $sources = @(
                $loadedDocuments |
                    Where-Object { $_.Text.Contains($binding) } |
                    ForEach-Object { $_.PackagedPath } |
                    Sort-Object -Unique
            )
            [pscustomobject]@{
                Binding = $binding
                Present = ($sources.Count -gt 0)
                SourceFiles = $sources
            }
        }
    )

    $radialSources = @(
        "PlayerCharacterProperties.SpellsAndActions",
        "TogglablePassivePredicate",
        "TogglableMetaMagicPassivePredicate",
        "Inventory.Slots"
    )
    $radialCoverage = @(
        foreach ($source in $radialSources) {
            $sources = @(
                $loadedDocuments |
                    Where-Object { $_.Text.Contains($source) } |
                    ForEach-Object { $_.PackagedPath } |
                    Sort-Object -Unique
            )
            [pscustomobject]@{
                Source = $source
                Present = ($sources.Count -gt 0)
                SourceFiles = $sources
            }
        }
    )

    $inputTransportSymbols = @(
        "SwitchWeaponSetCommand",
        "ToggleWeaponSet",
        "UISelectionLeft",
        "ControllerHoldButtonStyle",
        "WeaponSetSwitchStyle",
        "LSInputBinding",
        "HoldTimeShortcuts"
    )
    $inputTransportProbes = @(
        foreach ($symbol in $inputTransportSymbols) {
            $matches = @(
                foreach ($document in $loadedDocuments) {
                    $pattern = '<[^>]*' + [regex]::Escape($symbol) + '[^>]*>'
                    foreach ($match in [regex]::Matches(
                        $document.Text,
                        $pattern,
                        [System.Text.RegularExpressions.RegexOptions]::Singleline
                    )) {
                        $tag = $match.Value
                        [pscustomobject]@{
                            SourceFile = $document.PackagedPath
                            Element = Get-XamlElementNameFromTag -Tag $tag
                            ElementName = @(
                                Get-XamlAttributeFromTag -Tag $tag -AttributeName "x:Name"
                                Get-XamlAttributeFromTag -Tag $tag -AttributeName "Name"
                                Get-XamlAttributeFromTag -Tag $tag -AttributeName "x:Key"
                            ) | Where-Object { $_ } | Select-Object -First 1
                            BoundEvent = Get-XamlAttributeFromTag -Tag $tag -AttributeName "BoundEvent"
                            EventName = Get-XamlAttributeFromTag -Tag $tag -AttributeName "EventName"
                            Command = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Command"
                            CommandParameter = Get-XamlAttributeFromTag -Tag $tag -AttributeName "CommandParameter"
                            Style = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Style"
                            Content = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Content"
                            HoldTime = Get-XamlAttributeFromTag -Tag $tag -AttributeName "HoldTime"
                            TapTime = Get-XamlAttributeFromTag -Tag $tag -AttributeName "TapTime"
                            EatInput = Get-XamlAttributeFromTag -Tag $tag -AttributeName "EatInput"
                            Property = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Property"
                            Value = Get-XamlAttributeFromTag -Tag $tag -AttributeName "Value"
                            RawTag = $tag
                        }
                    }
                }
            )

            [pscustomobject]@{
                Symbol = $symbol
                Present = ($matches.Count -gt 0)
                MatchCount = $matches.Count
                Matches = $matches
            }
        }
    )

    $missingInputTransportSymbols = @(
        $inputTransportProbes |
            Where-Object { -not $_.Present } |
            ForEach-Object { $_.Symbol }
    )

    $missingCommands = @(
        $commandProbes |
            Where-Object { -not $_.Present } |
            ForEach-Object { $_.Command }
    )

    [ordered]@{
        SchemaVersion = 3
        HotBarSha256 = if ($HotBarPath -and (Test-Path -LiteralPath $HotBarPath -PathType Leaf)) {
            (Get-FileHash -Algorithm SHA256 -LiteralPath $HotBarPath).Hash.ToLowerInvariant()
        } else {
            $null
        }
        ScannedXamlCount = $loadedDocuments.Count
        CommandProbes = $commandProbes
        MissingCommands = $missingCommands
        InputTransportProbes = $inputTransportProbes
        MissingInputTransportSymbols = $missingInputTransportSymbols
        ExecutableCollections = $collections
        RadialAssignmentReferences = $radialCoverage
        Note = "Derived read-only discovery report. Missing research seams are evidence, not capture failures."
    }
}

if ($CoverageSelfTest) {
    $fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bg3-cam-coverage-selftest-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
    try {
        $hotBarFixture = Join-Path $fixtureRoot "HotBar.xaml"
        $otherFixture = Join-Path $fixtureRoot "Controller.xaml"
        @'
<Grid>
  <Button Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="Common"/>
  <Button Command="{Binding DataContext.FilterActionResourceCommand, RelativeSource={RelativeSource AncestorType=ls:UIWidget}}" CommandParameter="{Binding ActionResource}"/>
  <ItemsControl ItemsSource="{Binding CurrentShownDeck.SlotList}"/>
  <ItemsControl ItemsSource="{Binding SingleHotBar.SlotList}"/>
</Grid>
'@ | Set-Content -LiteralPath $hotBarFixture -Encoding UTF8
        @'
<Grid>
  <ItemsControl ItemsSource="{Binding PlayerCharacterProperties.SpellsAndActions}"/>
  <ItemsControl ItemsSource="{Binding Inventory.Slots}"/>
  <ls:LSInputBinding x:Name="WeaponInput"
                     BoundEvent="UISelectionLeft"
                     HoldTime="{StaticResource HoldTimeShortcuts}"
                     Command="{Binding SwitchWeaponSetCommand}"
                     EatInput="False"/>
  <ls:LSButton x:Name="WeaponHint"
               Style="{StaticResource ControllerHoldButtonStyle}"
               Content="{Binding InputEvents, ConverterParameter=UISelectionLeft}"/>
  <Style x:Key="WeaponSetSwitchStyle">
    <Setter Property="BoundEvent" Value="ToggleWeaponSet"/>
  </Style>
</Grid>
'@ | Set-Content -LiteralPath $otherFixture -Encoding UTF8

        $documents = @(
            [pscustomobject]@{ PackagedPath = "Mods/MainUI/GUI/Pages/HotBar.xaml"; CapturedPath = $hotBarFixture },
            [pscustomobject]@{ PackagedPath = "Public/Game/GUI/Library/Controller.xaml"; CapturedPath = $otherFixture }
        )
        $report = Get-HotBarCoverageReport -Documents $documents -HotBarPath $hotBarFixture
        $cantrip = @($report.CommandProbes | Where-Object { $_.Command -eq "FilterCantripsCommand" })[0]
        $deck = @($report.CommandProbes | Where-Object { $_.Command -eq "SetCurrentShownDeckCommand" })[0]
        $resourceFilter = @($report.CommandProbes | Where-Object { $_.Command -eq "FilterActionResourceCommand" })[0]

        if (-not $cantrip -or $cantrip.Present -or $cantrip.MatchCount -ne 0) {
            throw "Coverage self-test expected missing FilterCantripsCommand to be recorded without failure."
        }
        if ($report.MissingCommands -notcontains "FilterCantripsCommand") {
            throw "Coverage self-test did not record FilterCantripsCommand in MissingCommands."
        }
        if (-not $deck.Present -or $deck.MatchCount -ne 1 -or $deck.Matches[0].SourceFile -ne "Mods/MainUI/GUI/Pages/HotBar.xaml") {
            throw "Coverage self-test did not preserve discovered command source metadata."
        }
        if (-not $resourceFilter.Present -or $resourceFilter.MatchCount -ne 1) {
            throw "Coverage self-test did not recognize DataContext/RelativeSource command bindings."
        }
        $switchCommand = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "SwitchWeaponSetCommand" })[0]
        $toggleEvent = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "ToggleWeaponSet" })[0]
        $selectionLeft = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "UISelectionLeft" })[0]
        $holdTime = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "HoldTimeShortcuts" })[0]
        $inputBinding = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "LSInputBinding" })[0]
        $holdStyle = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "ControllerHoldButtonStyle" })[0]
        $weaponStyle = @($report.InputTransportProbes | Where-Object { $_.Symbol -eq "WeaponSetSwitchStyle" })[0]

        if (-not $switchCommand.Present -or $switchCommand.Matches[0].Command -ne "{Binding SwitchWeaponSetCommand}") {
            throw "Coverage self-test did not preserve SwitchWeaponSetCommand binding metadata."
        }
        if (-not $selectionLeft.Present -or
            @($selectionLeft.Matches | Where-Object { $_.BoundEvent -eq "UISelectionLeft" }).Count -ne 1) {
            throw "Coverage self-test did not preserve UISelectionLeft BoundEvent metadata."
        }
        if (-not $holdTime.Present -or
            @($holdTime.Matches | Where-Object { $_.HoldTime -eq "{StaticResource HoldTimeShortcuts}" }).Count -ne 1) {
            throw "Coverage self-test did not preserve hold-threshold metadata."
        }
        if (-not $toggleEvent.Present -or
            @($toggleEvent.Matches | Where-Object { $_.Property -eq "BoundEvent" -and $_.Value -eq "ToggleWeaponSet" }).Count -ne 1) {
            throw "Coverage self-test did not preserve semantic ToggleWeaponSet setter metadata."
        }
        if (-not $inputBinding.Present -or
            @($inputBinding.Matches | Where-Object { $_.Element -eq "ls:LSInputBinding" }).Count -ne 1 -or
            -not $holdStyle.Present -or
            -not $weaponStyle.Present) {
            throw "Coverage self-test did not preserve input-binding/style transport structure."
        }
        if (@($report.MissingInputTransportSymbols).Count -ne 0) {
            throw "Coverage self-test unexpectedly reported missing input-transport symbols."
        }
        if ($report.SchemaVersion -ne 3 -or $report.ScannedXamlCount -ne 2) {
            throw "Coverage self-test produced the wrong report schema."
        }

        Write-Host "Fail-soft HotBar coverage discovery self-test passed."
        exit 0
    } finally {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
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

    $hotBarManifest = @($manifest | Where-Object { $_.PackagedPath -eq "Mods/MainUI/GUI/Pages/HotBar.xaml" } | Select-Object -First 1)
    if ($hotBarManifest.Count -ne 1) {
        throw "Exact current HotBar.xaml was not captured."
    }
    $hotBarCapturedPath = Join-Path $outputDir $hotBarManifest[0].RelativeCapturedPath
    $coverageDocuments = @(
        $manifest |
            ForEach-Object {
                [pscustomobject]@{
                    PackagedPath = $_.PackagedPath
                    CapturedPath = Join-Path $outputDir $_.RelativeCapturedPath
                }
            }
    )
    $coverageReport = Get-HotBarCoverageReport -Documents $coverageDocuments -HotBarPath $hotBarCapturedPath
    $coverageReportPath = Join-Path $outputDir "hotbar-coverage-contract.json"
    $coverageReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $coverageReportPath -Encoding UTF8

    $essentialGroups = [ordered]@{
        PreloadedActionRadials = @($manifest | Where-Object { $_.PackagedPath -like "*PreloadedActionRadials*.xaml" })
        ActionRadials = @($manifest | Where-Object { $_.PackagedPath -like "*ActionRadials.xaml" -and $_.PackagedPath -notlike "*Preloaded*" })
        HotBar = @($manifest | Where-Object { $_.PackagedPath -like "*HotBar*.xaml" })
        HotBarPage = @($manifest | Where-Object { $_.PackagedPath -eq "Mods/MainUI/GUI/Pages/HotBar.xaml" })
        DataTemplates = @($manifest | Where-Object { $_.PackagedPath -eq "Public/Game/GUI/Library/DataTemplates.xaml" })
        KeyboardPointTemplates = @($manifest | Where-Object { $_.PackagedPath -eq "Public/Game/GUI/Library/DataTemplates_k.xaml" })
        ControllerPointTemplates = @($manifest | Where-Object { $_.PackagedPath -eq "Public/Game/GUI/Library/DataTemplates_c.xaml" })
        ControllerActionResourceTemplates = @($manifest | Where-Object { $_.PackagedPath -eq "Public/Game/GUI/Library/ActionResourceTemplates_c.xaml" })
        ControllerResourceImports = @($manifest | Where-Object { $_.PackagedPath -eq "Public/Game/GUI/Library/Libs_Controller.xaml" })
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
        "Derived HotBar/input transport report: hotbar-coverage-contract.json"
        "Upload the ZIP back to the development chat."
    ) | Set-Content -LiteralPath (Join-Path $outputDir "README.txt") -Encoding UTF8

    $summary = @(
        "BG3 Controller Action Menu - captured self-contained inputs"
        "Game package version: $(if ($package) { $package.Version } else { '(unknown)' })"
        "Game.pak: $($gamePak.FullName)"
        "Files captured: $($manifest.Count)"
        ""
        "Derived coverage/input report: hotbar-coverage-contract.json"
        "Missing research commands: $(if (@($coverageReport.MissingCommands).Count) { @($coverageReport.MissingCommands) -join ', ' } else { '(none)' })"
        "Missing input transport symbols: $(if (@($coverageReport.MissingInputTransportSymbols).Count) { @($coverageReport.MissingInputTransportSymbols) -join ', ' } else { '(none)' })"
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
