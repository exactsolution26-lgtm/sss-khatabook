# SaaS Tenant Access Foundation

## Implemented in this increment
- Explicit `superAdmin` and `accountAdmin` roles.
- Tenant-scoped authorization helper, default-deny on mismatched tenants.
- Super admin cannot silently access subscriber ledger data.
- Unit tests for tenant isolation rules.

## Not yet implemented
- Auth provider, verified signed session claims, database row-level security,
  tenant_id on every SaaS financial record, API middleware, audit logging,
  secure support access, provisioning, subscription billing or deployment.
- These client-side Dart rules are NOT a security boundary. Backend must
  verify identity and enforce row-level isolation for every query.

## Acceptance gates
1. Unauthorized cross-tenant reads and writes fail on the actual backend.
2. Every new account is provisioned with a unique immutable tenant ID.
3. Super-admin support access is explicit, scoped, time-limited and audited.
4. No credentials or secret keys are embedded in the mobile or web client.

## 4 November 2026 addition

Undeployed migration `202611040002_tenant_finance.sql` and disposable PostgreSQL role tests add financial isolation/audit/idempotency/version foundations. They have NOT been execution-verified or connected to the Flutter local ledger. See the current test report before interpreting this as a SaaS security boundary.
