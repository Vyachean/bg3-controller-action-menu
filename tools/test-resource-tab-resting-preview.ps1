$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Runtime = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"

if (-not (Test-Path -LiteralPath $Runtime -PathType Leaf)) {
    throw "Missing runtime XAML: $Runtime"
}

$text = Get-Content -Raw -LiteralPath $Runtime

# Source-exact keyboard glyph presentation nests a DataTemplate inside the
# outer CAM_ResourceTabTemplate. Count nested closing tags instead of taking
# the first </DataTemplate>, so quantity and selected-state assertions run
# against the entire original HotBar item.
$resourceTabHeader = [regex]::Match(
    $text,
    '<DataTemplate\b[^>]*x:Key="CAM_ResourceTabTemplate"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$resourceTabTemplate = [pscustomobject]@{ Success = $false; Value = "" }
if ($resourceTabHeader.Success) {
    $startOffset = $resourceTabHeader.Index + $resourceTabHeader.Length
    $tail = $text.Substring($startOffset)
    $depth = 1
    foreach ($tag in [regex]::Matches($tail, '</?DataTemplate\b[^>]*>')) {
        if ($tag.Value.StartsWith('</DataTemplate')) {
            $depth--
        } elseif (-not $tag.Value.EndsWith('/>')) {
            $depth++
        }
        if ($depth -eq 0) {
            $resourceTabTemplate = [pscustomobject]@{
                Success = $true
                Value = $text.Substring(
                    $resourceTabHeader.Index,
                    $resourceTabHeader.Length + $tag.Index + $tag.Length
                )
            }
            break
        }
    }
}


if (-not $resourceTabTemplate.Success) {
    throw "CAM_ResourceTabTemplate was not found."
}
if (-not $resourceTabTemplate.Value.Contains('<ls:LSButton Padding="0"') -or
    -not $resourceTabTemplate.Value.Contains('Margin="4,-10,4,10"') -or
    -not $resourceTabTemplate.Value.Contains('MaxActionPoints="{Binding MaxValue}"') -or
    -not $resourceTabTemplate.Value.Contains('AvailableActionPoints="{Binding Value}"') -or
    -not $resourceTabTemplate.Value.Contains('HighlightedActionPoints="0"') -or
    -not $resourceTabTemplate.Value.Contains('Style="{StaticResource ActionResourcesTemplateSelector}"') -or
    -not $resourceTabTemplate.Value.Contains('x:Name="ResourcesNumeralDisplay"') -or
    -not $resourceTabTemplate.Value.Contains('ElementName="ResourcePoints" Path="MaxGroupActionPoints"') -or
    -not $resourceTabTemplate.Value.Contains('<Trigger Property="IsMouseOver" Value="True">')) {
    throw "Resource tabs must retain the literal captured HotBar quantity renderer."
}
# Persistent resource tabs display native available/max quantities without
# permanently inheriting BG3's focused-action cost. Ordinary HUD preview is separate.
# Container selection changes only the image chrome, never action identity.
$selectedChrome = '<Condition Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType={x:Type ListBoxItem}}}" Value="True"/>'
$specialGuard = '<Condition Binding="{Binding Tag, ElementName=CAM_ProviderModeMarker}" Value="{x:Null}"/>'
if (-not $resourceTabTemplate.Value.Contains($selectedChrome) -or
    -not $resourceTabTemplate.Value.Contains($specialGuard) -or
    $resourceTabTemplate.Value.Contains('HighlightedActionPoints="{Binding IsSelected') -or
    $resourceTabTemplate.Value.Contains('DataContext="{Binding IsSelected')) {
    throw "Controller selection may affect native Bg/BgHL chrome only, never the quantity preview or action identity."
}

$hotBarList = [regex]::Match(
    $text,
    '<ls:LSListBox\b[^>]*x:Name="HotBarList"[\s\S]*?</ls:LSListBox>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $hotBarList.Success) {
    throw "HotBarList was not found."
}

$invokeActions = [regex]::Matches(
    $hotBarList.Value,
    '<b:InvokeCommandAction\b[\s\S]*?/>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$highlightActions = @($invokeActions | Where-Object { $_.Value.Contains('HighlightResourcesCommand') })
if ($highlightActions.Count -ne 3) {
    throw "Expected three game-owned action-cost highlight seams, found $($highlightActions.Count)."
}

$focusEvent = @(
    [regex]::Matches(
        $hotBarList.Value,
        '<b:EventTrigger EventName="LocalFocusChanged">[\s\S]*?</b:EventTrigger>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    ) | Where-Object { $_.Value.Contains('CreateFocusedTooltipDataCommand') -and $_.Value.Contains('ClearResourceHighlightsCommand') }
) | Select-Object -First 1
$focusTimer = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$entryWake = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

if (-not $focusEvent.Success -or -not $focusTimer.Success -or -not $entryWake.Success) {
    throw "Expected current focus/entry ownership boundaries."
}
# An immediate focus change only invalidates prior predictions. The game's
# active cost preview is established when that same native VMHotBarSlot has
# survived the existing 70ms focus delay.
if (-not $focusEvent.Value.Contains('ClearResourceHighlightsCommand') -or
    -not $focusEvent.Value.Contains('IsEnabled="False"') -or
    -not $focusEvent.Value.Contains('CreateFocusedTooltipDataCommand')) {
    throw "Immediate focus transition must clear old cost and not preview a transient slot."
}
foreach ($deferred in @($focusTimer, $entryWake)) {
    if (-not $deferred.Value.Contains('Command="{Binding DataContext.HighlightResourcesCommand') -or
        -not $deferred.Value.Contains('CommandParameter="{Binding LocalFocus.DataContext, ElementName=HotBarList}"') -or
        -not $deferred.Value.Contains('CreateFocusedTooltipDataCommand') -or
        $deferred.Value.Contains('ClearResourceHighlightsCommand') -or
        $deferred.Value.Contains('IsEnabled="False"')) {
        throw "Stable focused VMHotBarSlot must request native cost, without clearing it in the same tick."
    }
}
if (-not $focusTimer.Value.Contains('Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"') -or
    -not $entryWake.Value.Contains('LocalFocus.DataContext')) {
    throw "Cost preview may never change the authoritative action slot/focus identity."
}
if ($resourceTabTemplate.Value.Contains('HighlightedActionPoints="{Binding DataContext.Cost') -or
    -not $resourceTabTemplate.Value.Contains('AvailableActionPoints="{Binding Value}"')) {
    throw "Upper navigation tabs must retain resting quantities independent of HUD action-cost preview."
}

Write-Host "Native HUD cost feedback / resting upper tab contract passed."
