# Kiosk Admin

Phone field console for staff. It uses the same `/v1` admin API as the web panel in `apps/admin`.

Sign in with a staff email and password. The seeded local account is `admin@smartkiosk.local`. `admin` and `operator` can change a kiosk, load paper, resume printing, and resolve support. `viewer` can read those screens and request a printer refresh.

## Run

```bash
cd apps/admin_app
flutter pub get
flutter run
```

The default base URL is `https://uat-kiosk-api.immortaltechnovation.com/v1`, the same UAT API the admin panel uses. Override it with `--dart-define=SKP_API_BASE_URL=http://localhost:3000/v1` when you want a local API. On a phone, `localhost` is the phone itself, so point that URL at the computer running the API.

Android and iOS only. Registering kiosks, pricing, ads, surveillance playback, and platform settings stay on the web panel.
