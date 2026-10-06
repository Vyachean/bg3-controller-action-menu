Option Explicit

Dim shell, fso, baseDir, scriptPath, logPath, statusPath
Dim command, exitCode, state, message, archive, stream

If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "--self-test" Then
        WScript.Echo "capture launcher syntax OK"
        WScript.Quit 0
    End If
End If

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(baseDir, "capture-self-contained-inputs.ps1")
logPath = fso.BuildPath(baseDir, "capture.log")
statusPath = fso.BuildPath(baseDir, "capture-status.txt")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Capture component is missing:" & vbCrLf & scriptPath, vbCritical, "BG3 Controller Action Menu"
    WScript.Quit 2
End If

If fso.FileExists(statusPath) Then
    On Error Resume Next
    fso.DeleteFile statusPath, True
    On Error GoTo 0
End If

command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File " & QuoteArg(scriptPath) & _
          " -PortableRoot " & QuoteArg(baseDir)

shell.Popup "Collecting BG3 UI files for self-contained mod development..." & vbCrLf & _
            "The game installation is read only. This can take a few minutes.", _
            3, "BG3 Controller Action Menu", 64

exitCode = shell.Run(command, 0, True)

state = ""
message = ""
archive = ""

If fso.FileExists(statusPath) Then
    Set stream = fso.OpenTextFile(statusPath, 1, False, -1)
    If Not stream.AtEndOfStream Then state = stream.ReadLine
    If Not stream.AtEndOfStream Then message = stream.ReadLine
    If Not stream.AtEndOfStream Then archive = stream.ReadLine
    stream.Close
End If

If exitCode = 0 And UCase(state) = "SUCCESS" Then
    MsgBox "Capture completed." & vbCrLf & vbCrLf & _
           "Archive:" & vbCrLf & archive & vbCrLf & vbCrLf & _
           "Upload this ZIP to the development chat.", _
           vbInformation, "BG3 Controller Action Menu"
    WScript.Quit 0
End If

If message = "" Then
    message = "Capture did not complete. See capture.log beside this VBS file."
End If

MsgBox "Capture failed." & vbCrLf & vbCrLf & _
       message & vbCrLf & vbCrLf & _
       "Log: " & logPath, _
       vbCritical, "BG3 Controller Action Menu"
WScript.Quit exitCode

Function QuoteArg(value)
    QuoteArg = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
