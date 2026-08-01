# Security Hardening

V1 baseline controls implemented or required in ops:

## API

- Helmet security headers
- CORS allow-list via `SKP_CORS_ORIGINS`
- Global rate limiting (`SKP_RATE_LIMIT_*`)
- JWT access tokens with configurable TTL
- Password / device secret hashing (bcrypt)
- OTP codes stored hashed (SHA-256); single-use + TTL
- Idempotency keys on OTP redeem and DigiLocker print
- Structured error envelope without stack traces
- Correlation IDs on every request
- Audit log for auth, device, OTP, DigiLocker, print events

## DigiLocker (MeriPehchaan)

- OAuth2 Authorization Code + PKCE (S256); `code_verifier` and access tokens stored server-side only
- Registered redirect URI must match exactly (`SKP_DIGILOCKER_REDIRECT_URI`), e.g. `http://localhost:3000/api/v1/auth/digilocker/callback`
- Callback is public HTML; kiosk polls session status over device JWT — never expose tokens to clients
- Print flow downloads PDF with the stored access token, persists temp bytes, exposes `GET /v1/print-jobs/:id/content` to the owning device
- Never log client secrets, access tokens, or PKCE verifiers

## Operational

- Separate secrets per environment
- No production DigiLocker credentials in non-prod
- Rotate `SKP_JWT_SECRET` and device secrets via runbooks
- Monitor `audit_logs` for `otp.redeemed` / auth failures
