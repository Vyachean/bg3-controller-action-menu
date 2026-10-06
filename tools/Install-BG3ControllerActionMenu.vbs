Option Explicit

' Universal development shortcut.
' Keep this file tiny and backward-compatible. It resolves the newest published
' development release, downloads that release's dev-entry.ps1, and runs it.
' The VBS does not know whether the current development task is install, capture,
' diagnostics, or another operation. That behavior belongs entirely to GitHub.

Dim shell, fso, baseDir, stateRoot, cacheRoot, logPath, statusPath, reportPath
Dim metadataPath, entryPath, psCommand, command, exitCode
Dim state, version, message, stream

If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "--self-test" Then
        WScript.Echo "universal development launcher syntax OK"
        WScript.Quit 0
    End If
End If

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
stateRoot = fso.BuildPath(baseDir, "installer-work")
cacheRoot = fso.BuildPath(stateRoot, "entry-cache")
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

psCommand = "$ErrorActionPreference='Stop';" & _
    "$repo='Vyachean/bg3-controller-action-menu';" & _
    "$api='https://api.github.com/repos/'+$repo+'/releases?per_page=20';" & _
    "$headers=@{'User-Agent'='BG3ControllerActionMenu-DevLauncher';'Accept'='application/vnd.github+json'};" & _
    "$releases=@(Invoke-RestMethod -Uri $api -Headers $headers);" & _
    "$release=@($releases|Where-Object{-not $_.draft -and $_.published_at -and $_.tag_name}|Sort-Object{[DateTimeOffset]$_.published_at} -Descending)[0];" & _
    "if(-not $release){throw 'No published development release found.'};" & _
    "$asset=@($release.assets|Where-Object{$_.name -eq 'dev-entry.ps1'})[0];" & _
    "if(-not $asset){throw 'Latest development release does not contain dev-entry.ps1.'};" & _
    "$release|ConvertTo-Json -Depth 20|Set-Content -LiteralPath " & PsLiteral(metadataPath) & " -Encoding UTF8;" & _
    "Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile " & PsLiteral(entryPath) & ";" & _
    "& " & PsLiteral(entryPath) & _
        " -Repository $repo" & _
        " -ReleaseMetadataPath " & PsLiteral(metadataPath) & _
        " -CacheRoot " & PsLiteral(fso.BuildPath(stateRoot, "release-cache")) & _
        " -LogPath " & PsLiteral(logPath) & _
        " -StatusPath " & PsLiteral(statusPath) & _
        " -ReportPath " & PsLiteral(reportPath) & _
        " -LauncherRoot " & PsLiteral(baseDir) & ";" & _
    "exit $LASTEXITCODE"

command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command " & QuoteArg(psCommand)

shell.Popup "Running the current BG3 Controller Action Menu development task..." & vbCrLf & _
            "The task is controlled by the newest published development release.", _
            2, "BG3 Controller Action Menu", 64

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
    MsgBox "Development task completed." & vbCrLf & vbCrLf & _
           "Release: " & version & vbCrLf & _
           message, _
           vbInformation, "BG3 Controller Action Menu"
    WScript.Quit 0
End If

If message = "" Then
    message = "Development task did not complete. See the log for details."
End If

MsgBox "Development task failed safely." & vbCrLf & vbCrLf & _
       message & vbCrLf & vbCrLf & _
       "Log: " & logPath & vbCrLf & _
       "Report: " & reportPath, _
       vbCritical, "BG3 Controller Action Menu"
WScript.Quit exitCode

Function PsLiteral(value)
    PsLiteral = "'" & Replace(value, "'", "''") & "'"
End Function

Function QuoteArg(value)
    QuoteArg = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
