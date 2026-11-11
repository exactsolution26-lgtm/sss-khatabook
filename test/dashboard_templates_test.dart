import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/theme/app_theme.dart';
import 'package:offline_khata_app/core/utils/date_utils.dart' as dates;
import 'package:intl/intl.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_layout.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_templates.dart';
import 'package:offline_khata_app/models/account_model.dart';
import 'package:offline_khata_app/features/dashboard/super_admin_preview.dart';

ThemeData previewTheme(bool dark) {
  final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'PreviewFont'));
}

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
      {'id': 1, 'account_id': 1, 'account_name': 'Main Account', 'kind': 'income', 'amount': 15000, 'note': 'Recorded income', 'date': '2026-11-04', 'created_at': '2026-11-04T03:00:00Z', 'contact_name': 'Ravi Sharma'},
      {'id': 1, 'account_id': 1, 'account_name': 'Main Account', 'kind': 'expense', 'amount': 3500, 'note': 'Recorded expense', 'date': '2026-11-04', 'created_at': '2026-11-04T03:15:00Z'},
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
          theme: previewTheme(dark),
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
  for (final layout in DashboardLayout.values) {
    testWidgets('${layout.name} supports large Hindi text, desktop and empty records', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 1000);
        String? destination;
        final hindi = width == 320;
        final empty = <String,dynamic>{'totalBalance':0,'totalIncome':0,'totalExpense':0,
          'accountDetails':<Object>[],'recentTransactions':<Object>[]};
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(size:Size(width,1000),textScaler:TextScaler.linear(hindi ? 2 : 1)),
          child: Scaffold(body: SingleChildScrollView(child: Padding(
            padding:const EdgeInsets.all(16),child:DashboardTemplateView(
              layout:layout,data:empty,hindi:hindi,onNavigate:(route)=>destination=route)))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(),isNull);
        for (var i=0;i<3;i++) {
          expect(tester.widget<Text>(find.byKey(ValueKey('metric-$i'))).data, '₹0.00');
        }
        final expense=find.text(hindi ? 'खर्च जोड़ें' : 'Add Expense');
        await tester.ensureVisible(expense); await tester.pumpAndSettle();
        await tester.tap(expense.hitTestable());
        expect(destination,'/expenses');
        expect(tester.takeException(),isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Compact search and type filter narrow recent entries', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: DashboardTemplateView(layout: DashboardLayout.dashboard3, data: data,
        onNavigate: (_) {}),
    ))));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'recorded income');
    await tester.pumpAndSettle();
    expect(find.text('Ravi Sharma'), findsOneWidget);
    expect(find.text('Recorded expense'), findsNothing);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    expect(find.text('Ravi Sharma'), findsNothing);
    expect(find.text('No recent entries to show.'), findsOneWidget);
  });

  testWidgets('Timeline period uses the matching recent entries', (tester) async {
    final rows = data['recentTransactions'] as List;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: DashboardTemplateView(layout: DashboardLayout.dashboard6,
        data: {...data, 'recentThisMonth': [rows.first], 'recentLastMonth': [rows.last]},
        onNavigate: (_) {}),
    ))));
    expect(find.text('Ravi Sharma'), findsOneWidget);
    expect(find.text('Recorded expense'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recent-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Sharma'), findsNothing);
    expect(find.text('Recorded expense'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('metric-0'))).data, '₹31,500.00');
  });

  testWidgets('Overview changes period without changing all-time totals', (tester) async {
    final today = dates.DateUtils.indiaToday();
    final lastMonth = DateFormat('yyyy-MM').format(DateTime(today.year, today.month - 1));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: DashboardTemplateView(layout: DashboardLayout.dashboard4,
        data: {...data, 'dashboardAnalytics': [
          {'month': lastMonth, 'week': 0, 'kind': 'expense', 'category': 'Travel', 'paise': 12345},
        ]},
        onNavigate: (_) {}),
    ))));
    expect(find.text('No entries in this period.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cash-flow-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month').last);
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('₹123.45'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('metric-0'))).data, '₹31,500.00');
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('super admin design is explicitly simulated in ${dark ? 'dark' : 'light'} theme', (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
          debugShowCheckedModeBanner: false,
        theme: previewTheme(dark),
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
