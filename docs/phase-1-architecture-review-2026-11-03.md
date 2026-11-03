# Phase 1 — Architecture review and implementation contract

Date: 2026-11-03. Status: PLAN REVIEW COMPLETED; IMPLEMENTATION NOT YET APPROVED AS PASSING.

## Existing repository findings (verified by reading code)
1. Local schema still seeds a shared 'local-demo' business, 'local-cash' and 'local-bank'. Both Income and Expense writers use these fixed IDs. This is not safe for real multi-user SaaS.
2. The ledger summary accepts a businessId but retrieves balances by fixed account IDs. Other workspaces would fail or show incorrect totals.
3. ExpenseModel and ExpenseTable convert money through double and toStringAsFixed(2); exact paise are not preserved end-to-end.
4. Income and expense transaction IDs use microsecond timestamps, not stable retry-safe UUIDs/idempotency keys.
5. Accounts store a mutable balance alongside transactions. Opening balance updates overwrite the same balance field; reconciliation and opening-balance adjustment policy are missing.
6. There is no authenticated server identity, workspace membership authorization, row-level security, encrypted offline storage or sync queue.
7. Flutter SDK execution, Android/Windows builds and 10k load tests have not been verified.

## Canonical model
- users(id UUID PK, verified identities); devices(id UUID PK, user_id, last_seen, revoked_at)
- workspaces(id UUID PK, kind PERSONAL|BUSINESS, owner_user_id, display_name, status)
- memberships(user_id, workspace_id, role, status); authorize every server operation against membership
- parties(id UUID PK, workspace_id, name, contact fields); composite unique (id,workspace_id)
- accounts(id UUID PK, workspace_id, type CASH|BANK, opening_balance_paise, currency INR); composite unique (id,workspace_id)
- ledger_entries(id UUID PK, workspace_id, account_id, party_id nullable, type, amount_paise integer >0, direction, occurred_at_utc, created_at_utc, created_by, idempotency_key, revision_of nullable)
- attachment_metadata(id UUID, workspace_id, entry_id, encrypted storage reference)
- sync_outbox(workspace_id, device_id, event_id UUID, payload hash, status, retry_count, last_error)
- authorization_leases(device_id, user_id, workspace_id, issued_at, expires_at, signature; max 30 days from server authorization)
- audit_events(actor, workspace, action, entity, time UTC, result); render IST in UI.

## Required invariants
A. No cross-workspace FK, query, export, attachment or cache leak; server RLS/permission checks, deny by default.
B. No data loss or duplicate postings: stable UUID, server unique (workspace_id,idempotency_key), durable outbox, atomic posting and replay.
C. Ledger balances are derived/reconciled from opening amount plus immutable entries, not freely overwritten stored totals.
D. Corrections are reversal/new entry, preserving audit history.
E. Offline lease is server-signed and expires at 30 days; disconnected devices cannot be killed instantly; expiry never deletes local data.
F. Personal and business workspaces share ledger engine but not data; each party is scoped to a workspace.
G. Login via phone OTP, verified email and Google; linked identities require verified proof.
H. Ads off by default and never expose financial transaction data.

## Safe implementation sequence
1. Add new schema and repository contracts in isolated modules, without changing working legacy screens in the same commit.
2. Add two-workspace and two-user tests before wiring new UI.
3. Implement server auth/RLS and authorization tests, then device-bound offline lease.
4. Implement exact-paise ledger and idempotent sync; test crashes, retries, concurrency and reconciliation.
5. Wire personal/business workspace picker, entry forms, dashboard and person-wise ledgers.
6. Backup/restore, Windows/Android packaging, billing and ads flags.
7. Execute Flutter analyze/test/build, real-device E2E, security tests and 10k load tests. Inspect logs and fix all blockers before FINAL.

## Review disposition
PLAN REVIEW: documented.
IMPLEMENT: pending.
TEST: pending.
FINAL: blocked.
Main branch must not be merged or released before proof of passing required tests.

## Product clarification — account ownership and admin (2026-11-03)
- Every registered user is the Owner/Admin of their own personal account by default.
- Every newly created business workspace grants its creator Owner membership automatically through a trusted, atomic server-side creation operation.
- Owner/Admin may manage only their own workspaces, parties, entries, reports, and invited staff permissions. An invited staff member is not automatically a workspace owner.
- Platform Super Admin is a distinct privileged operator for account suspension, subscriptions and system administration; platform role must not grant unrestricted read access to private financial ledgers.
- User-level account administration must never grant access to other users' unrelated personal/business workspaces.
- Implementation prerequisite: audited server-side workspace bootstrap must atomically create workspace and owner membership, since direct client membership inserts remain denied by RLS.

## Final admin hierarchy clarification (2026-11-03)
- Exactly two ADMIN LEVELS: (1) one designated Platform Super Admin, (2) every registered user is administrator/owner of their own account and personal workspace.
- A user creating a business workspace is its owner/admin. Delegated staff/accountant/viewer permissions are not additional platform admin levels.
- Platform Super Admin can manage accounts, plans, suspension and infrastructure but does not automatically have access to private financial ledger contents.
- No user may administer another unrelated user's account. Shared business access is by explicit invitation with scoped non-owner permissions.
- The platform super-admin identity must be provisioned securely on the backend, never selected via client signup or editable profile role. Enforce one active designated platform super-admin identity and audit any recovery/transfer.
