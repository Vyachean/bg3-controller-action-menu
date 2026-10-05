param(
    [string]$BasePackage = "",
    [string]$OutputPackage = "",
    [string]$GameInstallRoot = "",
    [string]$DivinePath = "",
    [string]$WorkRoot = "",
    [switch]$NoDownload,
    [string]$PatchOnlySourceXaml = "",
    [string]$PatchOnlyDestinationXaml = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LslibVersion = "v1.20.4"
$LslibAsset = "ExportTool-$LslibVersion.zip"
$LslibSha256 = "5e02368fb8acafda9b45acba37a3f3bf507fc3d65a083a159abbeab06337190e"
$LslibUrl = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$LslibAsset"

$NativePaths = @(
    "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml",
    "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"
)

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
    if ($cached) { return $cached.FullName }

    if ($NoDownload) {
        throw "LSLib $LslibVersion is not cached and -NoDownload was specified."
    }

    New-Item -ItemType Directory -Force -Path $cacheBase | Out-Null
    $zip = Join-Path $cacheBase $LslibAsset
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
    if (-not $divine) { throw "divine.exe was not found after extracting pinned LSLib." }
    return $divine.FullName
}

function Get-Bg3InstallRoot {
    if ($GameInstallRoot) {
        if (-not (Test-Path -LiteralPath $GameInstallRoot -PathType Container)) {
            throw "BG3 install root does not exist: $GameInstallRoot"
        }
        return (Resolve-Path -LiteralPath $GameInstallRoot).Path
    }

    $packages = @(Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3" -ErrorAction SilentlyContinue)
    if ($packages.Count -ne 1) {
        throw "Expected exactly one Xbox/App BG3 package, found $($packages.Count)."
    }
    if (-not $packages[0].InstallLocation -or -not (Test-Path -LiteralPath $packages[0].InstallLocation)) {
        throw "BG3 package install location is unavailable."
    }
    return (Resolve-Path -LiteralPath $packages[0].InstallLocation).Path
}

function Get-RadialSpan {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $escaped = [regex]::Escape($Name)
    $openRegex = [regex]::new(
        '<ls:Radial\b[^>]*x:Name="' + $escaped + '"[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $open = $openRegex.Match($Text)
    if (-not $open.Success) { throw "Native radial '$Name' was not found." }

    $tokenRegex = [regex]::new(
        '</?ls:Radial\b[^>]*?/?>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $depth = 1
    $position = $open.Index + $open.Length
    while ($depth -gt 0) {
        $token = $tokenRegex.Match($Text, $position)
        if (-not $token.Success) { throw "Native radial '$Name' has no matching closing element." }

        if ($token.Value.StartsWith("</ls:Radial", [System.StringComparison]::Ordinal)) {
            $depth -= 1
        } elseif (-not $token.Value.EndsWith("/>", [System.StringComparison]::Ordinal)) {
            $depth += 1
        }
        $position = $token.Index + $token.Length
    }

    return [pscustomobject]@{
        Start = $open.Index
        End = $position
        OpenLength = $open.Length
        OpenText = $open.Value
    }
}

function New-GridMirrorXaml {
    param(
        [Parameter(Mandatory = $true)][string]$RadialName,
        [Parameter(Mandatory = $true)][string]$ItemsSource
    )

    $template = @'
                            <ls:LSListBox x:Name="CAM___RADIAL__Grid"
                                          ItemsSource="__ITEMS__"
                                          SelectedIndex="{Binding LocalFocus.Index, ElementName=__RADIAL__, Mode=OneWay}"
                                          Focusable="False"
                                          IsHitTestVisible="False"
                                          Template="{StaticResource ScrolllessListBox}"
                                          HorizontalAlignment="Center"
                                          VerticalAlignment="Center"
                                          Width="1040"
                                          Background="#F0111318">
                                <ls:LSListBox.ItemContainerStyle>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource {x:Type ListBoxItem}}">
                                        <Setter Property="Background" Value="Transparent"/>
                                        <Setter Property="BorderBrush" Value="Transparent"/>
                                        <Setter Property="BorderThickness" Value="3"/>
                                        <Setter Property="Focusable" Value="False"/>
                                        <Setter Property="Template">
                                            <Setter.Value>
                                                <ControlTemplate TargetType="{x:Type ListBoxItem}">
                                                    <Border x:Name="CAM_FocusBorder"
                                                            Background="Transparent"
                                                            BorderBrush="{TemplateBinding BorderBrush}"
                                                            BorderThickness="{TemplateBinding BorderThickness}"
                                                            Padding="3">
                                                        <ContentPresenter/>
                                                    </Border>
                                                    <ControlTemplate.Triggers>
                                                        <Trigger Property="IsSelected" Value="True">
                                                            <Setter TargetName="CAM_FocusBorder" Property="BorderBrush" Value="{DynamicResource LS_PrimaryColor}"/>
                                                        </Trigger>
                                                    </ControlTemplate.Triggers>
                                                </ControlTemplate>
                                            </Setter.Value>
                                        </Setter>
                                    </Style>
                                </ls:LSListBox.ItemContainerStyle>
                                <ls:LSListBox.ItemTemplate>
                                    <DataTemplate>
                                        <ls:LSButton Style="{StaticResource HotBarSlotStyle}"
                                                     Content="{Binding Content}"
                                                     Command="{x:Null}"
                                                     CommandParameter="{x:Null}"
                                                     EatInput="False"
                                                     BoundEvent="UIAccept"
                                                     Focusable="False"
                                                     ls:MoveFocus.Focusable="False"
                                                     IsHitTestVisible="False"
                                                     Margin="6"/>
                                    </DataTemplate>
                                </ls:LSListBox.ItemTemplate>
                                <ls:LSListBox.ItemsPanel>
                                    <ItemsPanelTemplate>
                                        <ls:LSGrid AutoIndex="True"
                                                   Columns="6"
                                                   CellWidth="{StaticResource HotBarSlotWidth}"
                                                   CellHeight="{StaticResource HotBarSlotHeight}"
                                                   HorizontalSpacing="14"
                                                   VerticalSpacing="14"
                                                   DisableScrolling="True"/>
                                    </ItemsPanelTemplate>
                                </ls:LSListBox.ItemsPanel>
                            </ls:LSListBox>
'@
    return $template.Replace("__RADIAL__", $RadialName).Replace("__ITEMS__", $ItemsSource)
}

function Add-VisualMirror {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$RadialName,
        [Parameter(Mandatory = $true)][string]$ItemsSource
    )

    $mirrorName = "CAM_" + $RadialName + "Grid"
    if ($Text.Contains($mirrorName)) {
        throw "Native XAML already contains CAM mirror '$RadialName'."
    }

    $span = Get-RadialSpan -Text $Text -Name $RadialName
    $open = $span.OpenText
    if ($open -match '\sOpacity=') {
        throw "Native radial '$RadialName' already defines Opacity; refusing an ambiguous patch."
    }

    $patchedOpen = $open.Substring(0, $open.Length - 1) + ' Opacity="0">'
    $mirror = New-GridMirrorXaml -RadialName $RadialName -ItemsSource $ItemsSource

    $before = $Text.Substring(0, $span.Start)
    $element = $Text.Substring($span.Start, $span.End - $span.Start)
    $after = $Text.Substring($span.End)

    $element = $patchedOpen + $element.Substring($span.OpenLength)
    return $before + $element + $mirror + $after
}

function Patch-NativeRadialXaml {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $text = [System.IO.File]::ReadAllText($Source)

    foreach ($required in @(
        'x:Key="ActionRadialWidgetTemplate_P8"',
        'x:Key="BarPageViewStyle"',
        'x:Key="SingleBarPageViewStyle"',
        'x:Name="UseSlotBinding"',
        'x:Name="CancelButton"',
        'Command="{Binding UseSlotCommand}"',
        'Command="{Binding ClearSingleHotbarCommand}"'
    )) {
        if (-not $text.Contains($required)) {
            throw "Native XAML is missing required Patch 8 seam: $required"
        }
    }

    $text = Add-VisualMirror -Text $text -RadialName "HotBarRadial" -ItemsSource "{TemplateBinding ItemsSource}"
    $text = Add-VisualMirror -Text $text -RadialName "SingleBar" -ItemsSource "{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}"

    foreach ($required in @(
        'CAM_HotBarRadialGrid',
        'CAM_SingleBarGrid',
        'x:Name="UseSlotBinding"',
        'x:Name="CancelButton"'
    )) {
        if (-not $text.Contains($required)) {
            throw "Patched native XAML is missing required mirror/native seam: $required"
        }
    }

    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
    [xml]$null = Get-Content -Raw -LiteralPath $Destination
}

if ($PatchOnlySourceXaml) {
    if (-not $PatchOnlyDestinationXaml) {
        throw "-PatchOnlyDestinationXaml is required with -PatchOnlySourceXaml."
    }
    Patch-NativeRadialXaml -Source $PatchOnlySourceXaml -Destination $PatchOnlyDestinationXaml
    Write-Host "Patched native radial XAML: $PatchOnlyDestinationXaml"
    exit 0
}

if (-not $BasePackage -or -not (Test-Path -LiteralPath $BasePackage -PathType Leaf)) {
    throw "-BasePackage must point to the downloaded CAM base .pak."
}
if (-not $OutputPackage) { throw "-OutputPackage is required." }

$GameInstallRoot = Get-Bg3InstallRoot
$gamePaks = @(
    Get-ChildItem -LiteralPath $GameInstallRoot -Filter "Game.pak" -File -Recurse -Force -ErrorAction SilentlyContinue
)
if ($gamePaks.Count -ne 1) {
    throw "Expected exactly one Game.pak under '$GameInstallRoot', found $($gamePaks.Count)."
}
$gamePak = $gamePaks[0]

if (-not $WorkRoot) {
    $cache = if ($env:LOCALAPPDATA) {
        Join-Path $env:LOCALAPPDATA "BG3ControllerActionMenu\native-overlay"
    } else {
        Join-Path $env:TEMP "BG3ControllerActionMenu\native-overlay"
    }
    $WorkRoot = Join-Path $cache ([guid]::NewGuid().ToString("N"))
}
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

$divine = Resolve-Divine -ExplicitPath $DivinePath
$packageRoot = Join-Path $WorkRoot "package"
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

& $divine --game bg3 --action extract-package --source $BasePackage --destination $packageRoot --loglevel error
if ($LASTEXITCODE -ne 0) { throw "Failed to extract CAM base package." }

$sourceHashes = [ordered]@{}
$nativeIndex = 0
foreach ($nativePath in $NativePaths) {
    $nativeIndex += 1
    $nativeSource = Join-Path $WorkRoot ("native-$nativeIndex.xaml")
    & $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $nativeSource --packaged-path $nativePath --loglevel error
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nativeSource)) {
        throw "Failed to extract native '$nativePath' from Game.pak."
    }

    $sourceHashes[$nativePath] = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativeSource).Hash.ToLowerInvariant()
    $destination = Join-Path $packageRoot ($nativePath -replace "/", "\")
    Patch-NativeRadialXaml -Source $nativeSource -Destination $destination
}

$outputParent = Split-Path -Parent $OutputPackage
if ($outputParent) { New-Item -ItemType Directory -Force -Path $outputParent | Out-Null }
if (Test-Path -LiteralPath $OutputPackage) { Remove-Item -LiteralPath $OutputPackage -Force }

& $divine --game bg3 --action create-package --source $packageRoot --destination $OutputPackage --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPackage -PathType Leaf)) {
    throw "Failed to create native-derived CAM package."
}

$verify = @(
    & $divine --game bg3 --action list-package --source $OutputPackage --expression "*PreloadedActionRadials_c.xaml" --loglevel error 2>&1 |
        ForEach-Object { "$_" }
)
if ($LASTEXITCODE -ne 0) { throw "Generated package could not be listed for verification." }

$tab = [char]9
foreach ($nativePath in $NativePaths) {
    if (@($verify | Where-Object { $_.StartsWith($nativePath + $tab, [System.StringComparison]::Ordinal) }).Count -ne 1) {
        throw "Generated package does not contain exactly one '$nativePath'."
    }
}

Write-Host "Native-derived CAM package created."
Write-Host "  Game.pak: $($gamePak.FullName)"
foreach ($key in $sourceHashes.Keys) {
    Write-Host "  Native SHA: $key :: $($sourceHashes[$key])"
}
Write-Host "  Output: $OutputPackage"
