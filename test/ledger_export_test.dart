import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/expenses/expense_controller.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/features/reports/ledger_export.dart';
import 'package:offline_khata_app/models/income_model.dart';
import 'package:offline_khata_app/models/expense_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit(); databaseFactory = databaseFactoryFfiNoIsolate;
  late Directory folder;
  setUp(() async {folder = await Directory.systemTemp.createTemp('sss-export-'); await databaseFactory.setDatabasesPath(folder.path);});
  tearDown(() async {await DBHelper.close(); await folder.delete(recursive: true);});

  test('record-backed ledger isolates accounts and exports correct running amounts and contact snapshots', () async {
    await AccountTable.saveAccount(name: 'Ravi Verma', openingBalance: 1000);
    await AccountTable.saveAccount(name: 'Other account', openingBalance: 99999);
    final account = (await AccountTable.getAllAccounts()).first;
    await IncomeController().createIncome(IncomeModel(accountId: account.id!, amount: 200,
      date: DateTime(2026, 11, 4), createdAt: DateTime.utc(2020), contactName: 'Ravi Verma',
      contactPhone: '9876543210', description: '=HYPERLINK("https://invalid.test")'));
    await ExpenseController().saveExpense(ExpenseModel(accountId: account.id, amount: 50,
      mode: 'cash', category: 'Travel', note: 'Site visit', date: '2026-11-05'));
    final report = await LedgerExport.load(account.id!);
    expect(report.openingPaise, 100000); expect(report.incomePaise, 20000);
    expect(report.expensePaise, 5000); expect(report.closingPaise, 115000);
    expect(report.entries.length, 2);
    final csv = utf8.decode(report.csv());
    expect(csv, contains('Ravi Verma')); expect(csv, contains("'+919876543210"));
    expect(csv, contains("'=HYPERLINK")); expect(csv, contains('1150.0'));
    expect(csv, isNot(contains('Other account'))); expect(csv, contains('IST'));
    final workbook = ZipDecoder().decodeBytes(report.xlsx());
    final xml = utf8.decode(workbook.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(xml, contains('t="inlineStr"')); expect(xml, isNot(contains('<f>')));
    expect(xml, contains('=HYPERLINK')); expect(xml, contains('<v>1150.0</v>'));
    final pdf = await report.pdf();
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    expect(pdf.length, greaterThan(1000));
    if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] == 'true') {
      await Directory('design-evidence').create(recursive: true);
      await File('design-evidence/ledger-example.pdf').writeAsBytes(pdf);
      await File('design-evidence/ledger-example.csv').writeAsBytes(report.csv());
      await File('design-evidence/ledger-example.xlsx').writeAsBytes(report.xlsx());
    }
  });
  test('CSV escapes quotes, multiline notes and spreadsheet formulas', () {
    expect(LedgerExport.csvCell('a,"b"\nc'), '"a,""b""\nc"');
    expect(LedgerExport.csvCell(' =SUM(1,2)'), '"\' =SUM(1,2)"');
    expect(LedgerExport.csvCell(-25), '"-25"');
  });
}
