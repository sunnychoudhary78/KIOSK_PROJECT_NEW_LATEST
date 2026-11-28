# Kiosk hang watchdog — kill a frozen skp_kiosk.exe so kiosk_launcher.vbs / kiosk_shell.bat can relaunch.
# Managed by AthenaOtaUpdater — do not rely on this file being inside the app ZIP.
#
# Expected task (SYSTEM, every minute):
#   schtasks /Create /TN "SKP Kiosk Watchdog" /SC MINUTE /MO 1 /RU SYSTEM /F `
#     /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Kiosk\kiosk_watchdog.ps1"
#
# Liveness stamp is written by the Flutter app to:
#   C:\Kiosk\runtime\liveness.txt

$ErrorActionPreference = 'SilentlyContinue'

$KioskDir = 'C:\Kiosk'
$ExeName = 'skp_kiosk.exe'
$LivenessPath = Join-Path $KioskDir 'runtime\liveness.txt'
$LogPath = Join-Path $KioskDir 'watchdog.log'
$StaleAfter = [TimeSpan]::FromSeconds(90)
$MissingGrace = [TimeSpan]::FromSeconds(120)

function Write-WatchdogLog([string]$Message) {
  $line = '{0:u} {1}' -f [DateTime]::UtcNow, $Message
  try {
    Add-Content -Path $LogPath -Value $line -Encoding ascii
  } catch {
  }
}

$proc = Get-Process -Name 'skp_kiosk' -ErrorAction SilentlyContinue
if (-not $proc) {
  return
}

$now = [DateTime]::UtcNow
$stampAge = $null
$reason = $null

if (Test-Path -LiteralPath $LivenessPath) {
  try {
    $raw = (Get-Content -LiteralPath $LivenessPath -TotalCount 1).Trim()
    $stamp = [DateTime]::Parse(
      $raw,
      [System.Globalization.CultureInfo]::InvariantCulture,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    ).ToUniversalTime()
    $stampAge = $now - $stamp
    if ($stampAge -gt $StaleAfter) {
      $reason = "stale_liveness ageSec=$([int]$stampAge.TotalSeconds)"
    }
  } catch {
    $reason = "invalid_liveness error=$($_.Exception.Message)"
  }
} else {
  $started = ($proc | Sort-Object StartTime | Select-Object -First 1).StartTime.ToUniversalTime()
  $up = $now - $started
  if ($up -gt $MissingGrace) {
    $reason = "missing_liveness upSec=$([int]$up.TotalSeconds)"
  }
}

if (-not $reason) {
  return
}

Write-WatchdogLog "KILL $ExeName $reason"
try {
  $proc | Stop-Process -Force
  Write-WatchdogLog "KILL_OK $ExeName"
} catch {
  Write-WatchdogLog "KILL_FAIL $ExeName error=$($_.Exception.Message)"
}
