# Task1 — voice capture repair

Reported on Samsung A14, APK1.0.2: Hindi + on-device selected; generic Speech unavailable; no recognized text. Screenshot cannot establish Android error code or microphone permission state.

Confirmed source problems: app-owned callbacks bound to first disposable dialog despite plugin initialize-once contract; generic error discards native reason; offline-only failure has no explicit provider fallback; inactive lifecycle transition cancels while Android permission dialog can be active; stop failure escapes review handler.

Repair: one app-lifetime capture owner and injectable device adapter; callback/listener separation; no cancellation merely for inactive while the financial UI is visible; hidden financial/PIN gate or real hidden/paused/detached transitions cancel and never restart automatically; generation fences after all awaits and result callbacks; bounded startup timeout; explicit English/Hindi/Hinglish selection (Hinglish requests the Hindi India recognizer, mixed words/script depend on phone provider), locale selection even when enumeration incomplete, never silent language swap; phone-mic mode disables unconfigured Bluetooth permission dependency. Offline-only remains the default. Device-provider mode requires explicit online-processing consent. Error-specific permission/language/network/no-speech/microphone/service guidance and Retry, visible listening/level state. Review then Use in form then explicit Save remains mandatory.

Automated evidence on e4489252883a2225b7db799a7ff66799e291ebe7: zero analyzer issues,111 Flutter tests PASS (100 existing +11 voice service/widget regressions),12 SQLite +4 schema checks PASS; run41833092188/job126584978532. Actual disposable PostgreSQL security run41833092252/job126584977098 PASS. Web job126586165776 PASS: compilation, browser startup, IndexedDB save/reload, desktop/mobile rendering, offline reload and offline browser cold start. Android build/startup/publish jobs are SKIPPED under the owner's APK hold.

The11 voice regressions use an injected fake recognizer and cover requested locale selection (including explicit Hinglish→Hindi India mapping), denied permission/retry, unavailable service, offline-language failure without silent provider/network fallback, text retention, initialize-once/reopened dialogs, stale-result fencing, permission/background overlap, valid Android lifecycle sequence, hidden/locked financial UI cancellation, explicit provider consent, review before returning a draft, selectable language controls and bounded startup timeout. Ticker visibility also follows the real financial lock gate; capture cannot automatically restart when that gate becomes visible again.

The initial run failed three widget cases because eager cancellation futures crossed the test scheduler boundary; lazy cancellation fixed that, then a lifecycle test used an invalid direct resumed→paused transition and was corrected to the full inactive→hidden→paused sequence. The additional visibility guard first triggered an analyzer deprecation, corrected to Flutter's current valuesOf API. Failed runs are preserved;111 PASS refers only to the source/run above, not to earlier failed attempts. Fake recognizer tests do not prove Samsung microphone/recognition. Owner explicitly says no new APK until requested; development branch only, no main change. User’s phone verification remains required for final hardware acceptance.

Primary contract: https://pub.dev/documentation/speech_to_text/7.5.0/ — initialize once, initial callbacks retained. Android error meanings: https://developer.android.com/reference/android/speech/SpeechRecognizer .

## Phone acceptance after a separately authorized APK build

1. English: Start → native microphone permission → return to dialog → visible Listening state. Say "Received 500 rupees", Stop, Review, verify500, Use in form. Nothing is persisted until explicit Save.
2. Hindi: choose Hindi, say "रवि से 500 रुपये मिले". Missing offline language produces a specific message and an explicit provider-consent choice. Canceling consent must not activate provider/network capture.
3. Hinglish: choose Hinglish, say "Ravi se 500 rupees received". Uses Hindi India recognizer; mixed words and script are provider-dependent. Edit transcript if needed, Review before using it.
4. Reopen voice dialog repeatedly from Income and Expense; current dialog must receive results and errors, with no disposed-widget callback errors.
5. Cancel or background the app: microphone stops. Returning to the app never restarts listening automatically.
6. Deny microphone → guidance; grant it in app permissions → Retry. Disable global microphone privacy access → useful microphone failure rather than silent recording.
7. Offline-only mode never silently switches to online processing. No language pack or service reports a useful recovery path. Retained text remains editable after failures.

These are pending physical-device checks, not reported as passed. No new APK is built until the owner explicitly requests it.


## Delivery status

Code fix and automated regression are verified on e4489252883a2225b7db799a7ff66799e291ebe7. CI: https://github.com/exactsolution26-lgtm/sss-khatabook/actions/runs/41833092188 . Analyzer0issues,111 Flutter tests,16 Python checks, asset bundle and Web runtime PASS; disposable PostgreSQL checks also PASS. All Android APK/startup/publish jobs are SKIPPED. No new APK/version/release was generated. Installed1.0.2 still contains the previous voice implementation; source changes are not installed automatically.

Owner's latest constraint is explicit: do not build a new APK until asked. Real Samsung A14 microphone, permission dialogs, provider availability, offline language packs and Hindi/English/Hinglish accuracy are NOT hardware-certified by fake-recognizer tests. Test plan above is pending until a separately authorized build/device check. This report does not mark the whole58-point project complete.
