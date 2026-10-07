$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Runtime = Join-Path $Root "BG3ControllerActionMenu\Mods\BG3ControllerActionMenu\GUI\Library\Lib_Controller.xaml"

if (-not (Test-Path -LiteralPath $Runtime -PathType Leaf)) {
    throw "Missing runtime XAML: $Runtime"
}

$text = Get-Content -Raw -LiteralPath $Runtime

$resourceTabTemplate = [regex]::Match(
    $text,
    '<DataTemplate\b[^>]*x:Key="CAM_ResourceTabTemplate"[\s\S]*?</DataTemplate>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $resourceTabTemplate.Success) {
    throw "CAM_ResourceTabTemplate was not found."
}
if (-not $resourceTabTemplate.Value.Contains('<ls:LSButton Padding="0"') -or
    -not $resourceTabTemplate.Value.Contains('Margin="4,-10,4,10"') -or
    -not $resourceTabTemplate.Value.Contains('MaxActionPoints="{Binding MaxValue}"') -or
    -not $resourceTabTemplate.Value.Contains('AvailableActionPoints="{Binding Value}"') -or
    -not $resourceTabTemplate.Value.Contains('HighlightedActionPoints="{Binding DataContext.Cost, ElementName=Root}"') -or
    -not $resourceTabTemplate.Value.Contains('Style="{StaticResource ActionResourcesTemplateSelector}"') -or
    -not $resourceTabTemplate.Value.Contains('x:Name="ResourcesNumeralDisplay"') -or
    -not $resourceTabTemplate.Value.Contains('ElementName="ResourcePoints" Path="MaxGroupActionPoints"') -or
    -not $resourceTabTemplate.Value.Contains('<Trigger Property="IsMouseOver" Value="True">') -or
    $resourceTabTemplate.Value.Contains('IsSelected')) {
    throw "Resource tabs must use the literal captured HotBar quantity renderer without controller-selected visual state."
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
    throw "Expected exactly three preserved native HighlightResourcesCommand seams in HotBarList; found $($highlightActions.Count)."
}
foreach ($action in $highlightActions) {
    if (-not $action.Value.Contains('IsEnabled="False"')) {
        throw "Persistent controller focus must disable the mouse-HotBar HighlightResourcesCommand transport."
    }
}

$clearActions = @($invokeActions | Where-Object { $_.Value.Contains('ClearResourceHighlightsCommand') })
if ($clearActions.Count -lt 3) {
    throw "HotBarList must clear transient resource preview on ordinary focus and programmatic entry."
}

$localFocusEvent = [regex]::Match(
    $hotBarList.Value,
    '<b:EventTrigger EventName="LocalFocusChanged">[\s\S]*?</b:EventTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$localFocusTimer = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="LocalFocusChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$entryWake = [regex]::Match(
    $hotBarList.Value,
    '<b:TimerTrigger EventName="SelectionChanged" MillisecondsPerTick="70" TotalTicks="1">[\s\S]*?</b:TimerTrigger>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

foreach ($trigger in @($localFocusEvent, $localFocusTimer, $entryWake)) {
    if (-not $trigger.Success -or
        -not $trigger.Value.Contains('CreateFocusedTooltipDataCommand') -or
        -not $trigger.Value.Contains('ClearResourceHighlightsCommand')) {
        throw "Every CAM action-focus presentation boundary must keep tooltip data while clearing transient resource preview."
    }
}

if (-not $localFocusTimer.Value.Contains('Value="{Binding LocalFocus.DataContext, ElementName=HotBarList}"') -or
    -not $entryWake.Value.Contains('LocalFocus.DataContext')) {
    throw "Resting resource preview must not change LocalFocus.DataContext as the action identity authority."
}

Write-Host "Resting resource-tab preview contract passed."
