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

    foreach ($change in @(
        @("HorizontalAlignment", "Right"),
        @("HorizontalContentAlignment", "Right"),
        @("VerticalAlignment", "Bottom"),
        @("Width", "Auto"),
        @("FlowDirection", "RightToLeft"),
        @("Margin", "26,0,26,56")
    )) {
        $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:AlignableWrapPanel" -Name "ButtonHintsContainer" -Attribute $change[0] -Value $change[1]
    }

    foreach ($buttonName in @(
        "SelectButtonVisual",
        "CancelConcentrationButton",
        "ToggleWeaponSet",
        "ToggleDualWield",
        "CancelButton"
    )) {
        $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name $buttonName -Attribute "Width" -Value "Auto"
    }

    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "SelectButtonVisual" -Attribute "Margin" -Value "0,0,20,0"
    $WidgetText = Set-NamedElementAttribute -Text $WidgetText -Tag "ls:LSButton" -Name "CancelButton" -Attribute "Margin" -Value "0"

    # Preserve the native element name/type for template compatibility, but remove
    # the ContextMenu input binding itself. X is not an editor entry point in CAM.
    $contextMenuButton = Get-ElementSpan -Text $WidgetText -Tag "ls:LSButton" -AttributeName "x:Name" -AttributeValue "ShowContextMenu"
    $inertContextMenuButton = '<ls:LSButton x:Name="ShowContextMenu" Visibility="Collapsed" IsEnabled="False" IsHitTestVisible="False" Focusable="False" Width="0" Height="0" Command="{x:Null}"/>'
    $WidgetText = $WidgetText.Substring(0, $contextMenuButton.Start) +
        $inertContextMenuButton +
        $WidgetText.Substring($contextMenuButton.End)

    return Disable-RadialCustomizationCommands -Text $WidgetText
}
function Rename-NativeResource {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$OldKey,
        [Parameter(Mandatory = $true)][string]$NewKey
    )

    return $Text.Replace(
        'x:Key="' + $OldKey + '"',
        'x:Key="' + $NewKey + '"'
    )
}

function Convert-SpellGroupTemplateForCatalog {
    param([Parameter(Mandatory = $true)][string]$TemplateText)

    $TemplateText = Rename-NativeResource -Text $TemplateText -OldKey "SpellGroupListTemplate" -NewKey "CAM_SpellGroupListTemplate"
    $TemplateText = $TemplateText.Replace(
        "{StaticResource AvailableSlotContainer}",
        "{StaticResource CAM_AvailableSlotContainer}"
    )
    $TemplateText = $TemplateText.Replace(
        "{StaticResource AvailableSlotsListPanelTemplate}",
        "{StaticResource CAM_AvailableSlotsListPanelTemplate}"
    )

    return $TemplateText
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

function New-AutomaticActionCatalog {
    param([Parameter(Mandatory = $true)][string]$NativeAssignSelector)

    $actionsSelector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_ActionsSelector" -ListName "HotBarList"
    $itemsSelector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_ItemsSelector" -ListName "CAM_InventoryListbox"
    $passivesSelector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_PassivesSelector" -ListName "CAM_PassivesListbox"
    $metamagicSelector = New-AssignSelectorClone -NativeSelectorText $NativeAssignSelector -SelectorName "CAM_MetamagicSelector" -ListName "CAM_MetamagicListbox"

    $catalog = @'
            <Grid x:Name="MainHotbarListHolder"
                  HorizontalAlignment="Center"
                  VerticalAlignment="Center"
                  Background="Transparent">
                <Grid x:Name="CAM_AutoCatalogFocusRoot"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      Width="820"
                      Height="940"
                      Background="Transparent">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="70"/>
                        <RowDefinition Height="870"/>
                    </Grid.RowDefinitions>

                    <!-- Controller tabs choose which native source owns focus.
                         They never classify or copy gameplay actions. -->
                    <DockPanel x:Name="CAM_TabHeader"
                               Grid.Row="0"
                               HorizontalAlignment="Center"
                               VerticalAlignment="Top"
                               LastChildFill="True">
                        <ContentPresenter x:Name="CAM_TabPrevHint"
                                          DockPanel.Dock="Left"
                                          ContentTemplate="{StaticResource ControllerButtonHint}"
                                          Content="{Binding CurrentPlayer.UIData.InputEvents, ConverterParameter=UITabPrev, Converter={StaticResource FindInputEventConverter}}"
                                          Focusable="False"
                                          Margin="0,0,16,0"/>
                        <ContentPresenter x:Name="CAM_TabNextHint"
                                          DockPanel.Dock="Right"
                                          ContentTemplate="{StaticResource ControllerButtonHint}"
                                          Content="{Binding CurrentPlayer.UIData.InputEvents, ConverterParameter=UITabNext, Converter={StaticResource FindInputEventConverter}}"
                                          Focusable="False"
                                          Margin="16,0,0,0"/>

                        <ls:LSListBox x:Name="CAM_TabList"
                                      HorizontalAlignment="Center"
                                      VerticalAlignment="Center"
                                      ActionPrevEvent="UITabPrev"
                                      ActionNextEvent="UITabNext"
                                      KeyboardNavigation.DirectionalNavigation="Cycle"
                                      SelectedIndex="0">
                            <ls:LSListBox.Resources>
                                <Style x:Key="CAM_TabItemStyle"
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
                                    <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                </b:EventTrigger>
                            </b:Interaction.Triggers>

                            <ls:LSListBox.ItemsPanel>
                                <ItemsPanelTemplate>
                                    <StackPanel Orientation="Horizontal"/>
                                </ItemsPanelTemplate>
                            </ls:LSListBox.ItemsPanel>

                            <ls:LSListBoxItem x:Name="CAM_ActionsTab">
                                <ls:LSListBoxItem.Style>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource CAM_TabItemStyle}">
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.SpellsAndActions.Count}" Value="0">
                                                <Setter Property="Visibility" Value="Collapsed"/>
                                                <Setter Property="Focusable" Value="False"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </ls:LSListBoxItem.Style>
                                <TextBlock Text="Actions / Spells" FontSize="26"/>
                            </ls:LSListBoxItem>

                            <ls:LSListBoxItem x:Name="CAM_ItemsTab">
                                <ls:LSListBoxItem.Style>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource CAM_TabItemStyle}">
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding CurrentPlayer.SelectedCharacter.Inventory.Slots.Count}" Value="0">
                                                <Setter Property="Visibility" Value="Collapsed"/>
                                                <Setter Property="Focusable" Value="False"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </ls:LSListBoxItem.Style>
                                <TextBlock Text="Items" FontSize="26"/>
                            </ls:LSListBoxItem>

                            <ls:LSListBoxItem x:Name="CAM_PassivesTab">
                                <ls:LSListBoxItem.Style>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource CAM_TabItemStyle}">
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding (b:Interaction.Behaviors)[0].FilteredItems.Count, ElementName=CAM_PassivesFocusRoot}" Value="0">
                                                <Setter Property="Visibility" Value="Collapsed"/>
                                                <Setter Property="Focusable" Value="False"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </ls:LSListBoxItem.Style>
                                <TextBlock Text="Passives" FontSize="26"/>
                            </ls:LSListBoxItem>

                            <ls:LSListBoxItem x:Name="CAM_MetamagicTab">
                                <ls:LSListBoxItem.Style>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource CAM_TabItemStyle}">
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding (b:Interaction.Behaviors)[0].FilteredItems.Count, ElementName=CAM_MetamagicFocusRoot}" Value="0">
                                                <Setter Property="Visibility" Value="Collapsed"/>
                                                <Setter Property="Focusable" Value="False"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </ls:LSListBoxItem.Style>
                                <TextBlock Text="Metamagic" FontSize="26"/>
                            </ls:LSListBoxItem>
                        </ls:LSListBox>
                    </DockPanel>

                    <Grid x:Name="CAM_TabContent"
                          Grid.Row="1"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Top"
                          Width="820"
                          Height="870">
                        <b:Interaction.Triggers>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="0">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials"
                                                       FocusElement="{Binding ElementName=HotBarList}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="1">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials"
                                                       FocusElement="{Binding ElementName=CAM_InventoryListbox}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="2">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials"
                                                       FocusElement="{Binding ElementName=CAM_PassivesListbox}"/>
                            </b:DataTrigger>
                            <b:DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="3">
                                <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                <ls:SetMoveFocusAction TargetName="ActionRadials"
                                                       FocusElement="{Binding ElementName=CAM_MetamagicListbox}"/>
                            </b:DataTrigger>
                        </b:Interaction.Triggers>

                        <!-- Actions/spells keep the native HotBarList name so the
                             native page's initial focus handoff remains intact. -->
                        <Grid x:Name="CAM_ActionsFocusRoot"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Top"
                              Width="800"
                              Height="850"
                              Background="Transparent">
                            <Grid.Style>
                                <Style TargetType="{x:Type Grid}">
                                    <Setter Property="Visibility" Value="Collapsed"/>
                                    <Setter Property="IsEnabled" Value="False"/>
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="0">
                                            <Setter Property="Visibility" Value="Visible"/>
                                            <Setter Property="IsEnabled" Value="True"/>
                                        </DataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </Grid.Style>

                            <ls:LSListBox x:Name="HotBarList"
                                          ItemsSource="{Binding CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.SpellsAndActions}"
                                          Background="Transparent"
                                          KeyboardNavigation.DirectionalNavigation="Contained"
                                          ActionNextEvent="UIDown"
                                          ActionPrevEvent="UIUp"
                                          SelectedIndex="0"
                                          LocalFocusSelector="{Binding ElementName=CAM_ActionsSelector,Mode=OneWay}"
                                          Tag="{Binding LocalFocus, ElementName=HotBarList}"
                                          Height="850"
                                          Width="800">
                                <ls:LSListBox.ToolTip>
                                    <ls:LSTooltip x:Name="CAM_ActionsTooltip"
                                                  ToolTipService.Placement="Right"
                                                  ToolTipService.HorizontalOffset="40"
                                                  ToolTipService.VerticalOffset="-40"/>
                                </ls:LSListBox.ToolTip>
                                <ls:LSListBox.Template>
                                    <ControlTemplate TargetType="{x:Type ListBox}">
                                        <ScrollViewer HorizontalScrollBarVisibility="Hidden"
                                                      VerticalScrollBarVisibility="Visible"
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
                                <ls:LSListBox.ItemContainerStyle>
                                    <Style TargetType="{x:Type ListBoxItem}" BasedOn="{StaticResource {x:Type ListBoxItem}}">
                                        <Setter Property="Background" Value="Transparent"/>
                                        <Setter Property="Template" Value="{StaticResource CAM_SpellGroupListTemplate}"/>
                                        <Style.Triggers>
                                            <Trigger Property="IsSelected" Value="True">
                                                <Setter Property="Background" Value="Transparent"/>
                                                <Setter Property="BorderBrush" Value="Transparent"/>
                                            </Trigger>
                                            <DataTrigger Binding="{Binding Actions.Count}" Value="0">
                                                <Setter Property="Visibility" Value="Collapsed"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </ls:LSListBox.ItemContainerStyle>
                                <b:Interaction.Triggers>
                                    <b:EventTrigger EventName="LocalFocusChanged">
                                        <b:ChangePropertyAction TargetName="CAM_ActionsTooltip"
                                                                PropertyName="Content"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"/>
                                        <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=HotBarList, Converter={StaticResource NullToBoolFalseConverter}}"
                                                               Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                                               CommandParameter="{Binding ., ElementName=HotBarList}"/>
                                        <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                    </b:EventTrigger>
                                    <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                                        <b:ChangePropertyAction TargetName="ActionRadials"
                                                                PropertyName="Tag"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"/>
                                    </b:TimerTrigger>
                                </b:Interaction.Triggers>
                            </ls:LSListBox>
                            __CAM_ACTIONS_SELECTOR__
                        </Grid>

                        <Grid x:Name="CAM_ItemsFocusRoot"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Top"
                              Width="800"
                              Height="850"
                              Background="Transparent">
                            <Grid.Style>
                                <Style TargetType="{x:Type Grid}">
                                    <Setter Property="Visibility" Value="Collapsed"/>
                                    <Setter Property="IsEnabled" Value="False"/>
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="1">
                                            <Setter Property="Visibility" Value="Visible"/>
                                            <Setter Property="IsEnabled" Value="True"/>
                                        </DataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </Grid.Style>

                            <ls:LSListBox x:Name="CAM_InventoryListbox"
                                          ItemsSource="{Binding CurrentPlayer.SelectedCharacter.Inventory.Slots}"
                                          Style="{StaticResource CAM_InventoryGrid}"
                                          KeyboardNavigation.DirectionalNavigation="Contained"
                                          ActionNextEvent="UIDown"
                                          ActionPrevEvent="UIUp"
                                          SelectedIndex="0"
                                          LocalFocusSelector="{Binding ElementName=CAM_ItemsSelector,Mode=OneWay}"
                                          Tag="{Binding LocalFocus, ElementName=CAM_InventoryListbox}"
                                          Template="{StaticResource ScrolllessListBox}"
                                          ItemsPanel="{StaticResource CAM_AvailableSlotsListPanelTemplate}">
                                <ls:LSListBox.ToolTip>
                                    <ls:LSTooltip x:Name="CAM_ItemsTooltip"
                                                  ToolTipService.Placement="Right"
                                                  ToolTipService.HorizontalOffset="40"
                                                  ToolTipService.VerticalOffset="-40"/>
                                </ls:LSListBox.ToolTip>
                                <b:Interaction.Triggers>
                                    <b:PropertyChangedTrigger Binding="{Binding FocusIndex, ElementName=CAM_InventoryListbox}">
                                        <ls:LSPlaySound Sound="UI_Shared_Hover"/>
                                    </b:PropertyChangedTrigger>
                                    <b:EventTrigger EventName="LocalFocusChanged">
                                        <b:ChangePropertyAction TargetName="CAM_ItemsTooltip"
                                                                PropertyName="Content"
                                                                Value="{Binding LocalFocus.DataContext.Object, ElementName=CAM_InventoryListbox}"/>
                                        <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_InventoryListbox, Converter={StaticResource NullToBoolFalseConverter}}"
                                                               Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                                               CommandParameter="{Binding ., ElementName=CAM_InventoryListbox}"/>
                                        <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                    </b:EventTrigger>
                                    <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                                        <b:ChangePropertyAction TargetName="ActionRadials"
                                                                PropertyName="Tag"
                                                                Value="{Binding LocalFocus.DataContext.Object, ElementName=CAM_InventoryListbox}"/>
                                    </b:TimerTrigger>
                                </b:Interaction.Triggers>
                            </ls:LSListBox>
                            __CAM_ITEMS_SELECTOR__
                        </Grid>

                        <Grid x:Name="CAM_PassivesFocusRoot"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Top"
                              Width="800"
                              Height="850"
                              Background="Transparent">
                            <Grid.Style>
                                <Style TargetType="{x:Type Grid}">
                                    <Setter Property="Visibility" Value="Collapsed"/>
                                    <Setter Property="IsEnabled" Value="False"/>
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="2">
                                            <Setter Property="Visibility" Value="Visible"/>
                                            <Setter Property="IsEnabled" Value="True"/>
                                        </DataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </Grid.Style>
                            <b:Interaction.Behaviors>
                                <ls:CollectionFilterBehavior x:Name="CAM_PassivesFilter"
                                                             ItemsSource="{Binding CurrentPlayer.SelectedCharacter.Stats.Passives}"
                                                             Predicate="{Binding Data.TogglablePassivePredicate}"/>
                            </b:Interaction.Behaviors>

                            <ls:LSListBox x:Name="CAM_PassivesListbox"
                                          ItemsSource="{Binding (b:Interaction.Behaviors)[0].FilteredItems, ElementName=CAM_PassivesFocusRoot}"
                                          KeyboardNavigation.DirectionalNavigation="Contained"
                                          ActionNextEvent="UIDown"
                                          ActionPrevEvent="UIUp"
                                          SelectedIndex="0"
                                          LocalFocusSelector="{Binding ElementName=CAM_PassivesSelector,Mode=OneWay}"
                                          Tag="{Binding LocalFocus, ElementName=CAM_PassivesListbox}"
                                          Template="{StaticResource ScrolllessListBox}"
                                          Visibility="{Binding (b:Interaction.Behaviors)[0].FilteredItems.Count, ElementName=CAM_PassivesFocusRoot, Converter={StaticResource CountToVisibilityConverter}}"
                                          ItemContainerStyle="{StaticResource CAM_AvailableSlotContainer}"
                                          ItemsPanel="{StaticResource CAM_AvailableSlotsListPanelTemplate}">
                                <ls:LSListBox.ToolTip>
                                    <ls:LSTooltip x:Name="CAM_PassivesTooltip"
                                                  ToolTipService.Placement="Right"
                                                  ToolTipService.HorizontalOffset="40"
                                                  ToolTipService.VerticalOffset="-40"/>
                                </ls:LSListBox.ToolTip>
                                <b:Interaction.Triggers>
                                    <b:PropertyChangedTrigger Binding="{Binding FocusIndex, ElementName=CAM_PassivesListbox}">
                                        <ls:LSPlaySound Sound="UI_Shared_Hover"/>
                                    </b:PropertyChangedTrigger>
                                    <b:EventTrigger EventName="LocalFocusChanged">
                                        <b:ChangePropertyAction TargetName="CAM_PassivesTooltip"
                                                                PropertyName="Content"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=CAM_PassivesListbox}"/>
                                        <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_PassivesListbox, Converter={StaticResource NullToBoolFalseConverter}}"
                                                               Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                                               CommandParameter="{Binding ., ElementName=CAM_PassivesListbox}"/>
                                        <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                    </b:EventTrigger>
                                    <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                                        <b:ChangePropertyAction TargetName="ActionRadials"
                                                                PropertyName="Tag"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=CAM_PassivesListbox}"/>
                                    </b:TimerTrigger>
                                </b:Interaction.Triggers>
                            </ls:LSListBox>
                            __CAM_PASSIVES_SELECTOR__
                        </Grid>

                        <Grid x:Name="CAM_MetamagicFocusRoot"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Top"
                              Width="800"
                              Height="850"
                              Background="Transparent">
                            <Grid.Style>
                                <Style TargetType="{x:Type Grid}">
                                    <Setter Property="Visibility" Value="Collapsed"/>
                                    <Setter Property="IsEnabled" Value="False"/>
                                    <Style.Triggers>
                                        <DataTrigger Binding="{Binding SelectedIndex, ElementName=CAM_TabList}" Value="3">
                                            <Setter Property="Visibility" Value="Visible"/>
                                            <Setter Property="IsEnabled" Value="True"/>
                                        </DataTrigger>
                                    </Style.Triggers>
                                </Style>
                            </Grid.Style>
                            <b:Interaction.Behaviors>
                                <ls:CollectionFilterBehavior x:Name="CAM_MetaMagicFilter"
                                                             ItemsSource="{Binding CurrentPlayer.SelectedCharacter.Stats.Passives}"
                                                             Predicate="{Binding Data.TogglableMetaMagicPassivePredicate}"/>
                            </b:Interaction.Behaviors>

                            <ls:LSListBox x:Name="CAM_MetamagicListbox"
                                          ItemsSource="{Binding (b:Interaction.Behaviors)[0].FilteredItems, ElementName=CAM_MetamagicFocusRoot}"
                                          KeyboardNavigation.DirectionalNavigation="Contained"
                                          ActionNextEvent="UIDown"
                                          ActionPrevEvent="UIUp"
                                          SelectedIndex="0"
                                          LocalFocusSelector="{Binding ElementName=CAM_MetamagicSelector,Mode=OneWay}"
                                          Tag="{Binding LocalFocus, ElementName=CAM_MetamagicListbox}"
                                          Template="{StaticResource ScrolllessListBox}"
                                          Visibility="{Binding (b:Interaction.Behaviors)[0].FilteredItems.Count, ElementName=CAM_MetamagicFocusRoot, Converter={StaticResource CountToVisibilityConverter}}"
                                          ItemContainerStyle="{StaticResource CAM_AvailableSlotContainer}"
                                          ItemsPanel="{StaticResource CAM_AvailableSlotsListPanelTemplate}">
                                <ls:LSListBox.ToolTip>
                                    <ls:LSTooltip x:Name="CAM_MetamagicTooltip"
                                                  ToolTipService.Placement="Right"
                                                  ToolTipService.HorizontalOffset="40"
                                                  ToolTipService.VerticalOffset="-40"/>
                                </ls:LSListBox.ToolTip>
                                <b:Interaction.Triggers>
                                    <b:PropertyChangedTrigger Binding="{Binding FocusIndex, ElementName=CAM_MetamagicListbox}">
                                        <ls:LSPlaySound Sound="UI_Shared_Hover"/>
                                    </b:PropertyChangedTrigger>
                                    <b:EventTrigger EventName="LocalFocusChanged">
                                        <b:ChangePropertyAction TargetName="CAM_MetamagicTooltip"
                                                                PropertyName="Content"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=CAM_MetamagicListbox}"/>
                                        <b:InvokeCommandAction IsEnabled="{Binding LocalFocus, ElementName=CAM_MetamagicListbox, Converter={StaticResource NullToBoolFalseConverter}}"
                                                               Command="{Binding ShowTooltipOnUIElementCommand, RelativeSource={RelativeSource AncestorType={x:Type ls:UIWidget}}}"
                                                               CommandParameter="{Binding ., ElementName=CAM_MetamagicListbox}"/>
                                        <b:ChangePropertyAction TargetName="ActionRadials" PropertyName="Tag" Value="{x:Null}"/>
                                    </b:EventTrigger>
                                    <b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">
                                        <b:ChangePropertyAction TargetName="ActionRadials"
                                                                PropertyName="Tag"
                                                                Value="{Binding LocalFocus.DataContext, ElementName=CAM_MetamagicListbox}"/>
                                    </b:TimerTrigger>
                                </b:Interaction.Triggers>
                            </ls:LSListBox>
                            __CAM_METAMAGIC_SELECTOR__
                        </Grid>
                    </Grid>
                </Grid>
            </Grid>
'@

    return $catalog.
        Replace("__CAM_ACTIONS_SELECTOR__", $actionsSelector).
        Replace("__CAM_ITEMS_SELECTOR__", $itemsSelector).
        Replace("__CAM_PASSIVES_SELECTOR__", $passivesSelector).
        Replace("__CAM_METAMAGIC_SELECTOR__", $metamagicSelector)
}

function Convert-WidgetToAutomaticCatalog {
    param(
        [Parameter(Mandatory = $true)][string]$WidgetText,
        [Parameter(Mandatory = $true)][string]$NativeAssignSelector
    )

    $WidgetText = Convert-WidgetChromeForGrid -WidgetText $WidgetText

    $main = Get-ElementSpan -Text $WidgetText -Tag "Grid" -AttributeName "x:Name" -AttributeValue "MainHotbarListHolder"
    $catalog = New-AutomaticActionCatalog -NativeAssignSelector $NativeAssignSelector
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
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $native = [System.IO.File]::ReadAllText($Source)

    # Main catalog resources are taken from the exact installed assignment UI.
    $availableSlotContainer = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "AvailableSlotContainer").Text
    $availableSlotsPanel = (Get-ElementSpan -Text $native -Tag "ItemsPanelTemplate" -AttributeName "x:Key" -AttributeValue "AvailableSlotsListPanelTemplate").Text
    $spellGroupTemplate = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "SpellGroupListTemplate").Text
    $inventoryCellTemplate = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "InventoryCellTemplate").Text
    $inventoryGrid = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "InventoryGrid").Text
    $assignSelector = (Get-NamedElementSpan -Text $native -Name "SelectorAssign").Text

    $availableSlotContainer = Rename-NativeResource -Text $availableSlotContainer -OldKey "AvailableSlotContainer" -NewKey "CAM_AvailableSlotContainer"
    $availableSlotsPanel = Rename-NativeResource -Text $availableSlotsPanel -OldKey "AvailableSlotsListPanelTemplate" -NewKey "CAM_AvailableSlotsListPanelTemplate"
    $spellGroupTemplate = Convert-SpellGroupTemplateForCatalog -TemplateText $spellGroupTemplate

    $inventoryCellTemplate = Rename-NativeResource -Text $inventoryCellTemplate -OldKey "InventoryCellTemplate" -NewKey "CAM_InventoryCellTemplate"
    $inventoryGrid = Rename-NativeResource -Text $inventoryGrid -OldKey "InventoryGrid" -NewKey "CAM_InventoryGrid"
    $inventoryGrid = $inventoryGrid.Replace(
        "{StaticResource InventoryCellTemplate}",
        "{StaticResource CAM_InventoryCellTemplate}"
    )

    # Only the native second-stage list still needs the radial-to-grid renderer.
    $single = (Get-ElementSpan -Text $native -Tag "Style" -AttributeName "x:Key" -AttributeValue "SingleBarPageViewStyle").Text
    $widget = (Get-ElementSpan -Text $native -Tag "ControlTemplate" -AttributeName "x:Key" -AttributeValue "ActionRadialWidgetTemplate_P8").Text

    $single = Convert-PageStyleToGrid -StyleText $single -Name "SingleBar"
    $widget = Convert-WidgetToAutomaticCatalog -WidgetText $widget -NativeAssignSelector $assignSelector

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
'@

    $generated = @"
$root
$camResources

$availableSlotContainer

$availableSlotsPanel

$spellGroupTemplate

$inventoryCellTemplate

$inventoryGrid

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
