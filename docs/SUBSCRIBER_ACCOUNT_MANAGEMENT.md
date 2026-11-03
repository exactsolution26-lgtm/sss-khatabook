# Subscriber account management — backend foundation

Migration: `supabase/migrations/202611040001_subscriber_accounts.sql`.

Capabilities: tenant owner identity, unique subscriber account, active/suspended state, platform-admin-only create/update, owner read-only access, audit on creation/name/status changes. Subscriber account access does not grant access to other tenants' financial ledgers.

Provision the first super admin with trusted server tooling after verifying the intended auth.users UUID. Do not insert a known email or grant admin status based on a client-provided claim.

**Not yet deployed:** No Supabase project connection or production migration execution was provided. No server endpoint, invite/onboarding flow, UI, billing integration or end-to-end RLS verification exists yet. Schema static tests are not a substitute for real PostgreSQL authenticated-role integration tests. The privileged backend must validate auth, rate-limit, handle errors, and write an audit trail. Avoid direct client mutation APIs in production.
