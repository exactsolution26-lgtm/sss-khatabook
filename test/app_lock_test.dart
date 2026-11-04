import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:offline_khata_app/core/security/app_lock.dart';
import 'package:offline_khata_app/features/security/security_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PIN stores a salted hash and relocks after a new application session', () async {
    String? stored;
    AppLock create() => AppLock(read: () async => stored, write: (value) async {stored = value;}, supported: true);
    final lock = create(); await lock.load();
    await lock.setPin('654321');
    expect((jsonDecode(stored!) as Map).values, isNot(contains('654321')));
    expect(lock.enabled, true); expect(lock.locked, false);
    final restarted = create(); await restarted.load(); expect(restarted.locked, true);
    expect(await restarted.unlock('123456'), false); expect(restarted.locked, true);
    expect(await restarted.unlock('654321'), true); expect(restarted.locked, false);
    restarted.lock(); expect(restarted.locked, true);
  });
  test('attempt throttling survives restart and a device clock rollback cannot bypass it', () async {
    String? stored; var now = DateTime.utc(2026, 11, 4);
    AppLock create() => AppLock(read: () async => stored, write: (value) async {stored = value;}, supported: true, clock: () => now);
    final setup = create(); await setup.load(); await setup.setPin('654321');
    final state = jsonDecode(stored!) as Map<String, dynamic>; state['failures'] = 4; stored = jsonEncode(state);
    final lock = create(); await lock.load(); expect(await lock.unlock('000000'), false);
    final restarted = create(); await restarted.load(); expect(await restarted.unlock('654321'), false);
    now = now.subtract(const Duration(days: 1)); expect(await restarted.unlock('654321'), false);
    now = DateTime.utc(2026, 11, 4).add(const Duration(seconds: 31));
    expect(await restarted.unlock('654321'), true);
  });
  test('biometric opt-in requires the correct PIN and successful platform authentication', () async {
    String? stored; var biometricAllowed = false;
    final lock = AppLock(read: () async => stored, write: (value) async {stored = value;},
      supported: true, authenticateBiometric: () async => biometricAllowed);
    await lock.load(); await lock.setPin('654321');
    await expectLater(lock.setBiometric(true, '000000'), throwsStateError);
    await expectLater(lock.setBiometric(true, '654321'), throwsStateError); expect(lock.biometricEnabled, false);
    biometricAllowed = true; await lock.setBiometric(true, '654321'); expect(lock.biometricEnabled, true);
    lock.lock(); expect(await lock.unlockBiometric(), true); expect(lock.locked, false);
    await expectLater(lock.disable('000000'), throwsStateError); expect(lock.enabled, true);
  });
  test('corrupt or unavailable secure storage fails closed', () async {
    for (final value in ['invalid json', '{"version":1,"enabled":true}', '{"version":2,"enabled":false}']) {
      final lock = AppLock(read: () async => value, write: (_) async {}, supported: true);
      await lock.load(); expect(lock.locked, true); expect(lock.loaded, false); expect(lock.storageError, isNotNull);
    }
  });
  testWidgets('financial UI stays hidden until PIN verification and disappears when relocked', (tester) async {
    String? stored;
    final lock = AppLock(read: () async => stored, write: (value) async {stored = value;}, supported: true);
    await tester.runAsync(() async {await lock.load(); await lock.setPin('654321');});
    await tester.pumpWidget(MaterialApp(home: const Scaffold(),
      builder: (_, child) => AppLockGate(controller: lock, child: const Scaffold(body: Text('Private financial records')))));
    await tester.pumpAndSettle();
    expect(find.text('Private financial records'), findsNothing);
    expect(find.text('Unlock SSS Khatabook'), findsOneWidget);
    await tester.runAsync(() => lock.unlock('654321'));
    await tester.pumpAndSettle(); expect(find.text('Private financial records'), findsOneWidget);
    lock.lock(); await tester.pumpAndSettle(); expect(find.text('Private financial records'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink()); lock.dispose();
  });
}
