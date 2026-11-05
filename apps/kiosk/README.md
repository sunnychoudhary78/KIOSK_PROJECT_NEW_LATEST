# skp_kiosk

Windows Flutter client for the Smart Kiosk Platform (OTP print, DigiLocker, well-being).

## Printing (Windows)

The kiosk sends PDFs to the **USB** Brother queue via silent `directPrintPdf`, then **reconciles** physical completion from the USB total page count (`final - baseline >= expected`). If that USB baseline cannot be read, the job ends as `unknown` after a short wait. Bare `completed` is never reported without `reconcileStatus=verified`. Status, ink levels, pages, and error history on the admin card come from the USB HTTP latch (`skp_printer_usb.exe` → HttpToUsbBridge).

### Brother DCP-T830DW (current fleet)

1. Install the Brother USB printer/scanner driver. Any Windows port whose name starts with `USB` is accepted. WSD, TCP/IP, and other network ports are never selected.
2. Load **A4** plain paper; register cassette size as A4 on the printer panel.
3. Brother **HttpToUsbBridge** must be running so `http://127.0.0.1:60910` serves the printer EWS. Telemetry does **not** use AppDevKit DLLs.
4. Maintenance ink %, counters, and error history use the EWS login password (hardcoded lab default in `AppConfig`; override with `SKP_PRINTER_PASSWORD` if needed).

Print resolution order (USB ports only):

1. `SKP_PRINTER_NAME` substring match (default `Brother`), then an exact name match, then the Windows default among those matches
2. If `SKP_PRINTER_NAME` is empty: the default USB printer, otherwise the only USB printer
3. If no USB queue matches, printing fails with `USB_PRINTER_NOT_FOUND` and does not fall back to a network queue

Face-up trays: by default pages print last→first (`SKP_PRINT_REVERSE_PAGES=true`) so page 1 lands on top. Use `SKP_PRINT_REVERSE_PAGES=false` for face-down output.

### Dart-defines

| Define | Default | Purpose |
|--------|---------|---------|
| `SKP_PRINTER_NAME` | `Brother` | Windows printer name substring |
| `SKP_PRINT_RECONCILE_TIMEOUT_MS` | `180000` | Max wait for a USB page-count rise |
| `SKP_PRINTER_MODEL` | `Brother DCP-T830DW` | Model stored on the heartbeat |
| `SKP_PRINTER_PASSWORD` | lab default in `AppConfig` | EWS password for Maintenance Information (override per deploy) |

`getHealth` reads the USB spooler queue. After the first successful USB HTTP read, ink, pages, and error history come from the USB latch. Until that read, those cells stay blank. Live status is polled from `/home/monitor.html`; counters and ink % from `/general/information.html?kind=item`. Admin and kiosk surfaces label supplies as **ink** (wire JSON still uses `toner*`); belt/fuser Parts are laser-only and hidden when absent. Admin also shows **2-sided** page counters and per-color **refill** counts when present; scan and copy totals are not collected.

### Reconcile rules

- **Verified only** when the USB total page Δ ≥ expected under exclusive lock. A flat counter is not paper-out.
- If the USB baseline cannot be read, the job is `unknown` with detail `usb_baseline_unavailable`.
- Do **not** verify from spooler job gone/idle, `directPrintPdf` ok, or status back to idle alone.
- Spooler `EnumJobs` fields are correlation-only (except cancel/purge of orphans).
- Paper-out is derived from monitor status text mapped to legacy code `41236` when the message indicates empty/missing paper.

### Spooler orphan cancel

Visitor-bound prints must not resume after the visitor leaves. On abort, session reset, home, abandon-retry, post-submit fail/timeout, or a dirty pre-print queue, the kiosk cancels the Windows USB job (or purges that queue). Verified success does **not** cancel. Mid-print cancel can leave partial physical pages — those jobs still use `needsAdminReview`.

```powershell
flutter run -d windows
```

### Manual checklist (physical Brother)

Run only after a Windows rebuild against a live DCP-T830DW; do not claim these passed from unit tests alone.

1. Restart the Windows kiosk so the native printer plugin and `skp_printer_usb.exe` rebuild.
2. Confirm `http://127.0.0.1:60910/home/status.html` loads and the password define is set.
3. Quick Print a **1-page** PDF.
4. UI should show “Confirming print…” then success (no `completed requires reconcileStatus=verified` error).
5. Admin/API print job: `status=completed`, `reconcileStatus=verified`, `pagesReported >= 1`.
6. Optional: paper-out / orphan cancel checks against the live USB queue.

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
