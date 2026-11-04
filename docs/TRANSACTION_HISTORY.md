# Income and Expense history — approved flow implementation

Owner approved the in-chat history preview on 4 November 2026 and requested implementation, explicitly keeping APK generation on hold.

- Both the main dashboard summary cards and Income/Expenses action tiles open history. Separate Add Income/Add Expense actions retain existing forms. Six reconstruction preview metrics also link to history; explicitly labeled Add actions still open forms.
- Income/Expenses switch, name/mobile/note/account/reference search, category and inclusive accounting date-range filters. Totals sum integer paise for the currently displayed rows. Transaction dates group newest first; within each day save timestamp and ID break ties.
- Preserves unassigned historic expenses in a read-only detail view, without inventing an account or save timestamp.
- Actual database entries across this offline workspace's accounts, without seeded demonstration data. Lazy transaction rows; queries select attachment counts, never attachment payloads. Query is local; hosted subscriber authorization remains unfinished and is not certified by this screen.
- Details show the selected entry's snapshot name/mobile, account, category, payment mode, note, accounting date, original IST save time, last edit time, attachment count and type-specific ID. Offset-free legacy times are explicitly labeled timezone unknown; null/invalid times remain unknown.
- Reuses scoped record editor, recoverable deletion with required reason, attachment viewer/share, automatic audit triggers and allocated-payment restrictions. Reload on returning to history and dashboard.
- PDF receipt re-reads the current record; optional WhatsApp receipts resolve current income OR expense by explicit type and optional account constraint. Preview/opt-in/Skip and pre-open record comparison remain; opening WhatsApp never proves delivery.
- English default, Hindi screen labels, theme-derived colors, wrapping transaction rows for narrow mobile widths.
- Fixes synchronous account-list and dashboard reload callbacks, so returning from a saved entry/account updates financial views without a Future-returning setState assertion. Detail navigation retains the row's exact transaction kind even if the selected tab changes.

## Validation

Verified application source: `2409f4ea33c0b55b3ae52ea5d9bd33ea1a7d671e` on `development/stability-foundation`.

- [CI run 41840457388](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41840457388), analyzer/test job `126611029910`: PASS, zero analyzer issues, **124 Flutter tests**, **12 SQLite checks + 4 static subscriber schema checks**, release Dart asset bundle PASS.
- New history cases use real disposable SQLite: account and type separation with matching income/expense IDs, unknown legacy times/unassigned v3 expense preservation after migration, inclusive accounting dates, search and category filters, integer paise totals, original timestamps after edit/delete/restore, attachments after restore, PDF generation, current-record receipt validation (including changed mode, wrong account, ambiguous/deleted source and unknown timezone).
- Widget acceptance covers real save/edit forms, details → history → dashboard balance refresh, Income/Expenses switch, contact search, both 320px dark and 390px light layouts, account save feedback and recycle-bin restoration. Scrolling/focus in the mobile harness was corrected; assertions remain against real UI and database values.
- Earlier runs exposed an uninitialized date-format locale and Future-returning reload callbacks; both were fixed before the final passing source. Earlier failures are not passing evidence.
- Web job `126612375830` PASS: release compilation, actual browser startup/IndexedDB account save and reload persistence, desktop/mobile screenshots, offline reload and offline cold browser restart. This browser scenario covers the base application/storage path; the new history interactions are covered by the widget acceptance tests above.
- [Disposable PostgreSQL run 41840457356](https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41840457356): PASS. This is fixture-based policy testing, not certification of a deployed Supabase environment or SaaS client isolation.
- Android build/startup and publication jobs intentionally SKIPPED. Updated the native harness to follow the observed history → Add flow while retaining old APK verification compatibility; syntax checked only, no native run on this change. Physical-device verification is pending an authorized APK.

**No new APK or release.** The installed phone application does not include these changes until the owner authorizes a new build. Main was not changed. This completes the history task's code/automated checks; the broader 58-point plan and external/manual blockers remain separate.
