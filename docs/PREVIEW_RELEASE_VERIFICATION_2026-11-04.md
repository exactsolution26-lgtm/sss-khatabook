# Published Android testing preview — 4 November 2026 IST

Owner explicitly requested a new APK release of the work completed so far. Published as a GitHub prerelease; this is not a production certificate. Main was not modified or merged.

- Release: https://github.com/exactsolution26-lgtm/sss-khatabook/releases/tag/v1.0.1-preview.20261104
- Direct APK: https://github.com/exactsolution26-lgtm/sss-khatabook/releases/download/v1.0.1-preview.20261104/SSS-Khatabook-Preview-1.0.1.apk
- APK size: 70,208,157 bytes.
- SHA256: `79073c984cca9e1885238c39d4fdefd852b0e12e98ae27b638facf2e994dabb6` (also confirmed by GitHub release asset digest).
- Version:1.0.1 / build101.
- Package:com.sss.khatabook.preview; label:SSS Khatabook Preview.
- Built source:aa919f71aa092f575e65a946d0b8a80e491b8dae, development/stability-foundation.
- Native verification harness:c8450b656825e794afcfec9e56d7582326162421. No application code changed between build and final native retest.

## Genuine results

| Gate | Result and evidence |
|---|---|
| Analyzer | PASS, zero issues, job126487205310 |
| Flutter tests | PASS,100 tests, job126487205310 |
| Python database/schema checks | PASS,12+4 checks |
| Actual PostgreSQL16 RLS | PASS, run41804242739; test-role isolation, escalation, audit, duplicates/version conflicts/suspension |
| Debug Android build | PASS |
| Release Android build | PASS |
| APK signature/package/version | PASS, apksigner verify and aapt metadata; testing signature |
| Web compilation/runtime | PASS, job126488270968, saved-account persistence, offline reload and offline browser cold start |
| Exact release APK install/startup | PASS, Android35 x86_64 Pixel6 emulator |
| Native core ledger | PASS: opening100 + income200 - expense50 = closing250; success receipts visible |
| Native persistence | PASS: force-stop/relaunch retains250 balance |
| Runtime logs | No matched fatal/SSS startup/framework/async/unhandled errors in final test |
| Release publication | PASS; prerelease is public, not a draft; seven uploaded assets verified by release API |
| Physical-phone UAT/native optional APIs | NOT VERIFIED |
| Production signing/SaaS/merchant/sync/load | Remain blocked or unfinished |

Build and source tests: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41804242608
Final native verification/publication: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41806313621
Final native job126494101243; publish job126495829484.
Native evidence artifact13309303611, ZIP SHA2560c1f9a485276ce765eb70939d4b90b956bbb2ca8fb29abe423ee792170f016ad.
Original APK artifact13308538962, ZIP SHA2561a8970b5af4ae4e12b247aa4264df67dd95d4c28be34c7a03df139630eb9e4ea.

The initial native test failed while locating the Account name label: Android UIAutomator XML omitted Flutter hint text although the form visibly rendered. Startup did succeed. The harness was corrected to use the observed EditText order on the verified screen. The same original release APK was downloaded from the original run, its source and SHA256 checked, then the complete native ledger/restart test passed. The failed test was not relabeled successful, and the original APK was not silently replaced. Final release uses that exact verified binary.

## Installation/data handling

The production signing key is unavailable. This preview deliberately has a separate package and fresh local records, so installing it does not replace or erase the older app. Keep the older app installed; its financial data does not transfer automatically. A compatible exported encrypted backup can be imported explicitly where available. Never advise uninstalling the older app to resolve a signature mismatch.

This APK has no Supabase credentials and supports local testing. Cloud auth/tenant-specific client storage, payment verification, trusted lease issuing/sync, complete Hindi translation and six-layout visual approval remain open. Native contacts, speech, biometrics, reminders and sharing still require real-device acceptance. The old physical red-screen report is not certified resolved solely by an emulator pass.

Release assets include APK, BUILD_COMMIT.txt, SHA256SUMS.txt, APK_METADATA.txt, APK_SIGNATURE.txt, ANDROID_VERIFICATION.txt and RELEASE_NOTES.md. APK metadata/signature are evidence of the testing artifact, not production-key custody.
