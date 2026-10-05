Option Explicit

Dim shell, fso, baseDir, bootstrap, stateRoot, logPath, statusPath, reportPath
Dim command, exitCode, state, version, message, stream

If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "--self-test" Then
        WScript.Echo "one-click launcher syntax OK"
        WScript.Quit 0
    End If
End If

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
bootstrap = fso.BuildPath(baseDir, "bootstrap-latest.ps1")

If Not fso.FileExists(bootstrap) Then
    MsgBox "Installer component is missing:" & vbCrLf & bootstrap, vbCritical, "BG3 Controller Action Menu"
    WScript.Quit 2
End If

stateRoot = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\BG3ControllerActionMenu"
If Not fso.FolderExists(stateRoot) Then
    fso.CreateFolder stateRoot
End If

logPath = fso.BuildPath(stateRoot, "install-latest.log")
statusPath = fso.BuildPath(stateRoot, "install-status.txt")
reportPath = fso.BuildPath(stateRoot, "xbox-dev-environment.json")

If fso.FileExists(statusPath) Then
    On Error Resume Next
    fso.DeleteFile statusPath, True
    On Error GoTo 0
End If

command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File " & QuoteArg(bootstrap) & _
          " -LogPath " & QuoteArg(logPath) & _
          " -StatusPath " & QuoteArg(statusPath) & _
          " -ReportPath " & QuoteArg(reportPath)

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
    MsgBox "Installation completed." & vbCrLf & vbCrLf & _
           "Installed version: " & version & vbCrLf & _
           "The launcher updated itself if needed, then installed the newest verified release.", _
           vbInformation, "BG3 Controller Action Menu"
    WScript.Quit 0
End If

If message = "" Then
    message = "Installation did not complete. See the log for details."
End If

MsgBox "Installation failed safely." & vbCrLf & vbCrLf & _
       message & vbCrLf & vbCrLf & _
       "Log: " & logPath & vbCrLf & _
       "Diagnostic report: " & reportPath, _
       vbCritical, "BG3 Controller Action Menu"
WScript.Quit exitCode

Function QuoteArg(value)
    QuoteArg = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
