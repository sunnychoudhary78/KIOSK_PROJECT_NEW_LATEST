#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Registers AthenaOtaUpdater to start at kiosk user logon via Task Scheduler.

.DESCRIPTION
  Shell Launcher kiosks never load explorer.exe, so Startup folder / Run keys do not run.
  This creates an ONLOGON scheduled task in the interactive session so the updater
  starts after Autologon — alongside (not as) the Shell Launcher shell.

.PARAMETER ExePath
  Full path to AthenaOtaUpdater.exe. Defaults to the published exe beside this script's parent.

.PARAMETER TaskName
  Scheduled task name. Default: AthenaOtaUpdater

.PARAMETER User
  Windows account that Autologon uses (the kiosk user). Default: kiosk

.EXAMPLE
  .\Install-BootIntegration.ps1
  .\Install-BootIntegration.ps1 -ExePath "C:\Athena\AthenaOtaUpdater\AthenaOtaUpdater.exe" -User kiosk
#>
[CmdletBinding()]
param(
    [string]$ExePath = "",
    [string]$TaskName = "AthenaOtaUpdater",
    [string]$User = "kiosk"
)

$ErrorActionPreference = "Stop"

function Resolve-UpdaterExe {
    param([string]$Path)

    if ($Path -and (Test-Path -LiteralPath $Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $candidates = @(
        (Join-Path $scriptRoot "AthenaOtaUpdater.exe"),
        (Join-Path (Split-Path -Parent $PSScriptRoot) "AthenaOtaUpdater.exe"),
        (Join-Path $PSScriptRoot "..\AthenaOtaUpdater.exe"),
        (Join-Path (Get-Location) "AthenaOtaUpdater.exe")
    )

    foreach ($c in $candidates) {
        $full = [System.IO.Path]::GetFullPath($c)
        if (Test-Path -LiteralPath $full) {
            return $full
        }
    }

    throw "AthenaOtaUpdater.exe not found. Pass -ExePath explicitly."
}

$exe = Resolve-UpdaterExe -Path $ExePath
Write-Host "Updater exe: $exe"
Write-Host "Task name:   $TaskName"
Write-Host "Logon user:  $User"

# Verify local user exists (domain\user also allowed; skip check if backslash present).
if ($User -notmatch '\\') {
    try {
        $null = Get-LocalUser -Name $User -ErrorAction Stop
    }
    catch {
        Write-Warning "Local user '$User' was not found. Continuing anyway (domain account?)."
    }
}

$action = New-ScheduledTaskAction -Execute $exe -WorkingDirectory (Split-Path -Parent $exe)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
$principal = New-ScheduledTaskPrincipal `
    -UserId $User `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null

Write-Host "Scheduled task '$TaskName' registered (At logon for '$User')."

# Start now if that user session is already active (optional best-effort).
try {
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "Task start requested."
}
catch {
    Write-Host "Task registered. It will start on next logon of '$User' (or start it manually from Task Scheduler)."
}

Write-Host "Done. Confirm in taskschd.msc -> Task Scheduler Library -> $TaskName"
