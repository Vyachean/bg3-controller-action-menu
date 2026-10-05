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

    if ($open.Value.EndsWith("/>", [System.StringComparison]::Ordinal)) {
        return [pscustomobject]@{
            Start = $open.Index
            End = $open.Index + $open.Length
            OpenLength = $open.Length
            OpenText = $open.Value
            Text = $open.Value
        }
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

    $focusRootName = "CAM_" + $Name + "FocusRoot"

    return @"
                            <Grid x:Name="$focusRootName"
                                  HorizontalAlignment="Center"
                                  VerticalAlignment="Center"
                                  Width="640"
                                  Height="400"
                                  Background="Transparent">
                                <ls:LSListBox x:Name="$Name"
                                              ItemsSource="$ItemsSource"
                                              IsEnabled="$IsEnabled"
                                              Visibility="Collapsed"
                                              SelectedIndex="0"
                                              HorizontalAlignment="Stretch"
                                              VerticalAlignment="Stretch"
                                              HorizontalContentAlignment="Center"
                                              VerticalContentAlignment="Center"
                                              Background="Transparent"
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
                            </Grid>
"@
}

function Hide-RadialBackdrop {
    param([Parameter(Mandatory = $true)][string]$StyleText)

    $pattern = '<Ellipse\s+(?=[^>]*Margin="0,36,0,0")(?=[^>]*Height="1260")(?=[^>]*Width="1260")[^>]*>'
    $match = [regex]::Match(
        $StyleText,
        $pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $match.Success) {
        throw "Native PageView style is missing the radial backdrop ellipse."
    }

    $open = $match.Value
    if ($open -match '\sVisibility="[^"]*"') {
        $patched = [regex]::Replace($open, '\sVisibility="[^"]*"', ' Visibility="Collapsed"', 1)
    } else {
        $patched = $open.Substring(0, $open.Length - 1) + ' Visibility="Collapsed">'
    }
    return $StyleText.Substring(0, $match.Index) +
        $patched +
        $StyleText.Substring($match.Index + $match.Length)
}

function Set-NamedElementAttribute {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Attribute,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $span = Get-ElementSpan -Text $Text -Tag $Tag -AttributeName "x:Name" -AttributeValue $Name
    $open = $span.OpenText
    $escapedAttribute = [regex]::Escape($Attribute)
    $attributePattern = '\s' + $escapedAttribute + '="[^"]*"'

    if ([regex]::IsMatch($open, $attributePattern)) {
        $patchedOpen = [regex]::Replace(
            $open,
            $attributePattern,
            ' ' + $Attribute + '="' + $Value + '"',
            1
        )
    } else {
        if ($open.EndsWith("/>", [System.StringComparison]::Ordinal)) {
            $patchedOpen = $open.Substring(0, $open.Length - 2) +
                ' ' + $Attribute + '="' + $Value + '"/>'
        } else {
            $patchedOpen = $open.Substring(0, $open.Length - 1) +
                ' ' + $Attribute + '="' + $Value + '">'
        }
    }

    return $Text.Substring(0, $span.Start) +
        $patchedOpen +
        $Text.Substring($span.Start + $span.OpenLength)
}

function Convert-WidgetChromeForGrid {
    param([Parameter(Mandatory = $true)][string]$WidgetText)

    foreach ($change in @(
        @("HorizontalAlignment", "Center"),
        @("HorizontalContentAlignment", "Center"),
        @("VerticalAlignment", "Bottom"),
        @("Width", "Auto"),
        @("FlowDirection", "LeftToRight"),
        @("Margin", "0,0,0,56")
    )) {
        $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:AlignableWrapPanel" -Name "ButtonHintsContainer" -Attribute $change[0] -Value $change[1]
    }

    foreach ($buttonName in @(
        "SelectButtonVisual",
        "ShowContextMenu",
        "CancelConcentrationButton",
        "ToggleWeaponSet",
        "ToggleDualWield",
        "CancelButton"
    )) {
        $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name $buttonName -Attribute "Width" -Value "Auto"
    }

    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "SelectButtonVisual" -Attribute "Margin" -Value "0,0,20,0"
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "CancelButton" -Attribute "Margin" -Value "0"

    # ContextMenu still edits the underlying hotbar slots, which remains useful for
    # the grid. Keep X active and visible, but remove radial-specific wording.
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "ShowContextMenu" -Attribute "Opacity" -Value "1"
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "ShowContextMenu" -Attribute "Width" -Value "Auto"
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "ShowContextMenu" -Attribute "Margin" -Value "0,0,20,0"
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "ShowContextMenu" -Attribute "Tag" -Value "Customize"

    return $WidgetText
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

    $StyleText = $StyleText.Substring(0, $span.Start) +
        $replacement +
        $StyleText.Substring($span.End)

    return Hide-RadialBackdrop -StyleText $StyleText
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

    $single = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "SingleBarPageViewStyle").Text
    $bar = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "BarPageViewStyle").Text
    $container = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "RadialHotBarListItemContainer").Text
    $widget = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "ActionRadialWidgetTemplate_P8").Text

    $single = Convert-PageStyleToGrid -StyleText $single -Name "SingleBar"
    $bar = Convert-PageStyleToGrid -StyleText $bar -Name "HotBarRadial"
    $widget = Convert-WidgetChromeForGrid -WidgetText $widget

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
                   HorizontalAlignment="Center"
                   VerticalAlignment="Center"
                   Width="632"
                   Height="376"
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

    # Detailed semantic assertions are CI responsibilities. At install time,
    # generation only needs to produce syntactically valid XAML; source-game
    # compatibility was already checked before transformation.

    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $generated, $utf8NoBom)
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

Write-Host "Native-derived CAM controller grid package created."
Write-Host "  Game.pak:       $($gamePak.FullName)"
Write-Host "  Output:         $OutputPackage"
