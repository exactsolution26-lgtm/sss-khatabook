# SSS Khatabook — Verification findings (2026-11-03)

Scope: static inspection of development branch source files and availability of local execution tools. This is NOT a completed runtime verification.

## Confirmed code issues
- Fixed during review: Money.parseRupees regex incorrectly escaped the decimal point; corrected in commit c28538a4.
- Existing expense and opening-balance screens use double.tryParse(... ) ?? 0, silently converting malformed input to zero.
- SQLite stores monetary values in REAL and has no onUpgrade migration. New Money helper is not yet connected to persistence.
- AccountModel fields (name, opening_balance, created_at) do not match accounts table (cash_balance, bank_balance).
- Current account-table write updates a single existing row; this is not multi-tenant or suitable for arbitrary multiple accounts.
- Dashboard selection uses local shared_preferences only; no account-scoped preference sync or actual six dashboard implementations.
- Expense screen is not registered in AppRoutes.
- Attachments, download, share, WhatsApp, SaaS auth, user isolation and offline/cloud sync are not implemented in the inspected app.
- No Flutter/Dart executable was available in the local execution environment, so flutter analyze/test/build could not be run here.
- GitHub Actions workflow has been committed but no successful run logs were obtained or verified in this review.

## Coverage status
- Static review: partial, source files listed above.
- Money arithmetic test cases: committed, not executed as Flutter tests.
- Database migration and account isolation tests: not executed.
- Mobile, web, attachment, share and WhatsApp integration tests: not executed.
- 10,000-user load test: not executed.
- Production readiness: NOT VERIFIED.

## Required next gates
1. Fix malformed-input handling and show user-visible validation.
2. Implement versioned, backed-up migration from legacy REAL to integer paise with reconciliation.
3. Implement tenant-scoped cloud model and access-control tests.
4. Build the actual dashboards and transactional attachment flows.
5. Execute Flutter analyzer/tests on GitHub Actions and inspect logs; repair failures.
6. Execute device/browser, end-to-end and load tests with defined concurrency, and document evidence.
