# APK1.0.2 — build and download verification

Published testing prerelease: https://github.com/exactsolution26-lgtm/sss-khatabook/releases/tag/v1.0.2-preview.20261104

| APK | Exact bytes | SHA256 |
|---|---:|---|
| ARM64 |24715470|b0be9305321929c6cee2f975a5bc98377526354590dcd5d7ce182d7db61357db|
| Universal |70208157|d76928c162a1fa43d147418ff9794aefa9bd573977aa5b2a7b6b1d91ea57f483|
| ARM32 |22681624|60723c0e03c71c2e69d6a908117106fa8aa984a6fd0895220b9d568ffe6bd725|

ARM64 is a complete independently installable APK for ARM64 phones, not a config-only split requiring another APK. Choose Universal if CPU compatibility is unknown. Features are unchanged from1.0.1; version1.0.2 improves download packaging/delivery. English default; local mode needs no Supabase credentials. Testing signature; prior preview certificate may differ. Preserve financial data before any uninstall. Physical ARM-device/UAT remains unverified; no production-readiness claim.

Built source3efb19f6a9acbcb6ed4e886074b6655dc3934df8. Build run41823359970 has zero analyzer issues,100 Flutter tests,12+4 Python checks, successful Web offline runtime and Android release/signature/package/ABI checks. Actual disposable PostgreSQL security run41823360055 passes. No main modification/merge.

Both exact Universal andx64 native binaries passed Android35 emulator install/startup, opening100 + income200 - expense50 =250, saved receipts and process-restart persistence in run41825658096. Initial native attempts failed behind a PixelLauncher ANR system dialog; logs/XML identified that external system app. Test-only fix bfa66ec handles only that observed external overlay and records it, while rejecting SSS-specific ANR/errors. No application binary changed between build and final native retest.

Final release publish job126562646962 succeeded after pinning exact built source to releases/preview-1.0.2-built-source. First publish attempt126561419565 returned403; the same token retained its existing rights. GitHub documents that workflow-modifying target SHAs without an existing reference need additional workflow scope: https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/ . Source snapshot preserves the already-built approved commit; no protected/default branch was changed.

## Genuine public download tests

After publication, an unauthenticated client downloaded the entire ARM64 and Universal APKs from their public GitHub asset links. Both returned HTTP200, exact built byte count and SHA256. A separate non-zero-offset1024-byte request returned HTTP206 with matching Content-Range and exact bytes, proving resume/range support. DOWNLOAD_CHECKS.json is attached to the release.

CI measurements: ARM640.97seconds,Universal2.18seconds. These are measurements from the CI runner, not a promise about the owner's Wi-Fi, ISP or geographic GitHub CDN route. Rebuilding alone cannot guarantee the user's download speed.

## Alternate copies

The exact ARM64 and Universal APKs were copied to ChatGPT downloads. Build artifact ZIP digest was verified before extraction; local APK SHA256 values match GitHub's uploaded asset digests. Two ordered Library saves succeeded and applied local identity metadata. No address book, customer data, production keys or physical-device screenshots are included.

- ARM64: https://chatgpt.com/library?file_id=libfile_1bc3e2bb9ef081918c1b4c0ed0fa230a&account_id=personal
- Universal: https://chatgpt.com/library?file_id=libfile_9a01919d8d5c8191b4610b06a9261193&account_id=personal

Source test/build run: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41823359970
Native retest/publication/download-verification run: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41825658096

SaaS/auth/tenant storage/billing/signed-license issuer/sync, full Hindi translations and six dashboard reconstruction approvals remain open. This release does not complete the58-task product plan.
