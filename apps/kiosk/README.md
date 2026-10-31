# skp_kiosk

Windows Flutter client for the Smart Kiosk Platform (OTP print, DigiLocker, well-being).

## Printing (Windows)

The kiosk sends PDFs to the **USB** Brother queue via silent `directPrintPdf`, then **reconciles** physical completion from the USB total page count (`final - baseline >= expected`). If that USB baseline cannot be read, the job ends as `unknown` after a short wait. Bare `completed` is never reported without `reconcileStatus=verified`. Status, toner, pages, belt, fuser, and error history on the admin card come from the USB latch.

### Brother HL-L3280CDW (current fleet)

1. Install the Brother driver on a USB port. The lab queue is **Brother HL-L3280CDW series** on **USB001**. Any port whose name starts with `USB` is accepted (`USB002` after a reinstall still matches). WSD, TCP/IP, and other network ports are never selected.
2. Load **A4** plain paper; register cassette size as A4 on the printer panel.
3. Printer Wi-Fi can stay off. The kiosk does not poll the printer over the network.

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
| `SKP_PRINTER_MODEL` | `Brother HL-L3280CDW` | Model stored on the heartbeat |

`getHealth` reads the USB spooler queue. After the first successful USB read, toner, pages, parts, and error history come from the USB latch. Until that read, those cells stay blank.

### Reconcile rules

- **Verified only** when the USB total page Δ ≥ expected under exclusive lock. A flat counter is not paper-out.
- If the USB baseline cannot be read, the job is `unknown` with detail `usb_baseline_unavailable`.
- Do **not** verify from spooler job gone/idle, `directPrintPdf` ok, or status back to idle alone.
- Spooler `EnumJobs` fields are correlation-only.
- Tray 1 out of paper is USB status `41236`.

```powershell
flutter run -d windows
```

### Manual checklist (physical Brother)

Run only after a Windows rebuild against a live HL-L3280CDW; do not claim these passed from unit tests alone.

1. Restart the Windows kiosk so the native printer plugin rebuilds.
2. Quick Print a **1-page** PDF.
3. UI should show “Confirming print…” then success (no `completed requires reconcileStatus=verified` error).
4. Admin/API print job: `status=completed`, `reconcileStatus=verified`, `pagesReported >= 1`.
5. Optional: pull paper mid-job — expect paper-out from USB status `41236` and printing paused.

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
