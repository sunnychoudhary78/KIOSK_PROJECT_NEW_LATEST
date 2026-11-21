# DOCX print — LibreOffice on the API host

Citizen print-web / mobile may upload `.docx`. The API converts to PDF with LibreOffice headless, then uses the normal PDF quote and kiosk print path.

Install is **one-time on the API VPS** (UAT and prod). Deploy workflows do not install packages.

## Install (Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y libreoffice-writer-nogui
# Fallback if nogui package is unavailable:
# sudo apt-get install -y libreoffice-writer
```

Confirm the binary (as the user that runs PM2, e.g. root or the deploy user):

```bash
which soffice
soffice --version
# Smoke convert:
echo 'Hello' > /tmp/skp-docx-smoke.txt
# Prefer a real .docx; or convert any Writer-openable file in a throwaway dir:
mkdir -p /tmp/skp-docx-out
# Place sample.docx then:
# soffice --headless --nologo --nofirststartwizard --convert-to pdf --outdir /tmp/skp-docx-out /path/to/sample.docx
# ls /tmp/skp-docx-out/*.pdf
```

## API env (optional overrides)

Add to `apps/api/.env` on the host (restart PM2 after change):

| Variable | Default | Meaning |
|---|---|---|
| `SKP_LIBREOFFICE_BIN` | `soffice` | Path or name of LibreOffice |
| `SKP_DOCX_CONVERT_TIMEOUT_MS` | `60000` | Kill hung converts |
| `SKP_DOCX_CONVERT_MAX_CONCURRENT` | `2` | Cap parallel converts |

Example if `soffice` is not on `PATH`:

```bash
SKP_LIBREOFFICE_BIN=/usr/bin/soffice
```

```bash
pm2 restart KIOSK_UAT_API   # or prod process name
```

## Rollout checklist

### UAT
1. Install LibreOffice on UAT API host (commands above); set `SKP_LIBREOFFICE_*` if needed.
2. Merge/deploy API (`pm2 restart KIOSK_UAT_API`) + print-web (+ mobile if shipping).
3. Smoke: QR print session → upload simple `.docx` → confirm quote page count → print at kiosk.
4. Also try: multi-page doc, table, corrupt file (clear error, no hung session).

### Prod
1. Same LibreOffice install on prod API host.
2. Deploy API + clients after UAT pass.
3. Repeat smoke once.

## Failure codes

| Code | User-facing meaning |
|---|---|
| `docx_convert_unavailable` | Binary missing / cannot spawn — upload PDF instead |
| `docx_convert_failed` | Timeout or convert error — try export to PDF |
