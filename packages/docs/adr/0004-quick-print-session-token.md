# ADR 0004: Quick Print session-token auth

## Status

Accepted

## Context

Walk-up Quick Print must let a phone upload PDFs and pay without installing the citizen app. Existing JWT principals are `citizen`, `admin`, and `device`. Guest upload cannot require a citizen login, and the public page must not live in the admin panel.

## Decision

Do not add a fourth JWT principal. The kiosk (device JWT) creates a `QuickPrintSession` and receives a high-entropy token. The token is shown only in the QR URL, stored as a SHA-256 hash, and authorizes the public upload/pay routes. The kiosk polls and claims with its device JWT. Guest Razorpay payments have a null `userId` and attach to the session, not an `OtpChallenge`.

## Consequences

OTP Print stays citizen-owned. Webhook fulfillment branches: challenge → issue OTP; quick-print session → mark ready. Public routes are rate-limited and never log the raw token. History remains an app-only concern.
