# skp_kiosk

Windows Flutter client for the Smart Kiosk Platform (OTP print, DigiLocker, well-being).

## Printing (Windows)

The kiosk sends PDFs to a **Windows-installed printer** (USB, Wi‑Fi Canon, etc.). Install the manufacturer driver, print a Windows test page, then preferably set that printer as the **default**.

Print jobs request **A4 / plain paper** (not the driver’s leftover Letter/Legal prefs). To avoid Canon **Support Code 2113** (paper setting mismatch):

1. Load **A4** plain paper in the cassette/rear tray.
2. On the printer panel, register cassette paper size as **A4**, media **Plain paper**.
3. In Windows **Printers & scanners → [your Canon] → Printing preferences**, set paper size **A4** as well (for manual/test prints).

Print resolution order:

1. `SKP_PRINTER_NAME` (substring match on the Windows printer name), if set
2. Windows default printer
3. The only installed printer (if there is exactly one)

Face-up trays (typical Canon rear/face-up output) land the last printed page on top. By default the kiosk reverses page order at print time (`SKP_PRINT_REVERSE_PAGES=true`) so the physical stack has page 1 on top. Preview stays in normal order. Use `--dart-define=SKP_PRINT_REVERSE_PAGES=false` for face-down printers.

Example run with an explicit printer:

```powershell
flutter run -d windows --dart-define=SKP_API_BASE_URL=https://uat-kiosk-api.immortaltechnovation.com/v1 --dart-define=SKP_PRINTER_NAME=Canon
```

OTP Print and DigiLocker both use silent `directPrintPdf` (no Windows print dialog).

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
