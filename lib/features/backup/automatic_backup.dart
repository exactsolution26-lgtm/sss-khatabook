import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'backup_service.dart';
import 'backup_vault.dart';

/// Foreground/resume checkpoints, kept outside the financial database.
/// Uninstall/device loss still requires an exported portable backup.
class AutomaticBackup extends ChangeNotifier with WidgetsBindingObserver {
  AutomaticBackup._();
  @visibleForTesting
  AutomaticBackup.forTesting(this.keyProvider);
  static final instance = AutomaticBackup._();
  Future<String?> Function()? keyProvider;
  Timer? _timer;
  bool _busy = false;
  String? _password;
  Future<String?>? _loadingPassword;
  String? _fingerprint;
  DateTime? savedAt;
  String status = 'Not started';

  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => capture());
    capture();
  }
  void stop() {
    _timer?.cancel(); _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _password = null;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.resumed) capture();
  }
  Future<void> unlockWeb(String passphrase) async {
    if (passphrase.length < 12) throw ArgumentError('Use at least 12 characters');
    _password = passphrase;
    await capture(force: true);
  }
  Future<String?> password() => _password != null
    ? Future.value(_password) : _loadingPassword ??= _readPassword();
  Future<String?> _readPassword() async {
    try {
    if (keyProvider != null) return _password = await keyProvider!();
    if (kIsWeb) return null;
    const storage = FlutterSecureStorage();
    var value = await storage.read(key: 'sss_auto_backup_key_v1').timeout(const Duration(seconds: 10));
    if (value == null) {
      value = base64Encode(BackupCipher.randomBytes(32));
      await storage.write(key: 'sss_auto_backup_key_v1', value: value).timeout(const Duration(seconds: 10));
    }
    return _password = value;
    } finally { _loadingPassword = null; }
  }
  Future<void> capture({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      final secret = await password();
      if (secret == null) {
        status = 'Enter a backup passphrase to enable this browser session';
        return;
      }
      final snapshot = await BackupService().snapshot();
      final hash = base64Encode((await Sha256().hash(utf8.encode(jsonEncode(snapshot['tables'])))).bytes);
      if (!force && hash == _fingerprint) return;
      final encrypted = await BackupCipher.encrypt(snapshot, secret);
      await BackupVault.put(encrypted);
      savedAt = DateTime.parse(snapshot['created_at'] as String);
      _fingerprint = hash;
      status = 'Encrypted checkpoint saved on this device';
    } catch (_) {
      status = 'Automatic backup unavailable. Export a portable backup.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
