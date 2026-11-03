# 30-day offline lease: architecture plan review

Decision: APPROVED by product owner on 2026-11-03. Duration: 30 days maximum since last successful server authorization.

## Plan review outcomes
- Platform: Android and Windows local-first apps; browser SaaS requires separate storage and offline capability review.
- Authentication: phone OTP, verified email and Google; server user ID is canonical.
- Tenancy: personal and business workspaces; authorize all reads, writes, files and sync by membership and role. No fixed local-demo tenant in release.
- Offline: issue a signed, device-bound, workspace-scoped authorization lease at online login/refresh. Persist securely. Lease expires after 30 days; no offline renewal.
- Suspension: revoke server-side immediately for online API calls; reject reconnect and sync if suspended. For a fully disconnected device, access may continue until the 30-day lease expires. There is no instant remote kill guarantee.
- Expiry: lock protected actions and ledger display without deleting encrypted local data or queued entries; recovery after approved online verification.
- Security: device clock manipulation and compromised devices are risks. Use server-signed expiry, secure time anchors and tamper detection where possible; cannot promise cryptographic enforcement against fully compromised offline clients.
- Accounting: stable idempotency IDs, transactional writes, reconciliation and explicit sync conflicts.
- Ads: feature-flagged future free-tier ads only, never dependent on financial data.

## Implementation order
1. Define canonical user/workspace/member/party schema and access-policy tests.
2. Build auth and server-side tenant policies.
3. Add secure 30-day device lease and suspension checks.
4. Add encrypted local storage, durable offline queue and safe sync.
5. Implement Android/Windows install builds and controlled ads flags.

## Test gates (all must pass before FINAL)
- Two users and multiple workspaces cannot cross-read or cross-write, including guessed IDs.
- Online suspension blocks API calls and sync; offline lease expires at exactly 30 days, including boundary cases and clock rollback attempts.
- Expiry preserves all entries and pending sync; reinstatement resumes safely without duplicates.
- First login requires internet; reconnect and identity linking are safe.
- Flutter unit/integration tests, Android and Windows builds, and realistic 10,000-user load tests.
- Verify user-facing suspension messaging and admin audit logs.

Current status: PLAN REVIEW COMPLETE for 30-day policy; overall architecture and implementation are not yet production verified. Do not merge to main.
