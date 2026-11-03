# SaaS Migration Audit — 2026-11-03

Status: Initial static review only. No Flutter build, integration tests, or 10,000-user load tests have been run.

## Baseline
- Flutter/Dart app with local sqflite database (pubspec.yaml).
- Main entry initializes Flutter and launches MyApp (lib/main.dart).
- App starts at opening balance route (lib/app.dart, lib/routes/app_routes.dart).
- Database helper creates accounts(id, cash_balance, bank_balance) and expenses(id, amount, mode, category, note, date), schema version 1 (lib/database/db_helper.dart).

## Findings and risks
1. **Critical — Model/schema mismatch:** AccountModel expects name, opening_balance, created_at, while the accounts table defines cash_balance and bank_balance instead. Verify all account persistence paths before migrations.
2. **High — Multi-tenancy missing:** Current local schema has no tenant/user identifiers or access policies. Cloud database must enforce tenant isolation server-side.
3. **High — Migration and backup:** Database helper has onCreate but no onUpgrade. Implement versioned, tested migrations and export/restore before changing existing data.
4. **High — Monetary precision:** Financial values use SQLite REAL and Dart double. Plan exact integer minor units (paise) or decimal semantics and a compatibility migration.
5. **High — Input validation:** Opening balance and expense screens silently map invalid numbers to 0. Add validation, appropriate negative/zero rules, and error handling.
6. **Medium — Timestamps:** Expense screen uses DateTime.now().toString(). Store canonical UTC instants and display Asia/Kolkata with explicit timezone conversion; record audit timestamps.
7. **Medium — Navigation:** app_routes.dart only registers opening balance route. Verify routes for other screens and workflow completeness.
8. **Medium — Documentation drift:** README mentions intl and flutter_local_notifications, but pubspec.yaml does not list them. Verify actual imports before adding packages.
9. **High — Web support:** sqflite is not a drop-in web persistence backend. Define a repository abstraction, browser storage strategy, and cloud sync.
10. **High — Performance:** 10,000 users is a target, not a validated capacity. Design load scenarios (concurrent logins, ledger writes, sync, reporting) and measure latency/error rates.

## Proposed sequence (no production changes)
1. Inventory all files, models, controllers, and tests; run flutter analyze and tests in CI.
2. Document the approved 10 feature specifications and optional WhatsApp opt-in rules.
3. Add regression tests and backup/export path for existing offline data.
4. Design auth, tenant-aware cloud schema, row-level authorization, ledger and audit log.
5. Build offline-first sync with conflict handling and idempotent writes.
6. Add web-compatible UI and India timezone display.
7. Validate privacy/security, data migrations, mobile/web end-to-end behavior.
8. Run reproducible 10,000-user workload tests before rollout.

## Safety
- Do not merge into main until tests and review pass.
- Do not replace or delete existing offline customer data.
- WhatsApp delivery must be explicitly optional per relevant action.
