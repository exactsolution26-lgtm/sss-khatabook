import '../../core/localization/app_text.dart';
import 'dart:convert';
import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../core/utils/file_actions.dart';
import 'automatic_backup.dart';
import 'backup_service.dart';
import 'backup_vault.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}
class _BackupScreenState extends State<BackupScreen> {
  final password = TextEditingController();
  final service = BackupService();
  bool busy = false;
  String? message;
  @override
  void dispose() { password.dispose(); super.dispose(); }
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {busy = true; message = null;});
    try { await action(); }
    catch (_) { if (mounted) setState(() => message = 'Could not complete backup operation. Check the passphrase and file, then retry. Current records remain available.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void requirePassword() {
    if (password.text.length < 12 || password.text.length > 1024) {
      throw ArgumentError('Use 12–1024 characters');
    }
  }
  Future<void> review(Map<String, dynamic> snapshot) async {
    await service.validate(snapshot);
    if (!mounted) return;
    final tables = snapshot['tables'] as Map;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const AppText('Replace current financial records?'),
      content: Text('Backup: ${dates.DateUtils.formatIstDateTime(DateTime.parse(snapshot['created_at'] as String))}\n'
        'Accounts: ${(tables['accounts'] as List).length}\nIncome: ${(tables['income'] as List).length}\nExpenses: ${(tables['expenses'] as List).length}\n\n'
        'Current records will be replaced. An encrypted recovery copy is retained first using the passphrase entered on this screen.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const AppText('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const AppText('Replace records'))],
    ));
    if (confirmed != true) return;
    await service.restore(snapshot, recoveryPassword: password.text);
    await AutomaticBackup.instance.capture(force: true);
    if (mounted) setState(() => message = 'Records restored successfully. Previous records are retained in the recovery copy.');
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Backup & Restore')),
    body: AbsorbPointer(absorbing: busy, child: ListView(padding: const EdgeInsets.all(20), children: [
      const AppText('Portable encrypted backup', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true, enableSuggestions: false, autocorrect: false,
        decoration: const InputDecoration(label: AppText('Backup passphrase'), helperText: 'At least 12 characters. Keep it safe; it cannot be recovered.')),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => run(() async {
        requirePassword();
        final encrypted = await BackupCipher.encrypt(await service.snapshot(), password.text);
        if (!context.mounted) return;
        await shareFile(context, Uint8List.fromList(utf8.encode(encrypted)),
          'sss-khatabook-${DateTime.now().toUtc().millisecondsSinceEpoch}.sssbackup', 'application/json');
        if (mounted) setState(() => message = 'Encrypted backup prepared. Keep an exported copy outside this device.');
      }), icon: const Icon(Icons.save_alt), label: const AppText('Export / Share encrypted backup')),
      OutlinedButton.icon(onPressed: () => run(() async {
        requirePassword();
        final file = await files.openFile(acceptedTypeGroups: [const files.XTypeGroup(
          label: 'Khatabook backup', extensions: ['sssbackup', 'json'],
          mimeTypes: ['application/json', 'application/octet-stream'], uniformTypeIdentifiers: ['public.json'])]);
        if (file == null) return;
        if (await file.length() > 75000000) throw const FormatException('Backup too large');
        await review(await BackupCipher.decrypt(await file.readAsString(), password.text));
      }), icon: const Icon(Icons.restore), label: const AppText('Import and review backup')),
      const SizedBox(height: 24),
      const AppText('Automatic device checkpoints', style: TextStyle(fontWeight: FontWeight.bold)),
      const AppText('Keeps the latest seven changed snapshots while the app is open, and checks on resume. Export a portable backup for device loss or uninstall.'),
      ListenableBuilder(listenable: AutomaticBackup.instance, builder: (context, child) => ListTile(
        contentPadding: EdgeInsets.zero, title: Text(AutomaticBackup.instance.status),
        subtitle: AutomaticBackup.instance.savedAt == null ? null
          : Text(dates.DateUtils.formatIstDateTime(AutomaticBackup.instance.savedAt!)))),
      if (kIsWeb) OutlinedButton(onPressed: () => run(() async {
        requirePassword(); await AutomaticBackup.instance.unlockWeb(password.text);
      }), child: const AppText('Enable encrypted checkpoints for this browser session')),
      OutlinedButton(onPressed: () => run(() => AutomaticBackup.instance.capture(force: true)), child: const AppText('Create checkpoint now')),
      OutlinedButton(onPressed: () => run(() async {
        requirePassword();
        final history = await BackupVault.list();
        if (history.isEmpty) {if (mounted) setState(() => message = 'No device checkpoints available.'); return;}
        if (!context.mounted) return;
        final selected = await showDialog<int>(context: context, builder: (context) => SimpleDialog(
          title: const AppText('Choose checkpoint'), children: [for (var i = 0; i < history.length; i++)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, i),
              child: Text(i == 0 ? 'Latest checkpoint' : 'Older checkpoint ${i + 1}'))]));
        if (selected == null) return;
        final secret = kIsWeb ? password.text : await AutomaticBackup.instance.password();
        if (secret == null) throw StateError('Checkpoint key unavailable');
        await review(await BackupCipher.decrypt(await BackupVault.read(history[selected]['id'] as int), secret));
      }), child: const AppText('Review / Restore device checkpoint')),
      TextButton(onPressed: () => run(() async {
        requirePassword();
        final recovery = await BackupVault.list(purpose: 'recovery');
        if (recovery.isEmpty) {if (mounted) setState(() => message = 'No pre-restore recovery copy available.'); return;}
        await review(await BackupCipher.decrypt(await BackupVault.read(recovery.first['id'] as int), password.text));
      }), child: const AppText('Recover records from before the last restore')),
      if (busy) const LinearProgressIndicator(),
      if (message != null) Padding(padding: const EdgeInsets.only(top: 16),
        child: Semantics(liveRegion: true, child: Text(message!))),
    ])),
  );
}
