# skp_kiosk

Windows Flutter client for the Smart Kiosk Platform (OTP print, DigiLocker, well-being).

## Printing (Windows)

The kiosk sends PDFs to a **Windows-installed printer** via silent `directPrintPdf`, then **reconciles** physical completion using SNMP page counters (Brother HL-L3280CDW) and Windows spooler status. Bare `completed` is never reported without `reconcileStatus=verified`.

### Brother HL-L3280CDW (current fleet)

1. Install the Brother driver; prefer that printer as Windows **default** (or set `SKP_PRINTER_NAME`).
2. Load **A4** plain paper; register cassette size as A4 on the printer panel.
3. Enable **SNMP v2c** on the printer (community for lab only — do not commit secrets).
4. Use a **DHCP reservation** so the printer IP stays stable.

Print resolution order:

1. `SKP_PRINTER_NAME` (substring match on the Windows printer name), if set
2. Windows default printer
3. The only installed printer (if there is exactly one)

Face-up trays: by default pages print last→first (`SKP_PRINT_REVERSE_PAGES=true`) so page 1 lands on top. Use `SKP_PRINT_REVERSE_PAGES=false` for face-down output.

### Dart-defines (SNMP — never hardcode in source)

| Define | Default | Purpose |
|--------|---------|---------|
| `SKP_PRINTER_NAME` | empty | Windows printer name substring |
| `SKP_PRINTER_SNMP_HOST` | empty | Printer LAN IP (e.g. `192.168.1.13`) |
| `SKP_PRINTER_SNMP_VERSION` | `2c` | Only v2c supported |
| `SKP_PRINTER_SNMP_COMMUNITY` | empty | Community string (lab: `public`) |
| `SKP_PRINT_RECONCILE_TIMEOUT_MS` | `180000` | Max wait for page-counter proof |
| `SKP_PRINTER_MODEL` | `Brother HL-L3280CDW` | Profile selector |

Empty host/community disables SNMP; jobs end as `unknown` / `reconciliation_required` (never fake verified).

Example lab run:

```powershell
flutter run -d windows `
  --dart-define=SKP_API_BASE_URL=https://uat-kiosk-api.immortaltechnovation.com/v1 `
  --dart-define=SKP_PRINTER_NAME=Brother `
  --dart-define=SKP_PRINTER_SNMP_HOST=192.168.1.13 `
  --dart-define=SKP_PRINTER_SNMP_COMMUNITY=public
```

### Manual checklist (physical Brother)

1. Rebuild/restart the Windows kiosk with SNMP dart-defines above.
2. Quick Print a **1-page** PDF.
3. UI should show “Confirming print…” then success (no `completed requires reconcileStatus=verified` error).
4. Admin/API print job: `status=completed`, `reconcileStatus=verified`, `pagesReported >= 1`.
5. Optional: pull paper mid-job — expect jam messaging and `needsAdminReview` when partial/uncertain.

## Surveillance (Windows)

When admin enables surveillance on a device, the kiosk records ~10 minute MP4 segments and uploads them to private Cloudflare R2 via API-issued presigned PUT URLs.

Admin **Recordings** plays clips with short-lived presigned GET URLs. Configure the R2 bucket CORS so:

- Admin origins (same as `SKP_CORS_ORIGINS`, e.g. `http://localhost:5173`) may `GET` and `HEAD` (include `Range` for seeking)
- Kiosk / upload clients may `PUT`

Without GET CORS, the clip list still works but the browser video player fails.

## Getting Started

```powershell
cd apps/kiosk
flutter pub get
flutter run -d windows
```
