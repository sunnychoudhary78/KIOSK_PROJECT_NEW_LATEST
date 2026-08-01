# Coding Standards

## Universal

- Feature-first folders; avoid unowned catch-all `utils`
- Explicit error codes; never leak stack traces to clients
- Structured logs with `correlationId` / `X-Correlation-Id`
- No secrets in source; use `.env.example` only
- Conventional Commits: `feat(otp_print): …`, `fix(api): …`

## Flutter

- Riverpod for state (`StateNotifier` / `AsyncValue` patterns)
- Domain layer free of Flutter UI imports
- Presentation → application → data; never reverse
- Explicit loading / error / empty UI states

## React Admin

- TypeScript strict
- Feature folders own pages and API calls
- `VITE_SKP_*` env vars only (no secrets in SPA)

## Backend

- TypeScript strict
- Validate input at HTTP edge (Zod schemas)
- Services orchestrate; repositories persist
- Idempotency keys for redeem / create-job paths
- Modules export `register(router, deps)` only
