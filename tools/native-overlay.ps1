param(
    [string]$BasePackage = "",
    [string]$OutputPackage = "",
    [string]$GameInstallRoot = "",
    [string]$DivinePath = "",
    [string]$WorkRoot = "",
    [switch]$NoDownload,
    [string]$PatchOnlySourceXaml = "",
    [string]$PatchOnlyHotBarSourceXaml = "",
    [string]$PatchOnlyDestinationXaml = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$LslibVersion = "v1.20.4"
$LslibAsset = "ExportTool-$LslibVersion.zip"
$LslibUrl = "https://github.com/Norbyte/lslib/releases/download/$LslibVersion/$LslibAsset"

$NativePath = "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml"
$ClairmontPath = "Public/Game/GUI/Override/Clairmont/Library/PreloadedActionRadials_c.xaml"
$KeyboardHotBarPath = "Mods/MainUI/GUI/Pages/HotBar.xaml"

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

    # Do not restyle ButtonHintsContainer. 0.0.36 moved it into a custom
    # horizontal/right-aligned composition and runtime proved that was wrong.
    # The installed Patch 8 template already owns the canonical right-stacked
    # controller hint layout; preserve it byte-for-byte except for the removed
    # radial-customisation entry point below.
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

function Assert-CurrentHotBarFilterContract {
    param([Parameter(Mandatory = $true)][string]$HotBarText)

    # This is a source-compatibility gate, not a post-pack installer verifier.
    # CAM consumes these exact current DCHotBar seams to obtain VMHotBarSlot
    # collections instead of feeding assignment-catalog objects to UseSlotCommand.
    foreach ($required in @(
        "CurrentPlayer.UIData.ActionResourcesCostPreview",
        "FilterActionResourceCommand",
        "FilterCantripsCommand",
        "SetCurrentShownDeckCommand",
        "ClearSingleHotbarCommand",
        "CurrentShownDeck",
        "SingleHotBar.SlotList",
        "CommonHotBar",
        "ClassHotBar",
        "ItemHotBar",
        "CurrentPlayer.SelectedCharacter.PassivesHotBar"
    )) {
        if (-not $HotBarText.Contains($required)) {
            throw "Installed Patch 8 HotBar.xaml is missing required filter seam: $required"
        }
    }
}

function Get-CurrentCantripFilterParameter {
    param([Parameter(Mandatory = $true)][string]$HotBarText)

    $commandIndex = $HotBarText.IndexOf("FilterCantripsCommand", [System.StringComparison]::Ordinal)
    if ($commandIndex -lt 0) {
        throw "Installed HotBar.xaml has no FilterCantripsCommand."
    }

    $windowStart = [Math]::Max(0, $commandIndex - 500)
    $windowLength = [Math]::Min(1800, $HotBarText.Length - $windowStart)
    $window = $HotBarText.Substring($windowStart, $windowLength)
    $match = [regex]::Match(
        $window,
        'CommandParameter\s*=\s*"(?<value>h[0-9A-Za-z]+)"',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $match.Success) {
        throw "Installed HotBar.xaml does not expose the cantrip filter parameter beside FilterCantripsCommand."
    }
    return $match.Groups["value"].Value
}

function Convert-NativeRadialFocusTriggerForGrid {
    param([Parameter(Mandatory = $true)][string]$NativeTriggerText)

    $trigger = $NativeTriggerText.Replace(
        "ElementName=HotBarRadial",
        "ElementName=CAM_FilteredSlotList"
    )

    # The radial tooltip target is a PageView templated parent. CAM's main list
    # is not a PageView, so drop only that presentation call. Keep the native
    # Tag writer, focused-tooltip-data command, resource highlight command and
    # controller hover sound exactly as supplied by the installed game.
    $trigger = [regex]::Replace(
        $trigger,
        '<b:InvokeCommandAction\b(?=[^>]*ShowTooltipOnUIElement)[^>]*/>\s*',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    return $trigger
}

function New-AutomaticActionCatalog {
    param(
        [Parameter(Mandatory = $true)][string]$NativeAssignSelector,
        [Parameter(Mandatory = $true)][string]$NativeMainFocusTrigger,
        [Parameter(Mandatory = $true)][string]$CantripFilterParameter
    )

    $mainSelector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_MainSelector" -ListName "HotBarList"

    $catalog = @'
            <Grid x:Name="MainHotbarListHolder"
                  HorizontalAlignment="Center"
                  VerticalAlignment="Center"
                  Background="Transparent">
                <Grid x:Name="CAM_AutoCatalogFocusRoot"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      Width="840"
                      Height="950"
                      Background="Transparent">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="72"/>
                        <RowDefinition Height="878"/>
                    </Grid.RowDefinitions>

                    <!-- These are native hotbar type filters, not separate data
                         catalogs. LB/RB changes one VMHotBar slot source. -->
                    <ls:LSListBox x:Name="CAM_FilterTabs"
                                  Grid.Row="0"
                                  HorizontalAlignment="Center"
                                  VerticalAlignment="Center"
                                  ActionPrevEvent="UITabPrev"
                                  ActionNextEvent="UITabNext"
                                  KeyboardNavigation.DirectionalNavigation="Cycle"
                                  SelectedIndex="0">
                        <ls:LSListBox.Resources>
                            <Style x:Key="CAM_FilterTabItemStyle"
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
                        <ls:LSListBox.ItemsPanel>
                            <ItemsPanelTemplate>
                                <StackPanel Orientation="Horizontal"/>
                            </ItemsPanelTemplate>
                        </ls:LSListBox.ItemsPanel>

                        <ls:LSListBoxItem x:Name="CAM_CommonFilterTab" Style="{StaticResource CAM_FilterTabItemStyle}">
                            <TextBlock Text="Common" FontSize="24"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem x:Name="CAM_ClassFilterTab">
                            <ls:LSListBoxItem.Style>
                                <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource CAM_FilterTabItemStyle}">
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding CurrentPlayer.SelectedCharacter.IsShapeShifted}" Value="True">
                                            <Setter Property="Visibility" Value="Collapsed"/>
                                            <Setter Property="Focusable" Value="False"/>
                                        </DataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </ls:LSListBoxItem.Style>
                            <TextBlock Text="{Binding CurrentPlayer.SelectedCharacter.Stats.ClassList[0].ClassDisplayName}" FontSize="24"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem x:Name="CAM_ItemsFilterTab" Style="{StaticResource CAM_FilterTabItemStyle}">
                            <TextBlock Text="Items" FontSize="24"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem x:Name="CAM_PassivesFilterTab" Style="{StaticResource CAM_FilterTabItemStyle}">
                            <TextBlock Text="Passives" FontSize="24"/>
                        </ls:LSListBoxItem>
                        <ls:LSListBoxItem x:Name="CAM_CantripsFilterTab" Style="{StaticResource CAM_FilterTabItemStyle}">
                            <TextBlock Text="{Binding Source='__CAM_CANTRIP_FILTER__', Converter={StaticResource TranslatedStringConverter}}" FontSize="24"/>
                        </ls:LSListBoxItem>
                    </ls:LSListBox>

                    <Grid x:Name="CAM_FilterContent"
                          Grid.Row="1"
                          Width="820"
                          Height="878"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Top">
                        <b:Interaction.Triggers>
                            <b:EventTrigger EventName="Loaded">
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:EventTrigger>

                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="0">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="CommonHotBar"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="1">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ClassHotBar"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="2">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:InvokeCommandAction Command="{Binding SetCurrentShownDeckCommand}" CommandParameter="ItemHotBar"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="3">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials" FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="4">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                <b:InvokeCommandAction Command="{Binding ClearSingleHotbarCommand}"/>
                                <b:InvokeCommandAction Command="{Binding FilterCantripsCommand}" CommandParameter="__CAM_CANTRIP_FILTER__"/>
                            </b:DataTrigger>
                        </b:Interaction.Triggers>

                        <!-- Exact assignment-screen navigation shell:
                             one outer LSListBox owns vertical continuation and
                             scrolling; inner lists use DirectionalNavigation=Continue. -->
                        <ls:LSListBox x:Name="HotBarList"
                                      Width="800"
                                      Height="850"
                                      SelectedIndex="1"
                                      Background="Transparent"
                                      KeyboardNavigation.DirectionalNavigation="Contained"
                                      ActionNextEvent="UIDown"
                                      ActionPrevEvent="UIUp"
                                      LocalFocusSelector="{Binding ElementName=CAM_MainSelector,Mode=OneWay}">
                            <ls:LSListBox.Template>
                                <ControlTemplate TargetType="{x:Type ListBox}">
                                    <ScrollViewer HorizontalScrollBarVisibility="Hidden"
                                                  VerticalScrollBarVisibility="Visible"
                                                  Padding="32,-46,0,-46"
                                                  Template="{StaticResource ScrollViewerTemplate}">
                                        <ScrollViewer.Resources>
                                            <GridLength x:Key="Top">0</GridLength>
                                            <GridLength x:Key="Bottom">0</GridLength>
                                        </ScrollViewer.Resources>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </ControlTemplate>
                            </ls:LSListBox.Template>
                            <ls:LSListBox.ItemsPanel>
                                <ItemsPanelTemplate>
                                    <ls:LSVirtualizingStackPanel/>
                                </ItemsPanelTemplate>
                            </ls:LSListBox.ItemsPanel>

                            <!-- Resource entries are the same VMActionResourceCostPreview
                                 objects used by keyboard HotBar.xaml. Moving focus over
                                 one applies the native FilterActionResourceCommand. -->
                            <ls:LSListBoxItem x:Name="CAM_ResourceFilterHolder"
                                              HorizontalAlignment="Center"
                                              Visibility="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview.Count, Converter={StaticResource CountToVisibilityConverter}}">
                                <ls:LSListBox x:Name="CAM_ResourceFilterList"
                                              ItemsSource="{Binding CurrentPlayer.UIData.ActionResourcesCostPreview}"
                                              KeyboardNavigation.DirectionalNavigation="Continue"
                                              Template="{StaticResource ScrolllessListBox}"
                                              ItemContainerStyle="{StaticResource CAM_ResourceFilterContainer}"
                                              ItemsPanel="{StaticResource CAM_ResourceFilterPanel}">
                                    <b:Interaction.Triggers>
                                        <b:EventTrigger EventName="LocalFocusChanged">
                                            <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                            <b:InvokeCommandAction Command="{Binding ClearResourceHighlightsCommand}"/>
                                            <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_ResourceFilterList, Converter={StaticResource NullToBoolFalseConverter}}"
                                                                   Command="{Binding FilterActionResourceCommand}"
                                                                   CommandParameter="{Binding LocalFocus.DataContext, ElementName=CAM_ResourceFilterList}"/>
                                            <ls:LSPlaySound Sound="UI_Shared_Hover"/>
                                        </b:EventTrigger>
                                    </b:Interaction.Triggers>
                                </ls:LSListBox>
                            </ls:LSListBoxItem>

                            <!-- Only VMHotBarSlot collections enter gameplay dispatch. -->
                            <ls:LSListBoxItem x:Name="CAM_FilteredSlotHolder"
                                              HorizontalAlignment="Center">
                                <ls:LSListBox x:Name="CAM_FilteredSlotList"
                                              KeyboardNavigation.DirectionalNavigation="Continue"
                                              Template="{StaticResource ScrolllessListBox}"
                                              ItemContainerStyle="{StaticResource CAM_ActionGridSlotContainer}"
                                              ItemTemplate="{StaticResource CAM_ActionGridSlotTemplate}"
                                              ItemsPanel="{StaticResource CAM_ActionGridPanel}">
                                    <ls:LSListBox.Style>
                                        <Style TargetType="{x:Type ls:LSListBox}" BasedOn="{StaticResource {x:Type ls:LSListBox}}">
                                            <Setter Property="ItemsSource" Value="{Binding CurrentShownDeck.SlotList}"/>
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="3">
                                                    <Setter Property="ItemsSource" Value="{Binding CurrentPlayer.SelectedCharacter.PassivesHotBar.SlotList}"/>
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_FilterTabs}" Value="4">
                                                    <Setter Property="ItemsSource" Value="{x:Null}"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </ls:LSListBox.Style>
                                    <b:Interaction.Triggers>
                                        __CAM_MAIN_FOCUS_TRIGGER__
                                    </b:Interaction.Triggers>
                                </ls:LSListBox>
                            </ls:LSListBoxItem>
                        </ls:LSListBox>
                        __CAM_MAIN_SELECTOR__
                    </Grid>
                </Grid>
            </Grid>
'@

    $catalog = $catalog.Replace("__CAM_MAIN_SELECTOR__", $mainSelector)
    $catalog = $catalog.Replace("__CAM_MAIN_FOCUS_TRIGGER__", $NativeMainFocusTrigger)
    $catalog = $catalog.Replace("__CAM_CANTRIP_FILTER__", $CantripFilterParameter)
    return $catalog
}

function Convert-WidgetToAutomaticCatalog {
    param(
        [Parameter(Mandatory = $true)][string]$WidgetText,
        [Parameter(Mandatory = $true)][string]$NativeAssignSelector,
        [Parameter(Mandatory = $true)][string]$NativeMainFocusTrigger,
        [Parameter(Mandatory = $true)][string]$CantripFilterParameter
    )

    $WidgetText = Convert-WidgetChromeForGrid -WidgetText $WidgetText

    $main = Get-ElementSpan -Text $WidgetText -Tag "Grid" -AttributeName "x:Name" -AttributeValue "MainHotbarListHolder"
    $catalog = New-AutomaticActionCatalog -NativeAssignSelector $NativeAssignSelector -NativeMainFocusTrigger $NativeMainFocusTrigger -CantripFilterParameter $CantripFilterParameter
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
        [Parameter(Mandatory = $true)][string]$HotBarFilterSource,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $native = [System.IO.File]::ReadAllText($Source)
    $hotBar = [System.IO.File]::ReadAllText($HotBarFilterSource)
    Assert-CurrentHotBarFilterContract -HotBarText $hotBar
    $cantripFilterParameter = Get-CurrentCantripFilterParameter -HotBarText $hotBar

    # Reuse the exact installed assignment selector geometry for the one outer
    # navigation shell. The main cells themselves are VMHotBarSlot objects.
    $assignSelector = (Get-NamedElementSpan -Text $native -Name "SelectorAssign").Text

    # Reuse the current radial focus lifecycle instead of reconstructing
    # gameplay-facing actions. This keeps ActionRadials.Tag, focused tooltip
    # data, resource preview and hover sound aligned with vanilla.
    $nativeMainRadial = (Get-NamedElementSpan -Text $native -Name "HotBarRadial").Text
    $nativeMainInteractions = Get-FirstInteractionTriggers -Text $nativeMainRadial
    $nativeMainFocusTrigger = (Get-ElementSpan -Text $nativeMainInteractions -Tag "b:EventTrigger" -AttributeName "EventName" -AttributeValue "LocalFocusChanged").Text
    $nativeMainFocusTrigger = Convert-NativeRadialFocusTriggerForGrid -NativeTriggerText $nativeMainFocusTrigger

    # Nested variants/upcasts/filtered SingleHotBar state keeps the same
    # radial-to-grid conversion and therefore receives VMHotBarSlot objects too.
    $single = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "SingleBarPageViewStyle").Text
    $widget = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "ActionRadialWidgetTemplate_P8").Text

    $single = Convert-PageStyleToGrid -StyleText $single -Name "SingleBar"
    $widget = Convert-WidgetToAutomaticCatalog -WidgetText $widget -NativeAssignSelector $assignSelector -NativeMainFocusTrigger $nativeMainFocusTrigger -CantripFilterParameter $cantripFilterParameter

    $root = Get-RootOpenTag -Text $native

    $camResources = @'
    <Style x:Key="CAM_ActionGridSlotContainer"
           TargetType="{x:Type ListBoxItem}"
           BasedOn="{StaticResource {x:Type ListBoxItem}}">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="Transparent"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Focusable" Value="True"/>
        <Setter Property="Padding" Value="0"/>
        <!-- Native radial focus actions pass LocalFocus.Tag to DCHotBar. -->
        <Setter Property="Tag" Value="{Binding .}"/>
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

    <!-- No fixed Height: the installed assignment shell owns scrolling, so
         arbitrarily many rows remain reachable in both directions. -->
    <ItemsPanelTemplate x:Key="CAM_ActionGridPanel">
        <ls:LSGrid ActionUpEvent="UIUp"
                   ActionDownEvent="UIDown"
                   ActionRightEvent="UIRight"
                   ActionLeftEvent="UILeft"
                   AutoIndex="True"
                   ContainerData="{Binding}"
                   HorizontalAlignment="Center"
                   VerticalAlignment="Top"
                   Width="632"
                   Columns="5"
                   CellWidth="120"
                   CellHeight="120"
                   HorizontalSpacing="8"
                   VerticalSpacing="8"
                   DisableScrolling="True"
                   EmptyCellTemplate="{DynamicResource EmptyCellTemplate}"/>
    </ItemsPanelTemplate>

    <Style x:Key="CAM_ResourceFilterContainer"
           TargetType="{x:Type ListBoxItem}"
           BasedOn="{StaticResource {x:Type ListBoxItem}}">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="Transparent"/>
        <Setter Property="Focusable" Value="True"/>
        <Setter Property="Tag" Value="{Binding .}"/>
        <Setter Property="ContentTemplate" Value="{StaticResource CAM_ResourceFilterTemplate}"/>
        <Style.Triggers>
            <DataTrigger Binding="{Binding ActionResource.MaxValue}" Value="0">
                <Setter Property="Visibility" Value="Collapsed"/>
                <Setter Property="Focusable" Value="False"/>
            </DataTrigger>
        </Style.Triggers>
    </Style>

    <DataTemplate x:Key="CAM_ResourceFilterTemplate">
        <Grid Width="104" Height="104" Background="Transparent">
            <ls:LSActionPointResources Background="Transparent"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"
                                       MaxActionPoints="{Binding ActionResource.MaxValue}"
                                       AvailableActionPoints="{Binding ActionResource.Value}"
                                       HighlightedActionPoints="{Binding Cost}"
                                       DataContext="{Binding ActionResource}"
                                       MaxActionPointGroups="0"
                                       Style="{StaticResource ActionResourcesTemplateSelector}"/>
            <TextBlock Text="{Binding ActionResource.Name}"
                       HorizontalAlignment="Center"
                       VerticalAlignment="Bottom"
                       TextAlignment="Center"
                       TextWrapping="Wrap"
                       MaxWidth="104"
                       FontSize="16"/>
        </Grid>
    </DataTemplate>

    <ItemsPanelTemplate x:Key="CAM_ResourceFilterPanel">
        <ls:LSGrid ActionUpEvent="UIUp"
                   ActionDownEvent="UIDown"
                   ActionRightEvent="UIRight"
                   ActionLeftEvent="UILeft"
                   AutoIndex="True"
                   ContainerData="{Binding}"
                   HorizontalAlignment="Center"
                   VerticalAlignment="Top"
                   Width="760"
                   Columns="6"
                   CellWidth="120"
                   CellHeight="120"
                   HorizontalSpacing="8"
                   VerticalSpacing="8"
                   DisableScrolling="True"/>
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
    # assertions; this step only derives exact current native seams.
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $generated, $utf8NoBom)
}

if ($PatchOnlySourceXaml) {
    if (-not $PatchOnlyHotBarSourceXaml) {
        throw "-PatchOnlyHotBarSourceXaml is required with -PatchOnlySourceXaml."
    }
    if (-not $PatchOnlyDestinationXaml) {
        throw "-PatchOnlyDestinationXaml is required with -PatchOnlySourceXaml."
    }
    New-ControllerLibraryFromNative -Source $PatchOnlySourceXaml -HotBarFilterSource $PatchOnlyHotBarSourceXaml -Destination $PatchOnlyDestinationXaml
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
$hotBarFilterSource = Join-Path $WorkRoot "native-HotBar.xaml"

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $nativeSource --packaged-path $NativePath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nativeSource)) {
    throw "Failed to extract native '$NativePath' from Game.pak."
}

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $clairmontSource --packaged-path $ClairmontPath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $clairmontSource)) {
    throw "Failed to extract native '$ClairmontPath' from Game.pak."
}

& $divine --game bg3 --action extract-single-file --source $gamePak.FullName --destination $hotBarFilterSource --packaged-path $KeyboardHotBarPath --loglevel error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $hotBarFilterSource)) {
    throw "Failed to extract native '$KeyboardHotBarPath' from Game.pak."
}

$libraryPath = Join-Path $packageRoot "Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"
New-ControllerLibraryFromNative -Source $nativeSource -HotBarFilterSource $hotBarFilterSource -Destination $libraryPath

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
