import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/backup/automatic_backup.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
import 'package:offline_khata_app/features/backup/backup_vault.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/models/income_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  test('automatic resume checkpoint detects changed records, encrypts them and skips unchanged snapshots', () async {
    final folder = await Directory.systemTemp.createTemp('sss-auto-backup-');
    await databaseFactory.setDatabasesPath(folder.path);
    final backup = AutomaticBackup.forTesting(() async => 'automatic test checkpoint key');
    try {
      await AccountTable.saveAccount(name: 'Account', openingBalance: 100);
      await backup.capture(); expect((await BackupVault.list()).length, 1);
      await backup.capture(); expect((await BackupVault.list()).length, 1);
      await IncomeController().createIncome(IncomeModel(accountId: (await AccountTable.getAllAccounts()).single.id!,
        amount: 25, date: DateTime(2026, 11, 4), createdAt: DateTime.now().toUtc()));
      final done = Completer<void>(); backup.addListener(() {if (!done.isCompleted) done.complete();});
      backup.didChangeAppLifecycleState(AppLifecycleState.resumed); await done.future;
      final snapshots = await BackupVault.list(); expect(snapshots.length, 2);
      final encrypted = await BackupVault.read(snapshots.first['id'] as int);
      final content = await BackupCipher.decrypt(encrypted, 'automatic test checkpoint key');
      expect(((content['tables'] as Map)['income'] as List).single['amount'], 25);
      expect(backup.savedAt, isNotNull);
    } finally {backup.stop(); backup.dispose(); await DBHelper.close(); await folder.delete(recursive: true);}
  });
}
