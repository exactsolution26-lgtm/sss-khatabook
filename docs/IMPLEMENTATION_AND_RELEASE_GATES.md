# SSS Khatabook — 58-point implementation and release gate

Status: **IN PROGRESS**. This is a work plan, not a completion certificate.
Work only on `development/stability-foundation`; do not push to `main`.

## Non-negotiable release criteria
- Android release APK installs, starts and completes core ledger flows on real Android devices.
- Flutter analyzer, unit/widget/integration tests, migration and backup/restore tests pass.
- Web runtime passes browser testing; a successful web compile alone is insufficient.
- Supabase/Postgres RLS isolation tests, role escalation tests, auth and subscription tests pass against an actual database.
- Offline lease cryptographic verification, clock rollback, tampering and renewal are tested.
- No sensitive data leaks across tenants, through backups, logs, notifications or sharing.
- 10k-user load/concurrency tests run against a representative backend.
- No unverified claim of a passing test; archive logs, build commit SHA and artifacts.
- All remaining manual dependencies and skipped checks documented, not marked passed.

## Work order (58 tasks, same numbering as user-approved checklist)
### Phase 1 — Stability
1. Android red-screen root cause: collect device logcat; add startup error instrumentation; test release and debug.
2. Flutter static analyzer: zero errors.
3. Flutter unit and widget tests: zero failures.
4. Android build, install, startup and core workflow smoke tests.
5. Web runtime with browser-compatible persistence.

### Phase 2 — SaaS and security
6. Create/configure Supabase project [MANUAL: project owner].
7. Deploy versioned schema and migrations [BLOCKED until 6].
8. Auth signup/login/logout/reset.
9. Privileged Super Admin provisioning [MANUAL: trusted owner bootstrap].
10. Subscriber lifecycle and invitations.
11. Tenant financial data isolation.
12. RLS and authorization integration tests.

### Phase 3 — Core ledger
23. Customer accounts CRUD.
24. Cash/bank opening balance.
25. Income CRUD.
26. Expense CRUD.
27. Debit/credit and running balance.
28. History/search/filters.
29. Receipt and voucher.
30. Monthly/yearly statements.
31. PDF/Excel/CSV export.
18. Backup/restore and recovery.

### Phase 4 — Billing, license and sync
13. Subscription access and expiry.
14. Payment provider [MANUAL: merchant onboarding/credentials].
15. Signed 30-day lease.
16. Lease expiry/renewal/device and clock rollback.
17. Offline sync/conflicts.
32. Plan CRUD.
33. INR 99 plan.
34. Fixed/percentage discounts.
35. Renewals/payment history.
36. Platform revenue reports.

### Phase 5 — Product and UX
21. Super Admin dashboard.
22. Subscriber dashboard.
37. Ledger WhatsApp sharing.
38. Payment reminder and verified receipt.
39. Monthly statement/subscription alerts.
40. Optional send and draft audit.
41. IST timestamp/audit.
42. Responsive mobile/tablet/desktop.
43. Light/dark themes.
44. English/Hindi across screens.
45. Notifications/error/retry.
46. Branding/splash.
47. Onboarding.
48. Profile/business details.
49. Customer contacts.
50. Custom WhatsApp templates.
51. Due dates/reminder preferences.
52. Dashboard widgets.
53. Advanced reports/charts.
54. Import/deduplication.
55. Settings.
56. Support/feedback.

### Phase 6 — Release verification
19. 10k-user load/concurrency [BLOCKED until backend exists].
20. Security/privacy and end-to-end verification.
57. Android signing and distribution [MANUAL: release signing key custody].
58. UAT and launch approval [MANUAL: owner device testing].

## Evidence checklist for every task
1. Code and migrations committed on development branch.
2. Targeted tests committed.
3. CI job URL, run ID and commit SHA recorded.
4. Manual checks identified explicitly; failures and missing evidence remain open.
5. No production release or APK described as final until release gates pass.

## Immediate known issue
An older debug APK installed but displayed a solid red screen on Android. Removing the root app builder overlay is a hypothesis only, not a verified fix. Obtain device logcat and reproduce on a fresh APK; do not declare the red-screen issue resolved without that evidence.
