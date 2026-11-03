# Mandatory SaaS isolation and accounting integrity rules

Status: binding engineering requirements, NOT proof of implementation or passing tests.

## Hard release blockers
- Never use a fixed 'local-demo' business ID for real signed-in users. Assign immutable authenticated user IDs and tenant/business IDs.
- Every server-side read/write, aggregate, search, export, attachment and sync operation must enforce authenticated tenant membership and permission checks, independently of UI filters.
- Use database-enforced tenant/account relationships and row-level security (where supported); deny access by default.
- Ensure attachments belong to transactions in the same tenant and cannot be downloaded using another tenant's file reference.
- Every entry gets a stable client-generated UUID and a server-enforced unique idempotency key; retries cannot duplicate postings.
- Post transaction plus account/ledger effect atomically. Roll back fully on any failure.
- Do not silently drop entries. Track pending, synced, failed and conflicted states with explicit retry and reconciliation.
- Avoid cached state leakage on logout, account switch, device sharing or browser tab changes.
- Separate ledger domain logic from presentation, persistence and sync adapters. Do not duplicate calculation formulas across screens.
- All totals and reports must derive from authoritative ledger records, never independent manually maintained UI totals.

## Must-run adversarial tests
1. User A in Business A cannot read/write/delete Business B's accounts, entries, parties, files or reports, even with guessed IDs.
2. User A switching to Business B sees only authorized data; previous cached results and files disappear.
3. Offline 100 retries of same transaction produce exactly one posting and one balance effect.
4. Crash between transaction insert and balance update causes full rollback.
5. Concurrent edits, refunds, voids, imports and exports reconcile to the paise.
6. Invalid/empty/oversized amounts and malformed dates cannot be saved.
7. Attachment upload/download/share links cannot cross tenant boundaries.
8. Multiple devices syncing concurrently never lose entries or overwrite another tenant's data.
9. Dashboard, party ledger, monthly report and export reconcile to same filtered transaction set.
10. Run documented load tests for 10,000 registered users and realistic concurrency.

## Current limitations
Local v2 schema has composite business/account foreign key, but application code still uses local-demo. Cloud authentication, tenant authorization and secure sync are not yet implemented. No production isolation claim is justified until implementation and tests pass.
