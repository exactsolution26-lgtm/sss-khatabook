# SSS Khatabook — Master Implementation Plan v1
Date: 2026-11-03
Status: Approved requirements consolidated; implementation pending.
Repository: exactsolution26-lgtm/sss-khatabook
Branch: planning/master-plan-v1

## Product
Offline-first Flutter khatabook evolving into mobile + web SaaS, with Android/iOS clients and responsive web. Preserve existing SQLite data and functions through audited migrations.

## Roles
- Platform Super Admin: platform owner, controls tenants, plans, billing, operational audit and access.
- Tenant Admin: each subscribing customer administers their own account/data.
- Enforce server-side tenant isolation and least privilege; super admin access audited.

## Approved UX
- Premium visual design; selectable light and dark themes.
- Native mobile keyboard: decimal numeric for amounts, phone keypad for telephone, text keyboard for names/descriptions, date picker for dates.
- Validate monetary values, precision, negative values and malformed inputs.
- Interactive screen-by-screen visual reviews and mock tests before final approval.

## Ledger and sharing
- Preserve existing account, income, expense, balance and reporting functions.
- Add approved features after full inventory and mapping to code.
- WhatsApp sharing is opt-in per action, never automatic by default.
- Indian locale and Asia/Kolkata presentation for timestamps; store canonical UTC timestamps with offset-aware conversion.

## Offline and security
- 30-day offline authorization lease, signed/tamper-resistant and verified locally.
- Offline-first queue, durable transaction IDs, idempotent sync, conflict handling, retries, and safe backups.
- Auth/session hardening, secure key storage, tenant authorization, audit trails, and subscription enforcement.
- Lease renewal and expiry must be specified and tested, including clock manipulation and connectivity loss.

## SaaS operations
- Tenant onboarding, subscription plans, renewal and expiration, payment reconciliation, account controls, monitoring, backup/restore and privacy controls.
- Design for 10,000 users; run realistic concurrent-user and sync/load tests. Do not assume 10,000 concurrent users without separate targets.

## Execution gates
1. Full code/database audit, inventory and backup/migration plan.
2. Verify and detail previously approved 14 critical, 9 high, and medium-priority issues; do not invent their exact descriptions.
3. Implement security/data fixes on isolated development branch.
4. Implement tenant SaaS architecture, user/admin, UI, offline lease and features incrementally.
5. Automated unit/integration/security/offline/sync/migration/load tests.
6. User visual/mock approval, staging release and monitored deployment.
7. Merge to main only after tests and explicit approval.

## Acceptance criteria
- No cross-tenant data access; no data loss during migration.
- Offline entries remain usable and synchronize exactly once on reconnection.
- Lease behavior works for valid/expired/clock-tampered conditions.
- Native input keyboards and theme preferences work on supported devices.
- Optional WhatsApp, IST rendering and timestamps work correctly.
- 10,000-user scale target supported by recorded load-test evidence.

## Outstanding clarifications
- Full historical list of ten approved features and exact critical/high/medium findings must be recovered and reconciled against source.
- Billing gateway, cloud database/hosting, retention, exact offline lease renewal policy, concurrency targets and platform rollout order require technical decisions.

This is a planning document, not evidence of implemented code or passed tests.
