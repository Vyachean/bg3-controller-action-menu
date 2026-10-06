$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Launcher = Join-Path $Root "tools\Capture-BG3ControllerArtifacts.vbs"
$Capture = Join-Path $Root "tools\capture-self-contained-inputs.ps1"

foreach ($path in @($Launcher, $Capture)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing portable capture component: $path"
    }
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

$launcherOutput = & cscript.exe //nologo $Launcher --self-test
if ($LASTEXITCODE -ne 0 -or ($launcherOutput -join [Environment]::NewLine) -notmatch "syntax OK") {
    throw "Developer capture VBScript launcher self-test failed."
}

$captureText = Get-Content -Raw -LiteralPath $Capture
$launcherText = Get-Content -Raw -LiteralPath $Launcher

foreach ($forbidden in @("%LOCALAPPDATA%", "BG3ControllerActionMenu\\tools")) {
    if ($captureText.Contains($forbidden) -or $launcherText.Contains($forbidden)) {
        throw "Developer capture must be portable and must not use machine-global installer state: $forbidden"
    }
}

foreach ($required in @(
    'capture-work',
    '*PreloadedActionRadials*.xaml',
    '*ActionRadials*.xaml',
    '*HotBar*.xaml',
    '*DataTemplates.xaml',
    '*Controller.xaml',
    '*Lib_Controller.xaml',
    'No BG3 files, saves, profiles, or mods were modified.'
)) {
    if (-not $captureText.Contains($required)) {
        throw "Portable developer capture is missing required seam: $required"
    }
}

if (-not $launcherText.Contains('capture-self-contained-inputs.ps1') -or
    -not $launcherText.Contains('Upload this ZIP to the development chat.')) {
    throw "Developer capture VBS does not expose the intended one-click capture flow."
}

Write-Host "Portable developer capture fixture passed."
