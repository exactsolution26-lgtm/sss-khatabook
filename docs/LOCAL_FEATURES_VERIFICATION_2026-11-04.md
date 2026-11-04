# Verified local feature increment — 4 November 2026 IST

Source:4a4668a6beea8b92ff3b08119e4cd18cf001ab0b. This is development evidence, not a completed58-task or production certificate.

Flutter run41791096001: analyzer zero issues,85 Flutter tests pass,12 SQLite fixture tests and4 static subscriber-schema checks pass, Dart bundle and Web build/runtime pass. Web job126445349928 verifies a real account and INR100 opening balance before/after reload. PostgreSQL run41791096003 passes authenticated-role RLS tests in a disposable database; production Supabase deployment is still blocked.

## Local features executed
- AES-256-GCM portable backups, PBKDF2-HMAC-SHA256600,000 iterations, random salt/nonce and authenticated format context. Wrong passphrase and modified ciphertext are rejected.
- Snapshot validation in a disposable SQLite database before the live transaction. Foreign-key errors, unknown SQL-shaped keys and invalid records leave live financial data intact. IDs/contact snapshots/save times/balances survive restore; an encrypted current-state recovery copy persists first.
- Separate encrypted checkpoint vault, seven automatic checkpoints and separate recovery slot. Tests use an injected key provider but real cryptography/SQLite, check changed-data detection and actual resume-triggered checkpoint contents. Production keystore and background OS behavior still need device acceptance; Web checkpoints require unlocking the browser session with a passphrase.
- Schema7 additive migration, attachments saved atomically with income/expense. Excess attachment count rolls back both the financial row and its audit. Type/size checks reject executable HTML; IDs and file bytes survive restore. PDF/image rendering and OS download/share still need physical/platform acceptance.
- Append-only local audit: actual insert/update/delete before/after financial values, contact snapshots and UTC times. Application SQL cannot update/delete audit rows. Device audit is not server-verified or proof against an attacker controlling the database file.
- Record-backed customer ledger PDF/CSV, account isolation, running balances and CSV formula escaping. The generated PDF was actually rendered and visually inspected: no clipping/missing glyphs in the English fixture; INR1,150 closing equals1,000+200-50. Offline font assets include OFL licenses. Hindi shaping remains a visual/device gate.
- Optional six-digit PIN with a salted derived hash, persisted retry throttling, secure-storage failure closed and a gate hiding financial UI until verification. Widget tests prove relocking hides financial content. Keystore is an explicit test adapter; biometric tests simulate OS authentication, never claim real hardware verification.
- Real Ed25519 verification of domain-separated signed30-day leases. Tests reject changed claims/signatures, unknown keys, tenant/device mismatch, expiry and clock rollback. No private signing key or permissive test key is bundled. Issuance, secure trusted-time persistence and production enforcement await backend/key provisioning.

## Current unverified follow-up
Excel XLSX and a public-assets-only offline Web shell/cold-start test are being implemented after this tested source. Do not mark them passed until their own run completes. Receipt phone autofill/international numbers and review-again protection are also in the next increment.

## Explicit limits
No new APK in this increment; Android jobs remain gated. Physical red-screen fix, biometric/contact/file-picker OS behavior, actual Supabase auth/sync/payment verification, production signing and10,000-user backend load are not certified. Many58-plan tasks remain pending; no production-ready label applies.
