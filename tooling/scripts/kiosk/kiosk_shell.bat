@echo off
REM Windows Embedded Shell Launcher entrypoint for Smart Kiosk.
REM Deploy as C:\Kiosk\kiosk_shell.bat and set WESL Shell to this path.
REM WESL only restarts when this process exits — use kiosk_watchdog.ps1 for hangs.

setlocal
set "KIOSK_DIR=C:\Kiosk"
set "KIOSK_EXE=%KIOSK_DIR%\skp_kiosk.exe"
set "LOG=%KIOSK_DIR%\shell_debug.log"
set "BROTHER_BRIDGE=%ProgramFiles(x86)%\Brother\HttpToUsbBridge\HttpToUsbBridge.exe"
set "BROTHER_CLIENT=%ProgramFiles(x86)%\Brother\BrLauncher\HttpToUsbBridge.NetFramework.dll"

if not exist "%KIOSK_DIR%" mkdir "%KIOSK_DIR%"

REM Brother HttpToUsbBridge is per-user (not a service). WESL skips normal Run-key
REM startups, so the kiosk session must start the bridge and open the USB EWS.
REM Logging into kadmin first is NOT required when this runs in the kiosk profile.
tasklist /FI "IMAGENAME eq HttpToUsbBridge.exe" 2>nul | find /I "HttpToUsbBridge.exe" >nul
if errorlevel 1 (
  if exist "%BROTHER_BRIDGE%" (
    echo Starting HttpToUsbBridge at %date% %time% >> "%LOG%"
    start "" /MIN "%BROTHER_BRIDGE%"
    timeout /t 2 /nobreak >nul
  ) else (
    echo HttpToUsbBridge missing: %BROTHER_BRIDGE% at %date% %time% >> "%LOG%"
  )
)

REM Open the USB device via Brother's BridgeClient (raw control-port GET returns 400
REM and never brings up http://127.0.0.1:60910). Safe if the printer is unplugged.
if exist "%BROTHER_CLIENT%" (
  echo Opening Brother USB EWS at %date% %time% >> "%LOG%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Add-Type -Path '%BROTHER_CLIENT%'; $c = New-Object HttpToUsbBridgeClient.BridgeClient; $r = $c.GetDeviceUrl('04f9','0714'); Add-Content -Path '%LOG%' -Value ('GetDeviceUrl ' + $r.Item1 + ' ' + $r.Item2 + ' at ' + (Get-Date)) } catch { Add-Content -Path '%LOG%' -Value ('GetDeviceUrl error: ' + $_.Exception.Message + ' at ' + (Get-Date)) }"
)

:loop
echo Starting at %date% %time% >> "%LOG%"
if not exist "%KIOSK_EXE%" (
  echo Missing %KIOSK_EXE% at %date% %time% >> "%LOG%"
  timeout /t 5 /nobreak >nul
  goto loop
)

start /wait "" "%KIOSK_EXE%"
echo Exited with code %errorlevel% at %date% %time% >> "%LOG%"
timeout /t 2 /nobreak >nul
goto loop
