# New Service Checklist

Use this when adding a kiosk capability (e.g. Health Check, Phone Charging).

## 1. Identity

- [ ] Choose stable service code (`snake_case`), e.g. `health_check`
- [ ] Add display name + description for catalog

## 2. Backend (`apps/api`)

- [ ] Create `src/modules/<service_code>/` with routes, service, schemas, `index.ts` `register()`
- [ ] Seed / migrate `platform_services` row for the new code
- [ ] Reuse shared modules (`printing`, `audit`, `identity`, `devices`) via public exports only
- [ ] Register module in `src/app.ts`
- [ ] Add external adapters under `infrastructure/external/` if needed
- [ ] Extend OpenAPI in `packages/api-contracts/openapi/openapi.yaml`

## 3. Kiosk (`apps/kiosk`)

- [ ] Add `features/<service_code>/` with domain / application / data / presentation
- [ ] Wire route from home service catalog
- [ ] Respect backend enablement flags

## 4. Mobile (`apps/mobile`) — if citizen-facing

- [ ] Add feature folder and navigation entry
- [ ] Reuse shared auth + API client

## 5. Admin (`apps/admin`)

- [ ] Add feature page for config / monitoring
- [ ] Link from shell navigation

## 6. Quality

- [ ] Unit / integration tests for happy path + authz failures
- [ ] Audit events for start / complete / fail
- [ ] Update `packages/docs/ARCHITECTURE.md` module map
- [ ] ADR if the service introduces a new cross-cutting concern

## Optional later

- [ ] Async queue worker if the service has long-running I/O
- [ ] Client codegen from OpenAPI
