# SSS Khatabook verification report — 4 November 2026 IST

**Result: NOT production-ready. No new verified APK is available.**
Main was not changed or merged. All remote work targets `development/stability-foundation`.

## Counts
- 58 release tasks: 0 fully verified complete; 50 pending (many have partial implementation); 8 blocked by manual/external dependencies.
- Local unittest checks: **16 passed, 0 failed on final rerun**.
- Of those: 8 SQL integrity checks executing trigger strings extracted from the Dart source; 4 legacy migration/backup fixture checks; 4 static subscriber SQL checks.
- JavaScript/Python smoke harness syntax and git whitespace checks passed. These are not application runtime tests.
- **40 Dart test cases across 14 files are NOT EXECUTED on the current code.** PostgreSQL RLS, browser and Android runtime suites are also NOT EXECUTED. Existing tests passing on older commits do not certify this code.

Actual local output: `evidence/2026-11-04/local-checks.txt`.
Full per-task status: `TASK_STATUS_58.md`.

## Fixes and implementation evidence
- Real expenses now carry account_id; missing ownership and invalid amounts are rejected for new writes. Existing unassigned expenses stay untouched and are included in global totals with explicit attribution warnings in reports.
- Local schema v3 installs opening-balance locks after the first transaction and insert/update integrity guards. No migration deletes existing rows or invents legacy ownership.
- One database-opening future is shared by concurrent requests. Financial report aggregates use one transaction snapshot, avoiding N+1 queries and inconsistent totals.
- Dashboard, customer account editor, account ledger search and income/expense/report/timer/settings navigation are connected.
- Theme/language choices are persisted; full Hindi coverage remains incomplete. Forms scroll above mobile keyboards. Timer action buttons have bounded widths.
- ISO UTC timestamps and legacy local timestamps can both be read; regression tests cover account rows created by the existing ISO-writing code.
- Startup/framework/async failures expose stable support codes and source-location stacks rather than exception values. Runtime harnesses fail on those markers, so the safer error surface cannot turn failures into passing acceptance checks.
- WhatsApp financial messages resolve saved records again immediately before opening. Hand-entered receipt/ledger/monthly-statement drafts cannot be shared. User opt-in, Skip and WhatsApp's own Send confirmation remain required. No message was sent during development.
- Added financial tenant schema with composite tenant/party foreign keys, paise integers, RLS without a platform-admin financial bypass, version guards, idempotency uniqueness and server-owned metadata audit. It is undeployed and unverified.
- Added disposable PostgreSQL role tests, real browser IndexedDB persistence test and Android emulator install/start/dashboard test with screenshot/logcat capture. Their existence is not a passing test result.
- CI now has bounded analysis/test execution, concurrency cancellation for future runs, analyzer/test prerequisites for platform builds, debug and release compilation, explicit testing-signature labels and artifact SHA256/build commit files.
- Generated Android runners receive INTERNET permission, cleartext disabled and OS automatic backup disabled. Local DB encryption is still unfinished.

## Root-cause investigations
1. Historic run **41692307209**, jobs **126113730657** and **126113730779**, failed because shared_preferences was undeclared at that historic commit. Current baseline already declares it; current analyzer success remains unproven.
2. The Python backup fixture held an uncommitted write transaction when calling sqlite3.backup on that connection. This hung indefinitely. Committing the fixture before backup resolves the reproducer; all four fixture tests pass after the fix.
3. Inspected old run **41694471162**, job **126121260445**, is still in progress at the SQLite migration fixture step after its analyzer/unit tests passed. The retrieved run listing contains 19 older runs marked in progress, with newer runs queued. Not every older job was individually inspected.
4. First implementation commit **a07ead42ae3d1e1bbde90944314697ee172a1de6** generated run **41700967999**, later cancelled by the new concurrency rule. Baseline **e88fb18c0d5ff22aa1d7aeee13f5ff843c457c0c** generated queued run **41698303742**. Latest implementation commit **72880be8d44afa49019f5319d753909882162f21** generated Flutter run **41703447919** (job **126152464443**) and PostgreSQL run **41703447988** (job **126152455185**); both are **QUEUED**, not passed.
5. The user's 1002291016.jpg screenshot was visually inspected: solid red screen, no readable exception or stack. It does not establish the red-screen cause. Root overlay removal remains an earlier hypothesis. The additional timestamp fix does not prove this specific red screen is fixed.

## Security and privacy findings
Resolved in code / local SQL checks: missing new-expense account association, controller/form non-finite validation, direct SQL invalid-money guards, opening balance rewriting after transactions, free-text financial sharing, raw exception display on several forms, and inconsistent legacy expense totals.

Unresolved release blockers: production authentication and recovery, tenant-isolated local stores, backend financial API integration, actual PostgreSQL RLS execution, signed leases, secure storage/encryption, clock rollback tamper resistance, sync conflicts, verified payments/subscription enforcement, backup encryption/recovery, soft delete/edit history, rate limits, account deletion/retention, dependency vulnerability scan and representative 10k-user load.

The current local ledger must not be sold or described as secure multi-tenant SaaS. The financial RLS migration is a foundation, not a deployed security boundary. Existing REAL/double local money requires a separately tested exact-money migration. Draft audit storage is metadata-only but best-effort and not a durable server audit trail.

## Build and QA status
| Check | Current result |
|---|---|
| Local Python unittests | 16 passed |
| Current Flutter analyzer/unit/widget/integration | Not executed; CI queued |
| Current Android debug/release compile | Not executed; CI queued |
| Current APK install/start/core flows | Not executed; emulator job authored; physical UAT required |
| Current Web compile/browser persistence | Not executed; CI queued |
| Real PostgreSQL migration/RLS/role tests | Not executed; CI authored |
| Subscription/payment/lease/sync/security E2E | Not executed / major implementation missing |
| Representative 10k-user load | Blocked by backend/infrastructure |
| Fresh APK download | Unavailable; no verified fresh artifact exists |

## Execution environment blockers
Local Flutter dependency setup was rejected by automatic approval review after an unexpected request to `169.254.169.254` (cloud metadata). It was not retried or bypassed. Only standalone Dart formatting, Python checks and source review continued locally; Flutter dependency/build/test execution was moved to GitHub Actions.

Local PostgreSQL installation could not complete: package downloads were denied by the network allowlist. No destination-policy bypass was attempted. A separate disposable PostgreSQL CI service is configured instead.

The available GitHub connector does not expose run cancellation. Older stuck Actions runs need cancellation to free runner capacity; browser fallback requires user permission. New timeout/concurrency configuration prevents recurrence for future runs but cannot retroactively change old jobs lacking that configuration.

## Manual actions
1. Cancel obsolete stuck development-branch Actions runs, retaining the latest verification run; then inspect/rerun latest failed checks.
2. Configure Supabase and securely authorize migration deployment; bootstrap the verified owner's Super Admin UUID using trusted tooling.
3. Complete merchant onboarding and secure webhook/payment configuration.
4. Configure private release signing outside chat.
5. Supply physical-device startup/logcat/UAT evidence for the red screen and final acceptance.

Never paste passwords, service-role keys or private signing keys into chat. No launch or main-branch merge has been authorized.

## All 20 requested QA categories
| # | Category | Evidence/status on current code |
|---|---|---|
| 1 | Flutter static analysis | Queued; not executed |
| 2 | Flutter unit tests | Part of 40 unexecuted Dart cases |
| 3 | Widget tests | 2 authored cases; not executed |
| 4 | Integration tests | Full end-to-end Flutter integration suite incomplete/not executed |
| 5 | Android debug build | Queued/not executed |
| 6 | Android release build | Queued/not executed; production signing absent |
| 7 | APK installation/startup | Emulator harness authored/not executed; physical device blocked |
| 8 | Web build/browser runtime | Build and real IndexedDB smoke authored/not executed |
| 9 | Database migrations | 4 legacy Python fixture tests + 8 extracted-SQL checks pass; actual Dart/PostgreSQL callbacks not executed |
| 10 | Backup/restore | One fixture snapshot/restore check passes; production encrypted app recovery absent |
| 11 | Authentication/RLS | PostgreSQL role script authored/not executed; auth flows incomplete |
| 12 | Subscription/payment | Existing local policy cases not executed on this commit; payment backend absent |
| 13 | Offline lease | Existing unsigned policy cases not executed; signed verification absent |
| 14 | Offline synchronization | Incomplete/not executed |
| 15 | WhatsApp drafts/sharing | Record-verification regressions authored/not executed; no external message sent |
| 16 | Security/privacy | SQL guard/static checks pass; error-privacy regression authored/not executed; comprehensive audit open |
| 17 | 10,000-user load/concurrency | Blocked; no representative backend |
| 18 | Regression | 16 local checks pass; 40 Dart cases not executed |
| 19 | Crash/recovery | Runtime harnesses fail on stable error markers; not executed |
| 20 | Final acceptance | Blocked/not executed; no final APK certification |

## GitHub evidence links
- [First implementation commit](https://github.com/exactsolution26-lgtm/sss-khatabook/commit/a07ead42ae3d1e1bbde90944314697ee172a1de6)
- [Latest implementation commit](https://github.com/exactsolution26-lgtm/sss-khatabook/commit/72880be8d44afa49019f5319d753909882162f21)
- [Flutter/platform verification — 41703447919](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41703447919)
- [PostgreSQL security verification — 41703447988](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41703447988)
- [Inspected historical backup hang — 41694471162](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41694471162)

These links identify evidence locations; queued jobs do not supply passing test evidence. The docs-only checkpoint commit after the implementation commit intentionally skips CI; it changes no application source.
