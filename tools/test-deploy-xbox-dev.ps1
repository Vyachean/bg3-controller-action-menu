$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Temp = Join-Path $Root "build\deploy-xbox-test"
$FakeCache = Join-Path $Temp "Packages\LarianStudiosGamesLtd.baldurssgate3_551z37b1dechw"
$Local = Join-Path $FakeCache "LocalCache\Local"
$Profile = Join-Path $Local "1234567890\PlayerProfiles\Public"
$Mods = Join-Path $Local "Mods"
$Settings = Join-Path $Profile "modsettings.lsx"
$FakePak = Join-Path $Temp "fixture.pak"
$Uuid = "c4be2039-13bf-4413-8d4f-2642f86d4a8e"

if (Test-Path $Temp) {
    Remove-Item -Recurse -Force $Temp
}

New-Item -ItemType Directory -Force -Path $Profile | Out-Null
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
Set-Content -Path $FakePak -Value "fake pak bytes" -NoNewline

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
              <attribute id="UUID" type="FixedString" value="11111111-1111-1111-1111-111111111111"/>
            </node>
          </children>
        </node>
        <node id="Mods">
          <children>
            <node id="ModuleShortDesc">
              <attribute id="Folder" type="LSString" value="ExistingMod"/>
              <attribute id="MD5" type="LSString" value=""/>
              <attribute id="Name" type="LSString" value="Existing Mod"/>
              <attribute id="UUID" type="FixedString" value="11111111-1111-1111-1111-111111111111"/>
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

& $installer -CacheRoot $FakeCache -ModSettingsPath $Settings -PackagePath $FakePak

if ($LASTEXITCODE -ne 0) {
    throw "First deploy failed."
}

$deployedPak = Join-Path $Mods "BG3ControllerActionMenu.pak"
if (-not (Test-Path $deployedPak)) {
    throw "Deployed pak is missing."
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

# Run a second time to prove idempotence and duplicate removal.
& $installer -CacheRoot $FakeCache -ModSettingsPath $Settings -PackagePath $FakePak
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
    throw "Deploy is not idempotent."
}

$backups = @(Get-ChildItem (Join-Path $Profile "BG3ControllerActionMenu-backups") -Filter "modsettings.*.lsx")
if ($backups.Count -lt 1) {
    throw "modsettings backup was not created."
}

Write-Host "Xbox dev deploy fixture test passed."
