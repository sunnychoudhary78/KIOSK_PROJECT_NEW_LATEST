# ADR 0003: Service plugin model

## Status

Accepted

## Context

V1 ships OTP Print and DigiLocker Print; many more kiosk services will follow.

## Decision

Each service is a backend module + client feature(s) + catalog entry. Shared print orchestration lives in `printing`. Enablement is per device via `services`.

## Consequences

New services follow `NEW_SERVICE_CHECKLIST.md` without rewriting host shells. Avoid microservices until team/deploy boundaries require them.
