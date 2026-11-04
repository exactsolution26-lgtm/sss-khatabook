import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/app.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/features/accounts/opening_balance_screen.dart';
import 'package:offline_khata_app/core/utils/date_utils.dart' as khata_dates;

void main() {
  sqfliteFfiInit();
  // Keep real SQLite on disk, without isolate I/O inside the widget fake clock.
  databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory temporary;
  setUp(() async {
    await DBHelper.close();
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('sss-widget-');
    await databaseFactory.setDatabasesPath(temporary.path);
    // Open the actual schema before entering testWidgets' fake async zone.
    await DBHelper.database;
  });
  tearDown(() async {
    await DBHelper.close();
    await temporary.delete(recursive: true);
  });

  testWidgets('dashboard opens, settings switch theme and language', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Dark'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();
    expect(find.text('सेटिंग्स'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sss_theme_mode'), 'dark');
    expect(prefs.getString('sss_language'), 'hindi');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening form stays usable above a mobile keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Opening Balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opening Balance').hitTestable());
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Save & Continue'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('opening save has persistent success and the actual stored IST timestamp', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OpeningBalanceScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.enterText(find.byType(TextFormField).at(1), '1000');
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Saved ✓'), findsOneWidget);
    expect(find.text('Opening balance saved successfully'), findsOneWidget);
    final db = await DBHelper.database;
    final rows = await db.query('accounts');
    expect(rows, hasLength(1));
    expect(rows.single['opening_balance'], 1500);
    final stamp = DateTime.parse(rows.single['opening_balance_saved_at'] as String);
    expect(stamp.isUtc, isTrue);
    expect(find.text(khata_dates.DateUtils.formatIstDateTime(stamp)), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Opening balance saved successfully'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '600');
    await tester.pumpAndSettle();
    expect(find.text('Saved ✓'), findsNothing);
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    expect((await db.query('accounts')).single['opening_balance'], 1600);
    expect((await db.query('accounts')), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('IST saved timestamps include weekday and roll over independently of host timezone', () {
    expect(khata_dates.DateUtils.formatIstDateTime(DateTime.utc(2026, 11, 4, 20, 1, 2)),
      'Thursday, 5 November 2026 · 01:31:02 AM IST');
  });

  test('v3 migration preserves existing balances without fabricating historic save times', () async {
    final legacyPath = '${temporary.path}/legacy-v3.db';
    final old = await databaseFactory.openDatabase(legacyPath,
      options: OpenDatabaseOptions(version: 3, onCreate: (db, version) async {
        await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY, name TEXT, opening_balance REAL, cash_balance REAL, bank_balance REAL, created_at TEXT)');
        await db.execute("INSERT INTO accounts VALUES(7,'Existing',1500,500,1000,'2026-10-01T00:00:00Z')");
        await db.execute('CREATE TABLE income(id INTEGER PRIMARY KEY, account_id INTEGER, amount REAL, description TEXT, date TEXT, created_at TEXT)');
        await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY, account_id INTEGER, amount REAL, mode TEXT, category TEXT, note TEXT, date TEXT)');
      }));
    await old.close();
    final upgraded = await DBHelper.openAt(legacyPath);
    try {
      final row = (await upgraded.query('accounts')).single;
      expect(row['id'], 7);
      expect(row['opening_balance'], 1500);
      expect(row['cash_balance'], 500);
      expect(row['bank_balance'], 1000);
      expect(row['created_at'], '2026-10-01T00:00:00Z');
      expect(row['opening_balance_saved_at'], isNull);
      expect((await upgraded.rawQuery('PRAGMA integrity_check')).single.values.single, 'ok');
    } finally {
      await upgraded.close();
    }
  });
}
