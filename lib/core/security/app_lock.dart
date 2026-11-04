import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../features/backup/backup_service.dart';

class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  AppLock({required this.read, required this.write, required this.supported,
    DateTime Function()? clock, this.authenticateBiometric}) : clock = clock ?? (() => DateTime.now().toUtc());
  static final instance = AppLock(
    supported: !kIsWeb && [TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform),
    read: () => const FlutterSecureStorage().read(key: 'sss_pin_v1'),
    write: (value) => const FlutterSecureStorage().write(key: 'sss_pin_v1', value: value),
    authenticateBiometric: () => LocalAuthentication().authenticate(localizedReason: 'Unlock SSS Khatabook',
      biometricOnly: true, persistAcrossBackgrounding: true),
  );
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final bool supported;
  final DateTime Function() clock;
  final Future<bool> Function()? authenticateBiometric;
  Map<String, dynamic>? _config;
  bool loaded = false, locked = true, _checking = false, _biometricBusy = false;
  String? storageError, message;
  bool get enabled => _config?['enabled'] == true;
  bool get biometricEnabled => enabled && _config?['biometric'] == true;

  Future<void> load() async {
    loaded = false; locked = true; notifyListeners();
    try {
      storageError = null;
      if (!supported) {loaded = true; locked = false; return;}
      final raw = await read().timeout(const Duration(seconds: 10));
      _config = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (_config != null && (_config!['version'] != 1 || _config!['enabled'] is! bool)) {
        throw const FormatException('Invalid lock configuration');
      }
      if (enabled && (_config!['iterations'] != BackupCipher.iterations ||
          base64Decode(_config!['salt'] as String).length != 16 ||
          base64Decode(_config!['hash'] as String).length != 32)) {
        throw const FormatException('Invalid PIN configuration');
      }
      loaded = true; locked = enabled;
    } catch (_) {loaded = false; locked = true; storageError = 'Secure storage unavailable. Please retry.';}
    finally {notifyListeners();}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && enabled && !_biometricBusy) lock();
  }
  void lock() {if (enabled) {locked = true; message = null; notifyListeners();}}
  Future<void> _persist(Map<String, dynamic> state) async {
    await write(jsonEncode(state)).timeout(const Duration(seconds: 10)); _config = state;
  }
  Future<List<int>> _hash(String pin, List<int> salt) async =>
    (await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: BackupCipher.iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt)).extractBytes();
  Future<bool> verify(String pin) async {
    if (!supported || !loaded || !enabled || _checking) return false;
    _checking = true;
    try {
      final state = Map<String, dynamic>.from(_config!);
      final now = clock().toUtc();
      final last = DateTime.tryParse(state['last_attempt'] as String? ?? '');
      final next = DateTime.tryParse(state['retry_after'] as String? ?? '');
      if (last != null && now.add(const Duration(minutes: 5)).isBefore(last)) {
        message = 'Check the device date and time before trying again.'; return false;
      }
      if (next != null && now.isBefore(next)) {message = 'Too many attempts. Please try again later.'; return false;}
      final expected = base64Decode(state['hash'] as String);
      final actual = await _hash(pin, base64Decode(state['salt'] as String));
      var mismatch = expected.length ^ actual.length;
      for (var i = 0; i < expected.length && i < actual.length; i++) {mismatch |= expected[i] ^ actual[i];}
      final valid = mismatch == 0 && RegExp(r'^\d{6}$').hasMatch(pin);
      final failures = valid ? 0 : (state['failures'] as int? ?? 0) + 1;
      state['failures'] = failures; state['last_attempt'] = now.toIso8601String();
      state['retry_after'] = failures >= 5
        ? now.add(Duration(seconds: failures >= 10 ? 300 : 30)).toIso8601String() : null;
      await _persist(state);
      message = valid ? null : 'Incorrect PIN. Please retry.';
      return valid;
    } catch (_) {storageError = 'Secure storage unavailable. Please retry.'; locked = true; return false;}
    finally {_checking = false; notifyListeners();}
  }
  Future<bool> unlock(String pin) async {
    if (!await verify(pin)) return false;
    locked = false; notifyListeners(); return true;
  }
  Future<void> setPin(String newPin, {String currentPin = ''}) async {
    if (!supported || !loaded || !RegExp(r'^\d{6}$').hasMatch(newPin)) throw ArgumentError('Enter a six digit PIN');
    if (enabled && !await verify(currentPin)) throw StateError('Current PIN required');
    final salt = BackupCipher.randomBytes(16);
    await _persist({'version': 1, 'enabled': true, 'salt': base64Encode(salt),
      'hash': base64Encode(await _hash(newPin, salt)), 'iterations': BackupCipher.iterations,
      'failures': 0, 'biometric': false});
    locked = false; notifyListeners();
  }
  Future<void> disable(String currentPin) async {
    if (!await verify(currentPin)) throw StateError('Current PIN required');
    await _persist({'version': 1, 'enabled': false}); locked = false; notifyListeners();
  }
  Future<bool> unlockBiometric() async {
    if (!biometricEnabled || authenticateBiometric == null || _biometricBusy) return false;
    _biometricBusy = true;
    try {
      if (!await authenticateBiometric!()) return false;
      locked = false; message = null; notifyListeners(); return true;
    } catch (_) {message = 'Biometric unavailable. Use your PIN.'; notifyListeners(); return false;}
    finally {_biometricBusy = false;}
  }
  Future<void> setBiometric(bool value, String currentPin) async {
    if (!await verify(currentPin)) throw StateError('Current PIN required');
    if (value) {
      if (authenticateBiometric == null) throw StateError('Biometric unavailable');
      _biometricBusy = true;
      try {if (!await authenticateBiometric!()) throw StateError('Biometric confirmation required');}
      finally {_biometricBusy = false;}
    }
    await _persist({..._config!, 'biometric': value}); notifyListeners();
  }
}
