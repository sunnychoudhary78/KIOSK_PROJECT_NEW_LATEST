# ADR 0001: Monorepo layout

## Status

Accepted

## Context

Four apps share one product vocabulary and API contract. Independent repos would slow contract changes.

## Decision

Use a pnpm monorepo with `apps/*` and `packages/*`. Flutter apps live under `apps/` with their own pubspecs.

## Consequences

Coordinated CI and shared OpenAPI. JS tooling does not manage Flutter packages.
