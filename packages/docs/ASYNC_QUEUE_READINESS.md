# Async / Queue Readiness

V1 uses synchronous request/response + DB-backed print jobs with client polling/status patches.

When DigiLocker fetch or document rendering becomes slow:

1. Introduce a worker process (e.g. BullMQ + Redis, or cloud queue)
2. Keep `printing` module as the job state authority in PostgreSQL
3. API enqueues work; worker updates job status (`ready` / `failed`)
4. Kiosk continues to poll `GET /v1/print-jobs/:id` or receives push later (SSE/WebSocket)

Do not split microservices until queue + deploy cadence require it.
