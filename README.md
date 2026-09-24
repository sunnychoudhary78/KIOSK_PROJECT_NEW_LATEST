# Smart Kiosk Platform

pnpm docker:up
pnpm dev:api  
pnpm dev:admin

Enterprise SaaS platform for a scalable public kiosk ecosystem.

This monorepo contains four independently deployable applications that share one API contract, one domain vocabulary, and a modular **service plugin** model. Version 1 ships two kiosk services; more services (Health Check, Phone Charging, Astrology, Government Services, etc.) are intended to plug into the same spine without rewriting host apps.

| Item            | Value                         |
| --------------- | ----------------------------- |
| Package name    | `smart-kiosk-platform`        |
| Version         | `0.1.0`                       |
| Workspace       | pnpm (`apps/*`, `packages/*`) |
| Node            | `>=20`                        |
| Package manager | pnpm `9.15.0`                 |

---

## Table of contents

1. [What this project is](#1-what-this-project-is)
2. [Applications and stack](#2-applications-and-stack)
3. [System architecture](#3-system-architecture)
4. [Monorepo folder structure](#4-monorepo-folder-structure)
5. [Backend API deep dive](#5-backend-api-deep-dive)
6. [Admin panel deep dive](#6-admin-panel-deep-dive)
7. [Flutter kiosk deep dive](#7-flutter-kiosk-deep-dive)
8. [Flutter mobile deep dive](#8-flutter-mobile-deep-dive)
9. [Shared packages](#9-shared-packages)
10. [Data model (Prisma)](#10-data-model-prisma)
11. [Authentication](#11-authentication)
12. [End-to-end flows](#12-end-to-end-flows)
13. [Configuration and environments](#13-configuration-and-environments)
14. [Quick start](#14-quick-start)
15. [Workspace scripts](#15-workspace-scripts)
16. [CI / CD](#16-ci--cd)
17. [Coding standards and conventions](#17-coding-standards-and-conventions)
18. [Further documentation](#18-further-documentation)

---

## 1. What this project is

### Purpose

Smart Kiosk Platform (SKP) is designed as a multi-tenant operator platform:

- **Citizens** use a mobile app to start services (e.g. generate an OTP for printing).
- **Kiosks** (Windows terminals in public sites) redeem those intents, talk to DigiLocker, and print locally.
- **Operators** manage devices, services, print jobs, and audit trails from a web admin panel.
- **Backend** is a single Node.js API (not microservices in V1) with feature modules and a service catalog.

### V1 services

| Service code       | Name             | What it does                                                            |
| ------------------ | ---------------- | ----------------------------------------------------------------------- |
| `otp_print`        | OTP Print        | Citizen creates an OTP on mobile; kiosk redeems it and prints           |
| `digilocker_print` | DigiLocker Print | Kiosk starts a DigiLocker session, lists documents, creates a print job |

### Extensibility model

Every future kiosk capability follows the same contract:

```text
Service = API module + catalog entry (platform_services)
        + kiosk feature folder
        + optional mobile feature
        + optional admin monitoring page
```

Shared orchestration for printing lives in the `printing` module. Enablement is per device via `service_enablements`. See [`packages/docs/NEW_SERVICE_CHECKLIST.md`](packages/docs/NEW_SERVICE_CHECKLIST.md).

### Design principles (as implemented)

- **Feature-first** folders in Flutter and Admin
- **Modular backend** — each bounded context under `apps/api/src/modules/*`
- **Clean Architecture where useful** — Flutter features split into `domain` / `application` / `data` / `presentation`
- **SOLID without ceremony** — adapters for DigiLocker/SMS; composition in `app.ts`
- **Avoid overengineering** — one API deployable, one Postgres database for V1
- **OpenAPI as contract** — [`packages/api-contracts/openapi/openapi.yaml`](packages/api-contracts/openapi/openapi.yaml)

---

## 2. Applications and stack

| App        | Path                         | Stack                                                  | Role                     |
| ---------- | ---------------------------- | ------------------------------------------------------ | ------------------------ |
| **API**    | [`apps/api`](apps/api)       | Node.js, Express, Prisma, PostgreSQL, Zod, JWT, Vitest | Platform backend (`/v1`) |
| **Admin**  | [`apps/admin`](apps/admin)   | React 19, Vite 6, TypeScript, React Router             | Operator console         |
| **Kiosk**  | [`apps/kiosk`](apps/kiosk)   | Flutter (Windows), Riverpod 3, http                    | On-site terminal         |
| **Mobile** | [`apps/mobile`](apps/mobile) | Flutter (Android/iOS), Riverpod 3, http                | Citizen app              |

Flutter apps use their own `pubspec.yaml` and are **not** part of the pnpm dependency graph. Root pnpm workspace manages JS/TS packages only.

---

## 3. System architecture

### High-level topology

```mermaid
flowchart TB
  subgraph clients [Client Applications]
    Kiosk["Flutter Windows Kiosk"]
    Mobile["Flutter Mobile Android/iOS"]
    Admin["React Vite Admin Panel"]
  end

  subgraph backend [Backend Platform]
    API["Express API /v1"]
    Modules["Feature Modules"]
    Prisma["Prisma ORM"]
    PG[(PostgreSQL)]
  end

  subgraph external [External / Local]
    DigiLocker["DigiLocker Adapter"]
    PrintHW["Local Print Spooler"]
    Notify["SMS Provider noop"]
  end

  Mobile -->|"HTTPS REST + citizen JWT"| API
  Kiosk -->|"HTTPS REST + device JWT"| API
  Admin -->|"HTTPS REST + admin JWT"| API
  API --> Modules
  Modules --> Prisma
  Prisma --> PG
  Modules --> DigiLocker
  Modules --> Notify
  Kiosk --> PrintHW
```

### Logical backend layers

```mermaid
flowchart LR
  Presentation["HTTP routes / controllers"]
  Application["Module services use-cases"]
  Domain["Enums policies entities via Prisma"]
  Infrastructure["Prisma DigiLocker SMS logging"]

  Presentation --> Application
  Application --> Domain
  Application --> Infrastructure
```

### Communication summary

| From → To        | Pattern                                                             |
| ---------------- | ------------------------------------------------------------------- |
| Mobile → API     | REST JSON + Bearer JWT (`citizen`)                                  |
| Kiosk → API      | REST JSON + Bearer JWT (`device`)                                   |
| Admin → API      | REST JSON + Bearer JWT (`admin`)                                    |
| API → DigiLocker | MeriPehchaan OAuth2 + PKCE adapter                                  |
| API → SMS        | No-op adapter (`SKP_SMS_PROVIDER=noop`)                             |
| Kiosk → Printer  | Local OS print adapter (`PrintSpooler`) — **not** via backend       |
| All clients      | `X-Correlation-Id` header; echoed in error envelopes and audit logs |

### Print job lifecycle (shared)

```text
created → ready → printing → completed
                          ↘ failed
                          ↘ expired (where applicable)
```

OTP Print and DigiLocker Print both create jobs through the **`printing`** module. Kiosk reports status with `PATCH /v1/print-jobs/:jobId/status`.

---

## 4. Monorepo folder structure

### Top level

```text
smart-kiosk-platform/
├── apps/
│   ├── api/                 # Node.js + Express + Prisma backend
│   ├── admin/               # React + Vite admin panel
│   ├── kiosk/               # Flutter Windows kiosk
│   └── mobile/              # Flutter Android & iOS citizen app
├── packages/
│   ├── api-contracts/       # OpenAPI source of truth
│   ├── docs/                # Architecture, ADRs, checklists
│   ├── eslint-config/       # Shared ESLint configs
│   └── tsconfig/            # Shared TypeScript bases
├── tooling/
│   ├── docker/              # Local Postgres Compose
│   └── scripts/             # bootstrap.ps1
├── .github/
│   └── workflows/
│       └── ci.yml           # api-contracts, api, admin, flutter jobs
├── .vscode/
│   └── extensions.json
├── .editorconfig
├── .gitignore
├── package.json
├── pnpm-workspace.yaml
├── pnpm-lock.yaml
└── README.md
```

### `apps/api` — backend

```text
apps/api/
├── prisma/
│   ├── schema.prisma
│   ├── seed.ts
│   └── migrations/
│       └── 20260328120000_init/
│           └── migration.sql
├── src/
│   ├── main.ts              # Process entry, env load, listen
│   ├── app.ts               # Express composition + module register()
│   ├── config/              # Typed SKP_* config (Zod)
│   ├── infrastructure/
│   │   ├── database/        # Prisma client singleton
│   │   ├── external/        # DigiLocker + SMS adapters
│   │   ├── http/            # correlation, validate, error-handler
│   │   └── logging/
│   ├── modules/
│   │   ├── identity/        # citizen / admin / device auth
│   │   ├── devices/         # kiosk registry + heartbeat
│   │   ├── services/        # catalog + per-device enablement
│   │   ├── audit/           # append-only audit trail
│   │   ├── printing/        # shared print job orchestration
│   │   ├── otp_print/       # OTP create + redeem
│   │   └── digilocker/      # DigiLocker session + print
│   ├── shared/              # auth helpers, AppError, params
│   └── types/               # AuthPrincipal, AppDeps, Express augments
├── test/
│   └── config.test.ts
├── .env.example
├── package.json
├── tsconfig.json
├── eslint.config.js
└── vitest.config.ts
```

### `apps/admin` — operator UI

```text
apps/admin/
├── index.html
├── vite.config.ts
├── src/
│   ├── main.tsx
│   ├── styles.css
│   ├── app/
│   │   ├── App.tsx
│   │   ├── AppShell.tsx
│   │   └── router.tsx
│   ├── core/
│   │   ├── api/client.ts
│   │   ├── auth/            # AuthProvider, session, context
│   │   ├── config/
│   │   ├── errors/
│   │   └── ui/primitives.tsx
│   ├── features/
│   │   ├── auth/LoginPage.tsx
│   │   ├── dashboard/DashboardPage.tsx
│   │   ├── kiosks/KiosksPage.tsx
│   │   ├── users/UsersPage.tsx
│   │   ├── services/ServicesPage.tsx
│   │   ├── print-jobs/PrintJobsPage.tsx
│   │   ├── digilocker/DigiLockerPage.tsx
│   │   └── audit-logs/AuditLogsPage.tsx
│   └── shared/
├── .env.example
└── package.json
```

### `apps/kiosk` — Windows terminal

```text
apps/kiosk/
├── lib/
│   ├── main.dart
│   ├── app/                 # app.dart, bootstrap.dart, router.dart
│   ├── core/
│   │   ├── auth/            # device JWT via Riverpod Notifier
│   │   ├── config/
│   │   ├── errors/
│   │   ├── logging/
│   │   ├── network/         # ApiClient
│   │   ├── theme/
│   │   └── widgets/
│   ├── features/
│   │   ├── home/
│   │   ├── otp_print/       # domain, data, application, presentation
│   │   ├── digilocker_print/
│   │   ├── device/
│   │   └── session/
│   └── services/
│       └── print_spooler.dart
├── windows/                 # Flutter Windows runner
├── test/
└── pubspec.yaml
```

### `apps/mobile` — citizen app

```text
apps/mobile/
├── lib/
│   ├── main.dart
│   ├── app/
│   ├── core/                # config, network, theme
│   └── features/
│       ├── auth/
│       ├── home/
│       ├── history/
│       ├── otp_print/
│       ├── digilocker/      # placeholder for future mobile-assisted flows
│       └── profile/
├── android/
├── ios/
├── test/
└── pubspec.yaml
```

### `packages/` and `tooling/`

```text
packages/
├── api-contracts/
│   ├── openapi/openapi.yaml
│   └── scripts/validate.mjs
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CODING_STANDARDS.md
│   ├── SECURITY_HARDENING.md
│   ├── KIOSK_LOCKDOWN.md
│   ├── NEW_SERVICE_CHECKLIST.md
│   ├── ASYNC_QUEUE_READINESS.md
│   └── adr/
│       ├── 0001-monorepo.md
│       ├── 0002-auth-principals.md
│       └── 0003-service-plugin-model.md
├── eslint-config/
│   ├── index.js
│   └── react.js
└── tsconfig/
    ├── base.json
    ├── node.json
    └── react.json

tooling/
├── docker/docker-compose.yml    # Postgres 16 (skp / skp_local)
└── scripts/bootstrap.ps1
```

---

## 5. Backend API deep dive

### Entry and composition

- [`apps/api/src/main.ts`](apps/api/src/main.ts) — load `.env`, build deps, listen
- [`apps/api/src/app.ts`](apps/api/src/app.ts) — Helmet, CORS, JSON body, correlation ID, rate limit, `/v1` router, module `register()` calls, error handler

### Modules

| Module       | Responsibility                                             |
| ------------ | ---------------------------------------------------------- |
| `identity`   | Citizen login, admin login, device token exchange          |
| `devices`    | Register kiosk, list devices, heartbeat                    |
| `services`   | Platform service catalog; per-device enable/disable        |
| `audit`      | Append-only audit log listing (admin)                      |
| `printing`   | Create/list/get print jobs; device status updates          |
| `otp_print`  | Create OTP challenge (citizen); redeem (device)            |
| `digilocker` | Start session, list documents, create DigiLocker print job |

Module rule: depend on another module’s public `index` / shared services only; register from `app.ts`.

### HTTP API surface (`/v1`)

| Method  | Path                                 | Principal            | Purpose                                            |
| ------- | ------------------------------------ | -------------------- | -------------------------------------------------- |
| `GET`   | `/health`                            | public               | Liveness                                           |
| `POST`  | `/auth/citizen/login`                | public               | Citizen JWT                                        |
| `POST`  | `/auth/admin/login`                  | public               | Admin JWT                                          |
| `POST`  | `/auth/device/token`                 | public               | Device JWT from key/secret                         |
| `GET`   | `/devices`                           | admin                | List devices                                       |
| `POST`  | `/devices`                           | admin                | Register device (returns key + secret once)        |
| `POST`  | `/devices/:deviceId/heartbeat`       | device               | Heartbeat                                          |
| `GET`   | `/services`                          | admin/device/citizen | Catalog (+ optional device enablement)             |
| `PUT`   | `/services/:serviceCode/enablement`  | admin                | Enable/disable for a device                        |
| `GET`   | `/otp-challenges`                    | citizen              | List own recent OTP print sessions                 |
| `POST`  | `/otp-challenges`                    | citizen              | Create OTP                                         |
| `POST`  | `/otp-challenges/redeem`             | device               | Redeem OTP → print job                             |
| `POST`  | `/digilocker/sessions`               | device               | Start DigiLocker OAuth (pending + authorize URL)   |
| `GET`   | `/digilocker/sessions/:id`           | device               | Poll session status                                |
| `GET`   | `/digilocker/sessions/:id/documents` | device               | List issued documents                              |
| `POST`  | `/digilocker/sessions/:id/print`     | device               | Download PDF → print job                           |
| `GET`   | `/api/v1/auth/digilocker/callback`   | public               | MeriPehchaan OAuth callback (exact registered URI) |
| `GET`   | `/print-jobs`                        | admin                | List jobs                                          |
| `GET`   | `/print-jobs/:jobId`                 | admin/device/citizen | Get job                                            |
| `GET`   | `/print-jobs/:jobId/content`         | device               | Download job PDF                                   |
| `PATCH` | `/print-jobs/:jobId/status`          | device               | `printing` / `completed` / `failed`                |
| `GET`   | `/audit-logs`                        | admin                | Audit trail                                        |

Full schemas: [`packages/api-contracts/openapi/openapi.yaml`](packages/api-contracts/openapi/openapi.yaml).

### Infrastructure adapters

| Adapter    | Path                                           | V1 behavior                                            |
| ---------- | ---------------------------------------------- | ------------------------------------------------------ |
| DigiLocker | `infrastructure/external/digilocker.client.ts` | MeriPehchaan OAuth2 + PKCE; issued docs + PDF download |
| SMS        | `infrastructure/external/sms.client.ts`        | No-op                                                  |
| Prisma     | `infrastructure/database/prisma.ts`            | Single Postgres schema                                 |

### Cross-cutting API behavior

- Typed config via Zod (`SKP_*`); fail fast on missing secrets
- `AppError` → `{ code, message, correlationId }` (no stack traces to clients)
- OTP codes stored as SHA-256 hashes; single-use + TTL
- Idempotency keys on OTP redeem and DigiLocker print
- bcrypt for passwords and device secrets
- Global rate limiting (`SKP_RATE_LIMIT_*`)

---

## 6. Admin panel deep dive

Operator console at [`apps/admin`](apps/admin).

| Route / feature | Purpose                                                      |
| --------------- | ------------------------------------------------------------ |
| `/login`        | Admin email/password login                                   |
| `/` Dashboard   | Overview placeholder                                         |
| `/kiosks`       | List devices; register new kiosk (shows one-time key/secret) |
| `/services`     | View platform service catalog                                |
| `/print-jobs`   | Monitor OTP + DigiLocker print jobs                          |
| `/digilocker`   | DigiLocker ops notes / future session UI                     |
| `/audit-logs`   | Security and ops audit trail                                 |
| `/users`        | Seeded-admin note (user CRUD can expand later)               |

Auth token stored in `localStorage` (`skp_admin_token`). API base URL from `VITE_SKP_API_BASE_URL` (default `http://localhost:3000/v1`).

---

## 7. Flutter kiosk deep dive

Windows kiosk at [`apps/kiosk`](apps/kiosk) (`skp_kiosk`), Riverpod 3 (`Notifier` / `AsyncNotifier`).

| Feature                       | Role                                                        |
| ----------------------------- | ----------------------------------------------------------- |
| `home`                        | Device activate (key/secret) + service picker               |
| `otp_print`                   | Enter OTP → redeem → local print → status report            |
| `digilocker_print`            | Start session → list docs → print → status                  |
| `device`                      | Device identity domain placeholder                          |
| `session`                     | Idle timeout policy placeholder                             |
| `services/print_spooler.dart` | Host print adapter (console stub; swap for Windows spooler) |

API base URL via `--dart-define=SKP_API_BASE_URL=...` (default `http://localhost:3000/v1`).

---

## 8. Flutter mobile deep dive

Citizen app at [`apps/mobile`](apps/mobile) (`skp_mobile`), Riverpod 3.

| Feature      | Role                                                      |
| ------------ | --------------------------------------------------------- |
| `auth`       | Citizen mobile OTP login                                  |
| `home`       | Welcome + signed-in hub (active OTP, upload, nearby)      |
| `history`    | Recent OTP print sessions                                 |
| `otp_print`  | Upload PDFs, pay extra pages, receive kiosk OTP by SMS    |
| `nearby`     | Distance-sorted kiosks + map                              |
| `digilocker` | Placeholder for future mobile-assisted DigiLocker consent |
| `profile`    | Language, how it works, about, sign out                   |

DigiLocker print in V1 is **kiosk-led**; mobile focuses on OTP Print.

---

## 9. Shared packages

| Package              | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `@skp/api-contracts` | OpenAPI YAML + validation script                     |
| `@skp/docs`          | Architecture handbook, ADRs, security/ops checklists |
| `@skp/eslint-config` | Shared ESLint for API + Admin                        |
| `@skp/tsconfig`      | Shared TS bases (`base`, `node`, `react`)            |

Dart and TypeScript do **not** share runtime models. Clients follow OpenAPI / HTTP contracts.

---

## 10. Data model (Prisma)

Schema: [`apps/api/prisma/schema.prisma`](apps/api/prisma/schema.prisma)  
Migration: `apps/api/prisma/migrations/20260328120000_init/`

### Enums

| Enum                      | Values                                                           |
| ------------------------- | ---------------------------------------------------------------- |
| `PrincipalType`           | `citizen`, `admin`, `device`, `system`                           |
| `UserRole`                | `citizen`, `admin`, `operator`, `viewer`                         |
| `DeviceStatus`            | `provisioning`, `active`, `inactive`                             |
| `PrintJobStatus`          | `created`, `ready`, `printing`, `completed`, `failed`, `expired` |
| `PrintJobSource`          | `otp_print`, `digilocker_print`                                  |
| `OtpChallengeStatus`      | `pending`, `redeemed`, `expired`, `cancelled`                    |
| `DigiLockerSessionStatus` | `pending`, `authorized`, `expired`, `failed`                     |

### Models

| Model               | Purpose                                      |
| ------------------- | -------------------------------------------- |
| `Tenant`            | Operator organization                        |
| `Site`              | Physical location under a tenant             |
| `User`              | Citizens and admin users                     |
| `Device`            | Kiosk terminal (key + secret hash)           |
| `PlatformService`   | Catalog (`otp_print`, `digilocker_print`, …) |
| `ServiceEnablement` | Per-device service on/off                    |
| `OtpChallenge`      | OTP print intent (hashed code, expiry)       |
| `DigiLockerSession` | Kiosk DigiLocker session                     |
| `PrintJob`          | Shared print work item                       |
| `AuditLog`          | Append-only audit events                     |

### Seed data (`prisma/seed.ts`)

- Tenant `default`, site `Demo Site`
- Services `otp_print` and `digilocker_print`
- Admin + citizen users (see [Quick start](#14-quick-start))
- Devices are **not** seeded — register from Admin → Kiosks

---

## 11. Authentication

Three principal types, one API (see ADR [`0002-auth-principals.md`](packages/docs/adr/0002-auth-principals.md)):

```mermaid
flowchart LR
  Citizen[Citizen Mobile] -->|"User JWT"| API
  AdminUser[Admin Panel] -->|"Admin JWT + RBAC"| API
  Device[Kiosk Device] -->|"Device credential → JWT"| API
```

| Principal | How obtained                                     | Typical authorization                                        |
| --------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `citizen` | `POST /auth/citizen/login`                       | Own OTP challenges                                           |
| `admin`   | `POST /auth/admin/login`                         | Devices, services, jobs, audit (role: admin/operator/viewer) |
| `device`  | `POST /auth/device/token` with device key/secret | Redeem OTP, DigiLocker, heartbeat, job status                |

Tokens: short-lived JWT (`SKP_JWT_SECRET`, `SKP_JWT_ACCESS_TTL_SECONDS`). TLS expected in deployed environments.

---

## 12. End-to-end flows

### Device registration

```text
Admin (JWT) → POST /v1/devices
           ← deviceId, deviceKey, deviceSecret (secret shown once)
Kiosk enters key/secret → POST /v1/auth/device/token → device JWT
Kiosk may POST /v1/devices/:id/heartbeat
```

### OTP Print

```mermaid
sequenceDiagram
  participant Mobile
  participant API
  participant Kiosk
  participant Printer

  Mobile->>API: POST /otp-challenges citizen JWT
  API-->>Mobile: code + expiresAt
  Kiosk->>API: POST /otp-challenges/redeem device JWT
  API-->>Kiosk: printJob
  Kiosk->>Printer: PrintSpooler.printDocument
  Kiosk->>API: PATCH /print-jobs/:id/status
```

### DigiLocker Print

```text
Kiosk → POST /digilocker/sessions
     ← pending session + authorizationUrl
Kiosk → open authorizationUrl (system browser)
Citizen consents on MeriPehchaan
DigiLocker → GET /api/v1/auth/digilocker/callback?code&state
API exchanges code (PKCE), stores access_token server-side, marks authorized
Kiosk → poll GET /digilocker/sessions/:id until authorized
Kiosk → GET  /digilocker/sessions/:id/documents
Kiosk → POST /digilocker/sessions/:id/print { documentId }
     ← printJob (payloadUrl = /v1/print-jobs/:id/content)
Kiosk → GET /print-jobs/:id/content → local PDF → PrintSpooler
Kiosk → PATCH job status
```

Access tokens never leave the API. Redirect URI must match DigiLocker portal registration exactly (`SKP_DIGILOCKER_REDIRECT_URI`). See [`SECURITY_HARDENING.md`](packages/docs/SECURITY_HARDENING.md).

---

## 13. Configuration and environments

### API (`SKP_*`) — from [`apps/api/.env.example`](apps/api/.env.example)

| Variable                                     | Purpose                                       | Local default idea                                           |
| -------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------ |
| `SKP_NODE_ENV`                               | `local` / `dev` / `staging` / `prod` / `test` | `local`                                                      |
| `SKP_PORT`                                   | HTTP port                                     | `3000`                                                       |
| `SKP_LOG_LEVEL`                              | Pino level                                    | `info`                                                       |
| `SKP_DATABASE_URL`                           | Postgres connection                           | `postgresql://skp:skp_dev_password@localhost:5432/skp_local` |
| `SKP_JWT_SECRET`                             | JWT signing (≥32 chars)                       | dev-only placeholder                                         |
| `SKP_JWT_ACCESS_TTL_SECONDS`                 | Access token TTL                              | `3600`                                                       |
| `SKP_CORS_ORIGINS`                           | Comma-separated origins                       | Vite `5173`                                                  |
| `SKP_OTP_TTL_SECONDS`                        | OTP lifetime                                  | `300`                                                        |
| `SKP_OTP_LENGTH`                             | OTP digits                                    | `6`                                                          |
| `SKP_RATE_LIMIT_WINDOW_MS` / `MAX`           | Rate limit                                    | `60000` / `120`                                              |
| `SKP_DIGILOCKER_BASE_URL`                    | MeriPehchaan DigiLocker host                  | `https://digilocker.meripehchaan.gov.in`                     |
| `SKP_DIGILOCKER_CLIENT_ID` / `CLIENT_SECRET` | Portal credentials                            | from DigiLocker portal                                       |
| `SKP_DIGILOCKER_REDIRECT_URI`                | Exact registered callback                     | `http://localhost:3000/api/v1/auth/digilocker/callback`      |
| `SKP_DIGILOCKER_*_PATH` / `SCOPE`            | OAuth + files paths                           | authorize/token/issued/file defaults                         |
| `SKP_SMS_PROVIDER`                           | `noop` or future `twilio`                     | `noop`                                                       |

### Admin (`VITE_SKP_*`)

| Variable                | Purpose                  |
| ----------------------- | ------------------------ |
| `VITE_SKP_API_BASE_URL` | API base including `/v1` |
| `VITE_SKP_APP_NAME`     | UI title                 |

### Flutter

| Define             | Purpose                                       |
| ------------------ | --------------------------------------------- |
| `SKP_API_BASE_URL` | API base (default `http://localhost:3000/v1`) |
| `SKP_ENV`          | Kiosk environment label (kiosk app)           |

### Local Postgres (Docker)

[`tooling/docker/docker-compose.yml`](tooling/docker/docker-compose.yml):

| Setting              | Value                                    |
| -------------------- | ---------------------------------------- |
| Image                | `postgres:16-alpine`                     |
| Container            | `skp-postgres`                           |
| User / password / DB | `skp` / `skp_dev_password` / `skp_local` |
| Port                 | `5432`                                   |

Environments intended: **local → dev → staging → prod** (separate DBs; DigiLocker credentials per environment).

---

## 14. Quick start

### Prerequisites

- Node.js ≥ 20
- pnpm 9.x
- Docker Desktop (for Postgres)
- Flutter stable (for kiosk/mobile)
- Windows SDK / Visual Studio components for Flutter Windows kiosk builds

### Bootstrap

```bash
# 1) Install JS/TS workspace
pnpm install

# 2) Start Postgres (Docker Desktop must be running)
pnpm docker:up

# 3) API env + schema + seed
cp apps/api/.env.example apps/api/.env
pnpm --filter @skp/api prisma:generate
pnpm --filter @skp/api prisma:migrate
pnpm --filter @skp/api prisma:seed

# 4) Run API
pnpm dev:api
# → http://localhost:3000/v1/health

# 5) Admin
cp apps/admin/.env.example apps/admin/.env
pnpm dev:admin
# → http://localhost:5173

# 6) Flutter clients
cd apps/kiosk && flutter pub get
cd apps/mobile && flutter pub get
```

PowerShell helper: [`tooling/scripts/bootstrap.ps1`](tooling/scripts/bootstrap.ps1).

### Seeded credentials

| Principal | Credential                               |
| --------- | ---------------------------------------- |
| Admin     | `admin@smartkiosk.local` / `Admin@12345` |
| Citizen   | `+919999999999` / `Citizen@12345`        |

### First end-to-end smoke path

1. Sign in to Admin → **Kiosks** → register a device → copy `deviceKey` / `deviceSecret`.
2. Run kiosk app → activate with those credentials.
3. Run mobile app → sign in as citizen → **OTP Print** → generate code.
4. On kiosk → **OTP Print** → enter code → confirm print job appears under Admin **Print jobs**.

---

## 15. Workspace scripts

### Root

| Script                           | Description                       |
| -------------------------------- | --------------------------------- |
| `pnpm dev:api`                   | API watch mode (`tsx watch`)      |
| `pnpm dev:admin`                 | Vite admin dev server             |
| `pnpm build:api`                 | Compile API TypeScript            |
| `pnpm build:admin`               | Typecheck + Vite production build |
| `pnpm lint`                      | Lint apps/packages                |
| `pnpm typecheck`                 | Typecheck apps/packages           |
| `pnpm test:api`                  | Vitest for API                    |
| `pnpm docker:up` / `docker:down` | Postgres Compose                  |
| `pnpm bootstrap`                 | `pnpm install` + Prisma generate  |

### API (`@skp/api`)

`dev`, `build`, `start`, `lint`, `typecheck`, `test`, `prisma:generate`, `prisma:migrate`, `prisma:deploy`, `prisma:seed`

### Admin (`@skp/admin`)

`dev`, `build`, `preview`, `lint`, `typecheck`

### Flutter

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # kiosk
flutter run              # mobile device/emulator
```

---

## 16. CI / CD

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

| Job             | What it does                                                 |
| --------------- | ------------------------------------------------------------ |
| `api-contracts` | Validate OpenAPI stub                                        |
| `api`           | Prisma generate/migrate against CI Postgres, typecheck, test |
| `admin`         | Typecheck + production build                                 |
| `flutter`       | `pub get`, analyze, test for kiosk and mobile                |

Triggers: push/PR to `main` and `develop`.

There are **no Dockerfiles** for app images yet; only Compose for local Postgres.

---

## 17. Coding standards and conventions

| Area             | Convention                                                 |
| ---------------- | ---------------------------------------------------------- |
| Repo / packages  | `kebab-case`                                               |
| Flutter features | `snake_case` folders (`otp_print`)                         |
| Backend modules  | `snake_case` matching service codes                        |
| Admin features   | `kebab-case` folders, `PascalCase` components              |
| Service codes    | Stable IDs: `otp_print`, `digilocker_print`                |
| API paths        | Plural nouns under `/v1`                                   |
| Env vars         | `SKP_*` (API), `VITE_SKP_*` (admin)                        |
| Audit actions    | `resource.verb` e.g. `otp.redeemed`, `print_job.completed` |
| Commits          | Conventional Commits e.g. `feat(otp_print): …`             |

Full guide: [`packages/docs/CODING_STANDARDS.md`](packages/docs/CODING_STANDARDS.md).

---

## 18. Further documentation

| Document                                                                                     | Description                                           |
| -------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| [`packages/docs/ARCHITECTURE.md`](packages/docs/ARCHITECTURE.md)                             | Architecture summary                                  |
| [`packages/docs/adr/`](packages/docs/adr/)                                                   | ADRs: monorepo, auth principals, service plugin model |
| [`packages/docs/CODING_STANDARDS.md`](packages/docs/CODING_STANDARDS.md)                     | Coding standards                                      |
| [`packages/docs/SECURITY_HARDENING.md`](packages/docs/SECURITY_HARDENING.md)                 | Security baseline                                     |
| [`packages/docs/KIOSK_LOCKDOWN.md`](packages/docs/KIOSK_LOCKDOWN.md)                         | Windows kiosk lockdown checklist                      |
| [`packages/docs/NEW_SERVICE_CHECKLIST.md`](packages/docs/NEW_SERVICE_CHECKLIST.md)           | How to add a new kiosk service                        |
| [`packages/docs/ASYNC_QUEUE_READINESS.md`](packages/docs/ASYNC_QUEUE_READINESS.md)           | When/how to add async workers later                   |
| [`packages/docs/COMPLETION_REPORT.md`](packages/docs/COMPLETION_REPORT.md)                   | Brief V1 completion status across all four apps       |
| [`packages/api-contracts/openapi/openapi.yaml`](packages/api-contracts/openapi/openapi.yaml) | API contract                                          |

---

## License / status

Private monorepo (`"private": true`). Platform foundation and V1 service spines are in place; MeriPehchaan DigiLocker OAuth is integrated. Real Windows print hardening and fleet remote-update remain intentional next steps.
