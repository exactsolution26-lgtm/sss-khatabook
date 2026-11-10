# SSS Khatabook master-command tracker

Scope is the 47-task master command. The existing [58-point release plan](IMPLEMENTATION_AND_RELEASE_GATES.md) remains the repository's broader release checklist.

## Phase 1 plan and acceptance checks

1. Verify development HEAD and match the exact tree before edits. Compare the workflow gate result with analyzer and test logs.
2. Reproduce the failing financial regression from CI evidence. Preserve the allocated-payment guard and assert the live balance and obligation remain unchanged.
3. Protect the restore snapshot from concurrent writes and commit the same rows that validation checked. Verify encryption failure leaves the original ledger in place.
4. Measure the existing history query with realistic local volume. Add a backwards-compatible SQLite index migration and verify row identity, foreign keys and rollback.
5. Run the full Flutter, SQLite, PostgreSQL and Web checks. Retain the exact commit and check results.
6. Record permissions and local storage findings separately from hosted subscriber isolation and production scale.

## Phase 2 implementation order

1. Use integer paise when aggregating recorded ledger values. Verify dashboard and exports agree after edits, reversals and recovery.
2. Route the Income and Expenses history screens through bounded SQLite pages. Keep account, category, search and date filters consistent with the result count and total.
3. Show the account running balance in chronological ledger order. Validate date-range carry-forward and stable ordering for equal-date rows.
4. Verify opening balances, partial payments, reports, vouchers and CSV/XLSX/PDF output with recorded examples and device-specific acceptance where available.

## Verification evidence

- [Initial exact-commit Flutter failure](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42877082303/job/130043129711) on `459f14e`. Analyzer passed. The suite logged 158 passes and one stale exception expectation.
- [Corrected Flutter suite](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42878165313/job/130046959181) on `075a2e8`. Analyzer exit 0, 159 Flutter tests, 13 SQLite checks, four static schema checks and Dart release bundle passed.
- [Disposable PostgreSQL isolation](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42877082167/job/130043128259) on `459f14e`. Actual migrations and authenticated-role tests passed against the disposable database.
- [Restore hardening CI](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42878743369) and [PostgreSQL CI](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42878743268) on `fef6cf4`.
- `fef6cf4` had zero analyzer issues, 162 Flutter passes and one new fixture failure before the restore assertion. SQLite and schema checks still ran and passed. The [re-test](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42879258087/job/130050807147) on `0cf71cb` passed all 163 Flutter tests with zero analyzer issues. Chromium compiled Web and persisted data offline, but the profile test lost the initial letter while typing.
- [Migration matrix](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42880519264/job/130055245394) on `39959a4` passed 171 Flutter tests and zero analyzer issues. The same run's [Chromium job](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42880519264/job/130056544047) reproduced the initial-letter issue after clicking to focus.
- [Combined Phase 1 and Phase 2 verification](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42881669067) and [PostgreSQL isolation](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/42881669111/job/130059245305) on `bf89df2`. Analyzer reported zero issues. All 175 Flutter tests, 13 SQLite checks, four schema checks and the Dart release bundle passed. Chromium passed release build, profile persistence, dashboard switching, IndexedDB and offline cold start. PostgreSQL passed actual migration, role isolation, privilege, audit, idempotency, version and suspension assertions.
- Local Python checks on the `fef6cf4` source tree exited 0 with 13 SQLite and four schema tests. The [reproducible history benchmark](../test_tools/sqlite_history_benchmark.py) used SQLite 3.53.1, 10,000 local accounts and 200,000 synthetic rows. Median page latency changed from 64.80 ms to 26.99 ms globally and 6.14 ms to 0.11 ms for one account. It verified identical pages and no duplicate identities before and after indexing. Live multi-user backend measurements remain open.

## Task ledger

File paths identify the affected source or existing evidence. SHAs identify the code or test baseline reviewed. Only VERIFIED PASS counts as a completed task.

| No. | Phase | Requirement | Status | Files or evidence | SHA | Actual tests, remaining work and blockers |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | Flutter Analyzer | VERIFIED PASS | `test/dues_followups_test.dart` | 39959a4 | CI analyzer exit 0, zero issues. The combined Phase 2 run is separate. |
| 2 | 1 | Full Flutter unit/widget suite | VERIFIED PASS | `test/dues_followups_test.dart` | 075a2e8 | CI exit 0 with 159 tests on this fix and 171 tests on 39959a4. Baseline had 158 passes and one stale deletion-exception assertion. |
| 3 | 1 | GitHub CI and evidence | VERIFIED PASS | `.github/workflows/flutter-ci.yml` | fef6cf4 | Baseline gate failed correctly. Independent Python checks now run even if the Flutter gate fails. The combined Flutter, PostgreSQL and Chromium run passed. Exact-SHA logs are linked above. |
| 4 | 1 | SQLite migrations and rollback | VERIFIED PASS | `lib/database/db_helper.dart`, `test/database_regression_test.dart`, `test/database_migration_versions_test.dart`, `test/workspace_completion_test.dart` | 39959a4 | 13 Python SQLite checks and the Flutter fixture matrix passed. Tests exercise v1–v11 upgrades, IDs, balances, timestamps, audit, indexes, foreign keys and rollback/retry. |
| 5 | 1 | Encrypted backup and atomic restore | TESTING | `lib/features/backup/backup_service.dart`, `lib/database/db_helper.dart`, `test/backup_recovery_test.dart` | 0cf71cb | Encrypted round trip, corrupted input, mutable input and recovery encryption failure passed in Flutter CI. Physical process interruption and native/browser restore acceptance remain open. |
| 6 | 1 | Subscriber isolation | BLOCKED | `supabase/migrations/`, `test_tools/postgres/tenant_isolation.sql` | 459f14e | Disposable PostgreSQL authenticated-role tests passed. Provisioned identity, tenant-scoped device storage and sync are required for end-to-end verification. |
| 7 | 1 | Permissions and privacy | IN PROGRESS | `.github/workflows/flutter-ci.yml`, `lib/core/error_reporting.dart`, `lib/features/backup/` | 459f14e | Reviewed generated Android permissions and log redaction. App-private SQLite and restore staging remain plaintext. Device permission, file sharing and at-rest protection remain open. |
| 8 | 1 | Scale and concurrency | BLOCKED | `lib/database/db_helper.dart`, `test_tools/sqlite_history_benchmark.py` | fef6cf4 | Measured 10,000 local accounts and 200,000 synthetic entries with equivalent keyset pages. Flutter suite exercises competing payments/imports. Representative SaaS backend required for simultaneous-user load. |
| 9 | 2 | Income and expense history details | CODE COMPLETE | `lib/features/history/` | 075a2e8 | Full suite passed with history widgets and entry details. Broader native acceptance remains open. |
| 10 | 2 | History pagination and filters | VERIFIED PASS | `lib/features/history/`, `test/transaction_history_test.dart` | efde966 | History UI now uses bounded keyset pages with account/date/category/search filters and full filtered totals. Service and widget regressions passed in the 175-test suite. |
| 11 | 2 | Running balance per transaction | VERIFIED PASS | `lib/features/reports/ledger_export.dart`, `lib/features/accounts/accounts_screen.dart` | 233e663 | Account ledger and exports share one running-balance calculation. Edit/delete/recovery and exact paise reconciliation tests passed in the 175-test suite. |
| 12 | 2 | Opening balance management | VERIFIED PASS | `lib/features/accounts/`, `lib/database/tables/account_table.dart` | 233e663 | Existing tests cover persistence and lock after entries. The cash-plus-bank paise and sub-paise rejection regression passed in the 175-test suite. |
| 13 | 2 | Partial payments and settlements | CODE COMPLETE | `lib/features/dues/`, `test/dues_followups_test.dart` | 075a2e8 | Full suite passed with exact paise, retry, concurrent payment, reversal, and guard tests. |
| 14 | 2 | Monthly, yearly and category reports | CODE COMPLETE | `lib/features/reports/` | 075a2e8 | The year grouping joins the existing month and category views. Multi-year totals are covered in the next CI run. |
| 15 | 2 | Printable receipts and vouchers | CODE COMPLETE | `lib/features/history/transaction_detail_screen.dart` | 075a2e8 | Income receipt and expense voucher have distinct record-backed PDFs and filenames. Native printing acceptance remains open. |
| 16 | 2 | CSV, Excel and PDF exports | CODE COMPLETE | `lib/features/reports/`, `test/ledger_export_test.dart` | 075a2e8 | Format regression tests ran in full suite. Native download/share and Hindi layout acceptance remain open. |
| 17 | 2 | Financial calculations regression | IN PROGRESS | `test/database_regression_test.dart`, `test/dues_followups_test.dart` | 075a2e8 | Existing calculations and settlements passed. Further legacy precision and running-balance reconciliation remain open. |
| 18 | 3 | Record, save and replay audio | NOT STARTED | `lib/features/voice/` | 459f14e | Existing mic flow transcribes speech. Persisted voice recordings and playback still require implementation. |
| 19 | 3 | English, Hindi and Hinglish speech | IN PROGRESS | `lib/features/voice/`, `test/voice_capture_test.dart` | 075a2e8 | Device-adapter and confirmation tests passed. Physical recognizer language accuracy and offline availability remain open. |
| 20 | 3 | Categories and custom categories | CODE COMPLETE | `lib/features/income/`, `lib/features/expenses/`, `test/database_regression_test.dart` | 075a2e8 | Entry form and custom category tests ran in full suite. |
| 21 | 3 | Contact picker and linking | IN PROGRESS | `lib/features/entries/`, `lib/features/workspace/` | 075a2e8 | Directory, manual entry and snapshots tested. Native picker and denial flows require physical-device verification. |
| 22 | 3 | Bills, images and document attachments | IN PROGRESS | `lib/features/entries/attachments.dart`, `test/attachments_test.dart` | 075a2e8 | Attachment validation, persistence and recovery tested. Device picker/share acceptance remains open. |
| 23 | 3 | IST date, time and weekday | CODE COMPLETE | `lib/features/history/transaction_history.dart`, `test/date_utils_test.dart` | 075a2e8 | Date display tests ran. Existing offset-free legacy timestamps remain labeled unknown. |
| 24 | 3 | Saved confirmation | CODE COMPLETE | `lib/features/income/`, `lib/features/expenses/`, `test/entry_forms_test.dart` | 075a2e8 | Entry form tests ran in full suite. Native acceptance remains open. |
| 25 | 3 | Optional WhatsApp | CODE COMPLETE | `lib/features/whatsapp/`, `test/whatsapp_share_test.dart` | 075a2e8 | Opt-in, draft review and saved-record verification covered. Actual device handoff remains open. |
| 26 | 3 | Edit, delete and recovery | CODE COMPLETE | `lib/features/entries/record_recovery.dart`, `test/record_recovery_test.dart` | 075a2e8 | Existing recoverable deletion and attachments tests passed. Phase-level acceptance remains open. |
| 27 | 4 | Six dashboard templates | CODE COMPLETE | `lib/features/dashboard/dashboard_templates.dart`, `test/dashboard_templates_test.dart` | 075a2e8 | Template widget checks ran. Visual review and approval remain open. |
| 28 | 4 | One active dashboard and safe switching | CODE COMPLETE | `lib/features/dashboard/`, `test/dashboard_activation_test.dart` | 075a2e8 | Widget coverage exists for selecting and retaining layouts. Exact-SHA browser evidence tracked separately. |
| 29 | 4 | Two selectable premium themes | CODE COMPLETE | `lib/features/settings/`, `test/dashboard_preferences_test.dart` | 075a2e8 | Light and dark widget coverage exists. Visual review remains open. |
| 30 | 4 | Charts, cards, filters and navigation | IN PROGRESS | `lib/features/dashboard/`, `lib/features/analysis/` | 075a2e8 | Existing dashboard navigation and stored totals covered by widget suite. Full chart/filter reconciliation remains open. |
| 31 | 4 | Individual and Business modes | IN PROGRESS | `lib/features/settings/`, `lib/features/workspace/` | 459f14e | Business profile exists. Full Individual/Business mode behavior remains to be verified. |
| 32 | 4 | Responsive Android and Web | IN PROGRESS | `lib/features/dashboard/`, `test_tools/browser/smoke.cjs` | 075a2e8 | Responsive widget cases ran. Browser and physical Android coverage remain separate. |
| 33 | 5 | Super Admin dashboard | IN PROGRESS | `lib/features/subscribers/`, `supabase/migrations/` | 459f14e | Admin foundation exists. Live privileged operations and bootstrap need backend integration. |
| 34 | 5 | Subscriber account administration | IN PROGRESS | `lib/features/subscribers/`, `supabase/migrations/` | 459f14e | Schema and local foundations exist. Authenticated subscriber end-to-end administration remains open. |
| 35 | 5 | Editable ₹99 monthly plan | IN PROGRESS | `test/subscription_plan_test.dart`, `test/pricing_policy_test.dart` | 075a2e8 | Default policy tested. Durable backend editing and live subscription enforcement remain open. |
| 36 | 5 | Discount and plan management | IN PROGRESS | `test/pricing_policy_test.dart` | 075a2e8 | Pricing policy tests ran. Admin management and server-side application remain open. |
| 37 | 5 | 30-day offline lease | IN PROGRESS | `lib/core/security/offline_lease_policy.dart`, `lib/core/security/signed_offline_lease.dart` | 075a2e8 | Signed lease and expiry tests ran. Trusted issuance, device storage and session enforcement remain open. |
| 38 | 5 | Super Admin kill switch | IN PROGRESS | `lib/core/security/`, `supabase/migrations/` | 459f14e | Account status foundation exists. Revocation and renewal end-to-end behavior remain open. |
| 39 | 5 | Phone, email and Google authentication | BLOCKED | `lib/main.dart`, `lib/core/security/backend_mode.dart` | 459f14e | Cloud startup fails closed. Provider configuration and provisioned backend are required for production authentication. |
| 40 | 5 | Offline-to-online sync | NOT STARTED | `lib/core/security/backend_mode.dart` | 459f14e | Integrated synchronization and conflict handling remain open. |
| 41 | 5 | Free tier and future optional ads | NOT STARTED | Subscription foundation | 459f14e | Tier enforcement and optional advertising integration remain open. |
| 42 | 6 | Comprehensive security audit | IN PROGRESS | `test_tools/postgres/`, `supabase/migrations/` | 459f14e | Disposable database tests passed. Complete release configuration, local data protection and production verification remain open. |
| 43 | 6 | Comprehensive privacy audit | IN PROGRESS | `lib/core/error_reporting.dart`, `lib/features/backup/`, `lib/features/entries/` | 459f14e | Partial source review. Device sharing and lifecycle review remain open. |
| 44 | 6 | Physical Android compatibility | BLOCKED | `test_tools/android/smoke.py` | 459f14e | Requires APK authorization and a physical device for the current source. |
| 45 | 6 | Web browser compatibility | IN PROGRESS | `test_tools/browser/smoke.cjs` | bf89df2 | Chromium release build and offline cold start passed on bf89df2. Firefox, Safari and broader browser coverage remain open. |
| 46 | 6 | Performance, memory, startup and crashes | IN PROGRESS | `test_tools/sqlite_history_benchmark.py`, `test_tools/browser/smoke.cjs` | fef6cf4 | Local SQL pagination measured. Cold-start, memory and crash soak at representative scale remain open. |
| 47 | 6 | Release and universal APK readiness | BLOCKED | `.github/workflows/flutter-ci.yml` | fef6cf4 | Requires owner approval, current physical-device acceptance and production signing. Current work uses non-APK CI. |
