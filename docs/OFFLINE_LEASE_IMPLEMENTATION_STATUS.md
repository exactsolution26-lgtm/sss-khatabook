# Offline lease: implementation status

The pure Dart policy now evaluates tenant/device binding, 30-day maximum
duration, expiry boundary, future issuance and local clock rollback.

**Not production-ready:** A local policy check alone cannot securely authorize
offline access. Pending: signed lease issuance by backend, embedded public-key
verification (not shared secret), trusted server time, tamper-resistant persisted
high-water timestamp, device identity binding, revocation upon reconnect,
renewal UX, and integration with actual app startup and financial writes.
Until these are implemented, do not claim offline authorization is enforced.

The app must never delete or alter financial records on lease expiry. Expiry
should gate privileged operations according to product policy, with a
recoverable renewal path.
