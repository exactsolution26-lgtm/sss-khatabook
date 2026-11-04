# SSS Khatabook 1.0.1 — Testing Preview

Owner-requested release of the features implemented so far. This is a prerelease, not a production-readiness certificate. Built from development/stability-foundation; main is unchanged.

Download **SSS-Khatabook-Preview-1.0.1.apk**. Version1.0.1 (101), separate Android package **com.sss.khatabook.preview**, app label **SSS Khatabook Preview**. Testing signature; the owner's production signing key is not configured.

This app installs alongside the older Khatabook app and starts with its own empty local records. Existing app records are not imported automatically. Keep the old app installed. Only use a compatible exported encrypted backup to transfer data; never uninstall an app merely to overcome a signature mismatch.

## Included
- Local offline accounts, opening balances, income and expenses.
- Clear Saved receipt and actual saved timestamp shown in Indian date/time.
- Category options/custom categories and optional native/saved contact selection; name/phone snapshots stay with each entry.
- Dues, partial payments, remaining balance and auditable reversal.
- Ledger editing, recoverable deletion and audit history.
- Encrypted backup/restore, attachments and PDF/Excel/CSV statements with date-range carry-forward.
- PIN/biometric options, follow-ups and optional device reminders.
- Optional Hindi/English speech with review before filling the form and explicit Save.
- Light/Dark preferences; six labeled reconstruction dashboard previews under Settings. Main dashboard awaits design approval.
- Optional WhatsApp draft preview/Skip; an opened draft does not mean delivered.

## Verification and limits
The release upload is gated on analyzer/unit/database tests, Web save/reload and offline browser restart, and Android release-APK emulator installation/startup/core ledger checks. The Actions run tied to BUILD_COMMIT.txt contains the genuine results and runtime evidence.

Physical-phone verification of contacts, microphone/languages, biometric prompts, notification delivery/boot behavior, PDF sharing and the previously reported red-screen issue remains pending. Six dashboard reconstructions await visual approval; full Hindi translation is unfinished.

Supabase cloud signup/login/tenant client isolation, production billing/payment verification, trusted offline-license provisioning and synchronization remain unfinished or blocked. This preview is built without Supabase credentials for local testing. Do not use it as a hosted multi-subscriber SaaS release.

No production signing, deployed-backend load-test or launch approval is claimed. SHA256SUMS.txt verifies the exact downloadable APK; BUILD_COMMIT.txt identifies its source.
