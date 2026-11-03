# SSS Khatabook — Source Code & Database Audit (Static)
Date: 2026-11-03
Scope: GitHub main tree 113e0dfd6e17700ee360be650f1d606379b58ba4; inspected Dart source, pubspec, routing and schema.
Status: Static source audit completed. Runtime/build, device, migration, security penetration and load tests NOT performed (Flutter/Dart SDK unavailable).

## Blockers (confirmed in source)
1. lib/features/income/income_controller.dart and work_today/work_today_screen.dart use DbHelper.instance, while lib/database/db_helper.dart defines DBHelper with only static database; compile errors.
2. lib/features/income/income_screen.dart and analysis/analysis_logic.dart invoke AccountController.getAllAccounts() absent in account_controller.dart; compile errors.
3. analysis/analysis_logic.dart invokes ExpenseController.getTotalExpensesByAccount() absent in expense_controller.dart; compile errors.
4. income_screen.dart and work_today_screen.dart instantiate SimpleInput with label/maxLines/validator, but widgets/simple_input.dart only supports required hintText/keyboardType/controller; compile errors.
5. income_screen.dart and work_today_screen.dart pass isLoading and nullable onPressed to SimpleButton, but simple_button.dart requires non-null onPressed and has no isLoading; compile errors.
6. core/utils/date_utils.dart imports package:intl/intl.dart; pubspec.yaml lacks intl dependency. work_today/notification_service.dart imports flutter_local_notifications absent from pubspec; dependency resolution errors.
7. db_helper.dart onCreate creates only accounts(id,cash_balance,bank_balance) and expenses; income_table.dart and work_table.dart CREATE TABLE definitions are never executed. Income and work queries will fail if reached.
8. models/account_model.dart expects name,opening_balance,created_at fields absent from accounts schema. Expense schema has no account_id although reports are account-specific.
9. account_table.dart saveOpeningBalance deletes all accounts before inserting a new record. Existing records can be lost and account foreign references broken.
10. app_routes.dart exposes only OpeningBalanceScreen; income, expense, analysis, work screens have no navigation routes.

## Data correctness / reliability
11. Monetary values use SQLite REAL and Dart double; consider integer minor units for exact currency accounting with tested legacy migration.
12. Opening balance and expense screens use double.tryParse(...) ?? 0; invalid input silently becomes zero. Validation and explicit error UX required.
13. expense_table.dart uses ConflictAlgorithm.replace; replacing an existing ID can overwrite records. Use stable transaction IDs, append-only ledger where appropriate.
14. SQLite openDatabase(version:1) has no onUpgrade migrations, foreign_keys pragma or integrity checks; schema evolution and integrity risks.
15. expenses table lacks NOT NULL/CHECK constraints, account linkage and timestamp normalization.
16. work_today timer stop() resets duration before _saveWork(), losing elapsed duration. Resume/start logic can double count after restore; timer is not durable against process termination.
17. date_utils.dart serializes local date-time without timezone offset; does not meet canonical UTC + IST display requirement.
18. No backend auth, tenant ID, row-level isolation, subscription billing or 30-day signed lease implementation found in current source tree.
19. No test/ directory, CI workflows, Android/iOS/Web project scaffolds or assets directories appear in the repository tree. This checkout may not be directly buildable as-is.
20. Only lightTheme exists, and approved decimal numeric keyboard is not consistently implemented.

## Recommended remediation order
A. Freeze and back up legacy SQLite; define migration fixtures and no-loss acceptance tests.
B. Reconcile controllers/widgets/model/schema and dependencies until flutter analyze/build passes.
C. Create versioned, transactional database migrations and integrity tests, retaining legacy data.
D. Add robust monetary validation, transaction integrity and timestamp handling.
E. Add authentication, tenant isolation, offline signed lease, sync protocol and SaaS backend.
F. Add premium themes, native keyboard behavior, routing and functional UX.
G. Run automated tests and real device tests, then 10,000-user workload testing.

## Verification limits
This audit is source-level only. No actual Flutter compiler, unit tests, database migrations, device tests, security scans or 10,000-user load tests were executed. Historical '14 critical / 9 high' requirements were not asserted as verified counts; triage and mapping remain a separate task. All findings should be retested against a complete working project before fixes are merged.
