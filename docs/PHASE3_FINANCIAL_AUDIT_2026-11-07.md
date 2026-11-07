# Phase 3 financial management audit — 7 November 2026

Scope: customer accounts, opening balances, income, expenses, running ledger, history, receipts, statements and PDF/CSV/XLSX export. Work exclusively on `development/stability-foundation`. Do not build an APK or modify `main` without explicit owner approval.

## Confirmed from source review

1. Customer account create/edit/list/archive/restore and empty-account deletion are implemented. Archived edit was rejected in `AccountTable.saveAccount` (commit 180dfb9). Empty account deletion now rejects pending obligations, follow-ups and recycled entries, not just active income/expenses (commit d561b1b).
2. A targeted regression test covers the archived-edit and pending-dues protections (commit 464a933). It has **not** been executed in this session; do not mark passing without CI evidence.
3. Opening balances use an SQLite integrity guard; saved-time and immutable-after-transaction tests existed previously.
4. Income/expense creation, editing and recoverable deletion exist, but require full authorization, rounding, archived-account and real-device checks.
5. Partial payment allocation/reversal uses integer paise; legacy REAL amounts need reconciliation checks.
6. History has account ledger text search and transaction history filters; large-history pagination remains open.
7. Record-backed receipt sharing exists, but complete printable voucher workflow and native share acceptance remain open.
8. Monthly/yearly/custom-date statement and PDF/CSV/XLSX generation exist; native download/share and Hindi font acceptance remain open.
9. Local SQLite verification is **not** equivalent to production multi-tenant SaaS authorization; live Supabase setup, tenant isolation and device UAT remain blocked.

## Priority implementation and release gates

1. **P0 account integrity**: run the new regression test; ensure account delete checks all foreign-key dependents and archived accounts reject every financial mutation, including direct controller writes and restore paths.
2. **P0 money accuracy**: test integer-paise edge cases, opening-balance lock, partial settlements, reversals, account ownership and legacy REAL migration against fixed fixtures.
3. **P0 history**: add stable keyset pagination, date/type filters and consistent running balances without loading entire history; cover ties, deleted/restored rows and empty states.
4. **P1 vouchers**: implement saved-record-only printable income and expense vouchers with stable identifiers, IST timestamps and explicit draft/share semantics.
5. **P1 reports/exports**: verify all-account vs per-account totals, period carry-forward, legacy unassigned expenses, Hindi rendering, CSV escaping, XLSX and PDF output and native share/download.
6. **P1 automated QA**: Flutter analyzer, full Flutter suite, SQLite migration/integrity, browser/Web persistence and disposable PostgreSQL isolation. Record run IDs, failing cases and fixes.
7. **External acceptance**: actual device tests and live tenant authorization after authorized infrastructure is supplied. No APK generation without owner request.

## Status

**IN PROGRESS, not release-certified.** The source changes above were committed; full Phase 3 automated testing and deployment acceptance are not yet evidenced. Never label the whole phase complete solely because local code exists.
