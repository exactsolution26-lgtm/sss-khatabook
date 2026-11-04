# Local Android testing — 4 November 2026 IST

User direction: test the phone app locally without Supabase first. SaaS setup is deferred, not certified or removed.

## Verified code and artifacts
- Branch: development/stability-foundation. Main was not changed or merged.
- Tested implementation SHA: f96a7030dd8b863f4161ae5b18299015660ba26d.
- API deprecation fixes: dropdown initialValue and Supabase publishableKey; existing SUPABASE_ANON_KEY build-variable compatibility retained.
- Widget tests use real on-disk SQLite without isolate I/O inside the widget fake clock; the schema opens before the widget test. Scrolling settles before the mobile navigation tap. No assertions or tests were removed.
- Workflow test command has a 240-second process bound, 90-second test timeout and expanded reporting.
- No SUPABASE_URL or SUPABASE_ANON_KEY defines are supplied to these APK builds. Existing startup skips Supabase initialization when both are absent.
- 40 Flutter tests passed; flutter analyze reported no issues; 12 SQLite fixture/integrity and 4 subscriber-schema checks passed; asset bundle built.
- Android debug and release compilation passed. Both artifacts use development/default debug signing, not owner production signing.
- Debug APK installed and started on the API-35 emulator; dashboard accessibility, process survival and logcat startup-error checks passed.
- Release APK compiled and its bytes were verified; release APK emulator startup and the owner's physical-device acceptance are NOT executed.
- Release SHA256: 631257f34c19c81f904c7ef0ecc37e7cae635a9ec1ec150d85b9c5bc79e7723c.
- Debug SHA256: 179a9f1066f724733b1f14b7b3a5f19514099edcc2e2117469139f0bf8d5c994.
- Release file size: 58,794,606 bytes.
- APK artifact: 13288786846, sss-khatabook-testing-apks. Artifact retention ends 11 November 2026; a standalone release testing APK was also delivered to the user.

## Evidence
- Flutter/Android run: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41755348404
- Passing analyzer/tests job: 126330037868.
- Passing Android build job: 126330610732.
- Passing Android debug startup job: 126333342643.
- Earlier real PostgreSQL isolation verification passed on implementation SHA 72880be8d44afa49019f5319d753909882162f21, run 41703447988. No Supabase deployment is implied.

## Open issues and next work
- Web compilation passed in this run; browser acceptance did not execute. Playwright 1.56.1 cannot install Chromium dependencies on the ubuntu-latest runner now resolving to Ubuntu 26.04. Pin a supported runner before resuming Web verification. The overall workflow is therefore failed despite the successful Android jobs.
- Physical Samsung/device installation, red-screen reproduction, offline ledger entry/relaunch acceptance, upgrade compatibility, backups and owner UAT remain open.
- Supabase/auth/subscription/lease/sync/security and scale gates remain open as previously documented. Passing local policy cases does not certify these services.
- Do not uninstall an existing data-bearing app merely to resolve installation conflicts without a tested backup.
- This is a development testing APK, not a final production-ready SaaS release.
