param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureArchive,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Overlay = Join-Path $RepoRoot "tools\native-overlay.ps1"

if (-not (Test-Path -LiteralPath $CaptureArchive -PathType Leaf)) {
    throw "Capture archive does not exist: $CaptureArchive"
}
$CaptureArchive = (Resolve-Path -LiteralPath $CaptureArchive).Path

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $RepoRoot "build\self-contained-reference"
}
if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path

$ExtractRoot = Join-Path $OutputRoot "capture"
Expand-Archive -LiteralPath $CaptureArchive -DestinationPath $ExtractRoot -Force

$manifestPath = Join-Path $ExtractRoot "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    $manifestPath = Get-ChildItem -LiteralPath $ExtractRoot -Filter "manifest.json" -File -Recurse | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $manifestPath) { throw "Capture archive does not contain manifest.json." }

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$manifestDir = Split-Path -Parent $manifestPath

function Resolve-CapturedMatch {
    param(
        [Parameter(Mandatory = $true)][string]$ExactPackagedPath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $matches = @($manifest.Matches | Where-Object {
        ([string]$_.PackagedPath).Replace("\", "/").Equals($ExactPackagedPath, [System.StringComparison]::OrdinalIgnoreCase)
    })

    if ($matches.Count -ne 1) {
        $available = @($manifest.Matches | Where-Object { ([string]$_.PackagedPath) -match [regex]::Escape($Label) } | ForEach-Object { [string]$_.PackagedPath })
        throw "Capture must contain exactly one '$ExactPackagedPath' ($Label); found $($matches.Count). Nearby captured paths: $($available -join '; ')"
    }

    $relative = ([string]$matches[0].RelativeCapturedPath).Replace("/", "\")
    $path = Join-Path $manifestDir $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Manifest points to a missing captured file: $path"
    }

    return [pscustomobject]@{ Manifest = $matches[0]; Path = (Resolve-Path -LiteralPath $path).Path }
}

$radial = Resolve-CapturedMatch -ExactPackagedPath "Public/Game/GUI/Library/PreloadedActionRadials_c.xaml" -Label "PreloadedActionRadials"
$hotBar = Resolve-CapturedMatch -ExactPackagedPath "Mods/MainUI/GUI/Pages/HotBar.xaml" -Label "HotBar"

$referenceLibrary = Join-Path $OutputRoot "Lib_Controller.reference.xaml"
& $Overlay -PatchOnlySourceXaml $radial.Path -PatchOnlyHotBarSourceXaml $hotBar.Path -PatchOnlyDestinationXaml $referenceLibrary
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $referenceLibrary -PathType Leaf)) {
    throw "Failed to generate the development reference controller library."
}

$hotBarText = Get-Content -Raw -LiteralPath $hotBar.Path
$cantripElement = [regex]::Match($hotBarText, '<(?<tag>[A-Za-z_][A-Za-z0-9_.:-]*)\b(?=[^>]*Command\s*=\s*"\{Binding\s+FilterCantripsCommand\}")[^>]*>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$cantripParameter = $null
if ($cantripElement.Success) {
    $parameterMatch = [regex]::Match($cantripElement.Value, 'CommandParameter\s*=\s*"(?<value>[^"]+)"')
    if ($parameterMatch.Success) { $cantripParameter = $parameterMatch.Groups["value"].Value }
}

$evidence = [ordered]@{
    SchemaVersion = 1
    GamePackageVersion = $manifest.GamePackageVersion
    CaptureCreatedAtUtc = $manifest.CreatedAtUtc
    Radial = [ordered]@{ PackagedPath = [string]$radial.Manifest.PackagedPath; Sha256 = [string]$radial.Manifest.Sha256 }
    HotBar = [ordered]@{ PackagedPath = [string]$hotBar.Manifest.PackagedPath; Sha256 = [string]$hotBar.Manifest.Sha256 }
    CantripFilterParameter = $cantripParameter
    ReferenceLibrarySha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $referenceLibrary).Hash.ToLowerInvariant()
    Note = "Development-only reference generated from captured current-game evidence. Do not commit captured raw XAML or this reference verbatim as copied game source."
}
$evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputRoot "evidence.json") -Encoding UTF8

Write-Host "Self-contained migration reference prepared."
Write-Host "  Evidence:  $(Join-Path $OutputRoot 'evidence.json')"
Write-Host "  Reference: $referenceLibrary"
Write-Host ""
Write-Host "Next: author/review project-owned runtime XAML from this evidence, then run the self-contained release gate."
