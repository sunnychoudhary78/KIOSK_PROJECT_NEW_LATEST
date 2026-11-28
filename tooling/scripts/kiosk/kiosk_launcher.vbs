' Smart Kiosk Shell Launcher entrypoint (HIDDEN — no CMD window).
' WESL must point here:
'   wscript.exe //B //Nologo "C:\Kiosk\kiosk_launcher.vbs"
' Owned by AthenaOtaUpdater (not the app ZIP).
'
' On each boot / shell start this script:
'   1) waits for network (so Autologon does not race Wi-Fi)
'   2) starts Brother HttpToUsbBridge in the kiosk session
'   3) opens USB EWS via BridgeClient.GetDeviceUrl (ink/pages without kadmin)
'   4) keeps skp_kiosk.exe alive

Option Explicit
Dim sh, fso, exe, logFile, rc, bridge, clientDll, wmi, procs, p, found
Dim waitSec, maxWait, pingHost, psCmd

Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

Const KIOSK_DIR = "C:\Kiosk"
exe = KIOSK_DIR & "\skp_kiosk.exe"
logFile = KIOSK_DIR & "\shell_debug.log"

If Not fso.FolderExists(KIOSK_DIR) Then
  fso.CreateFolder KIOSK_DIR
End If

sh.CurrentDirectory = KIOSK_DIR

Sub WriteLog(msg)
  On Error Resume Next
  Dim ts
  Set ts = fso.OpenTextFile(logFile, 8, True)
  ts.WriteLine msg & " at " & Now
  ts.Close
  On Error GoTo 0
End Sub

' --- Network wait (max ~3 minutes) so Wi-Fi can come up after reboot ---
maxWait = 180
waitSec = 0
pingHost = "1.1.1.1"
WriteLog "Waiting for network"
Do While waitSec < maxWait
  On Error Resume Next
  rc = sh.Run("cmd /c ping -n 1 -w 1000 " & pingHost & " >nul", 0, True)
  On Error GoTo 0
  If rc = 0 Then
    WriteLog "Network ready after " & CStr(waitSec) & "s"
    Exit Do
  End If
  WScript.Sleep 3000
  waitSec = waitSec + 3
Loop
If waitSec >= maxWait Then
  WriteLog "WARNING: network wait timed out after " & CStr(maxWait) & "s — starting app anyway"
End If

' --- Brother HttpToUsbBridge (per-user; WESL skips Run-key startups) ---
On Error Resume Next
bridge = sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Brother\HttpToUsbBridge\HttpToUsbBridge.exe")
clientDll = sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Brother\BrLauncher\HttpToUsbBridge.NetFramework.dll")
found = False
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("Select Name from Win32_Process Where Name='HttpToUsbBridge.exe'")
For Each p In procs
  found = True
Next
If (Not found) And fso.FileExists(bridge) Then
  WriteLog "Starting HttpToUsbBridge"
  sh.Run """" & bridge & """", 7, False
  WScript.Sleep 2000
ElseIf Not fso.FileExists(bridge) Then
  WriteLog "HttpToUsbBridge missing: " & bridge
End If
On Error GoTo 0

' --- Open USB EWS (:60910). Raw control-port GET returns 400 and never brings EWS up.
'     Logging into kadmin is NOT required when this runs in the kiosk profile. ---
If fso.FileExists(clientDll) Then
  WriteLog "Opening Brother USB EWS via GetDeviceUrl"
  psCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command " & _
    """try { Add-Type -Path '" & clientDll & "'; " & _
    "$c = New-Object HttpToUsbBridgeClient.BridgeClient; " & _
    "$r = $c.GetDeviceUrl('04f9','0714'); " & _
    "Add-Content -Path '" & logFile & "' -Value ('GetDeviceUrl ' + $r.Item1 + ' ' + $r.Item2 + ' at ' + (Get-Date)) " & _
    "} catch { Add-Content -Path '" & logFile & "' -Value ('GetDeviceUrl error: ' + $_.Exception.Message + ' at ' + (Get-Date)) }"""
  On Error Resume Next
  sh.Run psCmd, 0, True
  On Error GoTo 0
Else
  WriteLog "Brother BridgeClient DLL missing: " & clientDll
End If

' Keep the Flutter app alive. Never exit this script (WESL would restart us).
Do
  If Not fso.FileExists(exe) Then
    WriteLog "Missing " & exe
    WScript.Sleep 5000
  Else
    WriteLog "Starting"
    ' 1 = normal window, True = wait until process exits
    rc = sh.Run("""" & exe & """", 1, True)
    WriteLog "Exited with code " & CStr(rc)
    WScript.Sleep 5000
  End If
Loop
