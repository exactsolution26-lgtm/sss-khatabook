import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/entries/record_recovery.dart';
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
  test('period statements carry earlier balance forward and exclude outside-period entries',() async {
    await AccountTable.saveAccount(name: 'Statement customer',openingBalance: 1000);
    final id=(await AccountTable.getAllAccounts()).single.id!;
    for(final value in [(DateTime(2026,10,31),100.0),(DateTime(2026,11,1),200.0),(DateTime(2026,12,1),300.0)]) {
      await IncomeController().createIncome(IncomeModel(accountId: id,amount: value.$2,date: value.$1,createdAt: DateTime.now().toUtc()));
    }
    final report=await LedgerExport.load(id,fromDate: '2026-11-01',toDate: '2026-11-30');
    expect(report.openingPaise,110000);expect(report.incomePaise,20000);expect(report.closingPaise,130000);expect(report.entries.length,1);
    expect(utf8.decode(report.csv()),contains('2026-11-01 to 2026-11-30'));
    await expectLater(LedgerExport.load(id,fromDate: '2026-02-30'),throwsArgumentError);
  });
  test('dashboard and exported running balance agree to the paise through edits and recovery', () async {
    await AccountTable.saveAccount(name: 'Paise customer', openingBalance: 0);
    final account = (await AccountTable.getAllAccounts()).single.id!;
    final income = IncomeController();
    final date = DateTime(2026, 10, 1);
    final first = await income.createIncome(IncomeModel(
      accountId: account, amount: 0.10, date: date, createdAt: date,
    ));
    await income.createIncome(IncomeModel(accountId: account, amount: 0.20, date: date, createdAt: date));
    await ExpenseController().saveExpense(ExpenseModel(
      accountId: account, amount: 0.30, date: '2026-10-02', mode: 'cash',
      category: 'Other', note: '',
    ));

    Future<void> expectClosing(int paise) async {
      final dashboard = await AnalysisLogic().getAnalysisData();
      final ledger = await LedgerExport.load(account);
      expect(dashboard['totalBalance'], paise / 100);
      expect(ledger.closingPaise, paise);
      expect(ledger.tabularRows().last[3], paise / 100);
    }

    await expectClosing(0);
    await income.updateIncome((await income.getIncomeById(first)).copyWith(amount: 0.11));
    await expectClosing(1);
    final archive = await RecordRecovery.remove(income: true, id: first, accountId: account, reason: 'Check recovery');
    await expectClosing(-10);
    await RecordRecovery.restore(archive, account);
    await expectClosing(1);
  });
  test('legacy amounts reconcile across statements and spreadsheets', () async {
    await AccountTable.saveAccount(name: 'Legacy customer', openingBalance: 100.05);
    final account = (await AccountTable.getAllAccounts()).single.id!;
    final db = await DBHelper.database;
    await db.insert('income', {
      'account_id': account, 'amount': 10.126, 'date': '2026-09-30',
      'description': 'Legacy income', 'created_at': '2026-09-30 10:00:00',
    });
    final expense = await db.insert('expenses', {
      'account_id': account, 'amount': 4.124, 'date': '2026-10-01',
      'mode': 'cash', 'category': 'Other', 'note': 'Legacy expense',
    });
    await IncomeController().createIncome(IncomeModel(
      accountId: account, amount: 0.20, date: DateTime(2026, 10, 2),
      createdAt: DateTime.utc(2026, 10, 2),
    ));

    Future<LedgerExport> expectClosing(int paise) async {
      final report = await LedgerExport.load(
        account, fromDate: '2026-10-01', toDate: '2026-10-31',
      );
      expect(report.openingPaise, 11018);
      expect(report.closingPaise, paise);
      expect((await LedgerExport.load(account)).closingPaise, paise);
      expect((await AnalysisLogic().getAnalysisData())['totalBalance'], paise / 100);
      return report;
    }

    final report = await expectClosing(10626);
    expect(report.tabularRows()[4].sublist(2, 4), [4.12, 106.06]);
    expect(utf8.decode(report.csv()), contains('"4.12","106.06"'));
    final workbook = ZipDecoder().decodeBytes(report.xlsx());
    final xml = utf8.decode(workbook.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(xml, contains('<v>4.12</v>'));
    expect(xml, isNot(contains('<v>4.124</v>')));

    final archive = await RecordRecovery.remove(
      income: false, id: expense, accountId: account, reason: 'Check legacy recovery',
    );
    await expectClosing(11038);
    await RecordRecovery.restore(archive, account);
    await expectClosing(10626);
  });

  test('cash and bank opening balances are saved and added at paise precision', () async {
    await AccountTable.saveOpeningBalance(cash: 0.10, bank: 0.20);
    expect((await AccountTable.getAllAccounts()).single.openingBalance, 0.30);
    await expectLater(AccountTable.saveOpeningBalance(cash: 1.005, bank: 0), throwsArgumentError);
    expect((await AccountTable.getAllAccounts()).single.openingBalance, 0.30);
  });
  test('exported historic timestamps retain unknown timezone instead of inventing IST',() async {
    await AccountTable.saveAccount(name:'Historic',openingBalance:0);
    final account=(await AccountTable.getAllAccounts()).single;
    final db=await DBHelper.database;
    await db.insert('income',{'account_id':account.id,'amount':10,'date':'2026-11-04','description':'Historic',
      'created_at':'2026-11-04 12:00:00'});
    final report=await LedgerExport.load(account.id!);
    expect(utf8.decode(report.csv()),contains('historic timezone unknown'));
    expect(report.tabularRows().last.last,contains('historic timezone unknown'));
  });
  test('ledger PDF embeds shaped Hindi and spreadsheet exports retain Unicode', () async {
    const name = 'रवि त्रिपाठी';
    const note = 'Invoice 42 · प्रशिक्षण शुल्क और प्राप्ति';
    final report = LedgerExport({'name': name, 'opening_balance': 0}, [
      {'date': '2026-10-02', 'kind': 'income', 'amount': 100, 'note': note},
    ]);
    final pdf = await report.pdf();
    final encoded = latin1.decode(pdf);
    expect(encoded, startsWith('%PDF-'));
    expect(RegExp(r'/Subtype\s*/Image\b').allMatches(encoded).length, greaterThanOrEqualTo(2));
    expect(utf8.decode(report.csv()), contains(note));
    final workbook = ZipDecoder().decodeBytes(report.xlsx());
    expect(utf8.decode(workbook.findFile('xl/worksheets/sheet1.xml')!.content), contains(note));
    if (Platform.environment['CAPTURE_DASHBOARD_PREVIEWS'] == 'true') {
      await Directory('design-evidence').create(recursive: true);
      await File('design-evidence/ledger-hindi-example.pdf').writeAsBytes(pdf);
    }
  });
  test('CSV escapes quotes, multiline notes and spreadsheet formulas', () {
    expect(LedgerExport.csvCell('a,"b"\nc'), '"a,""b""\nc"');
    expect(LedgerExport.csvCell(' =SUM(1,2)'), '"\' =SUM(1,2)"');
    expect(LedgerExport.csvCell(-25), '"-25"');
  });
}
