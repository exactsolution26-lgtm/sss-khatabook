# Database regression retest — 2026-11-03

Scope: SQLite 3 in-memory execution of the current v2 table definitions reproduced from lib/database/db_helper.dart. This is a schema-level test, NOT a Flutter integration test or full SaaS security assessment.

## Changes
- f17d566: add composite business/account ownership foreign key.
- 956c760: adapt expense write to v2 transactions and update account balance atomically.
- 3677cd8: reject fractional-paise opening balances.
- cef1620: fix SQLite table-level foreign key placement.

## Executed checks — 7/7 PASS
1. Create businesses/accounts/transactions/attachments schema: PASS
2. Reject negative transaction amount: PASS
3. Reject unknown account reference: PASS
4. Reject invalid payment mode: PASS
5. Reject account belonging to another business: PASS
6. Insert valid expense: PASS
7. Reject duplicate transaction id: PASS

Additional SQLite account balance decrement check: PASS.

## Still NOT verified
- Flutter/Dart SDK absent in this execution environment: no flutter analyze, flutter test, Android/web build.
- Account/expense widget integration, exact money conversion and full ledger reconciliation.
- Cloud auth, row-level tenant security, offline sync, attachments and file operations.
- 10,000-user load test.

Do not merge to main or mark release ready until all required runtime and security checks pass.
