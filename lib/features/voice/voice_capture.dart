import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceLanguage { english, hindi, hinglish }

abstract class SpeechDevice {
  Future<bool> initialize({required void Function(String) status,required void Function(String) error});
  Future<bool> get hasPermission;
  Future<List<String>> locales();
  Future<void> listen({required String locale,required bool offlineOnly,
    required void Function(String) words,required void Function(double) level});
  Future<void> stop();
  Future<void> cancel();
}
class PluginSpeechDevice implements SpeechDevice {
  final speech=stt.SpeechToText();
  @override Future<bool> initialize({required void Function(String) status,required void Function(String) error}) =>
    speech.initialize(onStatus: status,onError: (e) => error(e.errorMsg),
      options: [stt.SpeechToText.androidNoBluetooth]);
  @override Future<bool> get hasPermission => speech.hasPermission;
  @override Future<List<String>> locales() async => (await speech.locales()).map((l)=>l.localeId).toList();
  @override Future<void> listen({required String locale,required bool offlineOnly,
      required void Function(String) words,required void Function(double) level}) async {
    await speech.listen(onResult: (result)=>words(result.recognizedWords),onSoundLevelChange: level,
      listenOptions: stt.SpeechListenOptions(localeId: locale,onDevice: offlineOnly,cancelOnError: true,
        partialResults: true,listenFor: const Duration(seconds: 30)));
  }
  @override Future<void> stop()=>speech.stop();
  @override Future<void> cancel()=>speech.cancel();
}

/// One app-lifetime owner: speech_to_text keeps its FIRST initialize callbacks.
/// Views subscribe/unsubscribe; callbacks never capture a disposed dialog.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture(this.device);
  static final instance=VoiceCapture(PluginSpeechDevice());
  final SpeechDevice device;
  bool offlineOnly=true,preparing=false,starting=false,listening=false;
  VoiceLanguage language=VoiceLanguage.english;
  bool get hindi=>language!=VoiceLanguage.english;
  String words='';String? issue;
  double soundLevel=0;
  bool _ready=false,_active=false,_acceptEvents=false,_disposed=false;
  int _generation=0;
  Timer? _startTimeout;
  Future<void> _cancelling=Future<void>.value();
  bool get busy=>preparing || starting || listening;
  bool get canTryProvider=>offlineOnly && ['error_language_not_supported','error_language_unavailable',
    'error_not_available','service_unavailable','start_timeout'].contains(issue);
  String get message {
    switch(issue) {
      case 'permission_denied': case 'error_permission': case 'error_insufficient_permissions':
        return 'Microphone permission is denied. Allow Microphone in Android Settings → Apps → SSS Khatabook Preview → Permissions, then Retry.';
      case 'service_unavailable': case 'error_not_available':
        return 'A speech recognition service is unavailable. Enable or update your phone’s speech service, then Retry. You can also type below.';
      case 'error_language_not_supported': case 'error_language_unavailable':
        return offlineOnly ? 'Offline ${hindi ? 'Hindi' : 'English'} recognition is unavailable. Download that speech language in your phone’s speech settings, or try the device speech service with your consent.'
          : '${hindi ? 'Hindi' : 'English'} is unavailable in the selected speech service. Check its language settings or try the other language.';
      case 'error_no_match': case 'error_speech_timeout':
        return 'No speech was recognized. Tap Retry and speak clearly near the microphone.';
      case 'error_network': case 'error_network_timeout': case 'error_server': case 'error_server_disconnected':
        return 'The device speech service could not connect. Check your connection or select Offline only if its language pack is installed.';
      case 'error_audio': case 'error_audio_error':
        return 'The microphone could not start. Check Android microphone access and close other apps using the microphone, then Retry.';
      case 'error_busy': case 'error_recognizer_busy': case 'error_too_many_requests':
        return 'The speech service is busy. Wait a moment, then Retry.';
      case 'start_timeout':
        return 'The speech service did not start. Check the speech service/language settings or try device speech service.';
      case null:return '';
      default:return 'Speech stopped ($issue). Check microphone access and speech language settings, then Retry. Your text is still editable.';
    }
  }
  void _notify(){if(!_disposed) notifyListeners();}
  void open() {
    _generation++;_active=true;_acceptEvents=false;_startTimeout?.cancel();
    language=VoiceLanguage.english;offlineOnly=true;preparing=false;starting=false;listening=false;
    words='';issue=null;soundLevel=0;_notify();
  }
  void setLanguage(VoiceLanguage value){if(!busy){language=value;issue=null;_notify();}}
  void setOffline(bool value){if(!busy){offlineOnly=value;issue=null;_notify();}}
  static String localeFor(List<String> locales,VoiceLanguage selected) {
    final language=selected!=VoiceLanguage.english ? 'hi' : 'en';
    final matches=locales.where((l)=>l.toLowerCase().replaceAll('_','-').split('-').first==language).toList();
    final indian=matches.where((l)=>l.toLowerCase().replaceAll('_','-')=='$language-in');
    // Android providers do not always enumerate every supported language.
    // Request the chosen language explicitly; never silently switch Hindi to English.
    return indian.isNotEmpty ? indian.first : matches.isNotEmpty ? matches.first : '$language-IN';
  }
  Future<void> _cancelDevice() {
    _cancelling=_cancelling.then((_) async {try {await device.cancel().timeout(const Duration(seconds: 3));}catch(_){}});
    return _cancelling;
  }
  bool _current(int generation)=>!_disposed && _active && generation==_generation;
  Future<void> start() async {
    if(!_active || busy || _disposed) return;
    final generation=++_generation;
    preparing=true;starting=false;listening=false;_acceptEvents=false;issue=null;soundLevel=0;_notify();
    try {
      await _cancelling;
      if(!_current(generation)) return;
      if(!_ready) _ready=await device.initialize(status:_status,error:_error).timeout(const Duration(seconds: 20));
      if(!_current(generation)) return;
      if(!_ready) {
        final permission=await device.hasPermission;
        if(_current(generation)) {issue=permission ? 'service_unavailable':'permission_denied';_notify();}
        return;
      }
      List<String> locales=[];
      try {locales=await device.locales().timeout(const Duration(seconds: 5));}catch(_){ /* Enumeration is advisory; use the requested BCP47 language. */ }
      if(!_current(generation)) return;
      await _cancelDevice();
      if(!_current(generation)) return;
      preparing=false;starting=true;_acceptEvents=true;_notify();
      _startTimeout=Timer(const Duration(seconds: 10),(){
        if(_current(generation) && starting) {_error('start_timeout');unawaited(_cancelDevice());}
      });
      await device.listen(locale:localeFor(locales,language),offlineOnly:offlineOnly,
        words:(value){if(_current(generation) && _acceptEvents){words=value.length>2000 ? value.substring(0,2000):value;_notify();}},
        level:(value){if(_current(generation) && _acceptEvents && value.isFinite){soundLevel=value;_notify();}})
        .timeout(const Duration(seconds: 10));
    } catch(_) {
      if(_current(generation)){issue='start_failed';starting=false;listening=false;_acceptEvents=false;_startTimeout?.cancel();unawaited(_cancelDevice());}
    } finally {if(_current(generation)){preparing=false;_notify();}}
  }
  void _status(String status) {
    if(!_active || !_acceptEvents || _disposed) return;
    if(status=='listening'){starting=false;listening=true;_startTimeout?.cancel();}
    else if(status=='notListening' || status=='done' || status=='doneNoResult'){
      starting=false;listening=false;_startTimeout?.cancel();
    }
    _notify();
  }
  void _error(String code) {
    if(!_active || !_acceptEvents || _disposed) return;
    issue=code;starting=false;listening=false;_acceptEvents=false;_startTimeout?.cancel();_notify();
  }
  Future<void> stop() async {
    _startTimeout?.cancel();starting=false;listening=false;preparing=false;_notify();
    try {await device.stop().timeout(const Duration(seconds: 3));}catch(_){await _cancelDevice();}
  }
  /// Inactive can be the Android permission prompt. Only a real background or
  /// detach transition cancels capture; no automatic microphone restart on resume.
  Future<void> background() async {
    _generation++;_acceptEvents=false;preparing=false;starting=false;listening=false;_startTimeout?.cancel();_notify();
    await _cancelDevice();
  }
  Future<void> close() async {
    _active=false;_generation++;_acceptEvents=false;_startTimeout?.cancel();preparing=false;starting=false;listening=false;
    await _cancelDevice();
  }
  @override void dispose(){_disposed=true;_active=false;_generation++;_startTimeout?.cancel();unawaited(_cancelDevice());super.dispose();}
}
