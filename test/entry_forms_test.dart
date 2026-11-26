import 'dart:io';
import 'dart:typed_data';
import 'package:offline_khata_app/features/entries/attachment_widgets.dart';
import 'package:offline_khata_app/features/entries/attachments.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/theme/app_theme.dart';
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
        theme: AppTheme.lightTheme.copyWith(
          textTheme: AppTheme.lightTheme.textTheme.apply(fontFamily: 'PreviewFont')),
        home: income ? const IncomeScreen() : const ExpenseScreen(),
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contact name (optional)'), 'Ravi Verma');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number (optional)'), '98765 43210');
      await tester.enterText(find.byType(TextFormField).last, 'First entry note');
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').first);
      await tester.pumpAndSettle();
      final category = income ? 'Commission / Brokerage' : 'Travel';
      await tester.tap(find.text(category).last);
      await tester.pumpAndSettle();
      if (!income) {
        expect(find.text('Select category'), findsNothing);
        await tester.tap(find.text(category));
        await tester.pumpAndSettle();
        final selected = tester.widget<ListTile>(
          find.widgetWithText(ListTile, category),
        );
        expect(selected.selected, isTrue);
        expect(selected.leading, isA<Image>());
        expect(selected.trailing, isA<Icon>());
        Navigator.of(tester.element(find.widgetWithText(ListTile, category))).pop();
        await tester.pumpAndSettle();
      }

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
      final picker = tester.widget<AttachmentPicker>(find.byType(AttachmentPicker));
      picker.selected.value = [await PendingAttachment.inspect('receipt.pdf', Uint8List.fromList('%PDF-test'.codeUnits))];
      await tester.pumpAndSettle();
      await capture('form');
      final save = find.text(income ? 'Save Income' : 'Save Expense');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Saved ✓'), findsNothing);
      expect(find.text(income ? 'Income saved successfully' : 'Expense saved'), findsOneWidget);
      final db = await DBHelper.database;
      final row = (await db.query(income ? 'income' : 'expenses')).single;
      expect(row['amount'], 200);
      expect(await db.query('attachments'), hasLength(1));
      expect(picker.selected.value, isEmpty);
      expect(row['category'], category);
      expect(row['mode'], 'online');
      expect(row[income ? 'description' : 'note'], 'First entry note');
      expect(row['contact_name'], 'Ravi Verma');
      expect(row['contact_phone'], '+919876543210');
      expect(DateTime.parse(row['created_at'] as String).isUtc, isTrue);
      expect((await AnalysisLogic().getAnalysisData())['totalBalance'], income ? 1200 : 800);
      expect(find.textContaining('Saved at:'), findsNothing);
      for (final field in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
        expect(field.controller?.text ?? '', isEmpty);
      }
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      // A second entry must be possible immediately, without stale contact data.
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '50');
      await tester.ensureVisible(save);
      await tester.tap(save.hitTestable());
      await tester.pumpAndSettle();
      final rows = await db.query(income ? 'income' : 'expenses', orderBy: 'id');
      expect(rows, hasLength(2));
      expect(rows.last['amount'], 50);
      expect(rows.last['contact_name'], isNull);
      expect(rows.last['contact_phone'], isNull);
      expect(rows.last['category'], 'Other');
      expect(rows.last['mode'], 'cash');
      expect(rows.last[income ? 'description' : 'note'] ?? '', isEmpty);
      expect(tester.takeException(), isNull);
      await capture('saved');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final phone in ['', 'invalid', '9876543210']) {
      testWidgets('${income ? 'income' : 'expense'} name-only save and invalid-phone preservation: $phone', (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: income ? const IncomeScreen() : const ExpenseScreen()));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '125');
        final nameField = find.widgetWithText(TextFormField, 'Contact name (optional)');
        final phoneField = find.widgetWithText(TextFormField, 'Mobile number (optional)');
        await tester.enterText(nameField, 'shambhu');
        await tester.enterText(phoneField, phone);
        if (phone == '9876543210') {
          final db = await DBHelper.database;
          await db.execute("CREATE TRIGGER reject_entry BEFORE INSERT ON ${income ? 'income' : 'expenses'} BEGIN SELECT RAISE(ABORT, 'Test write failure'); END");
        }
        final save = find.text(income ? 'Save Income' : 'Save Expense');
        await tester.ensureVisible(save);
        await tester.tap(save.hitTestable());
        await tester.pumpAndSettle();
        final db = await DBHelper.database;
        final rows = await db.query(income ? 'income' : 'expenses');
        if (phone.isEmpty) {
          expect(rows, hasLength(1));
          expect(rows.single['contact_name'], 'shambhu');
          expect(rows.single['contact_phone'], '');
          for (final field in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
            expect(field.controller?.text ?? '', isEmpty);
          }
        } else {
          expect(rows, isEmpty);
          expect(tester.widget<TextFormField>(nameField).controller!.text, 'shambhu');
          expect(tester.widget<TextFormField>(phoneField).controller!.text, phone);
          expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, '125');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
