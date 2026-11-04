import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_layout.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_templates.dart';
import 'package:offline_khata_app/models/account_model.dart';
import 'package:offline_khata_app/features/dashboard/super_admin_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] != 'true') return;
    final sdk = Platform.environment['FLUTTER_ROOT'];
    final candidates = [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ];
    final path = candidates.firstWhere((p) => File(p).existsSync());
    final loader = FontLoader('PreviewFont');
    loader.addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    await loader.load();
    final iconFile = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(await iconFile.readAsBytes())));
    await icons.load();
  });
  final data = <String, dynamic>{
    'totalBalance': 31500.0, 'totalIncome': 15000.0, 'totalExpense': 3500.0,
    'accountDetails': [{
      'account': AccountModel.fromMap({'id': 1, 'name': 'Main Account',
        'opening_balance': 20000, 'created_at': '2026-11-04T00:00:00Z'}),
      'openingBalance': 20000, 'income': 15000, 'expense': 3500, 'balance': 31500,
    }],
    'recentTransactions': [
      {'kind': 'income', 'amount': 15000, 'note': 'Recorded income', 'date': '2026-11-04'},
      {'kind': 'expense', 'amount': 3500, 'note': 'Recorded expense', 'date': '2026-11-04'},
    ],
  };
  for (final layout in DashboardLayout.values) {
    for (final dark in [false, true]) {
      testWidgets('${layout.name} preserves one financial snapshot in ${dark ? 'dark' : 'light'} theme', (tester) async {
        tester.view.physicalSize = Size(dark ? 320 : 360, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? destination;
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'PreviewFont',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff086b78),
              brightness: dark ? Brightness.dark : Brightness.light)),
          home: Scaffold(appBar: AppBar(title: Text(layout.title(false))),
            body: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('RECONSTRUCTION PREVIEW · DEMO DATA'),
              const SizedBox(height: 16),
              DashboardTemplateView(layout: layout, data: data,
                onNavigate: (route) => destination = route),
            ]),
          ))),
        )));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          expect(find.byKey(ValueKey('metric-$i')), findsOneWidget);
          expect(tester.widget<Text>(find.byKey(ValueKey('metric-$i'))).data,
            contains(['31,500.00', '15,000.00', '3,500.00'][i]));
        }
        expect(data['totalBalance'], 31500.0);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] == 'true') {
          await tester.runAsync(() async {
            final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            if (bytes == null) throw StateError('Preview image encoding failed');
            await Directory('design-evidence').create(recursive: true);
            await File('design-evidence/${layout.preferenceId}-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
        final income = find.text('Add Income');
        await tester.ensureVisible(income);
        await tester.pumpAndSettle();
        await tester.tap(income.hitTestable());
        expect(destination, '/income');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final dark in [false, true]) {
    testWidgets('super admin design is explicitly simulated in ${dark ? 'dark' : 'light'} theme', (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
          debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'PreviewFont', colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff086b78), brightness: dark ? Brightness.dark : Brightness.light)),
        home: const SuperAdminPreview(),
      )));
      await tester.pumpAndSettle();
      expect(find.text('RECONSTRUCTION · SIMULATED PLATFORM DATA'), findsOneWidget);
      expect(find.text('₹198.00 · two ₹99 payments'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] == 'true') {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('Preview encoding failed');
          await Directory('design-evidence').create(recursive: true);
          await File('design-evidence/super-admin-${dark ? 'dark' : 'light'}.png')
            .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
