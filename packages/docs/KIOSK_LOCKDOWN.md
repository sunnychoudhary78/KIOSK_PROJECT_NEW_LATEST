# Windows Kiosk Lockdown Checklist

Use before production fleet rollout.

## OS

- [ ] Dedicated Windows user for kiosk mode (no admin)
- [ ] Shell Launcher (WESL) points at `C:\Kiosk\kiosk_shell.bat` (not the exe directly)
- [ ] WESL `DefaultAction` restarts the custom shell on exit
- [ ] Disable Windows Store, Cortana, and unnecessary startup apps
- [ ] Auto-logon to kiosk user (secured credentials store)
- [ ] Disk encryption (BitLocker) enabled
- [ ] Automatic updates scheduled off-hours; reboot policy defined
- [ ] Hang watchdog scheduled task installed (see Crash and hang recovery)

## Application

- [ ] App runs fullscreen / kiosk chrome disabled
- [ ] Idle timeout returns to service catalog (`features/session`)
- [ ] Device credentials stored in OS credential manager (not plain text)
- [ ] Heartbeat enabled against API
- [ ] Local print spooler permissions limited to required printers
- [ ] Deploy `tooling/scripts/kiosk/kiosk_shell.bat` → `C:\Kiosk\kiosk_shell.bat`
- [ ] Deploy `tooling/scripts/kiosk/kiosk_watchdog.ps1` → `C:\Kiosk\kiosk_watchdog.ps1`

## Network

- [ ] Outbound allow-list to API + DigiLocker endpoints
- [ ] Outbound allow-list for LiveKit Cloud screen share (see Remote support)
- [ ] TLS inspection exceptions documented if corporate proxy exists
- [ ] No inbound ports exposed on kiosk LAN interface

## Ops

- [x] Remote support channel defined (LiveKit Cloud view-only screen share from admin **View screen**)
- [ ] Signed builds only; version reported in heartbeat (future)
- [ ] Wipe / re-provision procedure documented

### Remote support (LiveKit screen share)

Admin **View screen** (admin/operator) starts an on-demand, view-only desktop share. The kiosk dials **out** to LiveKit; no inbound ports on the kiosk.

Configure API env: `SKP_LIVEKIT_URL`, `SKP_LIVEKIT_API_KEY`, `SKP_LIVEKIT_API_SECRET` (see `apps/api/.env.example`).

Outbound allow-list (in addition to API + DigiLocker):

- Your LiveKit project host from `SKP_LIVEKIT_URL` (e.g. `*.livekit.cloud` wss/https)
- LiveKit TURN / media relays used by that project (confirm in LiveKit Cloud dashboard / docs for your region)

Smoke test before fleet rollout: publish a Windows screen with LiveKit Meet or the Flutter sample against the same project; subscribe in a browser.

---

## Crash and hang recovery

WESL / Shell Launcher only relaunches when the **shell process exits**. A frozen
Flutter process that never exits will not recover unless something kills it.

### Shell restart loop

1. Copy [`tooling/scripts/kiosk/kiosk_shell.bat`](../../tooling/scripts/kiosk/kiosk_shell.bat)
   to `C:\Kiosk\kiosk_shell.bat`.
2. Set WESL `Shell` for the kiosk user SID to `C:\Kiosk\kiosk_shell.bat`.
3. Confirm `DefaultAction` restarts the custom shell on exit.

The batch file logs start/exit/`errorlevel` to `C:\Kiosk\shell_debug.log` and
relaunchs `skp_kiosk.exe` after a short delay.

Verify WESL:

```powershell
$class = [wmiclass]"root\standardcimv2\embedded:WESL_UserSetting"
$class.GetInstances() | Select-Object Sid, Shell, DefaultAction
```

### Hang watchdog

1. Copy [`tooling/scripts/kiosk/kiosk_watchdog.ps1`](../../tooling/scripts/kiosk/kiosk_watchdog.ps1)
   to `C:\Kiosk\kiosk_watchdog.ps1`.
2. Schedule every minute (SYSTEM):

```powershell
schtasks /Create /TN "SKP Kiosk Watchdog" /SC MINUTE /MO 1 /RU SYSTEM /F `
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Kiosk\kiosk_watchdog.ps1"
```

The watchdog kills `skp_kiosk.exe` when:

- `C:\Kiosk\runtime\liveness.txt` is older than **90s**, or
- the stamp is missing and the process has been up longer than **120s** (grace for
  first write after launch).

Actions are logged to `C:\Kiosk\watchdog.log`. After a kill, `kiosk_shell.bat`
relaunches the app.

### Field triage

| Symptom | Check | Likely cause |
| --- | --- | --- |
| App gone, blank / Explorer | `shell_debug.log` exit lines; WESL Shell path | Crash/exit without shell loop, or wrong Shell |
| Stuck on Astrology / cannot leave service | Still can open nested tiles? | Session reset hung (fixed in app: pop-first + timeouts) |
| Frozen UI, process still in Task Manager | `liveness.txt` age; `watchdog.log` | UI hang — watchdog should kill within ~2 min |
| "Can't reach the server" while API healthy | Device DNS/TLS/proxy; `app.log` | Client timeout / network path |
| Only fixed by redeploying binaries | File dates under `C:\Kiosk`; DLLs in `data\` | Corrupt deploy tree or hung process cleared by replace |

### Astrology stuck-exit checklist

1. Note exact screen (hub "Choose a Reading" vs inside a reading).
2. Tap Back/Home — if nested options still open, suspect session exit hang (app-side).
3. Check whether `skp_kiosk.exe` is still running (hang) or restarted (crash).
4. Collect `C:\Kiosk\shell_debug.log`, `C:\Kiosk\watchdog.log`, `C:\Kiosk\logs\app.log`.
5. Prefer kill/restart via watchdog or Task Manager before full redeploy.
