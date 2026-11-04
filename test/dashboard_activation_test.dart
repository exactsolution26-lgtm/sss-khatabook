import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/app.dart';
import 'package:offline_khata_app/core/security/app_lock.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_layout.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_screen.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_templates.dart';
import 'package:offline_khata_app/features/history/transaction_detail_screen.dart';
import 'package:offline_khata_app/features/accounts/accounts_screen.dart';
import 'package:offline_khata_app/features/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder;
  late int account;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('sss-dashboard-');
    await databaseFactory.setDatabasesPath(folder.path);
    await AccountTable.saveAccount(name: 'Main Account', openingBalance: 1000);
    account = (await AccountTable.getAllAccounts()).single.id!;
    final db = await DBHelper.database;
    await db.insert('income', {'id':1,'account_id':account,'amount':100.10,
      'date':'2026-11-04','description':'Payment received','category':'Services','mode':'cash',
      'contact_name':'Ravi','contact_phone':'+919876543210','created_at':'2026-11-04T20:01:02Z'});
    await db.insert('expenses', {'id':1,'account_id':account,'amount':50.05,
      'date':'2026-11-04','note':'Travel','category':'Travel','mode':'cash','created_at':'2026-11-04T11:05:12Z'});
  });
  tearDown(() async { await DBHelper.close(); await folder.delete(recursive:true); });
  MyApp app() => MyApp(automaticBackups:false,
    appLock:AppLock(read:() async => null,write:(_) async {},supported:true));

  Future<String> fingerprint() async {
    final db = await DBHelper.database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
    final rows = <String, Object?>{};
    for (final table in tables) {
      final name = table['name'] as String;
      rows[name] = await db.rawQuery('SELECT * FROM "$name" ORDER BY rowid');
    }
    return jsonEncode(rows);
  }
  Future<void> choose(WidgetTester tester, String title) async {
    await tester.tap(find.byKey(const ValueKey('dashboard-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title).last);
    await tester.pumpAndSettle();
  }

  testWidgets('preview cancel never activates; apply all six updates home and preserves every database row', (tester) async {
    final before = await fingerprint();
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    await tester.tap(find.text('Change dashboard')); await tester.pumpAndSettle();
    await choose(tester, 'Timeline');
    expect(find.byKey(const ValueKey('dashboard_6')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('sss_dashboard_layout'), isNull);
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(find.text('Active: Classic'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_1')), findsOneWidget);
    for (final layout in DashboardLayout.values) {
      await tester.tap(find.text('Change dashboard')); await tester.pumpAndSettle();
      await choose(tester, layout.title(false));
      await tester.tap(find.byKey(const ValueKey('apply-dashboard'))); await tester.pumpAndSettle();
      expect(find.text('Active: ${layout.title(false)}'), findsOneWidget);
      expect(find.byKey(ValueKey(layout.preferenceId)), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('metric-0'))).data,'₹1,050.05');
      expect(await fingerprint(), before);
    }
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    expect(find.text('Active: Timeline'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_6')), findsOneWidget);
    expect(await fingerprint(), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timeline distinguishes identical income/expense IDs and opens the correct source account', (tester) async {
    SharedPreferences.setMockInitialValues({'sss_dashboard_layout':'dashboard_6'});
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    for (final income in [true,false]) {
      final key = ValueKey('recent-${income ? 'income' : 'expense'}-1');
      await tester.ensureVisible(find.byKey(key)); await tester.pumpAndSettle();
      await tester.tap(find.byKey(key).hitTestable()); await tester.pumpAndSettle();
      final detail = tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen));
      expect(detail.income, income); expect(detail.id,1); expect(detail.accountId,account);
      expect(find.text('Entry details'), findsOneWidget);
      await tester.pageBack(); await tester.pumpAndSettle();
    }
    expect(find.text('Saved: Thursday, 5 November 2026 · 01:31:02 AM IST'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Accounts template opens the selected account ledger', (tester) async {
    SharedPreferences.setMockInitialValues({'sss_dashboard_layout':'dashboard_5'});
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('dashboard-account-$account'))); await tester.pumpAndSettle();
    expect(tester.widget<AccountLedgerScreen>(find.byType(AccountLedgerScreen)).account.id,account);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hide amounts updates the active dashboard and persists after app restart', (tester) async {
    SharedPreferences.setMockInitialValues({'sss_dashboard_layout':'dashboard_4'});
    final before = await fingerprint();
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide amounts')); await tester.pumpAndSettle();
    for (var i=0;i<3;i++) {
      expect(tester.widget<Text>(find.byKey(ValueKey('metric-$i'))).data,'••••');
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Show amounts')); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('metric-0'))).data, '₹1,050.05');
    expect(await fingerprint(), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('summary keeps legacy expenses in totals and exposes bounded, deterministic recent metadata', () async {
    var db = await DBHelper.database;
    var data = await AnalysisLogic().getAnalysisData();
    final recent = data['recentTransactions'] as List;
    expect(recent.map((e) => '${e['kind']}-${e['id']}'), ['income-1','expense-1']);
    expect(recent.first['contact_name'],'Ravi');
    expect(recent.first['contact_phone'],'+919876543210');
    for (var i=2;i<=20;i++) {
      await db.insert('income', {'id':i,'account_id':account,'amount':1,'date':'2026-11-05',
        'created_at':'2026-11-05T00:00:00Z'});
    }
    data=await AnalysisLogic().getAnalysisData();
    expect((data['recentTransactions'] as List).map((e) => e['id']), List.generate(12,(i)=>20-i));

    // Version 2 predates the version-3 integrity triggers. Exercise that actual
    // upgrade boundary without labelling a trigger-free fixture as version 3.
    await DBHelper.close();
    final path='${folder.path}/offline_khata.db';
    await databaseFactory.deleteDatabase(path);
    final old=await databaseFactory.openDatabase(path,options:OpenDatabaseOptions(version:2,onCreate:(db,version) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY,name TEXT,opening_balance REAL,cash_balance REAL,bank_balance REAL,created_at TEXT)');
      await db.execute('CREATE TABLE income(id INTEGER PRIMARY KEY,account_id INTEGER,amount REAL,description TEXT,date TEXT,created_at TEXT)');
      await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY,account_id INTEGER,amount REAL,mode TEXT,category TEXT,note TEXT,date TEXT)');
      await db.execute("INSERT INTO accounts VALUES(1,'Legacy account',1000,1000,0,'2026-11-01T00:00:00Z')");
      await db.execute("INSERT INTO income VALUES(1,1,100.10,'Payment','2026-11-04','2026-11-04T20:01:02Z')");
      await db.execute("INSERT INTO expenses VALUES(1,1,50.05,'cash','Travel','Travel','2026-11-04')");
      await db.execute("INSERT INTO expenses VALUES(2,NULL,7,'cash','Other','Historic unassigned','2026-11-04')");
    }));
    await old.close();
    data=await AnalysisLogic().getAnalysisData();
    expect(data['totalBalance'],closeTo(1043.05,0.000001));
    expect(data['unassignedExpenseCount'],1);
    final legacy=(data['recentTransactions'] as List).singleWhere((e)=>e['account_id']==null);
    expect(legacy['created_at'],isNull); expect(legacy['account_name'],isNull);
    db=await DBHelper.database;
    await expectLater(db.insert('expenses',{'account_id':null,'amount':7,'date':'2026-11-04',
      'note':'New unassigned','category':'Other','mode':'cash'}),throwsA(isA<DatabaseException>()));
  });

  testWidgets('loading failure is explicit; retry shows real data instead of fake zero totals', (tester) async {
    final first = Completer<Map<String,dynamic>>();
    final settings = AppSettings();
    var attempts=0;
    await tester.pumpWidget(SettingsScope(settings:settings, child:MaterialApp(home:DashboardScreen(
      loadSummary: () => ++attempts == 1 ? first.future : AnalysisLogic().getAnalysisData()))));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator),findsOneWidget);
    first.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open local records. Your data has not been deleted.'),findsOneWidget);
    expect(find.byKey(const ValueKey('metric-0')),findsNothing);
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('metric-0'))).data,'₹1,050.05');
    expect(attempts,2); expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink()); settings.dispose();
  });
}
