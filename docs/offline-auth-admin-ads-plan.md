# Master plan addendum: Offline installs, authentication, admin suspension and future ads

Status: PLAN ONLY. Do not implement before architecture approval and threat-model review.

## Platforms
- Installable Android application and Windows desktop application, with local SQLite storage.
- Web SaaS when online. A browser-installed PWA may have limited offline storage and is not equivalent to the native desktop application.
- Local-first transactions, durable pending sync queue, deterministic reconciliation and no silent data loss.
- Support a personal workspace and multiple independent business workspaces per account.

## Authentication
- Phone number with verified OTP, email sign-in, and Google OAuth/OIDC.
- One canonical internal user ID with explicitly verified linked identities; do not merge users merely because email/phone strings match.
- First login and device enrollment require internet. Returning users may access encrypted local data offline using cached, time-limited device authorization.
- Session revocation, device inventory, lost-device recovery, and rate-limited OTP flows.
- Enforce tenant membership on every server query and attachment, with row-level security and cross-tenant tests.

## Super-admin controls
- Suspend individual user or workspace; optionally revoke all device sessions.
- Check server suspension status on every online refresh and at a documented bounded offline-authorization lease expiry.
- Instant remote suspension cannot be guaranteed on a disconnected device; shorter leases reduce offline duration and usability. Choose policy explicitly.
- Preserve encrypted local ledger data and pending entries when suspended; no deletion or data loss.
- Audit actor, target, reason, timestamp and outcome; role separation and two-step confirmation for high-impact actions.
- Never allow super admin bypass to expose unrelated tenant ledger contents without separately governed support permissions.

## Free tier and future advertising
- Feature flags and plan entitlements for free/paid; ads are disabled by default until an explicit launch decision.
- Modular ad placement adapter for free-tier UI only, not transaction entry/save or critical accounting workflows.
- Respect platform ad SDK policies, consent, privacy laws, age-appropriate ads and offline behavior.
- No selling or exposing private financial transaction contents to advertisers.
- Paid plans can remain ad-free.

## Delivery gates
PLAN: platform/auth/lease/sync/ad policy approval.
IMPLEMENT: native builds, encrypted local storage, backend auth/RLS, sync and admin panel.
TEST: offline/online switches, device loss, 2+ users/workspaces, kill-switch expiry, OTP/OAuth, crash and idempotency, ads flag off/on, and 10k-user workload.
FINAL: reproducible builds and documented passing tests before merge or release.
