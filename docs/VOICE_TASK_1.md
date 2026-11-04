# Task1 — voice capture repair

Reported on Samsung A14, APK1.0.2: Hindi + on-device selected; generic Speech unavailable; no recognized text. Screenshot cannot establish Android error code or microphone permission state.

Confirmed source problems: app-owned callbacks bound to first disposable dialog despite plugin initialize-once contract; generic error discards native reason; offline-only failure has no explicit provider fallback; inactive lifecycle transition cancels while Android permission dialog can be active; stop failure escapes review handler.

Repair: one app-lifetime capture owner and injectable device adapter; callback/listener separation; no cancellation on inactive-only, real paused/detached transitions cancel and never restart automatically; generation fences after all awaits and result callbacks; bounded startup timeout; explicit English/Hindi/Hinglish selection (Hinglish requests the Hindi India recognizer, mixed words/script depend on phone provider), locale selection even when enumeration incomplete, never silent language swap; phone-mic mode disables unconfigured Bluetooth permission dependency. Offline-only remains the default. Device-provider mode requires explicit online-processing consent. Error-specific permission/language/network/no-speech/microphone/service guidance and Retry, visible listening/level state. Review then Use in form then explicit Save remains mandatory.

Tests/results are pending until CI executes. Fake recognizer tests do not prove Samsung microphone/recognition. Owner explicitly says no new APK until requested; development branch only, no main change. User’s phone verification remains required for final hardware acceptance.

Primary contract: https://pub.dev/documentation/speech_to_text/7.5.0/ — initialize once, initial callbacks retained. Android error meanings: https://developer.android.com/reference/android/speech/SpeechRecognizer .
