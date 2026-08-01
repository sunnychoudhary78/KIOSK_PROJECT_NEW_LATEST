# Windows Kiosk Lockdown Checklist

Use before production fleet rollout.

## OS

- [ ] Dedicated Windows user for kiosk mode (no admin)
- [ ] Assigned access / shell launcher for the Flutter kiosk exe
- [ ] Disable Windows Store, Cortana, and unnecessary startup apps
- [ ] Auto-logon to kiosk user (secured credentials store)
- [ ] Disk encryption (BitLocker) enabled
- [ ] Automatic updates scheduled off-hours; reboot policy defined

## Application

- [ ] App runs fullscreen / kiosk chrome disabled
- [ ] Idle timeout returns to service catalog (`features/session`)
- [ ] Device credentials stored in OS credential manager (not plain text)
- [ ] Heartbeat enabled against API
- [ ] Local print spooler permissions limited to required printers
- [ ] Crash recovery: restart app on exit

## Network

- [ ] Outbound allow-list to API + DigiLocker endpoints only
- [ ] TLS inspection exceptions documented if corporate proxy exists
- [ ] No inbound ports exposed on kiosk LAN interface

## Ops

- [ ] Remote support channel defined
- [ ] Signed builds only; version reported in heartbeat (future)
- [ ] Wipe / re-provision procedure documented
