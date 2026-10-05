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

$NativePath = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"
$ClairmontPath = "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"

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
    if (-not $divine) {
        throw "divine.exe was not found after extracting pinned LSLib."
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

    $packages = @(Get-AppxPackage -Name "LarianStudiosGamesLtd.baldurssgate3" -ErrorAction SilentlyContinue)
    if ($packages.Count -ne 1) {
        throw "Expected exactly one Xbox/App BG3 package, found $($packages.Count)."
    }
    if (-not $packages[0].InstallLocation -or -not (Test-Path -LiteralPath $packages[0].InstallLocation)) {
        throw "BG3 package install location is unavailable."
    }
    return (Resolve-Path -LiteralPath $packages[0].InstallLocation).Path
}

function Get-ElementSpan {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$AttributeName,
        [Parameter(Mandatory = $true)][string]$AttributeValue
    )

    $tagEscaped = [regex]::Escape($Tag)
    $attrEscaped = [regex]::Escape($AttributeName)
    $valueEscaped = [regex]::Escape($AttributeValue)

    $openRegex = [regex]::new(
        '<' + $tagEscaped + '\b[^>]*\b' + $attrEscaped + '="' + $valueEscaped + '"[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $open = $openRegex.Match($Text)
    if (-not $open.Success) {
        throw "Element <$Tag $AttributeName='$AttributeValue'> was not found."
    }

    $tokenRegex = [regex]::new(
        '</?' + $tagEscaped + '\b[^>]*?/?>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $depth = 1
    $position = $open.Index + $open.Length
    while ($depth -gt 0) {
        $token = $tokenRegex.Match($Text, $position)
        if (-not $token.Success) {
            throw "Element <$Tag $AttributeName='$AttributeValue'> has no matching closing tag."
        }

        if ($token.Value.StartsWith("</$Tag", [System.StringComparison]::Ordinal)) {
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
        Text = $Text.Substring($open.Index, $position - $open.Index)
    }
}

function Get-FirstInteractionTriggers {
    param([Parameter(Mandatory = $true)][string]$Text)

    $start = $Text.IndexOf("<b:Interaction.Triggers>", [System.StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw "Native radial is missing b:Interaction.Triggers."
    }

    $closing = "</b:Interaction.Triggers>"
    $end = $Text.IndexOf($closing, $start, [System.StringComparison]::Ordinal)
    if ($end -lt 0) {
        throw "Native radial interaction triggers are not closed."
    }
    $end += $closing.Length
    return $Text.Substring($start, $end - $start)
}

function New-GridRenderer {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ItemsSource,
        [Parameter(Mandatory = $true)][string]$IsEnabled,
        [Parameter(Mandatory = $true)][string]$OriginalRadialText
    )

    $selectorName = "CAM_" + $Name + "Selector"
    $interaction = Get-FirstInteractionTriggers -Text $OriginalRadialText

    return @"
                            <ls:LSListBox x:Name="$Name"
                                          ItemsSource="$ItemsSource"
                                          IsEnabled="$IsEnabled"
                                          Visibility="Collapsed"
                                          SelectedIndex="0"
                                          KeyboardNavigation.DirectionalNavigation="Contained"
                                          ActionNextEvent="UIDown"
                                          ActionPrevEvent="UIUp"
                                          LocalFocusSelector="{Binding ElementName=$selectorName,Mode=OneWay}"
                                          Template="{StaticResource ScrolllessListBox}"
                                          ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"
                                          ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"
                                          ItemsPanel="{StaticResource CAM_ActionGridPanel}">
$interaction
                            </ls:LSListBox>
                            <Control x:Name="$selectorName"
                                     IsHitTestVisible="False"
                                     VerticalAlignment="Top"
                                     HorizontalAlignment="Left"
                                     Template="{StaticResource SelectorTemplate}"
                                     Visibility="{Binding Visibility, ElementName=$Name}"/>
"@
}

function Convert-PageStyleToGrid {
    param(
        [Parameter(Mandatory = $true)][string]$StyleText,
        [Parameter(Mandatory = $true)][ValidateSet("HotBarRadial","SingleBar")][string]$Name
    )

    $span = Get-ElementSpan -Text $StyleText -Tag "ls:Radial" -AttributeName "x:Name" -AttributeValue $Name

    if ($Name -eq "HotBarRadial") {
        $items = "{TemplateBinding ItemsSource}"
        $isEnabled = "{Binding Path=(ls:MoveFocus.IsFocused), RelativeSource={RelativeSource Mode=TemplatedParent}}"
    } else {
        $items = "{Binding ItemsSource,RelativeSource={RelativeSource TemplatedParent}}"
        $isEnabled = "False"
    }

    $replacement = New-GridRenderer -Name $Name -ItemsSource $items -IsEnabled $isEnabled -OriginalRadialText $span.Text

    return $StyleText.Substring(0, $span.Start) +
        $replacement +
        $StyleText.Substring($span.End)
}

function Get-RootOpenTag {
    param([Parameter(Mandatory = $true)][string]$Text)

    $m = [regex]::Match(
        $Text,
        '<ResourceDictionary\b[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $m.Success) {
        throw "Native radial dictionary has no ResourceDictionary root."
    }
    return $m.Value
}

function New-ControllerLibraryFromNative {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $native = [System.IO.File]::ReadAllText($Source)

    foreach ($required in @(
        'x:Key="ActionRadialWidgetTemplate_P8"',
        'x:Key="RadialHotBarListItemContainer"',
        'x:Key="BarPageViewStyle"',
        'x:Key="SingleBarPageViewStyle"',
        'x:Key="SlotAssignHolderStyle"',
        'x:Key="AvailableSlotContainer"',
        'x:Key="AvailableSlotsListPanelTemplate"',
        'x:Name="AssignList"',
        'LocalFocusSelector="{Binding ElementName=SelectorAssign,Mode=OneWay}"',
        'ActionUpEvent="UIUp"',
        'ActionDownEvent="UIDown"',
        'ActionLeftEvent="UILeft"',
        'ActionRightEvent="UIRight"',
        'x:Name="UseSlotBinding"',
        'x:Name="CancelButton"',
        'Command="{Binding UseSlotCommand}"',
        'Command="{Binding ClearSingleHotbarCommand}"'
    )) {
        if (-not $native.Contains($required)) {
            throw "Native XAML is missing required Patch 8 seam: $required"
        }
    }

    $single = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "SingleBarPageViewStyle").Text
    $bar = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "BarPageViewStyle").Text
    $container = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "RadialHotBarListItemContainer").Text
    $widget = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "ActionRadialWidgetTemplate_P8").Text

    $single = Convert-PageStyleToGrid -StyleText $single -Name "SingleBar"
    $bar = Convert-PageStyleToGrid -StyleText $bar -Name "HotBarRadial"

    $root = Get-RootOpenTag -Text $native

    $camResources = @'
    <!-- CAM-authored grid resources. Navigation follows the current native
         slot-assignment UI: focusable ListBoxItem + LSGrid directional events. -->
    <Style x:Key="CAM_ActionGridSlotContainer"
           TargetType="{x:Type ListBoxItem}"
           BasedOn="{StaticResource {x:Type ListBoxItem}}">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="Transparent"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Focusable" Value="True"/>
        <Setter Property="Padding" Value="0"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="{x:Type ListBoxItem}">
                    <Border Background="Transparent">
                        <ContentPresenter/>
                    </Border>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
        <Style.Triggers>
            <Trigger Property="IsSelected" Value="True">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="BorderBrush" Value="Transparent"/>
            </Trigger>
            <DataTrigger Binding="{Binding SlotType}" Value="Empty">
                <Setter Property="Visibility" Value="Collapsed"/>
                <Setter Property="Focusable" Value="False"/>
            </DataTrigger>
        </Style.Triggers>
    </Style>

    <DataTemplate x:Key="CAM_ActionGridSlotTemplate">
        <ContentControl Style="{StaticResource SlotIconStyle}"
                        Content="{Binding Content}"
                        Width="104"
                        Height="104"
                        IsHitTestVisible="False"
                        Focusable="False"/>
    </DataTemplate>

    <ItemsPanelTemplate x:Key="CAM_ActionGridPanel">
        <ls:LSGrid ActionUpEvent="UIUp"
                   ActionDownEvent="UIDown"
                   ActionRightEvent="UIRight"
                   ActionLeftEvent="UILeft"
                   AutoIndex="True"
                   ContainerData="{Binding}"
                   Columns="5"
                   CellWidth="120"
                   CellHeight="120"
                   HorizontalSpacing="8"
                   VerticalSpacing="8"
                   DisableScrolling="True"
                   EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"/>
    </ItemsPanelTemplate>
'@

    $generated = @"
$root
$camResources

$single

$bar

$container

$widget
</ResourceDictionary>
"@

    foreach ($required in @(
        'x:Key="CAM_ActionGridPanel"',
        'LocalFocusSelector="{Binding ElementName=CAM_HotBarRadialSelector,Mode=OneWay}"',
        'LocalFocusSelector="{Binding ElementName=CAM_SingleBarSelector,Mode=OneWay}"',
        '<ls:LSListBox x:Name="HotBarRadial"',
        '<ls:LSListBox x:Name="SingleBar"',
        'x:Key="ActionRadialWidgetTemplate_P8"',
        'x:Key="RadialHotBarListItemContainer"',
        'x:Name="UseSlotBinding"',
        'x:Name="CancelButton"',
        'Command="{Binding UseSlotCommand}"',
        'Command="{Binding ClearSingleHotbarCommand}"'
    )) {
        if (-not $generated.Contains($required)) {
            throw "Generated controller library is missing required seam: $required"
        }
    }

    if ($generated.Contains("<ls:Radial ")) {
        throw "Generated controller library still contains a radial slot renderer."
    }
    if ($generated.Contains("AssignSlotCommand")) {
        throw "Generated action-browsing controller library must not dispatch AssignSlotCommand."
    }

    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $generated, $utf8NoBom)
    [xml]$null = Get-Content -Raw -LiteralPath $Destination
}

if ($PatchOnlySourceXaml) {
    if (-not $PatchOnlyDestinationXaml) {
        throw "-PatchOnlyDestinationXaml is required with -PatchOnlySourceXaml."
    }
    New-ControllerLibraryFromNative -Source $PatchOnlySourceXaml -Destination $PatchOnlyDestinationXaml
    Write-Host "Generated controller grid library: $PatchOnlyDestinationXaml"
    exit 0
}

if (-not $BasePackage -or -not (Test-Path -LiteralPath $BasePackage -PathType Leaf)) {
    throw "-BasePackage must point to the downloaded CAM base .pak."
}
if (-not $OutputPackage) {
    throw "-OutputPackage is required."
}

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
if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract CAM base package."
}

$nativeSource = Join-Path $WorkRoot "native-PreloadedActionRadials.xaml"
$clairmontSource = Join-Path $WorkRoot "native-PreloadedActionRadials-Clairmont.xaml"

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $nativeSource --packaged-path $NativePath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nativeSource)) {
    throw "Failed to extract native '$NativePath' from Game.pak."
}

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $clairmontSource --packaged-path $ClairmontPath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $clairmontSource)) {
    throw "Failed to extract native '$ClairmontPath' from Game.pak."
}

foreach ($candidate in @($nativeSource, $clairmontSource)) {
    $text = [System.IO.File]::ReadAllText($candidate)
    foreach ($required in @(
        'x:Key="ActionRadialWidgetTemplate_P8"',
        'x:Key="BarPageViewStyle"',
        'x:Key="SingleBarPageViewStyle"',
        'x:Key="SlotAssignHolderStyle"',
        'x:Name="AssignList"',
        'x:Name="UseSlotBinding"',
        'x:Name="CancelButton"'
    )) {
        if (-not $text.Contains($required)) {
            throw "Installed radial dictionary '$candidate' is missing required seam: $required"
        }
    }
}

$libraryPath = Join-Path $packageRoot "Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
New-ControllerLibraryFromNative -Source $nativeSource -Destination $libraryPath

foreach ($relative in @(
    "Public\Game\GUI\Library\PreloadedActionRadials_c.xaml",
    "Public\Game\GUI\Override\Clairmont\Library\PreloadedActionRadials_c.xaml"
)) {
    $stale = Join-Path $packageRoot $relative
    if (Test-Path -LiteralPath $stale) {
        Remove-Item -LiteralPath $stale -Force
    }
}

$outputParent = Split-Path -Parent $OutputPackage
if ($outputParent) { New-Item -ItemType Directory -Force -Path $outputParent | Out-Null }
if (Test-Path -LiteralPath $OutputPackage) { Remove-Item -LiteralPath $OutputPackage -Force }

& $divine --game bg3 --action create-package --source $packageRoot --destination $OutputPackage --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPackage -PathType Leaf)) {
    throw "Failed to create native-derived CAM package."
}

$verify = Join-Path $WorkRoot "verify"
if (Test-Path -LiteralPath $verify) { Remove-Item -LiteralPath $verify -Recurse -Force }
New-Item -ItemType Directory -Force -Path $verify | Out-Null
& $divine --game bg3 --action extract-package --source $OutputPackage --destination $verify --loglevel error
if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract generated package for verification."
}

$verifiedLibrary = Join-Path $verify "Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
if (-not (Test-Path -LiteralPath $verifiedLibrary -PathType Leaf)) {
    throw "Generated package is missing Lib_Controller.xaml."
}

$verifiedText = [System.IO.File]::ReadAllText($verifiedLibrary)
foreach ($required in @(
    'x:Key="ActionRadialWidgetTemplate_P8"',
    '<ls:LSListBox x:Name="HotBarRadial"',
    '<ls:LSListBox x:Name="SingleBar"',
    'LocalFocusSelector="{Binding ElementName=CAM_HotBarRadialSelector,Mode=OneWay}"',
    'ActionUpEvent="UIUp"',
    'ActionDownEvent="UIDown"',
    'ActionLeftEvent="UILeft"',
    'ActionRightEvent="UIRight"',
    'x:Name="UseSlotBinding"',
    'x:Name="CancelButton"'
)) {
    if (-not $verifiedText.Contains($required)) {
        throw "Packed controller library is missing required seam: $required"
    }
}

Write-Host "Native-derived CAM controller grid package created."
Write-Host "  Game.pak:       $($gamePak.FullName)"
Write-Host "  Native SHA:     $((Get-FileHash -Algorithm SHA256 -LiteralPath $nativeSource).Hash.ToLowerInvariant())"
Write-Host "  Clairmont SHA:  $((Get-FileHash -Algorithm SHA256 -LiteralPath $clairmontSource).Hash.ToLowerInvariant())"
Write-Host "  Output:         $OutputPackage"
