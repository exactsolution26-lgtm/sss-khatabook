# RLS Phase 1 security review and executable test checklist

Status: IMPLEMENTATION FOUNDATION ONLY. SQL has been committed but NOT applied to a live Supabase/PostgreSQL database. No RLS test has passed yet.

## Migration
supabase/migrations/202611030001_khata_rls_foundation.sql

## Safeguards implemented in SQL
- Authenticated auth.uid() checked in helper, scoped to active workspace membership.
- RLS enabled for workspaces, memberships, parties, accounts and entries.
- Client cannot create workspaces, assign roles or change account opening balances directly.
- Viewer may read but not insert entries. Staff/accountant/admin/owner may insert only into an authorized workspace and only with their own created_by.
- Entry updates and deletes denied. Cross-workspace account/party references rejected by composite FKs.
- Unique workspace/idempotency key blocks duplicate insert; service_role must remain server-side.
- Suspensions of membership status block all policies on subsequent requests. Full user-level suspension and 30-day offline leases remain future work.

## Must run against isolated Supabase test project before release
1. Anonymous select/insert rejected.
2. User A cannot select User B's workspace, parties, accounts or entries.
3. User A cannot insert using User B's workspace ID.
4. User A cannot insert using account or party belonging to another workspace.
5. Viewer cannot insert entry; accountant can insert into own workspace.
6. created_by spoofing rejected.
7. Membership suspended => reads and writes denied.
8. Client cannot self-assign owner role or change memberships.
9. Client cannot update/delete immutable entry or overwrite opening balance.
10. Duplicate idempotency key rejected; retry returns prior result through future sync endpoint.
11. Role change and owner transfer require audited trusted backend path.
12. Two users with shared business membership can read only authorized workspace.
13. Server admin suspension must also block signed offline lease renewal and all API endpoints.
14. 10,000-user load and race-condition tests remain pending.

## Review blockers
- Auth provider and cloud instance not configured.
- Trusted workspace bootstrap and membership management RPCs not implemented.
- Super-admin global suspension, 30-day lease issuance/verification, device revocation, audit events, immutable correction workflow not implemented.
- Live PostgreSQL tests and Flutter integration not executed.
- Security-definer functions and grants require independent review in a disposable test database.

Do not apply to production, claim secure production isolation, or merge main until all gates pass.
