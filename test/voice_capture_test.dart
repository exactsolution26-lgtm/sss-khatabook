import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/voice/voice_capture.dart';
import 'package:offline_khata_app/features/voice/voice_entry_button.dart';
import 'package:offline_khata_app/features/voice/voice_draft.dart';

class FakeSpeechDevice implements SpeechDevice {
  void Function(String)? status,error,words;
  void Function(double)? level;
  int initializations=0,cancels=0,stops=0,listens=0;
  bool ready=true,permission=true;
  Completer<bool>? permissionPrompt;
  List<String> languages=['en_US','en-IN','hi_IN'];
  String? chosenLocale;bool? offline;bool emitListening=true;
  @override Future<bool> initialize({required void Function(String) status,required void Function(String) error}) async {
    initializations++;this.status=status;this.error=error;
    if(permissionPrompt!=null) return await permissionPrompt!.future;
    return ready;
  }
  @override Future<bool> get hasPermission async=>permission;
  @override Future<List<String>> locales() async=>languages;
  @override Future<void> listen({required String locale,required bool offlineOnly,
      required void Function(String) words,required void Function(double) level}) async {
    listens++;chosenLocale=locale;offline=offlineOnly;this.words=words;this.level=level;
    if(emitListening) status?.call('listening');
  }
  @override Future<void> cancel() async {cancels++;}
  @override Future<void> stop() async {stops++;status?.call('done');}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSpeechDevice device;late VoiceCapture capture;
  setUp((){device=FakeSpeechDevice();capture=VoiceCapture(device);});
  tearDown((){capture.dispose();});
  test('English Hindi Hinglish choose the requested language without silent English fallback',(){
    expect(VoiceCapture.localeFor(['en_US','en-IN','hi_IN'],VoiceLanguage.english),'en-IN');
    expect(VoiceCapture.localeFor(['en_US','hi_IN'],VoiceLanguage.hindi),'hi_IN');
    expect(VoiceCapture.localeFor(['en_US','hi-IN'],VoiceLanguage.hinglish),'hi-IN');
    expect(VoiceCapture.localeFor(['en-US'],VoiceLanguage.hindi),'hi-IN');
    expect(VoiceCapture.localeFor([],VoiceLanguage.english),'en-IN');
    for(final phrase in ['Ravi se 500 rupees received','500 रुपये मिले','Received 500 rupees']) {
      expect(VoiceDraft.parse(phrase).amount,'500');
    }
  });
  test('permission denial gives permission guidance; enabling permission allows retry',() async {
    capture.open();device.ready=false;device.permission=false;await capture.start();
    expect(capture.issue,'permission_denied');expect(capture.message,contains('Permissions'));expect(device.listens,0);
    device.ready=true;device.permission=true;await capture.start();expect(capture.listening,true);expect(device.listens,1);
  });
  test('missing service is distinguished from denied microphone',() async {
    capture.open();device.ready=false;await capture.start();
    expect(capture.issue,'service_unavailable');expect(capture.message,contains('speech recognition service'));expect(device.listens,0);
  });
  test('offline language failure retains text and NEVER silently starts an online provider',() async {
    capture.open();capture.setLanguage(VoiceLanguage.hindi);await capture.start();
    device.words!('500 रुपये');device.error!('error_language_unavailable');
    expect(capture.words,'500 रुपये');expect(capture.canTryProvider,true);expect(capture.listening,false);
    expect(capture.message,contains('Offline Hindi'));expect(device.offline,true);expect(device.listens,1);
  });
  test('app-lifetime initialization routes callbacks to reopened capture without stale dialog ownership',() async {
    capture.open();await capture.start();await capture.close();device.words!('old text');expect(capture.words,'');
    capture.open();capture.setLanguage(VoiceLanguage.hinglish);await capture.start();device.words!('Ravi se 500 received');
    expect(device.initializations,1);expect(capture.words,'Ravi se 500 received');expect(device.chosenLocale,'hi_IN');
    device.error!('error_no_match');expect(capture.message,contains('No speech'));expect(capture.busy,false);
  });
  test('backgrounding during microphone permission waits prevents a late microphone start',() async {
    capture.open();device.permissionPrompt=Completer<bool>();final starting=capture.start();await Future<void>.delayed(Duration.zero);
    await capture.background();device.permissionPrompt!.complete(true);await starting;
    expect(device.listens,0);expect(capture.busy,false);
  });
  test('closing during initialization and late results cannot change a reopened session',() async {
    capture.open();await capture.start();final oldWords=device.words!;
    await capture.close();capture.open();oldWords('stale money 999');expect(capture.words,'');
    await capture.start();device.words!('current 500');expect(capture.words,'current 500');
  });
  testWidgets('inactive permission prompt does not cancel recording startup, paused does', (tester) async {
    device.permissionPrompt=Completer<bool>();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:VoiceEntryButton(income:true,capture:capture,onConfirmed:(_){}))));
    await tester.tap(find.text('Voice entry — review first'));await tester.pumpAndSettle();
    await tester.tap(find.text('Start speaking'));await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);await tester.pump();
    expect(device.initializations,1);expect(device.cancels,0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    device.permissionPrompt!.complete(true);await tester.pumpAndSettle();
    expect(find.text('Listening… Speak now'),findsOneWidget);expect(device.listens,1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(capture.listening,false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);await tester.pump();
    expect(capture.listening,false);expect(device.cancels,greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);await tester.pumpAndSettle();
    expect(device.listens,1);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
  testWidgets('hidden financial UI cancels active capture and never auto restarts',(tester) async {
    final visible=ValueNotifier<bool>(true);addTearDown(visible.dispose);
    final app=MaterialApp(home:Scaffold(body:VoiceEntryButton(income:true,capture:capture,onConfirmed:(_){})));
    await tester.pumpWidget(ValueListenableBuilder<bool>(valueListenable:visible,builder:(context,value,_)=>TickerMode(enabled:value,child:app)));
    await tester.tap(find.text('Voice entry — review first'));await tester.pumpAndSettle();
    await tester.tap(find.text('Start speaking'));await tester.pumpAndSettle();expect(capture.listening,true);
    visible.value=false;await tester.pump();expect(capture.listening,false);
    await tester.pump();expect(device.cancels,greaterThan(1));
    visible.value=true;await tester.pumpAndSettle();expect(device.listens,1);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
  testWidgets('online fallback requires explicit consent; recognized words still require review and Use in form',(tester) async {
    VoiceDraft? confirmed;
    tester.view.physicalSize=const Size(360,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:VoiceEntryButton(income:true,capture:capture,onConfirmed:(v)=>confirmed=v))));
    await tester.tap(find.text('Voice entry — review first'));await tester.pumpAndSettle();
    await tester.tap(find.text('Start speaking'));await tester.pumpAndSettle();expect(device.listens,1);device.error!('error_language_not_supported');await tester.pumpAndSettle();
    final fallback=find.text('Try device speech service');await tester.ensureVisible(fallback);await tester.tap(fallback);await tester.pumpAndSettle();
    expect(find.text('Use device speech service?'),findsOneWidget);expect(device.listens,1);expect(device.offline,true);
    await tester.tap(find.text('Cancel').last);await tester.pumpAndSettle();expect(device.listens,1);
    await tester.ensureVisible(fallback);await tester.tap(fallback);await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));await tester.pumpAndSettle();expect(device.offline,false);expect(device.listens,2);
    device.words!('Received 500 rupees');await tester.pump();await tester.tap(find.text('Stop'));await tester.pumpAndSettle();
    expect(confirmed,isNull);await tester.tap(find.text('Review details'));await tester.pumpAndSettle();
    expect(find.text('Amount: 500'),findsOneWidget);expect(confirmed,isNull);
    await tester.tap(find.text('Use in form'));await tester.pumpAndSettle();expect(confirmed!.amount,'500');
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
  testWidgets('all three voice language choices are selectable and startup cannot spin forever',(tester) async {
    device.emitListening=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:VoiceEntryButton(income:true,capture:capture,onConfirmed:(_){}))));
    await tester.tap(find.text('Voice entry — review first'));await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<VoiceLanguage>));await tester.pumpAndSettle();
    expect(find.text('English'),findsWidgets);expect(find.text('Hindi / हिंदी'),findsOneWidget);
    await tester.tap(find.text('Hinglish / Hindi + English').last);await tester.pumpAndSettle();expect(capture.language,VoiceLanguage.hinglish);
    await tester.ensureVisible(find.text('Start speaking'));await tester.pumpAndSettle();
    await tester.tap(find.text('Start speaking'));await tester.pumpAndSettle();expect(device.listens,1);
    await tester.pump(const Duration(seconds:11));await tester.pumpAndSettle();
    expect(capture.issue,'start_timeout');expect(capture.busy,false);expect(device.listens,1);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
}
