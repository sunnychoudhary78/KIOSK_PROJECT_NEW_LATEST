# Smart Kiosk Platform — Completion Report (Brief)

**Scope:** V1 monorepo — API, Admin, Windows Kiosk, Citizen Mobile.

---

## 1. API (`apps/api`) — largely complete for V1

- Auth: admin password, citizen SMS OTP, device JWT
- Devices: register, heartbeat, geo + **nearby** search
- Services: catalog + per-device enablement (`otp_print`, `digilocker_print`)
- OTP Print: create challenge (PDF + OTP), kiosk redeem, document fetch
- DigiLocker Print: MeriPehchaan OAuth/PKCE, list/download docs → print jobs
- Print jobs: lifecycle + device status + PDF content
- Ads: full CRUD + device playlist/playback events
- Platform settings + audit logs
- Seed data for local demo

**Gaps:** SMS defaults to noop (MSG91 when configured); no well-being API; thin unit tests only.

---

## 2. Admin (`apps/admin`) — ops console usable

- Login + JWT shell
- Kiosks: register devices (incl. lat/lng), activation credentials
- Ads: advertisers, creatives, campaigns/targeting, dashboard stats
- Print jobs + audit logs (view)
- Services catalog (view)
- Platform settings (OTP/print limits, citizen OTP TTL)

**Gaps:** Users and DigiLocker pages are stubs.

---

## 3. Kiosk (`apps/kiosk`) — Windows terminal ready for core services

- Device activate / persist / heartbeat / deactivate
- **OTP Print:** redeem → preview → silent Windows PDF print → status
- **DigiLocker Print:** WebView consent → list → preview → print
- **Well Being:** SpO₂/HR + temperature over serial (local HW; no API)
- Ads banner + idle player
- Serial debug UI + configurable printer via dart-define

**Gaps:** Extra vitals “coming soon”; idle session policy not fully wired; no other catalog services yet.

---

## 4. Mobile (`apps/mobile`) — citizen flows for OTP + discovery

- Phone SMS OTP login (Android autofill), session restore
- Home hub + branded UI shell
- **OTP Print:** multi-PDF upload → challenge + success/expiry screen
- **Nearby kiosks:** GPS list + map
- Minimal profile (phone + sign out)

**Gaps:** DigiLocker placeholder only (print is kiosk-led); no redeem/print on mobile.

---

## End-to-end status

| Flow | Status |
|------|--------|
| Admin registers kiosk → kiosk activates | Done |
| Citizen OTP Print → kiosk redeem/print | Done |
| DigiLocker on kiosk → print job | Done |
| Nearby kiosks (mobile) | Done |
| Ads to kiosk | Done |
| Well Being vitals | Kiosk/HW only |
| User mgmt / more services | Not done |

**Bottom line:** V1 spine (auth, devices, OTP Print, DigiLocker Print, print jobs, ads, nearby) is in place across all four apps. Remaining work is polish (admin stubs, SMS prod config, more vitals/services) rather than missing core platform wiring.
