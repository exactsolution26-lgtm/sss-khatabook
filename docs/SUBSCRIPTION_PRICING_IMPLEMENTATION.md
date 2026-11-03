# Subscription pricing implementation

Default approved monthly plan: INR 99 (9900 paise).

Implemented pure-Dart pricing policy:
- Super-admin-only plan changes (local domain rule)
- Editable base price, duration, active state
- Optional percentage or fixed-amount discount with UTC start/end
- Deterministic quote with original price, savings, and payable amount
- Input validation and policy tests

Not yet implemented: super-admin editing UI, durable backend catalogue,
authenticated admin API, database migrations, customer checkout UI,
payment provider integration, tax computation, immutable price snapshots
for issued orders, audit logs, notifications, and renewal handling.

**Security requirement:** never trust price or role claims from client apps.
Backend must authenticate the super admin, persist plan versions, calculate
quotes itself and verify provider payment webhooks before activating access.
Tax inclusivity/exclusivity must be disclosed before checkout.
