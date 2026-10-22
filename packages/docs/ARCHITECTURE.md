# Smart Kiosk Platform — Architecture

This document mirrors the approved software architecture for the monorepo.

## Applications

- `apps/api` — Node.js + Express + Prisma + PostgreSQL
- `apps/admin` — React + Vite + TypeScript admin panel
- `apps/print-web` — public Vite + React Quick Print site (QR guest upload)
- `apps/kiosk` — Flutter Windows kiosk (Riverpod)
- `apps/mobile` — Flutter Android/iOS citizen app (Riverpod)

## Platform spine

Modules in `apps/api/src/modules`:

| Module | Role |
|--------|------|
| identity | Citizen, admin, device authentication |
| devices | Kiosk registry + heartbeat |
| services | Service catalog + per-device enablement |
| audit | Append-only audit trail |
| printing | Shared print job lifecycle + physical reconciliation |
| otp_print | OTP challenge create/redeem |
| quick_print | Walk-up QR session, guest upload, Razorpay |
| digilocker | DigiLocker session + print |
| fuel_stations | Nearby petrol, diesel, CNG, and EV stations from a synced Delhi NCR catalog |
| print_quota | Phone free-page ledger (reserve / consume / release) |

### Print job reconciliation

`PrintJobStatus` tracks queue state (`ready` → `printing` → `completed` / `failed`). Physical evidence is tracked separately via `reconcileStatus`:

| reconcileStatus | Meaning |
|-----------------|--------|
| `pending` | Awaiting spooler/SNMP evidence |
| `verified` | Physical pages confirmed (`pagesReported >= pagesExpected`) |
| `partial` | Some pages printed, less than expected |
| `reconciliation_required` | Timeout / inconclusive; needs ops review |
| `unknown` | Evidence unavailable (e.g. SNMP down) |

`completed` is accepted only with `reconcileStatus=verified`. Free-page ledger entries move `reserved` → `consumed` only on verified completion; uncertain or partial jobs leave the reservation held and set `needsAdminReview`. Device heartbeats may include a `printer` health snapshot (persisted like surveillance health).

## Contracts

OpenAPI source of truth: `packages/api-contracts/openapi/openapi.yaml`

## ADRs

See [`adr/`](./adr/).
