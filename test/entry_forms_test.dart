import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/features/income/income_screen.dart';
import 'package:offline_khata_app/features/expenses/expense_screen.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory directory;
  setUpAll(() async {
    if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] != 'true') return;
    final sdk = Platform.environment['FLUTTER_ROOT'];
    final path = ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'].firstWhere((p) => File(p).existsSync());
    final loader = FontLoader('PreviewFont');
    loader.addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    await loader.load();
    final iconFile = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(await iconFile.readAsBytes())));
    await icons.load();
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sss-entry-');
    await databaseFactory.setDatabasesPath(directory.path);
    final db = await DBHelper.database;
    await db.insert('accounts', {'name': 'Main Account', 'opening_balance': 1000,
      'cash_balance': 1000, 'bank_balance': 0, 'created_at': '2026-11-04T00:00:00Z'});
  });
  tearDown(() async {
    await DBHelper.close();
    await directory.delete(recursive: true);
  });

  for (final income in [false, true]) {
    testWidgets('${income ? 'income' : 'expense'} form saves selected category, contact and timestamp', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
          debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'PreviewFont', colorSchemeSeed: const Color(0xff086b78)),
        home: income ? const IncomeScreen() : const ExpenseScreen(),
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contact name (optional)'), 'Ravi Verma');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number (optional)'), '98765 43210');
      await tester.tap(find.text('Other').first);
      await tester.pumpAndSettle();
      final category = income ? 'Commission / Brokerage' : 'Travel';
      await tester.tap(find.text(category).last);
      await tester.pumpAndSettle();

      Future<void> capture(String suffix) async {
        if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] != 'true') return;
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('Preview encoding failed');
          await Directory('design-evidence').create(recursive: true);
          await File('design-evidence/${income ? 'income' : 'expense'}-$suffix.png')
            .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
      await capture('form');
      final save = find.text(income ? 'Save Income' : 'Save Expense');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Saved ✓'), findsOneWidget);
      final db = await DBHelper.database;
      final row = (await db.query(income ? 'income' : 'expenses')).single;
      expect(row['amount'], 200);
      expect(row['category'], category);
      expect(row['contact_name'], 'Ravi Verma');
      expect(row['contact_phone'], '+919876543210');
      expect(DateTime.parse(row['created_at'] as String).isUtc, isTrue);
      expect((await AnalysisLogic().getAnalysisData())['totalBalance'], income ? 1200 : 800);
      expect(find.textContaining('Saved at:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('saved');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
