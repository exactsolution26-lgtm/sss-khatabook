# SSS Khatabook — Implementation Blueprint (2026-11-03)

## Approved product decisions
- Mobile + Web SaaS; retain existing offline functionality and data.
- Exactly six built-in dashboard choices: Simple, Business, Analytics, Accounting, Collection, Advanced.
- Each user has **one active dashboard** at a time and can switch among these six; no user-created/unlimited dashboards.
- Dashboard choice is presentation only; switching never changes ledger data.
- Optional WhatsApp delivery must require a per-action choice and appropriate consent.
- Show date/time in Asia/Kolkata; store unambiguous UTC timestamps and preserve audit history.
- Target 10,000 registered users; do not claim this load is validated before testing.
- All 10 previously approved features remain in scope; retrieve their exact acceptance criteria before implementing any ambiguous item.

## Architecture decisions to validate
- Flutter responsive Android/iOS/web presentation with shared domain logic.
- Offline persistence via a platform-aware repository interface; SQLite on mobile, suitable browser storage on web.
- Cloud API and PostgreSQL with tenant-scoped records, server-side authorization, migrations, backups, and audit logs.
- Authentication, business membership and roles: owner, authorized staff, platform administrator; enforce least privilege.
- Financial records use integer paise or a documented exact decimal type, with explicit conversion of legacy double/REAL.
- Offline sync: stable UUIDs, outbox, idempotency, retry/backoff, conflict policy, and reconciliation.
- Dashboard definitions are versioned and administrator-managed; one dashboard_selection value per user.
- Chart rendering: native interactive charts in app; optional Python-generated reporting service later, never execute arbitrary user Python.

## Dashboard catalog (planning)
1. Simple: cash, bank, income, expense, recent entries.
2. Business: accounts, parties, receivables, payables, ledger.
3. Analytics: income/expense trends, filters, comparisons, chart choices.
4. Accounting: reconciliations, cash flow, P&L with clearly defined accounting rules.
5. Collection: aging, pending payments, follow-up status, optional WhatsApp.
6. Advanced: cross-period reports, exports, drilldowns, permission-scoped KPIs.

## Implementation gates
A. Baseline: inventory imports/files, add missing declared dependencies, CI analyzer/tests, backup and regression fixtures.
B. Data safety: resolve AccountModel vs accounts schema; remove destructive delete/reinsert patterns only with tested migration; add validation and atomic writes.
C. Cloud design: migrations, tenant isolation tests, auth, secrets management, audit timestamps, data retention.
D. Dashboard prototype: preview and approve all six mobile/web designs before implementing dashboard screens.
E. Features: implement ten approved features against documented acceptance tests, optional WhatsApp and timezone behavior.
F. Integration: offline sync, exports, error handling, accessibility and responsive layouts.
G. Verification: unit/widget/integration/security tests, migration rollback, device/browser matrix, staged rollout.
H. Scale: model 10,000 registered users and explicitly defined concurrent-user profiles; measure p95/p99 latency, error rate, database capacity and cost.

## Initial source findings
- lib/core/utils/date_utils.dart imports package:intl/intl.dart, but pubspec.yaml does not declare intl: a concrete dependency defect.
- lib/database/tables/account_table.dart deletes all accounts before inserting an opening balance: potentially destructive and not tenant safe.
- lib/models/account_model.dart expects fields absent from the accounts table.
- Existing SQLite schema version is 1 without onUpgrade.
- Screens parse invalid money as 0, and expense date uses DateTime.now().toString().
- No verified CI test execution or load test results yet.

## Safety and release
- Commit only to develop/saas-audit-2026-11-03 until reviewed.
- Do not migrate or overwrite real user data without backup, reversible migrations and tests.
- Do not deploy or merge to main without explicit approval and passing checks.
