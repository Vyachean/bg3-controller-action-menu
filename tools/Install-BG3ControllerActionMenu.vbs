Option Explicit

' Universal development shortcut.
' This is the only operator-facing file. It resolves the newest published
' development release, downloads that release's dev-entry.ps1, and runs it.
' All changeable development behavior lives behind dev-entry.ps1.

Dim shell, fso, baseDir, stateRoot, cacheRoot
Dim bootstrapLogPath, logPath, statusPath, reportPath, metadataPath, entryPath
Dim psCommand, command, exitCode, resolveOnly, noUi, i
Dim state, version, message, stream, bootstrapLog

resolveOnly = False
noUi = False

For i = 0 To WScript.Arguments.Count - 1
    Select Case LCase(WScript.Arguments(i))
        Case "--self-test"
            WScript.Echo "universal development launcher syntax OK"
            WScript.Quit 0
        Case "--resolve-only"
            resolveOnly = True
        Case "--no-ui"
            noUi = True
    End Select
Next

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
stateRoot = fso.BuildPath(baseDir, "installer-work")
cacheRoot = fso.BuildPath(stateRoot, "entry-cache")
bootstrapLogPath = fso.BuildPath(stateRoot, "launcher-bootstrap.log")
logPath = fso.BuildPath(stateRoot, "dev-task.log")
statusPath = fso.BuildPath(stateRoot, "dev-status.txt")
reportPath = fso.BuildPath(stateRoot, "dev-report.json")
metadataPath = fso.BuildPath(cacheRoot, "active-release.json")
entryPath = fso.BuildPath(cacheRoot, "dev-entry.ps1")

If Not fso.FolderExists(stateRoot) Then
    fso.CreateFolder stateRoot
End If
If Not fso.FolderExists(cacheRoot) Then
    fso.CreateFolder cacheRoot
End If

If fso.FileExists(statusPath) Then
    On Error Resume Next
    fso.DeleteFile statusPath, True
    On Error GoTo 0
End If

' Create diagnostics before any network request or PowerShell bootstrap work.
' A standalone-launch failure must never point at a log that does not exist.
Set bootstrapLog = fso.CreateTextFile(bootstrapLogPath, True, False)
bootstrapLog.WriteLine "BG3 Controller Action Menu universal launcher"
bootstrapLog.WriteLine "Started: " & Now
bootstrapLog.WriteLine "Launcher: " & WScript.ScriptFullName
bootstrapLog.WriteLine "Stage: starting PowerShell bootstrap"
bootstrapLog.Close

psCommand = "$ErrorActionPreference='Stop';" & _
    "$bootstrapLog=" & PsLiteral(bootstrapLogPath) & ";" & _
    "try{" & _
        "Add-Content -LiteralPath $bootstrapLog -Value 'Stage: resolving newest published development release';" & _
        "$repo='Vyachean/bg3-controller-action-menu';" & _
        "$api='https://api.github.com/repos/'+$repo+'/releases?per_page=20';" & _
        "$headers=@{'User-Agent'='BG3ControllerActionMenu-DevLauncher';'Accept'='application/vnd.github+json'};" & _
        "$token=$env:GH_TOKEN;if(-not $token){$token=$env:GITHUB_TOKEN};if($token){$headers['Authorization']='Bearer '+$token};" & _
        "$payload=Invoke-RestMethod -Uri $api -Headers $headers;" & _
        "$published=@();" & _
        "foreach($candidate in @($payload)){" & _
            "if(-not $candidate.draft -and $candidate.published_at -and $candidate.tag_name){$published+=$candidate}" & _
        "};" & _
        "$release=@($published|Sort-Object{[DateTimeOffset]$_.published_at} -Descending)[0];" & _
        "if(-not $release){throw 'No published development release found.'};" & _
        "Add-Content -LiteralPath $bootstrapLog -Value ('Release: '+[string]$release.tag_name);" & _
        "$asset=@($release.assets|Where-Object{$_.name -eq 'dev-entry.ps1'})[0];" & _
        "if(-not $asset){throw 'Latest development release does not contain dev-entry.ps1.'};" & _
        "$release|ConvertTo-Json -Depth 20|Set-Content -LiteralPath " & PsLiteral(metadataPath) & " -Encoding UTF8;" & _
        "Add-Content -LiteralPath $bootstrapLog -Value 'Stage: downloading dev-entry.ps1';" & _
        "Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile " & PsLiteral(entryPath) & ";" & _
        "$entryArgs=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File'," & PsLiteral(entryPath) & _
            ",'-Repository',$repo" & _
            ",'-ReleaseMetadataPath'," & PsLiteral(metadataPath) & _
            ",'-CacheRoot'," & PsLiteral(fso.BuildPath(stateRoot, "release-cache")) & _
            ",'-LogPath'," & PsLiteral(logPath) & _
            ",'-StatusPath'," & PsLiteral(statusPath) & _
            ",'-ReportPath'," & PsLiteral(reportPath) & _
            ",'-LauncherRoot'," & PsLiteral(baseDir) & ");" & _
        ResolveOnlyPowerShellArg(resolveOnly) & _
        "Add-Content -LiteralPath $bootstrapLog -Value 'Stage: running dev-entry.ps1';" & _
        "& powershell.exe @entryArgs *>> $bootstrapLog;" & _
        "$code=$LASTEXITCODE;" & _
        "Add-Content -LiteralPath $bootstrapLog -Value ('dev-entry exit code: '+$code);" & _
        "exit $code" & _
    "}catch{" & _
        "Add-Content -LiteralPath $bootstrapLog -Value ('BOOTSTRAP ERROR: '+$_.Exception.ToString());" & _
        "exit 1" & _
    "}"

command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command " & QuoteArg(psCommand)

If Not noUi Then
    shell.Popup "Running the current BG3 Controller Action Menu development task..." & vbCrLf & _
                "The task is controlled by the newest published development release.", _
                2, "BG3 Controller Action Menu", 64
End If

exitCode = shell.Run(command, 0, True)

state = ""
version = ""
message = ""

If fso.FileExists(statusPath) Then
    Set stream = fso.OpenTextFile(statusPath, 1, False, -1)
    If Not stream.AtEndOfStream Then state = stream.ReadLine
    If Not stream.AtEndOfStream Then version = stream.ReadLine
    If Not stream.AtEndOfStream Then message = stream.ReadLine
    stream.Close
End If

If exitCode = 0 And UCase(state) = "SUCCESS" Then
    If message = "" Then message = "Development task completed."
    If Not noUi Then
        MsgBox "Development task completed." & vbCrLf & vbCrLf & _
               "Release: " & version & vbCrLf & _
               message, _
               vbInformation, "BG3 Controller Action Menu"
    End If
    WScript.Quit 0
End If

If message = "" Then
    message = "Development task did not complete. See launcher-bootstrap.log for the bootstrap error."
End If

If Not noUi Then
    MsgBox "Development task failed safely." & vbCrLf & vbCrLf & _
           message & vbCrLf & vbCrLf & _
           "Bootstrap log: " & bootstrapLogPath & vbCrLf & _
           "Task log: " & logPath & vbCrLf & _
           "Report: " & reportPath, _
           vbCritical, "BG3 Controller Action Menu"
End If
WScript.Quit exitCode

Function PsLiteral(value)
    PsLiteral = "'" & Replace(value, "'", "''") & "'"
End Function

Function QuoteArg(value)
    QuoteArg = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function

Function ResolveOnlyPowerShellArg(enabled)
    If enabled Then
        ResolveOnlyPowerShellArg = "$entryArgs+='-ResolveOnly';"
    Else
        ResolveOnlyPowerShellArg = ""
    End If
End Function
