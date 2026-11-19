# Athena OTA Updater (.NET 8 WPF)

## What it does
- Checks an HTTPS JSON manifest every 15 minutes.
- Downloads a complete Flutter Windows ZIP build.
- Validates SHA-256 before extracting or executing.
- Waits for Windows input inactivity (configurable idle minutes).
- Stops Athena, backs up the old folder, swaps the new build, starts it, and rolls back if the process does not remain running.

## Important limitations before production
1. This starter uses Windows last-input idle time. It does NOT know whether a print/payment/wellbeing transaction is active. For safe kiosk deployment, add an explicit Flutter-to-updater IPC "safe to update" signal before relying on automatic updates.
2. SHA-256 protects against corruption only if the manifest is trusted. Host the manifest on a trusted HTTPS endpoint and add a digital signature (Ed25519/RSA) verification before production.
3. Run the updater under a Windows account that has Modify rights to C:\Athena. Do not run it as a public kiosk user with broad administrator privileges. Prefer a dedicated updater service running with narrowly scoped permissions.
4. The health check here confirms only that Athena.exe remains running. A stronger check should use a local health endpoint/Named Pipe handshake from Flutter.
5. Configure Flutter Windows build to include Athena.exe at the ZIP root, with its data and DLL folders alongside it. Do not ZIP an enclosing parent folder unless you change extraction validation.
6. Test in a disposable Windows VM first. Never test the first update on the live kiosk.

## Configure
Edit `appsettings.json`:
- manifestUrl: HTTPS URL to manifest.json
- installDirectory: existing Flutter app folder
- executableName: actual Flutter executable (must match manifest)
- checkIntervalMinutes: 15
- idleMinutes: 2

## Manifest example
{
  "product": "Athena",
  "version": "1.0.1",
  "downloadUrl": "https://updates.example.com/athena/1.0.1/athena.zip",
  "sha256": "64_HEX_CHARACTERS",
  "executableName": "Athena.exe"
}

The SHA-256 must be the hash of the exact ZIP file uploaded.

## Build
Install the .NET 8 SDK on Windows, open this folder in Visual Studio Code, then:
  dotnet restore
  dotnet build -c Release
  dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true

Publish output is under bin/Release/net8.0-windows/win-x64/publish.

## Deployment
- Copy publish output to a fixed folder (example: `C:\Athena\AthenaOtaUpdater`).
- Place `appsettings.json` beside `AthenaOtaUpdater.exe`.
- **Boot integration (required on Shell Launcher kiosks):** explorer Startup/Run never run. As `kadmin` (elevated), run once:

```powershell
cd C:\Athena\AthenaOtaUpdater
powershell -ExecutionPolicy Bypass -File .\scripts\Install-BootIntegration.ps1 -ExePath "C:\Athena\AthenaOtaUpdater\AthenaOtaUpdater.exe" -User kiosk
```

  That creates an At-logon scheduled task so the updater starts after Autologon, alongside the Shell Launcher shell (not as the shell).
  With `ensureBootTask: true` in `appsettings.json`, the app also self-heals the task path when it is already running.
- Do **not** set AthenaOtaUpdater as the Shell Launcher shell; keep `skp_kiosk.exe` / `kiosk_shell.bat` as the shell.
- Configure Athena itself to start via Shell Launcher (existing kiosk flow).
