$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Launcher = Join-Path $Root "tools\Install-BG3ControllerActionMenu.vbs"
$TestRoot = Join-Path $env:TEMP ("bg3-cam-standalone-vbs-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null

try {
    $standalone = Join-Path $TestRoot "Install-BG3ControllerActionMenu.vbs"
    Copy-Item -LiteralPath $Launcher -Destination $standalone -Force

    # Reproduce the operator contract exactly: one VBS in an otherwise empty
    # folder. ResolveOnly exercises the real GitHub release/bootstrap path
    # without touching BG3 installation or profile data.
    & cscript.exe //nologo $standalone --resolve-only --no-ui
    if ($LASTEXITCODE -ne 0) {
        $bootstrapLog = Join-Path $TestRoot "installer-work\launcher-bootstrap.log"
        $details = if (Test-Path -LiteralPath $bootstrapLog) {
            Get-Content -Raw -LiteralPath $bootstrapLog
        } else {
            "<bootstrap log missing>"
        }
        throw ("Standalone VBS resolve failed with exit code {0}. Details: {1}" -f $LASTEXITCODE, $details)
    }

    $stateRoot = Join-Path $TestRoot "installer-work"
    $bootstrapLog = Join-Path $stateRoot "launcher-bootstrap.log"
    $status = Join-Path $stateRoot "dev-status.txt"
    $entry = Join-Path $stateRoot "entry-cache\dev-entry.ps1"
    $metadata = Join-Path $stateRoot "entry-cache\active-release.json"

    foreach ($required in @($bootstrapLog, $status, $entry, $metadata)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Standalone VBS did not create required bootstrap artifact: $required"
        }
    }

    $bootstrapText = Get-Content -Raw -LiteralPath $bootstrapLog
    foreach ($requiredText in @(
        "Stage: resolving newest published development release",
        "Stage: downloading dev-entry.ps1",
        "Stage: running dev-entry.ps1",
        "dev-entry exit code: 0"
    )) {
        if (-not $bootstrapText.Contains($requiredText)) {
            throw "Standalone VBS bootstrap log is missing: $requiredText"
        }
    }

    $statusLines = @(Get-Content -LiteralPath $status -Encoding Unicode)
    if ($statusLines.Count -lt 2 -or $statusLines[0] -ne "SUCCESS") {
        throw "Standalone VBS did not preserve the universal entry success status."
    }

    $release = Get-Content -Raw -LiteralPath $metadata | ConvertFrom-Json
    $expected = ([string]$release.tag_name).TrimStart("v")
    if ($statusLines[1] -ne $expected) {
        throw "Standalone VBS resolved '$($statusLines[1])' but metadata identifies '$expected'."
    }

    Write-Host "Standalone one-file VBS bootstrap fixture passed for $expected."
} finally {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
