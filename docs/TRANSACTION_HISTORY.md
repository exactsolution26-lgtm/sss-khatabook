# Income and Expense history — approved flow implementation

Owner approved the in-chat history preview on 4 November 2026 and requested implementation, explicitly keeping APK generation on hold.

- Both the main dashboard summary cards and Income/Expenses action tiles open history. Separate Add Income/Add Expense actions retain existing forms. Six reconstruction preview metrics also link to history; explicitly labeled Add actions still open forms.
- Income/Expenses switch, name/mobile/note/account/reference search, category and inclusive accounting date-range filters. Totals sum integer paise for the currently displayed rows. Transaction dates group newest first; within each day save timestamp and ID break ties.
- Actual database entries across this offline workspace's accounts, without seeded demonstration data. Lazy transaction rows; queries select attachment counts, never attachment payloads. Query is local; hosted subscriber authorization remains unfinished and is not certified by this screen.
- Details show the selected entry's snapshot name/mobile, account, category, payment mode, note, accounting date, original IST save time, last edit time, attachment count and type-specific ID. Offset-free legacy times are explicitly labeled timezone unknown; null/invalid times remain unknown.
- Reuses scoped record editor, recoverable deletion with required reason, attachment viewer/share, automatic audit triggers and allocated-payment restrictions. Reload on returning to history and dashboard.
- PDF receipt re-reads the current record; optional WhatsApp receipts resolve current income OR expense by explicit type and optional account constraint. Preview/opt-in/Skip and pre-open record comparison remain; opening WhatsApp never proves delivery.
- English default, Hindi screen labels, theme-derived colors, wrapping transaction rows for narrow mobile widths.

Validation pending CI on the implementation commit. Python SQLite migration/integrity 12 checks and subscriber static schema 4 checks passed locally. Added real SQLite/query/financial regression cases and widget navigation/filter/save/detail tests; report their outcome only after CI. Physical-device verification remains pending. No APK requested or built.
