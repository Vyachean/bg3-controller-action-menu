$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Capture = Join-Path $Root "tools\capture-self-contained-inputs.ps1"

if (-not (Test-Path -LiteralPath $Capture -PathType Leaf)) {
    throw "Missing portable capture helper: $Capture"
}

$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $Capture,
    [ref]$tokens,
    [ref]$errors
)
if (@($errors).Count -gt 0) {
    throw "capture-self-contained-inputs.ps1 has PowerShell parse errors: $($errors[0].Message)"
}

$captureText = Get-Content -Raw -LiteralPath $Capture

foreach ($forbidden in @("%LOCALAPPDATA%", "BG3ControllerActionMenu\tools")) {
    if ($captureText.Contains($forbidden)) {
        throw "Developer capture must be portable and must not use machine-global installer state: $forbidden"
    }
}

foreach ($required in @(
    'capture-work',
    '*PreloadedActionRadials*.xaml',
    '*ActionRadials*.xaml',
    '*HotBar*.xaml',
    'Mods/MainUI/GUI/Pages/HotBar.xaml',
    'HotBarPage',
    '*DataTemplates*.xaml',
    '*ActionResourceTemplates*.xaml',
    '*Libs_*.xaml',
    '*Resource*.xaml',
    'Public/Game/GUI/Library/DataTemplates_k.xaml',
    'Public/Game/GUI/Library/DataTemplates_c.xaml',
    'Public/Game/GUI/Library/ActionResourceTemplates_c.xaml',
    '*FocusableControls*.xaml',
    '*Tooltips*.xaml',
    '*SpellBook*.xaml',
    '*Controller.xaml',
    '*Lib_Controller.xaml',
    'Get-ChildItem -LiteralPath $Root -Filter "Game.pak"',
    'Scanned PAKs: 1 (Game.pak only)',
    'capture-summary.txt',
    'hotbar-coverage-contract.json',
    'Get-HotBarCoverageReport',
    'SetCurrentShownDeckCommand',
    'FilterCantripsCommand',
    'FilterActionResourceCommand',
    'CommandParameter',
    'RadialAssignmentReferences',
    'CommandProbes',
    'MissingCommands',
    'InputTransportProbes',
    'MissingInputTransportSymbols',
    'SwitchWeaponSetCommand',
    'ToggleWeaponSet',
    'UISelectionLeft',
    'ControllerHoldButtonStyle',
    'WeaponSetSwitchStyle',
    'LSInputBinding',
    'HoldTimeShortcuts',
    'BoundEvent',
    'HoldTime',
    'TapTime',
    'EatInput',
    'RawTag',
    'SourceFile',
    'SchemaVersion = 3',
    'Missing research seams are evidence, not capture failures.',
    'CoverageSelfTest',
    'missing required UI groups',
    'No BG3 files, saves, profiles, or mods were modified.'
)) {
    if (-not $captureText.Contains($required)) {
        throw "Portable developer capture is missing required seam: $required"
    }
}

& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Capture -CoverageSelfTest
if ($LASTEXITCODE -ne 0) {
    throw "Fail-soft coverage discovery self-test failed with exit code $LASTEXITCODE."
}

Write-Host "Portable developer capture helper fixture passed."
