# Smart Kiosk Platform — Architecture

This document mirrors the approved software architecture for the monorepo.

## Applications

- `apps/api` — Node.js + Express + Prisma + PostgreSQL
- `apps/admin` — React + Vite + TypeScript admin panel
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
| printing | Shared print job lifecycle |
| otp_print | OTP challenge create/redeem |
| digilocker | DigiLocker session + print |

## Contracts

OpenAPI source of truth: `packages/api-contracts/openapi/openapi.yaml`

## ADRs

See [`adr/`](./adr/).
