param(
    [string]$BasePackage = "",
    [string]$OutputPackage = "",
    [string]$GameInstallRoot = "",
    [string]$DivinePath = "",
    [string]$WorkRoot = "",
    [switch]$NoDownload,
    [string]$PatchOnlySourceXaml = "",
    [string]$PatchOnlyHotbarXaml = "",
    [string]$PatchOnlyDestinationXaml = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LslibVersion = "v1.20.4"
$LslibAsset = "ExportTool-$LslibVersion.zip"
$LslibUrl = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$LslibAsset"

$NativePath = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"
$ClairmontPath = "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"
$HotBarPaths = @(
    "Public/Game/GUI/Widgets/HotBar.xaml",
    "Public/Game/GUI/Widgets/HotBar_k.xaml"
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


function Get-NamedElementSpan {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $nameEscaped = [regex]::Escape($Name)
    $open = [regex]::Match(
        $Text,
        '<(?<tag>[A-Za-z_][A-Za-z0-9_.:-]*)\b[^>]*\bx:Name="' + $nameEscaped + '"[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $open.Success) {
        throw "Element x:Name='$Name' was not found."
    }

    return Get-ElementSpan -Text $Text -Tag $open.Groups["tag"].Value -AttributeName "x:Name" -AttributeValue $Name
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
    } elseif ($open.EndsWith("/>", [System.StringComparison]::Ordinal)) {
        $patched = $open.Substring(0, $open.Length - 2) + ' Visibility="Collapsed"/>'
    } else {
        $patched = $open.Substring(0, $open.Length - 1) + ' Visibility="Collapsed">'
    }
    return $StyleText.Substring(0, $match.Index) +
        $patched +
        $StyleText.Substring($match.Index + $match.Length)
}

function Disable-RadialCustomizationCommands {
    param([Parameter(Mandatory = $true)][string]$Text)

    # The copied native widget can contain dormant context-menu command bindings.
    # CAM has no radial-editor mode, so neutralize every mutation command even if a
    # future native template keeps the corresponding menu item around.
    foreach ($commandName in @(
        "ShowContextMenuCommand",
        "RequestAssignSlotCommand",
        "AssignSlotCommand",
        "SwapSlotCommand",
        "ClearSlotCommand",
        "AddRadialCommand",
        "RemoveRadialCommand"
    )) {
        $escaped = [regex]::Escape($commandName)
        $pattern = 'Command\s*=\s*"\{Binding[^"]*' + $escaped + '[^"]*\}"'
        $Text = [regex]::Replace($Text, $pattern, 'Command="{x:Null}"')
    }

    return $Text
}

function Convert-WidgetChromeForGrid {
    param([Parameter(Mandatory = $true)][string]$WidgetText)

    # Keep the installed game's controller-hint layout byte-for-byte. CAM only
    # removes the radial editor entry point; it does not reflow surviving hints.
    $contextMenuButton = Get-ElementSpan -Text $WidgetText -Tag "ls:LSButton" -AttributeName "x:Name" -AttributeValue "ShowContextMenu"
    $inertContextMenuButton = '<ls:LSButton x:Name="ShowContextMenu" Visibility="Collapsed" IsEnabled="False" IsHitTestVisible="False" Focusable="False" Width="0" Height="0" Command="{x:Null}"/>'
    $WidgetText = $WidgetText.Substring(0, $contextMenuButton.Start) +
        $inertContextMenuButton +
        $WidgetText.Substring($contextMenuButton.End)

    return Disable-RadialCustomizationCommands -Text $WidgetText
}


function New-AssignSelectorClone {
    param(
        [Parameter(Mandatory = $true)][string]$NativeSelectorText,
        [Parameter(Mandatory = $true)][string]$SelectorName,
        [Parameter(Mandatory = $true)][string]$ListName
    )

    $clone = $NativeSelectorText.Replace(
        'x:Name="SelectorAssign"',
        'x:Name="' + $SelectorName + '"'
    )
    $clone = $clone.Replace("ElementName=AssignList", "ElementName=$ListName")
    return $clone
}

function Assert-NativeHotbarContract {
    param([Parameter(Mandatory = $true)][string]$HotbarText)

    # These are operational inputs to generation, not a second semantic verifier:
    # if the current installed HotBar no longer exposes the required DCHotBar seams,
    # this generator cannot safely construct a controller filter surface.
    foreach ($required in @(
        "CurrentShownDeck",
        "SetCurrentShownDeckCommand",
        "CurrentSingleHotbarFilter",
        "SingleHotBar",
        "PassivesHotBar",
        "CommonHotBar",
        "ClassHotBar",
        "ItemHotBar",
        "FilterActionResourceCommand",
        "FilterCantripsCommand",
        "ActionResourcesCostPreview",
        "HighlightResourcesCommand",
        "ClearResourceHighlightsCommand"
    )) {
        if (-not $HotbarText.Contains($required)) {
            throw "Installed HotBar.xaml is missing required native seam '$required'."
        }
    }
}

function New-NativeHotbarFilterGrid {
    param([Parameter(Mandatory = $true)][string]$NativeAssignSelector)

    $selector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_HotbarSelector" -ListName "CAM_HotbarGrid"

    $catalog = @'
            <Grid x:Name="MainHotbarListHolder"
                  HorizontalAlignment="Center"
                  VerticalAlignment="Center"
                  Background="Transparent">
                <Grid x:Name="CAM_HotbarFocusRoot"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      Width="900"
                      Height="940"
                      Background="Transparent">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="72"/>
                        <RowDefinition Height="868"/>
                    </Grid.RowDefinitions>

                    <!-- These are native DCHotBar deck filters, not CAM-owned
                         action-source categories. Custom is deliberately absent. -->
                    <ls:LSListBox x:Name="CAM_DeckFilters"
                                  Grid.Row="0"
                                  HorizontalAlignment="Center"
                                  VerticalAlignment="Top"
                                  ActionPrevEvent="UITabPrev"
                                  ActionNextEvent="UITabNext"
                                  KeyboardNavigation.DirectionalNavigation="Cycle"
                                  SelectedIndex="0">
                        <ls:LSListBox.Resources>
                            <Style x:Key="CAM_DeckFilterItemStyle"
                                   TargetType="{x:Type ListBoxItem}"
                                   BasedOn="{StaticResource {x:Type ListBoxItem}}">
                                <Setter Property="Background" Value="Transparent"/>
                                <Setter Property="BorderBrush" Value="Transparent"/>
                                <Setter Property="Padding" Value="18,8"/>
                                <Setter Property="Opacity" Value="0.55"/>
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
                                        <Setter Property="Opacity" Value="1"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                        </ls:LSListBox.Resources>

                        <b:Interaction.Triggers>
                            <b:EventTrigger EventName="SelectionChanged">
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials"
                                                       FocusElement="{Binding ElementName=CAM_HotbarGrid}"/>
                            </b:EventTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_DeckFilters}" Value="0">
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_DeckFilters}" Value="1">
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_DeckFilters}" Value="2">
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"/>
                            </b:DataTrigger>
                        </b:Interaction.Triggers>

                        <ls:LSListBox.ItemsPanel>
                            <ItemsPanelTemplate>
                                <StackPanel Orientation="Horizontal"/>
                            </ItemsPanelTemplate>
                        </ls:LSListBox.ItemsPanel>

                        <ls:LSListBoxItem Style="{StaticResource CAM_DeckFilterItemStyle}">
                            <TextBlock Text="Common" FontSize="26"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem Style="{StaticResource CAM_DeckFilterItemStyle}">
                            <TextBlock Text="{Binding CurrentPlayer.SelectedCharacter.Stats.ClassList[0].ClassDisplayName}" FontSize="26"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem Style="{StaticResource CAM_DeckFilterItemStyle}">
                            <TextBlock Text="Items" FontSize="26"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem Style="{StaticResource CAM_DeckFilterItemStyle}">
                            <TextBlock Text="Passives" FontSize="26"/>
                        </ls:LSListBoxItem>
                    </ls:LSListBox>

                    <Grid Grid.Row="1"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Top"
                          Width="880"
                          Height="850"
                          Background="Transparent">
                        <ls:LSListBox x:Name="CAM_HotbarGrid"
                                      Background="Transparent"
                                      KeyboardNavigation.DirectionalNavigation="Contained"
                                      ActionNextEvent="UIDown"
                                      ActionPrevEvent="UIUp"
                                      SelectedIndex="0"
                                      LocalFocusSelector="{Binding ElementName=CAM_HotbarSelector,Mode=OneWay}"
                                      Tag="{Binding LocalFocus, ElementName=CAM_HotbarGrid}"
                                      HorizontalContentAlignment="Center"
                                      VerticalContentAlignment="Top"
                                      Height="830"
                                      Width="860"
                                      ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"
                                      ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"
                                      ItemsPanel="{StaticResource CAM_HotbarGridPanel}">
                            <ls:LSListBox.Style>
                                <Style TargetType="{x:Type ls:LSListBox}" BasedOn="{StaticResource {x:Type ls:LSListBox}}">
                                    <!-- Native filter/container/upcast results always win. -->
                                    <Setter Property="ItemsSource" Value="{Binding SingleHotBar.SlotList}"/>
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding SingleHotBar.SlotList.Count}" Value="0">
                                            <Setter Property="ItemsSource" Value="{Binding CurrentShownDeck.SlotList}"/>
                                        </DataTrigger>
                                        <MultiDataTrigger>
                                            <MultiDataTrigger.Conditions>
                                                <Condition Binding="{Binding SingleHotBar.SlotList.Count}" Value="0"/>
                                                <Condition Binding="{Binding SelectedIndex, ElementName=CAM_DeckFilters}" Value="3"/>
                                            </MultiDataTrigger.Conditions>
                                            <Setter Property="ItemsSource" Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"/>
                                        </MultiDataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </ls:LSListBox.Style>

                            <ls:LSListBox.ToolTip>
                                <ls:LSTooltip x:Name="CAM_HotbarTooltip"
                                              ToolTipService.Placement="Right"
                                              ToolTipService.HorizontalOffset="40"
                                              ToolTipService.VerticalOffset="-40"/>
                            </ls:LSListBox.ToolTip>

                            <ls:LSListBox.Template>
                                <ControlTemplate TargetType="{x:Type ListBox}">
                                    <ScrollViewer HorizontalScrollBarVisibility="Hidden"
                                                  VerticalScrollBarVisibility="Auto"
                                                  Template="{StaticResource ScrollViewerTemplate}">
                                        <ScrollViewer.Resources>
                                            <GridLength x:Key="Top">0</GridLength>
                                            <GridLength x:Key="Bottom">0</GridLength>
                                        </ScrollViewer.Resources>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </ControlTemplate>
                            </ls:LSListBox.Template>

                            <b:Interaction.Triggers>
                                <b:EventTrigger EventName="LocalFocusChanged">
                                    <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"
                                                           CommandParameter="{Binding Tag, ElementName=ActionRadials}"/>
                                    <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                </b:EventTrigger>
                                <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="60" TotalTicks="1">
                                    <b:ChangePropertyAction TargetName="CAM_HotbarTooltip"
                                                            PropertyName="Content"
                                                            Value="{Binding LocalFocus.DataContext.Content, ElementName=CAM_HotbarGrid}"/>
                                    <b:ChangePropertyAction TargetName="ActionRadials"
                                                            PropertyName="Tag"
                                                            Value="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"/>
                                    <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_HotbarGrid, Converter={StaticResource NullToBoolFalseConverter}}"
                                                           Command="{Binding HighlightResourcesCommand}"
                                                           CommandParameter="{Binding LocalFocus.DataContext, ElementName=CAM_HotbarGrid}"/>
                                    <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_HotbarGrid, Converter={StaticResource NullToBoolFalseConverter}}"
                                                           Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                                           CommandParameter="{Binding ., ElementName=CAM_HotbarGrid}"/>
                                </b:TimerTrigger>
                            </b:Interaction.Triggers>
                        </ls:LSListBox>

                        __CAM_HOTBAR_SELECTOR__
                    </Grid>
                </Grid>
            </Grid>
'@

    return $catalog.Replace("__CAM_HOTBAR_SELECTOR__", $selector)
}

function Convert-WidgetToHotbarFilterGrid {
    param(
        [Parameter(Mandatory = $true)][string]$WidgetText,
        [Parameter(Mandatory = $true)][string]$NativeAssignSelector
    )

    $WidgetText = Convert-WidgetChromeForGrid -WidgetText $WidgetText

    $main = Get-ElementSpan -Text $WidgetText -Tag "Grid" -AttributeName "x:Name" -AttributeValue "MainHotbarListHolder"
    $catalog = New-NativeHotbarFilterGrid -NativeAssignSelector $NativeAssignSelector
    $WidgetText = $WidgetText.Substring(0, $main.Start) +
        $catalog +
        $WidgetText.Substring($main.End)

    $slotAssign = Get-ElementSpan -Text $WidgetText -Tag "Control" -AttributeName "x:Name" -AttributeValue "SlotAssignHolder"
    $disabledSlotAssign = '<Control x:Name="SlotAssignHolder" Visibility="Collapsed" IsEnabled="False" Focusable="False"/>'
    $WidgetText = $WidgetText.Substring(0, $slotAssign.Start) +
        $disabledSlotAssign +
        $WidgetText.Substring($slotAssign.End)

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
        [Parameter(Mandatory = $true)][string]$HotbarSource,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $native = [System.IO.File]::ReadAllText($Source)
    $hotbar = [System.IO.File]::ReadAllText($HotbarSource)
    Assert-NativeHotbarContract -HotbarText $hotbar

    # Selector geometry stays locally derived from the current controller
    # assignment UI, while top-level data/commands come from DCHotBar slots.
    $assignSelector = (Get-NamedElementSpan -Text $native -Name "SelectorAssign").Text

    # The native second-stage list keeps the already proven radial-to-grid renderer.
    $single = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "SingleBarPageViewStyle").Text
    $widget = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "ActionRadialWidgetTemplate_P8").Text

    $single = Convert-PageStyleToGrid -StyleText $single -Name "SingleBar"
    $widget = Convert-WidgetToHotbarFilterGrid -WidgetText $widget -NativeAssignSelector $assignSelector

    $root = Get-RootOpenTag -Text $native

    $camResources = @'
    <!-- Nested SingleHotBar still uses the already-proven controller grid renderer. -->
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

    <!-- Top-level execution grid: one flat focus domain with enough vertical
         extent for arbitrary deck/filter results and native scrolling. -->
    <ItemsPanelTemplate x:Key="CAM_HotbarGridPanel">
        <ls:LSGrid ActionUpEvent="UIUp"
                   ActionDownEvent="UIDown"
                   ActionRightEvent="UIRight"
                   ActionLeftEvent="UILeft"
                   AutoIndex="True"
                   ContainerData="{Binding}"
                   HorizontalAlignment="Center"
                   VerticalAlignment="Top"
                   Columns="6"
                   CellWidth="120"
                   CellHeight="120"
                   HorizontalSpacing="8"
                   VerticalSpacing="8"
                   DisableScrolling="False"
                   EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"/>
    </ItemsPanelTemplate>
'@

    $generated = @"
$root
$camResources

$single

$widget
</ResourceDictionary>
"@

    # Install-time generation remains operational only. CI owns the semantic
    # assertions for automatic sources, focus, customization removal and A/B.
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $generated, $utf8NoBom)
}

if ($PatchOnlySourceXaml) {
    if (-not $PatchOnlyHotbarXaml) {
        throw "-PatchOnlyHotbarXaml is required with -PatchOnlySourceXaml."
    }
    if (-not $PatchOnlyDestinationXaml) {
        throw "-PatchOnlyDestinationXaml is required with -PatchOnlySourceXaml."
    }
    New-ControllerLibraryFromNative -Source $PatchOnlySourceXaml -HotbarSource $PatchOnlyHotbarXaml -Destination $PatchOnlyDestinationXaml
    Write-Host "Generated controller hotbar-filter grid library: $PatchOnlyDestinationXaml"
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
$hotbarSource = Join-Path $WorkRoot "native-HotBar.xaml"

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $nativeSource --packaged-path $NativePath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nativeSource)) {
    throw "Failed to extract native '$NativePath' from Game.pak."
}

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $clairmontSource --packaged-path $ClairmontPath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $clairmontSource)) {
    throw "Failed to extract native '$ClairmontPath' from Game.pak."
}

$hotbarExtracted = $false
foreach ($hotbarPath in $HotBarPaths) {
    if (Test-Path -LiteralPath $hotbarSource) {
        Remove-Item -LiteralPath $hotbarSource -Force
    }
    & $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $hotbarSource --packaged-path $hotbarPath --loglevel error
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $hotbarSource -PathType Leaf)) {
        $hotbarExtracted = $true
        break
    }
}
if (-not $hotbarExtracted) {
    throw "Failed to extract the current native HotBar.xaml contract from Game.pak."
}

$libraryPath = Join-Path $packageRoot "Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
New-ControllerLibraryFromNative -Source $nativeSource -HotbarSource $hotbarSource -Destination $libraryPath

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
