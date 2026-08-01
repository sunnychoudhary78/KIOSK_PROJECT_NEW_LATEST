# ADR 0002: Auth principals

## Status

Accepted

## Context

Mobile citizens, admin operators, and kiosk devices need different credentials and authorization.

## Decision

Single API with three principal types: `citizen`, `admin`, `device`. JWT bearer tokens; device credentials exchanged for device tokens at `/v1/auth/device/token`.

## Consequences

Route guards filter by principal type. DigiLocker and OTP redeem require `device`. Admin RBAC uses `admin` / `operator` / `viewer` roles.
