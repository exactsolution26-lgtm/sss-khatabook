# Executed Workspace SQLite test report — 2026-11-03

Source: development branch test_support/test_workspace_sqlite.py, reproduced verbatim and executed using Python 3.13 sqlite3 in an isolated local container.

Command: python -m unittest -v test_workspace_sqlite.py

Result: Ran 7 tests in 0.009s — OK (7 PASS, 0 FAIL).

Passing checks:
1. Valid personal workspace entry
2. Cross-workspace account rejected by composite FK
3. Cross-workspace party rejected by composite FK
4. Duplicate idempotency key rejected
5. Zero amount rejected
6. Personal and business workspace sums stay separate
7. Invalid workspace kind rejected

Additional adversarial probe: direct insertion of membership (user u2, workspace personal1, viewer) was ACCEPTED by the local schema. This is expected from the absence of server authorization policies, and is a RELEASE BLOCKER for real multi-user SaaS. Local SQLite foreign keys cannot enforce authenticated access.

Not executed: Flutter analyzer/tests/build (Flutter/Dart SDK unavailable), actual Android/Windows devices, cloud auth and RLS, offline lease, secure sync, 10,000-user load.

Verdict: Local schema regression 7/7 PASS. Production user isolation NOT VERIFIED. Do not merge to main.
