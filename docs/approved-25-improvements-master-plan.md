# Approved 25-point improvement backlog — SSS Khatabook

Approved by product owner 2026-11-03. This is a PLAN document, not implemented features or passing tests.

Workflow for every feature: PLAN -> REVIEW -> IMPLEMENT in safe development branch -> TEST with evidence -> FINAL approval. No merge to main until release gates pass.

## Critical (13)
1. Automatic local backup, encrypted and restorable.
2. Cloud backup and verified restore on replacement device.
3. Offline sync conflict resolution across devices.
4. Idempotent transaction IDs, duplicate entry prevention.
5. Encryption for local databases, backups and cloud data.
7. Super-admin suspension, 30-day offline lease expiry and reactivation tests.
9. Immutable audit trail, actor and Asia/Kolkata display timestamps.
11. Ledger reconciliation of cash, bank, party and dashboard totals to integer paise.
12. Opening balance lock/adjustment policy after transactions exist.
20. Safe account recovery for lost phone or changed identity.
21. OTP limits, login rate limiting, security and abuse protection.
22. Realistic 10,000-user performance and concurrent sync testing.
25. Disaster recovery and restore drills.

## High (9)
6. User device inventory and remote sign-out.
8. Owner/Admin/Accountant/Staff/Viewer roles with server authorization.
10. Recoverable deletion/reversal policy and recycle bin where appropriate.
13. Party-wise receivables/payables and outstanding balances.
14. Transaction revision history and immutable correction events.
15. CSV/Excel/PDF import/export with reconciliation and validation.
18. Free/paid/trial subscription billing and entitlement rules.
23. Crash reporting, server monitoring and sync failure alerts.
24. App versioning, supported clients and safe database migrations.

## Medium (3)
16. Search and advanced filters.
17. Payment reminders and due-date follow-ups.
19. Free-tier ads management panel and feature flags (ads off until launch).

## Non-negotiable architecture
- Personal and Business are separate authenticated workspaces. Person/party ledgers are scoped within each workspace.
- Stable user ID, workspace ID, party ID and transaction UUID. Composite references and server-enforced workspace permissions prevent cross-tenant data mixing.
- Signed, device-bound 30-day offline authorization lease; immediate remote kill impossible on a fully disconnected device. Expiry locks protected access but preserves encrypted local entries.
- Android and Windows native offline installations; web SaaS separate.
- Login with phone OTP, email and Google. Never auto-merge identities by matching strings.
- Accounting uses integer paise, atomic postings, idempotent sync, full reconciliation and explicit errors; no silent loss or duplicate entries.
- File attachments and exports obey workspace authorization.
- Six fixed dashboard modes and optional WhatsApp sharing remain approved.
- No advertising access to private ledger contents.

## Implementation sequencing
Phase 1: workspace/user/party schema, authentication/roles and security boundaries; lease and revocation design.
Phase 2: exact-money ledger, transaction correction history, offline queue, backup/restore and conflict tests.
Phase 3: mobile/desktop/web surfaces, device management, reporting and import/export.
Phase 4: billing, monitoring, search/reminders and ads feature flags.
Phase 5: full unit/integration/security/device/load/restore verification and owner approval.

## Release gate
All 25 items must be explicitly marked implemented, deferred with approval, or blocked; never claim PASS without executing the corresponding test. Do not merge into main until required critical and high-priority gates pass and owner approves.
