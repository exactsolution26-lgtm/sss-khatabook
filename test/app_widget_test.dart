import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/app.dart';
import 'package:offline_khata_app/database/db_helper.dart';

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
    await tester.tap(find.text('Opening Balance'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Save & Continue'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
