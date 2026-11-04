import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
import 'package:offline_khata_app/features/backup/backup_vault.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/models/income_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('sss-recovery-');
    await databaseFactory.setDatabasesPath(folder.path);
  });
  tearDown(() async {await DBHelper.close(); await folder.delete(recursive: true);});

  Future<int> populate() async {
    await AccountTable.saveAccount(name: 'Ravi Verma', openingBalance: 1000);
    final account = (await AccountTable.getAllAccounts()).single;
    return IncomeController().createIncome(IncomeModel(accountId: account.id!, amount: 200,
      date: DateTime(2026, 11, 4), createdAt: DateTime.utc(2000),
      contactName: 'Ravi Verma', contactPhone: '9876543210', description: 'Commission'));
  }

  test('authenticated encrypted backup rejects wrong password and ciphertext tampering', () async {
    final data = <String, dynamic>{'private': 'Customer mobile and financial records'};
    final encrypted = await BackupCipher.encrypt(data, 'correct horse battery staple');
    expect(encrypted, isNot(contains('Customer')));
    expect(await BackupCipher.decrypt(encrypted, 'correct horse battery staple'), data);
    await expectLater(BackupCipher.decrypt(encrypted, 'wrong passphrase 123'), throwsA(anything));
    final modified = jsonDecode(encrypted) as Map<String, dynamic>;
    final text = modified['ciphertext'] as String;
    modified['ciphertext'] = '${text.startsWith('A') ? 'B' : 'A'}${text.substring(1)}';
    await expectLater(BackupCipher.decrypt(jsonEncode(modified), 'correct horse battery staple'), throwsA(anything));
    await expectLater(BackupCipher.encrypt(data, '123'), throwsArgumentError);
  });

  test('restore preserves identities, snapshots, balances and old data recovery copy', () async {
    final id = await populate();
    final service = BackupService();
    final snapshot = jsonDecode(jsonEncode(await service.snapshot())) as Map<String, dynamic>;
    final created = (await IncomeController().getIncomeById(id)).createdAt;
    await AccountTable.saveAccount(name: 'Created later', openingBalance: 25);
    await service.restore(snapshot, recoveryPassword: 'my portable backup password');
    expect((await AccountTable.getAllAccounts()).single.name, 'Ravi Verma');
    final income = await IncomeController().getIncomeById(id);
    expect(income.createdAt, created);
    expect(income.contactPhone, '+919876543210');
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'], 1200);
    final retained = await BackupVault.read((await BackupVault.list(purpose: 'recovery')).single['id'] as int);
    final recovered = await BackupCipher.decrypt(retained, 'my portable backup password');
    expect(((recovered['tables'] as Map)['accounts'] as List).length, 2);
    final db = await DBHelper.database;
    await expectLater(db.insert('income', {'amount': 1, 'account_id': null,
      'date': '2026-11-04', 'created_at': '2026-11-04T00:00:00Z'}), throwsA(isA<DatabaseException>()));
    expect((await db.rawQuery('PRAGMA foreign_key_check')), isEmpty);
    expect((await db.query('app_audit', where: 'operation = ?', whereArgs: ['restore'])), isNotEmpty);
  });

  test('invalid account links and unknown SQL-shaped fields never alter live records', () async {
    await populate(); final service = BackupService();
    final snapshot = jsonDecode(jsonEncode(await service.snapshot())) as Map<String, dynamic>;
    final tables = snapshot['tables'] as Map<String, dynamic>;
    final incomes = tables['income'] as List;
    incomes[0] = Map<String, Object?>.from(incomes.single as Map)..['account_id'] = 999;
    await expectLater(service.restore(snapshot, recoveryPassword: 'my portable backup password'), throwsA(anything));
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'], 1200);
    final malicious = jsonDecode(jsonEncode(await service.snapshot())) as Map<String, dynamic>;
    final accounts = (malicious['tables'] as Map)['accounts'] as List;
    accounts[0] = Map<String, Object?>.from(accounts.first as Map)..['id); DROP TABLE income;--'] = 1;
    await expectLater(service.validate(malicious), throwsFormatException);
    expect((await IncomeController().getAllIncome()).length, 1);
  });

  test('audit captures updates/deletes with before/after data and cannot be rewritten', () async {
    final id = await populate();
    final original = await IncomeController().getIncomeById(id);
    await IncomeController().updateIncome(original.copyWith(amount: 250));
    await IncomeController().deleteIncome(id);
    final db = await DBHelper.database;
    final history = await db.query('app_audit', where: 'entity = ?', whereArgs: ['income'], orderBy: 'rowid');
    expect(history.map((r) => r['operation']), ['insert', 'update', 'delete']);
    expect(history[1]['old_amount'], 200);
    expect(history[1]['new_amount'], 250);
    expect(history[2]['old_contact_name'], 'Ravi Verma');
    expect(history[2]['old_contact_phone'], '+919876543210');
    expect(DateTime.parse(history.last['occurred_at'] as String).isUtc, true);
    await expectLater(db.delete('app_audit'), throwsA(isA<DatabaseException>()));
    await expectLater(db.update('app_audit', {'operation': 'forged'}), throwsA(isA<DatabaseException>()));
  });
}
