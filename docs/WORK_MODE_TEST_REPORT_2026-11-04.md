# Work Mode implementation evidence — 4 November 2026

Status: IN PROGRESS; development testing, not production certification.
Latest tested source:04d20783286a97cbef5cfa66ffeae06ce7e77171; application code unchanged since ab0855af7a00f3810de81309b6a275ab2872291d.
Branch: development/stability-foundation. Main unchanged.

## Executed and passed
| Check | Actual evidence | Scope |
|---|---|---|
| Flutter analyzer | Actions41770051065/job126377355973: No issues found | Tested Dart source |
| Flutter suite | Same job:68 tests passed | Unit/widget, actual SQLite through FFI, preference/migration/financial/save UI checks |
| SQLite fixture checks | Same job:12 tests passed | Integrity guards, legacy v1 migration/backup fixture; not app automatic encrypted backup |
| Subscriber schema checks | Same job:4 tests passed | Static SQL structure; not a substitute for RLS execution |
| Dart asset bundle | Same job success | Release asset compilation; not APK certification |
| PostgreSQL16 security | Actions41770051086/job126377356026 success | Applies actual migrations, authenticated-role RLS, cross-tenant access, escalation, audit, duplicates, version conflicts, suspension |

## New behavior covered
- Six distinct preview renderers ×Light/Dark,320/360px; all show identical test financial values. Navigation callbacks tested; template preference survives reload/rapid changes, independent of theme/language.
- Income/Expense widgets select categories, fill manual contacts and persist actual database rows with normalized phone, genuine created_at, expected balances1000+200=1200 /1000-200=800. Saved confirmation reads the committed record.
- Income edits preserve original created_at and snapshot; updated_at changes. Receipt financial content resolves database values, not caller amounts/contact/time.
- Durable custom categories separated by kind, case-insensitive uniqueness; invalid/incomplete contacts do not create rows.
- Opening feedback contains actual committed cash/bank/time. v1/v3 upgrades preserve old ids/balances, avoid invented historic opening timestamps. IST weekday/time and midnight rollover tested independently of host timezone.

## Visual evidence
Eighteen PNGs:6 dashboards ×2 themes, Income/Expense before/after save, Super Admin ×2 themes. Latest artifact13294538484 from run41771280545, captured with production AppTheme; zip SHA256605ddd0a015bcdf4f5085188ef6ed10fb22ac3d34faf86fe7bc55ff219fd15ba. These are actual Flutter widget captures, with production AppTheme and test-loaded DejaVu/MaterialIcons fonts for readable glyphs, demo dashboard records and isolated entry-test records. No original-design parity is claimed. Super Admin management/data are simulated and explicitly labeled. Static screenshot interactions are not working app forms; the actual Flutter preview route opens real entry forms.

## Web verification
Compilation succeeded at prior eff500044aeb43343c7fa21d215a256ce5415d71, but browser startup failed with `Incorrect locale information provided`. Browser harness now pins en-IN/Asia-Kolkata and uses the engine accessibility entry point. Current Web runtime result is pending; no passing runtime/persistence result claimed until recorded below.

## Not executed / blocked / limitations
- No current APK build: intermediate APK hold remains, Android jobs skipped as designed. Earlier f96a7030dd8b863f4161ae5b18299015660ba26d compiled debug/release and passed debug emulator smoke only; it does not certify this increment. Physical-device red-screen cause/fix not certified.
- Native contact picker/permission/cancel/multiple numbers, iOS compile, physical Android and WhatsApp handoff remain unverified.
- Hosted Supabase deployment, real auth/recovery, server/local tenant separation and production cross-user testing remain unimplemented/blocked. Disposable DB RLS success is not production security certification.
- Automatic encrypted backup/restore, signed lease/secure clock, sync/conflicts, partial payments, attachments, exports, PIN/biometric, voice and reminders are not certified complete. Passing policy/fixture tests does not finish their app flows.
- Merchant onboarding/payment verification, signing keys, physical UAT and representative10,000-user infrastructure are external blockers.
- Current local ledger uses REAL values and hard-delete income paths; minor-unit money and complete authorization/audit still need work. Offline device time is not trusted server audit.
- Complete English/Hindi translations and main dashboard activation await further implementation/visual review.

## 58-point ledger
2 complete checks (analyzer/unit-widget suite),48 pending including partial implementations,8 blocked. See TASK_STATUS_58.md for each task; all58 are not complete.

## Outstanding owner decisions
Visual approval of the six reconstructions is outstanding; no routine implementation approval is needed. Current main dashboard is deliberately retained until this major design review. External setup blockers are separate from design approval.

## Commit sequence
- 948ec65e9834b45da56efe71a4f50b3ef33c2466: reconstructed previews, opening feedback/timestamp migration.
- b33dc9ac03624abfdc3a28b059842e74a57c95d7: analyzer import correction.
- eff500044aeb43343c7fa21d215a256ce5415d71: contact/category/timestamp save flows;68 tests pass, Web runtime failed.
- ab0855af7a00f3810de81309b6a275ab2872291d: capture fonts/narrow amounts and explicit Indian browser locale; analyzer/tests/PostgreSQL pass.

Browser rerun ab0855a renders the dashboard without the previous locale exception; its harness nevertheless failed waiting for networkidle. Follow-up0dbc107d92a43cdc2a47d0c1e5f08c6faea4a78d waits for DOMContentLoaded plus actual Flutter accessibility/application content, retaining all persistence assertions. This is a harness fix, not yet a passing acceptance result.

Follow-up0dbc107d92a43cdc2a47d0c1e5f08c6faea4a78d: Actions41770690234/job126379425150 repeats analyzer68 Flutter+16 Python checks and bundle successfully. PostgreSQL run41770690321 also SUCCESS. No Dart app code changed after ab0855a; only browser harness/evidence paths changed.

Follow-up0dbc107 browser runtime started and created the account, but exact text matching missed its merged accessibility label. Evidence DOM shows `Browser acceptance account / Opening: ₹0.00`; this does NOT verify the intended ₹100 input. Updated04d20783286a97cbef5cfa66ffeae06ce7e77171 uses real keyboard entry and explicitly asserts saved ₹100 before/after reload, matching the full merged semantics. Capture tests now use production AppTheme rather than a generic seed ThemeData, retaining test fonts.

Latest04d2078: Actions41771280545/job126381296309 SUCCESS, analyzer68 Flutter+16 Python checks and bundle. PostgreSQL run41771280544/job126381295923 SUCCESS. Browser result pending below.

04d207 browser run failed before saving because keyboard select-all was not forwarded by Flutter semantics: visible value0.00100.00 was correctly rejected by form validation.50cf7ea27fd799af41a06f48d8073d4a6e1c248b replaces that shortcut with standard End/Backspace editing and preserves strict saved-amount assertions. This failure is not labeled passed.

## Verified Web result superseding earlier failed harness attempts
Source50cf7ea27fd799af41a06f48d8073d4a6e1c248b; Flutter run41772008968 SUCCESS, web job126384199189 SUCCESS. Actual output: PASS: startup, real IndexedDB account create/persistence, desktop/mobile rendering. Strict ₹100 opening balance asserted before and after reload. Android jobs skipped. This certifies the tested browser smoke flow, not all financial/SaaS workflows.

## Next increment not yet certified
Encrypted portable backup/restore with staged validation, pre-restore recovery copy, automatic encrypted local checkpoints, and append-only local audit are being tested. New code is not marked passed until its CI completes.
