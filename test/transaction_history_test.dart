import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/app.dart';
import 'package:offline_khata_app/core/security/app_lock.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/entries/attachments.dart';
import 'package:offline_khata_app/features/entries/record_recovery.dart';
import 'package:offline_khata_app/features/entries/record_editor.dart';
import 'package:offline_khata_app/features/history/transaction_history.dart';
import 'package:offline_khata_app/features/history/transaction_detail_screen.dart';
import 'package:offline_khata_app/features/whatsapp/whatsapp_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder;
  late int account, other;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('sss-history-');
    await databaseFactory.setDatabasesPath(folder.path);
    await AccountTable.saveAccount(name: 'Main Account', openingBalance: 1000);
    account = (await AccountTable.getAllAccounts()).single.id!;
    await AccountTable.saveAccount(name: 'Second Account', openingBalance: 0);
    other = (await AccountTable.getAllAccounts()).firstWhere((a) => a.id != account).id!;
    final db = await DBHelper.database;
    for (final row in [
      {'id': 1,'account_id': account,'amount':100.10,'date':'2026-11-03','description':'Earlier service','category':'Services','mode':'cash','contact_name':'Ravi','contact_phone':'+919876543210','created_at':'2026-11-04T20:01:02Z'},
      {'id': 2,'account_id': other,'amount':200.20,'date':'2026-11-04','description':'Invoice payment','category':'Sales','mode':'online','contact_name':'Priya','contact_phone':'+919876543211','created_at':'2026-11-04T10:10:10Z'},
    ]) { await db.insert('income', row); }
    await db.insert('expenses', {'id':1,'account_id':account,'amount':50.05,'date':'2026-11-04','note':'Travel to supplier','category':'Travel','mode':'cash','created_at':'2026-11-04T11:05:12Z'});
    await db.transaction((txn) async {
      final file = await PendingAttachment.inspect('receipt.pdf', Uint8List.fromList(ascii.encode('%PDF-1.4\n%%EOF\n')));
      await AttachmentStore.insertBatch(txn, [file], incomeId: 1);
    });
  });
  tearDown(() async { await DBHelper.close(); await folder.delete(recursive: true); });

  test('history covers accounts, separates same income/expense IDs and excludes attachment bytes', () async {
    final incoming = await TransactionHistory.load(true);
    final outgoing = await TransactionHistory.load(false);
    expect(incoming.map((e) => e.id), [2,1]);
    expect(incoming.map((e) => e.accountId).toSet(), {account,other});
    expect(TransactionHistory.totalPaise(incoming), 30030);
    expect(TransactionHistory.totalPaise(outgoing), 5005);
    expect(incoming.last.attachmentCount, 1);
    expect(outgoing.single.attachmentCount, 0);
    expect(incoming.last.row.containsKey('content_base64'), false);
    expect(await TransactionHistory.load(true, id:1, accountId:other), isEmpty);
    expect((await TransactionHistory.load(false, id:1, accountId:account)).single.reference, 'EXP-1');
  });
  test('v3 unassigned expense remains visible after real migration without fabricated save time', () async {
    await DBHelper.close();
    final path='${folder.path}/offline_khata.db';
    await databaseFactory.deleteDatabase(path);
    final old=await databaseFactory.openDatabase(path,options:OpenDatabaseOptions(version:3,onCreate:(db,version) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY,name TEXT,opening_balance REAL,cash_balance REAL,bank_balance REAL,created_at TEXT)');
      await db.execute('CREATE TABLE income(id INTEGER PRIMARY KEY,account_id INTEGER,amount REAL,description TEXT,date TEXT,created_at TEXT)');
      await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY,account_id INTEGER,amount REAL,mode TEXT,category TEXT,note TEXT,date TEXT)');
      await db.execute("INSERT INTO expenses VALUES(9,NULL,7,'cash','Other','Historic unassigned expense','2026-11-04')");
    }));
    await old.close();
    final row=(await TransactionHistory.load(false)).single;
    expect(row.id,9);expect(row.accountId,isNull);expect(row.account,'Unassigned legacy account');
    expect(row.paise,700);expect(HistoryEntry.timestamp(row.row['created_at']),'Unknown historic save time');
  });
  test('search/category/inclusive date filters and totals use transaction date, not save date', () async {
    final rows = await TransactionHistory.load(true);
    expect(TransactionHistory.filter(rows,query:'9876543210').single.id,1);
    expect(TransactionHistory.filter(rows,query:'second account').single.id,2);
    expect(TransactionHistory.filter(rows,query:'INC-1').single.name,'Ravi');
    expect(TransactionHistory.filter(rows,query:'%'),isEmpty);
    final selected=TransactionHistory.filter(rows,category:'Services',fromDate:'2026-11-03',toDate:'2026-11-03');
    expect(TransactionHistory.totalPaise(selected),10010);
    expect(TransactionHistory.filter(rows,category:'Travel'),isEmpty);
  });
  test('timestamps roll over to IST and do not invent legacy times', () {
    expect(HistoryEntry.timestamp('2026-11-04T20:01:02Z'), 'Thursday, 5 November 2026 · 01:31:02 AM IST');
    expect(HistoryEntry.timestamp(null),'Unknown historic save time');
    expect(HistoryEntry.timestamp('invalid'),'Unknown historic save time');
    expect(HistoryEntry.timestamp('2026-11-04 12:00:00'), contains('historic timezone unknown'));
  });
  test('edit/delete/restore reload exact totals, original timestamp and attachment count', () async {
    final original=(await TransactionHistory.load(true,id:1,accountId:account)).single;
    await RecordRecovery.edit(income:true,id:1,accountId:account,amount:'150.15',date:'2026-11-03',note:'Corrected',category:'Services',mode:'cash',name:'Ravi',phone:'9876543210');
    var current=(await TransactionHistory.load(true,id:1,accountId:account)).single;
    expect(current.row['created_at'],original.row['created_at']);expect(current.row['updated_at'],isNotNull);
    expect(TransactionHistory.totalPaise(await TransactionHistory.load(true)),35035);
    final archive=await RecordRecovery.remove(income:true,id:1,accountId:account,reason:'Duplicate');
    expect(TransactionHistory.totalPaise(await TransactionHistory.load(true)),20020);
    await RecordRecovery.restore(archive,account);
    current=(await TransactionHistory.load(true,id:1,accountId:account)).single;
    expect(current.attachmentCount,1);expect(current.paise,15015);
  });
  test('expense receipt rechecks account/source and refuses deleted or ambiguous records', () async {
    const service=WhatsAppShareService();
    WhatsAppDraft draft({int? incomeId, int? expenseId, int? accountId}) => WhatsAppDraft(
      type:WhatsAppMessageType.receipt,customer:'Forged',amount:999,timestampUtc:DateTime.utc(2026),
      sourceIncomeId:incomeId,sourceExpenseId:expenseId,sourceAccountId:accountId);
    final resolved=await service.resolveDraft(draft(expenseId:1,accountId:account));
    expect(resolved.amount,50.05);expect(resolved.customer,'Main Account');
    expect(resolved.message,contains('recorded expense #1'));expect(resolved.sourceIncomeId,isNull);
    await (await DBHelper.database).update('expenses', {'mode':'online'}, where:'id=?',whereArgs:[1]);
    await expectLater(service.openDraft('9876543210',draft(expenseId:1,accountId:account),expectedMessage:resolved.message),throwsStateError);
    await expectLater(service.resolveDraft(draft(expenseId:1,accountId:other)),throwsStateError);
    await expectLater(service.resolveDraft(draft(expenseId:1,incomeId:1)),throwsStateError);
    await RecordRecovery.remove(income:false,id:1,accountId:account,reason:'Duplicate');
    await expectLater(service.resolveDraft(draft(expenseId:1)),throwsStateError);
  });
  test('WhatsApp receipt never labels an unknown historic timezone as verified IST', () async {
    await (await DBHelper.database).update('expenses', {'created_at':'2026-11-04 11:05:12'},where:'id=?',whereArgs:[1]);
    await expectLater(const WhatsAppShareService().resolveDraft(WhatsAppDraft(
      type:WhatsAppMessageType.receipt,customer:'',amount:0,timestampUtc:DateTime.utc(2026),sourceExpenseId:1)),throwsStateError);
  });
  test('receipt PDF uses real entry details and generates a readable PDF container', () async {
    final row=(await TransactionHistory.load(true,id:1,accountId:account)).single;
    final pdf=await TransactionReceipt.pdf(row);
    expect(ascii.decode(pdf.take(5).toList()),'%PDF-');expect(pdf.length,greaterThan(2000));
  });

  MyApp app() => MyApp(automaticBackups:false,
    appLock:AppLock(read:() async => null,write:(_) async {},supported:true));
  for(final dark in [false,true]) {
    testWidgets('dashboard summary opens history, filters and details at ${dark ? '320 dark' : '390 light'}', (tester) async {
      SharedPreferences.setMockInitialValues({'sss_theme_mode': dark ? 'dark' : 'light'});
      tester.view.physicalSize=Size(dark ? 320 : 390,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Income').first);await tester.tap(find.text('Income').first);await tester.pumpAndSettle();
      expect(find.text('Transaction history'),findsOneWidget);expect(find.text('₹300.30'),findsOneWidget);
      await tester.enterText(find.byType(TextField),'9876543210');await tester.pumpAndSettle();
      expect(find.text('₹100.10'),findsOneWidget);
      final tile=find.byKey(const ValueKey('history-INC-1'));
      await tester.scrollUntilVisible(tile,180,scrollable:find.byType(Scrollable).first);await tester.tap(tile);await tester.pumpAndSettle();
      expect(find.text('Entry details'),findsOneWidget);
      expect(find.text('Thursday, 5 November 2026 · 01:31:02 AM IST'),findsOneWidget);
      await tester.scrollUntilVisible(find.text('Edit entry'),180,scrollable:find.byType(Scrollable).first);
      await tester.tap(find.text('Edit entry'));await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField,'Amount'),'150.15');
      FocusManager.instance.primaryFocus?.unfocus();await tester.pumpAndSettle();
      final saveChanges=find.widgetWithText(FilledButton,'Save changes');
      await tester.scrollUntilVisible(saveChanges,180,scrollable:find.byType(Scrollable).first);
      await tester.ensureVisible(saveChanges);await tester.pumpAndSettle();
      await tester.tap(saveChanges.hitTestable());await tester.pumpAndSettle();
      expect(find.text('Entry details'),findsOneWidget);
      await tester.scrollUntilVisible(find.text('+₹150.15'),-180,scrollable:find.byType(Scrollable).first);
      expect(find.text('+₹150.15'),findsOneWidget);
      await tester.pageBack();await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('history-total')));
      expect(find.text('₹150.15'),findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));await tester.enterText(find.byType(TextField),'');await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();await tester.pumpAndSettle();
      final historyTabs=find.byType(SegmentedButton<bool>);
      await tester.scrollUntilVisible(historyTabs,-180,scrollable:find.byType(Scrollable).first);
      await tester.ensureVisible(historyTabs);await tester.pumpAndSettle();
      await tester.tap(find.text('Expenses').hitTestable());await tester.pumpAndSettle();
      expect(find.text('₹50.05'),findsOneWidget);expect(find.byKey(const ValueKey('history-INC-1')),findsNothing);
      await tester.pageBack();await tester.pumpAndSettle();
      expect(find.text('₹1,300.30'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('deleted entry can be restored from the real recycle bin without stale financial state', (tester) async {
    await RecordRecovery.remove(income:true,id:1,accountId:account,reason:'Duplicate');
    await tester.pumpWidget(MaterialApp(home:RecycleBinScreen(accountId:account)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));await tester.pumpAndSettle();
    expect(find.text('No deleted entries.'),findsOneWidget);
    expect(TransactionHistory.totalPaise(await TransactionHistory.load(true)),30030);
    expect((await TransactionHistory.load(true,id:1,accountId:account)).single.attachmentCount,1);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('account creation refreshes the list and reports the saved account correctly', (tester) async {
    await tester.pumpWidget(app());await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Accounts'),180,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Accounts'));await tester.pumpAndSettle();
    await tester.tap(find.text('New Account'));await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField,'Account name'),'History account');
    await tester.tap(find.text('Save'));await tester.pumpAndSettle();
    expect(find.text('History account'),findsOneWidget);
    expect(find.text('Could not save account'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('history Add Income opens existing entry form and reloads saved record on return', (tester) async {
    await tester.pumpWidget(app());await tester.pumpAndSettle();
    await tester.tap(find.text('Income').first);await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Income'));await tester.tap(find.text('Add Income'));await tester.pumpAndSettle();
    expect(find.text('Voice entry — review first'),findsOneWidget);
    // Save through the normal form; transaction row is never inserted by the UI test.
    await tester.enterText(find.widgetWithText(TextFormField,'Amount'), '25.25');
    await tester.scrollUntilVisible(find.text('Save Income'),200,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Save Income'));await tester.pumpAndSettle();
    expect(find.text('Saved ✓'),findsOneWidget);
    await tester.pageBack();await tester.pumpAndSettle();
    expect(find.text('₹325.55'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
