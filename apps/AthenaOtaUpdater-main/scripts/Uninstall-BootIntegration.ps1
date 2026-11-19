#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Removes the AthenaOtaUpdater logon scheduled task.

.EXAMPLE
  .\Uninstall-BootIntegration.ps1
  .\Uninstall-BootIntegration.ps1 -TaskName AthenaOtaUpdater
#>
[CmdletBinding()]
param(
    [string]$TaskName = "AthenaOtaUpdater"
)

$ErrorActionPreference = "Stop"

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Task '$TaskName' is not registered."
    return
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Removed scheduled task '$TaskName'."
