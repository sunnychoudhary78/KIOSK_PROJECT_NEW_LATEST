@echo off
REM Windows Embedded Shell Launcher entrypoint for Smart Kiosk.
REM Deploy as C:\Kiosk\kiosk_shell.bat and set WESL Shell to this path.
REM WESL only restarts when this process exits — use kiosk_watchdog.ps1 for hangs.

setlocal
set "KIOSK_DIR=C:\Kiosk"
set "KIOSK_EXE=%KIOSK_DIR%\skp_kiosk.exe"
set "LOG=%KIOSK_DIR%\shell_debug.log"

if not exist "%KIOSK_DIR%" mkdir "%KIOSK_DIR%"

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
