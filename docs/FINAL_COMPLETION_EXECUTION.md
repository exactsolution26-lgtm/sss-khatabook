# Full approved-scope execution — 6 November 2026 IST

Work only on development/stability-foundation. Owner requests completion of all previously approved work, not a new design. No new APK until a fresh explicit build request; main stays untouched. Use IMPLEMENTATION_AND_RELEASE_GATES.md and APPROVED_REQUIREMENTS_MAPPING.md as the full scope; a passing local increment does not mean every SaaS/release gate is complete.

## Dependency-ordered numbered execution

1. Reconcile latest development commits and genuine CI evidence; preserve the six reconstruction layouts and existing financial entry/history behavior.
2. Close configured-cloud fallthrough to the shared offline ledger, including asynchronous-error retry. Keep local mode usable without Supabase. Authenticated tenant storage/sync is required before cloud financial access is enabled.
3. Implement durable business profile with phone/email validation and committed Saved + IST feedback.
4. Provide a getting-started checklist linking actual profile/account/PIN/backup workflows, without fake completion marks or changing existing records.
5. Implement a contact directory with explicit native contact selection/manual fallback; expose directory entries in existing financial contact selection. Editing/deleting a directory contact must preserve historical entry snapshots.
6. Implement saved custom-message template create/edit/delete, bounded at 50, case-insensitive title uniqueness, explicit draft review and optional WhatsApp opening. Custom templates do not become verified financial receipts.
7. Expose bounded existing draft-open history with IST timestamps; never label opening as sending or delivery. This metadata-only local history remains outside ledger backups and is disclosed accordingly.
8. Add profile/contacts/templates/import identifiers to encrypted backup validation/restore, schema migration and recovery; retain schema6–9 compatibility. No silent omission of new workspace records.
9. Implement bounded CSV parsing/import with sample, preview, explicit confirmation, integer-paise validation, accounting-date/contact checks, existing account lookup, idempotency, source-ID conflicts and atomic rollback. Never overwrite existing financial rows. Identical intentional payments can use distinct source IDs.
10. Implement date/account-filtered monthly/category/payment-mode reports using one SQLite snapshot and integer-paise sums. Show period net movement separately from opening balances/unpaid dues; preserve all-account legacy expense accounting.
11. Add recoverable account archival: active pickers exclude archived accounts; all-time reports/history retain their records; SQLite rejects financial writes until restore. Preserve archive state through schema11 migration and backups.
12. Add useful help/backup/voice guidance and safe diagnostic-copy action; no automatic financial/contact data upload or fabricated support submission.
13. Run targeted tests and the full combined analyzer/Flutter/SQLite/PostgreSQL/Web/browser regression suite; fix actual failures and preserve run/commit evidence. No Android builds.
14. Continue remaining security/authentication/subscriber/admin/billing/lease/sync work in dependency order. Live Supabase deployment and trusted owner bootstrap, merchant credentials, trusted license/signing custody, physical-device verification and representative 10,000-user infrastructure are external blockers. Do not replace these with simulations labeled complete.
15. Keep full localization, production encryption/auth integration, advanced SaaS management and device acceptance visible as open gates until independently implemented and verified.

## Review decisions

- Configured cloud previously initialized Supabase then opened the same local MyApp; it must fail closed until a tenant-aware persistence path exists. The startup retry must follow that same decision.
- New non-financial workspace records belong in SQLite schema10 and portable backups, not untracked preferences. Audit directory/profile/template changes without rewriting transaction contacts.
- Import idempotency records intentionally outlive financial deletion so replaying an old source does not silently resurrect deleted financial entries. Changing source contents is an explicit conflict, not an update.
- CSV previews make no writes. Import commits revalidate all caller-constructed entries and recheck accounts/duplicates inside the same transaction. A later failing row rolls back earlier rows and audits.
- Reports are cash-movement reports and must not mislabel period net as overall account balance.
- External WhatsApp, Contacts, voice and file-share behavior still needs physical-device acceptance after a future authorized build.

Final test results and remaining counts will be recorded after CI completes; this plan itself is not evidence of completion.
