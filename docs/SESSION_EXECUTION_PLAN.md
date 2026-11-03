# Execution plan — 4 November 2026 IST

Baseline: e88fb18c0d5ff22aa1d7aeee13f5ff843c457c0c.
Development branch only. Existing production/local data must remain intact.

1. Audit every tracked source, schema and existing test; inspect historic Actions failures.
2. Stabilize startup, navigation, preference loading, web SQLite and amount/account validation.
3. Execute the actual Dart database migration against fresh and legacy fixtures; fix the hanging Python backup fixture.
4. Add tenant financial schema with exact paise, composite tenant foreign keys, RLS, version conflicts and server-owned audit.
5. Test authenticated database roles in disposable PostgreSQL; never substitute string checks for RLS execution.
6. Implement remaining core ledger/report/export, billing, signed lease, auth and sync in dependency order when earlier checks are green.
7. Build web and Android, exercise runtime, capture logs and artifact commit SHA.
8. Reconcile all 58 tasks with evidence, leaving unfinished or untested items open.

## Initial findings
- Historic run 41692307209: analyzer and Android failed because shared_preferences was absent at that commit. The current baseline declares it; this does not prove current checks pass.
- Latest baseline run 41698303742 is queued (not passing). Several earlier runs remain queued/in progress.
- ExpenseModel omitted account_id. New expenses were invisible in account totals.
- Income, expense, analysis and work screens lacked routes from the initial screen.
- Flutter web compiled against native sqflite without a browser factory.
- Python backup fixture never committed its write transaction; sqlite3.backup hangs on that connection.
- Signed offline leases are only a local policy stub; no real signatures or enforcement exist.
- Authentication, payment verification, tenant synchronization and financial RLS were not connected to local ledger flows.
- Exact earlier 25-item list recovered and mapped in APPROVED_REQUIREMENTS_MAPPING.md; 13 critical, 9 high, 3 medium. Ads management is additional explicit scope absent from the 58 headings.

## Manual dependencies
Supabase deployment/access; trusted first-super-admin bootstrap; payment merchant onboarding; release key custody; physical Android UAT. Credentials must be configured securely outside chat.
