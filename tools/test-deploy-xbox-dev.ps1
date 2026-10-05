$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Temp = Join-Path $Root "build\deploy-xbox-test"
$FakeCache = Join-Path $Temp "Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw"
$Local = Join-Path $FakeCache "LocalCache\Local"
$Mods = Join-Path $Local "Mods"
$Profile = Join-Path $FakeCache "SystemAppData\xgs\000901FDE86FE763_fixture\PlayerProfiles\2535464828397411"
$Settings = Join-Path $Profile "modsettings.lsx"
$FakePak = Join-Path $Temp "fixture.pak"
$FakeOverlay = Join-Path $Temp "native-overlay-fixture.ps1"
$OfficialPak = Join-Path $Mods "OfficialFixture.pak"
$SecondPak = Join-Path $Mods "SecondFixture.pak"
$DecoyDir = Join-Path $Mods "00000000-0000-0441-2693-069153013516"
$DecoySettings = Join-Path $DecoyDir "modsettings.lsx"
$Report = Join-Path $Temp "xbox-dev-environment.json"
$Uuid = "c4be2039-13bf-4413-8d4f-2642f86d4a8e"
$ExistingUuid = "11111111-1111-1111-1111-111111111111"

if (Test-Path $Temp) {
    Remove-Item -Recurse -Force $Temp
}

New-Item -ItemType Directory -Force -Path $Profile | Out-Null
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
New-Item -ItemType Directory -Force -Path $DecoyDir | Out-Null
Set-Content -Path $FakePak -Value "fake CAM pak bytes" -NoNewline
@'
param(
    [Parameter(Mandatory = $true)][string]$BasePackage,
    [Parameter(Mandatory = $true)][string]$OutputPackage,
    [string]$GameInstallRoot
)
$parent = Split-Path -Parent $OutputPackage
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
Copy-Item -LiteralPath $BasePackage -Destination $OutputPackage -Force
'@ | Set-Content -Path $FakeOverlay -Encoding UTF8
Set-Content -Path $OfficialPak -Value "existing official pak evidence" -NoNewline
Set-Content -Path $SecondPak -Value "second existing pak evidence" -NoNewline

# A package-local file can look like a valid Mods-only modsettings file, but it
# is not the signed-in PlayerProfiles order and must never be selected for writes.
@'
<?xml version="1.0" encoding="UTF-8"?>
<save>
  <version major="4" minor="8" revision="0" build="100"/>
  <region id="ModuleSettings">
    <node id="root">
      <children>
        <node id="Mods">
          <children>
            <node id="ModuleShortDesc">
              <attribute id="Folder" type="LSString" value="PackageLocal"/>
              <attribute id="MD5" type="LSString" value=""/>
              <attribute id="Name" type="LSString" value="Package Local"/>
              <attribute id="PublishHandle" type="uint64" value="99"/>
              <attribute id="UUID" type="guid" value="99999999-9999-9999-9999-999999999999"/>
              <attribute id="Version64" type="int64" value="1"/>
            </node>
          </children>
        </node>
      </children>
    </node>
  </region>
</save>
'@ | Set-Content -Path $DecoySettings -Encoding UTF8

# This mirrors the current BG3 Mod Manager Mods-only template and the Xbox
# SystemAppData\xgs\...\PlayerProfiles\... shape observed on a real install.
@'
<?xml version="1.0" encoding="UTF-8"?>
<save>
  <version major="4" minor="8" revision="0" build="100"/>
  <region id="ModuleSettings">
    <node id="root">
      <children>
        <node id="Mods">
          <children>
            <node id="ModuleShortDesc">
              <attribute id="Folder" type="LSString" value="ExistingMod"/>
              <attribute id="MD5" type="LSString" value=""/>
              <attribute id="Name" type="LSString" value="Existing Mod"/>
              <attribute id="PublishHandle" type="uint64" value="42"/>
              <attribute id="UUID" type="guid" value="11111111-1111-1111-1111-111111111111"/>
              <attribute id="Version64" type="int64" value="1"/>
            </node>
          </children>
        </node>
      </children>
    </node>
  </region>
</save>
'@ | Set-Content -Path $Settings -Encoding UTF8

$installer = Join-Path $Root "tools\install-xbox-dev.ps1"
$settingsBefore = (Get-FileHash -Algorithm SHA256 $Settings).Hash
$decoyBefore = (Get-FileHash -Algorithm SHA256 $DecoySettings).Hash

# Phase 1 must be read-only and discover the signed-in PlayerProfiles order.
& $installer -PackageRoot $FakeCache -PackagePath $FakePak -ReportPath $Report

if (-not (Test-Path $Report)) { throw "Discovery report was not created." }
if ((Get-FileHash -Algorithm SHA256 $Settings).Hash -ne $settingsBefore) {
    throw "Discovery mode modified the Xbox profile modsettings.lsx."
}
if ((Get-FileHash -Algorithm SHA256 $DecoySettings).Hash -ne $decoyBefore) {
    throw "Discovery mode modified package-local modsettings.lsx."
}
if (Test-Path (Join-Path $Mods "BG3ControllerActionMenu.pak")) {
    throw "Discovery mode copied the CAM package."
}

$reportJson = Get-Content -Raw $Report | ConvertFrom-Json
if (-not $reportJson.ReadyForApply) {
    throw "Mods-only Xbox profile fixture should be recognized as a safe apply target."
}
if ($reportJson.Roots.Count -ne 1) { throw "Fixture discovery should have exactly one candidate root." }
if ($reportJson.Roots[0].Mods[0].PakCount -ne 2) {
    throw "Existing PAK evidence was not detected."
}
if ($reportJson.Roots[0].ModSettings.Count -ne 1) {
    throw "Package-local modsettings.lsx must be excluded from profile-order candidates."
}

$usable = $reportJson.Roots[0].SelectedModSettings
if (-not $usable -or $usable.Path -ne $Settings) {
    throw "Discovery did not select the SystemAppData PlayerProfiles order."
}
if ($usable.Layout -ne "ModsOnly" -or $usable.WriteSchema.Layout -ne "ModsOnly") {
    throw "Current Xbox profile should be recognized as the Mods-only layout."
}
if ($usable.WriteSchema.ModOrderUuidType) {
    throw "Mods-only Xbox schema unexpectedly requires ModOrder."
}
if ($usable.WriteSchema.ModsUuidType -ne "guid" -or
    -not $usable.WriteSchema.HasPublishHandle -or
    $usable.WriteSchema.PublishHandleType -ne "uint64") {
    throw "Discovery did not preserve the donor ModuleShortDesc schema."
}

# Phase 2 performs the write only when explicitly requested.
& $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -NativeOverlayPath $FakeOverlay -ReportPath $Report

$deployedPak = Join-Path $Mods "BG3ControllerActionMenu.pak"
if (-not (Test-Path $deployedPak)) { throw "Deployed CAM pak is missing." }
if (-not (Test-Path $OfficialPak) -or -not (Test-Path $SecondPak)) {
    throw "Existing mod PAKs were removed."
}
if ((Get-FileHash -Algorithm SHA256 $DecoySettings).Hash -ne $decoyBefore) {
    throw "Package-local modsettings.lsx was modified."
}

[xml]$xml = Get-Content -Raw $Settings
$modOrder = @($xml.SelectNodes("//node[@id='ModOrder']"))
$descOurs = @(
    $xml.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
$existing = @(
    $xml.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $ExistingUuid }
)

if ($modOrder.Count -ne 0) { throw "Installer invented a ModOrder node in a Mods-only Xbox profile." }
if ($descOurs.Count -ne 1) { throw "Expected one CAM ModuleShortDesc entry." }
if ($existing.Count -ne 1) { throw "Existing active mod was not preserved." }
if ($descOurs[0].GetAttribute("type") -ne "guid") {
    throw "CAM UUID did not mirror donor UUID type."
}
$camDesc = $descOurs[0].ParentNode
$camPublish = $camDesc.SelectSingleNode("attribute[@id='PublishHandle']")
if (-not $camPublish -or $camPublish.GetAttribute("type") -ne "uint64" -or $camPublish.GetAttribute("value") -ne "0") {
    throw "CAM PublishHandle did not mirror the proven donor schema."
}

# Repeat apply: no duplicate UUID entries and still no ModOrder.
& $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -NativeOverlayPath $FakeOverlay -ReportPath $Report

[xml]$xml2 = Get-Content -Raw $Settings
$descOurs2 = @(
    $xml2.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
if ($descOurs2.Count -ne 1 -or @($xml2.SelectNodes("//node[@id='ModOrder']")).Count -ne 0) {
    throw "Mods-only apply is not idempotent."
}

$backups = @(Get-ChildItem (Join-Path $Profile "BG3ControllerActionMenu-backups") -Filter "modsettings.*.lsx")
if ($backups.Count -lt 1) { throw "modsettings backup was not created." }

# Two writable PlayerProfiles orders are ambiguous and must fail closed.
$OtherProfile = Join-Path $FakeCache "SystemAppData\xgs\000901FDE86FE763_other\PlayerProfiles\9876543210"
$OtherSettings = Join-Path $OtherProfile "modsettings.lsx"
New-Item -ItemType Directory -Force -Path $OtherProfile | Out-Null
Copy-Item $Settings $OtherSettings -Force

$failedClosed = $false
try {
    & $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -NativeOverlayPath $FakeOverlay -ReportPath $Report
} catch {
    if ($_.Exception.Message -like "*Refusing to modify Xbox data*") {
        $failedClosed = $true
    } else {
        throw
    }
}
if (-not $failedClosed) { throw "Ambiguous Xbox profile layout did not fail closed." }

Write-Host "Xbox Mods-only discovery/apply fixture tests passed."
