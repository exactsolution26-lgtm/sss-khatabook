# SSS Khatabook 1.0.2 — Smaller Downloads (Testing Preview)

Fresh owner-requested build of the implemented local application. Same implemented features as1.0.1; this release improves download packaging and verification. No main changes.

## Choose one APK

- **SSS-Khatabook-1.0.2-ARM64.apk**: smaller standalone APK for ARM64 phones. Does not require any other split file or a special installer. Choose only if your phone supports ARM64.
- **SSS-Khatabook-1.0.2-ARM32.apk**: smaller standalone APK for compatible ARM32 devices.
- **SSS-Khatabook-1.0.2-Universal.apk**: larger compatibility option containing all supported CPU architectures.

Application package:com.sss.khatabook.preview. Version name1.0.2; base build102, architecture-specific Android version codes may differ. All APKs are testing-signed in the same build. Production signing key custody is not configured. Earlier preview signatures may differ: preserve/export existing records before any uninstall; do not uninstall an app holding financial data just to overcome a signature mismatch. This release does not automatically recover records from previously uninstalled apps.

## Verification

Release upload requires analyzer/unit/database tests, Web runtime/offline persistence, signature/package/ABI checks and Android35 emulator core-ledger/restart tests of the Universal and x86_64 APKs. ARM64 and ARM32 binaries receive signature/package/ABI checks; physical ARM-device testing remains pending. The native tests use disposable emulator records only.

After publishing, the workflow anonymously downloads the full ARM64 and Universal assets, compares their SHA256 with the built bytes and verifies HTTP206 byte-range/resume behavior. DOWNLOAD_CHECKS.json contains genuine CI results and timing. This does not certify a user's Wi-Fi/ISP speed or guarantee GitHub CDN speed at their location. A separate ChatGPT-hosted copy of the same ARM64 APK is provided by the assistant if its upload succeeds.

## Included and remaining work

Local accounts/opening balance, income/expenses, Saved receipts/IST times, category/contact snapshots, partial payments/reversals, edit/recoverable delete/audit, encrypted backup/restore, attachments, PDF/Excel/CSV/date-range statements, PIN/biometric options, reviewed Hindi/English voice entry, followups/reminders and optional WhatsApp drafts. Six dashboard reconstruction previews remain under Settings pending visual approval. English default, optional Hindi not yet fully translated.

No Supabase credentials are embedded. Local testing works without Supabase. Cloud auth/tenant client isolation, verified billing/lease/sync, complete translations, real contacts/microphone/biometric/reminder/share behavior and physical-device red-screen UAT remain unfinished or blocked. This is a prerelease, not production-ready certification.
