$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Temp = Join-Path $Root "build\deploy-xbox-test"
$FakeCache = Join-Path $Temp "Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw"
$Local = Join-Path $FakeCache "LocalCache\Local"
$Profile = Join-Path $Local "1234567890\PlayerProfiles\Public"
$Mods = Join-Path $Local "Mods"
$Settings = Join-Path $Profile "modsettings.lsx"
$FakePak = Join-Path $Temp "fixture.pak"
$OfficialPak = Join-Path $Mods "OfficialFixture.pak"
$DecoyDir = Join-Path $Mods "00000000-0000-0441-2693-069153013516"
$DecoySettings = Join-Path $DecoyDir "modsettings.lsx"
$Report = Join-Path $Temp "xbox-dev-environment.json"
$Uuid = "c4be2039-13bf-4413-8d4f-2642f86d4a8e"

if (Test-Path $Temp) {
    Remove-Item -Recurse -Force $Temp
}

New-Item -ItemType Directory -Force -Path $Profile | Out-Null
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
New-Item -ItemType Directory -Force -Path $DecoyDir | Out-Null
Set-Content -Path $FakePak -Value "fake CAM pak bytes" -NoNewline
Set-Content -Path $OfficialPak -Value "existing official pak evidence" -NoNewline

@'
<?xml version="1.0" encoding="UTF-8"?>
<save>
  <version major="4" minor="8" revision="0" build="700"/>
  <region id="ModPackageMetadata">
    <node id="root"/>
  </region>
</save>
'@ | Set-Content -Path $DecoySettings -Encoding UTF8

@'
<?xml version="1.0" encoding="UTF-8"?>
<save>
  <version major="4" minor="8" revision="0" build="700"/>
  <region id="ModuleSettings">
    <node id="root">
      <children>
        <node id="ModOrder">
          <children>
            <node id="Module">
              <attribute id="UUID" type="guid" value="11111111-1111-1111-1111-111111111111"/>
            </node>
          </children>
        </node>
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
$before = (Get-FileHash -Algorithm SHA256 $Settings).Hash

# Phase 1 must be read-only and should discover a unique evidence-backed target.
& $installer -PackageRoot $FakeCache -PackagePath $FakePak -ReportPath $Report

if (-not (Test-Path $Report)) {
    throw "Discovery report was not created."
}

$afterDiscovery = (Get-FileHash -Algorithm SHA256 $Settings).Hash
if ($afterDiscovery -ne $before) {
    throw "Discovery mode modified modsettings.lsx."
}

if (Test-Path (Join-Path $Mods "BG3ControllerActionMenu.pak")) {
    throw "Discovery mode copied the CAM package."
}

$reportJson = Get-Content -Raw $Report | ConvertFrom-Json
if (-not $reportJson.ReadyForApply) {
    throw "Fixture should be recognized as a safe apply target."
}
if ($reportJson.Roots.Count -ne 1) {
    throw "Fixture discovery should have exactly one candidate root."
}
if ($reportJson.Roots[0].Mods[0].PakCount -ne 1) {
    throw "Existing official PAK evidence was not detected."
}
if ($reportJson.Roots[0].ModSettings.Count -ne 2) {
    throw "Discovery should report both the package-local decoy and the real active order."
}
$usableSettings = @($reportJson.Roots[0].ModSettings | Where-Object { $_.WriteSchemaReady })
if ($usableSettings.Count -ne 1) {
    throw "Exactly one active load order should provide a reusable LSX write schema."
}
if ($usableSettings[0].Path -ne $Settings) {
    throw "Discovery selected the wrong modsettings.lsx candidate."
}
if ($usableSettings[0].WriteSchema.ModOrderUuidType -ne "guid" -or
    $usableSettings[0].WriteSchema.ModsUuidType -ne "guid" -or
    -not $usableSettings[0].WriteSchema.HasPublishHandle -or
    $usableSettings[0].WriteSchema.PublishHandleType -ne "uint64") {
    throw "Discovery did not preserve the donor modsettings.lsx schema."
}

# Phase 2 performs the write only when explicitly requested.
& $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -ReportPath $Report

$deployedPak = Join-Path $Mods "BG3ControllerActionMenu.pak"
if (-not (Test-Path $deployedPak)) {
    throw "Deployed CAM pak is missing."
}
if (-not (Test-Path $OfficialPak)) {
    throw "Existing official mod PAK was removed."
}

[xml]$xml = Get-Content -Raw $Settings
$orderOurs = @(
    $xml.SelectNodes("//node[@id='ModOrder']/children/node[@id='Module']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
$descOurs = @(
    $xml.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
$existing = @(
    $xml.SelectNodes("//attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq "11111111-1111-1111-1111-111111111111" }
)

if ($orderOurs.Count -ne 1) { throw "Expected one CAM ModOrder entry." }
if ($descOurs.Count -ne 1) { throw "Expected one CAM Mods entry." }
if ($existing.Count -ne 2) { throw "Existing unrelated mod was not preserved." }
if ($orderOurs[0].GetAttribute("type") -ne "guid") {
    throw "CAM ModOrder UUID did not mirror donor UUID type."
}
if ($descOurs[0].GetAttribute("type") -ne "guid") {
    throw "CAM ModuleShortDesc UUID did not mirror donor UUID type."
}
$camDesc = $descOurs[0].ParentNode
$camPublish = $camDesc.SelectSingleNode("attribute[@id='PublishHandle']")
if (-not $camPublish -or $camPublish.GetAttribute("type") -ne "uint64" -or $camPublish.GetAttribute("value") -ne "0") {
    throw "CAM PublishHandle did not mirror the proven donor schema."
}

# Repeat apply: no duplicate UUID entries may appear.
& $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -ReportPath $Report

[xml]$xml2 = Get-Content -Raw $Settings
$orderOurs2 = @(
    $xml2.SelectNodes("//node[@id='ModOrder']/children/node[@id='Module']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
$descOurs2 = @(
    $xml2.SelectNodes("//node[@id='Mods']/children/node[@id='ModuleShortDesc']/attribute[@id='UUID']") |
        Where-Object { $_.GetAttribute("value") -eq $Uuid }
)
if ($orderOurs2.Count -ne 1 -or $descOurs2.Count -ne 1) {
    throw "Apply is not idempotent."
}

$backups = @(Get-ChildItem (Join-Path $Profile "BG3ControllerActionMenu-backups") -Filter "modsettings.*.lsx")
if ($backups.Count -lt 1) {
    throw "modsettings backup was not created."
}

# Ambiguous profile layout must fail closed.
$OtherProfile = Join-Path $Local "9876543210\PlayerProfiles\Public"
$OtherSettings = Join-Path $OtherProfile "modsettings.lsx"
New-Item -ItemType Directory -Force -Path $OtherProfile | Out-Null
Copy-Item $Settings $OtherSettings -Force

$failedClosed = $false
try {
    & $installer -Apply -PackageRoot $FakeCache -PackagePath $FakePak -ReportPath $Report
} catch {
    if ($_.Exception.Message -like "*Refusing to modify Xbox data*") {
        $failedClosed = $true
    } else {
        throw
    }
}
if (-not $failedClosed) {
    throw "Ambiguous profile layout did not fail closed."
}

Write-Host "Xbox discovery/apply fixture tests passed."
