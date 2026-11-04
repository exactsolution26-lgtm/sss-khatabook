import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/models/income_model.dart';
import 'package:offline_khata_app/features/entries/record_recovery.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();databaseFactory=databaseFactoryFfiNoIsolate;
  late Directory folder;late int account,id;
  setUp(() async {folder=await Directory.systemTemp.createTemp('sss-recycle-');await databaseFactory.setDatabasesPath(folder.path);
    await AccountTable.saveAccount(name: 'Ravi',openingBalance: 1000);account=(await AccountTable.getAllAccounts()).single.id!;
    id=await IncomeController().createIncome(IncomeModel(accountId: account,amount: 200,date: DateTime(2026,1,1),createdAt: DateTime.now().toUtc(),contactName: 'Ravi',contactPhone: '9876543210'));});
  tearDown(() async {await DBHelper.close();await folder.delete(recursive: true);});
  test('edit preserves original save time, updates balance and records before/after audit',() async {
    final original=await IncomeController().getIncomeById(id);
    await RecordRecovery.edit(income: true,id: id,accountId: account,amount: '250.25',date: '2026-01-02',note: 'Corrected',category: 'Sales',mode: 'cash',name: '',phone: '');
    final saved=await IncomeController().getIncomeById(id);
    expect(saved.createdAt,original.createdAt);expect(saved.updatedAt,isNotNull);expect(saved.contactName,isNull);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1250.25);
    final audit=(await (await DBHelper.database).query('app_audit',where: "entity='income' AND operation='update'")).single;
    expect(audit['old_amount'],200);expect(audit['new_amount'],250.25);
  });
  test('delete is recoverable with identity and contact snapshot after full backup/restore',() async {
    final original=await IncomeController().getIncomeById(id);
    final archive=await RecordRecovery.remove(income: true,id: id,accountId: account,reason: 'Duplicate');
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000);
    expect((await RecordRecovery.list()).single['record_id'],id);
    final backup=BackupService();await backup.restore(await backup.snapshot(),recoveryPassword: 'secure recovery password');
    await RecordRecovery.restore(archive,account);
    final saved=await IncomeController().getIncomeById(id);
    expect(saved.createdAt,original.createdAt);expect(saved.contactPhone,'+919876543210');
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1200);
    expect(await RecordRecovery.list(),isEmpty);
    await expectLater(RecordRecovery.restore(archive,account),throwsStateError);
  });
  test('wrong account cannot edit/delete/recover a record and invalid amounts do not mutate',() async {
    await expectLater(RecordRecovery.remove(income: true,id: id,accountId: account+1,reason: 'Wrong'),throwsStateError);
    await expectLater(RecordRecovery.edit(income: true,id: id,accountId: account+1,amount: '250',date: '2026-01-01',note: '',category: 'Other',mode: 'cash',name: '',phone: ''),throwsStateError);
    await expectLater(RecordRecovery.edit(income: true,id: id,accountId: account,amount: '0.001',date: '2026-01-01',note: '',category: 'Other',mode: 'cash',name: '',phone: ''),throwsArgumentError);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1200);
  });
}
