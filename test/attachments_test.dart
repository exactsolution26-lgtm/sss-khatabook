import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
import 'package:offline_khata_app/features/backup/backup_vault.dart';
import 'package:offline_khata_app/features/entries/attachments.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/models/income_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder;
  setUp(() async {folder = await Directory.systemTemp.createTemp('sss-files-'); await databaseFactory.setDatabasesPath(folder.path);});
  tearDown(() async {await DBHelper.close(); await folder.delete(recursive: true);});
  Future<PendingAttachment> pdf() => PendingAttachment.inspect('../../invoice.exe', Uint8List.fromList(ascii.encode('%PDF-1.4\n%%EOF\n')));
  Future<IncomeModel> income() async {
    await AccountTable.saveAccount(name: 'Account', openingBalance: 100);
    return IncomeModel(accountId: (await AccountTable.getAllAccounts()).single.id!, amount: 25,
      date: DateTime(2026, 11, 4), createdAt: DateTime.now().toUtc());
  }
  test('attachment type/size checks ignore misleading names and reject executable HTML', () async {
    final file = await pdf(); expect(file.name, 'invoice.pdf'); expect(file.mime, 'application/pdf');
    await expectLater(PendingAttachment.inspect('receipt.pdf', Uint8List.fromList(utf8.encode('<script>bad</script>'))), throwsFormatException);
    await expectLater(PendingAttachment.inspect('large.pdf', Uint8List(5 * 1024 * 1024 + 1)), throwsFormatException);
  });
  test('attachment failure rolls back both financial row and its audit record', () async {
    final model = await income(); final file = await pdf();
    await expectLater(IncomeController().createIncome(model, attachments: List.filled(6, file)), throwsFormatException);
    final db = await DBHelper.database;
    expect(await db.query('income'), isEmpty); expect(await db.query('attachments'), isEmpty);
    expect(await db.query('app_audit', where: 'entity = ?', whereArgs: ['income']), isEmpty);
  });
  test('attachment bytes and entry identity survive backup validation and restore', () async {
    final model = await income(); final file = await pdf();
    final id = await IncomeController().createIncome(model, attachments: [file]);
    final service = BackupService(); final snapshot = await service.snapshot();
    final db = await DBHelper.database;
    await IncomeController().deleteIncome(id); expect(await db.query('attachments'), isEmpty);
    await service.restore(snapshot, recoveryPassword: 'my secure backup phrase');
    final row = (await db.query('attachments')).single;
    expect(row['income_id'], id); expect(row['expense_id'], isNull);
    expect(base64Decode(row['content_base64'] as String), file.bytes);
    expect(row['name'], 'invoice.pdf');
  });
  test('automatic vault retains seven snapshots separately from pre-restore recovery', () async {
    for (var i = 0; i < 10; i++) {await BackupVault.put('ciphertext-$i');}
    await BackupVault.put('recovery-ciphertext', purpose: 'recovery');
    final snapshots = await BackupVault.list(); expect(snapshots.length, 7);
    expect(await BackupVault.read(snapshots.first['id'] as int), 'ciphertext-9');
    expect((await BackupVault.list(purpose: 'recovery')).length, 1);
  });
}
