import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/core/utils/money.dart';
import 'package:offline_khata_app/features/dues/dues_service.dart';
import 'package:offline_khata_app/features/dues/dues_screen.dart';
import 'package:offline_khata_app/features/followups/followup_service.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
import 'package:offline_khata_app/features/whatsapp/whatsapp_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder; late int accountId;
  final service = DuesService();
  String key(int n) => n.toRadixString(16).padLeft(32,'0');
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('sss-dues-'); await databaseFactory.setDatabasesPath(folder.path);
    await AccountTable.saveAccount(name: 'Ravi Verma', openingBalance: 1000);
    accountId = (await AccountTable.getAllAccounts()).single.id!;
  });
  tearDown(() async {await DBHelper.close(); await folder.delete(recursive: true);});
  Future<int> due({bool incoming = true}) => service.create(accountId: accountId, receivable: incoming,
    amountPaise: 50000, description: 'Recorded bill', dueDate: '2026-11-05',contactName: 'Ravi Verma',contactPhone: '9876543210');

  test('paise parsing is exact and rejects fractions of a paise', () {
    expect(Money.parse('0.10') + Money.parse('0.20'),30);
    expect(Money.format(123456789),'₹12,34,567.89'); expect(Money.format(-1),'-₹0.01');
    for (final value in ['0','-1','1.005','1e3','NaN']) {expect(() => Money.parse(value),throwsArgumentError);}
  });
  test('partial payment changes cash once and leaves the exact remaining amount', () async {
    final id = await due(); expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000);
    final payment = await service.recordPayment(obligationId: id,amountPaise: 20000,operationKey: key(1));
    expect(await service.recordPayment(obligationId: id,amountPaise: 20000,operationKey: key(1)),payment);
    final row = (await service.list()).single;
    expect(row['paid_paise'],20000); expect(row['remaining_paise'],30000);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1200);
    final income = (await IncomeController().getAllIncome()).single;
    expect(income.contactPhone,'+919876543210');
    await expectLater(service.recordPayment(obligationId: id,amountPaise: 20001,operationKey: key(1)),throwsStateError);
    await expectLater(service.recordPayment(obligationId: id,amountPaise: 30001,operationKey: key(2)),throwsA(isA<DatabaseException>()));
    expect((await IncomeController().getAllIncome()).length,1);
    await expectLater(IncomeController().updateIncome(income.copyWith(amount: 250)),throwsA(isA<DatabaseException>()));
    await expectLater(IncomeController().deleteIncome(income.id!),throwsA(isA<DatabaseException>()));
  });
  test('competing payments cannot overpay or leak an unallocated cash entry', () async {
    final id = await due();
    final requests = [service.recordPayment(obligationId: id,amountPaise: 40000,operationKey: key(1)),
      service.recordPayment(obligationId: id,amountPaise: 30000,operationKey: key(2))];
    var successes = 0;
    // Attach error handlers immediately so the rejected concurrent request is observed.
    final outcomes = await Future.wait(requests.map((f) => f.then((_) => true,onError: (Object _) => false)));
    successes = outcomes.where((v) => v).length;
    expect(successes,1); final row = (await service.list()).single;
    expect(row['paid_paise'],anyOf(30000,40000));
    expect((await IncomeController().getAllIncome()).length,1);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000 + (row['paid_paise'] as int) / 100);
  });
  test('reversal retains original history, restores remaining due and blocks stale receipts', () async {
    final id = await due(); final payment = await service.recordPayment(obligationId: id,amountPaise: 20000,operationKey: key(1));
    final income = (await IncomeController().getAllIncome()).single;
    await service.reversePayment(payment,'Recorded on wrong day');
    expect((await service.list()).single['remaining_paise'],50000);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000);
    expect((await IncomeController().getAllIncome()).single.id,income.id);
    await expectLater(service.reversePayment(payment,'Duplicate reversal'),throwsStateError);
    await expectLater(service.recordPayment(obligationId: id,amountPaise: 20000,operationKey: key(1)),throwsStateError);
    await expectLater(const WhatsAppShareService().resolveDraft(WhatsAppDraft(type: WhatsAppMessageType.receipt,
      customer: '',amount: 0,timestampUtc: DateTime.now().toUtc(),sourceIncomeId: income.id)),throwsStateError);
    final snapshot = await BackupService().snapshot();
    await BackupService().restore(snapshot,recoveryPassword: 'valid recovery passphrase');
    expect((await service.list()).single['remaining_paise'],50000);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000);
  });
  test('payable settlement subtracts cash and reversal adds it back', () async {
    final id = await due(incoming: false); final payment = await service.recordPayment(obligationId: id,amountPaise: 12550,operationKey: key(1));
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],874.5);
    expect((await service.list()).single['remaining_paise'],37450);
    await service.reversePayment(payment,'Payment refunded');
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1000);
  });
  test('follow-up permission denial does not undo the saved record; completion is durable', () async {
    var cancelled = 0;
    final followups = FollowupService(schedule: (_, time) async => false,cancel: (_) async {cancelled++;});
    final id = await followups.create(accountId: accountId,title: 'Call customer',dueAtUtc: DateTime.utc(2030),notify: true);
    expect((await followups.list()).single['notification_scheduled'],0);
    await followups.setDone(id,true); final row = (await followups.list()).single;
    expect(row['status'],'done'); expect(row['completed_at'],isNotNull); expect(cancelled,1);
    await followups.setDone(id,false); expect((await followups.list()).single['status'],'open');
  });
  test('follow-up cannot attach a due from a different customer', () async {
    final id = await due(); await AccountTable.saveAccount(name: 'Other customer',openingBalance: 0);
    final other = (await AccountTable.getAllAccounts()).last.id!;
    await expectLater(FollowupService().create(accountId: other,obligationId: id,title: 'Wrong link',dueAtUtc: DateTime.utc(2030)),throwsA(isA<DatabaseException>()));
  });
  testWidgets('mobile due form saves a real partial payment without a keyboard overflow', (tester) async {
    await due(); tester.view.physicalSize = const Size(360,1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DuesScreen())); await tester.pumpAndSettle();
    final action = find.text('Record received payment'); await tester.ensureVisible(action); await tester.tap(action); await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300); addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextFormField).first,'200');
    await tester.ensureVisible(find.text('Save payment')); await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment')); await tester.pumpAndSettle();
    expect(find.text('Remaining: ₹300.00'),findsOneWidget); expect(tester.takeException(),isNull);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],1200);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
